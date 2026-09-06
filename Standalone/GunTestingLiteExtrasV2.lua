-- GunTestingLiteExtrasV2.lua
-- Lightweight add-on for Standalone/GunTestingLiteV1.lua.
-- Adds Snaplines + local world visual controls without touching Combat/Movement.

if shared.GunTestingLiteExtrasV2 then return end
shared.GunTestingLiteExtrasV2 = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local parent = (gethui and gethui()) or CoreGui
local Gui = parent:FindFirstChild("GunTestingLiteV1", true)
if not Gui then
    for _=1,80 do
        task.wait(.05)
        Gui = parent:FindFirstChild("GunTestingLiteV1", true)
        if Gui then break end
    end
end
if not Gui then return end

local function findPage(name)
    for _,d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name == name then return d end
    end
end
local Visuals = findPage("Visuals")
local World = findPage("World")
if not (Visuals and World) then return end

local accent = Color3.fromRGB(120,75,230)
local E = {
    Snapline=false,
    SnapOrigin="Bottom",
    SnapThickness=1,
    SnapTransparency=10,
    SnapDistance=1500,
    Fullbright=false,
    FullbrightStrength=55,
    NoLeaves=false,
    NoFog=false,
    NoShadows=false,
}

local function section(page,text)
    local l=Instance.new("TextLabel")
    l.Name="LiteExtrasSection_"..text
    l.LayoutOrder=9000
    l.Size=UDim2.new(1,0,0,22)
    l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold
    l.TextSize=12
    l.TextColor3=Color3.fromRGB(145,145,165)
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Text=string.upper(text)
    l.Parent=page
end

local function row(page,label,order)
    local f=Instance.new("Frame")
    f.Name="LiteExtras_"..label:gsub("%W","")
    f.LayoutOrder=order or 9010
    f.Size=UDim2.new(1,0,0,36)
    f.BackgroundColor3=Color3.fromRGB(24,24,33)
    f.BorderSizePixel=0
    f.Parent=page
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0)
    t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(224,224,234)
    t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f
end

local function toggle(page,label,key,order,callback)
    local f=row(page,label,order)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=E[key]
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1)
        dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function()
        E[key]=not E[key]
        paint()
        if callback then task.defer(callback,E[key]) end
    end)
    paint()
end

local function number(page,label,key,min,max,order,callback)
    local f=row(page,label,order)
    local box=Instance.new("TextBox")
    box.Size=UDim2.fromOffset(78,24); box.Position=UDim2.new(1,-88,.5,-12)
    box.BackgroundColor3=Color3.fromRGB(34,34,45); box.BorderSizePixel=0
    box.Font=Enum.Font.Code; box.TextSize=12; box.TextColor3=Color3.new(1,1,1)
    box.Text=tostring(E[key]); box.ClearTextOnFocus=false; box.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=box
    box.FocusLost:Connect(function()
        local v=tonumber(box.Text)
        if v then E[key]=math.clamp(v,min,max) end
        box.Text=tostring(E[key])
        if callback then task.defer(callback,E[key]) end
    end)
end

local function choice(page,label,key,list,order)
    local f=row(page,label,order)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(116,24); b.Position=UDim2.new(1,-126,.5,-12)
    b.BackgroundColor3=Color3.fromRGB(34,34,45); b.BorderSizePixel=0
    b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text=E[key]; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function()
        local i=table.find(list,E[key]) or 1
        E[key]=list[i%#list+1]
        b.Text=E[key]
    end)
end

-- UI -----------------------------------------------------------------------
section(Visuals,"Snapline")
toggle(Visuals,"Snapline", "Snapline", 9010)
choice(Visuals,"Snap Origin", "SnapOrigin", {"Bottom","Top","Center","Mouse"}, 9020)
number(Visuals,"Snap Thickness", "SnapThickness", 1, 5, 9030)
number(Visuals,"Snap Transparency %", "SnapTransparency", 0, 95, 9040)
number(Visuals,"Snap Distance", "SnapDistance", 50, 5000, 9050)

section(World,"World Visuals")

local fullbrightFx=Lighting:FindFirstChild("GunTestingLiteFullbrightV2")
if not fullbrightFx then
    fullbrightFx=Instance.new("ColorCorrectionEffect")
    fullbrightFx.Name="GunTestingLiteFullbrightV2"
    fullbrightFx.Enabled=false
    fullbrightFx.Parent=Lighting
end
local function applyFullbright()
    fullbrightFx.Enabled=E.Fullbright
    fullbrightFx.Brightness=math.clamp(E.FullbrightStrength/100,0,1)*0.38
    fullbrightFx.Contrast=-0.08
    fullbrightFx.Saturation=0.02
    fullbrightFx.TintColor=Color3.fromRGB(255,250,242)
end

toggle(World,"Fullbright", "Fullbright", 9010, applyFullbright)
number(World,"Fullbright Strength", "FullbrightStrength", 0, 100, 9020, applyFullbright)

local leafStore=setmetatable({}, {__mode="k"})
local leafWords={"leaf","leaves","foliage","bush","shrub"}
local function looksLeaf(obj)
    if not obj:IsA("BasePart") then return false end
    local n=obj.Name:lower()
    for _,w in ipairs(leafWords) do if n:find(w,1,true) then return true end end
    local p=obj.Parent
    if p then
        n=p.Name:lower()
        for _,w in ipairs(leafWords) do if n:find(w,1,true) then return true end end
    end
    return false
end
local function setLeaf(obj,hide)
    if not looksLeaf(obj) then return end
    if hide then
        if leafStore[obj]==nil then leafStore[obj]=obj.LocalTransparencyModifier end
        obj.LocalTransparencyModifier=1
    elseif leafStore[obj]~=nil then
        obj.LocalTransparencyModifier=leafStore[obj]
        leafStore[obj]=nil
    end
end
local leafJob=0
local function applyLeaves(on)
    leafJob+=1
    local myJob=leafJob
    if not on then
        for obj in pairs(leafStore) do if obj and obj.Parent then pcall(setLeaf,obj,false) end end
        return
    end
    task.spawn(function()
        local list=Workspace:GetDescendants()
        for i,obj in ipairs(list) do
            if myJob~=leafJob or not E.NoLeaves then return end
            if obj:IsA("BasePart") then pcall(setLeaf,obj,true) end
            if i%180==0 then task.wait() end
        end
    end)
end
Workspace.DescendantAdded:Connect(function(obj)
    if E.NoLeaves and obj:IsA("BasePart") then task.defer(setLeaf,obj,true) end
end)
toggle(World,"No Leaves", "NoLeaves", 9030, applyLeaves)

local fogBackup=nil
local function applyFog(on)
    if on then
        if not fogBackup then fogBackup={Start=Lighting.FogStart,End=Lighting.FogEnd} end
        Lighting.FogStart=0
        Lighting.FogEnd=1000000
        for _,a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                if a:GetAttribute("LiteOldDensity")==nil then a:SetAttribute("LiteOldDensity",a.Density) end
                a.Density=0
            end
        end
    elseif fogBackup then
        Lighting.FogStart=fogBackup.Start; Lighting.FogEnd=fogBackup.End
        fogBackup=nil
        for _,a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                local old=a:GetAttribute("LiteOldDensity")
                if old~=nil then a.Density=old; a:SetAttribute("LiteOldDensity",nil) end
            end
        end
    end
end
toggle(World,"No Fog", "NoFog", 9040, applyFog)

local oldShadows=nil
local function applyShadows(on)
    if on then
        if oldShadows==nil then oldShadows=Lighting.GlobalShadows end
        Lighting.GlobalShadows=false
    elseif oldShadows~=nil then
        Lighting.GlobalShadows=oldShadows
        oldShadows=nil
    end
end
toggle(World,"No Shadows", "NoShadows", 9050, applyShadows)

-- Snapline target registry --------------------------------------------------
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function realCharacter(model)
    if not model then return false end
    for _,p in ipairs(Players:GetPlayers()) do
        local c=p.Character
        if c and (model==c or model:IsDescendantOf(c) or c:IsDescendantOf(model)) then return true end
    end
    return false
end
local function valid(model)
    if not model or not model:IsA("Model") or not model.Parent or model==LP.Character or realCharacter(model) then return false end
    local h=model:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and rootOf(model)~=nil
end
local bots=setmetatable({}, {__mode="k"})
local watched=setmetatable({}, {__mode="k"})
local names={Players=true,Bots=true,NPCs=true,Dummies=true,Zombies=true,Characters=true}
local function register(m) if valid(m) then bots[m]=true end end
local function watch(c)
    if not c or watched[c] then return end
    watched[c]=true
    for _,d in ipairs(c:GetDescendants()) do if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end end
    c.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(register,d.Parent) end end)
    c.DescendantRemoving:Connect(function(d) if d:IsA("Model") then bots[d]=nil elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end end)
end
for _,c in ipairs(Workspace:GetChildren()) do if names[c.Name] then watch(c) end end
Workspace.ChildAdded:Connect(function(c) if names[c.Name] then task.defer(watch,c) end end)

local overlay=Instance.new("ScreenGui")
overlay.Name="GunTestingLiteSnaplinesV2"; overlay.ResetOnSpawn=false; overlay.IgnoreGuiInset=true; overlay.DisplayOrder=4895; overlay.Parent=parent
local lines=setmetatable({}, {__mode="k"})
local function getLine(model)
    local f=lines[model]
    if f and f.Parent then return f end
    f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(160,130,255); f.Visible=false; f.Parent=overlay
    lines[model]=f
    return f
end
local function drawLine(f,a,b)
    local d=b-a
    if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,E.SnapThickness)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundTransparency=E.SnapTransparency/100
    f.Visible=true
end
local function originPoint(cam)
    local vp=cam.ViewportSize
    if E.SnapOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if E.SnapOrigin=="Center" then return vp/2 end
    if E.SnapOrigin=="Mouse" then
        local m=UIS:GetMouseLocation(); return Vector2.new(math.clamp(m.X,0,vp.X),math.clamp(m.Y,0,vp.Y))
    end
    return Vector2.new(vp.X/2,vp.Y)
end

local clock=0
RunService.RenderStepped:Connect(function(dt)
    clock+=dt
    if clock<1/30 then return end
    clock=0
    local cam=Workspace.CurrentCamera
    if not cam then return end
    for model,f in pairs(lines) do if not bots[model] or not valid(model) then f:Destroy(); lines[model]=nil end end
    if not E.Snapline then for _,f in pairs(lines) do f.Visible=false end return end
    local start=originPoint(cam)
    for model in pairs(bots) do
        if valid(model) then
            local root=rootOf(model)
            local dist=(root.Position-cam.CFrame.Position).Magnitude
            local p,on=cam:WorldToViewportPoint(root.Position)
            local f=getLine(model)
            if on and p.Z>0 and dist<=E.SnapDistance then
                drawLine(f,start,Vector2.new(p.X,p.Y))
            else f.Visible=false end
        end
    end
end)

applyFullbright()
print("[GunTestingLite] Extras V2 loaded")
