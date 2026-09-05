-- Final isolated local visual fixes requested by the repository owner.
-- Only replaces: SelfChams, ChangeSkydome and BulletTracer.
-- Does not add player-targeting logic and does not remove unrelated modules.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local WorldRec = objects["WorldWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local World = WorldRec and WorldRec["Api"]
local ZWSP = utf8.char(0x200B)

if not Visuals or not World then
    warn("FinalLocalVisualFixes: Visuals/World window missing")
    return
end

local function removeOptionKey(key)
    local rec = objects[key]
    if not rec then return end
    pcall(function()
        local api = rec["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
    end)
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end

local function removeNamed(name)
    removeOptionKey(name .. "OptionsButton")
    removeOptionKey(name .. ZWSP .. "OptionsButton")
end

-- ============================================================================
-- SELFCHAMS: preserve the game's natural first-person visibility.
-- ============================================================================
removeNamed("SelfChams")
pcall(function() RunService:UnbindFromRenderStep("YokaiArmMaterialFix") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiLocalSelfChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiFinalSelfChams") end)

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

local selfEnabled = false
local selfMaterial = "ForceField"
local selfColor = Color3.fromRGB(119,120,255)
local partState = setmetatable({}, {__mode="k"})
local decalState = setmetatable({}, {__mode="k"})
local meshState = setmetatable({}, {__mode="k"})
local surfaceState = setmetatable({}, {__mode="k"})

local function camera()
    return Workspace.CurrentCamera
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = camera()
    return head and cam and (cam.CFrame.Position - head.Position).Magnitude <= 1.45 or false
end

local function armish(name)
    local n = tostring(name):lower()
    return n:find("arm",1,true) ~= nil
        or n:find("hand",1,true) ~= nil
        or n:find("forearm",1,true) ~= nil
        or n:find("glove",1,true) ~= nil
        or n:find("sleeve",1,true) ~= nil
end

local function weaponish(name)
    local n = tostring(name):lower()
    local words = {"gun","weapon","barrel","muzzle","magazine","mag","scope","sight","bolt","ammo","bullet","receiver","stock","grip","slide","trigger"}
    for _, word in ipairs(words) do if n:find(word,1,true) then return true end end
    return false
end

local function effectivelyVisible(part)
    return part.Transparency < 0.95 and part.LocalTransparencyModifier < 0.95
end

local function ancestorWeaponish(part)
    local cam = camera()
    local cur = part.Parent
    while cur and cur ~= cam do
        if weaponish(cur.Name) or cur:IsA("Tool") then return true end
        cur = cur.Parent
    end
    return false
end

local function isCameraArm(part)
    local cam = camera()
    if not cam or not part:IsDescendantOf(cam) or not effectivelyVisible(part) then return false end
    if weaponish(part.Name) or ancestorWeaponish(part) then return false end
    -- Strict on purpose: do not style generic hidden viewmodel shell/body meshes.
    return armish(part.Name)
end

local function isVisibleCharacterArm(part)
    local char = LocalPlayer.Character
    if not char or not part:IsDescendantOf(char) then return false end
    if part:FindFirstAncestorWhichIsA("Tool") then return false end
    return armish(part.Name) and effectivelyVisible(part)
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
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function hideArmTextures(part)
    for _, obj in ipairs(part:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if decalState[obj] == nil then decalState[obj] = obj.Transparency end
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

local function restoreLayersFor(part)
    for obj, value in pairs(decalState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.Transparency = value end)
            decalState[obj] = nil
        end
    end
    for obj, value in pairs(meshState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.TextureId = value end)
            meshState[obj] = nil
        end
    end
    for obj, parent in pairs(surfaceState) do
        if obj and parent then
            pcall(function() obj.Parent = parent end)
            surfaceState[obj] = nil
        end
    end
end

local function styleArm(part)
    rememberPart(part)
    part.Material = materialMap[selfMaterial] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = selfColor
    part.CastShadow = false
    -- IMPORTANT: never modify Transparency or LocalTransparencyModifier here.
    -- That preserves exactly the first-person visibility the game already uses.
    if part:IsA("MeshPart") then part.TextureID = "" end
    hideArmTextures(part)
end

local function restorePart(part, forget)
    local state = partState[part]
    if not state or not part or not part.Parent then return end
    pcall(function()
        part.Material = state.Material
        if state.MaterialVariant ~= nil then part.MaterialVariant = state.MaterialVariant end
        part.Color = state.Color
        part.CastShadow = state.CastShadow
        if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
    end)
    restoreLayersFor(part)
    if forget then partState[part] = nil end
end

local function restoreSelf()
    for part in pairs(partState) do restorePart(part, true) end
    for obj, value in pairs(decalState) do if obj and obj.Parent then pcall(function() obj.Transparency=value end) end decalState[obj]=nil end
    for obj, value in pairs(meshState) do if obj and obj.Parent then pcall(function() obj.TextureId=value end) end meshState[obj]=nil end
    for obj, parent in pairs(surfaceState) do if obj and parent then pcall(function() obj.Parent=parent end) end surfaceState[obj]=nil end
end

local function applySelf()
    if not selfEnabled then return end
    local fp = isFirstPerson()
    local wanted = {}
    local char = LocalPlayer.Character
    local cam = camera()

    if fp then
        -- Prefer the actual camera viewmodel arms. Never force hidden body parts visible.
        if cam then
            for _, obj in ipairs(cam:GetDescendants()) do
                if obj:IsA("BasePart") and isCameraArm(obj) then wanted[obj] = true end
            end
        end
        -- Fallback for FPS games that render the character arms directly.
        if next(wanted) == nil and char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") and isVisibleCharacterArm(obj) then wanted[obj] = true end
            end
        end
    elseif char then
        -- Third person: style only body parts the game already renders.
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and not obj:FindFirstAncestorWhichIsA("Tool") and effectivelyVisible(obj) then
                wanted[obj] = true
            end
        end
    end

    for part in pairs(partState) do
        if not wanted[part] then restorePart(part, true) end
    end
    for part in pairs(wanted) do styleArm(part) end
end

local SelfChams = Visuals.CreateOptionsButton({
    ["Name"] = "SelfChams",
    ["Function"] = function(v)
        selfEnabled = v
        if v then applySelf() else restoreSelf() end
    end,
})
SelfChams.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = materialList,
    ["Function"] = function(v) selfMaterial=v if selfEnabled then applySelf() end end,
})
SelfChams.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) selfColor=Color3.fromHSV(h,s,v) if selfEnabled then applySelf() end end,
})

RunService:BindToRenderStep("YokaiFinalSelfChams", Enum.RenderPriority.Camera.Value + 130, function()
    if selfEnabled then applySelf() end
end)
LocalPlayer.CharacterAdded:Connect(function()
    restoreSelf()
    task.wait(.45)
    if selfEnabled then applySelf() end
end)

-- ============================================================================
-- SKY PRESETS: restore the complete previous list + Default.
-- ============================================================================
removeNamed("ChangeSkydome")

local savedSkies = {}
for _, child in ipairs(Lighting:GetChildren()) do
    if child:IsA("Sky") then table.insert(savedSkies, child:Clone()) end
end

local skyPresets = {
    ["Purple Nebula"] = {"159454299","159454296","159454293","159454286","159454300","159454288"},
    ["Blue Daylight"] = {"271042516","271077243","271042556","271042310","271042467","271077958"},
    ["Night Sky"] = {"12064107","12064152","12064121","12063984","12064115","12064131"},
    ["Purple Space"] = {"14543264135","14543358958","14543257810","14543275895","14543280890","14543371676"},
    ["Deep Night"] = {"15470149279","15470151245","15470153860","15470155938","15470158022","15470160563"},
    ["Starry Edge"] = {"2570432999","2570433005","2570432998","2570433000","2570432997","2570432996"},
    ["Vaporwave"] = {"8631780182","8631784904","8631769834","8631777199","8631735555","8631782345"},
}
local skyEnabled = false
local skyPreset = "Night Sky"

local function clearSkies()
    for _, child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end
end

local function restoreSkies()
    clearSkies()
    for _, sky in ipairs(savedSkies) do sky:Clone().Parent = Lighting end
end

local function applySky(name)
    if not skyEnabled or name == "Default" then restoreSkies() return end
    local ids = skyPresets[name]
    if not ids then return end
    clearSkies()
    local sky = Instance.new("Sky")
    sky.Name = "YokaiVisualSky"
    sky.SkyboxBk = "rbxassetid://" .. ids[1]
    sky.SkyboxDn = "rbxassetid://" .. ids[2]
    sky.SkyboxFt = "rbxassetid://" .. ids[3]
    sky.SkyboxLf = "rbxassetid://" .. ids[4]
    sky.SkyboxRt = "rbxassetid://" .. ids[5]
    sky.SkyboxUp = "rbxassetid://" .. ids[6]
    sky.Parent = Lighting
end

local ChangeSkydome = World.CreateOptionsButton({
    ["Name"] = "ChangeSkydome",
    ["Function"] = function(v)
        skyEnabled = v
        applySky(skyPreset)
    end,
})
ChangeSkydome.CreateDropdown({
    ["Name"] = "Preset",
    ["List"] = {"Night Sky","Deep Night","Purple Space","Starry Edge","Purple Nebula","Vaporwave","Blue Daylight","Default"},
    ["Function"] = function(v)
        skyPreset = v
        if skyEnabled then applySky(v) end
    end,
})

-- ============================================================================
-- BULLET TRACER: local shot only + locally suppress native tracer for that shot.
-- ============================================================================
removeNamed("BulletTracer")

local tracerEnabled = false
local tracerColor = Color3.fromRGB(255,255,255)
local tracerMaterial = "Neon"
local tracerLifetime = .35
local tracerThickness = .045
local tracerRange = 1800
local tracerRate = 10
local tracerMaxActive = 16
local triggerHeld = false
local nextTrace = 0
local lastEmitAt = 0
local suppressUntil = 0
local recentMuzzle = nil
local activeTraces = {}
local hiddenNative = setmetatable({}, {__mode="k"})
local toolConnections = setmetatable({}, {__mode="k"})

local tracerMaterials = {
    Neon=Enum.Material.Neon,
    ForceField=Enum.Material.ForceField,
    Glass=Enum.Material.Glass,
    Metal=Enum.Material.Metal,
    SmoothPlastic=Enum.Material.SmoothPlastic,
}

local function guiOpen()
    local opened = false
    pcall(function()
        local main = GuiLibrary["MainGui"]
        local click = main and main:FindFirstChild("ClickGui", true)
        opened = click and click.Visible or false
    end)
    return opened
end

local function equippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool") or nil
end

local function cameraWeaponModel()
    local cam = camera()
    if not cam then return nil end
    for _, obj in ipairs(cam:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Tool") then
            local n = obj.Name:lower()
            if n:find("view",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) or n:find("arms",1,true) then return obj end
        end
    end
    return nil
end

local function findMuzzle(root)
    if not root then return nil end
    local preferred = {"muzzle","firepoint","fire_point","barrel","tip","shootpoint","shoot_point"}
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
    return handle and handle:IsA("BasePart") and handle.Position or nil
end

local function localMuzzle()
    return findMuzzle(equippedTool()) or findMuzzle(cameraWeaponModel()) or (camera() and camera().CFrame.Position) or Vector3.zero
end

local function localWeaponPresent()
    return equippedTool() ~= nil or cameraWeaponModel() ~= nil
end

local function rayDestination(origin)
    local cam = camera()
    if not cam then return origin end
    local vp = cam.ViewportSize
    local ray = cam:ViewportPointToRay(vp.X/2, vp.Y/2)
    local direction = ray.Direction.Unit * tracerRange
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, cam}
    params.IgnoreWater = false
    local result = Workspace:Raycast(origin, direction, params)
    return result and result.Position or origin + direction
end

local function cleanupActive()
    for i=#activeTraces,1,-1 do
        if not activeTraces[i] or not activeTraces[i].Parent then table.remove(activeTraces,i) end
    end
    while #activeTraces >= tracerMaxActive do
        local oldest = table.remove(activeTraces,1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

local function createTracer(origin, finish)
    local delta = finish-origin
    local length = delta.Magnitude
    if length < .05 then return end
    cleanupActive()
    local line = Instance.new("Part")
    line.Name = "YokaiLocalBulletTracerV5"
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.CanQuery = false
    line.CastShadow = false
    line.Material = tracerMaterials[tracerMaterial] or Enum.Material.Neon
    line.Color = tracerColor
    line.Transparency = .02
    line.Size = Vector3.new(tracerThickness,tracerThickness,length)
    line.CFrame = CFrame.lookAt((origin+finish)/2, finish)
    line.Parent = Workspace
    table.insert(activeTraces,line)
    task.delay(tracerLifetime,function()
        if line and line.Parent then line:Destroy() end
    end)
end

local function onLocalShot()
    if not tracerEnabled or guiOpen() or not localWeaponPresent() then return end
    local now = os.clock()
    if now-lastEmitAt < .025 then return end
    lastEmitAt = now
    local origin = localMuzzle()
    recentMuzzle = origin
    suppressUntil = now + .20
    createTracer(origin, rayDestination(origin))
end

local function connectTool(tool)
    if not tool:IsA("Tool") or toolConnections[tool] then return end
    toolConnections[tool] = tool.Activated:Connect(onLocalShot)
end

local function scanTools()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if char then for _, obj in ipairs(char:GetChildren()) do connectTool(obj) end end
    if backpack then for _, obj in ipairs(backpack:GetChildren()) do connectTool(obj) end end
end
scanTools()
LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(connectTool)
    task.defer(scanTools)
end)
local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
if backpack then backpack.ChildAdded:Connect(connectTool) end

-- Some FPS scripts consume MouseButton1 before UserInputService reports it as unprocessed.
-- We intentionally do not reject processed clicks while a local weapon is equipped.
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not guiOpen() and localWeaponPresent() then
        triggerHeld = true
        nextTrace = 0
        onLocalShot()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerHeld=false end
end)

RunService.Heartbeat:Connect(function()
    if not tracerEnabled or not triggerHeld or guiOpen() or not localWeaponPresent() then return end
    local now = os.clock()
    if now >= nextTrace then
        nextTrace = now + (1/math.max(1,tracerRate))
        onLocalShot()
    end
end)

local function nearRecentMuzzle(pos, radius)
    return recentMuzzle and (pos-recentMuzzle).Magnitude <= radius
end

local function keywordTracer(name)
    local n=tostring(name):lower()
    local words={"tracer","bullet","projectile","beam","streak","shot","laser"}
    for _,w in ipairs(words) do if n:find(w,1,true) then return true end end
    return false
end

local function endpointNearMuzzle(obj)
    if obj:IsA("Beam") then
        local a0,a1=obj.Attachment0,obj.Attachment1
        return (a0 and nearRecentMuzzle(a0.WorldPosition,20)) or (a1 and nearRecentMuzzle(a1.WorldPosition,20))
    elseif obj:IsA("Trail") then
        local a0,a1=obj.Attachment0,obj.Attachment1
        return (a0 and nearRecentMuzzle(a0.WorldPosition,20)) or (a1 and nearRecentMuzzle(a1.WorldPosition,20))
    elseif obj:IsA("BasePart") then
        return nearRecentMuzzle(obj.Position,30)
    end
    return false
end

local function hideNativeTracer(obj)
    if not tracerEnabled or os.clock()>suppressUntil or obj.Name=="YokaiLocalBulletTracerV5" then return end
    if not (obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("BasePart")) then return end
    if not endpointNearMuzzle(obj) then return end

    local localDescendant = false
    local cam = camera()
    local tool = equippedTool()
    if cam and obj:IsDescendantOf(cam) then localDescendant=true end
    if tool and obj:IsDescendantOf(tool) then localDescendant=true end
    if not localDescendant and not keywordTracer(obj.Name) then return end

    if obj:IsA("Beam") or obj:IsA("Trail") then
        if hiddenNative[obj]==nil then hiddenNative[obj]=obj.Enabled end
        obj.Enabled=false
    elseif obj:IsA("BasePart") then
        if hiddenNative[obj]==nil then hiddenNative[obj]=obj.LocalTransparencyModifier end
        obj.LocalTransparencyModifier=1
    end
end

Workspace.DescendantAdded:Connect(function(obj)
    if tracerEnabled and os.clock()<=suppressUntil then task.defer(hideNativeTracer,obj) end
end)

local function restoreNative()
    for obj,state in pairs(hiddenNative) do
        if obj and obj.Parent then
            pcall(function()
                if obj:IsA("Beam") or obj:IsA("Trail") then obj.Enabled=state
                elseif obj:IsA("BasePart") then obj.LocalTransparencyModifier=state end
            end)
        end
        hiddenNative[obj]=nil
    end
end

local BulletTracer = World.CreateOptionsButton({
    ["Name"]="BulletTracer",
    ["Function"] = function(v)
        tracerEnabled=v
        if not v then
            triggerHeld=false
            restoreNative()
            for _,line in ipairs(activeTraces) do if line and line.Parent then line:Destroy() end end
            table.clear(activeTraces)
        end
    end,
})
BulletTracer.CreateDropdown({["Name"]="Material",["List"]={"Neon","ForceField","Glass","Metal","SmoothPlastic"},["Function"]=function(v) tracerMaterial=v end})
BulletTracer.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({["Name"]="Lifetime",["Min"]=1,["Max"]=15,["Default"]=4,["Function"]=function(v) tracerLifetime=v/10 end})
BulletTracer.CreateSlider({["Name"]="Thickness",["Min"]=2,["Max"]=15,["Default"]=5,["Function"]=function(v) tracerThickness=v/100 end})
BulletTracer.CreateSlider({["Name"]="Fire Rate",["Min"]=1,["Max"]=20,["Default"]=10,["Function"]=function(v) tracerRate=v end})
BulletTracer.CreateSlider({["Name"]="Range",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) tracerRange=v end})

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Final local visual fixes loaded",3) end)
