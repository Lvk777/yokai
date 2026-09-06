-- GunTestingLiteV1.lua
-- Clean standalone bot-practice client. No dependency on the old Yokai menu.
-- Targets world Humanoid rigs that are NOT the LocalPlayer character and are NOT
-- an exact Character of another game.Players entry. Workspace.Players may still
-- contain bot rigs; folder name alone does not make them a real Player target.
-- No __namecall hooks, no kick hooks, no anti-cheat bypass.

if shared.GunTestingLiteV1 then return end
shared.GunTestingLiteV1 = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================================
-- State
-- ============================================================================
local S = {
    Aimbot=false, AimFov=320, AimSmooth=.82, AimPart="Head", AimWall=true,
    SilentAim=false, SilentFov=420, SilentPart="Head", SilentWall=true,
    Hitbox=false, HitboxSize=6, HitboxPart="Head",
    NoRecoil=false, RecoilStrength=1,
    ESP=false, Corner=true, Box=false, Chams=false, Name=true, Distance=true,
    HealthBar=true, Lines=false, VisualDistance=1200,
    ESPColor=Color3.fromRGB(115,120,255), VisibleColor=Color3.fromRGB(60,235,135), OccludedColor=Color3.fromRGB(245,80,80),
    Fly=false, FlySpeed=75,
    WalkSpeed=false, WalkSpeedValue=28,
    CarFly=false, CarFlySpeed=100,
    CarESP=false,
    HitSound=false, HitSoundId="rbxassetid://9118823106",
    Crosshair=true, CrosshairSize=9, CrosshairGap=5, CrosshairColor=Color3.fromRGB(220,220,235),
}

local mouse1=false
local mouse2=false
local hitFlashUntil=0
local lastPitch=nil

-- ============================================================================
-- Helpers
-- ============================================================================
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end

local function realPlayerCharacter(model)
    if not model then return false end
    for _,p in ipairs(Players:GetPlayers()) do
        local c=p.Character
        if c and (model==c or model:IsDescendantOf(c) or c:IsDescendantOf(model)) then
            return true
        end
    end
    return false
end

local function validBot(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    if model==LP.Character or realPlayerCharacter(model) then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health>0 and rootOf(model)~=nil
end

local function botName(model)
    local hum=model and model:FindFirstChildOfClass("Humanoid")
    if hum and hum.DisplayName and hum.DisplayName~="" and hum.DisplayName~="Humanoid" then return hum.DisplayName end
    return model and model.Name or "Bot"
end

local function targetPart(model, name)
    if not model then return nil end
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end

local function isVisible(model, part)
    Camera=Workspace.CurrentCamera
    if not Camera or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local f={Camera}
    if LP.Character then table.insert(f,LP.Character) end
    rp.FilterDescendantsInstances=f
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(Camera.CFrame.Position,part.Position-Camera.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end

local function screenCenter()
    Camera=Workspace.CurrentCamera
    return Camera and Camera.ViewportSize/2 or Vector2.zero
end

-- ============================================================================
-- Event-driven bot registry
-- ============================================================================
local bots=setmetatable({}, {__mode="k"})
local watched=setmetatable({}, {__mode="k"})
local preferredNames={Players=true,Bots=true,NPCs=true,Dummies=true,Zombies=true,Characters=true}

local function registerModel(m)
    if validBot(m) then bots[m]=true end
end

local function watchContainer(c)
    if not c or watched[c] then return end
    watched[c]=true
    for _,d in ipairs(c:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerModel(d.Parent) end
    end
    c.DescendantAdded:Connect(function(d)
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerModel,d.Parent) end
    end)
    c.DescendantRemoving:Connect(function(d)
        if d:IsA("Model") then bots[d]=nil
        elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
    end)
end

for _,c in ipairs(Workspace:GetChildren()) do
    if preferredNames[c.Name] then watchContainer(c) end
end
Workspace.ChildAdded:Connect(function(c)
    if preferredNames[c.Name] then task.defer(watchContainer,c) end
end)

local function nearestBot(maxPx, maxStuds, partName, wall, useCenter)
    Camera=Workspace.CurrentCamera
    if not Camera then return nil end
    local ref
    if useCenter then ref=screenCenter() else
        local m=UIS:GetMouseLocation(); ref=Vector2.new(m.X,m.Y)
    end
    local best,bestPart,bestPx=nil,nil,maxPx or math.huge
    for model in pairs(bots) do
        if validBot(model) then
            local root=rootOf(model)
            local part=targetPart(model,partName)
            if root and part and (root.Position-Camera.CFrame.Position).Magnitude<=(maxStuds or math.huge) then
                local p,on=Camera:WorldToViewportPoint(part.Position)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-ref).Magnitude
                    if px<bestPx and (not wall or isVisible(model,part)) then
                        best,bestPart,bestPx=model,part,px
                    end
                end
            end
        end
    end
    return best,bestPart,bestPx
end

-- ============================================================================
-- GUI
-- ============================================================================
local parent=(gethui and gethui()) or CoreGui
local old=parent:FindFirstChild("GunTestingLiteV1",true)
if old then old:Destroy() end

local Gui=Instance.new("ScreenGui")
Gui.Name="GunTestingLiteV1"; Gui.ResetOnSpawn=false; Gui.IgnoreGuiInset=true; Gui.DisplayOrder=5000; Gui.Parent=parent

local Main=Instance.new("Frame")
Main.Size=UDim2.fromOffset(660,410); Main.Position=UDim2.new(.5,-330,.5,-205)
Main.BackgroundColor3=Color3.fromRGB(15,15,20); Main.BackgroundTransparency=.06; Main.BorderSizePixel=0; Main.Parent=Gui
local mc=Instance.new("UICorner"); mc.CornerRadius=UDim.new(0,10); mc.Parent=Main

local Stroke=Instance.new("UIStroke"); Stroke.Color=Color3.fromRGB(70,70,95); Stroke.Transparency=.35; Stroke.Thickness=1; Stroke.Parent=Main

local Top=Instance.new("Frame")
Top.Size=UDim2.new(1,0,0,48); Top.BackgroundColor3=Color3.fromRGB(19,19,27); Top.BorderSizePixel=0; Top.Parent=Main
local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,10); tc.Parent=Top

local Title=Instance.new("TextLabel")
Title.BackgroundTransparency=1; Title.Position=UDim2.fromOffset(18,0); Title.Size=UDim2.new(1,-36,1,0)
Title.Font=Enum.Font.GothamBold; Title.TextSize=18; Title.TextColor3=Color3.fromRGB(238,238,248); Title.TextXAlignment=Enum.TextXAlignment.Left
Title.Text="YOKAI  •  Gun Testing Lite"; Title.Parent=Top

local Sidebar=Instance.new("Frame")
Sidebar.Position=UDim2.fromOffset(0,48); Sidebar.Size=UDim2.new(0,150,1,-48); Sidebar.BackgroundColor3=Color3.fromRGB(17,17,23); Sidebar.BorderSizePixel=0; Sidebar.Parent=Main
local Content=Instance.new("Frame")
Content.Position=UDim2.fromOffset(150,48); Content.Size=UDim2.new(1,-150,1,-48); Content.BackgroundTransparency=1; Content.Parent=Main

local pages={}
local selected=nil
local accent=Color3.fromRGB(120,75,230)
local function makePage(name)
    local p=Instance.new("ScrollingFrame")
    p.Name=name; p.Size=UDim2.fromScale(1,1); p.BackgroundTransparency=1; p.BorderSizePixel=0; p.ScrollBarThickness=3; p.ScrollBarImageColor3=accent; p.Visible=false; p.AutomaticCanvasSize=Enum.AutomaticSize.Y; p.CanvasSize=UDim2.new(); p.Parent=Content
    local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,12); pad.PaddingLeft=UDim.new(0,14); pad.PaddingRight=UDim.new(0,14); pad.PaddingBottom=UDim.new(0,12); pad.Parent=p
    local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=p
    pages[name]=p
    return p
end
for _,n in ipairs({"Combat","Visuals","Movement","World"}) do makePage(n) end

local function tabButton(name,order)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-16,0,38); b.Position=UDim2.fromOffset(8,8+(order-1)*44); b.BackgroundColor3=Color3.fromRGB(20,20,27); b.BackgroundTransparency=1; b.BorderSizePixel=0
    b.Font=Enum.Font.GothamMedium; b.TextSize=13; b.TextColor3=Color3.fromRGB(190,190,205); b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="   "..name; b.Parent=Sidebar
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=b
    b.MouseButton1Click:Connect(function()
        for n,p in pairs(pages) do p.Visible=(n==name) end
        for _,x in ipairs(Sidebar:GetChildren()) do if x:IsA("TextButton") then x.BackgroundTransparency=1; x.TextColor3=Color3.fromRGB(190,190,205) end end
        b.BackgroundTransparency=.25; b.BackgroundColor3=accent; b.TextColor3=Color3.new(1,1,1); selected=name
    end)
    return b
end
local tabs={}
for i,n in ipairs({"Combat","Visuals","Movement","World"}) do tabs[n]=tabButton(n,i) end

local function section(page,text)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1; l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(145,145,165); l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=page
end

local function row(page,label)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=page
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0); t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(224,224,234); t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f,t
end

local function addToggle(page,label,key)
    local f=row(page,label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Position=UDim2.fromOffset(3,3); dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=S[key]==true
        b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1)
        TweenService:Create(dot,TweenInfo.new(.12),{Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)}):Play()
    end
    b.MouseButton1Click:Connect(function() S[key]=not S[key]; paint() end)
    paint()
    return f
end

local function addNumber(page,label,key,min,max)
    local f=row(page,label)
    local box=Instance.new("TextBox")
    box.Size=UDim2.fromOffset(78,24); box.Position=UDim2.new(1,-88,.5,-12); box.BackgroundColor3=Color3.fromRGB(34,34,45); box.BorderSizePixel=0; box.Font=Enum.Font.Code; box.TextSize=12; box.TextColor3=Color3.new(1,1,1); box.Text=tostring(S[key]); box.ClearTextOnFocus=false; box.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=box
    box.FocusLost:Connect(function()
        local v=tonumber(box.Text)
        if v then S[key]=math.clamp(v,min,max) end
        box.Text=tostring(S[key])
    end)
end

local function addChoice(page,label,key,list)
    local f=row(page,label)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(116,24); b.Position=UDim2.new(1,-126,.5,-12); b.BackgroundColor3=Color3.fromRGB(34,34,45); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.Text=tostring(S[key]); b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=b
    b.MouseButton1Click:Connect(function()
        local idx=table.find(list,S[key]) or 1
        idx=idx%#list+1; S[key]=list[idx]; b.Text=tostring(S[key])
    end)
end

section(pages.Combat,"Aim")
addToggle(pages.Combat,"Aimbot", "Aimbot")
addNumber(pages.Combat,"Aimbot FOV", "AimFov", 30, 1200)
addNumber(pages.Combat,"Aimbot Smooth 0.05-1", "AimSmooth", .05, 1)
addChoice(pages.Combat,"Aim Part", "AimPart", {"Head","Torso"})
addToggle(pages.Combat,"Wall Check", "AimWall")
addToggle(pages.Combat,"Silent Aim", "SilentAim")
addNumber(pages.Combat,"Silent FOV", "SilentFov", 30, 1600)
addChoice(pages.Combat,"Silent Part", "SilentPart", {"Head","Torso"})
addToggle(pages.Combat,"Silent Wall Check", "SilentWall")
section(pages.Combat,"Weapon")
addToggle(pages.Combat,"HitBox Expander", "Hitbox")
addNumber(pages.Combat,"HitBox Size", "HitboxSize", 2, 20)
addChoice(pages.Combat,"HitBox Part", "HitboxPart", {"Head","Torso"})
addToggle(pages.Combat,"No Recoil", "NoRecoil")
addNumber(pages.Combat,"Recoil Strength 0-1", "RecoilStrength", 0, 1)

section(pages.Visuals,"ESP")
addToggle(pages.Visuals,"ESP Master", "ESP")
addToggle(pages.Visuals,"Corner", "Corner")
addToggle(pages.Visuals,"Box", "Box")
addToggle(pages.Visuals,"Chams", "Chams")
addToggle(pages.Visuals,"Name", "Name")
addToggle(pages.Visuals,"Distance", "Distance")
addToggle(pages.Visuals,"HealthBar", "HealthBar")
addToggle(pages.Visuals,"Lines", "Lines")
addNumber(pages.Visuals,"Visual Distance", "VisualDistance", 50, 5000)
section(pages.Visuals,"Other")
addToggle(pages.Visuals,"Car ESP", "CarESP")
addToggle(pages.Visuals,"Custom Crosshair", "Crosshair")
addNumber(pages.Visuals,"Crosshair Size", "CrosshairSize", 4, 30)
addNumber(pages.Visuals,"Crosshair Gap", "CrosshairGap", 1, 20)

section(pages.Movement,"Player")
addToggle(pages.Movement,"Fly", "Fly")
addNumber(pages.Movement,"Fly Speed", "FlySpeed", 10, 250)
addToggle(pages.Movement,"WalkSpeed", "WalkSpeed")
addNumber(pages.Movement,"WalkSpeed Value", "WalkSpeedValue", 16, 120)
section(pages.Movement,"Vehicle")
addToggle(pages.Movement,"Car Fly  W/A/S/D + E/Q", "CarFly")
addNumber(pages.Movement,"Car Fly Speed", "CarFlySpeed", 20, 300)

section(pages.World,"Feedback")
addToggle(pages.World,"HitSound", "HitSound")

-- open Combat
tabs.Combat:Activate()
for n,p in pairs(pages) do p.Visible=(n=="Combat") end
tabs.Combat.BackgroundTransparency=.25; tabs.Combat.BackgroundColor3=accent; tabs.Combat.TextColor3=Color3.new(1,1,1)

-- drag
local dragging=false; local dragStart; local startPos
Top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=i.Position; startPos=Main.Position end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart; Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
UIS.InputBegan:Connect(function(i,p)
    if p then return end
    if i.KeyCode==Enum.KeyCode.RightShift then Main.Visible=not Main.Visible end
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=true end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=true end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then mouse1=false end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then mouse2=false end
end)

-- ============================================================================
-- Visual overlay
-- ============================================================================
local Overlay=Instance.new("ScreenGui")
Overlay.Name="GunTestingLiteOverlay"; Overlay.ResetOnSpawn=false; Overlay.IgnoreGuiInset=true; Overlay.DisplayOrder=4900; Overlay.Parent=parent
local stores=setmetatable({}, {__mode="k"})

local function line(parent)
    local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Visible=false; f.Parent=parent; return f
end
local function setLine(f,a,b,thickness,color,trans)
    local d=b-a
    if d.Magnitude<.1 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X)); f.BackgroundColor3=color; f.BackgroundTransparency=trans or 0; f.Visible=true
end

local function newStore(model)
    local s={}
    s.hi=Instance.new("Highlight"); s.hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; s.hi.Enabled=false; s.hi.Parent=Workspace
    s.box={}; for i=1,8 do s.box[i]=line(Overlay) end
    s.full={}; for i=1,4 do s.full[i]=line(Overlay) end
    s.tracer=line(Overlay)
    s.name=Instance.new("TextLabel"); s.name.BackgroundTransparency=1; s.name.Size=UDim2.fromOffset(220,18); s.name.Font=Enum.Font.Code; s.name.TextSize=11; s.name.TextColor3=Color3.new(1,1,1); s.name.TextStrokeTransparency=0; s.name.Visible=false; s.name.Parent=Overlay
    s.healthBack=Instance.new("Frame"); s.healthBack.BorderSizePixel=0; s.healthBack.BackgroundColor3=Color3.new(0,0,0); s.healthBack.Visible=false; s.healthBack.Parent=Overlay
    s.health=Instance.new("Frame"); s.health.BorderSizePixel=0; s.health.BackgroundColor3=Color3.fromRGB(70,230,120); s.health.Visible=false; s.health.Parent=Overlay
    stores[model]=s
    return s
end
local function hideStore(s)
    s.hi.Enabled=false; s.tracer.Visible=false; s.name.Visible=false; s.health.Visible=false; s.healthBack.Visible=false
    for _,x in ipairs(s.box) do x.Visible=false end; for _,x in ipairs(s.full) do x.Visible=false end
end
local function destroyStore(model)
    local s=stores[model]; if not s then return end
    for _,v in pairs(s) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in ipairs(v) do pcall(function() x:Destroy() end) end end
    end
    stores[model]=nil
end

local function bounds(model)
    Camera=Workspace.CurrentCamera; if not Camera then return nil end
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge; local any=false
    for _,p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency<1 then
            local size=p.Size; local cf=p.CFrame
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local v=Camera:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
                if v.Z>0 then any=true; minX=math.min(minX,v.X); minY=math.min(minY,v.Y); maxX=math.max(maxX,v.X); maxY=math.max(maxY,v.Y) end
            end end end
        end
    end
    if not any then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end

local function drawCorners(lines,tl,br,color)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y; local w,h=r-l,b-t; local cw,ch=math.max(5,w*.22),math.max(5,h*.22)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],1,color,0) end
end

-- ============================================================================
-- HitSound + hit flash
-- ============================================================================
local hitSound=Instance.new("Sound")
hitSound.Name="GunTestingLiteHitSound"; hitSound.Volume=.8; hitSound.SoundId=S.HitSoundId; hitSound.Parent=Camera or Workspace
local healthCache=setmetatable({}, {__mode="k"})
local function bindHealth(model)
    local hum=model and model:FindFirstChildOfClass("Humanoid")
    if not hum or healthCache[hum] then return end
    healthCache[hum]=hum.Health
    hum.HealthChanged:Connect(function(v)
        local old=healthCache[hum] or v; healthCache[hum]=v
        if v<old and mouse1 then
            hitFlashUntil=os.clock()+.14
            if S.HitSound then
                hitSound.SoundId=S.HitSoundId
                pcall(function() hitSound.TimePosition=0; hitSound:Play() end)
            end
        end
    end)
end

-- ============================================================================
-- HitBox restore store
-- ============================================================================
local originalSize=setmetatable({}, {__mode="k"})
local function restoreHitboxes()
    for p,sz in pairs(originalSize) do if p and p.Parent then pcall(function() p.Size=sz end) end originalSize[p]=nil end
end

-- ============================================================================
-- SilentAim: use GunTesting's local GunPlugin world-look API when available.
-- Fallback is one-frame pre-shot camera correction. No remotes/metamethods.
-- ============================================================================
local GunPlugin=nil
local originalGetWorldLookAtPos=nil
pcall(function()
    local ps=LP:WaitForChild("PlayerScripts",5)
    local gc=ps and ps:FindFirstChild("GunController")
    local ev=gc and gc:FindFirstChild("Events")
    local mod=ev and ev:FindFirstChild("GunPlugin")
    if mod and mod:IsA("ModuleScript") then
        local g=require(mod)
        if type(g)=="table" then GunPlugin=g end
    end
end)
if GunPlugin and type(GunPlugin.GetWorldLookAtPos)=="function" then
    originalGetWorldLookAtPos=GunPlugin.GetWorldLookAtPos
    GunPlugin.GetWorldLookAtPos=function(self,...)
        if S.SilentAim then
            local model,part=nearestBot(S.SilentFov,S.VisualDistance,S.SilentPart,S.SilentWall,true)
            if model and part then return part.Position end
        end
        return originalGetWorldLookAtPos(self,...)
    end
end

UIS.InputBegan:Connect(function(i,p)
    if p or i.UserInputType~=Enum.UserInputType.MouseButton1 or not S.SilentAim or GunPlugin then return end
    Camera=Workspace.CurrentCamera; if not Camera then return end
    local _,part=nearestBot(S.SilentFov,S.VisualDistance,S.SilentPart,S.SilentWall,true)
    if not part then return end
    local before=Camera.CFrame
    Camera.CFrame=CFrame.lookAt(before.Position,part.Position)
    task.defer(function() if Camera and Camera.Parent then Camera.CFrame=before end end)
end)

-- ============================================================================
-- Crosshair
-- ============================================================================
local Cross=Instance.new("Frame"); Cross.Size=UDim2.fromOffset(1,1); Cross.Position=UDim2.fromScale(.5,.5); Cross.BackgroundTransparency=1; Cross.Parent=Overlay
local crossLines={}
for i=1,4 do local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Parent=Cross; crossLines[i]=f end

-- ============================================================================
-- Main runtime: one render loop
-- ============================================================================
local visualClock=0
RunService.RenderStepped:Connect(function(dt)
    Camera=Workspace.CurrentCamera
    if not Camera then return end

    -- Aimbot
    if S.Aimbot and mouse2 then
        local _,part=nearestBot(S.AimFov,S.VisualDistance,S.AimPart,S.AimWall,true)
        if part then
            local desired=CFrame.lookAt(Camera.CFrame.Position,part.Position)
            Camera.CFrame=Camera.CFrame:Lerp(desired,math.clamp(S.AimSmooth,.05,1))
        end
    end

    -- No recoil (generic local camera stabilizer)
    local pitch=select(1,Camera.CFrame:ToOrientation())
    if S.NoRecoil and mouse1 and lastPitch then
        local delta=pitch-lastPitch
        if math.abs(delta)>.0025 then
            local _,yaw,roll=Camera.CFrame:ToOrientation()
            local targetPitch=lastPitch+delta*(1-math.clamp(S.RecoilStrength,0,1))
            Camera.CFrame=CFrame.new(Camera.CFrame.Position)*CFrame.fromOrientation(targetPitch,yaw,roll)
            pitch=targetPitch
        end
    end
    lastPitch=pitch

    -- WalkSpeed
    if S.WalkSpeed and LP.Character then
        local hum=LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=S.WalkSpeedValue end
    end

    -- Fly
    if S.Fly and LP.Character then
        local hum=LP.Character:FindFirstChildOfClass("Humanoid")
        local root=rootOf(LP.Character)
        if hum and root then
            hum.PlatformStand=true
            local f=Vector3.new(Camera.CFrame.LookVector.X,0,Camera.CFrame.LookVector.Z)
            local r=Vector3.new(Camera.CFrame.RightVector.X,0,Camera.CFrame.RightVector.Z)
            if f.Magnitude>.01 then f=f.Unit end; if r.Magnitude>.01 then r=r.Unit end
            local v=Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then v+=f end
            if UIS:IsKeyDown(Enum.KeyCode.S) then v-=f end
            if UIS:IsKeyDown(Enum.KeyCode.D) then v+=r end
            if UIS:IsKeyDown(Enum.KeyCode.A) then v-=r end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then v+=Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then v-=Vector3.yAxis end
            root.AssemblyLinearVelocity=v.Magnitude>0 and v.Unit*S.FlySpeed or Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
        end
    elseif LP.Character then
        local hum=LP.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.PlatformStand then hum.PlatformStand=false end
    end

    -- CarFly: W/A/S/D, E up, Q down
    if S.CarFly and LP.Character then
        local hum=LP.Character:FindFirstChildOfClass("Humanoid")
        local seat=hum and hum.SeatPart
        if seat then
            local model=seat:FindFirstAncestorOfClass("Model")
            local root=(model and model.PrimaryPart) or seat.AssemblyRootPart or seat
            if root then
                local f=Vector3.new(Camera.CFrame.LookVector.X,0,Camera.CFrame.LookVector.Z)
                local r=Vector3.new(Camera.CFrame.RightVector.X,0,Camera.CFrame.RightVector.Z)
                if f.Magnitude>.01 then f=f.Unit end; if r.Magnitude>.01 then r=r.Unit end
                local v=Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then v+=f end
                if UIS:IsKeyDown(Enum.KeyCode.S) then v-=f end
                if UIS:IsKeyDown(Enum.KeyCode.D) then v+=r end
                if UIS:IsKeyDown(Enum.KeyCode.A) then v-=r end
                if UIS:IsKeyDown(Enum.KeyCode.E) then v+=Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.Q) then v-=Vector3.yAxis end
                root.AssemblyLinearVelocity=v.Magnitude>0 and v.Unit*S.CarFlySpeed or Vector3.zero
            end
        end
    end

    -- Crosshair animation
    local crossOn=S.Crosshair
    local c= os.clock()<hitFlashUntil and Color3.fromRGB(255,70,70) or S.CrosshairColor
    local gap=S.CrosshairGap + math.sin(os.clock()*5)*1.2
    local len=S.CrosshairSize
    for _,x in ipairs(crossLines) do x.Visible=crossOn; x.BackgroundColor3=c end
    crossLines[1].Size=UDim2.fromOffset(len,2); crossLines[1].Position=UDim2.fromOffset(-(gap+len/2),0)
    crossLines[2].Size=UDim2.fromOffset(len,2); crossLines[2].Position=UDim2.fromOffset(gap+len/2,0)
    crossLines[3].Size=UDim2.fromOffset(2,len); crossLines[3].Position=UDim2.fromOffset(0,-(gap+len/2))
    crossLines[4].Size=UDim2.fromOffset(2,len); crossLines[4].Position=UDim2.fromOffset(0,gap+len/2)

    visualClock+=dt
    if visualClock<1/30 then return end
    visualClock=0

    -- Hitbox update at 30Hz, restore when off
    if S.Hitbox then
        for model in pairs(bots) do
            if validBot(model) then
                local p=targetPart(model,S.HitboxPart)
                if p and p:IsA("BasePart") then
                    if not originalSize[p] then originalSize[p]=p.Size end
                    p.Size=Vector3.new(S.HitboxSize,S.HitboxSize,S.HitboxSize)
                    p.CanCollide=false
                end
            end
        end
    elseif next(originalSize) then
        restoreHitboxes()
    end

    -- ESP bots
    for model,s in pairs(stores) do if not bots[model] or not validBot(model) then destroyStore(model) end end
    for model in pairs(bots) do
        if validBot(model) then
            bindHealth(model)
            local s=stores[model] or newStore(model)
            local root=rootOf(model); local hum=model:FindFirstChildOfClass("Humanoid")
            local dist=root and (root.Position-Camera.CFrame.Position).Magnitude or math.huge
            local tl,br=bounds(model)
            if not S.ESP or not tl or dist>S.VisualDistance then hideStore(s) continue end
            local head=model:FindFirstChild("Head") or root
            local vis=isVisible(model,head)
            local col=vis and S.VisibleColor or S.OccludedColor
            local mid=Vector2.new((tl.X+br.X)/2,(tl.Y+br.Y)/2)
            local w,h=br.X-tl.X,br.Y-tl.Y

            if S.Chams then
                s.hi.Adornee=model; s.hi.Enabled=true; s.hi.FillColor=col; s.hi.OutlineColor=col; s.hi.FillTransparency=.72; s.hi.OutlineTransparency=.05
            else s.hi.Enabled=false end
            if S.Corner then drawCorners(s.box,tl,br,col) else for _,x in ipairs(s.box) do x.Visible=false end end
            if S.Box then
                setLine(s.full[1],Vector2.new(tl.X,tl.Y),Vector2.new(br.X,tl.Y),1,col,0)
                setLine(s.full[2],Vector2.new(br.X,tl.Y),Vector2.new(br.X,br.Y),1,col,0)
                setLine(s.full[3],Vector2.new(br.X,br.Y),Vector2.new(tl.X,br.Y),1,col,0)
                setLine(s.full[4],Vector2.new(tl.X,br.Y),Vector2.new(tl.X,tl.Y),1,col,0)
            else for _,x in ipairs(s.full) do x.Visible=false end end
            if S.Name or S.Distance then
                local text=""
                if S.Name then text=botName(model) end
                if S.Distance then text=text..(text~="" and "  " or "").."["..math.floor(dist).."]" end
                s.name.Text=text; s.name.Position=UDim2.fromOffset(mid.X-110,tl.Y-18); s.name.Visible=true
            else s.name.Visible=false end
            if S.HealthBar and hum then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                s.healthBack.Position=UDim2.fromOffset(br.X+4,tl.Y); s.healthBack.Size=UDim2.fromOffset(4,h); s.healthBack.Visible=true
                s.health.Position=UDim2.fromOffset(br.X+5,tl.Y+1+(h-2)*(1-ratio)); s.health.Size=UDim2.fromOffset(2,(h-2)*ratio); s.health.BackgroundColor3=Color3.fromHSV(ratio*.33,.75,1); s.health.Visible=true
            else s.healthBack.Visible=false; s.health.Visible=false end
            if S.Lines then setLine(s.tracer,Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y),Vector2.new(mid.X,br.Y),1,col,.1) else s.tracer.Visible=false end
        end
    end
end)

-- Vehicle ESP uses one lightweight scan of Workspace.Vehicles and ChildAdded.
local vehicleLabels=setmetatable({}, {__mode="k"})
local function addVehicle(v)
    if not v or not v:IsA("Model") or vehicleLabels[v] then return end
    local tag=Instance.new("BillboardGui"); tag.Name="GunTestingLiteCarESP"; tag.Size=UDim2.fromOffset(160,26); tag.AlwaysOnTop=true; tag.Enabled=false
    local adornee=v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart",true); if not adornee then return end
    tag.Adornee=adornee; tag.Parent=parent
    local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Font=Enum.Font.Code; t.TextSize=12; t.TextColor3=Color3.fromRGB(180,210,255); t.TextStrokeTransparency=0; t.Text=v.Name; t.Parent=tag
    vehicleLabels[v]=tag
end
local vehicles=Workspace:FindFirstChild("Vehicles")
if vehicles then for _,v in ipairs(vehicles:GetChildren()) do addVehicle(v) end; vehicles.ChildAdded:Connect(addVehicle) end
RunService.Heartbeat:Connect(function()
    for v,g in pairs(vehicleLabels) do
        if not v.Parent then pcall(function() g:Destroy() end); vehicleLabels[v]=nil else g.Enabled=S.CarESP end
    end
end)

print("[GunTestingLite] loaded")
