-- GunTestingLiteSettingsV11.lua
-- Adds a lightweight Settings page to the standalone UI.
-- Includes a Rejoin button for the current place/server.

if shared.GunTestingLiteSettingsV11 then return end
shared.GunTestingLiteSettingsV11=true

local Players=game:GetService("Players")
local TeleportService=game:GetService("TeleportService")
local CoreGui=game:GetService("CoreGui")

local LP=Players.LocalPlayer
local parent=(gethui and gethui()) or CoreGui
local Gui=parent:FindFirstChild("GunTestingLiteV1",true)
if not Gui then
    for _=1,100 do
        task.wait(.05)
        Gui=parent:FindFirstChild("GunTestingLiteV1",true)
        if Gui then break end
    end
end
if not Gui then return end

local title
for _,d in ipairs(Gui:GetDescendants()) do
    if d:IsA("TextLabel") and tostring(d.Text):find("GUN TESTING LITE",1,true) then
        title=d
        break
    end
end
if not title then return end

local Top=title.Parent
local Main=Top and Top.Parent
if not Main then return end

local Sidebar,Content
for _,child in ipairs(Main:GetChildren()) do
    if child:IsA("Frame") and child~=Top then
        if child.Position.X.Offset<=10 then
            Sidebar=Sidebar or child
        elseif child.Position.X.Offset>=120 then
            Content=Content or child
        end
    end
end
if not (Sidebar and Content) then return end

local accent=Color3.fromRGB(125,82,235)

-- Settings page --------------------------------------------------------------
local Settings=Content:FindFirstChild("Settings")
if not Settings then
    Settings=Instance.new("ScrollingFrame")
    Settings.Name="Settings"
    Settings.Size=UDim2.fromScale(1,1)
    Settings.BackgroundTransparency=1
    Settings.BorderSizePixel=0
    Settings.ScrollBarThickness=4
    Settings.ScrollBarImageColor3=accent
    Settings.Visible=false
    Settings.AutomaticCanvasSize=Enum.AutomaticSize.Y
    Settings.CanvasSize=UDim2.new()
    Settings.Parent=Content

    local pad=Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,12)
    pad.PaddingLeft=UDim.new(0,14)
    pad.PaddingRight=UDim.new(0,14)
    pad.PaddingBottom=UDim.new(0,12)
    pad.Parent=Settings

    local list=Instance.new("UIListLayout")
    list.Padding=UDim.new(0,8)
    list.SortOrder=Enum.SortOrder.LayoutOrder
    list.Parent=Settings
end

local function section(text)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,0,0,22)
    l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold
    l.TextSize=12
    l.TextColor3=Color3.fromRGB(166,159,192)
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Text=string.upper(text)
    l.Parent=Settings
    return l
end

local function row(label)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,40)
    f.BackgroundColor3=Color3.fromRGB(24,24,33)
    f.BorderSizePixel=0
    f.Parent=Settings
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,7)
    c.Parent=f

    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Position=UDim2.fromOffset(10,0)
    t.Size=UDim2.new(1,-150,1,0)
    t.Font=Enum.Font.Gotham
    t.TextSize=13
    t.TextColor3=Color3.fromRGB(230,230,240)
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.Text=label
    t.Parent=f
    return f,t
end

section("Session")
local rejoinRow,rowText=row("Rejoin current server")
local rejoin=Instance.new("TextButton")
rejoin.Name="RejoinButton"
rejoin.AnchorPoint=Vector2.new(1,.5)
rejoin.Position=UDim2.new(1,-10,.5,0)
rejoin.Size=UDim2.fromOffset(118,26)
rejoin.BackgroundColor3=accent
rejoin.BorderSizePixel=0
rejoin.AutoButtonColor=false
rejoin.Font=Enum.Font.GothamBold
rejoin.TextSize=11
rejoin.TextColor3=Color3.new(1,1,1)
rejoin.Text="REJOIN"
rejoin.Parent=rejoinRow
local rc=Instance.new("UICorner")
rc.CornerRadius=UDim.new(0,6)
rc.Parent=rejoin

local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,0,0,30)
status.BackgroundTransparency=1
status.Font=Enum.Font.Gotham
status.TextSize=11
status.TextColor3=Color3.fromRGB(155,155,175)
status.TextXAlignment=Enum.TextXAlignment.Left
status.Text="Rejoins this place; same server is attempted first."
status.Parent=Settings

local busy=false
rejoin.MouseButton1Click:Connect(function()
    if busy then return end
    busy=true
    rejoin.Text="REJOINING..."
    rejoin.BackgroundColor3=Color3.fromRGB(86,65,155)
    status.Text="Attempting to reconnect..."

    local ok,err=pcall(function()
        if game.JobId and game.JobId~="" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LP)
        else
            TeleportService:Teleport(game.PlaceId,LP)
        end
    end)

    if not ok then
        local ok2,err2=pcall(function()
            TeleportService:Teleport(game.PlaceId,LP)
        end)
        if not ok2 then
            status.Text="Rejoin failed: "..tostring(err2 or err)
            rejoin.Text="REJOIN"
            rejoin.BackgroundColor3=accent
            busy=false
        end
    end
end)

-- Settings tab ---------------------------------------------------------------
local settingsButton=Sidebar:FindFirstChild("LiteSettingsTab")
if not settingsButton then
    settingsButton=Instance.new("TextButton")
    settingsButton.Name="LiteSettingsTab"
    settingsButton.Size=UDim2.new(1,-18,0,38)
    settingsButton.Position=UDim2.fromOffset(9,8+4*44)
    settingsButton.BackgroundColor3=Color3.fromRGB(20,20,27)
    settingsButton.BackgroundTransparency=1
    settingsButton.BorderSizePixel=0
    settingsButton.AutoButtonColor=false
    settingsButton.Font=Enum.Font.GothamMedium
    settingsButton.TextSize=12
    settingsButton.TextColor3=Color3.fromRGB(190,190,205)
    settingsButton.TextXAlignment=Enum.TextXAlignment.Left
    settingsButton.Text="   Settings"
    settingsButton.Parent=Sidebar
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,7)
    c.Parent=settingsButton
end

local function resetTabs()
    for _,b in ipairs(Sidebar:GetChildren()) do
        if b:IsA("TextButton") then
            b.BackgroundTransparency=1
            b.TextColor3=Color3.fromRGB(190,190,205)
        end
    end
end

local function showSettings()
    for _,p in ipairs(Content:GetChildren()) do
        if p:IsA("ScrollingFrame") then p.Visible=(p==Settings) end
    end
    resetTabs()
    settingsButton.BackgroundTransparency=.25
    settingsButton.BackgroundColor3=accent
    settingsButton.TextColor3=Color3.new(1,1,1)
end
settingsButton.MouseButton1Click:Connect(showSettings)

-- Existing V1 tab handlers know only the original four pages, so ensure they
-- explicitly hide Settings when clicked.
for _,b in ipairs(Sidebar:GetChildren()) do
    if b:IsA("TextButton") and b~=settingsButton then
        b.MouseButton1Click:Connect(function()
            Settings.Visible=false
        end)
    end
end

settingsButton.MouseEnter:Connect(function()
    if settingsButton.BackgroundTransparency>.2 then
        settingsButton.BackgroundTransparency=.72
    end
end)
settingsButton.MouseLeave:Connect(function()
    if not Settings.Visible then settingsButton.BackgroundTransparency=1 end
end)
