-- Reliable Visuals owner for the NPC/bot practice profile.
-- Rebuilds only target-oriented Visuals controls and leaves Combat/Movement/World,
-- local GunChams/SelfChams, FOV, crosshair and utility modules untouched.
-- Player characters are explicitly excluded.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec=objects.VisualsWindow
local Visuals=VisualsRec and VisualsRec.Api
if not Visuals then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP,"") end
local function optionName(key,rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$","")
end
local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end
local function removeVisual(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key,rec)==name and under(rec,VisualsRec) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

for _,name in ipairs({"ESP","Chams","Corner Box","Thermal Corner","HealthBar","Name + Distance","Skeleton","Tracers","Distance","3D Box","Preview"}) do
    removeVisual(name)
end

-- ---------------------------------------------------------------------------
-- Overlay and helpers
-- ---------------------------------------------------------------------------
local parentGui=(gethui and gethui()) or CoreGui
local old=parentGui and parentGui:FindFirstChild("YokaiBotVisualsReliableV14")
if old then pcall(function() old:Destroy() end) end
local Overlay=Instance.new("ScreenGui")
Overlay.Name="YokaiBotVisualsReliableV14"
Overlay.ResetOnSpawn=false
Overlay.IgnoreGuiInset=true
Overlay.DisplayOrder=1000
Overlay.Enabled=true
Overlay.Parent=parentGui or LocalPlayer:WaitForChild("PlayerGui")

local function newFrame(parent)
    local f=Instance.new("Frame")
    f.BorderSizePixel=0
    f.BackgroundColor3=Color3.new(1,1,1)
    f.Visible=false
    f.Parent=parent
    return f
end
local function newLabel(parent)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Font=Enum.Font.GothamSemibold
    t.TextSize=12
    t.TextColor3=Color3.new(1,1,1)
    t.TextStrokeTransparency=.35
    t.TextXAlignment=Enum.TextXAlignment.Center
    t.Visible=false
    t.Parent=parent
    return t
end
local function setLine(line,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then line.Visible=false return end
    line.AnchorPoint=Vector2.new(.5,.5)
    line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Size=UDim2.fromOffset(d.Magnitude,math.max(1,thickness or 1))
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3=color
    line.BackgroundTransparency=transparency or 0
    line.Visible=true
end

local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function explicitRoots()
    local out={}
    for _,name in ipairs({"Zombies","NPCs","Bots","Enemies","Mobs"}) do
        local r=Workspace:FindFirstChild(name)
        if r then table.insert(out,r) end
    end
    return out
end
local function insideExplicitRoot(model)
    for _,root in ipairs(explicitRoots()) do
        if model==root or model:IsDescendantOf(root) then return true end
    end
    return false
end
local function humanoidOf(model)
    return model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildWhichIsA("Humanoid",true)) or nil
end
local function rootOf(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart",true)
        or model:FindFirstChild("UpperTorso",true)
        or model:FindFirstChild("Torso",true)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart",true)
end
local function healthValueOf(model)
    if not model then return nil end
    for _,d in ipairs(model:GetDescendants()) do
        if (d:IsA("NumberValue") or d:IsA("IntValue")) and clean(d.Name):lower()=="health" then return d end
    end
end
local function healthInfo(model)
    local hum=humanoidOf(model)
    if hum then return hum.Health,math.max(1,hum.MaxHealth),hum end
    local h=healthValueOf(model)
    if h then
        local max=model:FindFirstChild("MaxHealth",true)
        local maxv=(max and (max:IsA("NumberValue") or max:IsA("IntValue"))) and max.Value or math.max(100,h.Value)
        return h.Value,math.max(1,maxv),h
    end
    return 100,100,nil
end
local function isBot(model)
    if not model or not model:IsA("Model") or not model.Parent or playerOwned(model) then return false end
    local root=rootOf(model)
    if not root then return false end
    if insideExplicitRoot(model) then return true end
    return humanoidOf(model)~=nil
end

local bots=setmetatable({}, {__mode="k"})
local function register(model)
    if isBot(model) then bots[model]=true end
end
local function scan()
    local foundRoot=false
    for _,root in ipairs(explicitRoots()) do
        foundRoot=true
        for _,d in ipairs(root:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end
        end
        for _,child in ipairs(root:GetChildren()) do
            if child:IsA("Model") then register(child) end
        end
    end
    if not foundRoot then
        for _,d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end
        end
    end
end
scan()
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(register,d.Parent) end
    if d:IsA("Model") then task.defer(register,d) end
end)

local function visibleFromCamera(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local filter={cam}
    if LocalPlayer.Character then table.insert(filter,LocalPlayer.Character) end
    rp.FilterDescendantsInstances=filter
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function bounds2D(model)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local ok,cf,size=pcall(model.GetBoundingBox,model)
    if not ok then return nil end
    local hx,hy,hz=size.X/2,size.Y/2,size.Z/2
    local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for _,x in ipairs({-hx,hx}) do for _,y in ipairs({-hy,hy}) do for _,z in ipairs({-hz,hz}) do
        local p=cam:WorldToViewportPoint((cf*CFrame.new(x,y,z)).Position)
        if p.Z>0 then
            any=true
            minx=math.min(minx,p.X); miny=math.min(miny,p.Y)
            maxx=math.max(maxx,p.X); maxy=math.max(maxy,p.Y)
        end
    end end end
    if not any then return nil end
    return minx,miny,maxx,maxy,cf,size
end

local cfg={
    ESP=false,Chams=false,Corner=false,Thermal=false,Health=false,NameDistance=false,Skeleton=false,Tracers=false,Box3D=false,
    WallCheck=true,MaxDistance=1800,Origin="Bottom",
    BaseColor=Color3.fromRGB(119,120,255),VisibleColor=Color3.fromRGB(45,230,155),OccludedColor=Color3.fromRGB(225,70,70),
    TracerColor=Color3.new(1,1,1),SkeletonColor=Color3.new(1,1,1),SkeletonTransparency=.1,SkeletonThickness=1,
}

local packs=setmetatable({}, {__mode="k"})
local bonesR15={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local bonesR6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local boxEdges={{1,2},{1,3},{1,5},{2,4},{2,6},{3,4},{3,7},{4,8},{5,6},{5,7},{6,8},{7,8}}

local function newPack(model)
    local p={}
    p.fill=newFrame(Overlay); p.fill.BackgroundTransparency=.88
    p.border={} for i=1,4 do p.border[i]=newFrame(Overlay) end
    p.corner={} for i=1,8 do p.corner[i]=newFrame(Overlay) end
    p.thermal=newFrame(Overlay); p.thermal.BackgroundTransparency=.58
    p.thermalGradient=Instance.new("UIGradient"); p.thermalGradient.Parent=p.thermal
    p.healthBG=newFrame(Overlay); p.healthBG.BackgroundColor3=Color3.fromRGB(8,8,8); p.healthBG.BackgroundTransparency=.15
    p.health=newFrame(Overlay)
    p.healthGradient=Instance.new("UIGradient"); p.healthGradient.Rotation=90; p.healthGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(65,235,185)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,225,110)),ColorSequenceKeypoint.new(1,Color3.fromRGB(235,70,70))}); p.healthGradient.Parent=p.health
    p.label=newLabel(Overlay)
    p.skeleton={} for i=1,14 do p.skeleton[i]=newFrame(Overlay) end
    p.tracer=newFrame(Overlay)
    p.box3d={} for i=1,12 do p.box3d[i]=newFrame(Overlay) end
    local hi=Instance.new("Highlight")
    hi.Name="YokaiBotReliableChamsV14"
    hi.Adornee=model
    hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hi.FillTransparency=.62
    hi.OutlineTransparency=.08
    hi.Enabled=false
    hi.Parent=model
    p.highlight=hi
    packs[model]=p
    return p
end
local function hidePack(p)
    if not p then return end
    p.fill.Visible=false; p.thermal.Visible=false; p.healthBG.Visible=false; p.health.Visible=false; p.label.Visible=false; p.tracer.Visible=false
    if p.highlight and p.highlight.Parent then p.highlight.Enabled=false end
    for _,list in ipairs({p.border,p.corner,p.skeleton,p.box3d}) do for _,x in ipairs(list) do x.Visible=false end end
end
local function destroyPack(model)
    local p=packs[model]
    if not p then return end
    for _,v in pairs(p) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in ipairs(v) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end
    end
    packs[model]=nil
end
local function rect(lines,x1,y1,x2,y2,color,t)
    setLine(lines[1],Vector2.new(x1,y1),Vector2.new(x2,y1),t,color,0)
    setLine(lines[2],Vector2.new(x2,y1),Vector2.new(x2,y2),t,color,0)
    setLine(lines[3],Vector2.new(x2,y2),Vector2.new(x1,y2),t,color,0)
    setLine(lines[4],Vector2.new(x1,y2),Vector2.new(x1,y1),t,color,0)
end
local function corners(lines,x1,y1,x2,y2,color,t)
    local w,h=x2-x1,y2-y1
    local cw,ch=math.max(5,w*.22),math.max(5,h*.22)
    local s={{Vector2.new(x1,y1),Vector2.new(x1+cw,y1)},{Vector2.new(x1,y1),Vector2.new(x1,y1+ch)},{Vector2.new(x2,y1),Vector2.new(x2-cw,y1)},{Vector2.new(x2,y1),Vector2.new(x2,y1+ch)},{Vector2.new(x1,y2),Vector2.new(x1+cw,y2)},{Vector2.new(x1,y2),Vector2.new(x1,y2-ch)},{Vector2.new(x2,y2),Vector2.new(x2-cw,y2)},{Vector2.new(x2,y2),Vector2.new(x2,y2-ch)}}
    for i,v in ipairs(s) do setLine(lines[i],v[1],v[2],t,color,0) end
end
local function tracerStart(cam)
    if cfg.Origin=="Top" then return Vector2.new(cam.ViewportSize.X/2,4) end
    if cfg.Origin=="Center" then return cam.ViewportSize/2 end
    if cfg.Origin=="Mouse" then
        local m=UserInputService:GetMouseLocation()
        return Vector2.new(math.clamp(m.X,0,cam.ViewportSize.X),math.clamp(m.Y,0,cam.ViewportSize.Y))
    end
    return Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y-4)
end

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------
local ESP=Visuals.CreateOptionsButton({["Name"]="ESP",["Function"]=function(v) cfg.ESP=v end,["HoverText"]="Bot/NPC-only 2D box."})
ESP.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) cfg.WallCheck=v end})
ESP.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.BaseColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) cfg.VisibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) cfg.OccludedColor=Color3.fromHSV(h,s,v) end})
local Chams=Visuals.CreateOptionsButton({["Name"]="Chams",["Function"]=function(v) cfg.Chams=v end})
local Corner=Visuals.CreateOptionsButton({["Name"]="Corner Box",["Function"]=function(v) cfg.Corner=v end})
local Thermal=Visuals.CreateOptionsButton({["Name"]="Thermal Corner",["Function"]=function(v) cfg.Thermal=v end})
local Health=Visuals.CreateOptionsButton({["Name"]="HealthBar",["Function"]=function(v) cfg.Health=v end})
local NameDistance=Visuals.CreateOptionsButton({["Name"]="Name + Distance",["Function"]=function(v) cfg.NameDistance=v end})
local Skeleton=Visuals.CreateOptionsButton({["Name"]="Skeleton",["Function"]=function(v) cfg.Skeleton=v end})
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.SkeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=100,["Default"]=10,["Function"]=function(v) cfg.SkeletonTransparency=v/100 end})
Skeleton.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=4,["Default"]=1,["Function"]=function(v) cfg.SkeletonThickness=v end})
local Tracers=Visuals.CreateOptionsButton({["Name"]="Tracers",["Function"]=function(v) cfg.Tracers=v end})
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Top","Bottom","Center","Mouse"},["Function"]=function(v) cfg.Origin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.TracerColor=Color3.fromHSV(h,s,v) end})
local Distance=Visuals.CreateOptionsButton({["Name"]="Distance",["Function"]=function() end})
Distance.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=4000,["Default"]=1800,["Function"]=function(v) cfg.MaxDistance=v end})
local Box3D=Visuals.CreateOptionsButton({["Name"]="3D Box",["Function"]=function(v) cfg.Box3D=v end})

-- Lightweight preview so the user can verify the Visuals callbacks even when no NPC
-- is currently streamed in. It never reads Player characters.
local previewEnabled=false
local Preview=Visuals.CreateOptionsButton({["Name"]="Preview",["Function"]=function(v) previewEnabled=v end})
local previewRoot=Instance.new("Frame")
previewRoot.Name="Preview"
previewRoot.AnchorPoint=Vector2.new(1,.5)
previewRoot.Position=UDim2.new(1,-30,.5,0)
previewRoot.Size=UDim2.fromOffset(180,260)
previewRoot.BackgroundColor3=Color3.fromRGB(18,18,21)
previewRoot.BackgroundTransparency=.08
previewRoot.BorderSizePixel=0
previewRoot.Visible=false
previewRoot.Parent=Overlay
local previewStroke=Instance.new("UIStroke"); previewStroke.Thickness=1; previewStroke.Transparency=.45; previewStroke.Parent=previewRoot
local previewTitle=newLabel(previewRoot); previewTitle.Visible=true; previewTitle.Text="Visuals Preview"; previewTitle.Size=UDim2.new(1,0,0,24); previewTitle.Position=UDim2.fromOffset(0,4)
local previewDummy=Instance.new("Frame"); previewDummy.AnchorPoint=Vector2.new(.5,.5); previewDummy.Position=UDim2.new(.5,0,.55,0); previewDummy.Size=UDim2.fromOffset(72,150); previewDummy.BorderSizePixel=0; previewDummy.BackgroundTransparency=.88; previewDummy.Parent=previewRoot
local previewDummyStroke=Instance.new("UIStroke"); previewDummyStroke.Thickness=1; previewDummyStroke.Parent=previewDummy

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------
local renderClock=0
RunService.RenderStepped:Connect(function(dt)
    renderClock+=dt
    if renderClock<1/45 then return end
    renderClock=0
    local cam=Workspace.CurrentCamera
    if not cam then return end

    previewRoot.Visible=previewEnabled
    if previewEnabled then
        local pc=cfg.WallCheck and cfg.VisibleColor or cfg.BaseColor
        previewDummy.BackgroundColor3=pc
        previewDummyStroke.Color=pc
        previewTitle.TextColor3=pc
    end

    for model in pairs(bots) do
        if not isBot(model) then
            destroyPack(model)
            bots[model]=nil
        else
            local root=rootOf(model)
            local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
            local p=packs[model]
            if not p or not p.highlight or not p.highlight.Parent then p=newPack(model) end
            hidePack(p)
            if dist<=cfg.MaxDistance then
                local head=model:FindFirstChild("Head",true) or root
                local vis=visibleFromCamera(model,head)
                local stateColor=cfg.WallCheck and (vis and cfg.VisibleColor or cfg.OccludedColor) or cfg.BaseColor
                local x1,y1,x2,y2,cf,size=bounds2D(model)
                if x1 then
                    if cfg.ESP then
                        p.fill.Visible=true; p.fill.Position=UDim2.fromOffset(x1,y1); p.fill.Size=UDim2.fromOffset(math.max(1,x2-x1),math.max(1,y2-y1)); p.fill.BackgroundColor3=stateColor
                        rect(p.border,x1,y1,x2,y2,stateColor,1)
                    end
                    if cfg.Corner then corners(p.corner,x1,y1,x2,y2,stateColor,1) end
                    if cfg.Thermal then
                        p.thermal.Visible=true; p.thermal.Position=UDim2.fromOffset(x1,y1); p.thermal.Size=UDim2.fromOffset(math.max(1,x2-x1),math.max(1,y2-y1)); p.thermal.BackgroundColor3=stateColor
                        p.thermalGradient.Rotation=(os.clock()*55)%360
                        p.thermalGradient.Color=ColorSequence.new(stateColor,Color3.fromRGB(18,18,24))
                        corners(p.corner,x1,y1,x2,y2,stateColor,1)
                    end
                    if cfg.Health then
                        local hp,maxhp=healthInfo(model)
                        local ratio=math.clamp(hp/math.max(1,maxhp),0,1)
                        local h=math.max(1,y2-y1)
                        p.healthBG.Visible=true; p.healthBG.Position=UDim2.fromOffset(x2+6,y1); p.healthBG.Size=UDim2.fromOffset(4,h)
                        p.health.Visible=true; p.health.Position=UDim2.fromOffset(x2+7,y2-h*ratio); p.health.Size=UDim2.fromOffset(2,h*ratio)
                    end
                    if cfg.NameDistance then
                        p.label.Visible=true; p.label.Position=UDim2.fromOffset(x1-25,y1-21); p.label.Size=UDim2.fromOffset((x2-x1)+50,18); p.label.Text=string.format("%s  [%d]",model.Name,math.floor(dist+.5)); p.label.TextColor3=stateColor
                    end
                    if cfg.Tracers then setLine(p.tracer,tracerStart(cam),Vector2.new((x1+x2)/2,y2),1,cfg.TracerColor,.05) end
                    if cfg.Skeleton then
                        local hum=humanoidOf(model)
                        local list=(hum and hum.RigType==Enum.HumanoidRigType.R6) and bonesR6 or bonesR15
                        local idx=0
                        for _,pair in ipairs(list) do
                            local a=model:FindFirstChild(pair[1],true); local b=model:FindFirstChild(pair[2],true)
                            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                                local sa=cam:WorldToViewportPoint(a.Position); local sb=cam:WorldToViewportPoint(b.Position)
                                if sa.Z>0 and sb.Z>0 then idx+=1; if p.skeleton[idx] then setLine(p.skeleton[idx],Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),cfg.SkeletonThickness,cfg.SkeletonColor,cfg.SkeletonTransparency) end end
                            end
                        end
                    end
                    if cfg.Box3D and cf and size then
                        local hx,hy,hz=size.X/2,size.Y/2,size.Z/2
                        local worldCorners={
                            (cf*CFrame.new(-hx,-hy,-hz)).Position,(cf*CFrame.new(-hx,-hy,hz)).Position,(cf*CFrame.new(-hx,hy,-hz)).Position,(cf*CFrame.new(-hx,hy,hz)).Position,
                            (cf*CFrame.new(hx,-hy,-hz)).Position,(cf*CFrame.new(hx,-hy,hz)).Position,(cf*CFrame.new(hx,hy,-hz)).Position,(cf*CFrame.new(hx,hy,hz)).Position,
                        }
                        local screen={}
                        for i,w in ipairs(worldCorners) do local s=cam:WorldToViewportPoint(w); screen[i]=s.Z>0 and Vector2.new(s.X,s.Y) or nil end
                        for i,e in ipairs(boxEdges) do if screen[e[1]] and screen[e[2]] then setLine(p.box3d[i],screen[e[1]],screen[e[2]],1,stateColor,0) end end
                    end
                end
                if cfg.Chams and p.highlight and p.highlight.Parent then
                    p.highlight.Enabled=true; p.highlight.FillColor=stateColor; p.highlight.OutlineColor=stateColor
                end
            end
        end
    end
end)

-- Streaming-safe refresh. Cheap and restricted to NPC/bot candidates.
task.spawn(function()
    while shared.YokaiExecuted~=false do
        task.wait(2)
        scan()
    end
end)

shared.YokaiBotVisualsReliableV14={Config=cfg,Bots=bots,Overlay=Overlay}
pcall(function() GuiLibrary.CreateNotification("Yokai","Bot Visuals V14 loaded",3) end)
