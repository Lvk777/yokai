-- Universal local/self movement helpers.
-- Only affects LocalPlayer character/seat; no remote calls and no anti-cheat bypass logic.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary["ObjectsThatCanBeSaved"] or {}
local MovementRec=objects["MovementWindow"]
local Movement=MovementRec and MovementRec.Api
if not Movement then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP,"") end
local function optionName(key) return clean(key):gsub("OptionsButton$","") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeMovementOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,MovementRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

for _,name in ipairs({"Fly","CarFly","MouseTP","Speed"}) do removeMovementOption(name) end

local function charParts()
    local char=LocalPlayer.Character
    if not char then return nil end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    return char,hum,root
end
local function cameraBasis()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector3.new(0,0,-1),Vector3.new(1,0,0) end
    local f=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
    local r=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
    if f.Magnitude<.01 then f=Vector3.new(0,0,-1) else f=f.Unit end
    if r.Magnitude<.01 then r=Vector3.new(1,0,0) else r=r.Unit end
    return f,r
end
local function inputVector(includeVertical)
    local f,r=cameraBasis()
    local v=Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then v+=f end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then v-=f end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then v+=r end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then v-=r end
    if includeVertical then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v+=Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v-=Vector3.yAxis end
    end
    return v
end

-- Fly: simple camera-relative flight. W/A/S/D, Space up, Ctrl/Shift down.
local flyEnabled=false
local flySpeed=70
local flyConn
local oldAutoRotate=nil
local Fly
Fly=Movement.CreateOptionsButton({
    ["Name"]="Fly",
    ["Function"]=function(v)
        flyEnabled=v
        if flyConn then flyConn:Disconnect() flyConn=nil end
        local _,hum,root=charParts()
        if v then
            if hum then oldAutoRotate=hum.AutoRotate hum.AutoRotate=false end
            flyConn=RunService.Heartbeat:Connect(function()
                local _,h,r=charParts()
                if not r then return end
                if h then h.AutoRotate=false end
                local move=inputVector(true)
                r.AssemblyLinearVelocity=move.Magnitude>0 and move.Unit*flySpeed or Vector3.zero
                r.AssemblyAngularVelocity=Vector3.zero
                if h and h.Health>0 and h.FloorMaterial==Enum.Material.Air then pcall(function() h:ChangeState(Enum.HumanoidStateType.Freefall) end) end
            end)
        else
            if root then root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero end
            if hum then hum.AutoRotate=(oldAutoRotate==nil) and true or oldAutoRotate end
        end
    end,
    ["HoverText"]="WASD + Space/Ctrl. Camera-relative local flight.",
})
Fly.CreateSlider({["Name"]="Speed",["Min"]=20,["Max"]=220,["Default"]=70,["Function"]=function(v) flySpeed=v end})

-- CarFly: same controls while seated; only moves the local seat assembly.
local carFlyEnabled=false
local carFlySpeed=95
local carFlyConn
local CarFly
CarFly=Movement.CreateOptionsButton({
    ["Name"]="CarFly",
    ["Function"]=function(v)
        carFlyEnabled=v
        if carFlyConn then carFlyConn:Disconnect() carFlyConn=nil end
        if v then
            carFlyConn=RunService.Heartbeat:Connect(function()
                local _,hum=charParts()
                local seat=hum and hum.SeatPart
                if not seat then return end
                local carrier=seat.AssemblyRootPart or seat
                if carrier.Anchored then return end
                local move=inputVector(true)
                carrier.AssemblyLinearVelocity=move.Magnitude>0 and move.Unit*carFlySpeed or Vector3.zero
                carrier.AssemblyAngularVelocity=Vector3.zero
                local cam=Workspace.CurrentCamera
                if cam then
                    local flat=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
                    if flat.Magnitude>.01 then pcall(function() carrier.CFrame=CFrame.lookAt(carrier.Position,carrier.Position+flat.Unit) end) end
                end
            end)
        end
    end,
    ["HoverText"]="While seated: WASD + Space/Ctrl to fly the local vehicle assembly.",
})
CarFly.CreateSlider({["Name"]="Speed",["Min"]=20,["Max"]=260,["Default"]=95,["Function"]=function(v) carFlySpeed=v end})

-- MouseTP: toggle on, then click a visible point in the world. It stays enabled for repeated jumps.
local mouseTPEnabled=false
local MouseTP=Movement.CreateOptionsButton({
    ["Name"]="MouseTP",
    ["Function"]=function(v) mouseTPEnabled=v end,
    ["HoverText"]="Enable, then left-click a world point to teleport your own character there.",
})
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or not mouseTPEnabled or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local char,_,root=charParts()
    local cam=Workspace.CurrentCamera
    if not char or not root or not cam then return end
    local m=UserInputService:GetMouseLocation()
    local ray=cam:ViewportPointToRay(m.X,m.Y)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={char,cam}
    rp.IgnoreWater=false
    local hit=Workspace:Raycast(ray.Origin,ray.Direction*5000,rp)
    if hit then
        local rot=root.CFrame.Rotation
        root.CFrame=CFrame.new(hit.Position+Vector3.new(0,3,0))*rot
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end
end)

-- Speed: resilient WalkSpeed lock with clean restore when disabled.
local speedEnabled=false
local speedValue=32
local speedConn
local savedWalkSpeed=16
local Speed
Speed=Movement.CreateOptionsButton({
    ["Name"]="Speed",
    ["Function"]=function(v)
        speedEnabled=v
        if speedConn then speedConn:Disconnect() speedConn=nil end
        local _,hum=charParts()
        if v then
            if hum then savedWalkSpeed=hum.WalkSpeed end
            speedConn=RunService.Heartbeat:Connect(function()
                local _,h=charParts()
                if h and h.Health>0 and h.WalkSpeed~=speedValue then h.WalkSpeed=speedValue end
            end)
        elseif hum then
            hum.WalkSpeed=savedWalkSpeed
        end
    end,
})
Speed.CreateSlider({["Name"]="WalkSpeed",["Min"]=16,["Max"]=120,["Default"]=32,["Function"]=function(v) speedValue=v end})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(.25)
    if speedEnabled then local _,h=charParts() if h then savedWalkSpeed=h.WalkSpeed h.WalkSpeed=speedValue end end
end)
