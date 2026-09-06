-- Final synthetic-target polish only.
-- Keeps HitBoxes from changing ESP/Corner geometry and reports hit parts on the test dummy.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary and shared.YokaiSafeTargetVisualState

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local UserInputService=game:GetService("UserInputService")
local LocalPlayer=Players.LocalPlayer
local visual=shared.YokaiSafeTargetVisualState

local function getTarget()
    return Workspace:FindFirstChild("YokaiSafeVisualTestTarget")
end

-- Important: the synthetic combat hitbox lives outside the visual model.
-- The original Combat code still owns/updates this same Part reference, but target:GetBoundingBox()
-- and Highlight no longer grow when HitBoxes Size increases.
local target=getTarget()
local hitbox=target and target:FindFirstChild("YokaiSafeHitbox")
if hitbox then
    hitbox.Parent=Workspace
    hitbox.Name="YokaiSafeHitbox"
end

local function getOverlay()
    local roots={LocalPlayer:FindFirstChildOfClass("PlayerGui"),game:GetService("CoreGui")}
    pcall(function() if gethui then table.insert(roots,gethui()) end end)
    for _,root in ipairs(roots) do
        if root then
            local gui=root:FindFirstChild("YokaiSafeTargetAllInOneOverlay",true)
            if gui then return gui end
        end
    end
end

-- The AllInOne renderer originally treated ESP as if Corner Box were also enabled.
-- Keep Corner Box independent again. The first 8 line Frames are its 8 corner segments.
local overlay=getOverlay()
local cornerLines={}
local cornerFill=nil
if overlay then
    local lineFrames={}
    for _,obj in ipairs(overlay:GetChildren()) do
        if obj:IsA("Frame") then
            local grad=obj:FindFirstChildOfClass("UIGradient")
            if grad and obj.ZIndex==0 and not cornerFill then
                cornerFill=obj
            elseif not grad and obj.AnchorPoint==Vector2.new(.5,.5) then
                table.insert(lineFrames,obj)
            end
        end
    end
    for i=1,math.min(8,#lineFrames) do cornerLines[i]=lineFrames[i] end
end

RunService.RenderStepped:Connect(function()
    -- Older code never reparents the hitbox, but keep this self-healing after respawn/reload.
    local trg=getTarget()
    if trg then
        local hb=trg:FindFirstChild("YokaiSafeHitbox")
        if hb then hb.Parent=Workspace hitbox=hb end
    end

    if not visual.Corner then
        if cornerFill then cornerFill.Visible=false end
        for _,line in ipairs(cornerLines) do line.Visible=false end
    end
end)

-- Hit-part notification for the synthetic dummy.
-- We raycast the user's actual click. Damage notification is emitted only when the dummy's
-- Humanoid really loses health, so it cannot report a hit that did not occur in the test target.
local lastPart="Target"
local lastPartAt=0
local lastHealth=nil
local boundHumanoid=nil
local healthConn=nil

local function prettyPart(name)
    local map={
        ["Head"]="Head",
        ["Torso"]="Torso",
        ["Left Arm"]="Left Arm",
        ["Right Arm"]="Right Arm",
        ["Left Leg"]="Left Leg",
        ["Right Leg"]="Right Leg",
        ["HumanoidRootPart"]="Torso",
    }
    return map[name] or "Target"
end

local function notifyHit(part,damage)
    pcall(function()
        GuiLibrary["CreateNotification"]("Hit",string.format("%s  •  -%d HP",prettyPart(part),math.max(1,math.floor(damage+.5))),2)
    end)
end

local function bindHumanoid()
    local trg=getTarget()
    local hum=trg and trg:FindFirstChildOfClass("Humanoid")
    if hum==boundHumanoid then return end
    if healthConn then healthConn:Disconnect() healthConn=nil end
    boundHumanoid=hum
    lastHealth=hum and hum.Health or nil
    if hum then
        healthConn=hum.HealthChanged:Connect(function(newHealth)
            if lastHealth and newHealth<lastHealth then
                local part=(os.clock()-lastPartAt<=0.35) and lastPart or "Target"
                notifyHit(part,lastHealth-newHealth)
            end
            lastHealth=newHealth
        end)
    end
end
bindHumanoid()

UserInputService.InputBegan:Connect(function(input,processed)
    if processed or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local trg=getTarget()
    local cam=Workspace.CurrentCamera
    if not trg or not cam then return end
    local mouse=UserInputService:GetMouseLocation()
    local ray=cam:ViewportPointToRay(mouse.X,mouse.Y)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local excludes={LocalPlayer.Character}
    if hitbox and hitbox.Parent then table.insert(excludes,hitbox) end
    rp.FilterDescendantsInstances=excludes
    rp.IgnoreWater=true
    local result=Workspace:Raycast(ray.Origin,ray.Direction*2000,rp)
    if result and result.Instance and result.Instance:IsDescendantOf(trg) then
        lastPart=result.Instance.Name
        lastPartAt=os.clock()
    else
        lastPart="Target"
        lastPartAt=0
    end
end)

RunService.Heartbeat:Connect(bindHumanoid)
