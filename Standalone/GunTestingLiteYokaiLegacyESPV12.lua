-- GunTestingLiteYokaiLegacyESPV12.lua
-- Legacy Yokai ESP renderer ported from AttachedVisualsPreview.lua.
-- Rendering style/functions are preserved; target source is direct bot rigs in Workspace.Players.
-- Real Roblox Player.Character models are excluded.

if shared.GunTestingLiteYokaiLegacyESPV12 then return end
shared.GunTestingLiteYokaiLegacyESPV12=true

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local LocalPlayer=Players.LocalPlayer
local parent=(gethui and gethui()) or CoreGui

local Gui=parent:FindFirstChild("GunTestingLiteV1",true)
if not Gui then
    for _=1,100 do task.wait(.05); Gui=parent:FindFirstChild("GunTestingLiteV1",true); if Gui then break end end
end
if not Gui then return end

local function findPage(name)
    for _,d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name==name then return d end
    end
end
local Visuals=findPage("Visuals")
if not Visuals then return end

-- Hide all previous bot ESP controls; keep crosshair + car ESP.
local hideLabels={
    ["ESP Master"]=true,["Corner"]=true,["Corner Box"]=true,["Box"]=true,["3D Box"]=true,["Chams"]=true,["Name"]=true,["Distance"]=true,
    ["HealthBar"]=true,["Lines"]=true,["Visual Distance"]=true,["Snapline"]=true,["Snap Origin"]=true,["Snap Thickness"]=true,
    ["Snap Transparency %"]=true,["Snap Distance"]=true,["ESP (all replicated bots)"]=true,["Snapline / Lines"]=true,["Line Origin"]=true,
    ["Max Distance"]=true,["ESP FPS"]=true,["Thermal Corner"]=true,["Name + Distance"]=true,["Skeleton"]=true,["Tracers"]=true,["ESP Pack"]=true,
    ["Self ESP Render Test"]=true,["First Bot ESP Probe"]=true,["Static Overlay Test"]=true,["Self 2D Box Test"]=true,["Self Highlight Test"]=true,
}
for _,child in ipairs(Visuals:GetChildren()) do
    if child:IsA("Frame") then
        local label=child:FindFirstChildOfClass("TextLabel")
        if label and hideLabels[label.Text] then child.Visible=false end
    elseif child:IsA("TextLabel") then
        local t=tostring(child.Text):upper()
        if t:find("WORKSPACE.PLAYERS VISUALS",1,true) or t:find("RENDERER PROBE",1,true) or t:find("ESP DIAGNOSTICS",1,true) or t:find("DIRECT WORKSPACE.PLAYERS ESP",1,true) then
            child.Visible=false
        end
    end
end

local accent=Color3.fromRGB(125,82,235)
local order=60000
local function section(text)
    local l=Instance.new("TextLabel")
    l.LayoutOrder=order; order+=1; l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(166,159,192)
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=Visuals
end
local function row(label)
    local f=Instance.new("Frame")
    f.LayoutOrder=order; order+=1; f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=Visuals
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0)
    t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(230,230,240); t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f,t
end
local function toggle(label,cfg,key)
    local f=row(label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=cfg[key]==true; b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function() cfg[key]=not cfg[key]; paint() end); paint()
end

local overlay=Instance.new("ScreenGui")
overlay.Name="YokaiAttachedVisualsFunctional"
overlay.ResetOnSpawn=false
overlay.IgnoreGuiInset=true
overlay.DisplayOrder=998
pcall(function() overlay.Parent=parent end)
if not overlay.Parent then overlay.Parent=LocalPlayer:WaitForChild("PlayerGui") end

-- Exact legacy renderer primitives -------------------------------------------
local function createLine(parentObj,color)
    local f=Instance.new("Frame")
    f.BorderSizePixel=0; f.AnchorPoint=Vector2.new(.5,.5); f.BackgroundColor3=color or Color3.new(1,1,1); f.Visible=false; f.Parent=parentObj
    return f
end
local function setLine(f,a,b,thickness,color)
    if not f then return end
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    if color then f.BackgroundColor3=color end
    f.Visible=true
end
local function hideList(list)
    if list then for _,x in ipairs(list) do if x then x.Visible=false end end end
end

local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isRealPlayerCharacter(model)
    if not model then return false end
    local ok,p=pcall(function() return Players:GetPlayerFromCharacter(model) end)
    if ok and p then return true end
    for _,plr in ipairs(Players:GetPlayers()) do if plr.Character==model then return true end end
    return model==LocalPlayer.Character
end
local function validBot(model,folder)
    if not model or not model:IsA("Model") or model.Parent~=folder or isRealPlayerCharacter(model) then return nil end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=rootOf(model)
    if not hum or not root or hum.Health<=0 then return nil end
    return model,hum,root
end
local function screenData(root)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local p,on=cam:WorldToViewportPoint(root.Position)
    if not on or p.Z<=0 then return nil end
    local scale=(root.Size.Y*cam.ViewportSize.Y)/(p.Z*2)
    return Vector2.new(p.X,p.Y),3*scale,4.5*scale,(cam.CFrame.Position-root.Position).Magnitude/3.5714285714
end

local cfg={
    Chams=false,ChamsThermal=true,ChamsFill=Color3.fromRGB(119,120,255),ChamsOutline=Color3.fromRGB(119,120,255),
    Corner=false,CornerLine=Color3.fromRGB(255,255,255),CornerFill=Color3.fromRGB(0,0,0),
    ThermalCorner=false,ThermalCornerLine=Color3.fromRGB(255,255,255),ThermalCornerFill=Color3.fromRGB(119,120,255),
    Health=false,HealthText=true,HealthTextColor=Color3.fromRGB(119,120,255),HealthWidth=2.5,
    NameDistance=false,NameColor=Color3.fromRGB(255,255,255),DistanceColor=Color3.fromRGB(255,255,255),DistancePosition="Text",
    Skeleton=false,SkeletonColor=Color3.fromRGB(255,255,255),
    Tracers=false,TracerColor=Color3.fromRGB(255,255,255),TracerThickness=1,TracerCenter=false,
    Box3D=false,Box3DColor=Color3.fromRGB(255,255,255),ESP=false,
}

section("Yokai Legacy ESP - copied renderer")
local _,status=row("Legacy targets: 0")
status.TextColor3=Color3.fromRGB(168,210,255)
toggle("Chams",cfg,"Chams")
toggle("Corner Box",cfg,"Corner")
toggle("Thermal Corner",cfg,"ThermalCorner")
toggle("HealthBar",cfg,"Health")
toggle("Name + Distance",cfg,"NameDistance")
toggle("Skeleton",cfg,"Skeleton")
toggle("Tracers",cfg,"Tracers")
toggle("3D Box",cfg,"Box3D")
toggle("ESP Pack",cfg,"ESP")

local stores={}
local function newCornerSet() local t={} for i=1,8 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end
local function newSkeletonSet() local t={} for i=1,14 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end
local function newBox3DSet() local t={} for i=1,12 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end

local function newStore(model)
    local s={Model=model}
    s.Chams=Instance.new("Highlight"); s.Chams.Name="AttachedChams"; s.Chams.FillTransparency=1; s.Chams.OutlineTransparency=0; s.Chams.OutlineColor=Color3.fromRGB(119,120,255); s.Chams.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; s.Chams.Enabled=false; s.Chams.Parent=overlay
    s.CornerFill=Instance.new("Frame"); s.CornerFill.BorderSizePixel=0; s.CornerFill.BackgroundColor3=Color3.fromRGB(0,0,0); s.CornerFill.BackgroundTransparency=.75; s.CornerFill.Visible=false; s.CornerFill.Parent=overlay; s.Corner=newCornerSet()
    s.ThermalFill=Instance.new("Frame"); s.ThermalFill.BorderSizePixel=0; s.ThermalFill.BackgroundColor3=Color3.fromRGB(119,120,255); s.ThermalFill.BackgroundTransparency=.75; s.ThermalFill.Visible=false; s.ThermalFill.Parent=overlay; s.ThermalCorner=newCornerSet()
    s.HealthBack=Instance.new("Frame"); s.HealthBack.BorderSizePixel=0; s.HealthBack.BackgroundColor3=Color3.fromRGB(0,0,0); s.HealthBack.Visible=false; s.HealthBack.Parent=overlay
    s.Health=Instance.new("Frame"); s.Health.BorderSizePixel=0; s.Health.BackgroundColor3=Color3.fromRGB(255,255,255); s.Health.Visible=false; s.Health.Parent=overlay
    s.HealthGradient=Instance.new("UIGradient"); s.HealthGradient.Rotation=-90; s.HealthGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(60,60,125)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,120,255))}); s.HealthGradient.Parent=s.Health
    s.HealthText=Instance.new("TextLabel"); s.HealthText.BackgroundTransparency=1; s.HealthText.AnchorPoint=Vector2.new(.5,.5); s.HealthText.Size=UDim2.fromOffset(100,20); s.HealthText.Font=Enum.Font.Code; s.HealthText.TextSize=11; s.HealthText.TextStrokeTransparency=0; s.HealthText.TextStrokeColor3=Color3.fromRGB(0,0,0); s.HealthText.Visible=false; s.HealthText.Parent=overlay
    s.Name=s.HealthText:Clone(); s.Name.RichText=true; s.Name.Parent=overlay
    s.Distance=s.HealthText:Clone(); s.Distance.RichText=true; s.Distance.Parent=overlay
    s.Skeleton=newSkeletonSet(); s.Tracer=createLine(overlay,Color3.fromRGB(255,255,255)); s.Box3D=newBox3DSet()
    s.PackChams=s.Chams:Clone(); s.PackChams.Name="AttachedESPPackChams"; s.PackChams.Parent=overlay
    s.PackBox=Instance.new("Frame"); s.PackBox.BorderSizePixel=1; s.PackBox.BorderColor3=Color3.fromRGB(255,255,255); s.PackBox.BackgroundColor3=Color3.fromRGB(255,255,255); s.PackBox.BackgroundTransparency=.75; s.PackBox.Visible=false; s.PackBox.Parent=overlay
    s.PackGradient=Instance.new("UIGradient"); s.PackGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(119,120,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}); s.PackGradient.Parent=s.PackBox
    s.PackCorners=newCornerSet(); s.PackHealthBack=s.HealthBack:Clone(); s.PackHealthBack.Parent=overlay; s.PackHealth=s.Health:Clone(); s.PackHealth.Parent=overlay; s.PackHealthText=s.HealthText:Clone(); s.PackHealthText.Parent=overlay; s.PackName=s.Name:Clone(); s.PackName.Parent=overlay; s.PackDistance=s.Distance:Clone(); s.PackDistance.Parent=overlay
    stores[model]=s
    return s
end

local function hideStore(s)
    if not s then return end
    s.Chams.Enabled=false; s.PackChams.Enabled=false; s.CornerFill.Visible=false; s.ThermalFill.Visible=false
    s.Health.Visible=false; s.HealthBack.Visible=false; s.HealthText.Visible=false; s.Name.Visible=false; s.Distance.Visible=false; s.Tracer.Visible=false
    s.PackBox.Visible=false; s.PackHealth.Visible=false; s.PackHealthBack.Visible=false; s.PackHealthText.Visible=false; s.PackName.Visible=false; s.PackDistance.Visible=false
    hideList(s.Corner); hideList(s.ThermalCorner); hideList(s.Skeleton); hideList(s.Box3D); hideList(s.PackCorners)
end
local function destroyStore(model)
    local s=stores[model]; if not s then return end
    for _,v in pairs(s) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in pairs(v) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end
    end
    stores[model]=nil
end

local bonesR15={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local bonesR6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local function updateCorners(lines,pos,w,h,color)
    local l,r,t,b=pos.X-w/2,pos.X+w/2,pos.Y-h/2,pos.Y+h/2; local cw,ch=w/5,h/5
    local p={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,v in ipairs(p) do setLine(lines[i],v[1],v[2],1,color) end
end
local function updateSkeleton(lines,char,color)
    local cam=Workspace.CurrentCamera; if not cam then hideList(lines) return end
    local bones=char:FindFirstChild("UpperTorso") and bonesR15 or bonesR6
    for i,line in ipairs(lines) do line.Visible=false end
    for i,b in ipairs(bones) do
        local p1,p2=char:FindFirstChild(b[1]),char:FindFirstChild(b[2]); local line=lines[i]
        if p1 and p2 and line then
            local a,va=cam:WorldToViewportPoint(p1.Position); local c,vc=cam:WorldToViewportPoint(p2.Position)
            if va and vc and a.Z>0 and c.Z>0 then setLine(line,Vector2.new(a.X,a.Y),Vector2.new(c.X,c.Y),1,color) end
        end
    end
end
local function update3D(lines,root,color)
    local cam=Workspace.CurrentCamera; if not cam then hideList(lines) return end
    local cf=root.CFrame*CFrame.new(0,-.5,0); local sz=Vector3.new(3,5,3)/2; local corners={}
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(corners,(cf*CFrame.new(sz*Vector3.new(x,y,z))).Position) end end end
    local screen={}; local all=true
    for i,p in ipairs(corners) do local s,v=cam:WorldToViewportPoint(p); screen[i]=Vector2.new(s.X,s.Y); if not v or s.Z<=0 then all=false end end
    local edges={{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}
    if not all then hideList(lines) return end
    for i,e in ipairs(edges) do setLine(lines[i],screen[e[1]],screen[e[2]],1,color) end
end
local function updateHealth(bar,back,text,hum,pos,w,h,width,textColor)
    local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
    back.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2); back.Size=UDim2.fromOffset(width,h); back.Visible=true
    bar.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2+h*(1-ratio)); bar.Size=UDim2.fromOffset(width,h*ratio); bar.Visible=true
    text.Position=UDim2.fromOffset(pos.X-w/2-15,pos.Y-h/2+h*(1-ratio)); text.Text=tostring(math.floor(ratio*100)); text.TextColor3=textColor; text.Visible=cfg.HealthText and hum.Health<hum.MaxHealth
end
local function updateNameDistance(nameLabel,distanceLabel,model,pos,w,h,dist)
    nameLabel.Text=string.format("%s [%d]",model.Name,math.floor(dist)); nameLabel.Position=UDim2.fromOffset(pos.X,pos.Y-h/2-15); nameLabel.TextColor3=cfg.NameColor; nameLabel.Visible=true
    distanceLabel.Visible=false
end

local activeLast=false
RunService.RenderStepped:Connect(function()
    local any=cfg.Chams or cfg.Corner or cfg.ThermalCorner or cfg.Health or cfg.NameDistance or cfg.Skeleton or cfg.Tracers or cfg.Box3D or cfg.ESP
    if not any then
        if activeLast then for _,s in pairs(stores) do hideStore(s) end; activeLast=false end
        return
    end
    activeLast=true
    local cam=Workspace.CurrentCamera; if not cam then return end
    local folder=Workspace:FindFirstChild("Players")
    local count=0
    local seen={}
    if folder then
        for _,model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then
                local char,hum,root=validBot(model,folder)
                if char then
                    count+=1; seen[model]=true
                    local s=stores[model] or newStore(model)
                    local pos,w,h,dist=screenData(root)
                    if not pos then hideStore(s) else
                        if cfg.Chams then
                            s.Chams.Adornee=char; s.Chams.Enabled=true; s.Chams.FillColor=cfg.ChamsFill; s.Chams.OutlineColor=cfg.ChamsOutline
                            if cfg.ChamsThermal then local t=math.clamp(math.atan(math.sin(os.clock()*2))*2/math.pi,0,1); s.Chams.FillTransparency=t; s.Chams.OutlineTransparency=t else s.Chams.FillTransparency=1; s.Chams.OutlineTransparency=0 end
                        else s.Chams.Enabled=false end

                        if cfg.Corner then
                            s.CornerFill.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2); s.CornerFill.Size=UDim2.fromOffset(w,h); s.CornerFill.BackgroundColor3=cfg.CornerFill; s.CornerFill.BackgroundTransparency=.75; s.CornerFill.Visible=true; updateCorners(s.Corner,pos,w,h,cfg.CornerLine)
                        else s.CornerFill.Visible=false; hideList(s.Corner) end

                        if cfg.ThermalCorner then
                            s.ThermalFill.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2); s.ThermalFill.Size=UDim2.fromOffset(w,h); s.ThermalFill.BackgroundColor3=cfg.ThermalCornerFill; s.ThermalFill.BackgroundTransparency=.75; s.ThermalFill.Visible=true; updateCorners(s.ThermalCorner,pos,w,h,cfg.ThermalCornerLine)
                        else s.ThermalFill.Visible=false; hideList(s.ThermalCorner) end

                        if cfg.Health then updateHealth(s.Health,s.HealthBack,s.HealthText,hum,pos,w,h,cfg.HealthWidth,cfg.HealthTextColor) else s.Health.Visible=false; s.HealthBack.Visible=false; s.HealthText.Visible=false end
                        if cfg.NameDistance then updateNameDistance(s.Name,s.Distance,model,pos,w,h,dist) else s.Name.Visible=false; s.Distance.Visible=false end
                        if cfg.Skeleton then updateSkeleton(s.Skeleton,char,cfg.SkeletonColor) else hideList(s.Skeleton) end
                        if cfg.Tracers then
                            local start=cfg.TracerCenter and cam.ViewportSize/2 or Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y)
                            setLine(s.Tracer,start,Vector2.new(pos.X,pos.Y+h/2),cfg.TracerThickness,cfg.TracerColor)
                        else s.Tracer.Visible=false end
                        if cfg.Box3D then update3D(s.Box3D,root,cfg.Box3DColor) else hideList(s.Box3D) end

                        if cfg.ESP then
                            s.PackChams.Adornee=char; s.PackChams.Enabled=true; s.PackChams.FillColor=Color3.fromRGB(119,120,255); s.PackChams.OutlineColor=Color3.fromRGB(119,120,255); s.PackChams.FillTransparency=.78; s.PackChams.OutlineTransparency=.05
                            s.PackBox.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2); s.PackBox.Size=UDim2.fromOffset(w,h); s.PackBox.Visible=true
                            updateCorners(s.PackCorners,pos,w,h,Color3.fromRGB(255,255,255))
                            updateHealth(s.PackHealth,s.PackHealthBack,s.PackHealthText,hum,pos,w,h,2.5,Color3.fromRGB(119,120,255))
                            updateNameDistance(s.PackName,s.PackDistance,model,pos,w,h,dist)
                        else
                            s.PackChams.Enabled=false; s.PackBox.Visible=false; hideList(s.PackCorners); s.PackHealthBack.Visible=false; s.PackHealth.Visible=false; s.PackHealthText.Visible=false; s.PackName.Visible=false; s.PackDistance.Visible=false
                        end
                    end
                end
            end
        end
    end
    for model in pairs(stores) do if not seen[model] then destroyStore(model) end end
    status.Text="Legacy targets: "..count..(folder and "  •  Workspace.Players FOUND" or "  •  Workspace.Players NOT FOUND")
end)
