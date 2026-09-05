-- Utility Rejoin + polished safe Preview/Studio visuals.
-- This patch does not add live-player wallcheck behavior.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local VisualsRec = objects["VisualsWindow"]
local UtilityRec = objects["UtilityWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local Utility = UtilityRec and UtilityRec["Api"]
if not Visuals or not Utility then
    warn("UtilityRejoinPreviewPolish: Visuals/Utility missing")
    return
end

local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end

local function isUnder(rec, parentRec)
    if not rec or not rec["Object"] or not parentRec then return false end
    local obj = rec["Object"]
    for _, root in ipairs({parentRec["Object"], parentRec["ChildrenObject"]}) do
        if root and typeof(root) == "Instance" and (obj == root or obj:IsDescendantOf(root)) then
            return true
        end
    end
    return false
end

local function findVisualOption(name)
    local found
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name and isUnder(rec, VisualsRec) then
            found = rec
        end
    end
    return found
end

local function removeOption(name, parentRec)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name then
            if not parentRec or isUnder(rec, parentRec) then table.insert(keys, key) end
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

local function removeSubcontrols(parentRec, names)
    if not parentRec then return end
    local wanted = {}
    for _, name in ipairs(names) do wanted[name] = true end
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Object"] and isUnder(rec, parentRec) then
            local ck = clean(key)
            for name in pairs(wanted) do
                if ck:find(name, 1, true) then
                    table.insert(keys, key)
                    break
                end
            end
        end
    end
    for _, key in ipairs(keys) do pcall(function() GuiLibrary["RemoveObject"](key) end) end
end

-- ============================================================================
-- Utility > Rejoin (one-shot action)
-- ============================================================================
removeOption("Rejoin", UtilityRec)
local Rejoin
Rejoin = Utility.CreateOptionsButton({
    ["Name"] = "Rejoin",
    ["Function"] = function(v)
        if not v then return end
        task.defer(function()
            pcall(function() Rejoin["ToggleButton"](false) end)
            task.wait(0.05)
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
            if not ok then
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
            end
        end)
    end,
    ["HoverText"] = "Reconnects to the current server; falls back to the same place if needed.",
})

-- ============================================================================
-- Preview controls/state
-- ============================================================================
local espRec = findVisualOption("ESP")
local cornerRec = findVisualOption("Corner Box")
local healthRec = findVisualOption("HealthBar")
local nameRec = findVisualOption("Name + Distance")
local tracerRec = findVisualOption("Tracers")
local skeletonRec = findVisualOption("Skeleton")

local sharedState = shared.YokaiVisualPreviewState or {}
sharedState.WallCheck = sharedState.WallCheck == true
sharedState.PreviewState = sharedState.PreviewState or "Visible"
sharedState.DefaultColor = sharedState.DefaultColor or Color3.fromRGB(119,120,255)
sharedState.VisibleColor = sharedState.VisibleColor or Color3.fromRGB(35,235,95)
sharedState.OccludedColor = sharedState.OccludedColor or Color3.fromRGB(245,55,55)
sharedState.TracerOrigin = sharedState.TracerOrigin or "Bottom"
shared.YokaiVisualPreviewState = sharedState

local polish = {
    FillSpin = true,
    FillSpinSpeed = 0.18,
    HealthPalette = "Blue / Red",
}
shared.YokaiPreviewPolishState = polish

removeSubcontrols(cornerRec, {"Fill Spin", "Spin Speed"})
removeSubcontrols(healthRec, {"Palette"})

if cornerRec and cornerRec["Api"] then
    pcall(function()
        cornerRec["Api"].CreateToggle({
            ["Name"] = "Fill Spin",
            ["Default"] = true,
            ["Function"] = function(v) polish.FillSpin = v end,
        })
        cornerRec["Api"].CreateSlider({
            ["Name"] = "Spin Speed",
            ["Min"] = 1,
            ["Max"] = 100,
            ["Default"] = 18,
            ["Function"] = function(v) polish.FillSpinSpeed = v / 100 end,
        })
    end)
end

if healthRec and healthRec["Api"] then
    pcall(function()
        healthRec["Api"].CreateDropdown({
            ["Name"] = "Palette",
            ["List"] = {"Blue / Red", "Mint / Yellow / Red"},
            ["Function"] = function(v) polish.HealthPalette = v end,
        })
    end)
end

-- Replace the previous Preview only. Other Visuals modules are left untouched.
removeOption("Preview", VisualsRec)
removeOption("Attached Preview", VisualsRec)

local function guiRoots()
    local out, seen = {}, {}
    local function add(x)
        if x and typeof(x) == "Instance" and not seen[x] then seen[x] = true table.insert(out, x) end
    end
    add(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    add(CoreGui)
    add(GuiLibrary["MainGui"])
    pcall(function() if gethui then add(gethui()) end end)
    return out
end

for _, root in ipairs(guiRoots()) do
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("ScreenGui") and (
            obj.Name == "YokaiVisualPreviewV4" or obj.Name == "YokaiVisualPreviewV5" or
            obj.Name == "YokaiVisualPreviewV6" or obj.Name == "YokaiVisualPreviewV7" or
            obj.Name == "YokaiAttachedESPPreview"
        ) then pcall(function() obj:Destroy() end) end
    end
end

local function enabled(name)
    local rec = findVisualOption(name)
    local api = rec and rec["Api"]
    return api and api["Enabled"] == true
end

local gui = Instance.new("ScreenGui")
gui.Name = "YokaiVisualPreviewV7"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 997
gui.Enabled = false
pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromOffset(310, 405)
window.Position = UDim2.new(1, -330, 0, 72)
window.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
window.BorderSizePixel = 0
window.Parent = gui
local wc = Instance.new("UICorner") wc.CornerRadius = UDim.new(0, 9) wc.Parent = window
local ws = Instance.new("UIStroke") ws.Color = Color3.fromRGB(62, 64, 72) ws.Transparency = .25 ws.Parent = window

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -28, 0, 25)
title.Font = Enum.Font.Code
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(235, 235, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Visuals Preview"
title.Parent = window

local drag = Instance.new("TextLabel")
drag.BackgroundTransparency = 1
drag.AnchorPoint = Vector2.new(1, 0)
drag.Position = UDim2.new(1, -12, 0, 8)
drag.Size = UDim2.fromOffset(48, 25)
drag.Font = Enum.Font.Code
drag.TextSize = 10
drag.TextColor3 = Color3.fromRGB(120, 122, 132)
drag.Text = "DRAG"
drag.Parent = window

local canvas = Instance.new("Frame")
canvas.Position = UDim2.fromOffset(12, 38)
canvas.Size = UDim2.new(1, -24, 1, -50)
canvas.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
canvas.BorderSizePixel = 0
canvas.ClipsDescendants = true
canvas.Parent = window
local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = canvas

-- Dragging
local dragging = false
local dragStart, windowStart, dragInput
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    windowStart = window.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end
for _, handle in ipairs({title, drag}) do
    handle.Active = true
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then beginDrag(input) end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
end
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local d = input.Position - dragStart
        window.Position = UDim2.new(windowStart.X.Scale, windowStart.X.Offset + d.X, windowStart.Y.Scale, windowStart.Y.Offset + d.Y)
    end
end)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(.5, 0)
status.Position = UDim2.new(.5, 0, 0, 8)
status.Size = UDim2.fromOffset(220, 18)
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextColor3 = sharedState.DefaultColor
status.Parent = canvas

local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.AnchorPoint = Vector2.new(.5, .5)
nameLabel.Position = UDim2.new(.5, 0, .12, 0)
nameLabel.Size = UDim2.fromOffset(190, 18)
nameLabel.Font = Enum.Font.Code
nameLabel.TextSize = 11
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.RichText = false
nameLabel.Text = "(E) Dummy [87]"
nameLabel.Visible = false
nameLabel.Parent = canvas

local distanceLabel = nameLabel:Clone()
distanceLabel.Position = UDim2.new(.5, 0, .90, 0)
distanceLabel.Text = "87 meters"
distanceLabel.Parent = canvas

local bodyRoot = Instance.new("Frame")
bodyRoot.AnchorPoint = Vector2.new(.5, .5)
bodyRoot.Position = UDim2.new(.5, 0, .54, 0)
bodyRoot.Size = UDim2.fromOffset(150, 230)
bodyRoot.BackgroundTransparency = 1
bodyRoot.Parent = canvas

local parts = {}
local function bodyPart(name, pos, size)
    local p = Instance.new("Frame")
    p.Name = name
    p.AnchorPoint = Vector2.new(.5, .5)
    p.Position = pos
    p.Size = size
    p.BorderSizePixel = 0
    p.BackgroundColor3 = sharedState.DefaultColor
    p.BackgroundTransparency = .12
    p.Parent = bodyRoot
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = p
    local s = Instance.new("UIStroke") s.Name = "Outline" s.Thickness = 1.4 s.Color = sharedState.DefaultColor s.Transparency = .05 s.Parent = p
    parts[name] = p
    return p
end
bodyPart("Head", UDim2.new(.5, 0, .10, 0), UDim2.fromOffset(40, 40))
bodyPart("Torso", UDim2.new(.5, 0, .40, 0), UDim2.fromOffset(62, 92))
bodyPart("LeftArm", UDim2.new(.25, 0, .42, 0), UDim2.fromOffset(18, 92))
bodyPart("RightArm", UDim2.new(.75, 0, .42, 0), UDim2.fromOffset(18, 92))
bodyPart("LeftLeg", UDim2.new(.40, 0, .79, 0), UDim2.fromOffset(22, 88))
bodyPart("RightLeg", UDim2.new(.60, 0, .79, 0), UDim2.fromOffset(22, 88))

-- Corner box preview with stationary geometry and animated fill color only.
local cornerFill = Instance.new("Frame")
cornerFill.AnchorPoint = Vector2.new(.5, .5)
cornerFill.Position = UDim2.new(.5, 0, .54, 0)
cornerFill.Size = UDim2.fromOffset(174, 258)
cornerFill.BorderSizePixel = 0
cornerFill.BackgroundColor3 = Color3.fromRGB(119, 120, 255)
cornerFill.BackgroundTransparency = .78
cornerFill.Visible = false
cornerFill.ZIndex = 0
cornerFill.Parent = canvas
local cornerGradient = Instance.new("UIGradient")
cornerGradient.Rotation = 0
cornerGradient.Color = ColorSequence.new(Color3.fromRGB(119, 120, 255), Color3.fromRGB(55, 28, 110))
cornerGradient.Parent = cornerFill

local cornerLines = {}
local function newLine(parent)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(.5, .5)
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.new(1, 1, 1)
    f.Visible = false
    f.ZIndex = 10
    f.Parent = parent
    return f
end
local function setLine(line, a, b, thickness, color)
    local d = b - a
    if d.Magnitude < .01 then line.Visible = false return end
    line.Size = UDim2.fromOffset(d.Magnitude, thickness or 1)
    line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    line.Rotation = math.deg(math.atan2(d.Y, d.X))
    line.BackgroundColor3 = color or Color3.new(1, 1, 1)
    line.Visible = true
end
for i = 1, 8 do cornerLines[i] = newLine(canvas) end

local wall = Instance.new("Frame")
wall.AnchorPoint = Vector2.new(.5, .5)
wall.Position = UDim2.new(.5, 0, .54, 0)
wall.Size = UDim2.fromOffset(178, 262)
wall.BackgroundColor3 = Color3.fromRGB(55, 56, 62)
wall.BackgroundTransparency = .70
wall.BorderSizePixel = 0
wall.ZIndex = 20
wall.Visible = false
wall.Parent = canvas

-- Health bar + text
local healthBack = Instance.new("Frame")
healthBack.BorderSizePixel = 0
healthBack.BackgroundColor3 = Color3.new(0, 0, 0)
healthBack.Size = UDim2.fromOffset(6, 220)
healthBack.Position = UDim2.new(.5, -98, .5, -110)
healthBack.Visible = false
healthBack.Parent = canvas
local health = Instance.new("Frame")
health.BorderSizePixel = 0
health.BackgroundColor3 = Color3.new(1, 1, 1)
health.AnchorPoint = Vector2.new(0, 1)
health.Position = UDim2.new(0, 0, 1, 0)
health.Size = UDim2.new(1, 0, .76, 0)
health.Parent = healthBack
local healthGradient = Instance.new("UIGradient")
healthGradient.Rotation = -90
healthGradient.Parent = health
local healthText = nameLabel:Clone()
healthText.Size = UDim2.fromOffset(42, 18)
healthText.Position = UDim2.new(.5, -116, .5, -55)
healthText.Text = "76"
healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
healthText.Visible = false
healthText.Parent = canvas

local tracer = newLine(canvas)
local skeletonLines = {}
for i = 1, 10 do skeletonLines[i] = newLine(canvas) end

local Preview = Visuals.CreateOptionsButton({
    ["Name"] = "Preview" .. ZWSP .. ZWSP .. ZWSP .. ZWSP .. ZWSP,
    ["Function"] = function(v)
        sharedState.Preview = v
        gui.Enabled = v
    end,
})

local function applyHealthPalette()
    if polish.HealthPalette == "Mint / Yellow / Red" then
        healthGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 42, 42)),
            ColorSequenceKeypoint.new(.5, Color3.fromRGB(255, 232, 126)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(116, 238, 188)),
        })
    else
        healthGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 0, 0)),
            ColorSequenceKeypoint.new(.5, Color3.fromRGB(60, 60, 125)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(119, 120, 255)),
        })
    end
end
applyHealthPalette()

local function updateCornerPreview(show)
    cornerFill.Visible = show
    if not show then for _, l in ipairs(cornerLines) do l.Visible = false end return end
    local sz = canvas.AbsoluteSize
    local center = Vector2.new(sz.X / 2, sz.Y * .54)
    local w, h = 174, 258
    local l, r, t, b = center.X - w / 2, center.X + w / 2, center.Y - h / 2, center.Y + h / 2
    local cw, ch = w / 5, h / 5
    local p = {
        {Vector2.new(l,t),Vector2.new(l+cw,t)}, {Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)}, {Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)}, {Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)}, {Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i, seg in ipairs(p) do setLine(cornerLines[i], seg[1], seg[2], 1, Color3.new(1,1,1)) end
end

RunService.RenderStepped:Connect(function()
    if not sharedState.Preview or not gui.Enabled then return end

    local espOn = enabled("ESP")
    local cornerOn = enabled("Corner Box")
    local healthOn = enabled("HealthBar") or espOn
    local nameOn = enabled("Name + Distance") or espOn
    local tracerOn = enabled("Tracers")
    local skeletonOn = enabled("Skeleton")

    local color = sharedState.DefaultColor
    if espOn and sharedState.WallCheck then
        color = sharedState.PreviewState == "Occluded" and sharedState.OccludedColor or sharedState.VisibleColor
    end

    for _, part in pairs(parts) do
        part.BackgroundColor3 = color
        local outline = part:FindFirstChild("Outline")
        if outline then outline.Color = color end
    end
    status.Text = sharedState.WallCheck and ("WALLCHECK • " .. string.upper(sharedState.PreviewState)) or "ESP • PREVIEW"
    status.TextColor3 = color
    wall.Visible = espOn and sharedState.WallCheck and sharedState.PreviewState == "Occluded"

    -- Names stay white in the Preview, independent of ESP color.
    nameLabel.Visible = nameOn
    nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
    distanceLabel.Visible = nameOn
    distanceLabel.TextColor3 = Color3.fromRGB(255,255,255)

    -- HealthText is always visible when the health preview is enabled.
    healthBack.Visible = healthOn
    healthText.Visible = healthOn
    healthText.TextColor3 = Color3.fromRGB(255,255,255)
    applyHealthPalette()

    updateCornerPreview(cornerOn)
    if cornerOn then
        if polish.FillSpin then
            local hue = (os.clock() * polish.FillSpinSpeed) % 1
            local a = Color3.fromHSV(hue, .72, 1)
            local b = Color3.fromHSV((hue + .12) % 1, .88, .55)
            cornerGradient.Color = ColorSequence.new(a, b)
        end
        cornerGradient.Rotation = 0 -- geometry and gradient orientation stay fixed; only color changes
    end

    if tracerOn then
        local sz = canvas.AbsoluteSize
        local start
        if sharedState.TracerOrigin == "Top" then
            start = Vector2.new(sz.X / 2, 0)
        elseif sharedState.TracerOrigin == "Center" then
            start = Vector2.new(sz.X / 2, sz.Y / 2)
        elseif sharedState.TracerOrigin == "Mouse" then
            local m = UserInputService:GetMouseLocation()
            local a = canvas.AbsolutePosition
            start = Vector2.new(math.clamp(m.X-a.X,0,sz.X), math.clamp(m.Y-a.Y,0,sz.Y))
        else
            start = Vector2.new(sz.X / 2, sz.Y)
        end
        setLine(tracer, start, Vector2.new(sz.X / 2, sz.Y * .54), 1, Color3.new(1,1,1))
    else
        tracer.Visible = false
    end

    if skeletonOn then
        local center = Vector2.new(canvas.AbsoluteSize.X/2, canvas.AbsoluteSize.Y*.54)
        local pts = {
            center+Vector2.new(0,-94), center+Vector2.new(0,-38), center+Vector2.new(0,34),
            center+Vector2.new(-39,-38), center+Vector2.new(-39,10),
            center+Vector2.new(39,-38), center+Vector2.new(39,10),
            center+Vector2.new(-18,34), center+Vector2.new(-18,104),
            center+Vector2.new(18,34), center+Vector2.new(18,104),
        }
        local edges = {{1,2},{2,3},{2,4},{4,5},{2,6},{6,7},{3,8},{8,9},{3,10},{10,11}}
        for i,e in ipairs(edges) do setLine(skeletonLines[i],pts[e[1]],pts[e[2]],1,Color3.new(1,1,1)) end
    else
        for _, l in ipairs(skeletonLines) do l.Visible = false end
    end
end)

-- ============================================================================
-- Roblox Studio: configurable wallcheck colors on non-player Humanoid dummies.
-- ============================================================================
local studioHighlights = setmetatable({}, {__mode="k"})
local studioHealth = setmetatable({}, {__mode="k"})

local function clearStudio()
    for model, h in pairs(studioHighlights) do if h and h.Parent then h:Destroy() end studioHighlights[model] = nil end
    for model, bill in pairs(studioHealth) do if bill and bill.Parent then bill:Destroy() end studioHealth[model] = nil end
end

local function targetVisible(model, root)
    local cam = Workspace.CurrentCamera
    if not cam or not root then return false end
    local origins = {root}
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then table.insert(origins, head) end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character, model, cam}
    rp.IgnoreWater = true
    for _, part in ipairs(origins) do
        local dir = part.Position - cam.CFrame.Position
        if dir.Magnitude > .05 and Workspace:Raycast(cam.CFrame.Position, dir, rp) == nil then return true end
    end
    return false
end

local studioTick = 0
RunService.Heartbeat:Connect(function(dt)
    if not RunService:IsStudio() then return end
    studioTick += dt
    if studioTick < .12 then return end
    studioTick = 0

    local espOn = enabled("ESP")
    if not espOn then clearStudio() return end

    local seen = {}
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
            if hum and root and hum.Health > 0 then
                seen[model] = true
                local h = studioHighlights[model]
                if not h or not h.Parent then
                    h = Instance.new("Highlight")
                    h.Name = "YokaiStudioESPWallCheck"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency = .72
                    h.OutlineTransparency = 0
                    h.Adornee = model
                    h.Parent = model
                    studioHighlights[model] = h
                end
                local c = sharedState.DefaultColor
                if sharedState.WallCheck then c = targetVisible(model, root) and sharedState.VisibleColor or sharedState.OccludedColor end
                h.FillColor = c
                h.OutlineColor = c
                h.Enabled = true
            end
        end
    end
    for model, h in pairs(studioHighlights) do
        if not seen[model] then if h and h.Parent then h:Destroy() end studioHighlights[model] = nil end
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Rejoin + Preview polish loaded", 3)
end)
