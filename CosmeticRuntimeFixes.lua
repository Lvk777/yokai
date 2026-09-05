-- Final local cosmetic runtime fixes.
-- Replaces only SelfChams, BulletTracer and HitSound/preview.
-- Keeps effects local/self-only; target-style rendering remains Preview/Studio-only.

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
local ZWSP = utf8.char(0x200B)

local VisualsRec = objects["VisualsWindow"]
local WorldRec = objects["WorldWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local World = WorldRec and WorldRec["Api"]
if not Visuals or not World then
    warn("CosmeticRuntimeFixes: Visuals/World missing")
    return
end

local function clean(value)
    return tostring(value):gsub(ZWSP, "")
end

local function optionNameFromKey(key)
    return clean(key):gsub("OptionsButton$", "")
end

local function removeNormalizedOption(name)
    local list = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionNameFromKey(key) == name then
            table.insert(list, key)
        end
    end
    for _, key in ipairs(list) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

local function camera()
    return Workspace.CurrentCamera
end

local function guiOpen()
    local opened = false
    pcall(function()
        local main = GuiLibrary["MainGui"]
        local click = main and main:FindFirstChild("ClickGui", true)
        opened = click and click.Visible or false
    end)
    return opened
end

-- ============================================================================
-- SELFCHAMS: bright/uniform local arms, with broader FPS-viewmodel detection.
-- ============================================================================
removeNormalizedOption("SelfChams")
pcall(function() RunService:UnbindFromRenderStep("YokaiArmMaterialFix") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiLocalSelfChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiFinalSelfChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiUILayoutArmChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiCosmeticSelfChams") end)

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
local armWords = {"arm","hand","forearm","wrist","glove","sleeve","skin","leftarm","rightarm","l_arm","r_arm"}
local weaponWords = {"gun","weapon","barrel","muzzle","magazine","scope","sight","bolt","ammo","bullet","receiver","stock","grip","slide","trigger","optic","rail"}

local selfEnabled = false
local selfMaterial = "ForceField"
local selfColor = Color3.fromRGB(119,120,255)
local selfGlow = 0.55
local partState = setmetatable({}, {__mode="k"})
local textureState = setmetatable({}, {__mode="k"})
local meshState = setmetatable({}, {__mode="k"})
local surfaceState = setmetatable({}, {__mode="k"})
local armHighlights = setmetatable({}, {__mode="k"})

local function containsWord(name, words)
    local n = tostring(name):lower()
    for _, word in ipairs(words) do
        if n:find(word, 1, true) then return true end
    end
    return false
end

local function parentArmish(part)
    local cur = part.Parent
    local depth = 0
    while cur and depth < 4 do
        if containsWord(cur.Name, armWords) then return true end
        cur = cur.Parent
        depth += 1
    end
    return false
end

local function ownWeaponish(part)
    if containsWord(part.Name, weaponWords) then return true end
    local cur = part.Parent
    local depth = 0
    while cur and depth < 2 do
        if containsWord(cur.Name, weaponWords) then return true end
        cur = cur.Parent
        depth += 1
    end
    return false
end

local function effectivelyVisible(part)
    return part.Transparency < 0.98 and part.LocalTransparencyModifier < 0.98
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = camera()
    return head and cam and (cam.CFrame.Position - head.Position).Magnitude <= 1.55 or false
end

local function genericViewmodelArm(part)
    local cam = camera()
    if not cam or not part:IsDescendantOf(cam) or not effectivelyVisible(part) then return false end
    if ownWeaponish(part) then return false end
    local p, onScreen = cam:WorldToViewportPoint(part.Position)
    if not onScreen or p.Z <= 0 then return false end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return false end

    -- The FPS arms in Infected Lands are the large visible meshes entering from
    -- the lower sides of the viewport. This fallback intentionally ignores the
    -- weapon root name and classifies the actual visible part geometry instead.
    if p.Y < vp.Y * 0.50 then return false end
    if not (p.X < vp.X * 0.46 or p.X > vp.X * 0.54) then return false end
    local mag = part.Size.Magnitude
    if mag < 0.45 or mag > 14 then return false end
    return true
end

local function wantedFirstPerson(part)
    if not effectivelyVisible(part) then return false end
    local cam = camera()
    local char = LocalPlayer.Character

    if cam and part:IsDescendantOf(cam) then
        if containsWord(part.Name, armWords) or parentArmish(part) then return true end
        return genericViewmodelArm(part)
    end

    if char and part:IsDescendantOf(char) then
        if part:FindFirstAncestorWhichIsA("Tool") then return false end
        return containsWord(part.Name, armWords) or parentArmish(part)
    end
    return false
end

local function wantedThirdPerson(part)
    local char = LocalPlayer.Character
    return char and part:IsDescendantOf(char)
        and part.Name ~= "HumanoidRootPart"
        and not part:FindFirstAncestorWhichIsA("Tool")
        and effectivelyVisible(part)
end

local function rememberPart(part)
    if partState[part] then return end
    local variant
    pcall(function() variant = part.MaterialVariant end)
    partState[part] = {
        Material = part.Material,
        MaterialVariant = variant,
        Color = part.Color,
        CastShadow = part.CastShadow,
        Reflectance = part.Reflectance,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function hideLayers(part)
    for _, obj in ipairs(part:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if textureState[obj] == nil then textureState[obj] = obj.Transparency end
            obj.Transparency = 1
        elseif obj:IsA("SpecialMesh") then
            if meshState[obj] == nil then meshState[obj] = obj.TextureId end
            obj.TextureId = ""
        elseif obj:IsA("SurfaceAppearance") then
            if surfaceState[obj] == nil then surfaceState[obj] = obj.Parent end
            obj.Parent = nil
        end
    end
end

local function ensureArmHighlight(part)
    local hi = armHighlights[part]
    if not hi or not hi.Parent then
        hi = Instance.new("Highlight")
        hi.Name = "YokaiSelfArmGlow"
        hi.Adornee = part
        hi.DepthMode = Enum.HighlightDepthMode.Occluded
        hi.Parent = part
        armHighlights[part] = hi
    end
    hi.FillColor = selfColor
    hi.OutlineColor = selfColor
    hi.FillTransparency = math.clamp(0.72 - selfGlow * 0.30, 0.38, 0.72)
    hi.OutlineTransparency = math.clamp(0.38 - selfGlow * 0.35, 0.02, 0.38)
    hi.Enabled = true
end

local function stylePart(part)
    rememberPart(part)
    part.Material = materialMap[selfMaterial] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = selfColor
    part.Reflectance = 0
    part.CastShadow = false
    -- Preserve the game's own first-person visibility.
    if part:IsA("MeshPart") then part.TextureID = "" end
    hideLayers(part)
    ensureArmHighlight(part)
end

local function restoreLayersFor(part)
    for obj, value in pairs(textureState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then pcall(function() obj.Transparency = value end) textureState[obj] = nil end
    end
    for obj, value in pairs(meshState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then pcall(function() obj.TextureId = value end) meshState[obj] = nil end
    end
    for obj, parent in pairs(surfaceState) do
        if obj and parent then pcall(function() obj.Parent = parent end) surfaceState[obj] = nil end
    end
end

local function restorePart(part, forget)
    local state = partState[part]
    if state and part and part.Parent then
        pcall(function()
            part.Material = state.Material
            if state.MaterialVariant ~= nil then part.MaterialVariant = state.MaterialVariant end
            part.Color = state.Color
            part.CastShadow = state.CastShadow
            part.Reflectance = state.Reflectance
            if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
        end)
        restoreLayersFor(part)
    end
    local hi = armHighlights[part]
    if hi and hi.Parent then hi:Destroy() end
    armHighlights[part] = nil
    if forget then partState[part] = nil end
end

local function restoreAll()
    for part in pairs(partState) do restorePart(part, true) end
    for obj, value in pairs(textureState) do if obj and obj.Parent then pcall(function() obj.Transparency=value end) end textureState[obj]=nil end
    for obj, value in pairs(meshState) do if obj and obj.Parent then pcall(function() obj.TextureId=value end) end meshState[obj]=nil end
    for obj, parent in pairs(surfaceState) do if obj and parent then pcall(function() obj.Parent=parent end) end surfaceState[obj]=nil end
    for part, hi in pairs(armHighlights) do if hi and hi.Parent then hi:Destroy() end armHighlights[part]=nil end
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
                if obj:IsA("BasePart") and wantedFirstPerson(obj) then wanted[obj] = true end
            end
        end
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") and wantedFirstPerson(obj) then wanted[obj] = true end
            end
        end
    elseif char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and wantedThirdPerson(obj) then wanted[obj] = true end
        end
    end

    for part in pairs(partState) do if not wanted[part] then restorePart(part, true) end end
    for part in pairs(wanted) do stylePart(part) end
end

local SelfChams = Visuals.CreateOptionsButton({
    ["Name"] = "SelfChams",
    ["Function"] = function(v)
        selfEnabled = v
        if v then applySelf() else restoreAll() end
    end,
})
SelfChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) selfMaterial=v if selfEnabled then applySelf() end end})
SelfChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) selfColor=Color3.fromHSV(h,s,v) if selfEnabled then applySelf() end end})
SelfChams.CreateSlider({["Name"]="Brightness",["Min"]=1,["Max"]=10,["Default"]=6,["Function"]=function(v) selfGlow=v/10 if selfEnabled then applySelf() end end})

RunService:BindToRenderStep("YokaiCosmeticSelfChams", Enum.RenderPriority.Camera.Value + 150, function()
    if selfEnabled then applySelf() end
end)
LocalPlayer.CharacterAdded:Connect(function()
    restoreAll()
    task.wait(.45)
    if selfEnabled then applySelf() end
end)

-- ============================================================================
-- BULLETTRACER: local weapon only, origin must be at an actual/estimated muzzle.
-- ============================================================================
removeNormalizedOption("BulletTracer")

local tracerEnabled = false
local tracerColor = Color3.fromRGB(255,255,255)
local tracerMaterial = "Neon"
local tracerLifetime = 0.35
local tracerThickness = 0.045
local tracerRange = 1800
local tracerRate = 10
local triggerHeld = false
local nextTrace = 0
local lastEmitAt = 0
local activeTraces = {}
local tracerMaxActive = 12
local recentMuzzle
local suppressUntil = 0
local hiddenNative = setmetatable({}, {__mode="k"})
local toolConnections = setmetatable({}, {__mode="k"})

local tracerMaterials = {
    Neon=Enum.Material.Neon,
    ForceField=Enum.Material.ForceField,
    Glass=Enum.Material.Glass,
    Metal=Enum.Material.Metal,
    SmoothPlastic=Enum.Material.SmoothPlastic,
}

local function equippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool") or nil
end

local function cameraWeaponRoots()
    local cam = camera()
    local roots = {}
    if not cam then return roots end
    for _, obj in ipairs(cam:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Tool") or obj:IsA("Folder") then
            local n = obj.Name:lower()
            local parts = 0
            for _, d in ipairs(obj:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
            if parts > 0 and (n:find("view",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) or n:find("arms",1,true) or parts >= 3) then
                table.insert(roots,obj)
            end
        end
    end
    return roots
end

local muzzleWords = {"muzzle","muzzlepoint","muzzleflash","firepoint","fire_point","fire","barrelend","barrel_end","tip","shootpoint","shoot_point","shotorigin","shot_origin","projectileorigin","projectile_origin"}

local function explicitMuzzle(root)
    if not root then return nil end
    local cam = camera()
    local bestPos, bestScore
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Attachment") or obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local matched = false
            for _, word in ipairs(muzzleWords) do
                if n == word or n:find(word,1,true) then matched=true break end
            end
            if matched then
                local pos = obj:IsA("Attachment") and obj.WorldPosition or obj.Position
                local score = cam and (pos-cam.CFrame.Position):Dot(cam.CFrame.LookVector) or 0
                if not bestScore or score > bestScore then bestPos,bestScore=pos,score end
            end
        end
    end
    return bestPos
end

local function estimatedMuzzle(root)
    local cam = camera()
    if not root or not cam then return nil end
    local bestPos, bestScore
    for _, part in ipairs(root:GetDescendants()) do
        if part:IsA("BasePart") and effectivelyVisible(part) and not containsWord(part.Name, armWords) and not parentArmish(part) then
            local center, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen and center.Z > 0 then
                local half = part.Size / 2
                for x=-1,1,2 do
                    for y=-1,1,2 do
                        for z=-1,1,2 do
                            local world = (part.CFrame * CFrame.new(half * Vector3.new(x,y,z))).Position
                            local score = (world-cam.CFrame.Position):Dot(cam.CFrame.LookVector)
                            if not bestScore or score > bestScore then bestPos,bestScore=world,score end
                        end
                    end
                end
            end
        end
    end
    return bestPos
end

local function localMuzzle()
    local tool = equippedTool()
    local pos = explicitMuzzle(tool)
    if pos then return pos end
    local roots = cameraWeaponRoots()
    for _, root in ipairs(roots) do
        pos = explicitMuzzle(root)
        if pos then return pos end
    end
    local best, bestScore
    if tool then
        local p = estimatedMuzzle(tool)
        if p then best=p bestScore=(p-camera().CFrame.Position):Dot(camera().CFrame.LookVector) end
    end
    for _, root in ipairs(roots) do
        local p = estimatedMuzzle(root)
        if p then
            local score=(p-camera().CFrame.Position):Dot(camera().CFrame.LookVector)
            if not bestScore or score>bestScore then best,bestScore=p,score end
        end
    end
    return best
end

local function localWeaponPresent()
    return equippedTool() ~= nil or #cameraWeaponRoots() > 0
end

local function rayDestination(origin)
    local cam = camera()
    if not cam then return nil end
    local vp = cam.ViewportSize
    local ray = cam:ViewportPointToRay(vp.X/2,vp.Y/2)
    local direction = ray.Direction.Unit * tracerRange
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character,cam}
    params.IgnoreWater = false
    local result = Workspace:Raycast(origin,direction,params)
    return result and result.Position or origin+direction
end

local function trimPool()
    for i=#activeTraces,1,-1 do if not activeTraces[i] or not activeTraces[i].Parent then table.remove(activeTraces,i) end end
    while #activeTraces>=tracerMaxActive do
        local oldest=table.remove(activeTraces,1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

local function createTracer(origin,finish)
    if not origin or not finish then return end
    local delta=finish-origin
    if delta.Magnitude<0.05 then return end
    trimPool()
    local line=Instance.new("Part")
    line.Name="YokaiMuzzleBulletTracer"
    line.Anchored=true line.CanCollide=false line.CanTouch=false line.CanQuery=false line.CastShadow=false
    line.Material=tracerMaterials[tracerMaterial] or Enum.Material.Neon
    line.Color=tracerColor line.Transparency=.02
    line.Size=Vector3.new(tracerThickness,tracerThickness,delta.Magnitude)
    line.CFrame=CFrame.lookAt((origin+finish)/2,finish)
    line.Parent=Workspace
    table.insert(activeTraces,line)
    task.delay(tracerLifetime,function() if line and line.Parent then line:Destroy() end end)
end

local function onLocalShot()
    if not tracerEnabled or guiOpen() or not localWeaponPresent() then return end
    local now=os.clock()
    if now-lastEmitAt<.025 then return end
    lastEmitAt=now
    local origin=localMuzzle()
    -- Never fall back to the camera/center of screen. If no muzzle can be found,
    -- skip this shot instead of drawing from the wrong place.
    if not origin then return end
    recentMuzzle=origin
    suppressUntil=now+.18
    createTracer(origin,rayDestination(origin))
end

local function connectTool(tool)
    if not tool:IsA("Tool") or toolConnections[tool] then return end
    toolConnections[tool]=tool.Activated:Connect(onLocalShot)
end

local function scanTools()
    local char=LocalPlayer.Character
    local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
    if char then for _,obj in ipairs(char:GetChildren()) do connectTool(obj) end end
    if backpack then for _,obj in ipairs(backpack:GetChildren()) do connectTool(obj) end end
end
scanTools()
LocalPlayer.CharacterAdded:Connect(function(char) char.ChildAdded:Connect(connectTool) task.defer(scanTools) end)
local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
if backpack then backpack.ChildAdded:Connect(connectTool) end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 and not guiOpen() and localWeaponPresent() then
        triggerHeld=true nextTrace=0 onLocalShot()
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then triggerHeld=false end end)
RunService.Heartbeat:Connect(function()
    if not tracerEnabled or not triggerHeld or guiOpen() or not localWeaponPresent() then return end
    local now=os.clock()
    if now>=nextTrace then nextTrace=now+(1/math.max(1,tracerRate)) onLocalShot() end
end)

local function nearMuzzle(pos,radius)
    return recentMuzzle and (pos-recentMuzzle).Magnitude<=radius
end
local function nativeTracerLike(obj)
    local n=obj.Name:lower()
    return n:find("tracer",1,true) or n:find("bullet",1,true) or n:find("projectile",1,true) or n:find("beam",1,true) or n:find("streak",1,true) or n:find("laser",1,true)
end
local function nativeNearMuzzle(obj)
    if obj:IsA("Beam") or obj:IsA("Trail") then
        local a0,a1=obj.Attachment0,obj.Attachment1
        return (a0 and nearMuzzle(a0.WorldPosition,20)) or (a1 and nearMuzzle(a1.WorldPosition,20))
    elseif obj:IsA("BasePart") then
        return nearMuzzle(obj.Position,25)
    end
    return false
end
local function hideNative(obj)
    if not tracerEnabled or os.clock()>suppressUntil or obj.Name=="YokaiMuzzleBulletTracer" then return end
    if not (obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("BasePart")) then return end
    if not nativeNearMuzzle(obj) then return end
    local cam=camera() local tool=equippedTool()
    local localDesc=(cam and obj:IsDescendantOf(cam)) or (tool and obj:IsDescendantOf(tool))
    if not localDesc and not nativeTracerLike(obj) then return end
    if obj:IsA("Beam") or obj:IsA("Trail") then
        if hiddenNative[obj]==nil then hiddenNative[obj]=obj.Enabled end
        obj.Enabled=false
    else
        if hiddenNative[obj]==nil then hiddenNative[obj]=obj.LocalTransparencyModifier end
        obj.LocalTransparencyModifier=1
    end
end
Workspace.DescendantAdded:Connect(function(obj) if tracerEnabled and os.clock()<=suppressUntil then task.defer(hideNative,obj) end end)
local function restoreNative()
    for obj,state in pairs(hiddenNative) do
        if obj and obj.Parent then pcall(function()
            if obj:IsA("Beam") or obj:IsA("Trail") then obj.Enabled=state else obj.LocalTransparencyModifier=state end
        end) end
        hiddenNative[obj]=nil
    end
end

local BulletTracer=World.CreateOptionsButton({["Name"]="BulletTracer",["Function"]=function(v)
    tracerEnabled=v
    if not v then
        triggerHeld=false restoreNative()
        for _,line in ipairs(activeTraces) do if line and line.Parent then line:Destroy() end end
        table.clear(activeTraces)
    end
end})
BulletTracer.CreateDropdown({["Name"]="Material",["List"]={"Neon","ForceField","Glass","Metal","SmoothPlastic"},["Function"]=function(v) tracerMaterial=v end})
BulletTracer.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({["Name"]="Lifetime",["Min"]=1,["Max"]=15,["Default"]=4,["Function"]=function(v) tracerLifetime=v/10 end})
BulletTracer.CreateSlider({["Name"]="Thickness",["Min"]=2,["Max"]=15,["Default"]=5,["Function"]=function(v) tracerThickness=v/100 end})
BulletTracer.CreateSlider({["Name"]="Fire Rate",["Min"]=1,["Max"]=20,["Default"]=10,["Function"]=function(v) tracerRate=v end})
BulletTracer.CreateSlider({["Name"]="Range",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) tracerRange=v end})

-- ============================================================================
-- HITSOUND: requested custom sound + local native-hit-sound muting + preview.
-- ============================================================================
removeNormalizedOption("HitSound")
removeNormalizedOption("HitSoundPreview")

local hitSoundEnabled=false
local muteNative=true
local hitVolume=1
local hitPreset="Custom 91546829095879"
local hitSounds={
    ["Custom 91546829095879"]="rbxassetid://91546829095879",
    ["Classic"]="rbxassetid://9118823106",
    ["Preset 1"]="rbxassetid://136087587949971",
    ["Preset 2"]="rbxassetid://118077944456512",
}
local mutedSounds=setmetatable({}, {__mode="k"})

local function looksLikeNativeHitSound(sound)
    if not sound:IsA("Sound") or sound.Name=="YokaiCustomHitSound" then return false end
    local n=sound.Name:lower()
    return n:find("hitmarker",1,true) or n:find("hitsound",1,true) or n:find("hit_sound",1,true)
        or n:find("confirmhit",1,true) or n:find("confirm_hit",1,true) or n=="hit"
end

local function muteOne(sound)
    if not hitSoundEnabled or not muteNative or not looksLikeNativeHitSound(sound) then return end
    if mutedSounds[sound]==nil then mutedSounds[sound]=sound.Volume end
    sound.Volume=0
end

local function scanNativeHitSounds()
    local roots={SoundService,LocalPlayer:FindFirstChild("PlayerGui"),Workspace}
    for _,root in ipairs(roots) do
        if root then for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then muteOne(obj) end end end
    end
end

local function restoreNativeHitSounds()
    for sound,volume in pairs(mutedSounds) do
        if sound and sound.Parent then pcall(function() sound.Volume=volume end) end
        mutedSounds[sound]=nil
    end
end

for _,root in ipairs({SoundService,Workspace}) do
    root.DescendantAdded:Connect(function(obj) if obj:IsA("Sound") then task.defer(muteOne,obj) end end)
end
local pg=LocalPlayer:FindFirstChild("PlayerGui")
if pg then pg.DescendantAdded:Connect(function(obj) if obj:IsA("Sound") then task.defer(muteOne,obj) end end) end

local function playCustomHitSound()
    local sound=Instance.new("Sound")
    sound.Name="YokaiCustomHitSound"
    sound.SoundId=hitSounds[hitPreset] or hitSounds["Custom 91546829095879"]
    sound.Volume=hitVolume
    sound.Parent=SoundService
    sound:Play()
    Debris:AddItem(sound,5)
end

local HitSound=World.CreateOptionsButton({["Name"]="HitSound",["Function"]=function(v)
    hitSoundEnabled=v
    if v then scanNativeHitSounds() else restoreNativeHitSounds() end
end})
HitSound.CreateDropdown({["Name"]="Sound",["List"]={"Custom 91546829095879","Classic","Preset 1","Preset 2"},["Function"]=function(v) hitPreset=v end})
HitSound.CreateSlider({["Name"]="Volume",["Min"]=1,["Max"]=10,["Default"]=5,["Function"]=function(v) hitVolume=v/5 end})
HitSound.CreateToggle({["Name"]="Mute Game HitSound",["Default"]=true,["Function"]=function(v)
    muteNative=v
    if hitSoundEnabled then if v then scanNativeHitSounds() else restoreNativeHitSounds() end end
end})

local HitSoundPreview
HitSoundPreview=World.CreateOptionsButton({["Name"]="HitSoundPreview",["Function"]=function(v)
    if not v then return end
    playCustomHitSound()
    task.defer(function() pcall(function() HitSoundPreview.ToggleButton(false) end) end)
end})

-- Damage-triggered playback is kept to Studio dummies only.
local studioHumanoids=setmetatable({}, {__mode="k"})
local function watchDummy(model)
    if not RunService:IsStudio() or not model:IsA("Model") or Players:GetPlayerFromCharacter(model) then return end
    local hum=model:FindFirstChildOfClass("Humanoid")
    if not hum or studioHumanoids[hum] then return end
    local last=hum.Health
    studioHumanoids[hum]=hum.HealthChanged:Connect(function(value)
        if hitSoundEnabled and value<last then playCustomHitSound() end
        last=value
    end)
end
if RunService:IsStudio() then
    for _,obj in ipairs(Workspace:GetDescendants()) do watchDummy(obj) end
    Workspace.DescendantAdded:Connect(function(obj) if obj:IsA("Humanoid") and obj.Parent then task.defer(watchDummy,obj.Parent) end end)
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai","Cosmetic runtime fixes loaded",3)
end)
