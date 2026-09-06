-- Gun Testing / bot-practice visuals.
-- Targets world Humanoid rigs that are not linked to a real game.Players character.
-- In this experience the folder Workspace.Players contains bot rigs as well, so the
-- folder name itself is NOT treated as evidence that a model is a real player.
-- Event-driven registry: no periodic Workspace:GetDescendants() sweep.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec = objects.VisualsWindow
local Visuals = VisualsRec and VisualsRec.Api
if not Visuals then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP, "") end
local function optionName(key, rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$", "")
end
local function under(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _, root in ipairs({parentRec.Object, parentRec.ChildrenObject}) do
        if root and typeof(root) == "Instance" then
            local ok, res = pcall(function()
                return rec.Object == root or rec.Object:IsDescendantOf(root)
            end)
            if ok and res then return true end
        end
    end
    return false
end
local function removeOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec.Type == "OptionsButton" and under(rec, VisualsRec) and optionName(key, rec) == name then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

for _, name in ipairs({
    "ESP", "Chams", "Corner Box", "Thermal Corner", "HealthBar",
    "Name + Distance", "Skeleton", "Tracers", "3D Box", "Distance"
}) do
    removeOption(name)
end

pcall(function() RunService:UnbindFromRenderStep("YokaiBotVisuals") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiGunTestingBotVisualsV20") end)

local function rootOf(model)
    return model and (
        model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
    )
end

local function actualPlayerModel(model)
    if not model then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            if model == char or model:IsDescendantOf(char) or char:IsDescendantOf(model) then
                return true
            end
        end
        -- Custom world avatars sometimes are not assigned to Player.Character.
        -- Only match an existing real Player object; bot names that have no Player
        -- instance remain valid targets even inside Workspace.Players.
        if model.Name == plr.Name then
            local container = model.Parent
            if container and container == Workspace:FindFirstChild("Players") then
                return true
            end
        end
        for _, attr in ipairs({"UserId", "PlayerUserId", "OwnerUserId"}) do
            local ok, value = pcall(function() return model:GetAttribute(attr) end)
            if ok and tonumber(value) == plr.UserId then return true end
        end
    end
    return false
end

local function validBot(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    if model.Name == "YokaiSafeVisualTestTarget" then return false end
    if actualPlayerModel(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = rootOf(model)
    return hum ~= nil and root ~= nil and hum.Health > 0
end

local bots = setmetatable({}, {__mode = "k"})
local watched = setmetatable({}, {__mode = "k"})
local targetContainerNames = {
    Players = true,
    Zombies = true,
    Characters = true,
    NPCs = true,
    Bots = true,
    Dummies = true,
}

local function registerModel(model)
    if validBot(model) then bots[model] = true end
end

local function scanContainer(container)
    if not container or watched[container] then return end
    watched[container] = true
    if container:IsA("Model") then registerModel(container) end
    for _, d in ipairs(container:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
            registerModel(d.Parent)
        end
    end
    container.DescendantAdded:Connect(function(d)
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
            task.defer(registerModel, d.Parent)
        elseif d:IsA("Model") then
            task.defer(registerModel, d)
        end
    end)
    container.DescendantRemoving:Connect(function(d)
        if d:IsA("Model") then bots[d] = nil
        elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent] = nil end
    end)
end

local foundContainer = false
for name in pairs(targetContainerNames) do
    local c = Workspace:FindFirstChild(name)
    if c then foundContainer = true; scanContainer(c) end
end
if not foundContainer then
    -- One startup fallback only; no recurring full-workspace sweep.
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerModel(d.Parent) end
    end
end
Workspace.ChildAdded:Connect(function(child)
    if targetContainerNames[child.Name] then scanContainer(child) end
end)
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char) bots[char] = nil end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr.Character then bots[plr.Character] = nil end
    plr.CharacterAdded:Connect(function(char) bots[char] = nil end)
end

shared.YokaiGunTestingBotRegistry = bots

local function visibleFromCamera(model, part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {cam}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    rp.FilterDescendantsInstances = filter
    rp.IgnoreWater = true
    local hit = Workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, rp)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end

local function parentGui()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return CoreGui
end
local guiParent = parentGui()
local old = guiParent:FindFirstChild("YokaiGunTestingBotVisualsV20", true)
if old then old:Destroy() end
local overlay = Instance.new("ScreenGui")
overlay.Name = "YokaiGunTestingBotVisualsV20"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 1020
overlay.Parent = guiParent

local function line(parent)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(.5, .5)
    f.BorderSizePixel = 0
    f.Visible = false
    f.Parent = parent
    return f
end
local function setLine(f, a, b, thickness, color, transparency)
    local d = b - a
    if d.Magnitude < .01 then f.Visible = false return end
    f.Size = UDim2.fromOffset(d.Magnitude, thickness or 1)
    f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = color
    f.BackgroundTransparency = transparency or 0
    f.Visible = true
end
local function hideLines(t)
    for _, f in ipairs(t) do f.Visible = false end
end

local stores = setmetatable({}, {__mode = "k"})
local function makeStore(model)
    local s = {Model = model}
    s.Highlight = Instance.new("Highlight")
    s.Highlight.Name = "YokaiBotChamsV20"
    s.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    s.Highlight.Enabled = false
    s.Highlight.Parent = Workspace

    s.Fill = Instance.new("Frame")
    s.Fill.BorderSizePixel = 0
    s.Fill.Visible = false
    s.Fill.Parent = overlay
    s.FillGradient = Instance.new("UIGradient")
    s.FillGradient.Rotation = 30
    s.FillGradient.Parent = s.Fill

    s.Corners = {}
    for i = 1, 8 do s.Corners[i] = line(overlay) end

    s.HealthBack = Instance.new("Frame")
    s.HealthBack.BorderSizePixel = 0
    s.HealthBack.BackgroundColor3 = Color3.new(0,0,0)
    s.HealthBack.Visible = false
    s.HealthBack.Parent = overlay
    s.Health = Instance.new("Frame")
    s.Health.BorderSizePixel = 0
    s.Health.BackgroundColor3 = Color3.new(1,1,1)
    s.Health.Visible = false
    s.Health.Parent = overlay
    s.HealthGradient = Instance.new("UIGradient")
    s.HealthGradient.Rotation = 90
    s.HealthGradient.Parent = s.Health
    s.HealthText = Instance.new("TextLabel")
    s.HealthText.BackgroundTransparency = 1
    s.HealthText.Size = UDim2.fromOffset(44, 16)
    s.HealthText.Font = Enum.Font.Code
    s.HealthText.TextSize = 11
    s.HealthText.TextColor3 = Color3.new(1,1,1)
    s.HealthText.TextStrokeTransparency = 0
    s.HealthText.Visible = false
    s.HealthText.Parent = overlay

    s.Name = Instance.new("TextLabel")
    s.Name.BackgroundTransparency = 1
    s.Name.Size = UDim2.fromOffset(190,18)
    s.Name.Font = Enum.Font.Code
    s.Name.TextSize = 11
    s.Name.TextColor3 = Color3.new(1,1,1)
    s.Name.TextStrokeTransparency = 0
    s.Name.Visible = false
    s.Name.Parent = overlay

    s.Skeleton = {}
    for i = 1, 16 do s.Skeleton[i] = line(overlay) end
    s.Tracer = line(overlay)
    s.Box3D = {}
    for i = 1, 12 do s.Box3D[i] = line(overlay) end

    stores[model] = s
    return s
end
local function hideStore(s)
    s.Highlight.Enabled = false
    s.Fill.Visible = false
    s.HealthBack.Visible = false
    s.Health.Visible = false
    s.HealthText.Visible = false
    s.Name.Visible = false
    s.Tracer.Visible = false
    hideLines(s.Corners); hideLines(s.Skeleton); hideLines(s.Box3D)
end
local function destroyStore(model)
    local s = stores[model]
    if not s then return end
    for _, value in pairs(s) do
        if typeof(value) == "Instance" then pcall(function() value:Destroy() end)
        elseif type(value) == "table" then
            for _, x in pairs(value) do if typeof(x) == "Instance" then pcall(function() x:Destroy() end) end end
        end
    end
    stores[model] = nil
end

local visualDistance = 1000
local wallCheck = true
local espEnabled = false
local espColor = Color3.fromRGB(119,120,255)
local visibleColor = Color3.fromRGB(35,235,95)
local occludedColor = Color3.fromRGB(245,70,70)
local espFillTransparency = .82
local espCorners = true
local espHealth = true
local espHealthText = true
local espNames = true
local healthPalette = "Blue / Red"

local chamsEnabled = false
local chamsFill = Color3.fromRGB(119,120,255)
local chamsOutline = Color3.fromRGB(119,120,255)
local chamsFillTransparency = .58
local chamsOutlineTransparency = .10
local chamsThermal = true

local cornerEnabled = false
local thermalCornerEnabled = false
local healthEnabled = false
local namesEnabled = false
local skeletonEnabled = false
local skeletonColor = Color3.new(1,1,1)
local skeletonTransparency = 0
local skeletonThickness = 1
local tracersEnabled = false
local tracerColor = Color3.new(1,1,1)
local tracerThickness = 1
local tracerTransparency = 0
local tracerOrigin = "Bottom"
local box3DEnabled = false
local box3DColor = Color3.new(1,1,1)
local box3DThickness = 1

local ESP = Visuals.CreateOptionsButton({Name="ESP", Function=function(v) espEnabled=v end, HoverText="Bot ESP. Workspace.Players bot rigs are supported; real Player characters are excluded."})
ESP.CreateToggle({Name="WallCheck", Default=true, Function=function(v) wallCheck=v end})
ESP.CreateColorSlider({Name="ESP Color", Function=function(h,s,v) espColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({Name="Visible Color", Function=function(h,s,v) visibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({Name="Occluded Color", Function=function(h,s,v) occludedColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({Name="Fill Transparency", Min=0, Max=100, Default=82, Function=function(v) espFillTransparency=v/100 end})
ESP.CreateToggle({Name="Corner", Default=true, Function=function(v) espCorners=v end})
ESP.CreateToggle({Name="ESP HealthBar", Default=true, Function=function(v) espHealth=v end})
ESP.CreateToggle({Name="ESP HealthText", Default=true, Function=function(v) espHealthText=v end})
ESP.CreateToggle({Name="Name + Distance", Default=true, Function=function(v) espNames=v end})
ESP.CreateDropdown({Name="Health Palette", List={"Blue / Red","Mint / Yellow / Red"}, Function=function(v) healthPalette=v end})

local Chams = Visuals.CreateOptionsButton({Name="Chams", Function=function(v) chamsEnabled=v end})
Chams.CreateToggle({Name="Thermal", Default=true, Function=function(v) chamsThermal=v end})
Chams.CreateColorSlider({Name="Fill Color", Function=function(h,s,v) chamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({Name="Outline Color", Function=function(h,s,v) chamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({Name="Fill Transparency", Min=0, Max=100, Default=58, Function=function(v) chamsFillTransparency=v/100 end})
Chams.CreateSlider({Name="Outline Transparency", Min=0, Max=100, Default=10, Function=function(v) chamsOutlineTransparency=v/100 end})

local Corner = Visuals.CreateOptionsButton({Name="Corner Box", Function=function(v) cornerEnabled=v end})
local ThermalCorner = Visuals.CreateOptionsButton({Name="Thermal Corner", Function=function(v) thermalCornerEnabled=v end})
local Health = Visuals.CreateOptionsButton({Name="HealthBar", Function=function(v) healthEnabled=v end})
Health.CreateToggle({Name="HealthText", Default=true, Function=function(v) espHealthText=v end})
Health.CreateDropdown({Name="Palette", List={"Blue / Red","Mint / Yellow / Red"}, Function=function(v) healthPalette=v end})
local Names = Visuals.CreateOptionsButton({Name="Name + Distance", Function=function(v) namesEnabled=v end})
local Skeleton = Visuals.CreateOptionsButton({Name="Skeleton", Function=function(v) skeletonEnabled=v end})
Skeleton.CreateColorSlider({Name="Color", Function=function(h,s,v) skeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({Name="Transparency", Min=0, Max=95, Default=0, Function=function(v) skeletonTransparency=v/100 end})
Skeleton.CreateSlider({Name="Thickness", Min=1, Max=5, Default=1, Function=function(v) skeletonThickness=v end})
local Tracers = Visuals.CreateOptionsButton({Name="Tracers", Function=function(v) tracersEnabled=v end})
Tracers.CreateDropdown({Name="Origin", List={"Top","Bottom","Center","Mouse"}, Function=function(v) tracerOrigin=v end})
Tracers.CreateColorSlider({Name="Color", Function=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({Name="Thickness", Min=1, Max=5, Default=1, Function=function(v) tracerThickness=v end})
Tracers.CreateSlider({Name="Transparency", Min=0, Max=95, Default=0, Function=function(v) tracerTransparency=v/100 end})
local Box3D = Visuals.CreateOptionsButton({Name="3D Box", Function=function(v) box3DEnabled=v end})
Box3D.CreateColorSlider({Name="Color", Function=function(h,s,v) box3DColor=Color3.fromHSV(h,s,v) end})
Box3D.CreateSlider({Name="Thickness", Min=1, Max=5, Default=1, Function=function(v) box3DThickness=v end})
local Distance = Visuals.CreateOptionsButton({Name="Distance", Function=function() end})
Distance.CreateSlider({Name="Max Distance", Min=25, Max=5000, Default=1000, Function=function(v) visualDistance=v end})

local function healthSequence()
    if healthPalette == "Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(120,255,205)),
            ColorSequenceKeypoint.new(.5, Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(230,55,55)),
        })
    end
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50,110,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220,40,50)),
    })
end

local function bounds(model)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local cf, size = model:GetBoundingBox()
    local minX,minY,maxX,maxY = math.huge,math.huge,-math.huge,-math.huge
    local any = false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local wp = (cf * CFrame.new(size.X*x/2, size.Y*y/2, size.Z*z/2)).Position
        local p = cam:WorldToViewportPoint(wp)
        if p.Z > 0 then
            any = true
            minX=math.min(minX,p.X); minY=math.min(minY,p.Y)
            maxX=math.max(maxX,p.X); maxY=math.max(maxY,p.Y)
        end
    end end end
    if not any then return nil end
    return Vector2.new(minX,minY), Vector2.new(maxX,maxY), cf, size
end

local function drawCorners(lines, tl, br, color, thickness, transparency)
    local l,t,r,b = tl.X,tl.Y,br.X,br.Y
    local cw = math.max(5,(r-l)/5)
    local ch = math.max(5,(b-t)/5)
    local seg = {
        {Vector2.new(l,t),Vector2.new(l+cw,t)}, {Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)}, {Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)}, {Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)}, {Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],thickness,color,transparency or 0) end
end

local r15 = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local r6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local function drawSkeleton(s, model)
    hideLines(s.Skeleton)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local list = model:FindFirstChild("UpperTorso") and r15 or r6
    for i,pair in ipairs(list) do
        local a,b = model:FindFirstChild(pair[1]), model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") and s.Skeleton[i] then
            local ap,ao = cam:WorldToViewportPoint(a.Position)
            local bp,bo = cam:WorldToViewportPoint(b.Position)
            if ao and bo and ap.Z>0 and bp.Z>0 then
                setLine(s.Skeleton[i],Vector2.new(ap.X,ap.Y),Vector2.new(bp.X,bp.Y),skeletonThickness,skeletonColor,skeletonTransparency)
            end
        end
    end
end

local edges = {{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}
local function draw3D(s, cf, size)
    hideLines(s.Box3D)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local pts = {}
    local idx = 1
    for z=-1,1,2 do for y=-1,1,2 do for x=-1,1,2 do
        local p,on = cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        pts[idx] = on and p.Z>0 and Vector2.new(p.X,p.Y) or nil
        idx += 1
    end end end
    for i,e in ipairs(edges) do
        local a,b = pts[e[1]],pts[e[2]]
        if a and b then setLine(s.Box3D[i],a,b,box3DThickness,box3DColor,0) end
    end
end

local function tracerStart()
    local cam = Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    local vp = cam.ViewportSize
    if tracerOrigin == "Top" then return Vector2.new(vp.X/2,0) end
    if tracerOrigin == "Center" then return vp/2 end
    if tracerOrigin == "Mouse" then
        local m = UserInputService:GetMouseLocation()
        return Vector2.new(math.clamp(m.X,0,vp.X),math.clamp(m.Y,0,vp.Y))
    end
    return Vector2.new(vp.X/2,vp.Y)
end

local function readableName(model, hum)
    local display = hum and tostring(hum.DisplayName or "") or ""
    if display ~= "" and #display < 40 then return display end
    if #model.Name < 40 then return model.Name end
    return "Bot"
end

RunService:BindToRenderStep("YokaiGunTestingBotVisualsV20", Enum.RenderPriority.Last.Value+90, function()
    local anything = espEnabled or chamsEnabled or cornerEnabled or thermalCornerEnabled or healthEnabled or namesEnabled or skeletonEnabled or tracersEnabled or box3DEnabled
    if not anything then
        for _,s in pairs(stores) do hideStore(s) end
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    for model in pairs(stores) do
        if not bots[model] or not validBot(model) then destroyStore(model) end
    end

    for model in pairs(bots) do
        if validBot(model) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = rootOf(model)
            if hum and root then
                local dist = (cam.CFrame.Position-root.Position).Magnitude
                local tl,br,cf,size = bounds(model)
                local s = stores[model] or makeStore(model)
                if not tl or dist > visualDistance then hideStore(s) continue end

                local head = model:FindFirstChild("Head") or root
                local occluded = wallCheck and not visibleFromCamera(model,head)
                local stateColor = wallCheck and (occluded and occludedColor or visibleColor) or espColor
                local w,h = br.X-tl.X, br.Y-tl.Y
                local ratio = math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)

                if espEnabled then
                    s.Fill.Position=UDim2.fromOffset(tl.X,tl.Y)
                    s.Fill.Size=UDim2.fromOffset(w,h)
                    s.Fill.BackgroundColor3=stateColor
                    s.Fill.BackgroundTransparency=espFillTransparency
                    s.FillGradient.Enabled=false
                    s.Fill.Visible=true
                    if espCorners then drawCorners(s.Corners,tl,br,stateColor,1,0) else hideLines(s.Corners) end
                    if espHealth then
                        local x=br.X+5
                        s.HealthBack.Position=UDim2.fromOffset(x,tl.Y); s.HealthBack.Size=UDim2.fromOffset(4,h); s.HealthBack.Visible=true
                        s.Health.Position=UDim2.fromOffset(x+1,tl.Y+1+(h-2)*(1-ratio)); s.Health.Size=UDim2.fromOffset(2,(h-2)*ratio); s.HealthGradient.Color=healthSequence(); s.Health.Visible=true
                        s.HealthText.Position=UDim2.fromOffset(x+8,tl.Y+h*(1-ratio)-8); s.HealthText.Text=tostring(math.floor(hum.Health)); s.HealthText.Visible=espHealthText
                    else
                        s.HealthBack.Visible=false; s.Health.Visible=false; s.HealthText.Visible=false
                    end
                    if espNames then
                        s.Name.Position=UDim2.fromOffset((tl.X+br.X)/2-95,tl.Y-18)
                        s.Name.Text=readableName(model,hum).." ["..math.floor(dist).."]"
                        s.Name.Visible=true
                    else s.Name.Visible=false end
                else
                    s.Fill.Visible=false
                    if not cornerEnabled and not thermalCornerEnabled then hideLines(s.Corners) end
                    if not healthEnabled then s.HealthBack.Visible=false; s.Health.Visible=false; s.HealthText.Visible=false end
                    if not namesEnabled then s.Name.Visible=false end
                end

                if chamsEnabled then
                    local wave=(math.sin(os.clock()*2.4)+1)/2
                    s.Highlight.Adornee=model; s.Highlight.Enabled=true
                    s.Highlight.FillColor=occluded and occludedColor or chamsFill
                    s.Highlight.OutlineColor=occluded and occludedColor or chamsOutline
                    s.Highlight.FillTransparency=math.clamp(chamsFillTransparency+(chamsThermal and (wave-.5)*.14 or 0),0,1)
                    s.Highlight.OutlineTransparency=math.clamp(chamsOutlineTransparency+(chamsThermal and (wave-.5)*.08 or 0),0,1)
                else s.Highlight.Enabled=false end

                if cornerEnabled then drawCorners(s.Corners,tl,br,stateColor,1,0) end

                if thermalCornerEnabled then
                    local hue=(os.clock()*.08)%1
                    local c1=Color3.fromHSV(hue,.42,1)
                    local c2=Color3.fromHSV((hue+.12)%1,.35,1)
                    s.Fill.Position=UDim2.fromOffset(tl.X,tl.Y); s.Fill.Size=UDim2.fromOffset(w,h)
                    s.Fill.BackgroundColor3=Color3.new(1,1,1); s.Fill.BackgroundTransparency=.78
                    s.FillGradient.Enabled=true
                    s.FillGradient.Color=ColorSequence.new(c1,c2)
                    s.FillGradient.Offset=Vector2.new(math.sin(os.clock()*.8)*.25,0)
                    s.Fill.Visible=true
                    drawCorners(s.Corners,tl,br,stateColor,1,0)
                elseif not espEnabled then
                    s.FillGradient.Enabled=false
                    if not cornerEnabled then s.Fill.Visible=false end
                end

                if healthEnabled and not espEnabled then
                    local x=br.X+7
                    s.HealthBack.Position=UDim2.fromOffset(x,tl.Y); s.HealthBack.Size=UDim2.fromOffset(4,h); s.HealthBack.Visible=true
                    s.Health.Position=UDim2.fromOffset(x+1,tl.Y+1+(h-2)*(1-ratio)); s.Health.Size=UDim2.fromOffset(2,(h-2)*ratio); s.HealthGradient.Color=healthSequence(); s.Health.Visible=true
                    s.HealthText.Position=UDim2.fromOffset(x+8,tl.Y+h*(1-ratio)-8); s.HealthText.Text=tostring(math.floor(hum.Health)); s.HealthText.Visible=espHealthText
                end
                if namesEnabled and not espEnabled then
                    s.Name.Position=UDim2.fromOffset((tl.X+br.X)/2-95,tl.Y-18)
                    s.Name.Text=readableName(model,hum).." ["..math.floor(dist).."]"
                    s.Name.Visible=true
                end
                if skeletonEnabled then drawSkeleton(s,model) else hideLines(s.Skeleton) end
                if tracersEnabled then setLine(s.Tracer,tracerStart(),Vector2.new((tl.X+br.X)/2,br.Y),tracerThickness,tracerColor,tracerTransparency) else s.Tracer.Visible=false end
                if box3DEnabled then draw3D(s,cf,size) else hideLines(s.Box3D) end
            end
        end
    end
end)
