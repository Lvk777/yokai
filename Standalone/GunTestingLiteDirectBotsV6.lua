-- GunTestingLiteDirectBotsV6.lua
-- Direct GunTesting practice runtime for the confirmed structure:
-- Workspace > Players > botName > Humanoid / HumanoidRootPart / R6 body parts.
-- Only direct models in Workspace.Players are considered; real Roblox Player characters are excluded.
-- No remote firing, metamethod hooks, kick hooks, or anti-cheat bypass.

if shared.GunTestingLiteDirectBotsV6 then return end
shared.GunTestingLiteDirectBotsV6 = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local parent = (gethui and gethui()) or CoreGui
local Gui = parent:FindFirstChild("GunTestingLiteV1", true)
if not Gui then
    for _ = 1, 100 do
        task.wait(.05)
        Gui = parent:FindFirstChild("GunTestingLiteV1", true)
        if Gui then break end
    end
end
if not Gui then return end

local function findPage(name)
    for _, d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name == name then return d end
    end
end
local Combat = findPage("Combat")
local Visuals = findPage("Visuals")
if not (Combat and Visuals) then return end

-- Hide all older Combat/ESP/CarESP controls. Crosshair remains owned by V1.
local hideLabels = {
    ["Aimbot"]=true,["Aimbot FOV"]=true,["Aimbot Smooth 0.05-1"]=true,["Aim Part"]=true,["Wall Check"]=true,
    ["Silent Aim"]=true,["Silent FOV"]=true,["Silent Part"]=true,["Silent Wall Check"]=true,
    ["HitBox Expander"]=true,["HitBox Size"]=true,["HitBox Part"]=true,["No Recoil"]=true,["Recoil Strength 0-1"]=true,
    ["Aimbot (hold Mouse2)"]=true,["Aimbot Wall Check"]=true,["Aim Max Distance"]=true,
    ["Silent Max Distance"]=true,["Silent Wall Check"]=true,
    ["ESP Master"]=true,["Corner"]=true,["Box"]=true,["Chams"]=true,["Name"]=true,["Distance"]=true,
    ["HealthBar"]=true,["Lines"]=true,["Visual Distance"]=true,["Snapline"]=true,["Snap Origin"]=true,
    ["Snap Thickness"]=true,["Snap Transparency %"]=true,["Snap Distance"]=true,
    ["ESP (all replicated bots)"]=true,["Snapline / Lines"]=true,["Line Origin"]=true,["Max Distance"]=true,["ESP FPS"]=true,
    ["Car ESP"]=true,
}
for _, page in ipairs({Combat, Visuals}) do
    for _, child in ipairs(page:GetChildren()) do
        if child:IsA("Frame") then
            local label = child:FindFirstChildOfClass("TextLabel")
            if label and hideLabels[label.Text] then child.Visible = false end
        elseif child:IsA("TextLabel") then
            local txt = tostring(child.Text):upper()
            if txt:find("PRACTICE COMBAT V5",1,true) or txt:find("PRACTICE VISUALS V5",1,true)
                or txt:find("MAP%-WIDE ESP V4") or txt:find("SNAPLINE",1,true) then
                child.Visible = false
            end
        end
    end
end

local accent = Color3.fromRGB(125,82,235)
local order = 30000
local function section(page, text)
    local l=Instance.new("TextLabel")
    l.LayoutOrder=order; order+=1; l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(166,159,192)
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=page
    return l
end
local function row(page,label)
    local f=Instance.new("Frame")
    f.LayoutOrder=order; order+=1; f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=page
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0)
    t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(230,230,240); t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f,t
end
local function toggle(page,label,state,key,callback)
    local f=row(page,label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=state[key]==true
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function()
        state[key]=not state[key]; paint(); if callback then callback(state[key]) end
    end)
    paint(); return f
end
local function number(page,label,state,key,min,max)
    local f=row(page,label)
    local box=Instance.new("TextBox")
    box.Size=UDim2.fromOffset(92,24); box.Position=UDim2.new(1,-102,.5,-12); box.BackgroundColor3=Color3.fromRGB(34,34,45)
    box.BorderSizePixel=0; box.Font=Enum.Font.Code; box.TextSize=12; box.TextColor3=Color3.new(1,1,1); box.ClearTextOnFocus=false
    box.Text=tostring(state[key]); box.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=box
    box.FocusLost:Connect(function()
        local n=tonumber(box.Text); if n then state[key]=math.clamp(n,min,max) end; box.Text=tostring(state[key])
    end)
end
local function choice(page,label,state,key,list)
    local f=row(page,label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(120,24); b.Position=UDim2.new(1,-130,.5,-12); b.BackgroundColor3=Color3.fromRGB(34,34,45)
    b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text=tostring(state[key]); b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function()
        local i=table.find(list,state[key]) or 1; state[key]=list[i%#list+1]; b.Text=tostring(state[key])
    end)
end

-- ============================================================================
-- Exact bot registry: direct children of Workspace.Players.
-- ============================================================================
local targets = setmetatable({}, {__mode="k"})
local botFolder = nil
local folderAddedConn, folderRemovedConn

local function rootOf(m)
    return m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m.PrimaryPart)
end
local function isRealPlayerModel(m)
    if not m then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        local c=p.Character
        if c and (m==c or m:IsDescendantOf(c) or c:IsDescendantOf(m)) then return true end
        -- Some experiences mirror a real player under Workspace.Players without assigning Character.
        if m.Name==p.Name then return true end
        for _,attr in ipairs({"UserId","PlayerUserId","OwnerUserId"}) do
            local ok,v=pcall(function() return m:GetAttribute(attr) end)
            if ok and tonumber(v)==p.UserId then return true end
        end
    end
    return false
end
local function validTarget(m)
    if not botFolder or not m or not m:IsA("Model") or m.Parent~=botFolder then return false end
    if isRealPlayerModel(m) then return false end
    local hum=m:FindFirstChildOfClass("Humanoid")
    return hum~=nil and hum.Health>0 and rootOf(m)~=nil
end
local function register(m)
    if validTarget(m) then targets[m]=true end
end
local function scanFolder()
    if not botFolder then return end
    for m in pairs(targets) do if not validTarget(m) then targets[m]=nil end end
    for _,m in ipairs(botFolder:GetChildren()) do register(m) end
end
local function attachFolder(folder)
    if botFolder==folder then return end
    if folderAddedConn then folderAddedConn:Disconnect(); folderAddedConn=nil end
    if folderRemovedConn then folderRemovedConn:Disconnect(); folderRemovedConn=nil end
    table.clear(targets)
    botFolder=folder
    if botFolder then
        scanFolder()
        folderAddedConn=botFolder.ChildAdded:Connect(function(m) task.defer(register,m) end)
        folderRemovedConn=botFolder.ChildRemoved:Connect(function(m) targets[m]=nil end)
    end
end
attachFolder(Workspace:FindFirstChild("Players"))
Workspace.ChildAdded:Connect(function(c) if c.Name=="Players" then attachFolder(c) end end)
Workspace.ChildRemoved:Connect(function(c) if c==botFolder then attachFolder(nil) end end)
task.spawn(function()
    while shared.GunTestingLiteDirectBotsV6 do
        task.wait(2)
        if not botFolder then attachFolder(Workspace:FindFirstChild("Players")) else scanFolder() end
    end
end)

local function targetName(m)
    local h=m and m:FindFirstChildOfClass("Humanoid")
    if h and h.DisplayName and h.DisplayName~="" and h.DisplayName~="Humanoid" then return h.DisplayName end
    return m and m.Name or "Bot"
end
local function partOf(m,name)
    if not m then return nil end
    if name=="Head" then return m:FindFirstChild("Head") or rootOf(m) end
    return m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso") or rootOf(m)
end
local function visible(m,p)
    local cam=Workspace.CurrentCamera; if not cam or not p then return false end
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
    local list={cam}; if LP.Character then table.insert(list,LP.Character) end
    rp.FilterDescendantsInstances=list; rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,p.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(m))
end
local function nearest(maxPx,maxStuds,partName,wall)
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local ref=cam.ViewportSize/2
    local best,bestPart,bestPx=nil,nil,maxPx or math.huge
    for m in pairs(targets) do
        if validTarget(m) then
            local r=rootOf(m); local p=partOf(m,partName)
            if r and p and (r.Position-cam.CFrame.Position).Magnitude<=(maxStuds or math.huge) then
                local v,on=cam:WorldToViewportPoint(p.Position)
                if on and v.Z>0 then
                    local px=(Vector2.new(v.X,v.Y)-ref).Magnitude
                    if px<bestPx and (not wall or visible(m,p)) then best,bestPart,bestPx=m,p,px end
                end
            end
        end
    end
    return best,bestPart,bestPx
end

-- ============================================================================
-- Combat
-- ============================================================================
local C={
    Aimbot=false,AimFov=1400,AimSmooth=.92,AimPart="Head",AimWall=false,AimDistance=20000,
    Silent=false,SilentFov=1800,SilentPart="Head",SilentWall=false,SilentDistance=20000,
    Hitbox=false,HitboxSize=7,HitboxPart="Head",NoRecoil=false,RecoilStrength=1,
}
section(Combat,"Direct Workspace.Players Combat V6")
local _,combatStatus=row(Combat,"Bots detected: 0")
combatStatus.TextColor3=Color3.fromRGB(168,210,255)
toggle(Combat,"Aimbot (hold Mouse2)",C,"Aimbot")
number(Combat,"Aimbot FOV",C,"AimFov",50,6000)
number(Combat,"Aimbot Smooth 0.05-1",C,"AimSmooth",.05,1)
choice(Combat,"Aim Part",C,"AimPart",{"Head","Torso"})
toggle(Combat,"Aimbot Wall Check",C,"AimWall")
number(Combat,"Aim Max Distance",C,"AimDistance",100,100000)
toggle(Combat,"Silent Aim",C,"Silent")
number(Combat,"Silent FOV",C,"SilentFov",50,6000)
choice(Combat,"Silent Part",C,"SilentPart",{"Head","Torso"})
toggle(Combat,"Silent Wall Check",C,"SilentWall")
number(Combat,"Silent Max Distance",C,"SilentDistance",100,100000)
toggle(Combat,"HitBox Expander",C,"Hitbox")
number(Combat,"HitBox Size",C,"HitboxSize",2,20)
choice(Combat,"HitBox Part",C,"HitboxPart",{"Head","Torso"})
toggle(Combat,"No Recoil",C,"NoRecoil")
number(Combat,"Recoil Strength 0-1",C,"RecoilStrength",0,1)

local mouse1,mouse2=false,false
UIS.InputBegan:Connect(function(i)
    -- Do not ignore processed mouse input: Roblox normally consumes RMB for camera/ADS.
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=true end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=true end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=false end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=false end
end)

-- Try the GunTesting local GunPlugin after PlayerScripts finishes loading.
local GunPlugin=nil
local originalLook=nil
local function tryInstallGunPlugin()
    if GunPlugin then return true end
    local ps=LP:FindFirstChild("PlayerScripts"); if not ps then return false end
    for _,d in ipairs(ps:GetDescendants()) do
        if d:IsA("ModuleScript") and d.Name=="GunPlugin" then
            local ok,g=pcall(require,d)
            if ok and type(g)=="table" and type(g.GetWorldLookAtPos)=="function" then
                GunPlugin=g; originalLook=g.GetWorldLookAtPos
                GunPlugin.GetWorldLookAtPos=function(self,...)
                    if C.Silent then
                        local _,p=nearest(C.SilentFov,C.SilentDistance,C.SilentPart,C.SilentWall)
                        if p then return p.Position end
                    end
                    return originalLook(self,...)
                end
                return true
            end
        end
    end
    return false
end
task.spawn(function()
    for _=1,24 do if tryInstallGunPlugin() then break end; task.wait(.35) end
end)

-- Camera fallback if this game build does not expose GunPlugin.
UIS.InputBegan:Connect(function(i)
    if i.UserInputType~=Enum.UserInputType.MouseButton1 or not C.Silent or GunPlugin then return end
    local cam=Workspace.CurrentCamera; if not cam then return end
    local _,p=nearest(C.SilentFov,C.SilentDistance,C.SilentPart,C.SilentWall)
    if not p then return end
    local before=cam.CFrame
    cam.CFrame=CFrame.lookAt(before.Position,p.Position)
    task.defer(function() if cam and cam.Parent then cam.CFrame=before end end)
end)

local originalSizes=setmetatable({}, {__mode="k"})
local function restoreHitboxes()
    for p,sz in pairs(originalSizes) do
        if p and p.Parent then pcall(function() p.Size=sz end) end
        originalSizes[p]=nil
    end
end

pcall(function() RunService:UnbindFromRenderStep("GunTestingLiteDirectAimV6") end)
local lastPitch=nil
RunService:BindToRenderStep("GunTestingLiteDirectAimV6",Enum.RenderPriority.Last.Value+150,function()
    local cam=Workspace.CurrentCamera; if not cam then return end
    if C.Aimbot and mouse2 then
        local _,p=nearest(C.AimFov,C.AimDistance,C.AimPart,C.AimWall)
        if p then
            local desired=CFrame.lookAt(cam.CFrame.Position,p.Position)
            cam.CFrame=cam.CFrame:Lerp(desired,math.clamp(C.AimSmooth,.05,1))
        end
    end
    local pitch=select(1,cam.CFrame:ToOrientation())
    if C.NoRecoil and mouse1 and lastPitch then
        local delta=pitch-lastPitch
        if math.abs(delta)>.0025 then
            local _,yaw,roll=cam.CFrame:ToOrientation()
            local target=lastPitch+delta*(1-math.clamp(C.RecoilStrength,0,1))
            cam.CFrame=CFrame.new(cam.CFrame.Position)*CFrame.fromOrientation(target,yaw,roll)
            pitch=target
        end
    end
    lastPitch=pitch
end)

-- ============================================================================
-- Visuals: direct R6/R15 bot models, default 20,000 studs.
-- ============================================================================
local V={Enabled=false,Corner=true,Box=false,Chams=false,Name=true,Distance=true,Health=true,Lines=false,LineOrigin="Bottom",MaxDistance=20000,FPS=30}
section(Visuals,"Direct Workspace.Players ESP V6")
local _,visualStatus=row(Visuals,"Bots detected: 0")
visualStatus.TextColor3=Color3.fromRGB(168,210,255)
toggle(Visuals,"ESP Master",V,"Enabled")
toggle(Visuals,"Corner",V,"Corner")
toggle(Visuals,"Box",V,"Box")
toggle(Visuals,"Chams",V,"Chams")
toggle(Visuals,"Name",V,"Name")
toggle(Visuals,"Distance",V,"Distance")
toggle(Visuals,"HealthBar",V,"Health")
toggle(Visuals,"Snapline / Lines",V,"Lines")
choice(Visuals,"Line Origin",V,"LineOrigin",{"Bottom","Top","Center","Mouse"})
number(Visuals,"Max Distance",V,"MaxDistance",100,100000)
number(Visuals,"ESP FPS",V,"FPS",10,60)

local overlay=Instance.new("ScreenGui")
overlay.Name="GunTestingLiteDirectBotsV6"; overlay.ResetOnSpawn=false; overlay.IgnoreGuiInset=true; overlay.DisplayOrder=4892; overlay.Parent=parent
local stores=setmetatable({}, {__mode="k"})
local function newLine()
    local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Visible=false; f.Parent=overlay; return f
end
local function setLine(f,a,b,thick,color,trans)
    local d=b-a; if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thick or 1); f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X)); f.BackgroundColor3=color; f.BackgroundTransparency=trans or 0; f.Visible=true
end
local function newStore(m)
    local s={}
    s.hi=Instance.new("Highlight"); s.hi.Name="GunTestingLiteDirectHighlight"; s.hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; s.hi.Enabled=false; s.hi.Parent=Workspace
    s.corners={}; for i=1,8 do s.corners[i]=newLine() end
    s.box={}; for i=1,4 do s.box[i]=newLine() end
    s.line=newLine()
    s.name=Instance.new("TextLabel"); s.name.BackgroundTransparency=1; s.name.Size=UDim2.fromOffset(260,18); s.name.Font=Enum.Font.Code; s.name.TextSize=11
    s.name.TextColor3=Color3.new(1,1,1); s.name.TextStrokeTransparency=0; s.name.Visible=false; s.name.Parent=overlay
    s.hb=Instance.new("Frame"); s.hb.BorderSizePixel=0; s.hb.BackgroundColor3=Color3.new(0,0,0); s.hb.Visible=false; s.hb.Parent=overlay
    s.h=Instance.new("Frame"); s.h.BorderSizePixel=0; s.h.Visible=false; s.h.Parent=overlay
    stores[m]=s; return s
end
local function hide(s)
    s.hi.Enabled=false; s.line.Visible=false; s.name.Visible=false; s.hb.Visible=false; s.h.Visible=false
    for _,x in ipairs(s.corners) do x.Visible=false end; for _,x in ipairs(s.box) do x.Visible=false end
end
local function destroyStore(m)
    local s=stores[m]; if not s then return end
    for _,v in pairs(s) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in ipairs(v) do pcall(function() x:Destroy() end) end end
    end
    stores[m]=nil
end
local function bounds(m,cam)
    local ok,cf,size=pcall(function() return m:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge; local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        if p.Z>0 then any=true; minX=math.min(minX,p.X); minY=math.min(minY,p.Y); maxX=math.max(maxX,p.X); maxY=math.max(maxY,p.Y) end
    end end end
    if not any then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function drawCorners(lines,tl,br,color)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y; local w,h=r-l,b-t; local cw,ch=math.max(5,w*.22),math.max(5,h*.22)
    local seg={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],1,color,0) end
end
local function lineOrigin(cam)
    local vp=cam.ViewportSize
    if V.LineOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if V.LineOrigin=="Center" then return vp/2 end
    if V.LineOrigin=="Mouse" then local m=UIS:GetMouseLocation(); return Vector2.new(math.clamp(m.X,0,vp.X),math.clamp(m.Y,0,vp.Y)) end
    return Vector2.new(vp.X/2,vp.Y)
end

local visualClock=0
RunService.RenderStepped:Connect(function(dt)
    visualClock+=dt
    if visualClock < 1/math.max(10,V.FPS) then return end
    visualClock=0
    local cam=Workspace.CurrentCamera; if not cam then return end
    local count=0; for m in pairs(targets) do if validTarget(m) then count+=1 end end
    combatStatus.Text="Bots detected: "..count; visualStatus.Text="Bots detected: "..count
    for m in pairs(stores) do if not targets[m] or not validTarget(m) then destroyStore(m) end end

    if C.Hitbox then
        for m in pairs(targets) do
            if validTarget(m) then
                local p=partOf(m,C.HitboxPart)
                if p and p:IsA("BasePart") then
                    if not originalSizes[p] then originalSizes[p]=p.Size end
                    p.Size=Vector3.new(C.HitboxSize,C.HitboxSize,C.HitboxSize); p.CanCollide=false
                end
            end
        end
    elseif next(originalSizes) then restoreHitboxes() end

    for m in pairs(targets) do
        if validTarget(m) then
            local s=stores[m] or newStore(m)
            local r=rootOf(m); local hum=m:FindFirstChildOfClass("Humanoid")
            local dist=r and (r.Position-cam.CFrame.Position).Magnitude or math.huge
            local tl,br=bounds(m,cam)
            if not V.Enabled or not tl or dist>V.MaxDistance then hide(s) continue end
            local col=Color3.fromRGB(125,150,255)
            if V.Chams then s.hi.Adornee=m; s.hi.Enabled=true; s.hi.FillColor=col; s.hi.OutlineColor=col; s.hi.FillTransparency=.72; s.hi.OutlineTransparency=.05 else s.hi.Enabled=false end
            if V.Corner then drawCorners(s.corners,tl,br,col) else for _,x in ipairs(s.corners) do x.Visible=false end end
            if V.Box then
                setLine(s.box[1],Vector2.new(tl.X,tl.Y),Vector2.new(br.X,tl.Y),1,col,0)
                setLine(s.box[2],Vector2.new(br.X,tl.Y),Vector2.new(br.X,br.Y),1,col,0)
                setLine(s.box[3],Vector2.new(br.X,br.Y),Vector2.new(tl.X,br.Y),1,col,0)
                setLine(s.box[4],Vector2.new(tl.X,br.Y),Vector2.new(tl.X,tl.Y),1,col,0)
            else for _,x in ipairs(s.box) do x.Visible=false end end
            if V.Name or V.Distance then
                local text=V.Name and targetName(m) or ""
                if V.Distance then text=text..(text~="" and "  " or "").."["..math.floor(dist).."]" end
                s.name.Text=text; s.name.Position=UDim2.fromOffset((tl.X+br.X)/2-130,tl.Y-18); s.name.Visible=true
            else s.name.Visible=false end
            if V.Health and hum then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1); local h=br.Y-tl.Y
                s.hb.Position=UDim2.fromOffset(br.X+4,tl.Y); s.hb.Size=UDim2.fromOffset(4,h); s.hb.Visible=true
                s.h.Position=UDim2.fromOffset(br.X+5,tl.Y+1+(h-2)*(1-ratio)); s.h.Size=UDim2.fromOffset(2,(h-2)*ratio)
                s.h.BackgroundColor3=Color3.fromHSV(ratio*.33,.75,1); s.h.Visible=true
            else s.hb.Visible=false; s.h.Visible=false end
            if V.Lines then setLine(s.line,lineOrigin(cam),Vector2.new((tl.X+br.X)/2,br.Y),1,col,.08) else s.line.Visible=false end
        end
    end
end)

-- ============================================================================
-- Car ESP: port of the previously working Yokai PreservedLocalExtras V15 logic.
-- ============================================================================
local Car={Enabled=false,Distance=20000}
section(Visuals,"Car ESP")
toggle(Visuals,"Car ESP",Car,"Enabled")
number(Visuals,"Car ESP Distance",Car,"Distance",100,100000)
local carColor=Color3.fromRGB(60,220,180)
local cars=setmetatable({}, {__mode="k"})
local vehicles=nil
local vehicleChildConn=nil
local carLoopToken=0
local function isVehicle(m)
    if not m or not m:IsA("Model") then return false end
    if m:FindFirstChildWhichIsA("VehicleSeat",true) then return true end
    local n=m.Name:lower()
    return n:find("car",1,true) or n:find("truck",1,true) or n:find("sedan",1,true) or n:find("vehicle",1,true) or n:find("pickup",1,true)
end
local function carAnchor(m)
    return m:FindFirstChildWhichIsA("VehicleSeat",true) or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
end
local function addCar(m)
    if cars[m] or not isVehicle(m) then return end
    local a=carAnchor(m); if not a then return end
    local h=Instance.new("Highlight"); h.Name="GunTestingLiteCarESP"; h.Adornee=m; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.FillTransparency=.86; h.OutlineTransparency=.08; h.Enabled=false; h.Parent=m
    local bb=Instance.new("BillboardGui"); bb.Name="GunTestingLiteCarLabel"; bb.Adornee=a; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(180,28); bb.StudsOffsetWorldSpace=Vector3.new(0,3,0); bb.Enabled=false; bb.Parent=a
    local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Font=Enum.Font.GothamSemibold; t.TextSize=12; t.TextStrokeTransparency=.45; t.Parent=bb
    cars[m]={h=h,bb=bb,t=t,a=a}
end
local function attachVehiclesFolder(folder)
    if vehicles==folder then return end
    if vehicleChildConn then vehicleChildConn:Disconnect(); vehicleChildConn=nil end
    vehicles=folder
    if vehicles then
        for _,m in ipairs(vehicles:GetChildren()) do addCar(m) end
        vehicleChildConn=vehicles.ChildAdded:Connect(function(m) task.defer(addCar,m) end)
    end
end
attachVehiclesFolder(Workspace:FindFirstChild("Vehicles"))
Workspace.ChildAdded:Connect(function(c) if c.Name=="Vehicles" then attachVehiclesFolder(c) end end)
Workspace.ChildRemoved:Connect(function(c) if c==vehicles then attachVehiclesFolder(nil) end end)
local function updateCarsOnce()
    local cam=Workspace.CurrentCamera
    for m,s in pairs(cars) do
        if not m.Parent or not s.a or not s.a.Parent then
            if s.h then s.h:Destroy() end; if s.bb then s.bb:Destroy() end; cars[m]=nil
        else
            local dist=cam and (s.a.Position-cam.CFrame.Position).Magnitude or math.huge
            local show=Car.Enabled and dist<=Car.Distance
            s.h.Enabled=show; s.bb.Enabled=show
            if show then
                s.h.FillColor=carColor; s.h.OutlineColor=carColor; s.t.TextColor3=carColor
                s.t.Text=string.format("%s  •  %d studs",m.Name:gsub("_"," "),math.floor(dist+.5))
            end
        end
    end
end
local function restartCarLoop()
    carLoopToken+=1; local token=carLoopToken
    task.spawn(function()
        while shared.GunTestingLiteDirectBotsV6 and token==carLoopToken do
            if not vehicles then attachVehiclesFolder(Workspace:FindFirstChild("Vehicles")) end
            updateCarsOnce(); task.wait(.20)
        end
    end)
end
restartCarLoop()
