-- GunTestingLiteMapESPV4.lua
-- Map-wide ESP for replicated NPC/bot Humanoid rigs.
-- Real game.Players Character models are excluded. No anti-cheat or remote hooks.

if shared.GunTestingLiteMapESPV4 then return end
shared.GunTestingLiteMapESPV4 = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local parent = (gethui and gethui()) or CoreGui
local Gui = parent:FindFirstChild("GunTestingLiteV1", true)
if not Gui then
    for _ = 1, 80 do task.wait(.05); Gui = parent:FindFirstChild("GunTestingLiteV1", true); if Gui then break end end
end
if not Gui then return end

local function findPage(name)
    for _, d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name == name then return d end
    end
end
local Visuals = findPage("Visuals")
if not Visuals then return end

-- Hide the old visual rows. Their state defaults off; V4 becomes the only visible ESP control set.
local oldLabels = {
    ["ESP Master"] = true, ["Corner"] = true, ["Box"] = true, ["Chams"] = true,
    ["Name"] = true, ["Distance"] = true, ["HealthBar"] = true, ["Lines"] = true,
    ["Visual Distance"] = true, ["Snapline"] = true, ["Snap Origin"] = true,
    ["Snap Thickness"] = true, ["Snap Transparency %"] = true, ["Snap Distance"] = true,
}
for _, child in ipairs(Visuals:GetChildren()) do
    if child:IsA("Frame") then
        local label = child:FindFirstChildOfClass("TextLabel")
        if label and oldLabels[label.Text] then child.Visible = false end
    elseif child:IsA("TextLabel") and tostring(child.Text):upper():find("SNAPLINE", 1, true) then
        child.Visible = false
    end
end

local accent = Color3.fromRGB(125,82,235)
local V = {
    Enabled = false,
    Corner = true,
    Box = false,
    Chams = false,
    Name = true,
    Distance = true,
    HealthBar = true,
    Lines = false,
    LineOrigin = "Bottom",
    MaxDistance = 100000,
    UpdateRate = 30,
}

local order = 12000
local function section(text)
    local l=Instance.new("TextLabel")
    l.Name="MapESPV4Section"; l.LayoutOrder=order; order+=1
    l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(160,154,185)
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=Visuals
end
local function row(label)
    local f=Instance.new("Frame")
    f.Name="MapESPV4_"..label:gsub("%W",""); f.LayoutOrder=order; order+=1
    f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=Visuals
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0)
    t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(230,230,240)
    t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f
end
local function toggle(label,key)
    local f=row(label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=V[key] == true
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function() V[key]=not V[key]; paint() end); paint()
end
local function number(label,key,min,max)
    local f=row(label)
    local box=Instance.new("TextBox")
    box.Size=UDim2.fromOffset(90,24); box.Position=UDim2.new(1,-100,.5,-12)
    box.BackgroundColor3=Color3.fromRGB(34,34,45); box.BorderSizePixel=0; box.Font=Enum.Font.Code; box.TextSize=12
    box.TextColor3=Color3.new(1,1,1); box.ClearTextOnFocus=false; box.Text=tostring(V[key]); box.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=box
    box.FocusLost:Connect(function()
        local n=tonumber(box.Text); if n then V[key]=math.clamp(n,min,max) end; box.Text=tostring(V[key])
    end)
end
local function choice(label,key,list)
    local f=row(label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(116,24); b.Position=UDim2.new(1,-126,.5,-12)
    b.BackgroundColor3=Color3.fromRGB(34,34,45); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=12
    b.TextColor3=Color3.new(1,1,1); b.Text=tostring(V[key]); b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function()
        local i=table.find(list,V[key]) or 1; V[key]=list[i%#list+1]; b.Text=tostring(V[key])
    end)
end

section("Map-wide ESP V4")
toggle("ESP (all replicated bots)","Enabled")
toggle("Corner","Corner")
toggle("Box","Box")
toggle("Chams","Chams")
toggle("Name","Name")
toggle("Distance","Distance")
toggle("HealthBar","HealthBar")
toggle("Snapline / Lines","Lines")
choice("Line Origin","LineOrigin",{"Bottom","Top","Center","Mouse"})
number("Max Distance","MaxDistance",100,1000000)
number("ESP FPS","UpdateRate",10,60)

local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isRealPlayerCharacter(model)
    if not model then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        local c=p.Character
        if c and (model==c or model:IsDescendantOf(c) or c:IsDescendantOf(model)) then return true end
    end
    return false
end
local function valid(model)
    if not model or not model:IsA("Model") or not model.Parent or model==LP.Character or isRealPlayerCharacter(model) then return false end
    local h=model:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and rootOf(model)~=nil
end
local function registerHumanoid(h)
    local m=h and h.Parent
    if m and m:IsA("Model") and valid(m) then targets[m]=true end
end

-- One full initial scan, then event-driven updates. This catches bots anywhere in Workspace.
targets=setmetatable({}, {__mode="k"})
for _, d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Humanoid") then registerHumanoid(d) end
end
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") then task.defer(registerHumanoid,d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then targets[d]=nil
    elseif d:IsA("Humanoid") and d.Parent then targets[d.Parent]=nil end
end)

local overlay=Instance.new("ScreenGui")
overlay.Name="GunTestingLiteMapESPV4"; overlay.ResetOnSpawn=false; overlay.IgnoreGuiInset=true; overlay.DisplayOrder=4888; overlay.Parent=parent
local stores=setmetatable({}, {__mode="k"})

local function newLine()
    local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Visible=false; f.Parent=overlay; return f
end
local function setLine(f,a,b,thickness,color,trans)
    local d=b-a; if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1); f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X)); f.BackgroundColor3=color; f.BackgroundTransparency=trans or 0; f.Visible=true
end
local function newStore(model)
    local s={}
    s.hi=Instance.new("Highlight"); s.hi.Name="MapESPV4Highlight"; s.hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; s.hi.Enabled=false; s.hi.Parent=Workspace
    s.corners={}; for i=1,8 do s.corners[i]=newLine() end
    s.box={}; for i=1,4 do s.box[i]=newLine() end
    s.line=newLine()
    s.name=Instance.new("TextLabel"); s.name.BackgroundTransparency=1; s.name.Size=UDim2.fromOffset(240,18); s.name.Font=Enum.Font.Code; s.name.TextSize=11
    s.name.TextColor3=Color3.new(1,1,1); s.name.TextStrokeTransparency=0; s.name.Visible=false; s.name.Parent=overlay
    s.hb=Instance.new("Frame"); s.hb.BorderSizePixel=0; s.hb.BackgroundColor3=Color3.new(0,0,0); s.hb.Visible=false; s.hb.Parent=overlay
    s.h=Instance.new("Frame"); s.h.BorderSizePixel=0; s.h.Visible=false; s.h.Parent=overlay
    stores[model]=s; return s
end
local function hide(s)
    s.hi.Enabled=false; s.line.Visible=false; s.name.Visible=false; s.hb.Visible=false; s.h.Visible=false
    for _,x in ipairs(s.corners) do x.Visible=false end; for _,x in ipairs(s.box) do x.Visible=false end
end
local function destroyStore(model)
    local s=stores[model]; if not s then return end
    for _,v in pairs(s) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in ipairs(v) do pcall(function() x:Destroy() end) end end
    end
    stores[model]=nil
end
local function bounds(model,cam)
    local ok,cf,size=pcall(function() local a,b=model:GetBoundingBox(); return a,b end)
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
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y; local w,h=r-l,b-t; local cw,ch=math.max(4,w*.22),math.max(4,h*.22)
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

local elapsed=0
RunService.RenderStepped:Connect(function(dt)
    elapsed+=dt; if elapsed < 1/math.max(10,V.UpdateRate) then return end; elapsed=0
    local cam=Workspace.CurrentCamera; if not cam then return end
    for m in pairs(stores) do if not targets[m] or not valid(m) then destroyStore(m) end end
    if not V.Enabled then for _,s in pairs(stores) do hide(s) end return end
    local origin=lineOrigin(cam)
    for m in pairs(targets) do
        if valid(m) then
            local root=rootOf(m); local hum=m:FindFirstChildOfClass("Humanoid")
            local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
            local s=stores[m] or newStore(m)
            if dist>V.MaxDistance then hide(s) continue end
            local tl,br=bounds(m,cam); if not tl then hide(s) continue end
            local center=Vector2.new((tl.X+br.X)/2,(tl.Y+br.Y)/2)
            local color=Color3.fromRGB(135,105,255)
            if V.Chams then s.hi.Adornee=m; s.hi.Enabled=true; s.hi.FillColor=color; s.hi.OutlineColor=Color3.new(1,1,1); s.hi.FillTransparency=.72; s.hi.OutlineTransparency=.10 else s.hi.Enabled=false end
            if V.Corner then drawCorners(s.corners,tl,br,color) else for _,x in ipairs(s.corners) do x.Visible=false end end
            if V.Box then
                setLine(s.box[1],Vector2.new(tl.X,tl.Y),Vector2.new(br.X,tl.Y),1,color,0); setLine(s.box[2],Vector2.new(br.X,tl.Y),Vector2.new(br.X,br.Y),1,color,0)
                setLine(s.box[3],Vector2.new(br.X,br.Y),Vector2.new(tl.X,br.Y),1,color,0); setLine(s.box[4],Vector2.new(tl.X,br.Y),Vector2.new(tl.X,tl.Y),1,color,0)
            else for _,x in ipairs(s.box) do x.Visible=false end end
            if V.Name or V.Distance then
                local text=""; if V.Name then text=(hum.DisplayName~="" and hum.DisplayName or m.Name) end
                if V.Distance then text=text..(text~="" and "  " or "").."["..math.floor(dist).."]" end
                s.name.Text=text; s.name.Position=UDim2.fromOffset(center.X-120,tl.Y-18); s.name.Visible=true
            else s.name.Visible=false end
            if V.HealthBar then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1); local h=br.Y-tl.Y
                s.hb.Position=UDim2.fromOffset(br.X+4,tl.Y); s.hb.Size=UDim2.fromOffset(4,h); s.hb.Visible=true
                s.h.Position=UDim2.fromOffset(br.X+5,tl.Y+1+(h-2)*(1-ratio)); s.h.Size=UDim2.fromOffset(2,(h-2)*ratio); s.h.BackgroundColor3=Color3.fromHSV(ratio*.33,.8,1); s.h.Visible=true
            else s.hb.Visible=false; s.h.Visible=false end
            if V.Lines then setLine(s.line,origin,Vector2.new(center.X,br.Y),1,color,.05) else s.line.Visible=false end
        end
    end
end)
