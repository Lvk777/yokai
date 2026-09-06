-- Studio-only fallback visual target for single-player Baseplate tests.
-- Does nothing outside Roblox Studio.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
if not VisualsRec then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    local obj=rec.Object
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (obj==root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end
local function findVisualOption(name)
    local found
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then found=rec end
    end
    return found
end
local function enabled(name)
    local rec=findVisualOption(name)
    return rec and rec.Api and rec.Api.Enabled==true
end

-- Remove an older fallback target/overlay from a previous execution.
local old=Workspace:FindFirstChild("YokaiStudioTestTarget")
if old then old:Destroy() end
for _,root in ipairs({LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}) do
    if root then
        local g=root:FindFirstChild("YokaiStudioSinglePlayerVisuals",true)
        if g then g:Destroy() end
    end
end
pcall(function()
    if gethui then
        local g=gethui():FindFirstChild("YokaiStudioSinglePlayerVisuals",true)
        if g then g:Destroy() end
    end
end)

local function otherPlayerCount()
    local n=0
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then n+=1 end end
    return n
end

local function makePart(model,name,size,cf,color,transparency)
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=cf
    p.Anchored=true
    p.CanCollide=false
    p.CanQuery=true
    p.CanTouch=false
    p.Material=Enum.Material.SmoothPlastic
    p.Color=color or Color3.fromRGB(155,155,165)
    p.Transparency=transparency or 0
    p.Parent=model
    return p
end

local target
local hum
local function createTarget()
    if target and target.Parent then return target end
    if otherPlayerCount()>0 then return nil end
    local char=LocalPlayer.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local base=root and (root.CFrame*CFrame.new(7,0,-20)) or CFrame.new(0,4,-20)

    target=Instance.new("Model")
    target.Name="YokaiStudioTestTarget"
    target.Parent=Workspace
    hum=Instance.new("Humanoid")
    hum.Name="Humanoid"
    hum.MaxHealth=100
    hum.Health=76
    hum.Parent=target

    local hrp=makePart(target,"HumanoidRootPart",Vector3.new(2,2,1),base*CFrame.new(0,1.5,0),Color3.new(1,1,1),1)
    makePart(target,"Torso",Vector3.new(2,2,1),base*CFrame.new(0,1.5,0))
    makePart(target,"Head",Vector3.new(2,1,1),base*CFrame.new(0,3.0,0))
    makePart(target,"Left Arm",Vector3.new(1,2,1),base*CFrame.new(-1.5,1.5,0))
    makePart(target,"Right Arm",Vector3.new(1,2,1),base*CFrame.new(1.5,1.5,0))
    makePart(target,"Left Leg",Vector3.new(1,2,1),base*CFrame.new(-.5,-.5,0))
    makePart(target,"Right Leg",Vector3.new(1,2,1),base*CFrame.new(.5,-.5,0))
    target.PrimaryPart=hrp
    return target
end

local overlay=Instance.new("ScreenGui")
overlay.Name="YokaiStudioSinglePlayerVisuals"
overlay.ResetOnSpawn=false
overlay.IgnoreGuiInset=true
overlay.DisplayOrder=995
pcall(function() overlay.Parent=(gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local highlight=Instance.new("Highlight")
highlight.Name="YokaiStudioSingleHighlight"
highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
highlight.FillTransparency=.72
highlight.OutlineTransparency=0
highlight.Enabled=false
highlight.Parent=Workspace

local function newLine()
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=Color3.new(1,1,1)
    f.Visible=false
    f.Parent=overlay
    return f
end
local function setLine(f,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color or Color3.new(1,1,1)
    f.BackgroundTransparency=transparency or 0
    f.Visible=true
end
local function hideLines(t) for _,v in ipairs(t) do v.Visible=false end end

local corners={} for i=1,8 do corners[i]=newLine() end
local skeleton={} for i=1,5 do skeleton[i]=newLine() end
local tracer=newLine()

local name=Instance.new("TextLabel")
name.BackgroundTransparency=1
name.AnchorPoint=Vector2.new(.5,.5)
name.Size=UDim2.fromOffset(220,18)
name.Font=Enum.Font.Code
name.TextSize=12
name.TextStrokeTransparency=0
name.TextColor3=Color3.new(1,1,1)
name.Text="StudioTestTarget"
name.Visible=false
name.Parent=overlay
local distance=name:Clone() distance.TextSize=11 distance.Parent=overlay
local healthText=name:Clone() healthText.Size=UDim2.fromOffset(42,16) healthText.TextSize=11 healthText.Parent=overlay
local healthBack=Instance.new("Frame") healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Visible=false healthBack.Parent=overlay
local health=Instance.new("Frame") health.BorderSizePixel=0 health.BackgroundColor3=Color3.new(1,1,1) health.Visible=false health.Parent=overlay
local healthGradient=Instance.new("UIGradient") healthGradient.Rotation=-90 healthGradient.Parent=health

local function palette()
    local p=shared.YokaiPreviewPolishState or {}
    if p.HealthPalette=="Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(230,55,55)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(120,255,205)),
        })
    end
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(220,40,50)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(50,110,255)),
    })
end

local function bounds(model)
    local cam=Workspace.CurrentCamera
    if not cam or not model then return nil end
    local cf,size=model:GetBoundingBox()
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local wp=(cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position
        local p=cam:WorldToViewportPoint(wp)
        if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
    end end end
    if not any then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end

local function visible(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end

local function updateCorners(tl,br,color)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(6,w*.24),math.max(6,h*.18)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(corners[i],v[1],v[2],1,color,0) end
end

local function tracerOrigin()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    local vp=cam.ViewportSize
    local s=shared.YokaiVisualPreviewState or {}
    local o=s.TracerOrigin or "Bottom"
    if o=="Top" then return Vector2.new(vp.X/2,0) end
    if o=="Center" then return Vector2.new(vp.X/2,vp.Y/2) end
    if o=="Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(vp.X/2,vp.Y)
end

local function hideAll()
    highlight.Enabled=false
    name.Visible=false distance.Visible=false healthText.Visible=false healthBack.Visible=false health.Visible=false tracer.Visible=false
    hideLines(corners) hideLines(skeleton)
end

RunService.RenderStepped:Connect(function()
    if otherPlayerCount()>0 then
        if target then target:Destroy() target=nil hum=nil end
        hideAll()
        return
    end
    local model=createTarget()
    if not model or not model.Parent then hideAll() return end
    local root=model:FindFirstChild("HumanoidRootPart")
    local head=model:FindFirstChild("Head")
    local torso=model:FindFirstChild("Torso")
    local tl,br=bounds(model)
    if not root or not tl then hideAll() return end

    local espOn=enabled("ESP")
    local healthOn=enabled("HealthBar") or espOn
    local namesOn=enabled("Name + Distance") or espOn
    local cornerOn=enabled("Corner Box") or espOn
    local tracerOn=enabled("Tracers")
    local sk=shared.YokaiStudioSkeletonState or {Enabled=enabled("Skeleton"),Color=Color3.new(1,1,1),Transparency=0,Thickness=1}
    local state=shared.YokaiVisualPreviewState or {}
    local col=state.DefaultColor or Color3.fromRGB(119,120,255)
    if espOn and state.WallCheck then col=visible(model,head or root) and (state.VisibleColor or Color3.fromRGB(35,235,95)) or (state.OccludedColor or Color3.fromRGB(245,55,55)) end

    highlight.Adornee=model highlight.Enabled=espOn highlight.FillColor=col highlight.OutlineColor=col
    if cornerOn then updateCorners(tl,br,col) else hideLines(corners) end

    local cx=(tl.X+br.X)/2
    if namesOn then
        name.Position=UDim2.fromOffset(cx,tl.Y-11) name.TextColor3=Color3.new(1,1,1) name.Visible=true
        local cam=Workspace.CurrentCamera
        local d=cam and (cam.CFrame.Position-root.Position).Magnitude/3.5714285714 or 0
        distance.Position=UDim2.fromOffset(cx,br.Y+9) distance.Text=string.format("%d meters",math.floor(d)) distance.TextColor3=Color3.new(1,1,1) distance.Visible=true
    else name.Visible=false distance.Visible=false end

    if healthOn then
        local ratio=hum and math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1) or .76
        local h=math.max(4,br.Y-tl.Y)
        healthBack.Position=UDim2.fromOffset(tl.X-7,tl.Y) healthBack.Size=UDim2.fromOffset(4,h) healthBack.Visible=true
        health.Position=UDim2.fromOffset(tl.X-7,tl.Y+h*(1-ratio)) health.Size=UDim2.fromOffset(4,h*ratio) healthGradient.Color=palette() health.Visible=true
        healthText.Position=UDim2.fromOffset(tl.X-20,tl.Y+h*(1-ratio)) healthText.Text=tostring(math.floor(ratio*100)) healthText.TextColor3=Color3.new(1,1,1) healthText.Visible=true
    else healthBack.Visible=false health.Visible=false healthText.Visible=false end

    if sk.Enabled and head and torso then
        local cam=Workspace.CurrentCamera
        local parts={head,torso,model:FindFirstChild("Left Arm"),model:FindFirstChild("Right Arm"),model:FindFirstChild("Left Leg"),model:FindFirstChild("Right Leg")}
        local pairs={{1,2},{2,3},{2,4},{2,5},{2,6}}
        for i,pair in ipairs(pairs) do
            local a,b=parts[pair[1]],parts[pair[2]]
            if a and b then
                local pa,ona=cam:WorldToViewportPoint(a.Position)
                local pb,onb=cam:WorldToViewportPoint(b.Position)
                if ona and onb and pa.Z>0 and pb.Z>0 then setLine(skeleton[i],Vector2.new(pa.X,pa.Y),Vector2.new(pb.X,pb.Y),sk.Thickness or 1,sk.Color or Color3.new(1,1,1),sk.Transparency or 0) else skeleton[i].Visible=false end
            else skeleton[i].Visible=false end
        end
    else hideLines(skeleton) end

    if tracerOn then setLine(tracer,tracerOrigin(),Vector2.new(cx,br.Y),1,col,0) else tracer.Visible=false end
end)
