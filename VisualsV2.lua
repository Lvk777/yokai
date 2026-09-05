-- Yokai Visuals V2
-- Integrates the requested visual modules into a dedicated "Visuals" window.
-- Uses only locally available replicated state and does not call remotes.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local Utility = objects["UtilityWindow"] and objects["UtilityWindow"]["Api"]
local World = objects["WorldWindow"] and objects["WorldWindow"]["Api"]
local Render = objects["RenderWindow"] and objects["RenderWindow"]["Api"]

if not (Utility and World and Render) then
    warn("VisualsV2: Yokai windows were not found")
    return
end

local function notify(title, text)
    pcall(function()
        GuiLibrary["CreateNotification"](title, text, 3)
    end)
end

local function removeModule(name)
    local key = name .. "OptionsButton"
    local obj = objects[key]
    if not obj then return end

    pcall(function()
        local api = obj["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then
            api["ToggleButton"](false)
        end
    end)

    pcall(function()
        GuiLibrary["RemoveObject"](key)
    end)
end

for _, name in ipairs({
    "ESP", "Chams", "Health", "Name", "Distance", "Box", "Tracers",
    "Arrows", "Breadcrumbs", "LocalChams", "LocalInventoryViewer",
    "FOV", "FOVChanger", "Night", "Brightness", "ChangeSkydome", "HitSound"
}) do
    removeModule(name)
end

local Visuals = GuiLibrary.CreateWindow({
    ["Name"] = "Visuals",
    ["Icon"] = "yokai/assets/RenderIcon.png",
    ["IconSize"] = 17,
})
pcall(function() Visuals.SetVisible(false) end)

local visualsVisible = false
local function setLabelText(root, text)
    if not root then return end
    if root:IsA("TextButton") or root:IsA("TextLabel") then
        if root.Text == "Render" or root.Text == "World" or root.Text == "Utility" then root.Text = text end
    end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("TextLabel") then
            if desc.Text == "Render" or desc.Text == "World" or desc.Text == "Utility" then desc.Text = text end
        end
    end
end

local function createVisualsMainButton()
    if objects["VisualsButton"] and objects["VisualsButton"]["Object"] then return end
    local template = objects["RenderButton"] or objects["WorldButton"] or objects["UtilityButton"]
    local templateObject = template and template["Object"]
    if not templateObject then return end

    local button = templateObject:Clone()
    button.Name = "VisualsButton"
    button.LayoutOrder = templateObject.LayoutOrder + 1
    setLabelText(button, "Visuals")
    button.Parent = templateObject.Parent

    local api = {Enabled = false}
    api.ToggleButton = function(state)
        if state == nil then state = not visualsVisible end
        visualsVisible = state
        pcall(function() Visuals.SetVisible(state) end)
    end
    button.MouseButton1Click:Connect(function() api.ToggleButton(not visualsVisible) end)
    objects["VisualsButton"] = {Type = "ButtonMain", Object = button, Api = api}
end

task.defer(createVisualsMainButton)

local overlay = Instance.new("ScreenGui")
overlay.Name = "YokaiVisualsV2Overlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 998
pcall(function() overlay.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not overlay.Parent then overlay.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function newFrame(parent, color, transparency)
    local frame = Instance.new("Frame")
    frame.BorderSizePixel = 0
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
    frame.BackgroundTransparency = transparency or 0
    frame.Visible = false
    frame.Parent = parent or overlay
    return frame
end

local function setLine(line, a, b, thickness, color)
    if not line or not a or not b then if line then line.Visible = false end return end
    local delta = b - a
    local length = delta.Magnitude
    if length < 0.01 then line.Visible = false return end
    line.Size = UDim2.fromOffset(length, thickness or 1)
    line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    if color then line.BackgroundColor3 = color end
    line.Visible = true
end

local function newLabel(parent)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Size = UDim2.fromOffset(180, 20)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.RichText = true
    label.Visible = false
    label.Parent = parent or overlay
    return label
end

local visual = {
    TeamCheck = false,
    MaxDistance = 200,
    Chams = false,
    ChamsThermal = true,
    ChamsVisibleCheck = false,
    ChamsColor = Color3.fromRGB(119, 120, 255),
    Box = false,
    BoxMode = "Corner",
    BoxLineColor = Color3.fromRGB(255, 255, 255),
    BoxFillColor = Color3.fromRGB(119, 120, 255),
    BoxThickness = 1,
    Health = false,
    HealthText = true,
    Name = false,
    Distance = false,
    NameColor = Color3.fromRGB(255, 255, 255),
    DistanceColor = Color3.fromRGB(255, 255, 255),
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    Tracers = false,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerThickness = 1,
    TracerOrigin = "Bottom",
    Arrows = false,
    ArrowColor = Color3.fromRGB(255, 255, 255),
    ArrowSize = 8,
    ArrowThickness = 1,
}

local packs = {}
local function createPack(plr)
    local pack = {
        player = plr,
        chams = Instance.new("Highlight"),
        fill = newFrame(),
        corners = {},
        box3d = {},
        healthBack = newFrame(nil, Color3.new(0, 0, 0), 0),
        health = newFrame(),
        healthText = newLabel(),
        name = newLabel(),
        distance = newLabel(),
        skeleton = {},
        tracer = newFrame(),
        arrowA = newFrame(),
        arrowB = newFrame(),
    }
    pack.chams.Name = "YokaiVisualsChams_" .. plr.Name
    pack.chams.FillColor = visual.ChamsColor
    pack.chams.OutlineColor = visual.ChamsColor
    pack.chams.FillTransparency = 0.5
    pack.chams.OutlineTransparency = 0
    pack.chams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    pack.chams.Enabled = false
    pack.chams.Parent = overlay
    for i = 1, 8 do pack.corners[i] = newFrame() end
    for i = 1, 12 do pack.box3d[i] = newFrame() end
    for i = 1, 14 do pack.skeleton[i] = newFrame() end
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = -90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 60, 125)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(119, 120, 255)),
    })
    gradient.Parent = pack.health
    packs[plr] = pack
    return pack
end

local function destroyPack(plr)
    local pack = packs[plr]
    if not pack then return end
    pcall(function() pack.chams:Destroy() end)
    for _, obj in pairs(pack) do
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        elseif type(obj) == "table" then
            for _, child in ipairs(obj) do
                if typeof(child) == "Instance" then pcall(function() child:Destroy() end) end
            end
        end
    end
    packs[plr] = nil
end
Players.PlayerRemoving:Connect(destroyPack)

local function hidePack(pack)
    if not pack then return end
    pack.chams.Enabled = false
    pack.fill.Visible = false
    pack.healthBack.Visible = false
    pack.health.Visible = false
    pack.healthText.Visible = false
    pack.name.Visible = false
    pack.distance.Visible = false
    pack.tracer.Visible = false
    pack.arrowA.Visible = false
    pack.arrowB.Visible = false
    for _, obj in ipairs(pack.corners) do obj.Visible = false end
    for _, obj in ipairs(pack.box3d) do obj.Visible = false end
    for _, obj in ipairs(pack.skeleton) do obj.Visible = false end
end

local function sameTeam(plr)
    return visual.TeamCheck and LocalPlayer.Team ~= nil and plr.Team ~= nil and LocalPlayer.Team == plr.Team
end

local function isVisibleCharacter(char, worldPosition)
    if not Camera then return false end
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, worldPosition - origin, params)
    return result == nil or (result.Instance and result.Instance:IsDescendantOf(char))
end

local friendCache = {}
local function friendPrefix(plr)
    local cached = friendCache[plr.UserId]
    if cached == nil then
        cached = false
        pcall(function() cached = LocalPlayer:IsFriendsWith(plr.UserId) end)
        friendCache[plr.UserId] = cached
    end
    if cached then return '(<font color="rgb(0,255,0)">F</font>)' end
    return '(<font color="rgb(255,0,0)">E</font>)'
end

local skeletonR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local skeletonR6 = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}}
local boxEdges = {{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}

local function get3DCorners(cf, size)
    local corners = {}
    local half = size / 2
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                table.insert(corners, (cf * CFrame.new(half * Vector3.new(x, y, z))).Position)
            end
        end
    end
    return corners
end

local function drawCorners(pack, x, y, w, h)
    local thickness = visual.BoxThickness
    local cornerW = math.max(4, w / 5)
    local cornerH = math.max(4, h / 5)
    local c = pack.corners
    local function place(frame, px, py, sx, sy, anchor)
        frame.AnchorPoint = anchor or Vector2.zero
        frame.Position = UDim2.fromOffset(px, py)
        frame.Size = UDim2.fromOffset(sx, sy)
        frame.BackgroundColor3 = visual.BoxLineColor
        frame.Visible = true
    end
    place(c[1], x - w/2, y - h/2, cornerW, thickness)
    place(c[2], x - w/2, y - h/2, thickness, cornerH)
    place(c[3], x + w/2, y - h/2, cornerW, thickness, Vector2.new(1, 0))
    place(c[4], x + w/2 - thickness, y - h/2, thickness, cornerH)
    place(c[5], x - w/2, y + h/2, thickness, cornerH, Vector2.new(0, 1))
    place(c[6], x - w/2, y + h/2, cornerW, thickness, Vector2.new(0, 1))
    place(c[7], x + w/2, y + h/2, thickness, cornerH, Vector2.new(1, 1))
    place(c[8], x + w/2, y + h/2, cornerW, thickness, Vector2.new(1, 1))
end

local function hideCornerAnd3D(pack)
    for _, obj in ipairs(pack.corners) do obj.Visible = false end
    for _, obj in ipairs(pack.box3d) do obj.Visible = false end
end

local function draw3DBox(pack, root)
    local corners = get3DCorners(root.CFrame * CFrame.new(0, -0.5, 0), Vector3.new(3, 5, 3))
    local points = {}
    for i, corner in ipairs(corners) do
        local p, onScreen = Camera:WorldToViewportPoint(corner)
        if not onScreen or p.Z <= 0 then
            for _, obj in ipairs(pack.box3d) do obj.Visible = false end
            return
        end
        points[i] = Vector2.new(p.X, p.Y)
    end
    for i, edge in ipairs(boxEdges) do
        setLine(pack.box3d[i], points[edge[1]], points[edge[2]], visual.BoxThickness, visual.BoxLineColor)
    end
end

local function drawSkeleton(pack, char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local bones = hum and hum.RigType == Enum.HumanoidRigType.R6 and skeletonR6 or skeletonR15
    for i, line in ipairs(pack.skeleton) do
        local bone = bones[i]
        if not bone then
            line.Visible = false
        else
            local a = char:FindFirstChild(bone[1])
            local b = char:FindFirstChild(bone[2])
            if a and b then
                local p1, v1 = Camera:WorldToViewportPoint(a.Position)
                local p2, v2 = Camera:WorldToViewportPoint(b.Position)
                if v1 and v2 and p1.Z > 0 and p2.Z > 0 then
                    setLine(line, Vector2.new(p1.X, p1.Y), Vector2.new(p2.X, p2.Y), 1, visual.SkeletonColor)
                else line.Visible = false end
            else line.Visible = false end
        end
    end
end

local function drawArrow(pack, rootPosition)
    if not Camera then return end
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local p = Camera:WorldToViewportPoint(rootPosition)
    local direction = Vector2.new(p.X, p.Y) - center
    if p.Z < 0 then direction = -direction end
    if direction.Magnitude < 0.01 then pack.arrowA.Visible = false pack.arrowB.Visible = false return end
    direction = direction.Unit
    local radius = math.max(50, math.min(viewport.X, viewport.Y) * 0.43)
    local tip = center + direction * radius
    local angle = math.atan2(direction.Y, direction.X)
    local wingAngle = math.rad(32)
    local size = visual.ArrowSize
    local a = tip - Vector2.new(math.cos(angle - wingAngle), math.sin(angle - wingAngle)) * size
    local b = tip - Vector2.new(math.cos(angle + wingAngle), math.sin(angle + wingAngle)) * size
    setLine(pack.arrowA, tip, a, visual.ArrowThickness, visual.ArrowColor)
    setLine(pack.arrowB, tip, b, visual.ArrowThickness, visual.ArrowColor)
end

local function anyEspEnabled()
    return visual.Chams or visual.Box or visual.Health or visual.Name or visual.Distance or visual.Skeleton or visual.Tracers or visual.Arrows
end

RunService.RenderStepped:Connect(function()
    if not anyEspEnabled() or not Camera then
        for _, pack in pairs(packs) do hidePack(pack) end
        return
    end
    local viewport = Camera.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local pack = packs[plr] or createPack(plr)
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (char and root and hum and hum.Health > 0) or sameTeam(plr) then hidePack(pack) continue end
            local distanceStuds = (Camera.CFrame.Position - root.Position).Magnitude
            if distanceStuds > visual.MaxDistance then hidePack(pack) continue end
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local screen = Vector2.new(pos.X, pos.Y)

            if visual.Chams and (not visual.ChamsVisibleCheck or isVisibleCharacter(char, root.Position)) then
                pack.chams.Adornee = char
                pack.chams.Enabled = true
                pack.chams.FillColor = visual.ChamsColor
                pack.chams.OutlineColor = visual.ChamsColor
                if visual.ChamsThermal then
                    local breathe = (math.sin(os.clock() * 2) + 1) / 2
                    pack.chams.FillTransparency = 0.35 + breathe * 0.35
                    pack.chams.OutlineTransparency = 0.05 + breathe * 0.25
                else
                    pack.chams.FillTransparency = 0.55
                    pack.chams.OutlineTransparency = 0
                end
            else pack.chams.Enabled = false end

            if onScreen and pos.Z > 0 then
                pack.arrowA.Visible = false
                pack.arrowB.Visible = false
                local scaleFactor = (root.Size.Y * Camera.ViewportSize.Y) / (pos.Z * 2)
                local w, h = 3 * scaleFactor, 4.5 * scaleFactor

                if visual.Box then
                    if visual.BoxMode == "3D" then
                        pack.fill.Visible = false
                        for _, obj in ipairs(pack.corners) do obj.Visible = false end
                        draw3DBox(pack, root)
                    else
                        for _, obj in ipairs(pack.box3d) do obj.Visible = false end
                        drawCorners(pack, screen.X, screen.Y, w, h)
                        if visual.BoxMode == "Thermal" then
                            pack.fill.AnchorPoint = Vector2.new(0.5, 0.5)
                            pack.fill.Position = UDim2.fromOffset(screen.X, screen.Y)
                            pack.fill.Size = UDim2.fromOffset(w, h)
                            pack.fill.BackgroundColor3 = visual.BoxFillColor
                            local breathe = (math.sin(os.clock() * 2) + 1) / 2
                            pack.fill.BackgroundTransparency = 0.5 + breathe * 0.3
                            pack.fill.Visible = true
                        else pack.fill.Visible = false end
                    end
                else
                    pack.fill.Visible = false
                    hideCornerAnd3D(pack)
                end

                if visual.Health then
                    local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                    local barX = screen.X - w/2 - 6
                    pack.healthBack.AnchorPoint = Vector2.new(0, 0)
                    pack.healthBack.Position = UDim2.fromOffset(barX, screen.Y - h/2)
                    pack.healthBack.Size = UDim2.fromOffset(2.5, h)
                    pack.healthBack.Visible = true
                    pack.health.AnchorPoint = Vector2.new(0, 0)
                    pack.health.Position = UDim2.fromOffset(barX, screen.Y - h/2 + h * (1 - ratio))
                    pack.health.Size = UDim2.fromOffset(2.5, h * ratio)
                    pack.health.BackgroundColor3 = Color3.new(1, 1, 1)
                    pack.health.Visible = true
                    if visual.HealthText and hum.Health < hum.MaxHealth then
                        pack.healthText.Position = UDim2.fromOffset(barX - 12, screen.Y - h/2 + h * (1 - ratio))
                        pack.healthText.Text = tostring(math.floor(ratio * 100))
                        pack.healthText.TextColor3 = Color3.fromRGB(119, 120, 255)
                        pack.healthText.Visible = true
                    else pack.healthText.Visible = false end
                else
                    pack.healthBack.Visible = false
                    pack.health.Visible = false
                    pack.healthText.Visible = false
                end

                if visual.Name then
                    pack.name.Position = UDim2.fromOffset(screen.X, screen.Y - h/2 - 15)
                    pack.name.Text = string.format("%s %s", friendPrefix(plr), plr.Name)
                    pack.name.TextColor3 = visual.NameColor
                    pack.name.Visible = true
                else pack.name.Visible = false end

                if visual.Distance then
                    pack.distance.Position = UDim2.fromOffset(screen.X, screen.Y + h/2 + 8)
                    pack.distance.Text = string.format("%d studs", math.floor(distanceStuds))
                    pack.distance.TextColor3 = visual.DistanceColor
                    pack.distance.Visible = true
                else pack.distance.Visible = false end

                if visual.Skeleton then drawSkeleton(pack, char) else for _, obj in ipairs(pack.skeleton) do obj.Visible = false end end
                if visual.Tracers then
                    local origin = visual.TracerOrigin == "Center" and Vector2.new(viewport.X / 2, viewport.Y / 2) or Vector2.new(viewport.X / 2, viewport.Y - 2)
                    setLine(pack.tracer, origin, screen, visual.TracerThickness, visual.TracerColor)
                else pack.tracer.Visible = false end
            else
                pack.fill.Visible = false
                pack.healthBack.Visible = false
                pack.health.Visible = false
                pack.healthText.Visible = false
                pack.name.Visible = false
                pack.distance.Visible = false
                pack.tracer.Visible = false
                hideCornerAnd3D(pack)
                for _, obj in ipairs(pack.skeleton) do obj.Visible = false end
                if visual.Arrows then drawArrow(pack, root.Position) else pack.arrowA.Visible = false pack.arrowB.Visible = false end
            end
        end
    end
end)

local TeamCheck = Visuals.CreateOptionsButton({["Name"] = "TeamCheck", ["Function"] = function(v) visual.TeamCheck = v end})
local VisualRange = Visuals.CreateOptionsButton({["Name"] = "ESPRange", ["Function"] = function() end})
VisualRange.CreateSlider({["Name"] = "Max Distance", ["Min"] = 50, ["Max"] = 1000, ["Default"] = 200, ["Function"] = function(v) visual.MaxDistance = v end})

local Chams = Visuals.CreateOptionsButton({["Name"] = "Chams", ["Function"] = function(v) visual.Chams = v end})
Chams.CreateToggle({["Name"] = "Thermal", ["Default"] = true, ["Function"] = function(v) visual.ChamsThermal = v end})
Chams.CreateToggle({["Name"] = "Visible Check", ["Default"] = false, ["Function"] = function(v) visual.ChamsVisibleCheck = v end})
Chams.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.ChamsColor = Color3.fromHSV(h,s,v) end})

local Box = Visuals.CreateOptionsButton({["Name"] = "Box", ["Function"] = function(v) visual.Box = v end})
Box.CreateDropdown({["Name"] = "Mode", ["List"] = {"Corner", "Thermal", "3D"}, ["Function"] = function(v) visual.BoxMode = v end})
Box.CreateColorSlider({["Name"] = "Line Color", ["Function"] = function(h,s,v) visual.BoxLineColor = Color3.fromHSV(h,s,v) end})
Box.CreateColorSlider({["Name"] = "Fill Color", ["Function"] = function(h,s,v) visual.BoxFillColor = Color3.fromHSV(h,s,v) end})
Box.CreateSlider({["Name"] = "Thickness", ["Min"] = 1, ["Max"] = 4, ["Default"] = 1, ["Function"] = function(v) visual.BoxThickness = v end})

local Health = Visuals.CreateOptionsButton({["Name"] = "Health", ["Function"] = function(v) visual.Health = v end})
Health.CreateToggle({["Name"] = "Health Text", ["Default"] = true, ["Function"] = function(v) visual.HealthText = v end})
local NameESP = Visuals.CreateOptionsButton({["Name"] = "Name", ["Function"] = function(v) visual.Name = v end})
NameESP.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.NameColor = Color3.fromHSV(h,s,v) end})
local DistanceESP = Visuals.CreateOptionsButton({["Name"] = "Distance", ["Function"] = function(v) visual.Distance = v end})
DistanceESP.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.DistanceColor = Color3.fromHSV(h,s,v) end})
local Skeleton = Visuals.CreateOptionsButton({["Name"] = "Skeleton", ["Function"] = function(v) visual.Skeleton = v end})
Skeleton.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.SkeletonColor = Color3.fromHSV(h,s,v) end})
local Tracers = Visuals.CreateOptionsButton({["Name"] = "Tracers", ["Function"] = function(v) visual.Tracers = v end})
Tracers.CreateDropdown({["Name"] = "Origin", ["List"] = {"Bottom", "Center"}, ["Function"] = function(v) visual.TracerOrigin = v end})
Tracers.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.TracerColor = Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"] = "Thickness", ["Min"] = 1, ["Max"] = 4, ["Default"] = 1, ["Function"] = function(v) visual.TracerThickness = v end})
local Arrows = Visuals.CreateOptionsButton({["Name"] = "Arrows", ["Function"] = function(v) visual.Arrows = v end})
Arrows.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) visual.ArrowColor = Color3.fromHSV(h,s,v) end})
Arrows.CreateSlider({["Name"] = "Size", ["Min"] = 5, ["Max"] = 18, ["Default"] = 8, ["Function"] = function(v) visual.ArrowSize = v end})
Arrows.CreateSlider({["Name"] = "Thickness", ["Min"] = 1, ["Max"] = 3, ["Default"] = 1, ["Function"] = function(v) visual.ArrowThickness = v end})

local selfChamsEnabled = false
local selfChamsMaterial = "ForceField"
local selfChamsColor = Color3.fromRGB(255, 110, 190)
local selfChamsTransparency = 0.2
local selfState = {}
local materials = {ForceField = Enum.Material.ForceField, Neon = Enum.Material.Neon, SmoothPlastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, Foil = Enum.Material.Foil, Metal = Enum.Material.Metal, Plastic = Enum.Material.Plastic}

local function rememberSelfPart(part)
    if selfState[part] then return end
    local state = {Material = part.Material, Color = part.Color, LocalTransparencyModifier = part.LocalTransparencyModifier}
    if part:IsA("MeshPart") then state.TextureID = part.TextureID end
    local special = part:FindFirstChildOfClass("SpecialMesh")
    if special then state.SpecialMesh = special state.SpecialTextureId = special.TextureId end
    selfState[part] = state
end

local function restoreSelfChams()
    for part, state in pairs(selfState) do
        if part and part.Parent then
            pcall(function()
                part.Material = state.Material
                part.Color = state.Color
                part.LocalTransparencyModifier = state.LocalTransparencyModifier
                if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
                if state.SpecialMesh and state.SpecialMesh.Parent then state.SpecialMesh.TextureId = state.SpecialTextureId or "" end
            end)
        end
    end
    table.clear(selfState)
end

local function applySelfChams()
    local char = LocalPlayer.Character
    if not char then return end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and not desc:FindFirstAncestorWhichIsA("Tool") then
            rememberSelfPart(desc)
            desc.Material = materials[selfChamsMaterial] or Enum.Material.ForceField
            desc.Color = selfChamsColor
            desc.LocalTransparencyModifier = selfChamsTransparency
            if desc:IsA("MeshPart") then desc.TextureID = "" end
            local special = desc:FindFirstChildOfClass("SpecialMesh")
            if special then special.TextureId = "" end
        end
    end
end

local SelfChams = Visuals.CreateOptionsButton({["Name"] = "SelfChams", ["Function"] = function(v) selfChamsEnabled = v if v then applySelfChams() else restoreSelfChams() end end})
SelfChams.CreateDropdown({["Name"] = "Material", ["List"] = {"ForceField", "Neon", "SmoothPlastic", "Glass", "Foil", "Metal", "Plastic"}, ["Function"] = function(v) selfChamsMaterial = v if selfChamsEnabled then applySelfChams() end end})
SelfChams.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) selfChamsColor = Color3.fromHSV(h,s,v) if selfChamsEnabled then applySelfChams() end end})
SelfChams.CreateSlider({["Name"] = "Transparency", ["Min"] = 0, ["Max"] = 100, ["Default"] = 20, ["Function"] = function(v) selfChamsTransparency = math.clamp(v / 100, 0, 1) if selfChamsEnabled then applySelfChams() end end})
LocalPlayer.CharacterAdded:Connect(function() table.clear(selfState) task.wait(0.4) if selfChamsEnabled then applySelfChams() end end)

local trailEnabled = false
local trailGlow = false
local trailColor = Color3.fromRGB(119, 120, 255)
local trailSize = 0.16
local trailLifetime = 2.5
local trailTimer = 0
local trailParts = {}
local function clearTrail()
    for part in pairs(trailParts) do if part and part.Parent then part:Destroy() end end
    table.clear(trailParts)
end
local function spawnTrailPoint(position)
    local part = Instance.new("Part")
    part.Name = "YokaiTrailPoint"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(trailSize, trailSize, trailSize)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Color = trailColor
    part.Material = trailGlow and Enum.Material.Neon or Enum.Material.SmoothPlastic
    part.Transparency = trailGlow and 0.05 or 0.2
    part.CFrame = CFrame.new(position)
    part.Parent = Workspace
    if trailGlow then
        local light = Instance.new("PointLight")
        light.Color = trailColor
        light.Brightness = 0.7
        light.Range = 3
        light.Shadows = false
        light.Parent = part
    end
    trailParts[part] = true
    task.delay(trailLifetime, function() trailParts[part] = nil if part and part.Parent then part:Destroy() end end)
end
RunService.Heartbeat:Connect(function(dt)
    if not trailEnabled then return end
    trailTimer += dt
    if trailTimer < 0.09 then return end
    trailTimer = 0
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then spawnTrailPoint(root.Position - Vector3.new(0, 2.4, 0)) end
end)
local Trail = Visuals.CreateOptionsButton({["Name"] = "Trail", ["Function"] = function(v) trailEnabled = v if not v then clearTrail() end end})
Trail.CreateToggle({["Name"] = "Glowing", ["Default"] = false, ["Function"] = function(v) trailGlow = v end})
Trail.CreateColorSlider({["Name"] = "Color", ["Function"] = function(h,s,v) trailColor = Color3.fromHSV(h,s,v) end})
Trail.CreateSlider({["Name"] = "Size", ["Min"] = 5, ["Max"] = 40, ["Default"] = 16, ["Function"] = function(v) trailSize = v / 100 end})
Trail.CreateSlider({["Name"] = "Lifetime", ["Min"] = 5, ["Max"] = 60, ["Default"] = 25, ["Function"] = function(v) trailLifetime = v / 10 end})

local fovEnabled = false
local fovValue = 70
local originalFov = setmetatable({}, {__mode = "k"})
local function applyFov()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if originalFov[cam] == nil then originalFov[cam] = cam.FieldOfView end
    cam.FieldOfView = fovEnabled and math.clamp(fovValue, 40, 120) or (originalFov[cam] or 70)
end
local FOVChanger = Visuals.CreateOptionsButton({["Name"] = "FOVChanger", ["Function"] = function(v) fovEnabled = v applyFov() end})
FOVChanger.CreateSlider({["Name"] = "FOV", ["Min"] = 40, ["Max"] = 120, ["Default"] = 70, ["Function"] = function(v) fovValue = v if fovEnabled then applyFov() end end})
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.wait() applyFov() end)

local noMenuFog = false
local function applyMenuFog()
    pcall(function()
        if GuiLibrary["MainBlur"] then GuiLibrary["MainBlur"].Size = noMenuFog and 0 or 25 end
        local clickGui = GuiLibrary["MainGui"] and GuiLibrary["MainGui"]:FindFirstChild("ClickGui", true)
        if clickGui and clickGui.Visible then RunService:SetRobloxGuiFocused(not noMenuFog) elseif noMenuFog then RunService:SetRobloxGuiFocused(false) end
    end)
end
local NoMenuFog = Visuals.CreateOptionsButton({["Name"] = "NoMenuFog", ["Function"] = function(v) noMenuFog = v applyMenuFog() end})

local previewGui
local previewEnabled = false
local function buildPreview()
    if previewGui and previewGui.Parent then return end
    previewGui = Instance.new("ScreenGui")
    previewGui.Name = "YokaiVisualPreview"
    previewGui.ResetOnSpawn = false
    previewGui.IgnoreGuiInset = true
    previewGui.DisplayOrder = 997
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(1,0)
    frame.Position = UDim2.new(1,-18,0,78)
    frame.Size = UDim2.fromOffset(230,310)
    frame.BackgroundColor3 = Color3.fromRGB(16,16,19)
    frame.BackgroundTransparency = 0.04
    frame.BorderSizePixel = 0
    frame.Parent = previewGui
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,8) corner.Parent = frame
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(65,65,74) stroke.Transparency = 0.25 stroke.Parent = frame
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(12,8)
    title.Size = UDim2.new(1,-24,0,24)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(235,235,240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Visuals Preview"
    title.Parent = frame
    local canvas = Instance.new("Frame")
    canvas.Position = UDim2.fromOffset(14,40)
    canvas.Size = UDim2.new(1,-28,1,-54)
    canvas.BackgroundColor3 = Color3.fromRGB(22,22,26)
    canvas.BorderSizePixel = 0
    canvas.Parent = frame
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,6) cc.Parent = canvas
    local name = newLabel(canvas) name.Position = UDim2.new(0.5,0,0,18) name.Text = "(E) Player" name.Visible = true
    local dist = newLabel(canvas) dist.Position = UDim2.new(0.5,0,1,-16) dist.Text = "87 studs" dist.Visible = true
    local function body(pos,size)
        local p = Instance.new("Frame") p.AnchorPoint = Vector2.new(0.5,0.5) p.Position = pos p.Size = size p.BorderSizePixel = 0 p.BackgroundColor3 = Color3.fromRGB(119,120,255) p.BackgroundTransparency = 0.18 p.Parent = canvas
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,5) c.Parent = p
    end
    body(UDim2.new(0.5,0,0.27,0),UDim2.fromOffset(34,34))
    body(UDim2.new(0.5,0,0.49,0),UDim2.fromOffset(48,76))
    body(UDim2.new(0.35,0,0.49,0),UDim2.fromOffset(16,72))
    body(UDim2.new(0.65,0,0.49,0),UDim2.fromOffset(16,72))
    body(UDim2.new(0.44,0,0.76,0),UDim2.fromOffset(18,76))
    body(UDim2.new(0.56,0,0.76,0),UDim2.fromOffset(18,76))
    previewGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
local Preview = Visuals.CreateOptionsButton({["Name"] = "Preview", ["Function"] = function(v) previewEnabled = v buildPreview() previewGui.Enabled = v end})

local savedLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    ExposureCompensation = Lighting.ExposureCompensation,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
}
local savedSkies = {}
for _, child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then table.insert(savedSkies, child:Clone()) end end
local nightEnabled = false
local brightnessEnabled = false
local brightnessValue = 3
local exposureValue = 0.35
local skydomeEnabled = false
local skydomePreset = "Night Sky"
local skyPresets = {
    ["Purple Nebula"] = {"159454299","159454296","159454293","159454286","159454300","159454288"},
    ["Blue Daylight"] = {"271042516","271077243","271042556","271042310","271042467","271077958"},
    ["Night Sky"] = {"12064107","12064152","12064121","12063984","12064115","12064131"},
    ["Purple Space"] = {"14543264135","14543358958","14543257810","14543275895","14543280890","14543371676"},
    ["Deep Night"] = {"15470149279","15470151245","15470153860","15470155938","15470158022","15470160563"},
    ["Starry Edge"] = {"2570432999","2570433005","2570432998","2570433000","2570432997","2570432996"},
    ["Vaporwave"] = {"8631780182","8631784904","8631769834","8631777199","8631735555","8631782345"},
}
local function clearAllSkies() for _, child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end end
local function restoreSavedSkies() clearAllSkies() for _, sky in ipairs(savedSkies) do sky:Clone().Parent = Lighting end end
local function makeSkyFromPreset(name)
    local ids = skyPresets[name] if not ids then return false end
    clearAllSkies()
    local sky = Instance.new("Sky") sky.Name = "YokaiVisualSky"
    sky.SkyboxBk = "rbxassetid://" .. ids[1] sky.SkyboxDn = "rbxassetid://" .. ids[2] sky.SkyboxFt = "rbxassetid://" .. ids[3]
    sky.SkyboxLf = "rbxassetid://" .. ids[4] sky.SkyboxRt = "rbxassetid://" .. ids[5] sky.SkyboxUp = "rbxassetid://" .. ids[6]
    sky.Parent = Lighting return true
end
local function makeBlackSky()
    clearAllSkies()
    local sky = Instance.new("Sky")
    sky.Name = "YokaiBlackNightSky"
    sky.CelestialBodiesShown = false sky.StarCount = 0 sky.MoonAngularSize = 0 sky.SunAngularSize = 0
    sky.SkyboxBk = "" sky.SkyboxDn = "" sky.SkyboxFt = "" sky.SkyboxLf = "" sky.SkyboxRt = "" sky.SkyboxUp = ""
    sky.Parent = Lighting
end
local function applyWorldVisuals()
    if nightEnabled then
        makeBlackSky()
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(205,205,205)
        Lighting.OutdoorAmbient = Color3.fromRGB(185,185,185)
        Lighting.ColorShift_Top = Color3.new(0,0,0)
        Lighting.ColorShift_Bottom = Color3.new(0,0,0)
        Lighting.Brightness = brightnessEnabled and brightnessValue or math.max(savedLighting.Brightness,3)
        Lighting.ExposureCompensation = savedLighting.ExposureCompensation + (brightnessEnabled and exposureValue or 0.2)
    else
        if skydomeEnabled then makeSkyFromPreset(skydomePreset) else restoreSavedSkies() end
        Lighting.ClockTime = savedLighting.ClockTime
        Lighting.Ambient = savedLighting.Ambient
        Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
        Lighting.ColorShift_Top = savedLighting.ColorShift_Top
        Lighting.ColorShift_Bottom = savedLighting.ColorShift_Bottom
        Lighting.Brightness = brightnessEnabled and brightnessValue or savedLighting.Brightness
        Lighting.ExposureCompensation = savedLighting.ExposureCompensation + (brightnessEnabled and exposureValue or 0)
    end
end
local Night = World.CreateOptionsButton({["Name"] = "Night", ["Function"] = function(v) nightEnabled = v applyWorldVisuals() end})
local Brightness = World.CreateOptionsButton({["Name"] = "Brightness", ["Function"] = function(v) brightnessEnabled = v applyWorldVisuals() end})
Brightness.CreateSlider({["Name"] = "Level", ["Min"] = 1, ["Max"] = 6, ["Default"] = 3, ["Function"] = function(v) brightnessValue = v if brightnessEnabled then applyWorldVisuals() end end})
Brightness.CreateSlider({["Name"] = "Exposure", ["Min"] = 0, ["Max"] = 20, ["Default"] = 4, ["Function"] = function(v) exposureValue = v / 10 if brightnessEnabled then applyWorldVisuals() end end})
local ChangeSkydome = World.CreateOptionsButton({["Name"] = "ChangeSkydome", ["Function"] = function(v) skydomeEnabled = v applyWorldVisuals() end})
ChangeSkydome.CreateDropdown({["Name"] = "Preset", ["List"] = {"Night Sky", "Deep Night", "Purple Space", "Starry Edge", "Purple Nebula", "Vaporwave", "Blue Daylight"}, ["Function"] = function(v) skydomePreset = v if skydomeEnabled and not nightEnabled then applyWorldVisuals() end end})

local hitSoundEnabled = false
local hitSoundVolume = 1
local hitSoundPreset = "Classic"
local hitSounds = {Classic = "rbxassetid://9118823106", ["Preset 1"] = "rbxassetid://136087587949971", ["Preset 2"] = "rbxassetid://118077944456512"}
local watchedHumanoids = setmetatable({}, {__mode = "k"})
local function playHitSound()
    local sound = Instance.new("Sound") sound.Name = "YokaiHitSoundV2" sound.SoundId = hitSounds[hitSoundPreset] or hitSounds.Classic sound.Volume = hitSoundVolume sound.Parent = SoundService sound:Play() Debris:AddItem(sound,4)
end
local function watchHumanoid(plr,char)
    if plr == LocalPlayer then return end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or watchedHumanoids[hum] then return end
    local lastHealth = hum.Health
    watchedHumanoids[hum] = hum.HealthChanged:Connect(function(newHealth) if newHealth < lastHealth and hitSoundEnabled then playHitSound() end lastHealth = newHealth end)
end
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        if plr.Character then watchHumanoid(plr,plr.Character) end
        plr.CharacterAdded:Connect(function(char) task.wait(0.2) watchHumanoid(plr,char) end)
    end
end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function(char) task.wait(0.2) watchHumanoid(plr,char) end) end)
local HitSound = Utility.CreateOptionsButton({["Name"] = "HitSound", ["Function"] = function(v) hitSoundEnabled = v end})
HitSound.CreateDropdown({["Name"] = "Preset", ["List"] = {"Classic", "Preset 1", "Preset 2"}, ["Function"] = function(v) hitSoundPreset = v end})
HitSound.CreateSlider({["Name"] = "Volume", ["Min"] = 1, ["Max"] = 10, ["Default"] = 5, ["Function"] = function(v) hitSoundVolume = v / 5 end})
local HitSoundPreview
HitSoundPreview = Utility.CreateOptionsButton({["Name"] = "HitSoundPreview", ["Function"] = function(v) if v then playHitSound() task.defer(function() pcall(function() HitSoundPreview.ToggleButton(false) end) end) end end})

local inventoryEnabled = false
local inventoryGui
local inventoryTitle
local inventoryText
local inventoryConnection
local inventoryAccumulator = 0
local function getClosestPlayerToMouse()
    if not Camera then return nil end
    local mouse = UserInputService:GetMouseLocation()
    local best,bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local p,onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen and p.Z > 0 then
                    local dist = (Vector2.new(p.X,p.Y)-mouse).Magnitude
                    if dist < 500 and (not bestDist or dist < bestDist) then best,bestDist = plr,dist end
                end
            end
        end
    end
    return best
end
local function ensureInventoryGui()
    if inventoryGui and inventoryGui.Parent then return end
    inventoryGui = Instance.new("ScreenGui") inventoryGui.Name = "YokaiInventoryViewerV2" inventoryGui.ResetOnSpawn = false inventoryGui.DisplayOrder = 997
    local frame = Instance.new("Frame") frame.AnchorPoint = Vector2.new(1,0) frame.Position = UDim2.new(1,-20,0,78) frame.Size = UDim2.fromOffset(350,280) frame.BackgroundColor3 = Color3.fromRGB(15,15,18) frame.BorderSizePixel = 0 frame.Parent = inventoryGui
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,8) corner.Parent = frame
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(70,70,80) stroke.Transparency = 0.25 stroke.Parent = frame
    inventoryTitle = Instance.new("TextLabel") inventoryTitle.BackgroundTransparency = 1 inventoryTitle.Position = UDim2.fromOffset(14,10) inventoryTitle.Size = UDim2.new(1,-28,0,26) inventoryTitle.Font = Enum.Font.Code inventoryTitle.TextSize = 15 inventoryTitle.TextColor3 = Color3.fromRGB(235,235,240) inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left inventoryTitle.Text = "Inventory Viewer" inventoryTitle.Parent = frame
    local sub = Instance.new("TextLabel") sub.BackgroundTransparency = 1 sub.Position = UDim2.fromOffset(14,34) sub.Size = UDim2.new(1,-28,0,18) sub.Font = Enum.Font.Code sub.TextSize = 11 sub.TextColor3 = Color3.fromRGB(130,132,142) sub.TextXAlignment = Enum.TextXAlignment.Left sub.Text = "Aponte o mouse para um player" sub.Parent = frame
    inventoryText = Instance.new("TextLabel") inventoryText.BackgroundTransparency = 1 inventoryText.Position = UDim2.fromOffset(14,62) inventoryText.Size = UDim2.new(1,-28,1,-76) inventoryText.Font = Enum.Font.Code inventoryText.TextSize = 13 inventoryText.TextColor3 = Color3.fromRGB(210,212,218) inventoryText.TextXAlignment = Enum.TextXAlignment.Left inventoryText.TextYAlignment = Enum.TextYAlignment.Top inventoryText.RichText = true inventoryText.Text = "Nenhum player selecionado." inventoryText.Parent = frame
    inventoryGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
local function ammoInfo(container)
    local mag = container:FindFirstChild("BulletsInMagazine",true) or container:FindFirstChild("Ammo",true) or container:FindFirstChild("Magazine",true)
    local reserve = container:FindFirstChild("BulletsInReserve",true) or container:FindFirstChild("Reserve",true)
    local function num(obj) if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then return obj.Value end end
    return num(mag),num(reserve)
end
local function collectReplicatedInventory(plr)
    local items,seen = {},{}
    local function add(name,source,mag,reserve)
        local key = tostring(source).."|"..tostring(name) if seen[key] then return end seen[key] = true table.insert(items,{name=tostring(name),source=source,mag=mag,reserve=reserve})
    end
    local backpack = plr:FindFirstChildOfClass("Backpack")
    if backpack then for _,obj in ipairs(backpack:GetChildren()) do if obj:IsA("Tool") then local m,r=ammoInfo(obj) add(obj.Name,"Backpack",m,r) end end end
    if plr.Character then for _,obj in ipairs(plr.Character:GetChildren()) do if obj:IsA("Tool") then local m,r=ammoInfo(obj) add(obj.Name,"Equipped",m,r) end end end
    local roots = {plr:FindFirstChild("GunInventory"),plr:FindFirstChild("Inventory"),plr:FindFirstChild("Hotbar"),plr:FindFirstChild("Equipment"),plr.Character and plr.Character:FindFirstChild("GunInventory"),plr.Character and plr.Character:FindFirstChild("Inventory"),plr.Character and plr.Character:FindFirstChild("Hotbar"),plr.Character and plr.Character:FindFirstChild("Equipment")}
    for _,root in ipairs(roots) do
        if root then
            for _,obj in ipairs(root:GetDescendants()) do
                if obj:IsA("Tool") then local m,r=ammoInfo(obj) add(obj.Name,root.Name,m,r)
                elseif obj:IsA("ObjectValue") then if obj.Value then local m,r=ammoInfo(obj) add(obj.Value.Name,obj.Name,m,r) end
                elseif obj:IsA("StringValue") and obj.Value ~= "" then local m,r=ammoInfo(obj) add(obj.Value,obj.Name,m,r) end
            end
        end
    end
    table.sort(items,function(a,b) if a.source == b.source then return a.name:lower() < b.name:lower() end return tostring(a.source) < tostring(b.source) end)
    return items
end
local function refreshInventoryViewer()
    if not inventoryEnabled then return end
    ensureInventoryGui()
    local target = getClosestPlayerToMouse()
    if not target then inventoryTitle.Text = "Inventory Viewer" inventoryText.Text = '<font color="rgb(140,142,150)">Aponte o mouse para um player visível.</font>' return end
    inventoryTitle.Text = target.Name .. "'s Inventory"
    local items = collectReplicatedInventory(target)
    if #items == 0 then inventoryText.Text = '<font color="rgb(140,142,150)">Nenhum inventário replicado foi encontrado para este player.</font>' return end
    local lines = {}
    for i,item in ipairs(items) do
        local ammo = "" if item.mag ~= nil or item.reserve ~= nil then ammo = string.format(' <font color="rgb(80,145,255)">[%s/%s]</font>',tostring(item.mag or "--"),tostring(item.reserve or "--")) end
        lines[#lines+1] = string.format('%02d -> <font color="rgb(217,218,219)">%s</font> <font color="rgb(130,132,142)">(%s)</font>%s',i,item.name,item.source,ammo)
        if #lines >= 14 then break end
    end
    inventoryText.Text = table.concat(lines,"\n")
end
local InventoryViewer = Utility.CreateOptionsButton({["Name"] = "InventoryViewer", ["Function"] = function(v)
    inventoryEnabled = v ensureInventoryGui() inventoryGui.Enabled = v
    if inventoryConnection then inventoryConnection:Disconnect() inventoryConnection = nil end
    if v then inventoryAccumulator = 0 refreshInventoryViewer() inventoryConnection = RunService.Heartbeat:Connect(function(dt) inventoryAccumulator += dt if inventoryAccumulator >= 0.25 then inventoryAccumulator = 0 refreshInventoryViewer() end end) end
end})

shared.YokaiVisualsV2Cleanup = function()
    for plr in pairs(packs) do destroyPack(plr) end
    pcall(function() selfChamsEnabled = false restoreSelfChams() end)
    pcall(function() trailEnabled = false clearTrail() end)
    pcall(function() if inventoryConnection then inventoryConnection:Disconnect() end if inventoryGui then inventoryGui:Destroy() end end)
    pcall(function() if previewGui then previewGui:Destroy() end end)
    pcall(function() if overlay then overlay:Destroy() end end)
    pcall(function() fovEnabled = false applyFov() end)
    pcall(function() nightEnabled = false brightnessEnabled = false skydomeEnabled = false applyWorldVisuals() end)
    pcall(function() noMenuFog = false applyMenuFog() end)
end

notify("Visuals", "Visuals V2 carregado.")
