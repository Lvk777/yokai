-- GunTestingLiteDirectVisualsV9.lua
-- Rebuilt bot visuals for the confirmed GunTesting layout:
-- Workspace > Players > botName > Humanoid / HumanoidRootPart / Head / Torso.
-- No distance filter. Excludes only actual Roblox Player.Character models.

if shared.GunTestingLiteDirectVisualsV9 then return end
shared.GunTestingLiteDirectVisualsV9=true

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
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

-- Hide older bot ESP rows. Keep Crosshair and Car ESP visible.
local hideLabels={
    ["ESP Master"]=true,["Corner"]=true,["Box"]=true,["Chams"]=true,["Name"]=true,["Distance"]=true,
    ["HealthBar"]=true,["Lines"]=true,["Visual Distance"]=true,["Snapline"]=true,["Snap Origin"]=true,
    ["Snap Thickness"]=true,["Snap Transparency %"]=true,["Snap Distance"]=true,["ESP (all replicated bots)"]=true,
    ["Snapline / Lines"]=true,["Line Origin"]=true,["Max Distance"]=true,["ESP FPS"]=true,
    ["First Bot ESP Probe"]=true,["Self ESP Render Test"]=true,
}
for _,child in ipairs(Visuals:GetChildren()) do
    if child:IsA("Frame") then
        local label=child:FindFirstChildOfClass("TextLabel")
        if label and hideLabels[label.Text] then child.Visible=false end
    elseif child:IsA("TextLabel") then
        local t=tostring(child.Text):upper()
        if t:find("DIRECT WORKSPACE.PLAYERS ESP",1,true) or t:find("ESP DIAGNOSTICS",1,true) then child.Visible=false end
    end
end

local accent=Color3.fromRGB(125,82,235)
local order=45000
local function section(text)
    local l=Instance.new("TextLabel")
    l.LayoutOrder=order; order+=1; l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(166,159,192)
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=Visuals
    return l
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
local function toggle(label,state,key)
    local f=row(label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=state[key]==true
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function() state[key]=not state[key]; paint() end); paint()
end
local function choice(label,state,key,list)
    local f=row(label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(120,24); b.Position=UDim2.new(1,-130,.5,-12)
    b.BackgroundColor3=Color3.fromRGB(34,34,45); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text=tostring(state[key]); b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function() local i=table.find(list,state[key]) or 1; state[key]=list[i%#list+1]; b.Text=tostring(state[key]) end)
end

local V={Enabled=false,Chams=true,Box=false,Corner=true,Name=true,Distance=true,Health=true,Lines=false,LineOrigin="Bottom"}
section("Workspace.Players Visuals V9 - no distance limit")
local _,status=row("Targets attached: 0")
status.TextColor3=Color3.fromRGB(168,210,255)
toggle("ESP Master",V,"Enabled")
toggle("Chams",V,"Chams")
toggle("3D Box",V,"Box")
toggle("Corner",V,"Corner")
toggle("Name",V,"Name")
toggle("Distance",V,"Distance")
toggle("HealthBar",V,"Health")
toggle("Snapline / Lines",V,"Lines")
choice("Line Origin",V,"LineOrigin",{"Bottom","Top","Center","Mouse"})

local overlay=Instance.new("ScreenGui")
overlay.Name="GunTestingLiteDirectVisualsV9"; overlay.ResetOnSpawn=false; overlay.IgnoreGuiInset=true; overlay.DisplayOrder=4905; overlay.Parent=parent

local targets=setmetatable({}, {__mode="k"})
local stores=setmetatable({}, {__mode="k"})
local botFolder=nil
local addConn,removeConn=nil,nil

local function rootOf(m)
    return m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
end
local function headOf(m)
    return m and (m:FindFirstChild("Head") or rootOf(m))
end
local function actualPlayerCharacter(m)
    if not m then return false end
    local ok,p=pcall(function() return Players:GetPlayerFromCharacter(m) end)
    if ok and p then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr.Character==m then return true end
    end
    return LP.Character==m
end
local function validTarget(m)
    if not botFolder or not m or not m:IsA("Model") or m.Parent~=botFolder then return false end
    if actualPlayerCharacter(m) then return false end
    local hum=m:FindFirstChildOfClass("Humanoid")
    return hum~=nil and hum.Health>0 and rootOf(m)~=nil
end
local function register(m)
    if validTarget(m) then targets[m]=true end
end
local function scan()
    if not botFolder then return end
    for m in pairs(targets) do if not validTarget(m) then targets[m]=nil end end
    for _,m in ipairs(botFolder:GetChildren()) do register(m) end
end
local function attach(folder)
    if botFolder==folder then return end
    if addConn then addConn:Disconnect(); addConn=nil end
    if removeConn then removeConn:Disconnect(); removeConn=nil end
    table.clear(targets); botFolder=folder
    if botFolder then
        scan()
        addConn=botFolder.ChildAdded:Connect(function(m) task.defer(register,m) end)
        removeConn=botFolder.ChildRemoved:Connect(function(m) targets[m]=nil end)
    end
end
attach(Workspace:FindFirstChild("Players"))
Workspace.ChildAdded:Connect(function(c) if c.Name=="Players" then attach(c) end end)
Workspace.ChildRemoved:Connect(function(c) if c==botFolder then attach(nil) end end)

task.spawn(function()
    while shared.GunTestingLiteDirectVisualsV9 do
        task.wait(1)
        if not botFolder then attach(Workspace:FindFirstChild("Players")) else scan() end
    end
end)

local function newLine()
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Visible=false; f.Parent=overlay
    return f
end
local function setLine(f,a,b,thick,color,trans)
    local d=b-a
    if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thick or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color; f.BackgroundTransparency=trans or 0; f.Visible=true
end
local function hide2D(s)
    if s.line then s.line.Visible=false end
    if s.corners then for _,x in ipairs(s.corners) do x.Visible=false end end
end
local function destroyStore(m)
    local s=stores[m]; if not s then return end
    for _,obj in pairs(s) do
        if typeof(obj)=="Instance" then pcall(function() obj:Destroy() end)
        elseif type(obj)=="table" then for _,x in ipairs(obj) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end
    end
    stores[m]=nil
end
local function makeStore(m)
    local s={}
    local root=rootOf(m); local head=headOf(m)

    local hi=Instance.new("Highlight")
    hi.Name="GunTestingLiteV9Highlight"; hi.Adornee=m; hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hi.FillColor=Color3.fromRGB(120,80,235); hi.OutlineColor=Color3.fromRGB(255,255,255); hi.FillTransparency=.72; hi.OutlineTransparency=.05; hi.Enabled=false
    hi.Parent=m; s.hi=hi

    if root then
        local box=Instance.new("BoxHandleAdornment")
        box.Name="GunTestingLiteV9Box"; box.Adornee=root; box.AlwaysOnTop=true; box.ZIndex=8; box.Color3=Color3.fromRGB(125,150,255); box.Transparency=.35; box.Visible=false
        box.Parent=root; s.box=box
    end

    if head then
        local bill=Instance.new("BillboardGui")
        bill.Name="GunTestingLiteV9Billboard"; bill.Adornee=head; bill.AlwaysOnTop=true; bill.MaxDistance=0
        bill.Size=UDim2.fromOffset(230,46); bill.StudsOffsetWorldSpace=Vector3.new(0,3.2,0); bill.Enabled=false; bill.Parent=head
        local name=Instance.new("TextLabel")
        name.BackgroundTransparency=1; name.Size=UDim2.new(1,0,0,20); name.Position=UDim2.fromOffset(0,0)
        name.Font=Enum.Font.GothamBold; name.TextSize=12; name.TextColor3=Color3.new(1,1,1); name.TextStrokeTransparency=.25; name.Parent=bill
        local bg=Instance.new("Frame")
        bg.Size=UDim2.new(.65,0,0,5); bg.Position=UDim2.new(.175,0,0,25); bg.BackgroundColor3=Color3.fromRGB(25,25,30); bg.BorderSizePixel=0; bg.Parent=bill
        local hp=Instance.new("Frame")
        hp.Size=UDim2.fromScale(1,1); hp.BackgroundColor3=Color3.fromRGB(70,230,120); hp.BorderSizePixel=0; hp.Parent=bg
        s.bill=bill; s.name=name; s.hpbg=bg; s.hp=hp
    end

    s.corners={}; for i=1,8 do s.corners[i]=newLine() end
    s.line=newLine()
    stores[m]=s
    return s
end

local function bounds(m,cam)
    local ok,cf,size=pcall(function() return m:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        if p.Z>0 then
            any=true; minX=math.min(minX,p.X); minY=math.min(minY,p.Y); maxX=math.max(maxX,p.X); maxY=math.max(maxY,p.Y)
        end
    end end end
    if not any then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function drawCorners(lines,tl,br,color)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t; local cw,ch=math.max(5,w*.22),math.max(5,h*.22)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}
    }
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],1,color,0) end
end
local function origin(cam)
    local vp=cam.ViewportSize
    if V.LineOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if V.LineOrigin=="Center" then return vp/2 end
    if V.LineOrigin=="Mouse" then local m=UIS:GetMouseLocation(); return Vector2.new(m.X,m.Y) end
    return Vector2.new(vp.X/2,vp.Y)
end

-- Persistent 3D/billboard update. No distance condition anywhere.
task.spawn(function()
    while shared.GunTestingLiteDirectVisualsV9 do
        local cam=Workspace.CurrentCamera
        local count=0
        for m in pairs(targets) do if validTarget(m) then count+=1 end end
        status.Text="Targets attached: "..count..(botFolder and "  •  Workspace.Players FOUND" or "  •  Workspace.Players NOT FOUND")
        for m in pairs(stores) do if not targets[m] or not validTarget(m) then destroyStore(m) end end
        if cam then
            for m in pairs(targets) do
                if validTarget(m) then
                    local s=stores[m] or makeStore(m)
                    local hum=m:FindFirstChildOfClass("Humanoid")
                    local root=rootOf(m)
                    local enabled=V.Enabled
                    if s.hi then s.hi.Enabled=enabled and V.Chams end
                    if s.box and root then
                        if enabled and V.Box then
                            local ok,cf,size=pcall(function() return m:GetBoundingBox() end)
                            if ok and cf and size then
                                s.box.Adornee=root; s.box.Size=size+Vector3.new(.15,.15,.15); s.box.CFrame=root.CFrame:ToObjectSpace(cf); s.box.Visible=true
                            else s.box.Visible=false end
                        else s.box.Visible=false end
                    end
                    if s.bill and hum and root then
                        s.bill.Enabled=enabled and (V.Name or V.Distance or V.Health)
                        if s.name then
                            local text=""
                            if V.Name then text=m.Name end
                            if V.Distance then
                                local dist=(root.Position-cam.CFrame.Position).Magnitude
                                text=text..(text~="" and "  " or "").."["..math.floor(dist).."]"
                            end
                            s.name.Text=text; s.name.Visible=V.Name or V.Distance
                        end
                        if s.hpbg and s.hp then
                            s.hpbg.Visible=V.Health
                            if V.Health then
                                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                                s.hp.Size=UDim2.new(ratio,0,1,0); s.hp.BackgroundColor3=Color3.fromHSV(ratio*.33,.75,1)
                            end
                        end
                    end
                end
            end
        end
        task.wait(.1)
    end
end)

RunService.RenderStepped:Connect(function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    for m,s in pairs(stores) do
        if not V.Enabled or not validTarget(m) then hide2D(s) continue end
        local tl,br=bounds(m,cam)
        if not tl then hide2D(s) continue end
        local col=Color3.fromRGB(125,150,255)
        if V.Corner then drawCorners(s.corners,tl,br,col) else for _,x in ipairs(s.corners) do x.Visible=false end end
        if V.Lines then setLine(s.line,origin(cam),Vector2.new((tl.X+br.X)/2,br.Y),1,col,.08) else s.line.Visible=false end
    end
end)
