-- Safe visual test target. Never renders or inspects other real players.
-- It creates one local synthetic R6 target so ESP/health/skeleton/wallcheck/tracer
-- settings can be exercised reliably in Baseplate, Studio, or a private test map.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then return end

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
local function removeVisualOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- Replace Skeleton with one shared-state version so Preview/test target use the same settings.
removeVisualOption("Skeleton")
local skeletonState={Enabled=false,Color=Color3.fromRGB(255,255,255),Transparency=0,Thickness=1}
shared.YokaiSafeTestSkeletonState=skeletonState
local Skeleton=Visuals.CreateOptionsButton({
    ["Name"]="Skeleton",
    ["Function"]=function(v) skeletonState.Enabled=v end,
    ["HoverText"]="Safe visual-test skeleton settings.",
})
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) skeletonState.Color=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=0,["Function"]=function(v) skeletonState.Transparency=v/100 end})
Skeleton.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) skeletonState.Thickness=v end})

local roots={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
pcall(function() if gethui then table.insert(roots,gethui()) end end)
for _,root in ipairs(roots) do
    if root then
        for _,n in ipairs({"YokaiStudioSinglePlayerVisuals","YokaiSafeVisualTestOverlay"}) do
            local g=root:FindFirstChild(n,true)
            if g then pcall(function() g:Destroy() end) end
        end
    end
end
for _,n in ipairs({"YokaiStudioTestTarget","YokaiSafeVisualTestTarget"}) do
    local old=Workspace:FindFirstChild(n)
    if old then old:Destroy() end
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

local function spawnCFrame()
    local cam=Workspace.CurrentCamera
    if cam then
        local look=cam.CFrame.LookVector
        local flat=Vector3.new(look.X,0,look.Z)
        if flat.Magnitude<0.01 then flat=Vector3.new(0,0,-1) else flat=flat.Unit end
        local origin=cam.CFrame.Position+flat*18+Vector3.new(0,8,0)
        local rp=RaycastParams.new()
        rp.FilterType=Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
        local hit=Workspace:Raycast(origin,Vector3.new(0,-80,0),rp)
        local y=hit and (hit.Position.Y+3) or (cam.CFrame.Position.Y-2)
        local pos=Vector3.new(origin.X,y,origin.Z)
        return CFrame.lookAt(pos,pos-flat)
    end
    local char=LocalPlayer.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    return root and (root.CFrame*CFrame.new(0,0,-18)) or CFrame.new(0,4,-18)
end

local target=Instance.new("Model")
target.Name="YokaiSafeVisualTestTarget"
target.Parent=Workspace
local hum=Instance.new("Humanoid")
hum.MaxHealth=100 hum.Health=76 hum.Parent=target
local base=spawnCFrame()
local hrp=makePart(target,"HumanoidRootPart",Vector3.new(2,2,1),base*CFrame.new(0,0,0),Color3.new(1,1,1),1)
makePart(target,"Torso",Vector3.new(2,2,1),base*CFrame.new(0,0,0))
makePart(target,"Head",Vector3.new(2,1,1),base*CFrame.new(0,1.5,0))
makePart(target,"Left Arm",Vector3.new(1,2,1),base*CFrame.new(-1.5,0,0))
makePart(target,"Right Arm",Vector3.new(1,2,1),base*CFrame.new(1.5,0,0))
makePart(target,"Left Leg",Vector3.new(1,2,1),base*CFrame.new(-.5,-2,0))
makePart(target,"Right Leg",Vector3.new(1,2,1),base*CFrame.new(.5,-2,0))
target.PrimaryPart=hrp

local overlay=Instance.new("ScreenGui")
overlay.Name="YokaiSafeVisualTestOverlay"
overlay.ResetOnSpawn=false
overlay.IgnoreGuiInset=true
overlay.DisplayOrder=999
pcall(function() overlay.Parent=(gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local highlight=Instance.new("Highlight")
highlight.Name="YokaiSafeVisualTestHighlight"
highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
highlight.FillTransparency=.72
highlight.OutlineTransparency=0
highlight.Enabled=false
highlight.Parent=Workspace

local function newLine()
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
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
name.BackgroundTransparency=1 name.AnchorPoint=Vector2.new(.5,.5) name.Size=UDim2.fromOffset(220,18)
name.Font=Enum.Font.Code name.TextSize=12 name.TextStrokeTransparency=0 name.TextStrokeColor3=Color3.new(0,0,0)
name.TextColor3=Color3.new(1,1,1) name.Text="VisualTestTarget" name.Visible=false name.Parent=overlay
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
    return ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(220,40,50)),ColorSequenceKeypoint.new(1,Color3.fromRGB(50,110,255))})
end

local function bounds(model)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local cf,size=model:GetBoundingBox()
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local wp=(cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position
        local p=cam:WorldToViewportPoint(wp)
        if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
    end end end
    if not any or maxX<0 or maxY<0 or minX>cam.ViewportSize.X or minY>cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end

local function wallVisible(part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
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
    highlight.Enabled=false name.Visible=false distance.Visible=false healthText.Visible=false healthBack.Visible=false health.Visible=false tracer.Visible=false hideLines(corners) hideLines(skeleton)
end

RunService.RenderStepped:Connect(function()
    if not target.Parent then hideAll() return end
    local cam=Workspace.CurrentCamera
    if not cam then hideAll() return end
    local root=target:FindFirstChild("HumanoidRootPart")
    local head=target:FindFirstChild("Head")
    local torso=target:FindFirstChild("Torso")
    local tl,br=bounds(target)
    if not root or not tl then hideAll() return end

    local espOn=enabled("ESP")
    local healthOn=enabled("HealthBar") or espOn
    local namesOn=enabled("Name + Distance") or espOn
    local cornerOn=enabled("Corner Box") or espOn
    local tracerOn=enabled("Tracers")
    local state=shared.YokaiVisualPreviewState or {}
    local color=state.DefaultColor or Color3.fromRGB(119,120,255)
    if espOn and state.WallCheck then color=wallVisible(head or root) and (state.VisibleColor or Color3.fromRGB(35,235,95)) or (state.OccludedColor or Color3.fromRGB(245,55,55)) end

    highlight.Adornee=target highlight.Enabled=espOn highlight.FillColor=color highlight.OutlineColor=color
    if cornerOn then updateCorners(tl,br,color) else hideLines(corners) end

    local cx=(tl.X+br.X)/2
    if namesOn then
        name.Position=UDim2.fromOffset(cx,tl.Y-11) name.Visible=true name.TextColor3=Color3.new(1,1,1)
        local d=(cam.CFrame.Position-root.Position).Magnitude/3.5714285714
        distance.Position=UDim2.fromOffset(cx,br.Y+9) distance.Text=string.format("%d meters",math.floor(d)) distance.Visible=true distance.TextColor3=Color3.new(1,1,1)
    else name.Visible=false distance.Visible=false end

    if healthOn then
        local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
        local h=math.max(4,br.Y-tl.Y)
        healthBack.Position=UDim2.fromOffset(tl.X-7,tl.Y) healthBack.Size=UDim2.fromOffset(4,h) healthBack.Visible=true
        health.Position=UDim2.fromOffset(tl.X-7,tl.Y+h*(1-ratio)) health.Size=UDim2.fromOffset(4,h*ratio) healthGradient.Color=palette() health.Visible=true
        healthText.Position=UDim2.fromOffset(tl.X-20,tl.Y+h*(1-ratio)) healthText.Text=tostring(math.floor(ratio*100)) healthText.Visible=true healthText.TextColor3=Color3.new(1,1,1)
    else healthBack.Visible=false health.Visible=false healthText.Visible=false end

    if skeletonState.Enabled and head and torso then
        local parts={head,torso,target:FindFirstChild("Left Arm"),target:FindFirstChild("Right Arm"),target:FindFirstChild("Left Leg"),target:FindFirstChild("Right Leg")}
        local pairs={{1,2},{2,3},{2,4},{2,5},{2,6}}
        for i,pair in ipairs(pairs) do
            local a,b=parts[pair[1]],parts[pair[2]]
            if a and b then
                local pa,ona=cam:WorldToViewportPoint(a.Position)
                local pb,onb=cam:WorldToViewportPoint(b.Position)
                if ona and onb and pa.Z>0 and pb.Z>0 then setLine(skeleton[i],Vector2.new(pa.X,pa.Y),Vector2.new(pb.X,pb.Y),skeletonState.Thickness,skeletonState.Color,skeletonState.Transparency) else skeleton[i].Visible=false end
            else skeleton[i].Visible=false end
        end
    else hideLines(skeleton) end

    if tracerOn then setLine(tracer,tracerOrigin(),Vector2.new(cx,br.Y),1,color,0) else tracer.Visible=false end
end)
