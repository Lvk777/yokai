-- Final viewmodel/audio correction.
-- Replaces only SelfChams, GunChams and HitSound/preview.
-- Keeps the effects local: viewmodel cosmetics + replacement of the game's own
-- local hit-confirm feedback. It does not inspect remote player health/remotes.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local VisualsRec = objects["VisualsWindow"]
local WorldRec = objects["WorldWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local World = WorldRec and WorldRec["Api"]
if not Visuals or not World then
    warn("ViewmodelAudioFixes: Visuals/World missing")
    return
end

local function camera()
    return Workspace.CurrentCamera
end

local function clean(v)
    return tostring(v):gsub(ZWSP, "")
end

local function optionNameFromKey(key)
    return clean(key):gsub("OptionsButton$", "")
end

local function removeNormalizedOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionNameFromKey(key) == name then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

local materialMap = {
    ForceField = Enum.Material.ForceField,
    Neon = Enum.Material.Neon,
    SmoothPlastic = Enum.Material.SmoothPlastic,
    Glass = Enum.Material.Glass,
    Foil = Enum.Material.Foil,
    Metal = Enum.Material.Metal,
    Plastic = Enum.Material.Plastic,
}
local materialList = {"ForceField","Neon","SmoothPlastic","Glass","Foil","Metal","Plastic"}

local armWords = {
    "arm","hand","forearm","wrist","glove","sleeve","skin",
    "leftarm","rightarm","left_arm","right_arm","larm","rarm",
    "lefthand","righthand","left_hand","right_hand"
}
local weaponWords = {
    "gun","weapon","barrel","muzzle","magazine","scope","sight","bolt",
    "ammo","bullet","receiver","stock","grip","slide","trigger","optic",
    "rail","blade","bodygun","wep","firearm"
}
local helperWords = {
    "helper","hitbox","collision","collider","camera","aimpart","aim_part",
    "origin","pivot","root","handleproxy","invisible","dummy"
}

local function containsWord(name, words)
    local n = tostring(name):lower()
    for _, word in ipairs(words) do
        if n:find(word, 1, true) then return true end
    end
    return false
end

local function ancestorNamed(part, words, maxDepth)
    local cur = part.Parent
    local depth = 0
    while cur and cur ~= camera() and depth < (maxDepth or 4) do
        if containsWord(cur.Name, words) then return true end
        cur = cur.Parent
        depth += 1
    end
    return false
end

local function effectivelyVisible(part)
    if not part:IsA("BasePart") then return false end
    return part.Transparency < 0.96 and part.LocalTransparencyModifier < 0.96
end

local function pointOnScreen(part)
    local cam = camera()
    if not cam then return nil end
    local p, visible = cam:WorldToViewportPoint(part.Position)
    if not visible or p.Z <= 0 then return nil end
    return p, cam.ViewportSize
end

local function explicitlyArm(part)
    -- Important: only inspect the part and a few immediate parents. Do NOT reject
    -- arms merely because the whole viewmodel is called Weapon/Gun.
    return containsWord(part.Name, armWords) or ancestorNamed(part, armWords, 3)
end

local function explicitlyWeapon(part)
    if containsWord(part.Name, weaponWords) then return true end
    -- Functional weapon submodels are useful, but stop before the broad viewmodel root.
    return ancestorNamed(part, weaponWords, 2)
end

local function likelyArmGeometry(part)
    if not effectivelyVisible(part) then return false end
    local p, vp = pointOnScreen(part)
    if not p or vp.X <= 0 or vp.Y <= 0 then return false end

    -- First-person arms generally enter from the lower left/right. Keep the band
    -- intentionally wide so different guns/animations still classify the arms.
    if p.Y < vp.Y * 0.42 then return false end
    local x = p.X / vp.X
    local y = p.Y / vp.Y
    local mag = part.Size.Magnitude
    if mag < 0.28 or mag > 16 then return false end

    local side = x <= 0.48 or x >= 0.52
    local deepLower = y >= 0.67
    local longPiece = math.max(part.Size.X, part.Size.Y, part.Size.Z) >= 1.25

    -- Explicit weapon-labelled pieces always stay with GunChams unless the part
    -- itself is explicitly named as an arm/hand.
    if explicitlyWeapon(part) and not explicitlyArm(part) then return false end
    return (side and longPiece) or deepLower
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = camera()
    return head and cam and (cam.CFrame.Position - head.Position).Magnitude <= 1.65 or false
end

local function isArmPart(part)
    if not effectivelyVisible(part) then return false end
    local cam = camera()
    local char = LocalPlayer.Character

    if cam and part:IsDescendantOf(cam) then
        if explicitlyArm(part) then return true end
        return likelyArmGeometry(part)
    end

    if char and part:IsDescendantOf(char) and not part:FindFirstAncestorWhichIsA("Tool") then
        return explicitlyArm(part)
    end
    return false
end

local function isGunPart(part)
    if not effectivelyVisible(part) then return false end
    if containsWord(part.Name, helperWords) then return false end
    if isArmPart(part) then return false end

    local char = LocalPlayer.Character
    local cam = camera()
    if char and part:IsDescendantOf(char) and part:FindFirstAncestorWhichIsA("Tool") then
        return true
    end
    if cam and part:IsDescendantOf(cam) then
        if explicitlyWeapon(part) then return true end

        -- Generic viewmodels often name every mesh Part/MeshPart. Anything visible
        -- in the lower weapon area that is not classified as an arm is treated as
        -- weapon geometry. Invisible/helper geometry is already rejected above.
        local p, vp = pointOnScreen(part)
        if p and vp.X > 0 and vp.Y > 0 then
            local x, y = p.X / vp.X, p.Y / vp.Y
            if y >= 0.40 and x >= 0.23 and x <= 0.77 and part.Size.Magnitude <= 12 then
                return true
            end
        end
    end
    return false
end

local function rememberPart(store, part)
    if store[part] then return end
    local variant
    pcall(function() variant = part.MaterialVariant end)
    store[part] = {
        Material = part.Material,
        MaterialVariant = variant,
        Color = part.Color,
        CastShadow = part.CastShadow,
        Reflectance = part.Reflectance,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function restorePart(store, part)
    local state = store[part]
    if state and part and part.Parent then
        pcall(function()
            part.Material = state.Material
            if state.MaterialVariant ~= nil then part.MaterialVariant = state.MaterialVariant end
            part.Color = state.Color
            part.CastShadow = state.CastShadow
            part.Reflectance = state.Reflectance
            if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
        end)
    end
    store[part] = nil
end

-- ============================================================================
-- SELFCHAMS / ARMCHAMS
-- ============================================================================
removeNormalizedOption("SelfChams")
for _, bind in ipairs({
    "YokaiArmMaterialFix","YokaiLocalSelfChams","YokaiFinalSelfChams",
    "YokaiUILayoutArmChams","YokaiCosmeticSelfChams","YokaiUniversalArmChams"
}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end

local selfEnabled = false
local selfMaterial = "ForceField"
local selfColor = Color3.fromRGB(119,120,255)
local selfBrightness = 0.70
local selfState = setmetatable({}, {__mode="k"})
local selfHighlights = setmetatable({}, {__mode="k"})

local function ensureSelfHighlight(part)
    local hi = selfHighlights[part]
    if not hi or not hi.Parent then
        hi = Instance.new("Highlight")
        hi.Name = "YokaiArmGlow"
        hi.Adornee = part
        hi.DepthMode = Enum.HighlightDepthMode.Occluded
        hi.Parent = part
        selfHighlights[part] = hi
    end
    hi.FillColor = selfColor
    hi.OutlineColor = selfColor
    hi.FillTransparency = math.clamp(0.82 - selfBrightness * 0.34, 0.42, 0.80)
    hi.OutlineTransparency = math.clamp(0.35 - selfBrightness * 0.28, 0.02, 0.35)
    hi.Enabled = true
end

local function styleArm(part)
    rememberPart(selfState, part)
    part.Material = materialMap[selfMaterial] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = selfColor
    part.CastShadow = false
    part.Reflectance = 0
    -- Keep the game's mesh/texture geometry intact: no transparency forcing and
    -- no texture deletion. This makes it work consistently across more weapons.
    ensureSelfHighlight(part)
end

local function restoreSelfPart(part)
    restorePart(selfState, part)
    local hi = selfHighlights[part]
    if hi and hi.Parent then hi:Destroy() end
    selfHighlights[part] = nil
end

local function restoreSelf()
    local parts = {}
    for part in pairs(selfState) do table.insert(parts, part) end
    for _, part in ipairs(parts) do restoreSelfPart(part) end
    for part, hi in pairs(selfHighlights) do
        if hi and hi.Parent then hi:Destroy() end
        selfHighlights[part] = nil
    end
end

local function applySelf()
    if not selfEnabled then return end
    local fp = isFirstPerson()
    local wanted = {}
    local cam = camera()
    local char = LocalPlayer.Character

    if fp then
        if cam then
            for _, obj in ipairs(cam:GetDescendants()) do
                if obj:IsA("BasePart") and isArmPart(obj) then wanted[obj] = true end
            end
        end
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") and isArmPart(obj) then wanted[obj] = true end
            end
        end
    elseif char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and not obj:FindFirstAncestorWhichIsA("Tool") and effectivelyVisible(obj) then
                wanted[obj] = true
            end
        end
    end

    local stale = {}
    for part in pairs(selfState) do if not wanted[part] then table.insert(stale, part) end end
    for _, part in ipairs(stale) do restoreSelfPart(part) end
    for part in pairs(wanted) do styleArm(part) end
end

local SelfChams = Visuals.CreateOptionsButton({
    ["Name"] = "SelfChams",
    ["Function"] = function(v)
        selfEnabled = v
        if v then applySelf() else restoreSelf() end
    end,
})
SelfChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) selfMaterial=v if selfEnabled then applySelf() end end})
SelfChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) selfColor=Color3.fromHSV(h,s,v) if selfEnabled then applySelf() end end})
SelfChams.CreateSlider({["Name"]="Brightness",["Min"]=1,["Max"]=10,["Default"]=7,["Function"]=function(v) selfBrightness=v/10 if selfEnabled then applySelf() end end})

RunService:BindToRenderStep("YokaiUniversalArmChams", Enum.RenderPriority.Camera.Value + 190, function()
    if selfEnabled then applySelf() end
end)

-- ============================================================================
-- GUNCHAMS: weapon geometry only, one fixed color, optional per-part glow.
-- ============================================================================
removeNormalizedOption("GunChams")
pcall(function() RunService:UnbindFromRenderStep("YokaiGunChamsExact") end)

local gunEnabled = false
local gunMaterial = "ForceField"
local gunColor = Color3.fromRGB(45,110,255)
local gunTransparency = 0
local gunGlow = true
local gunGlowStrength = 0.65
local gunState = setmetatable({}, {__mode="k"})
local gunHighlights = setmetatable({}, {__mode="k"})

local function ensureGunHighlight(part)
    local hi = gunHighlights[part]
    if not hi or not hi.Parent then
        hi = Instance.new("Highlight")
        hi.Name = "YokaiGunPartGlow"
        hi.Adornee = part
        hi.DepthMode = Enum.HighlightDepthMode.Occluded
        hi.Parent = part
        gunHighlights[part] = hi
    end
    hi.FillColor = gunColor
    hi.OutlineColor = gunColor
    hi.FillTransparency = math.clamp(0.90 - gunGlowStrength * 0.16, 0.72, 0.90)
    hi.OutlineTransparency = math.clamp(0.35 - gunGlowStrength * 0.30, 0.02, 0.35)
    hi.Enabled = gunGlow
end

local function styleGun(part)
    rememberPart(gunState, part)
    part.Material = materialMap[gunMaterial] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = gunColor
    part.Transparency = gunTransparency
    part.CastShadow = false
    part.Reflectance = 0
    -- Do not remove MeshPart textures: keeping the mesh/texture avoids turning
    -- complex guns into blocky silhouettes and preserves the exact gun shape.
    ensureGunHighlight(part)
end

local function restoreGunPart(part)
    restorePart(gunState, part)
    local hi = gunHighlights[part]
    if hi and hi.Parent then hi:Destroy() end
    gunHighlights[part] = nil
end

local function restoreGun()
    local parts = {}
    for part in pairs(gunState) do table.insert(parts, part) end
    for _, part in ipairs(parts) do restoreGunPart(part) end
    for part, hi in pairs(gunHighlights) do if hi and hi.Parent then hi:Destroy() end gunHighlights[part]=nil end
end

local function applyGun()
    if not gunEnabled then return end
    local wanted = {}
    local cam = camera()
    local char = LocalPlayer.Character
    for _, root in ipairs({cam, char}) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("BasePart") and isGunPart(obj) then wanted[obj] = true end
            end
        end
    end

    local stale = {}
    for part in pairs(gunState) do if not wanted[part] then table.insert(stale, part) end end
    for _, part in ipairs(stale) do restoreGunPart(part) end
    for part in pairs(wanted) do styleGun(part) end
end

local GunChams = Visuals.CreateOptionsButton({
    ["Name"] = "GunChams",
    ["Function"] = function(v)
        gunEnabled = v
        if v then applyGun() else restoreGun() end
    end,
})
GunChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) gunMaterial=v if gunEnabled then applyGun() end end})
GunChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) gunColor=Color3.fromHSV(h,s,v) if gunEnabled then applyGun() end end})
GunChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=90,["Default"]=0,["Function"]=function(v) gunTransparency=v/100 if gunEnabled then applyGun() end end})
GunChams.CreateToggle({["Name"]="Glow",["Default"]=true,["Function"]=function(v) gunGlow=v if gunEnabled then applyGun() end end})
GunChams.CreateSlider({["Name"]="Glow Strength",["Min"]=1,["Max"]=10,["Default"]=7,["Function"]=function(v) gunGlowStrength=v/10 if gunEnabled then applyGun() end end})

RunService:BindToRenderStep("YokaiGunChamsExact", Enum.RenderPriority.Camera.Value + 180, function()
    if gunEnabled then applyGun() end
end)

-- Reapply both after weapon/viewmodel swaps.
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(function()
        if selfEnabled then applySelf() end
        if gunEnabled then applyGun() end
    end)
end)
LocalPlayer.CharacterAdded:Connect(function()
    restoreSelf()
    restoreGun()
    task.wait(0.35)
    if selfEnabled then applySelf() end
    if gunEnabled then applyGun() end
end)

-- ============================================================================
-- HITSOUND: replace the game's own local hit-confirm feedback.
-- ============================================================================
removeNormalizedOption("HitSound")
removeNormalizedOption("HitSoundPreview")

local hitEnabled = false
local muteGame = true
local hitVolume = 1
local hitPreset = "Custom 91546829095879"
local hitSounds = {
    ["Custom 91546829095879"] = "rbxassetid://91546829095879",
    ["Classic"] = "rbxassetid://9118823106",
    ["Preset 1"] = "rbxassetid://136087587949971",
    ["Preset 2"] = "rbxassetid://118077944456512",
}

local watchedSounds = setmetatable({}, {__mode="k"})
local nativeVolumes = setmetatable({}, {__mode="k"})
local nativeIds = {}
local guiConnections = setmetatable({}, {__mode="k"})
local lastCustom = 0

local hitTerms = {
    "hitmarker","hit_marker","hitsound","hit_sound","hitconfirm","hit_confirm",
    "confirmhit","confirm_hit","damageconfirm","damage_confirm","headshot",
    "hitindicator","hit_indicator"
}

local function fullNameLower(obj)
    local parts = {}
    local cur = obj
    local depth = 0
    while cur and depth < 7 do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
        depth += 1
    end
    return table.concat(parts, "."):lower()
end

local function pathLooksHit(obj)
    local path = fullNameLower(obj)
    for _, term in ipairs(hitTerms) do
        if path:find(term, 1, true) then return true end
    end
    return false
end

local function playCustom()
    if not hitEnabled then return end
    local now = os.clock()
    if now - lastCustom < 0.035 then return end
    lastCustom = now
    local sound = Instance.new("Sound")
    sound.Name = "YokaiCustomHitSound"
    sound.SoundId = hitSounds[hitPreset] or hitSounds["Custom 91546829095879"]
    sound.Volume = hitVolume
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 5)
end

local function rememberAndMute(sound)
    if not sound or not sound.Parent or sound.Name == "YokaiCustomHitSound" then return end
    if nativeVolumes[sound] == nil then nativeVolumes[sound] = sound.Volume end
    if sound.SoundId and sound.SoundId ~= "" then nativeIds[sound.SoundId] = true end
    if muteGame and hitEnabled then sound.Volume = 0 end
end

local function nativeCandidate(sound)
    if not sound:IsA("Sound") or sound.Name == "YokaiCustomHitSound" then return false end
    if pathLooksHit(sound) then return true end
    return nativeIds[sound.SoundId] == true
end

local function onNativePlayed(sound)
    if not hitEnabled or sound.Name == "YokaiCustomHitSound" then return end
    if nativeCandidate(sound) then
        rememberAndMute(sound)
        playCustom()
    end
end

local function watchSound(sound)
    if not sound:IsA("Sound") or watchedSounds[sound] then return end
    watchedSounds[sound] = sound.Played:Connect(function() onNativePlayed(sound) end)
    if pathLooksHit(sound) then
        if sound.SoundId and sound.SoundId ~= "" then nativeIds[sound.SoundId] = true end
        if hitEnabled and muteGame then rememberAndMute(sound) end
    end
end

local function localAudioRoots()
    return {
        SoundService,
        LocalPlayer:FindFirstChild("PlayerGui"),
        camera(),
    }
end

local function scanSounds()
    for _, root in ipairs(localAudioRoots()) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("Sound") then watchSound(obj) end
            end
        end
    end
end

-- If the game exposes a hitmarker GUI instead of a clearly-named Sound, use the
-- GUI's own local confirmation to learn which short SoundId is playing at that
-- moment. This replaces existing feedback rather than inferring a hit ourselves.
local function capturePlayingLocalSounds()
    for _, root in ipairs({SoundService, LocalPlayer:FindFirstChild("PlayerGui")}) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("Sound") and obj.Name ~= "YokaiCustomHitSound" and obj.Playing then
                    local short = true
                    pcall(function()
                        if obj.TimeLength > 0 then short = obj.TimeLength <= 2.5 end
                    end)
                    if short then rememberAndMute(obj) end
                end
            end
        end
    end
end

local function hitGuiLike(gui)
    if not gui:IsA("GuiObject") then return false end
    return pathLooksHit(gui)
end

local function watchGui(gui)
    if not hitGuiLike(gui) or guiConnections[gui] then return end
    guiConnections[gui] = gui:GetPropertyChangedSignal("Visible"):Connect(function()
        if hitEnabled and gui.Visible then
            capturePlayingLocalSounds()
            playCustom()
        end
    end)
end

local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
if playerGui then
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("Sound") then watchSound(obj) end
        if obj:IsA("GuiObject") then watchGui(obj) end
    end
    playerGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then task.defer(watchSound, obj) end
        if obj:IsA("GuiObject") then task.defer(watchGui, obj) end
    end)
end

for _, root in ipairs({SoundService, Workspace}) do
    root.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") then task.defer(watchSound, obj) end
    end)
end
scanSounds()

local function enforceMute()
    if not hitEnabled or not muteGame then return end
    for sound in pairs(nativeVolumes) do
        if sound and sound.Parent and sound.Volume ~= 0 then sound.Volume = 0 end
    end
end
RunService.Heartbeat:Connect(enforceMute)

local function restoreNativeSounds()
    for sound, volume in pairs(nativeVolumes) do
        if sound and sound.Parent then pcall(function() sound.Volume = volume end) end
        nativeVolumes[sound] = nil
    end
end

local HitSound = World.CreateOptionsButton({
    ["Name"] = "HitSound",
    ["Function"] = function(v)
        hitEnabled = v
        if v then
            scanSounds()
            for _, root in ipairs(localAudioRoots()) do
                if root then
                    for _, obj in ipairs(root:GetDescendants()) do
                        if obj:IsA("Sound") and pathLooksHit(obj) then rememberAndMute(obj) end
                    end
                end
            end
        else
            restoreNativeSounds()
        end
    end,
})
HitSound.CreateDropdown({["Name"]="Sound",["List"]={"Custom 91546829095879","Classic","Preset 1","Preset 2"},["Function"]=function(v) hitPreset=v end})
HitSound.CreateSlider({["Name"]="Volume",["Min"]=1,["Max"]=10,["Default"]=5,["Function"]=function(v) hitVolume=v/5 end})
HitSound.CreateToggle({["Name"]="Mute Game HitSound",["Default"]=true,["Function"]=function(v)
    muteGame=v
    if v and hitEnabled then
        for sound in pairs(nativeVolumes) do if sound and sound.Parent then sound.Volume=0 end end
    elseif not v then
        restoreNativeSounds()
    end
end})

local HitSoundPreview
HitSoundPreview = World.CreateOptionsButton({
    ["Name"] = "HitSoundPreview",
    ["Function"] = function(v)
        if not v then return end
        local old = hitEnabled
        hitEnabled = true
        playCustom()
        hitEnabled = old
        task.defer(function() pcall(function() HitSoundPreview.ToggleButton(false) end) end)
    end,
})

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Viewmodel + HitSound fixes loaded", 3)
end)
