-- GunTestingLiteMovementV4.lua
-- Local camera movement replacement for the old character-physics Fly.
-- Does not move the avatar or vehicle and does not contain anti-kick/anti-cheat logic.

if shared.GunTestingLiteMovementV4 then return end
shared.GunTestingLiteMovementV4 = true

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local parent=(gethui and gethui()) or CoreGui
local Gui=parent:FindFirstChild("GunTestingLiteV1",true)
if not Gui then for _=1,80 do task.wait(.05); Gui=parent:FindFirstChild("GunTestingLiteV1",true); if Gui then break end end end
if not Gui then return end

local function findPage(name)
    for _,d in ipairs(Gui:GetDescendants()) do if d:IsA("ScrollingFrame") and d.Name==name then return d end end
end
local Movement=findPage("Movement")
if not Movement then return end

-- Hide the old character-physics Fly rows. WalkSpeed and Car Fly stay separate.
for _,child in ipairs(Movement:GetChildren()) do
    if child:IsA("Frame") then
        local label=child:FindFirstChildOfClass("TextLabel")
        if label and (label.Text=="Fly" or label.Text=="Fly Speed") then child.Visible=false end
    end
end

local accent=Color3.fromRGB(125,82,235)
local enabled=false
local speed=85
local looking=false
local yaw=0
local pitch=0
local sensitivity=.0025
local oldType=nil
local oldSubject=nil
local oldMouseBehavior=nil
local order=12000

local function row(label)
    local f=Instance.new("Frame"); f.LayoutOrder=order; order+=1; f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=Movement
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0); t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(230,230,240); t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f
end

local function stopFreecam()
    local cam=Workspace.CurrentCamera
    looking=false
    if oldMouseBehavior~=nil then pcall(function() UIS.MouseBehavior=oldMouseBehavior end) end
    if cam then
        if oldType then cam.CameraType=oldType end
        if oldSubject then pcall(function() cam.CameraSubject=oldSubject end) end
    end
    oldType=nil; oldSubject=nil; oldMouseBehavior=nil
end
local function startFreecam()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if not oldType then oldType=cam.CameraType; oldSubject=cam.CameraSubject; oldMouseBehavior=UIS.MouseBehavior end
    local x,y=cam.CFrame:ToOrientation(); pitch=x; yaw=y
    cam.CameraType=Enum.CameraType.Scriptable
end

local f=row("Freecam (local view fly)")
local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
local function paint()
    b.BackgroundColor3=enabled and accent or Color3.fromRGB(50,50,62); dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=enabled and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
end
b.MouseButton1Click:Connect(function() enabled=not enabled; if enabled then startFreecam() else stopFreecam() end; paint() end); paint()

local sf=row("Freecam Speed")
local box=Instance.new("TextBox"); box.Size=UDim2.fromOffset(78,24); box.Position=UDim2.new(1,-88,.5,-12); box.BackgroundColor3=Color3.fromRGB(34,34,45); box.BorderSizePixel=0; box.Font=Enum.Font.Code; box.TextSize=12; box.TextColor3=Color3.new(1,1,1); box.Text=tostring(speed); box.ClearTextOnFocus=false; box.Parent=sf
local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,5); bc.Parent=box
box.FocusLost:Connect(function() local n=tonumber(box.Text); if n then speed=math.clamp(n,10,500) end; box.Text=tostring(speed) end)

local hint=row("Freecam controls: WASD + E/Q • hold RMB to look")
hint.BackgroundTransparency=.35

UIS.InputBegan:Connect(function(input,processed)
    if not enabled or processed then return end
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        looking=true
        pcall(function() UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition end)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        looking=false
        if oldMouseBehavior~=nil then pcall(function() UIS.MouseBehavior=oldMouseBehavior end) end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if not enabled then return end
    local cam=Workspace.CurrentCamera; if not cam then return end
    if cam.CameraType~=Enum.CameraType.Scriptable then cam.CameraType=Enum.CameraType.Scriptable end

    if looking then
        local delta=UIS:GetMouseDelta()
        yaw-=delta.X*sensitivity
        pitch=math.clamp(pitch-delta.Y*sensitivity,-math.rad(89),math.rad(89))
    end

    local pos=cam.CFrame.Position
    local rot=CFrame.fromOrientation(pitch,yaw,0)
    local move=Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then move+=Vector3.new(0,0,-1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move+=Vector3.new(0,0,1) end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move+=Vector3.new(-1,0,0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move+=Vector3.new(1,0,0) end
    if UIS:IsKeyDown(Enum.KeyCode.E) then move+=Vector3.new(0,1,0) end
    if UIS:IsKeyDown(Enum.KeyCode.Q) then move+=Vector3.new(0,-1,0) end
    if move.Magnitude>0 then pos+=(rot:VectorToWorldSpace(move.Unit))*speed*dt end
    cam.CFrame=CFrame.new(pos)*rot
end)
