-- Visuals styles adapted from the user-supplied ESP examples.
-- These controls render in a local draggable preview. They do not target live players.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then
    warn("AttachedVisualsPreview: Visuals window missing")
    return
end

local ZWSP=utf8.char(0x200B)
local function opt(name,fn)
    return Visuals.CreateOptionsButton({["Name"]=name..ZWSP..ZWSP,["Function"]=fn})
end

local state={
    Preview=true,
    Chams=false,Thermal=true,ChamsColor=Color3.fromRGB(119,120,255),
    Corner=false,CornerColor=Color3.fromRGB(255,255,255),CornerFill=Color3.fromRGB(0,0,0),
    ThermalCorner=false,ThermalFill=Color3.fromRGB(119,120,255),
    Health=false,HealthText=true,Health=0.76,
    NameDistance=false,Friend=true,NameColor=Color3.fromRGB(255,255,255),FriendColor=Color3.fromRGB(0,255,0),DistanceColor=Color3.fromRGB(255,255,255),
    Skeleton=false,SkeletonColor=Color3.fromRGB(255,255,255),
    Tracers=false,TracerOrigin="Bottom",TracerColor=Color3.fromRGB(255,255,255),TracerThickness=1,
    Box3D=false,Box3DColor=Color3.fromRGB(255,255,255),
    Pack=false,
}

local gui=Instance.new("ScreenGui")
gui.Name="YokaiAttachedESPPreview"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=996
gui.Parent=LocalPlayer:WaitForChild("PlayerGui")

local frame=Instance.new("Frame")
frame.Name="Window"
frame.Size=UDim2.fromOffset(280,360)
frame.Position=UDim2.new(1,-590,0,72)
frame.BackgroundColor3=Color3.fromRGB(14,14,18)
frame.BorderSizePixel=0
frame.Parent=gui
local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,9) fc.Parent=frame
local fs=Instance.new("UIStroke") fs.Color=Color3.fromRGB(65,66,75) fs.Transparency=.2 fs.Parent=frame

local title=Instance.new("TextLabel")
title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(14,7) title.Size=UDim2.new(1,-28,0,26)
title.Font=Enum.Font.Code title.TextSize=13 title.TextColor3=Color3.fromRGB(235,235,240)
title.TextXAlignment=Enum.TextXAlignment.Left title.Text="Attached ESP Preview • drag" title.Parent=frame

local canvas=Instance.new("Frame")
canvas.Position=UDim2.fromOffset(12,38) canvas.Size=UDim2.new(1,-24,1,-50)
canvas.BackgroundColor3=Color3.fromRGB(21,21,26) canvas.BorderSizePixel=0 canvas.ClipsDescendants=true canvas.Parent=frame
local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=canvas

local dragging=false local dragStart local frameStart
local function beginDrag(input)
    dragging=true dragStart=input.Position frameStart=frame.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
end
title.Active=true
title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then beginDrag(input) end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart
        frame.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
    end
end)

local function label(text,size)
    local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Size=size or UDim2.fromOffset(130,18)
    t.AnchorPoint=Vector2.new(.5,.5) t.Font=Enum.Font.Code t.TextSize=11 t.TextStrokeTransparency=0 t.TextColor3=Color3.new(1,1,1) t.Text=text or "" t.Parent=canvas
    return t
end
local function line()
    local f=Instance.new("Frame") f.BorderSizePixel=0 f.AnchorPoint=Vector2.new(.5,.5) f.BackgroundColor3=Color3.new(1,1,1) f.Visible=false f.Parent=canvas return f
end
local function setLine(f,a,b,thick,color)
    local d=b-a if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thick or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color or Color3.new(1,1,1) f.Visible=true
end

local dummy=Instance.new("Frame")
dummy.AnchorPoint=Vector2.new(.5,.5) dummy.Position=UDim2.new(.5,0,.53,0) dummy.Size=UDim2.fromOffset(70,180)
dummy.BackgroundColor3=Color3.fromRGB(72,74,82) dummy.BorderSizePixel=0 dummy.Parent=canvas
local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(0,5) dc.Parent=dummy
local ds=Instance.new("UIStroke") ds.Thickness=1 ds.Color=Color3.fromRGB(95,97,107) ds.Parent=dummy

local head=Instance.new("Frame") head.AnchorPoint=Vector2.new(.5,.5) head.Position=UDim2.new(.5,0,0,-26) head.Size=UDim2.fromOffset(40,40) head.BorderSizePixel=0 head.BackgroundColor3=dummy.BackgroundColor3 head.Parent=dummy
local hc=Instance.new("UICorner") hc.CornerRadius=UDim.new(0,6) hc.Parent=head

local nameLabel=label("(F) Dummy [87]",UDim2.fromOffset(180,18)) nameLabel.Position=UDim2.new(.5,0,.13,0)
local distLabel=label("87 meters",UDim2.fromOffset(160,18)) distLabel.Position=UDim2.new(.5,0,.88,0)
local weaponLabel=label("Weapon",UDim2.fromOffset(120,16)) weaponLabel.Position=UDim2.new(.5,0,.82,0) weaponLabel.TextColor3=Color3.fromRGB(119,120,255)
local healthText=label("76",UDim2.fromOffset(36,16)) healthText.Position=UDim2.new(.33,0,.44,0)

local healthBack=Instance.new("Frame") healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Parent=canvas
local health=Instance.new("Frame") health.BorderSizePixel=0 health.BackgroundColor3=Color3.new(1,1,1) health.Parent=canvas
local grad=Instance.new("UIGradient") grad.Rotation=-90 grad.Parent=health
grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(60,60,125)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,120,255))})

local fill=Instance.new("Frame") fill.BackgroundTransparency=.75 fill.BorderSizePixel=0 fill.Visible=false fill.Parent=canvas
local corners={} for i=1,8 do corners[i]=line() end
local skeleton={} for i=1,14 do skeleton[i]=line() end
local box3d={} for i=1,12 do box3d[i]=line() end
local tracer=line()

local badge=label("ATTACHED VISUALS",UDim2.fromOffset(160,16)) badge.AnchorPoint=Vector2.new(.5,0) badge.Position=UDim2.new(.5,0,0,5) badge.TextSize=9 badge.TextColor3=Color3.fromRGB(150,152,165)

local function hideLines(tbl) for _,f in ipairs(tbl) do f.Visible=false end end

local function update()
    gui.Enabled=state.Preview
    if not state.Preview then return end
    local sz=canvas.AbsoluteSize if sz.X<10 or sz.Y<10 then return end
    local cx,cy=sz.X*.5,sz.Y*.53
    local w,h=70,180
    local top,left,right,bottom=cy-h/2,cx-w/2,cx+w/2,cy+h/2

    local pack=state.Pack
    local chams=state.Chams or pack
    local thermalCorner=state.ThermalCorner or pack
    local corner=state.Corner or pack
    local healthOn=state.Health or pack
    local nameOn=state.NameDistance or pack
    local skel=state.Skeleton or pack
    local tr=state.Tracers or pack
    local box=state.Box3D or pack

    local breathe=.5+(math.sin(os.clock()*2)+1)*.15
    if chams then
        local c=state.ChamsColor
        dummy.BackgroundColor3=c head.BackgroundColor3=c
        dummy.BackgroundTransparency=state.Thermal and breathe or .18
        head.BackgroundTransparency=dummy.BackgroundTransparency
        ds.Color=c ds.Thickness=2 ds.Transparency=state.Thermal and math.clamp(breathe-.25,0,.7) or 0
    else
        dummy.BackgroundColor3=Color3.fromRGB(72,74,82) head.BackgroundColor3=dummy.BackgroundColor3
        dummy.BackgroundTransparency=0 head.BackgroundTransparency=0 ds.Color=Color3.fromRGB(95,97,107) ds.Thickness=1 ds.Transparency=0
    end

    fill.Visible=corner or thermalCorner
    if fill.Visible then
        fill.Position=UDim2.fromOffset(left,top) fill.Size=UDim2.fromOffset(w,h)
        fill.BackgroundColor3=thermalCorner and state.ThermalFill or state.CornerFill
        fill.BackgroundTransparency=thermalCorner and breathe or .75
    end

    local cw,ch=w/5,h/5
    local cpairs={
        {Vector2.new(left,top),Vector2.new(left+cw,top)},{Vector2.new(left,top),Vector2.new(left,top+ch)},
        {Vector2.new(right,top),Vector2.new(right-cw,top)},{Vector2.new(right,top),Vector2.new(right,top+ch)},
        {Vector2.new(left,bottom),Vector2.new(left+cw,bottom)},{Vector2.new(left,bottom),Vector2.new(left,bottom-ch)},
        {Vector2.new(right,bottom),Vector2.new(right-cw,bottom)},{Vector2.new(right,bottom),Vector2.new(right,bottom-ch)},
    }
    if corner or thermalCorner then for i,p in ipairs(cpairs) do setLine(corners[i],p[1],p[2],1,state.CornerColor) end else hideLines(corners) end

    healthBack.Visible=healthOn health.Visible=healthOn healthText.Visible=healthOn and state.HealthText
    if healthOn then
        local ratio=state.Health
        healthBack.Position=UDim2.fromOffset(left-8,top) healthBack.Size=UDim2.fromOffset(4,h)
        health.Position=UDim2.fromOffset(left-8,top+h*(1-ratio)) health.Size=UDim2.fromOffset(4,h*ratio)
        healthText.Position=UDim2.fromOffset(left-22,top+h*(1-ratio)) healthText.Text=tostring(math.floor(ratio*100)) healthText.TextColor3=Color3.fromRGB(119,120,255)
    end

    nameLabel.Visible=nameOn distLabel.Visible=nameOn weaponLabel.Visible=pack
    if nameOn then
        local flag=state.Friend and "F" or "E"
        nameLabel.Text="("..flag..") Dummy [87]" nameLabel.TextColor3=state.Friend and state.FriendColor or state.NameColor
        distLabel.TextColor3=state.DistanceColor
    end

    local pts={
        Head=Vector2.new(cx,top-26),Chest=Vector2.new(cx,top+42),Hip=Vector2.new(cx,top+94),
        LShoulder=Vector2.new(cx-34,top+44),LElbow=Vector2.new(cx-46,top+83),LHand=Vector2.new(cx-50,top+118),
        RShoulder=Vector2.new(cx+34,top+44),RElbow=Vector2.new(cx+46,top+83),RHand=Vector2.new(cx+50,top+118),
        LKnee=Vector2.new(cx-18,top+142),LFoot=Vector2.new(cx-22,bottom+4),RKnee=Vector2.new(cx+18,top+142),RFoot=Vector2.new(cx+22,bottom+4),
    }
    local bones={{"Head","Chest"},{"Chest","Hip"},{"Chest","LShoulder"},{"LShoulder","LElbow"},{"LElbow","LHand"},{"Chest","RShoulder"},{"RShoulder","RElbow"},{"RElbow","RHand"},{"Hip","LKnee"},{"LKnee","LFoot"},{"Hip","RKnee"},{"RKnee","RFoot"}}
    if skel then for i,b in ipairs(bones) do setLine(skeleton[i],pts[b[1]],pts[b[2]],1,state.SkeletonColor) end for i=#bones+1,#skeleton do skeleton[i].Visible=false end else hideLines(skeleton) end

    if tr then
        local start
        if state.TracerOrigin=="Center" then start=Vector2.new(sz.X/2,sz.Y/2)
        elseif state.TracerOrigin=="Top" then start=Vector2.new(sz.X/2,0)
        elseif state.TracerOrigin=="Mouse" then
            local m=UserInputService:GetMouseLocation() local abs=canvas.AbsolutePosition start=Vector2.new(math.clamp(m.X-abs.X,0,sz.X),math.clamp(m.Y-abs.Y,0,sz.Y))
        else start=Vector2.new(sz.X/2,sz.Y) end
        setLine(tracer,start,Vector2.new(cx,cy),state.TracerThickness,state.TracerColor)
    else tracer.Visible=false end

    if box then
        local ox,oy=14,-12
        local a=Vector2.new(left,top) local b=Vector2.new(right,top) local c=Vector2.new(right,bottom) local d=Vector2.new(left,bottom)
        local a2=a+Vector2.new(ox,oy) local b2=b+Vector2.new(ox,oy) local c2=c+Vector2.new(ox,oy) local d2=d+Vector2.new(ox,oy)
        local edges={{a,b},{b,c},{c,d},{d,a},{a2,b2},{b2,c2},{c2,d2},{d2,a2},{a,a2},{b,b2},{c,c2},{d,d2}}
        for i,e in ipairs(edges) do setLine(box3d[i],e[1],e[2],1,state.Box3DColor) end
    else hideLines(box3d) end
end

local Preview=opt("Attached Preview",function(v) state.Preview=v update() end)

local Chams=opt("Chams Style",function(v) state.Chams=v end)
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) state.Thermal=v end})
Chams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) state.ChamsColor=Color3.fromHSV(h,s,v) end})

local Corner=opt("Corner Box",function(v) state.Corner=v end)
Corner.CreateColorSlider({["Name"]="Corner Color",["Function"]=function(h,s,v) state.CornerColor=Color3.fromHSV(h,s,v) end})
Corner.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) state.CornerFill=Color3.fromHSV(h,s,v) end})

local Thermal=opt("Thermal Corner",function(v) state.ThermalCorner=v end)
Thermal.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) state.ThermalFill=Color3.fromHSV(h,s,v) end})

local Health=opt("HealthBar",function(v) state.Health=v end)
Health.CreateToggle({["Name"]="Health Text",["Default"]=true,["Function"]=function(v) state.HealthText=v end})
Health.CreateSlider({["Name"]="Preview Health",["Min"]=1,["Max"]=100,["Default"]=76,["Function"]=function(v) state.Health=v/100 end})

local NameDistance=opt("Name + Distance",function(v) state.NameDistance=v end)
NameDistance.CreateToggle({["Name"]="Friend",["Default"]=true,["Function"]=function(v) state.Friend=v end})
NameDistance.CreateColorSlider({["Name"]="Name Color",["Function"]=function(h,s,v) state.NameColor=Color3.fromHSV(h,s,v) end})
NameDistance.CreateColorSlider({["Name"]="Friend Color",["Function"]=function(h,s,v) state.FriendColor=Color3.fromHSV(h,s,v) end})
NameDistance.CreateColorSlider({["Name"]="Distance Color",["Function"]=function(h,s,v) state.DistanceColor=Color3.fromHSV(h,s,v) end})

local Skeleton=opt("Skeleton Style",function(v) state.Skeleton=v end)
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) state.SkeletonColor=Color3.fromHSV(h,s,v) end})

local Tracers=opt("Tracers Style",function(v) state.Tracers=v end)
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Bottom","Center","Mouse","Top"},["Function"]=function(v) state.TracerOrigin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) state.TracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=3,["Default"]=1,["Function"]=function(v) state.TracerThickness=v end})

local Box3D=opt("3D Box Style",function(v) state.Box3D=v end)
Box3D.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) state.Box3DColor=Color3.fromHSV(h,s,v) end})

local Pack=opt("ESP Pack",function(v) state.Pack=v end)

RunService.RenderStepped:Connect(update)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Attached Visuals preview styles loaded",3) end)
