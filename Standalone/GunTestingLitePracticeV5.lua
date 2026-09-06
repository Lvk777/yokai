-- GunTestingLitePracticeV5.lua
-- Unified practice-target Combat + Visuals for the standalone menu.
-- Scope: models inside Workspace.Players (plus obvious NPC/Bot containers), excluding the local character.
-- No remote firing, no metamethod hooks, no anti-cheat bypass.

if shared.GunTestingLitePracticeV5 then return end
shared.GunTestingLitePracticeV5 = true

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

-- Hide legacy Combat/Visual controls so V5 is the only visible owner.
local hideLabels = {
    ["Aimbot"]=true,["Aimbot FOV"]=true,["Aimbot Smooth 0.05-1"]=true,["Aim Part"]=true,["Wall Check"]=true,
    ["Silent Aim"]=true,["Silent FOV"]=true,["Silent Part"]=true,["Silent Wall Check"]=true,
    ["HitBox Expander"]=true,["HitBox Size"]=true,["HitBox Part"]=true,["No Recoil"]=true,["Recoil Strength 0-1"]=true,
    ["ESP Master"]=true,["Corner"]=true,["Box"]=true,["Chams"]=true,["Name"]=true,["Distance"]=true,
    ["HealthBar"]=true,["Lines"]=true,["Visual Distance"]=true,["Snapline"]=true,["Snap Origin"]=true,
    ["Snap Thickness"]=true,["Snap Transparency %"]=true,["Snap Distance"]=true,
    ["ESP (all replicated bots)"]=true,["Snapline / Lines"]=true,["Line Origin"]=true,["Max Distance"]=true,["ESP FPS"]=true,
}
for _, page in ipairs({Combat,Visuals}) do
    for _, child in ipairs(page:GetChildren()) do
        if child:IsA("Frame") then
            local label = child:FindFirstChildOfClass("TextLabel")
            if label and hideLabels[label.Text] then child.Visible = false end
        elseif child:IsA("TextLabel") then
            local txt = tostring(child.Text):upper()
            if txt:find("MAP%-WIDE ESP V4") or txt:find("SNAPLINE") then child.Visible=false end
        end
    end
end

local accent=Color3.fromRGB(125,82,235)
local order=20000
local function section(page,text)
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
local function toggle(page,label,state,key)
    local f=row(page,label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=state[key]==true
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62); dot.BackgroundColor3=Color3.new(1,1,1)
        dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function() state[key]=not state[key]; paint() end); paint()
end
local function number(page,label,state,key,min,max)
    local f=row(page,label)
    local box=Instance.new("TextBox"); box.Size=UDim2.fromOffset(92,24); box.Position=UDim2.new(1,-102,.5,-12)
    box.BackgroundColor3=Color3.fromRGB(34,34,45); box.BorderSizePixel=0; box.Font=Enum.Font.Code; box.TextSize=12; box.TextColor3=Color3.new(1,1,1)
    box.ClearTextOnFocus=false; box.Text=tostring(state[key]); box.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=box
    box.FocusLost:Connect(function() local n=tonumber(box.Text); if n then state[key]=math.clamp(n,min,max) end; box.Text=tostring(state[key]) end)
end
local function choice(page,label,state,key,list)
    local f=row(page,label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(120,24); b.Position=UDim2.new(1,-130,.5,-12)
    b.BackgroundColor3=Color3.fromRGB(34,34,45); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text=tostring(state[key]); b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function() local i=table.find(list,state[key]) or 1; state[key]=list[i%#list+1]; b.Text=tostring(state[key]) end)
end

-- ============================================================================
-- Practice target registry
-- ============================================================================
local targets=setmetatable({}, {__mode="k"})
local function rootOf(m)
    return m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m.PrimaryPart)
end
local function isLocalModel(m)
    if not m then return true end
    if LP.Character and (m==LP.Character or m:IsDescendantOf(LP.Character) or LP.Character:IsDescendantOf(m)) then return true end
    if m.Name==LP.Name then return true end
    for _,attr in ipairs({"UserId","PlayerUserId","OwnerUserId"}) do
        local ok,v=pcall(function() return m:GetAttribute(attr) end)
        if ok and tonumber(v)==LP.UserId then return true end
    end
    return false
end
local function underPracticeContainer(m)
    local cur=m.Parent
    while cur and cur~=Workspace do
        local n=cur.Name
        if n=="Players" or n=="Bots" or n=="NPCs" or n=="Dummies" or n=="Zombies" or n=="Characters" then return true end
        cur=cur.Parent
    end
    return false
end
local function hasGunTestingMarkers(m)
    return m:FindFirstChild("ServerCollider")~=nil
        or m:FindFirstChild("ServerColliderHead")~=nil
        or m:FindFirstChild("NoClipDetection")~=nil
        or m:FindFirstChild("Nameplate")~=nil
end
local function validTarget(m)
    if not m or not m:IsA("Model") or not m.Parent or isLocalModel(m) then return false end
    local hum=m:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 or not rootOf(m) then return false end
    return underPracticeContainer(m) or hasGunTestingMarkers(m) or m:GetAttribute("Bot")==true or m:GetAttribute("NPC")==true
end
local function registerModel(m) if validTarget(m) then targets[m]=true end end
local function fullScan()
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerModel(d.Parent) end
    end
end
fullScan()
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerModel,d.Parent)
    elseif d:IsA("Model") then task.defer(registerModel,d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then targets[d]=nil
    elseif d:IsA("Humanoid") and d.Parent then targets[d.Parent]=nil end
end)
-- Low-frequency recovery scan for games that replace whole rigs without firing a convenient child pattern.
task.spawn(function()
    while shared.GunTestingLitePracticeV5 do
        task.wait(3)
        fullScan()
    end
end)

local function targetName(m)
    local h=m and m:FindFirstChildOfClass("Humanoid")
    if h and h.DisplayName and h.DisplayName~="" and h.DisplayName~="Humanoid" then return h.DisplayName end
    return m and m.Name or "Bot"
end
local function partOf(m,name)
    if name=="Head" then return m:FindFirstChild("Head") or rootOf(m) end
    return m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or rootOf(m)
end
local function visible(m,p)
    local cam=Workspace.CurrentCamera; if not cam or not p then return false end
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
    local f={cam}; if LP.Character then table.insert(f,LP.Character) end
    rp.FilterDescendantsInstances=f; rp.IgnoreWater=true
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
-- Combat V5
-- ============================================================================
local C={
    Aimbot=false,AimFov=900,AimSmooth=.88,AimPart="Head",AimWall=false,AimDistance=100000,
    Silent=false,SilentFov=1200,SilentPart="Head",SilentWall=false,SilentDistance=100000,
    Hitbox=false,HitboxSize=7,HitboxPart="Head",NoRecoil=false,RecoilStrength=1,
}
section(Combat,"Practice Combat V5")
local statusFrame,statusText=row(Combat,"Targets detected: 0")
statusFrame.LayoutOrder=19999
statusText.TextColor3=Color3.fromRGB(168,210,255)
toggle(Combat,"Aimbot (hold Mouse2)",C,"Aimbot")
number(Combat,"Aimbot FOV",C,"AimFov",50,4000)
number(Combat,"Aimbot Smooth 0.05-1",C,"AimSmooth",.05,1)
choice(Combat,"Aim Part",C,"AimPart",{"Head","Torso"})
toggle(Combat,"Aimbot Wall Check",C,"AimWall")
number(Combat,"Aim Max Distance",C,"AimDistance",100,1000000)
toggle(Combat,"Silent Aim",C,"Silent")
number(Combat,"Silent FOV",C,"SilentFov",50,5000)
choice(Combat,"Silent Part",C,"SilentPart",{"Head","Torso"})
toggle(Combat,"Silent Wall Check",C,"SilentWall")
number(Combat,"Silent Max Distance",C,"SilentDistance",100,1000000)
toggle(Combat,"HitBox Expander",C,"Hitbox")
number(Combat,"HitBox Size",C,"HitboxSize",2,20)
choice(Combat,"HitBox Part",C,"HitboxPart",{"Head","Torso"})
toggle(Combat,"No Recoil",C,"NoRecoil")
number(Combat,"Recoil Strength 0-1",C,"RecoilStrength",0,1)

local mouse1=false; local mouse2=false; local lastPitch=nil
UIS.InputBegan:Connect(function(i,p)
    if p then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=true end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=true end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=false end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=false end
end)

-- Optional GunPlugin route; camera fallback remains active when unavailable.
local GunPlugin=nil; local originalLook=nil
pcall(function()
    local ps=LP:FindFirstChild("PlayerScripts")
    if not ps then return end
    for _,d in ipairs(ps:GetDescendants()) do
        if d:IsA("ModuleScript") and d.Name=="GunPlugin" then
            local ok,g=pcall(require,d)
            if ok and type(g)=="table" and type(g.GetWorldLookAtPos)=="function" then GunPlugin=g; break end
        end
    end
end)
if GunPlugin then
    originalLook=GunPlugin.GetWorldLookAtPos
    GunPlugin.GetWorldLookAtPos=function(self,...)
        if C.Silent then
            local _,p=nearest(C.SilentFov,C.SilentDistance,C.SilentPart,C.SilentWall)
            if p then return p.Position end
        end
        return originalLook(self,...)
    end
end
UIS.InputBegan:Connect(function(i,p)
    if p or i.UserInputType~=Enum.UserInputType.MouseButton1 or not C.Silent or GunPlugin then return end
    local cam=Workspace.CurrentCamera; if not cam then return end
    local _,part=nearest(C.SilentFov,C.SilentDistance,C.SilentPart,C.SilentWall)
    if not part then return end
    local before=cam.CFrame; cam.CFrame=CFrame.lookAt(before.Position,part.Position)
    task.defer(function() if cam and cam.Parent then cam.CFrame=before end end)
end)

local originalSizes=setmetatable({}, {__mode="k"})
local function restoreHitboxes()
    for p,sz in pairs(originalSizes) do if p and p.Parent then pcall(function() p.Size=sz end) end originalSizes[p]=nil end
end

-- ============================================================================
-- Visuals V5
-- ============================================================================
local V={Enabled=false,Corner=true,Box=false,Chams=true,Name=true,Distance=true,HealthBar=true,Lines=false,LineOrigin="Bottom",MaxDistance=1000000,FPS=30}
section(Visuals,"Practice Visuals V5")
local visualStatusFrame,visualStatusText=row(Visuals,"Targets detected: 0")
visualStatusFrame.LayoutOrder=19999
visualStatusText.TextColor3=Color3.fromRGB(168,210,255)
toggle(Visuals,"ESP Master",V,"Enabled")
toggle(Visuals,"Corner",V,"Corner")
toggle(Visuals,"Box",V,"Box")
toggle(Visuals,"Chams",V,"Chams")
toggle(Visuals,"Name",V,"Name")
toggle(Visuals,"Distance",V,"Distance")
toggle(Visuals,"HealthBar",V,"HealthBar")
toggle(Visuals,"Snapline / Lines",V,"Lines")
choice(Visuals,"Line Origin",V,"LineOrigin",{"Bottom","Top","Center","Mouse"})
number(Visuals,"Max Distance",V,"MaxDistance",100,1000000)
number(Visuals,"ESP FPS",V,"FPS",10,60)

local overlay=Instance.new("ScreenGui")
overlay.Name="GunTestingLitePracticeV5"; overlay.ResetOnSpawn=false; overlay.IgnoreGuiInset=true; overlay.DisplayOrder=4887; overlay.Parent=parent
local stores=setmetatable({}, {__mode="k"})
local function mkLine()
    local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Visible=false; f.Parent=overlay; return f
end
local function setLine(f,a,b,thickness,color,trans)
    local d=b-a; if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1); f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X)); f.BackgroundColor3=color; f.BackgroundTransparency=trans or 0; f.Visible=true
end
local function storeFor(m)
    local s=stores[m]; if s then return s end
    s={}
    s.hi=Instance.new("Highlight"); s.hi.Name="PracticeV5Highlight"; s.hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; s.hi.Enabled=false; s.hi.Parent=Workspace
    s.c={}; for i=1,8 do s.c[i]=mkLine() end
    s.b={}; for i=1,4 do s.b[i]=mkLine() end
    s.line=mkLine()
    s.name=Instance.new("TextLabel"); s.name.BackgroundTransparency=1; s.name.Size=UDim2.fromOffset(260,18); s.name.Font=Enum.Font.Code; s.name.TextSize=11; s.name.TextColor3=Color3.new(1,1,1); s.name.TextStrokeTransparency=0; s.name.Visible=false; s.name.Parent=overlay
    s.hb=Instance.new("Frame"); s.hb.BorderSizePixel=0; s.hb.BackgroundColor3=Color3.new(0,0,0); s.hb.Visible=false; s.hb.Parent=overlay
    s.h=Instance.new("Frame"); s.h.BorderSizePixel=0; s.h.Visible=false; s.h.Parent=overlay
    stores[m]=s; return s
end
local function hide(s)
    s.hi.Enabled=false; s.line.Visible=false; s.name.Visible=false; s.hb.Visible=false; s.h.Visible=false
    for _,x in ipairs(s.c) do x.Visible=false end; for _,x in ipairs(s.b) do x.Visible=false end
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
local function corners(lines,tl,br,col)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y; local w,h=r-l,b-t; local cw,ch=math.max(5,w*.22),math.max(5,h*.22)
    local seg={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],1,col,0) end
end
local function lineStart(cam)
    local vp=cam.ViewportSize
    if V.LineOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if V.LineOrigin=="Center" then return vp/2 end
    if V.LineOrigin=="Mouse" then local m=UIS:GetMouseLocation(); return Vector2.new(math.clamp(m.X,0,vp.X),math.clamp(m.Y,0,vp.Y)) end
    return Vector2.new(vp.X/2,vp.Y)
end

local visualClock=0; local statusClock=0
RunService.RenderStepped:Connect(function(dt)
    local cam=Workspace.CurrentCamera; if not cam then return end

    -- Combat runtime
    if C.Aimbot and mouse2 then
        local _,p=nearest(C.AimFov,C.AimDistance,C.AimPart,C.AimWall)
        if p then cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position,p.Position),math.clamp(C.AimSmooth,.05,1)) end
    end
    local pitch=select(1,cam.CFrame:ToOrientation())
    if C.NoRecoil and mouse1 and lastPitch then
        local delta=pitch-lastPitch
        if math.abs(delta)>.0025 then
            local _,yaw,roll=cam.CFrame:ToOrientation(); local np=lastPitch+delta*(1-math.clamp(C.RecoilStrength,0,1))
            cam.CFrame=CFrame.new(cam.CFrame.Position)*CFrame.fromOrientation(np,yaw,roll); pitch=np
        end
    end
    lastPitch=pitch

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

    statusClock+=dt
    if statusClock>=.5 then
        statusClock=0; local count=0
        for m in pairs(targets) do if validTarget(m) then count+=1 end end
        statusText.Text="Targets detected: "..count.."  |  Gun API: "..(GunPlugin and "GunPlugin" or "camera fallback")
        visualStatusText.Text="Targets detected: "..count
    end

    visualClock+=dt
    if visualClock < 1/math.max(10,V.FPS) then return end
    visualClock=0

    for m in pairs(stores) do if not targets[m] or not validTarget(m) then destroyStore(m) end end
    if not V.Enabled then for _,s in pairs(stores) do hide(s) end return end

    local start=lineStart(cam)
    for m in pairs(targets) do
        if validTarget(m) then
            local r=rootOf(m); local hum=m:FindFirstChildOfClass("Humanoid"); local s=storeFor(m)
            local dist=r and (r.Position-cam.CFrame.Position).Magnitude or math.huge
            local tl,br=bounds(m,cam)
            if not tl or dist>V.MaxDistance then hide(s) continue end
            local mid=Vector2.new((tl.X+br.X)/2,(tl.Y+br.Y)/2); local h=br.Y-tl.Y
            local col=Color3.fromRGB(125,150,255)
            if V.Chams then s.hi.Adornee=m; s.hi.FillColor=col; s.hi.OutlineColor=Color3.new(1,1,1); s.hi.FillTransparency=.72; s.hi.OutlineTransparency=.08; s.hi.Enabled=true else s.hi.Enabled=false end
            if V.Corner then corners(s.c,tl,br,col) else for _,x in ipairs(s.c) do x.Visible=false end end
            if V.Box then
                setLine(s.b[1],Vector2.new(tl.X,tl.Y),Vector2.new(br.X,tl.Y),1,col,0); setLine(s.b[2],Vector2.new(br.X,tl.Y),Vector2.new(br.X,br.Y),1,col,0)
                setLine(s.b[3],Vector2.new(br.X,br.Y),Vector2.new(tl.X,br.Y),1,col,0); setLine(s.b[4],Vector2.new(tl.X,br.Y),Vector2.new(tl.X,tl.Y),1,col,0)
            else for _,x in ipairs(s.b) do x.Visible=false end end
            if V.Name or V.Distance then
                local txt=V.Name and targetName(m) or ""
                if V.Distance then txt=txt..(txt~="" and "  " or "").."["..math.floor(dist).."]" end
                s.name.Text=txt; s.name.Position=UDim2.fromOffset(mid.X-130,tl.Y-18); s.name.Visible=true
            else s.name.Visible=false end
            if V.HealthBar and hum then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                s.hb.Position=UDim2.fromOffset(br.X+4,tl.Y); s.hb.Size=UDim2.fromOffset(4,h); s.hb.Visible=true
                s.h.Position=UDim2.fromOffset(br.X+5,tl.Y+1+(h-2)*(1-ratio)); s.h.Size=UDim2.fromOffset(2,(h-2)*ratio); s.h.BackgroundColor3=Color3.fromHSV(ratio*.33,.8,1); s.h.Visible=true
            else s.hb.Visible=false; s.h.Visible=false end
            if V.Lines then setLine(s.line,start,Vector2.new(mid.X,br.Y),1,col,.08) else s.line.Visible=false end
        end
    end
end)
