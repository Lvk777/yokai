-- Yokai Visuals V3
-- Keeps the original Render window untouched.
-- Self/local visual effects work normally.
-- Target-oriented visual testing is intentionally restricted to Roblox Studio
-- and only operates on non-player Humanoid dummy/NPC models.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local STUDIO = RunService:IsStudio()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local function notify(title, text)
    pcall(function() GuiLibrary["CreateNotification"](title, text, 4) end)
end

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------
local function setOptionLabel(internalName, label)
    task.defer(function()
        local rec = objects[internalName .. "OptionsButton"]
        local obj = rec and rec["Object"]
        if not obj or typeof(obj) ~= "Instance" then return end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then obj.Text = label end
        local text = obj:FindFirstChild("ButtonText", true)
        if text and (text:IsA("TextLabel") or text:IsA("TextButton")) then text.Text = label end
    end)
end

local function newLine(parent, color, thickness)
    local frame = Instance.new("Frame")
    frame.BorderSizePixel = 0
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = color or Color3.new(1,1,1)
    frame.Size = UDim2.fromOffset(0, thickness or 1)
    frame.Visible = false
    frame.Parent = parent
    return frame
end

local function setLine(line, a, b, thickness, color)
    if not line or not a or not b then
        if line then line.Visible = false end
        return
    end
    local delta = b - a
    if delta.Magnitude < 0.01 then line.Visible = false return end
    line.Size = UDim2.fromOffset(delta.Magnitude, thickness or 1)
    line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    if color then line.BackgroundColor3 = color end
    line.Visible = true
end

local function newLabel(parent, size)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5,0.5)
    label.Size = size or UDim2.fromOffset(180,18)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.TextColor3 = Color3.new(1,1,1)
    label.Visible = false
    label.Parent = parent
    return label
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

-- --------------------------------------------------------------------------
-- Dedicated Visuals window with unique internal module names.
-- --------------------------------------------------------------------------
local Visuals = GuiLibrary.CreateWindow({
    ["Name"] = "Visuals",
    ["Icon"] = "yokai/assets/RenderIcon.png",
    ["IconSize"] = 17,
})
pcall(function() Visuals.SetVisible(false) end)

local visualsWindowVisible = false
local function createVisualsMainButton()
    if objects["VisualsV3Button"] and objects["VisualsV3Button"]["Object"] then return end
    local template = objects["RenderButton"] or objects["WorldButton"] or objects["UtilityButton"]
    local templateObject = template and template["Object"]
    if not templateObject then return end

    local button = templateObject:Clone()
    button.Name = "VisualsV3Button"
    button.LayoutOrder = (templateObject.LayoutOrder or 0) + 1
    local function relabel(root)
        if root:IsA("TextLabel") or root:IsA("TextButton") then
            if root.Text == "Render" then root.Text = "Visuals" end
        end
        for _, child in ipairs(root:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                if child.Text == "Render" then child.Text = "Visuals" end
            end
        end
    end
    relabel(button)
    button.Parent = templateObject.Parent

    local api = {Enabled = false}
    api.ToggleButton = function(state)
        if state == nil then state = not visualsWindowVisible end
        visualsWindowVisible = state
        api.Enabled = state
        pcall(function() Visuals.SetVisible(state) end)
    end
    button.MouseButton1Click:Connect(function() api.ToggleButton(not visualsWindowVisible) end)
    objects["VisualsV3Button"] = {Type="ButtonMain", Object=button, Api=api}
end
task.defer(createVisualsMainButton)

local function makeVisualOption(internalName, visibleName, fn)
    local api = Visuals.CreateOptionsButton({
        ["Name"] = internalName,
        ["Function"] = fn,
    })
    setOptionLabel(internalName, visibleName)
    return api
end

-- --------------------------------------------------------------------------
-- Original Breadcrumbs -> Trail. No behavior is replaced.
-- Only the visible name changes and Glow is added via Trail.LightEmission.
-- --------------------------------------------------------------------------
local trailGlowEnabled = false
local trailGlowState = setmetatable({}, {__mode="k"})

local function isLocalBreadcrumbTrail(obj)
    if not obj:IsA("Trail") then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local a0, a1 = obj.Attachment0, obj.Attachment1
    return (a0 and a0:IsDescendantOf(char)) or (a1 and a1:IsDescendantOf(char))
end

local function applyTrailGlow()
    local containers = {Workspace, Workspace.CurrentCamera}
    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if isLocalBreadcrumbTrail(obj) then
                    if not trailGlowState[obj] then
                        trailGlowState[obj] = {LightEmission=obj.LightEmission, LightInfluence=obj.LightInfluence}
                    end
                    if trailGlowEnabled then
                        obj.LightEmission = 1
                        obj.LightInfluence = 0
                    else
                        local old = trailGlowState[obj]
                        obj.LightEmission = old.LightEmission
                        obj.LightInfluence = old.LightInfluence
                    end
                end
            end
        end
    end
    if not trailGlowEnabled then table.clear(trailGlowState) end
end

local breadcrumbsRecord = objects["BreadcrumbsOptionsButton"]
if breadcrumbsRecord and breadcrumbsRecord["Api"] then
    local obj = breadcrumbsRecord["Object"]
    if obj and typeof(obj) == "Instance" then
        local text = obj:FindFirstChild("ButtonText", true)
        if text and (text:IsA("TextLabel") or text:IsA("TextButton")) then text.Text = "Trail" end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            if obj.Text == "Breadcrumbs" then obj.Text = "Trail" end
        end
    end
    pcall(function()
        breadcrumbsRecord["Api"].CreateToggle({
            ["Name"] = "Glow",
            ["Default"] = false,
            ["Function"] = function(v)
                trailGlowEnabled = v
                applyTrailGlow()
            end,
        })
    end)
end

local trailGlowAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
    if not trailGlowEnabled then return end
    trailGlowAccumulator += dt
    if trailGlowAccumulator >= 0.25 then
        trailGlowAccumulator = 0
        applyTrailGlow()
    end
end)

-- --------------------------------------------------------------------------
-- SelfChams: robust ForceField including Head/face texture handling.
-- --------------------------------------------------------------------------
local selfChamsEnabled = false
local selfChamsMaterial = "ForceField"
local selfChamsColor = Color3.fromRGB(255,110,190)
local selfChamsTransparency = 0.15
local selfPartState = setmetatable({}, {__mode="k"})
local selfTextureState = setmetatable({}, {__mode="k"})

local function rememberSelfPart(part)
    if selfPartState[part] then return end
    selfPartState[part] = {
        Material = part.Material,
        Color = part.Color,
        Transparency = part.Transparency,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
        CastShadow = part.CastShadow,
    }
end

local function rememberTexture(obj)
    if selfTextureState[obj] then return end
    if obj:IsA("Decal") or obj:IsA("Texture") then
        selfTextureState[obj] = {Transparency=obj.Transparency}
    end
end

local function applySelfChams()
    local char = LocalPlayer.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and not obj:FindFirstAncestorWhichIsA("Tool") then
            rememberSelfPart(obj)
            obj.Material = materialMap[selfChamsMaterial] or Enum.Material.ForceField
            obj.Color = selfChamsColor
            obj.Transparency = selfChamsTransparency
            obj.LocalTransparencyModifier = 0
            obj.CastShadow = false
            if obj:IsA("MeshPart") then obj.TextureID = "" end
        elseif (obj:IsA("Decal") or obj:IsA("Texture")) and not obj:FindFirstAncestorWhichIsA("Tool") then
            rememberTexture(obj)
            obj.Transparency = 1
        end
    end

    -- Head gets explicitly reapplied because avatar/animate scripts can rewrite it.
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        rememberSelfPart(head)
        head.Material = materialMap[selfChamsMaterial] or Enum.Material.ForceField
        head.Color = selfChamsColor
        head.Transparency = selfChamsTransparency
        head.LocalTransparencyModifier = 0
        if head:IsA("MeshPart") then head.TextureID = "" end
        for _, d in ipairs(head:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then rememberTexture(d) d.Transparency = 1 end
        end
    end
end

local function restoreSelfChams()
    for part, state in pairs(selfPartState) do
        if part and part.Parent then
            pcall(function()
                part.Material = state.Material
                part.Color = state.Color
                part.Transparency = state.Transparency
                part.LocalTransparencyModifier = state.LocalTransparencyModifier
                part.CastShadow = state.CastShadow
                if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
            end)
        end
    end
    for obj, state in pairs(selfTextureState) do
        if obj and obj.Parent then pcall(function() obj.Transparency = state.Transparency end) end
    end
    table.clear(selfPartState)
    table.clear(selfTextureState)
end

-- Self aura / rotating reticle.
local auraEnabled = false
local reticleEnabled = false
local auraColor = Color3.fromRGB(119,120,255)
local auraSpinSpeed = 90
local selfAuraGui
local selfAuraRing
local selfReticle
local reticleParts = {}

local function destroySelfAura()
    if selfAuraGui then selfAuraGui:Destroy() selfAuraGui = nil end
    selfAuraRing = nil
    selfReticle = nil
    table.clear(reticleParts)
end

local function ensureSelfAura()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if selfAuraGui and selfAuraGui.Parent and selfAuraGui.Adornee == root then return end
    destroySelfAura()

    local gui = Instance.new("BillboardGui")
    gui.Name = "YokaiSelfAura"
    gui.Adornee = root
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Size = UDim2.fromOffset(120,120)
    gui.StudsOffsetWorldSpace = Vector3.new(0,2.7,0)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5,0.5)
    ring.Position = UDim2.fromScale(0.5,0.5)
    ring.Size = UDim2.fromOffset(76,76)
    ring.BackgroundTransparency = 1
    ring.Parent = gui
    local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(1,0) rc.Parent = ring
    local rs = Instance.new("UIStroke") rs.Name = "GlowStroke" rs.Thickness = 2 rs.Transparency = 0.08 rs.Color = auraColor rs.Parent = ring

    local reticle = Instance.new("Frame")
    reticle.AnchorPoint = Vector2.new(0.5,0.5)
    reticle.Position = UDim2.fromScale(0.5,0.5)
    reticle.Size = UDim2.fromOffset(100,100)
    reticle.BackgroundTransparency = 1
    reticle.Parent = gui

    local specs = {
        {UDim2.new(0.5,0,0,8), UDim2.fromOffset(3,20)},
        {UDim2.new(0.5,0,1,-8), UDim2.fromOffset(3,20)},
        {UDim2.new(0,8,0.5,0), UDim2.fromOffset(20,3)},
        {UDim2.new(1,-8,0.5,0), UDim2.fromOffset(20,3)},
    }
    for _, spec in ipairs(specs) do
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5,0.5)
        f.Position = spec[1]
        f.Size = spec[2]
        f.BorderSizePixel = 0
        f.BackgroundColor3 = auraColor
        f.Parent = reticle
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1,0) c.Parent = f
        table.insert(reticleParts, f)
    end

    selfAuraGui = gui
    selfAuraRing = ring
    selfReticle = reticle
end

local SelfChams = makeVisualOption("V3SelfChams", "SelfChams", function(v)
    selfChamsEnabled = v
    if v then applySelfChams() else restoreSelfChams() end
end)
SelfChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) selfChamsMaterial=v if selfChamsEnabled then applySelfChams() end end})
SelfChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) selfChamsColor=Color3.fromHSV(h,s,v) if selfChamsEnabled then applySelfChams() end end})
SelfChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=90,["Default"]=15,["Function"]=function(v) selfChamsTransparency=v/100 if selfChamsEnabled then applySelfChams() end end})
SelfChams.CreateToggle({["Name"]="Aura",["Default"]=false,["Function"]=function(v) auraEnabled=v if v then ensureSelfAura() end end})
SelfChams.CreateToggle({["Name"]="Rotating Reticle",["Default"]=false,["Function"]=function(v) reticleEnabled=v if v then ensureSelfAura() end end})
SelfChams.CreateColorSlider({["Name"]="Aura Color",["Function"]=function(h,s,v) auraColor=Color3.fromHSV(h,s,v) end})
SelfChams.CreateSlider({["Name"]="Spin Speed",["Min"]=10,["Max"]=360,["Default"]=90,["Function"]=function(v) auraSpinSpeed=v end})

local selfReapply = 0
RunService.Heartbeat:Connect(function(dt)
    if selfChamsEnabled then
        selfReapply += dt
        if selfReapply >= 0.25 then selfReapply=0 applySelfChams() end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    restoreSelfChams()
    destroySelfAura()
    task.wait(0.5)
    if selfChamsEnabled then applySelfChams() end
    if auraEnabled or reticleEnabled then ensureSelfAura() end
end)

-- --------------------------------------------------------------------------
-- GunChams: only the local player's equipped Tool / local camera viewmodel.
-- Visible and occluded colors are independently configurable.
-- --------------------------------------------------------------------------
local gunEnabled = false
local gunMaterial = "ForceField"
local gunVisibleColor = Color3.fromRGB(0,255,90)
local gunOccludedColor = Color3.fromRGB(255,45,45)
local gunUseVisibility = true
local gunTransparency = 0
local gunState = setmetatable({}, {__mode="k"})
local gunTextureState = setmetatable({}, {__mode="k"})
local gunPreviewState = "Visible"

local function rememberGunPart(part)
    if gunState[part] then return end
    gunState[part] = {
        Material=part.Material,
        Color=part.Color,
        Transparency=part.Transparency,
        TextureID=part:IsA("MeshPart") and part.TextureID or nil,
        CastShadow=part.CastShadow,
    }
end

local function rememberGunTexture(obj)
    if gunTextureState[obj] then return end
    if obj:IsA("Decal") or obj:IsA("Texture") then gunTextureState[obj]={Transparency=obj.Transparency} end
end

local function cameraModelLooksLikeWeapon(part)
    if not Camera or not part:IsDescendantOf(Camera) then return false end
    local cur = part.Parent
    while cur and cur ~= Camera do
        if cur:IsA("Tool") then return true end
        if cur:IsA("Model") then
            local n = cur.Name:lower()
            if n:find("view") or n:find("weapon") or n:find("gun") or n:find("arms") then return true end
        end
        cur = cur.Parent
    end
    return false
end

local function isLocalGunPart(part)
    if not part:IsA("BasePart") then return false end
    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) and part:FindFirstAncestorWhichIsA("Tool") then return true end
    return cameraModelLooksLikeWeapon(part)
end

local function gunPartVisible(part)
    if not Camera then return true end
    if part:IsDescendantOf(Camera) then return true end
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    if direction.Magnitude < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, direction, params)
    return result == nil
end

local function collectLocalGunParts()
    local list = {}
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetDescendants()) do if isLocalGunPart(obj) then table.insert(list,obj) end end
    end
    if Camera then
        for _, obj in ipairs(Camera:GetDescendants()) do if isLocalGunPart(obj) then table.insert(list,obj) end end
    end
    return list
end

local function applyGunChams()
    if not gunEnabled then return end
    local active = {}
    for _, part in ipairs(collectLocalGunParts()) do
        active[part] = true
        rememberGunPart(part)
        local visible = (not gunUseVisibility) or gunPartVisible(part)
        part.Material = materialMap[gunMaterial] or Enum.Material.ForceField
        part.Color = visible and gunVisibleColor or gunOccludedColor
        part.Transparency = gunTransparency
        part.CastShadow = false
        if part:IsA("MeshPart") then part.TextureID = "" end
        for _, d in ipairs(part:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then rememberGunTexture(d) d.Transparency=1 end
        end
    end
    for part, state in pairs(gunState) do
        if not active[part] and part and part.Parent then
            pcall(function()
                part.Material=state.Material part.Color=state.Color part.Transparency=state.Transparency part.CastShadow=state.CastShadow
                if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID=state.TextureID end
            end)
            gunState[part]=nil
        end
    end
end

local function restoreGunChams()
    for part,state in pairs(gunState) do
        if part and part.Parent then pcall(function()
            part.Material=state.Material part.Color=state.Color part.Transparency=state.Transparency part.CastShadow=state.CastShadow
            if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID=state.TextureID end
        end) end
    end
    for obj,state in pairs(gunTextureState) do if obj and obj.Parent then pcall(function() obj.Transparency=state.Transparency end) end end
    table.clear(gunState)
    table.clear(gunTextureState)
end

local GunChams = makeVisualOption("V3GunChams", "GunChams", function(v)
    gunEnabled=v
    if v then applyGunChams() else restoreGunChams() end
end)
GunChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) gunMaterial=v if gunEnabled then applyGunChams() end end})
GunChams.CreateToggle({["Name"]="Visibility Colors",["Default"]=true,["Function"]=function(v) gunUseVisibility=v if gunEnabled then applyGunChams() end end})
GunChams.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) gunVisibleColor=Color3.fromHSV(h,s,v) end})
GunChams.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) gunOccludedColor=Color3.fromHSV(h,s,v) end})
GunChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=90,["Default"]=0,["Function"]=function(v) gunTransparency=v/100 end})
GunChams.CreateDropdown({["Name"]="Preview State",["List"]={"Visible","Occluded"},["Function"]=function(v) gunPreviewState=v end})

local gunAccumulator=0
RunService.Heartbeat:Connect(function(dt)
    if not gunEnabled then return end
    gunAccumulator += dt
    if gunAccumulator >= 0.08 then gunAccumulator=0 applyGunChams() end
end)

-- --------------------------------------------------------------------------
-- Studio-only target visual test engine (NPC/dummy models, never Players).
-- --------------------------------------------------------------------------
local target = {
    Chams=false,
    ChamsColor=Color3.fromRGB(119,120,255),
    Thermal=true,
    VisibleCheck=false,
    ESP=false,
    Box=true,
    BoxMode="Corner",
    BoxLineColor=Color3.fromRGB(255,255,255),
    BoxFillColor=Color3.fromRGB(119,120,255),
    Health=true,
    HealthText=true,
    Name=true,
    Distance=true,
    Skeleton=false,
    SkeletonColor=Color3.fromRGB(255,255,255),
    Tracers=false,
    TracerOrigin="Bottom",
    TracerColor=Color3.fromRGB(255,255,255),
    TracerThickness=1,
    Arrows=false,
    ArrowColor=Color3.fromRGB(255,255,255),
    MaxDistance=1000,
}

local warnedStudioOnly=false
local function studioOnlyNotice()
    if not STUDIO and not warnedStudioOnly then
        warnedStudioOnly=true
        notify("Visuals", "Target visuals run on Preview only outside Roblox Studio. In Studio they also render on NPC/dummy Humanoids.")
    end
end

local targetGui = Instance.new("ScreenGui")
targetGui.Name="YokaiVisualsV3Targets"
targetGui.ResetOnSpawn=false
targetGui.IgnoreGuiInset=true
targetGui.DisplayOrder=996
targetGui.Parent=LocalPlayer:WaitForChild("PlayerGui")

local targetPacks={}
local function isStudioDummy(model)
    if not STUDIO or not model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if model == LocalPlayer.Character then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart")
    return hum~=nil and root~=nil
end

local function makeTargetPack(model)
    local pack={model=model,corners={},skeleton={}}
    pack.highlight=Instance.new("Highlight")
    pack.highlight.Name="YokaiStudioDummyChams"
    pack.highlight.Enabled=false
    pack.highlight.Parent=Workspace
    pack.fill=Instance.new("Frame") pack.fill.BorderSizePixel=0 pack.fill.AnchorPoint=Vector2.new(.5,.5) pack.fill.Visible=false pack.fill.Parent=targetGui
    pack.healthBack=Instance.new("Frame") pack.healthBack.BorderSizePixel=0 pack.healthBack.BackgroundColor3=Color3.new(0,0,0) pack.healthBack.Visible=false pack.healthBack.Parent=targetGui
    pack.health=Instance.new("Frame") pack.health.BorderSizePixel=0 pack.health.BackgroundColor3=Color3.new(1,1,1) pack.health.Visible=false pack.health.Parent=targetGui
    local grad=Instance.new("UIGradient") grad.Rotation=-90 grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(220,40,40)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(230,200,45)),ColorSequenceKeypoint.new(1,Color3.fromRGB(40,220,90))}) grad.Parent=pack.health
    pack.healthText=newLabel(targetGui,UDim2.fromOffset(55,16))
    pack.name=newLabel(targetGui)
    pack.distance=newLabel(targetGui)
    pack.tracer=newLine(targetGui,Color3.new(1,1,1),1)
    pack.arrow1=newLine(targetGui,Color3.new(1,1,1),1)
    pack.arrow2=newLine(targetGui,Color3.new(1,1,1),1)
    for i=1,8 do pack.corners[i]=newLine(targetGui,Color3.new(1,1,1),1) end
    for i=1,14 do pack.skeleton[i]=newLine(targetGui,Color3.new(1,1,1),1) end
    targetPacks[model]=pack
    return pack
end

local function destroyTargetPack(model)
    local p=targetPacks[model]
    if not p then return end
    for _,obj in pairs(p) do
        if typeof(obj)=="Instance" then pcall(function() obj:Destroy() end)
        elseif type(obj)=="table" then for _,child in ipairs(obj) do if typeof(child)=="Instance" then pcall(function() child:Destroy() end) end end end
    end
    targetPacks[model]=nil
end

local function hideTargetPack(p)
    if not p then return end
    p.highlight.Enabled=false p.fill.Visible=false p.healthBack.Visible=false p.health.Visible=false p.healthText.Visible=false p.name.Visible=false p.distance.Visible=false p.tracer.Visible=false p.arrow1.Visible=false p.arrow2.Visible=false
    for _,x in ipairs(p.corners) do x.Visible=false end
    for _,x in ipairs(p.skeleton) do x.Visible=false end
end

local dummyScan=0
local function scanDummies()
    if not STUDIO then return end
    local seen={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if isStudioDummy(obj) then
            seen[obj]=true
            if not targetPacks[obj] then makeTargetPack(obj) end
        end
    end
    for model in pairs(targetPacks) do if not seen[model] or not model.Parent then destroyTargetPack(model) end end
end

local function modelVisible(model, point)
    if not Camera then return false end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={LocalPlayer.Character,Camera}
    params.IgnoreWater=true
    local origin=Camera.CFrame.Position
    local result=Workspace:Raycast(origin,point-origin,params)
    return result==nil or (result.Instance and result.Instance:IsDescendantOf(model))
end

local skeletonR15={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local skeletonR6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function drawTargetCorners(p,x,y,w,h)
    local cw,ch=math.max(5,w/5),math.max(5,h/5)
    local l,r,t,b=x-w/2,x+w/2,y-h/2,y+h/2
    local pts={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,pair in ipairs(pts) do setLine(p.corners[i],pair[1],pair[2],1,target.BoxLineColor) end
end

local function drawTargetSkeleton(p,model)
    local hum=model:FindFirstChildOfClass("Humanoid")
    local bones=(hum and hum.RigType==Enum.HumanoidRigType.R6) and skeletonR6 or skeletonR15
    for i,line in ipairs(p.skeleton) do
        local pair=bones[i]
        if not pair then line.Visible=false continue end
        local a,b=model:FindFirstChild(pair[1]),model:FindFirstChild(pair[2])
        if a and b and Camera then
            local pa,va=Camera:WorldToViewportPoint(a.Position)
            local pb,vb=Camera:WorldToViewportPoint(b.Position)
            if va and vb and pa.Z>0 and pb.Z>0 then setLine(line,Vector2.new(pa.X,pa.Y),Vector2.new(pb.X,pb.Y),1,target.SkeletonColor) else line.Visible=false end
        else line.Visible=false end
    end
end

local function tracerOrigin(viewport)
    if target.TracerOrigin=="Center" then return Vector2.new(viewport.X/2,viewport.Y/2) end
    if target.TracerOrigin=="Top" then return Vector2.new(viewport.X/2,2) end
    if target.TracerOrigin=="Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(viewport.X/2,viewport.Y-2)
end

local function drawOffscreenArrow(p,worldPos)
    local vp=Camera.ViewportSize
    local center=Vector2.new(vp.X/2,vp.Y/2)
    local sp=Camera:WorldToViewportPoint(worldPos)
    local dir=Vector2.new(sp.X,sp.Y)-center
    if sp.Z<0 then dir=-dir end
    if dir.Magnitude<.01 then p.arrow1.Visible=false p.arrow2.Visible=false return end
    dir=dir.Unit
    local tip=center+dir*(math.min(vp.X,vp.Y)*.43)
    local ang=math.atan2(dir.Y,dir.X)
    local size=9
    local a=tip-Vector2.new(math.cos(ang-.55),math.sin(ang-.55))*size
    local b=tip-Vector2.new(math.cos(ang+.55),math.sin(ang+.55))*size
    setLine(p.arrow1,tip,a,1,target.ArrowColor)
    setLine(p.arrow2,tip,b,1,target.ArrowColor)
end

-- --------------------------------------------------------------------------
-- Functional draggable preview. It reflects Visuals settings only.
-- --------------------------------------------------------------------------
local previewEnabled=false
local previewGui,previewFrame,previewCanvas
local preview={body={},box={},skeleton={}}

local function makeDraggable(handle,frame)
    local dragging=false
    local dragStart
    local startPos
    local dragInput
    handle.Active=true
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true dragStart=input.Position startPos=frame.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input==dragInput then
            local d=input.Position-dragStart
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

local function makePreviewBodyPart(pos,size)
    local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.Position=pos f.Size=size f.BorderSizePixel=0 f.BackgroundColor3=Color3.fromRGB(90,92,105) f.BackgroundTransparency=.1 f.Parent=previewCanvas
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,5) c.Parent=f
    table.insert(preview.body,f)
    return f
end

local function buildPreview()
    if previewGui and previewGui.Parent then return end
    previewGui=Instance.new("ScreenGui") previewGui.Name="YokaiVisualsV3Preview" previewGui.ResetOnSpawn=false previewGui.IgnoreGuiInset=true previewGui.DisplayOrder=997
    previewGui.Parent=LocalPlayer:WaitForChild("PlayerGui")

    previewFrame=Instance.new("Frame") previewFrame.Position=UDim2.new(1,-270,0,78) previewFrame.Size=UDim2.fromOffset(245,340) previewFrame.BackgroundColor3=Color3.fromRGB(16,16,19) previewFrame.BackgroundTransparency=.03 previewFrame.BorderSizePixel=0 previewFrame.Parent=previewGui
    local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,8) fc.Parent=previewFrame
    local fs=Instance.new("UIStroke") fs.Color=Color3.fromRGB(70,70,82) fs.Transparency=.2 fs.Parent=previewFrame

    local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(12,7) title.Size=UDim2.new(1,-24,0,28) title.Font=Enum.Font.Code title.TextSize=14 title.TextColor3=Color3.fromRGB(240,240,245) title.TextXAlignment=Enum.TextXAlignment.Left title.Text="Visuals Preview  •  drag" title.Parent=previewFrame
    makeDraggable(title,previewFrame)

    previewCanvas=Instance.new("Frame") previewCanvas.Position=UDim2.fromOffset(12,38) previewCanvas.Size=UDim2.new(1,-24,1,-50) previewCanvas.BackgroundColor3=Color3.fromRGB(22,22,27) previewCanvas.BorderSizePixel=0 previewCanvas.ClipsDescendants=true previewCanvas.Parent=previewFrame
    local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=previewCanvas

    preview.name=newLabel(previewCanvas) preview.name.Text="Dummy" preview.name.Visible=false
    preview.distance=newLabel(previewCanvas) preview.distance.Text="87 studs" preview.distance.Visible=false
    preview.healthBack=Instance.new("Frame") preview.healthBack.BorderSizePixel=0 preview.healthBack.BackgroundColor3=Color3.new(0,0,0) preview.healthBack.Visible=false preview.healthBack.Parent=previewCanvas
    preview.health=Instance.new("Frame") preview.health.BorderSizePixel=0 preview.health.BackgroundColor3=Color3.fromRGB(70,220,100) preview.health.Visible=false preview.health.Parent=previewCanvas
    preview.healthText=newLabel(previewCanvas,UDim2.fromOffset(50,16)) preview.healthText.Text="76%" preview.healthText.Visible=false
    preview.fill=Instance.new("Frame") preview.fill.AnchorPoint=Vector2.new(.5,.5) preview.fill.BorderSizePixel=0 preview.fill.Visible=false preview.fill.ZIndex=1 preview.fill.Parent=previewCanvas
    for i=1,8 do preview.box[i]=newLine(previewCanvas,Color3.new(1,1,1),1) end
    for i=1,10 do preview.skeleton[i]=newLine(previewCanvas,Color3.new(1,1,1),1) end
    preview.tracer=newLine(previewCanvas,Color3.new(1,1,1),1)

    local bodyCenterX=.50
    preview.head=makePreviewBodyPart(UDim2.new(bodyCenterX,0,.27,0),UDim2.fromOffset(34,34))
    preview.torso=makePreviewBodyPart(UDim2.new(bodyCenterX,0,.48,0),UDim2.fromOffset(48,72))
    preview.leftArm=makePreviewBodyPart(UDim2.new(.35,0,.48,0),UDim2.fromOffset(16,68))
    preview.rightArm=makePreviewBodyPart(UDim2.new(.65,0,.48,0),UDim2.fromOffset(16,68))
    preview.leftLeg=makePreviewBodyPart(UDim2.new(.44,0,.75,0),UDim2.fromOffset(18,72))
    preview.rightLeg=makePreviewBodyPart(UDim2.new(.56,0,.75,0),UDim2.fromOffset(18,72))

    preview.aura=Instance.new("Frame") preview.aura.AnchorPoint=Vector2.new(.5,.5) preview.aura.Position=UDim2.new(.5,0,.50,0) preview.aura.Size=UDim2.fromOffset(105,105) preview.aura.BackgroundTransparency=1 preview.aura.Visible=false preview.aura.Parent=previewCanvas
    local ac=Instance.new("UICorner") ac.CornerRadius=UDim.new(1,0) ac.Parent=preview.aura
    preview.auraStroke=Instance.new("UIStroke") preview.auraStroke.Thickness=2 preview.auraStroke.Transparency=.05 preview.auraStroke.Parent=preview.aura

    preview.reticle=Instance.new("Frame") preview.reticle.AnchorPoint=Vector2.new(.5,.5) preview.reticle.Position=UDim2.new(.5,0,.50,0) preview.reticle.Size=UDim2.fromOffset(130,130) preview.reticle.BackgroundTransparency=1 preview.reticle.Visible=false preview.reticle.Parent=previewCanvas
    preview.reticleParts={}
    local specs={{UDim2.new(.5,0,0,10),UDim2.fromOffset(3,22)},{UDim2.new(.5,0,1,-10),UDim2.fromOffset(3,22)},{UDim2.new(0,10,.5,0),UDim2.fromOffset(22,3)},{UDim2.new(1,-10,.5,0),UDim2.fromOffset(22,3)}}
    for _,spec in ipairs(specs) do local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.Position=spec[1] f.Size=spec[2] f.BorderSizePixel=0 f.Parent=preview.reticle table.insert(preview.reticleParts,f) end

    preview.gun=Instance.new("Frame") preview.gun.AnchorPoint=Vector2.new(.5,.5) preview.gun.Position=UDim2.new(.73,0,.47,0) preview.gun.Size=UDim2.fromOffset(46,9) preview.gun.BorderSizePixel=0 preview.gun.Visible=false preview.gun.Parent=previewCanvas
    local gc=Instance.new("UICorner") gc.CornerRadius=UDim.new(0,3) gc.Parent=preview.gun
    preview.gunText=newLabel(previewCanvas,UDim2.fromOffset(100,16)) preview.gunText.Position=UDim2.new(.72,0,.40,0) preview.gunText.Visible=false

    preview.studioLabel=newLabel(previewCanvas,UDim2.new(1,-10,0,18)) preview.studioLabel.AnchorPoint=Vector2.new(.5,0) preview.studioLabel.Position=UDim2.new(.5,0,0,4) preview.studioLabel.Text=STUDIO and "STUDIO DUMMY MODE" or "PREVIEW MODE" preview.studioLabel.TextColor3=STUDIO and Color3.fromRGB(90,255,140) or Color3.fromRGB(255,190,80) preview.studioLabel.Visible=true
end

local Preview = makeVisualOption("V3Preview", "Preview", function(v)
    previewEnabled=v
    buildPreview()
    previewGui.Enabled=v
end)

-- --------------------------------------------------------------------------
-- Visual modules. Internal names are unique so Render originals stay intact.
-- --------------------------------------------------------------------------
local Chams=makeVisualOption("V3TargetChams","Chams",function(v) target.Chams=v if v then studioOnlyNotice() end end)
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) target.Thermal=v end})
Chams.CreateToggle({["Name"]="Visible Check",["Default"]=false,["Function"]=function(v) target.VisibleCheck=v end})
Chams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) target.ChamsColor=Color3.fromHSV(h,s,v) end})

local ESP=makeVisualOption("V3TargetESP","ESP",function(v) target.ESP=v if v then studioOnlyNotice() end end)
ESP.CreateToggle({["Name"]="Box",["Default"]=true,["Function"]=function(v) target.Box=v end})
ESP.CreateDropdown({["Name"]="Box Mode",["List"]={"Corner","Thermal"},["Function"]=function(v) target.BoxMode=v end})
ESP.CreateColorSlider({["Name"]="Box Color",["Function"]=function(h,s,v) target.BoxLineColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Box Fill",["Function"]=function(h,s,v) target.BoxFillColor=Color3.fromHSV(h,s,v) end})
ESP.CreateToggle({["Name"]="Health",["Default"]=true,["Function"]=function(v) target.Health=v end})
ESP.CreateToggle({["Name"]="Health Text",["Default"]=true,["Function"]=function(v) target.HealthText=v end})
ESP.CreateToggle({["Name"]="Name",["Default"]=true,["Function"]=function(v) target.Name=v end})
ESP.CreateToggle({["Name"]="Distance",["Default"]=true,["Function"]=function(v) target.Distance=v end})
ESP.CreateToggle({["Name"]="Skeleton",["Default"]=false,["Function"]=function(v) target.Skeleton=v end})
ESP.CreateColorSlider({["Name"]="Skeleton Color",["Function"]=function(h,s,v) target.SkeletonColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=2000,["Default"]=1000,["Function"]=function(v) target.MaxDistance=v end})

local Tracers=makeVisualOption("V3TargetTracers","Tracers",function(v) target.Tracers=v if v then studioOnlyNotice() end end)
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Bottom","Center","Mouse","Top"},["Function"]=function(v) target.TracerOrigin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) target.TracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=4,["Default"]=1,["Function"]=function(v) target.TracerThickness=v end})

local Arrows=makeVisualOption("V3TargetArrows","Arrows",function(v) target.Arrows=v if v then studioOnlyNotice() end end)
Arrows.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) target.ArrowColor=Color3.fromHSV(h,s,v) end})

-- Local FOV and GUI blur controls remain in Visuals because they are purely local.
local fovEnabled=false
local fovValue=70
local originalFov=setmetatable({}, {__mode="k"})
local function applyFov()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if originalFov[cam]==nil then originalFov[cam]=cam.FieldOfView end
    cam.FieldOfView=fovEnabled and fovValue or (originalFov[cam] or 70)
end
local FOV=makeVisualOption("V3FOVChanger","FOVChanger",function(v) fovEnabled=v applyFov() end)
FOV.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=120,["Default"]=70,["Function"]=function(v) fovValue=v if fovEnabled then applyFov() end end})

local noMenuFog=false
local function applyNoMenuFog()
    pcall(function()
        if GuiLibrary["MainBlur"] then GuiLibrary["MainBlur"].Size=noMenuFog and 0 or 25 end
        if noMenuFog then RunService:SetRobloxGuiFocused(false) end
    end)
end
local NoMenuFog=makeVisualOption("V3NoMenuFog","NoMenuFog",function(v) noMenuFog=v applyNoMenuFog() end)

-- --------------------------------------------------------------------------
-- Render / preview loop
-- --------------------------------------------------------------------------
local function updatePreview(dt)
    if not previewEnabled or not previewGui or not previewGui.Enabled or not previewCanvas then return end
    local size=previewCanvas.AbsoluteSize
    if size.X<=0 or size.Y<=0 then return end
    local cx,cy=size.X*.5,size.Y*.52
    local w,h=78,190

    local bodyColor=Color3.fromRGB(90,92,105)
    if selfChamsEnabled then bodyColor=selfChamsColor elseif target.Chams then bodyColor=target.ChamsColor end
    for _,b in ipairs(preview.body) do b.BackgroundColor3=bodyColor b.BackgroundTransparency=selfChamsEnabled and selfChamsTransparency or .1 end

    preview.name.Position=UDim2.fromOffset(cx,cy-h/2-10)
    preview.name.Text="Dummy"
    preview.name.Visible=target.ESP and target.Name
    preview.distance.Position=UDim2.fromOffset(cx,cy+h/2+10)
    preview.distance.Text="87 studs"
    preview.distance.Visible=target.ESP and target.Distance

    local healthRatio=.76
    local bx=cx-w/2-8
    preview.healthBack.Position=UDim2.fromOffset(bx,cy-h/2) preview.healthBack.Size=UDim2.fromOffset(3,h) preview.healthBack.Visible=target.ESP and target.Health
    preview.health.Position=UDim2.fromOffset(bx,cy-h/2+h*(1-healthRatio)) preview.health.Size=UDim2.fromOffset(3,h*healthRatio) preview.health.Visible=target.ESP and target.Health
    preview.healthText.Position=UDim2.fromOffset(bx-18,cy-h/2+h*(1-healthRatio)) preview.healthText.Text="76%" preview.healthText.Visible=target.ESP and target.Health and target.HealthText

    local l,r,t,b=cx-w/2,cx+w/2,cy-h/2,cy+h/2
    local cw,ch=18,28
    local pts={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,pair in ipairs(pts) do
        if target.ESP and target.Box then setLine(preview.box[i],pair[1],pair[2],1,target.BoxLineColor) else preview.box[i].Visible=false end
    end
    preview.fill.Position=UDim2.fromOffset(cx,cy) preview.fill.Size=UDim2.fromOffset(w,h) preview.fill.BackgroundColor3=target.BoxFillColor preview.fill.BackgroundTransparency=.7 preview.fill.Visible=target.ESP and target.Box and target.BoxMode=="Thermal"

    -- Simple preview skeleton.
    local skPts={Vector2.new(cx,cy-70),Vector2.new(cx,cy-30),Vector2.new(cx,cy+15),Vector2.new(cx-28,cy-25),Vector2.new(cx+28,cy-25),Vector2.new(cx-16,cy+76),Vector2.new(cx+16,cy+76)}
    local skEdges={{1,2},{2,3},{2,4},{2,5},{3,6},{3,7}}
    for i,line in ipairs(preview.skeleton) do
        local e=skEdges[i]
        if target.ESP and target.Skeleton and e then setLine(line,skPts[e[1]],skPts[e[2]],1,target.SkeletonColor) else line.Visible=false end
    end

    if target.Tracers then
        local origin
        if target.TracerOrigin=="Center" then origin=Vector2.new(size.X/2,size.Y/2)
        elseif target.TracerOrigin=="Top" then origin=Vector2.new(size.X/2,2)
        elseif target.TracerOrigin=="Mouse" then
            local m=UserInputService:GetMouseLocation()-previewCanvas.AbsolutePosition
            origin=Vector2.new(math.clamp(m.X,0,size.X),math.clamp(m.Y,0,size.Y))
        else origin=Vector2.new(size.X/2,size.Y-2) end
        setLine(preview.tracer,origin,Vector2.new(cx,cy),target.TracerThickness,target.TracerColor)
    else preview.tracer.Visible=false end

    preview.aura.Visible=auraEnabled
    preview.auraStroke.Color=auraColor
    preview.reticle.Visible=reticleEnabled
    preview.reticle.Rotation=(preview.reticle.Rotation+auraSpinSpeed*dt)%360
    for _,x in ipairs(preview.reticleParts) do x.BackgroundColor3=auraColor end

    preview.gun.Visible=gunEnabled
    preview.gunText.Visible=gunEnabled
    local gunVisible=(gunPreviewState=="Visible")
    preview.gun.BackgroundColor3=gunVisible and gunVisibleColor or gunOccludedColor
    preview.gun.BackgroundTransparency=gunTransparency
    preview.gunText.Text=gunVisible and "GUN • VISIBLE" or "GUN • OCCLUDED"
    preview.gunText.TextColor3=preview.gun.BackgroundColor3
end

local function updateStudioTargets()
    if not STUDIO or not Camera then return end
    local anyTarget=target.Chams or target.ESP or target.Tracers or target.Arrows
    if not anyTarget then for _,p in pairs(targetPacks) do hideTargetPack(p) end return end

    local vp=Camera.ViewportSize
    for model,p in pairs(targetPacks) do
        if not model.Parent then destroyTargetPack(model) continue end
        local hum=model:FindFirstChildOfClass("Humanoid")
        local root=model:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health<=0 then hideTargetPack(p) continue end
        local dist=(Camera.CFrame.Position-root.Position).Magnitude
        if dist>target.MaxDistance then hideTargetPack(p) continue end
        local sp,onScreen=Camera:WorldToViewportPoint(root.Position)
        local visible=modelVisible(model,root.Position)

        if target.Chams and (not target.VisibleCheck or visible) then
            p.highlight.Adornee=model p.highlight.Enabled=true p.highlight.FillColor=target.ChamsColor p.highlight.OutlineColor=target.ChamsColor p.highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            if target.Thermal then local breathe=(math.sin(os.clock()*2)+1)/2 p.highlight.FillTransparency=.35+breathe*.35 p.highlight.OutlineTransparency=.05+breathe*.25 else p.highlight.FillTransparency=.55 p.highlight.OutlineTransparency=0 end
        else p.highlight.Enabled=false end

        if onScreen and sp.Z>0 then
            p.arrow1.Visible=false p.arrow2.Visible=false
            local scale=(root.Size.Y*vp.Y)/(sp.Z*2)
            local w,h=math.max(22,3*scale),math.max(42,4.5*scale)
            local x,y=sp.X,sp.Y

            if target.ESP and target.Box then
                drawTargetCorners(p,x,y,w,h)
                p.fill.AnchorPoint=Vector2.new(.5,.5) p.fill.Position=UDim2.fromOffset(x,y) p.fill.Size=UDim2.fromOffset(w,h) p.fill.BackgroundColor3=target.BoxFillColor p.fill.BackgroundTransparency=.72 p.fill.Visible=target.BoxMode=="Thermal"
            else p.fill.Visible=false for _,q in ipairs(p.corners) do q.Visible=false end end

            if target.ESP and target.Health then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                local bx=x-w/2-7
                p.healthBack.Position=UDim2.fromOffset(bx,y-h/2) p.healthBack.Size=UDim2.fromOffset(3,h) p.healthBack.Visible=true
                p.health.Position=UDim2.fromOffset(bx,y-h/2+h*(1-ratio)) p.health.Size=UDim2.fromOffset(3,h*ratio) p.health.Visible=true
                p.healthText.Position=UDim2.fromOffset(bx-20,y-h/2+h*(1-ratio)) p.healthText.Text=string.format("%d%%",math.floor(ratio*100)) p.healthText.Visible=target.HealthText
            else p.healthBack.Visible=false p.health.Visible=false p.healthText.Visible=false end

            p.name.Position=UDim2.fromOffset(x,y-h/2-12) p.name.Text=model.Name p.name.Visible=target.ESP and target.Name
            p.distance.Position=UDim2.fromOffset(x,y+h/2+10) p.distance.Text=string.format("%d studs",math.floor(dist)) p.distance.Visible=target.ESP and target.Distance
            if target.ESP and target.Skeleton then drawTargetSkeleton(p,model) else for _,q in ipairs(p.skeleton) do q.Visible=false end end
            if target.Tracers then setLine(p.tracer,tracerOrigin(vp),Vector2.new(x,y),target.TracerThickness,target.TracerColor) else p.tracer.Visible=false end
        else
            p.fill.Visible=false p.healthBack.Visible=false p.health.Visible=false p.healthText.Visible=false p.name.Visible=false p.distance.Visible=false p.tracer.Visible=false
            for _,q in ipairs(p.corners) do q.Visible=false end for _,q in ipairs(p.skeleton) do q.Visible=false end
            if target.Arrows then drawOffscreenArrow(p,root.Position) else p.arrow1.Visible=false p.arrow2.Visible=false end
        end
    end
end

RunService.RenderStepped:Connect(function(dt)
    -- self aura / reticle
    if auraEnabled or reticleEnabled then
        ensureSelfAura()
        if selfAuraRing then
            selfAuraRing.Visible=auraEnabled
            local stroke=selfAuraRing:FindFirstChild("GlowStroke")
            if stroke then stroke.Color=auraColor end
        end
        if selfReticle then
            selfReticle.Visible=reticleEnabled
            selfReticle.Rotation=(selfReticle.Rotation+auraSpinSpeed*dt)%360
            for _,f in ipairs(reticleParts) do f.BackgroundColor3=auraColor end
        end
    elseif selfAuraGui then destroySelfAura() end

    updatePreview(dt)
    updateStudioTargets()
end)

RunService.Heartbeat:Connect(function(dt)
    if STUDIO then
        dummyScan += dt
        if dummyScan>=.6 then dummyScan=0 scanDummies() end
    end
end)

if STUDIO then scanDummies() end

notify("Yokai", STUDIO and "Visuals V3 loaded • Studio dummy testing enabled" or "Visuals V3 loaded • self/preview mode")
