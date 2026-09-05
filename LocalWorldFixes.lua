-- Final local/self fixes for the curated Yokai build.
-- This patch intentionally avoids player-targeting logic.
-- It replaces the old global projectile scanner with a local-input tracer,
-- moves HitSound to World with preview/presets, removes World FOV, and adds
-- a local GunChams glow layer without replacing Visuals V4's GunChams.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local WorldRec = objects["WorldWindow"]
local World = WorldRec and WorldRec["Api"]
local ZWSP = utf8.char(0x200B)

if not World then
    warn("LocalWorldFixes: World window not found")
    return
end

local function removeOptionByKey(key)
    local rec = objects[key]
    if not rec then return end
    pcall(function()
        local api = rec["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
    end)
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end

local function removeNamedOption(name)
    removeOptionByKey(name .. "OptionsButton")
    removeOptionByKey(name .. ZWSP .. "OptionsButton")
end

-- Remove the old World FOV entirely. FOVChanger remains in Visuals.
removeNamedOption("FOV")

-- Remove the old Utility HitSound and any previous preview before rebuilding it in World.
removeNamedOption("HitSound")
removeNamedOption("HitSoundPreview")

-- Remove the old global projectile tracker. It listened to every descendant added
-- to Workspace, which is why other players' shooting could create many tracers.
removeNamedOption("BulletTracer")

-- --------------------------------------------------------------------------
-- WORLD: HitSound + Preview
-- --------------------------------------------------------------------------
local hitSoundEnabled = false
local hitSoundVolume = 1
local hitSoundPreset = "Classic"
local hitSounds = {
    ["Classic"] = "rbxassetid://9118823106",
    ["Preset 1"] = "rbxassetid://136087587949971",
    ["Preset 2"] = "rbxassetid://118077944456512",
}

local function playHitSound()
    local sound = Instance.new("Sound")
    sound.Name = "YokaiLocalHitSound"
    sound.SoundId = hitSounds[hitSoundPreset] or hitSounds.Classic
    sound.Volume = hitSoundVolume
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 5)
end

local HitSound = World.CreateOptionsButton({
    ["Name"] = "HitSound",
    ["Function"] = function(v)
        hitSoundEnabled = v
    end,
})
HitSound.CreateDropdown({
    ["Name"] = "Sound",
    ["List"] = {"Classic", "Preset 1", "Preset 2"},
    ["Function"] = function(v) hitSoundPreset = v end,
})
HitSound.CreateSlider({
    ["Name"] = "Volume",
    ["Min"] = 1,
    ["Max"] = 10,
    ["Default"] = 5,
    ["Function"] = function(v) hitSoundVolume = v / 5 end,
})

local HitSoundPreview
HitSoundPreview = World.CreateOptionsButton({
    ["Name"] = "HitSoundPreview",
    ["Function"] = function(v)
        if not v then return end
        playHitSound()
        task.defer(function()
            pcall(function() HitSoundPreview.ToggleButton(false) end)
        end)
    end,
})

-- In Roblox Studio, HitSound can respond to damage on non-player Humanoid dummies.
-- Outside Studio, Preview remains available without observing other players.
local studioHumanoids = setmetatable({}, {__mode = "k"})
local function watchStudioDummy(model)
    if not RunService:IsStudio() or not model:IsA("Model") then return end
    if Players:GetPlayerFromCharacter(model) then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or studioHumanoids[hum] then return end
    local last = hum.Health
    studioHumanoids[hum] = hum.HealthChanged:Connect(function(value)
        if hitSoundEnabled and value < last then playHitSound() end
        last = value
    end)
end
if RunService:IsStudio() then
    for _, obj in ipairs(Workspace:GetDescendants()) do watchStudioDummy(obj) end
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Humanoid") and obj.Parent then task.defer(watchStudioDummy, obj.Parent) end
    end)
end

-- --------------------------------------------------------------------------
-- WORLD: Local-only BulletTracer
-- --------------------------------------------------------------------------
local tracerEnabled = false
local tracerColor = Color3.fromRGB(255,255,255)
local tracerMaterial = "Neon"
local tracerLifetime = 0.35
local tracerThickness = 0.045
local tracerRange = 1200
local tracerRate = 10
local tracerMaxActive = 20
local triggerHeld = false
local nextTrace = 0
local activeTraces = {}

local tracerMaterials = {
    Neon = Enum.Material.Neon,
    ForceField = Enum.Material.ForceField,
    Glass = Enum.Material.Glass,
    Metal = Enum.Material.Metal,
    SmoothPlastic = Enum.Material.SmoothPlastic,
}

local function cleanupTrace(part)
    for i = #activeTraces, 1, -1 do
        if activeTraces[i] == part or not activeTraces[i] or not activeTraces[i].Parent then
            table.remove(activeTraces, i)
        end
    end
end

local function trimTracePool()
    for i = #activeTraces, 1, -1 do
        if not activeTraces[i] or not activeTraces[i].Parent then table.remove(activeTraces, i) end
    end
    while #activeTraces >= tracerMaxActive do
        local oldest = table.remove(activeTraces, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

local function equippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool") or nil
end

local function cameraWeaponModel()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    for _, obj in ipairs(cam:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Tool") then
            local n = obj.Name:lower()
            if n:find("view",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) or n:find("arms",1,true) then
                return obj
            end
        end
    end
    return nil
end

local function hasLocalWeapon()
    return equippedTool() ~= nil or cameraWeaponModel() ~= nil
end

local function findMuzzleIn(root)
    if not root then return nil end
    local preferred = {"muzzle", "firepoint", "fire_point", "barrel", "tip", "shootpoint", "shoot_point"}
    for _, obj in ipairs(root:GetDescendants()) do
        local n = obj.Name:lower()
        for _, word in ipairs(preferred) do
            if n == word or n:find(word,1,true) then
                if obj:IsA("Attachment") then return obj.WorldPosition end
                if obj:IsA("BasePart") then return obj.Position end
            end
        end
    end
    local handle = root:FindFirstChild("Handle", true)
    if handle and handle:IsA("BasePart") then return handle.Position end
    return nil
end

local function tracerOrigin()
    local origin = findMuzzleIn(equippedTool()) or findMuzzleIn(cameraWeaponModel())
    local cam = Workspace.CurrentCamera
    return origin or (cam and cam.CFrame.Position) or Vector3.zero
end

local function rayDestination(origin)
    local cam = Workspace.CurrentCamera
    if not cam then return origin end
    local vp = cam.ViewportSize
    local unitRay = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
    local direction = unitRay.Direction.Unit * tracerRange
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, cam}
    params.IgnoreWater = false
    local result = Workspace:Raycast(origin, direction, params)
    return result and result.Position or (origin + direction)
end

local function createTrace(origin, finish)
    local delta = finish - origin
    local length = delta.Magnitude
    if length < 0.05 then return end
    trimTracePool()

    local line = Instance.new("Part")
    line.Name = "YokaiLocalBulletTracer"
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.CanQuery = false
    line.CastShadow = false
    line.Material = tracerMaterials[tracerMaterial] or Enum.Material.Neon
    line.Color = tracerColor
    line.Transparency = 0.04
    line.Size = Vector3.new(tracerThickness, tracerThickness, length)
    line.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
    line.Parent = Workspace
    table.insert(activeTraces, line)

    task.delay(tracerLifetime, function()
        if line and line.Parent then line:Destroy() end
        cleanupTrace(line)
    end)
end

local function guiIsOpen()
    local open = false
    pcall(function()
        local main = GuiLibrary["MainGui"]
        local click = main and main:FindFirstChild("ClickGui", true)
        open = click and click.Visible or false
    end)
    return open
end

local function emitLocalTrace()
    if not tracerEnabled or not hasLocalWeapon() or guiIsOpen() then return end
    local origin = tracerOrigin()
    createTrace(origin, rayDestination(origin))
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        triggerHeld = true
        nextTrace = 0
        emitLocalTrace()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerHeld = false end
end)

RunService.Heartbeat:Connect(function()
    if not tracerEnabled or not triggerHeld or not hasLocalWeapon() then return end
    local now = os.clock()
    if now >= nextTrace then
        nextTrace = now + (1 / math.max(1, tracerRate))
        emitLocalTrace()
    end
end)

local BulletTracer = World.CreateOptionsButton({
    ["Name"] = "BulletTracer",
    ["Function"] = function(v)
        tracerEnabled = v
        if not v then
            triggerHeld = false
            for _, part in ipairs(activeTraces) do if part and part.Parent then part:Destroy() end end
            table.clear(activeTraces)
        end
    end,
})
BulletTracer.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = {"Neon", "ForceField", "Glass", "Metal", "SmoothPlastic"},
    ["Function"] = function(v) tracerMaterial = v end,
})
BulletTracer.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) tracerColor = Color3.fromHSV(h,s,v) end,
})
BulletTracer.CreateSlider({
    ["Name"] = "Lifetime",
    ["Min"] = 1,
    ["Max"] = 15,
    ["Default"] = 4,
    ["Function"] = function(v) tracerLifetime = v / 10 end,
})
BulletTracer.CreateSlider({
    ["Name"] = "Thickness",
    ["Min"] = 2,
    ["Max"] = 15,
    ["Default"] = 5,
    ["Function"] = function(v) tracerThickness = v / 100 end,
})
BulletTracer.CreateSlider({
    ["Name"] = "Fire Rate",
    ["Min"] = 1,
    ["Max"] = 20,
    ["Default"] = 10,
    ["Function"] = function(v) tracerRate = v end,
})
BulletTracer.CreateSlider({
    ["Name"] = "Range",
    ["Min"] = 100,
    ["Max"] = 3000,
    ["Default"] = 1200,
    ["Function"] = function(v) tracerRange = v end,
})

-- --------------------------------------------------------------------------
-- VISUALS: Add Glow to the existing local GunChams without replacing it.
-- --------------------------------------------------------------------------
local gunRec = objects["GunChams" .. ZWSP .. "OptionsButton"] or objects["GunChamsOptionsButton"]
local gunGlowEnabled = false
local gunGlowStrength = 0.8
local gunBloom
local gunHighlights = setmetatable({}, {__mode = "k"})

local function readGunColor()
    local fallback = Color3.fromRGB(40,235,90)
    for key, rec in pairs(objects) do
        local clean = tostring(key):gsub(ZWSP, "")
        if clean:find("GunChams",1,true) and clean:find("Visible Color",1,true) and rec["Api"] then
            local api = rec["Api"]
            if api.Hue ~= nil and api.Sat ~= nil and api.Value ~= nil then
                return Color3.fromHSV(api.Hue, api.Sat, api.Value)
            end
        end
    end
    return fallback
end

local function gunRootFromPart(part)
    local tool = part:FindFirstAncestorWhichIsA("Tool")
    if tool then return tool end
    local cam = Workspace.CurrentCamera
    local cur = part.Parent
    while cur and cam and cur and cur ~= cam do
        if cur:IsA("Model") then
            local n = cur.Name:lower()
            if n:find("view",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) then return cur end
        end
        cur = cur.Parent
    end
    return part
end

local function localGunParts()
    local list = {}
    local char = LocalPlayer.Character
    local cam = Workspace.CurrentCamera
    local roots = {char, cam}
    for _, root in ipairs(roots) do
        if root then
            for _, part in ipairs(root:GetDescendants()) do
                if part:IsA("BasePart") then
                    local isTool = char and part:IsDescendantOf(char) and part:FindFirstAncestorWhichIsA("Tool")
                    local isCameraWeapon = false
                    if cam and part:IsDescendantOf(cam) then
                        local cur = part.Parent
                        while cur and cur ~= cam do
                            local n = cur.Name:lower()
                            if cur:IsA("Tool") or n:find("view",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) then isCameraWeapon = true break end
                            cur = cur.Parent
                        end
                    end
                    if isTool or isCameraWeapon then table.insert(list, part) end
                end
            end
        end
    end
    return list
end

local function ensureGunBloom()
    if not gunGlowEnabled then return end
    if not gunBloom or not gunBloom.Parent then
        gunBloom = Lighting:FindFirstChild("YokaiGunBloom")
        if not gunBloom then
            gunBloom = Instance.new("BloomEffect")
            gunBloom.Name = "YokaiGunBloom"
            gunBloom.Parent = Lighting
        end
    end
    gunBloom.Intensity = gunGlowStrength
    gunBloom.Size = 24
    gunBloom.Threshold = 0.78
end

local function clearGunGlow()
    for root, highlight in pairs(gunHighlights) do
        if highlight and highlight.Parent then highlight:Destroy() end
        gunHighlights[root] = nil
    end
    if gunBloom and gunBloom.Parent then gunBloom:Destroy() end
    gunBloom = nil
end

local function updateGunGlow()
    local apiEnabled = gunRec and gunRec["Api"] and gunRec["Api"]["Enabled"]
    if not gunGlowEnabled or not apiEnabled then clearGunGlow() return end
    ensureGunBloom()
    local color = readGunColor()
    local seen = {}
    for _, part in ipairs(localGunParts()) do
        local root = gunRootFromPart(part)
        seen[root] = true
        local hi = gunHighlights[root]
        if not hi or not hi.Parent then
            hi = Instance.new("Highlight")
            hi.Name = "YokaiGunGlow"
            hi.Adornee = root
            hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hi.Parent = Workspace
            gunHighlights[root] = hi
        end
        hi.FillColor = color
        hi.OutlineColor = color
        hi.FillTransparency = math.clamp(0.90 - gunGlowStrength * 0.15, 0.55, 0.9)
        hi.OutlineTransparency = math.clamp(0.30 - gunGlowStrength * 0.2, 0, 0.3)
        hi.Enabled = true
    end
    for root, hi in pairs(gunHighlights) do
        if not seen[root] then if hi and hi.Parent then hi:Destroy() end gunHighlights[root] = nil end
    end
end

if gunRec and gunRec["Api"] then
    pcall(function()
        gunRec["Api"].CreateToggle({
            ["Name"] = "Glow",
            ["Default"] = false,
            ["Function"] = function(v)
                gunGlowEnabled = v
                if v then updateGunGlow() else clearGunGlow() end
            end,
        })
        gunRec["Api"].CreateSlider({
            ["Name"] = "Glow Strength",
            ["Min"] = 1,
            ["Max"] = 15,
            ["Default"] = 8,
            ["Function"] = function(v)
                gunGlowStrength = v / 10
                if gunGlowEnabled then updateGunGlow() end
            end,
        })
    end)
end

local glowTimer = 0
RunService.Heartbeat:Connect(function(dt)
    if not gunGlowEnabled then return end
    glowTimer += dt
    if glowTimer >= 0.12 then glowTimer = 0 updateGunGlow() end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Local World fixes loaded", 3)
end)
