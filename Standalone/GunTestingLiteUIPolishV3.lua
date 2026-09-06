-- GunTestingLiteUIPolishV3.lua
-- Lightweight visual polish for the standalone menu only.
-- Does not replace Combat/Visuals/Movement/World runtime logic.

if shared.GunTestingLiteUIPolishV3 then return end
shared.GunTestingLiteUIPolishV3 = true

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local parent = (gethui and gethui()) or CoreGui
local Gui = parent:FindFirstChild("GunTestingLiteV1", true)
if not Gui then
    for _ = 1, 80 do
        task.wait(.05)
        Gui = parent:FindFirstChild("GunTestingLiteV1", true)
        if Gui then break end
    end
end
if not Gui then return end

local title
for _, d in ipairs(Gui:GetDescendants()) do
    if d:IsA("TextLabel") and tostring(d.Text):find("Gun Testing Lite", 1, true) then
        title = d
        break
    end
end
if not title then return end

local Top = title.Parent
local Main = Top and Top.Parent
if not (Top and Top:IsA("Frame") and Main and Main:IsA("Frame")) then return end

local Sidebar, Content
for _, child in ipairs(Main:GetChildren()) do
    if child:IsA("Frame") and child ~= Top then
        if child.Position.X.Offset <= 10 then
            Sidebar = Sidebar or child
        elseif child.Position.X.Offset >= 120 then
            Content = Content or child
        end
    end
end
if not (Sidebar and Content) then return end

local accent = Color3.fromRGB(125, 82, 235)
local expandedSize = UDim2.fromOffset(700, 440)
local collapsedSize = UDim2.fromOffset(700, 52)
local collapsed = false

-- Geometry / hierarchy polish ------------------------------------------------
Main.Size = expandedSize
Main.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
Main.BackgroundTransparency = .025
Top.Size = UDim2.new(1, 0, 0, 52)
Top.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
Sidebar.Position = UDim2.fromOffset(0, 52)
Sidebar.Size = UDim2.new(0, 160, 1, -52)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Content.Position = UDim2.fromOffset(160, 52)
Content.Size = UDim2.new(1, -160, 1, -52)

title.Position = UDim2.fromOffset(18, 0)
title.Size = UDim2.new(1, -190, 1, 0)
title.Text = "YOKAI  •  GUN TESTING LITE"
title.TextSize = 17

local stroke = Main:FindFirstChildOfClass("UIStroke")
if stroke then
    stroke.Color = Color3.fromRGB(88, 70, 135)
    stroke.Transparency = .28
    stroke.Thickness = 1
end

-- Lightweight title accent; no blur/shadow objects.
local accentBar = Top:FindFirstChild("LiteAccentBar")
if not accentBar then
    accentBar = Instance.new("Frame")
    accentBar.Name = "LiteAccentBar"
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundColor3 = accent
    accentBar.Size = UDim2.fromOffset(3, 26)
    accentBar.Position = UDim2.fromOffset(10, 13)
    accentBar.Parent = Top
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = accentBar
end

local keyHint = Top:FindFirstChild("LiteKeyHint")
if not keyHint then
    keyHint = Instance.new("TextLabel")
    keyHint.Name = "LiteKeyHint"
    keyHint.AnchorPoint = Vector2.new(1, .5)
    keyHint.Position = UDim2.new(1, -58, .5, 0)
    keyHint.Size = UDim2.fromOffset(86, 24)
    keyHint.BackgroundColor3 = Color3.fromRGB(29, 29, 40)
    keyHint.BorderSizePixel = 0
    keyHint.Font = Enum.Font.GothamMedium
    keyHint.TextSize = 10
    keyHint.TextColor3 = Color3.fromRGB(185, 181, 205)
    keyHint.Text = "RSHIFT"
    keyHint.Parent = Top
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = keyHint
end

local minimize = Top:FindFirstChild("LiteMinimize")
if not minimize then
    minimize = Instance.new("TextButton")
    minimize.Name = "LiteMinimize"
    minimize.AnchorPoint = Vector2.new(1, .5)
    minimize.Position = UDim2.new(1, -12, .5, 0)
    minimize.Size = UDim2.fromOffset(34, 28)
    minimize.BackgroundColor3 = Color3.fromRGB(31, 31, 42)
    minimize.BorderSizePixel = 0
    minimize.AutoButtonColor = false
    minimize.Font = Enum.Font.GothamBold
    minimize.TextSize = 16
    minimize.TextColor3 = Color3.fromRGB(220, 218, 232)
    minimize.Text = "—"
    minimize.Parent = Top
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = minimize
end

local function setCollapsed(v)
    collapsed = v == true
    Sidebar.Visible = not collapsed
    Content.Visible = not collapsed
    minimize.Text = collapsed and "□" or "—"
    TweenService:Create(Main, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = collapsed and collapsedSize or expandedSize
    }):Play()
end

minimize.MouseButton1Click:Connect(function()
    setCollapsed(not collapsed)
end)
minimize.MouseEnter:Connect(function()
    TweenService:Create(minimize, TweenInfo.new(.10), {BackgroundColor3 = Color3.fromRGB(52, 44, 72)}):Play()
end)
minimize.MouseLeave:Connect(function()
    TweenService:Create(minimize, TweenInfo.new(.10), {BackgroundColor3 = Color3.fromRGB(31, 31, 42)}):Play()
end)

-- Improve tabs/rows without adding expensive effects -------------------------
for _, b in ipairs(Sidebar:GetChildren()) do
    if b:IsA("TextButton") then
        b.Size = UDim2.new(1, -18, 0, 38)
        b.Position = UDim2.new(0, 9, b.Position.Y.Scale, b.Position.Y.Offset)
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.AutoButtonColor = false
        b.MouseEnter:Connect(function()
            if b.BackgroundTransparency > .2 then
                TweenService:Create(b, TweenInfo.new(.08), {BackgroundTransparency = .72}):Play()
            end
        end)
        b.MouseLeave:Connect(function()
            if b.BackgroundColor3 ~= accent then
                TweenService:Create(b, TweenInfo.new(.08), {BackgroundTransparency = 1}):Play()
            end
        end)
    end
end

for _, d in ipairs(Content:GetDescendants()) do
    if d:IsA("ScrollingFrame") then
        d.ScrollBarThickness = 4
        d.ScrollBarImageColor3 = accent
        d.ScrollingDirection = Enum.ScrollingDirection.Y
        d.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        d.AutomaticCanvasSize = Enum.AutomaticSize.Y
    elseif d:IsA("TextBox") then
        d.PlaceholderColor3 = Color3.fromRGB(125, 125, 145)
        d.TextColor3 = Color3.fromRGB(238, 238, 246)
    end
end

-- The V1 source's original drag handling becomes active once the loader fixes
-- its early init error. This extra clamp keeps the window recoverable onscreen.
local function clampMain()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local abs = Main.AbsolutePosition
    local size = Main.AbsoluteSize
    local dx, dy = 0, 0
    if abs.X < 8 then dx = 8 - abs.X end
    if abs.Y < 8 then dy = 8 - abs.Y end
    if abs.X + size.X > vp.X - 8 then dx = (vp.X - 8) - (abs.X + size.X) end
    if abs.Y + math.min(size.Y, 52) > vp.Y - 8 then dy = (vp.Y - 8) - (abs.Y + math.min(size.Y, 52)) end
    if dx ~= 0 or dy ~= 0 then
        Main.Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset + dx, Main.Position.Y.Scale, Main.Position.Y.Offset + dy)
    end
end

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.defer(clampMain)
    end
end)

-- Robust menu visibility hotkey. Loader removes the old V1 RightShift handler
-- before executing it, so this is the single owner of the shortcut.
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

Main.Visible = true
print("[GunTestingLite] UI V3 ready")
