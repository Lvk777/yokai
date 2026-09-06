-- Preserved local extras for the restored Gun Testing V3 baseline.
-- Optimized revision: no permanent per-frame work while a feature is disabled.
-- Features kept: FullBrightness, animated Crosshair, FPS Boost, Menu Optimizer, Car ESP.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local CoreGui=game:GetService("CoreGui")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec=objects.VisualsWindow
local UtilityRec=objects.UtilityWindow
local Visuals=VisualsRec and VisualsRec.Api
local Utility=UtilityRec and UtilityRec.Api
if not (Visuals and Utility) then return end

local ZWSP=utf8.char(0x200B)
local function unique(name,n) return name..string.rep(ZWSP,n or 1) end

-- ==========================================================================
-- FULL BRIGHTNESS: one ColorCorrectionEffect, no day/night loop.
-- ==========================================================================
local brightnessEnabled=false
local brightnessStrength=65
local oldCC=Lighting:FindFirstChild("YokaiPreservedBrightnessV15")
if oldCC then oldCC:Destroy() end
local cc=Instance.new("ColorCorrectionEffect")
cc.Name="YokaiPreservedBrightnessV15"
cc.Enabled=false
cc.Parent=Lighting
local function applyBrightness()
    cc.Enabled=brightnessEnabled
    if brightnessEnabled then
        local s=brightnessStrength/100
        cc.Brightness=.08+.32*s
        cc.Contrast=-.02-.08*s
        cc.Saturation=.02+.05*s
    end
end
local Bright=Visuals.CreateOptionsButton({Name=unique("FullBrightness",1),Function=function(v) brightnessEnabled=v; applyBrightness() end,HoverText="Stable local brightness without fighting the map clock."})
Bright.CreateSlider({Name="Strength",Min=0,Max=100,Default=65,Function=function(v) brightnessStrength=v; applyBrightness() end})

-- ==========================================================================
-- ANIMATED CROSSHAIR: RenderStepped exists only while enabled.
-- ==========================================================================
local parentGui=(gethui and gethui()) or CoreGui
local oldHud=parentGui:FindFirstChild("YokaiPreservedCrosshairV15")
if oldHud then oldHud:Destroy() end
local Hud=Instance.new("ScreenGui")
Hud.Name="YokaiPreservedCrosshairV15"; Hud.ResetOnSpawn=false; Hud.IgnoreGuiInset=true; Hud.DisplayOrder=1002; Hud.Parent=parentGui
local Root=Instance.new("Frame")
Root.AnchorPoint=Vector2.new(.5,.5); Root.Size=UDim2.fromOffset(1,1); Root.BackgroundTransparency=1; Root.Visible=false; Root.Parent=Hud
local lines={}
for i=1,4 do local f=Instance.new("Frame"); f.Name="Line"..i; f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.Parent=Root; lines[i]=f end
local dot=Instance.new("Frame")
dot.Name="Dot"; dot.AnchorPoint=Vector2.new(.5,.5); dot.Size=UDim2.fromOffset(2,2); dot.BorderSizePixel=0; dot.Parent=Root
local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot

local crossEnabled=false
local crossAnimated=true
local crossGap=6
local crossLength=8
local crossThickness=1
local crossSpeed=5
local crossColor=Color3.fromRGB(205,225,255)
local hitUntil=0
local crossConn=nil

local function renderCross()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local c=cam.ViewportSize/2
    Root.Position=UDim2.fromOffset(c.X,c.Y)
    if not crossEnabled then return end
    local pulse=crossAnimated and math.sin(os.clock()*crossSpeed)*1.6 or 0
    local gap=math.max(1,crossGap+pulse)
    local len=math.max(2,crossLength+(crossAnimated and math.cos(os.clock()*crossSpeed*.75)*.7 or 0))
    local t=math.max(1,crossThickness)
    local col=os.clock()<hitUntil and Color3.fromRGB(255,70,70) or crossColor
    local spec={
        {UDim2.fromOffset(-(gap+len/2),0),UDim2.fromOffset(len,t)},
        {UDim2.fromOffset((gap+len/2),0),UDim2.fromOffset(len,t)},
        {UDim2.fromOffset(0,-(gap+len/2)),UDim2.fromOffset(t,len)},
        {UDim2.fromOffset(0,(gap+len/2)),UDim2.fromOffset(t,len)},
    }
    for i,f in ipairs(lines) do f.Position=spec[i][1]; f.Size=spec[i][2]; f.BackgroundColor3=col end
    dot.BackgroundColor3=col
end
local function setCrossEnabled(v)
    crossEnabled=v; Root.Visible=v
    if v and not crossConn then crossConn=RunService.RenderStepped:Connect(renderCross)
    elseif not v and crossConn then crossConn:Disconnect(); crossConn=nil end
end
local Cross=Visuals.CreateOptionsButton({Name=unique("Custom Crosshair",2),Function=setCrossEnabled})
Cross.CreateToggle({Name="Animated",Default=true,Function=function(v) crossAnimated=v end})
Cross.CreateSlider({Name="Gap",Min=2,Max=20,Default=6,Function=function(v) crossGap=v end})
Cross.CreateSlider({Name="Length",Min=4,Max=24,Default=8,Function=function(v) crossLength=v end})
Cross.CreateSlider({Name="Thickness",Min=1,Max=4,Default=1,Function=function(v) crossThickness=v end})
Cross.CreateSlider({Name="Animation Speed",Min=1,Max=12,Default=5,Function=function(v) crossSpeed=v end})
Cross.CreateColorSlider({Name="Color",Function=function(h,s,v) crossColor=Color3.fromHSV(h,s,v) end})

task.spawn(function()
    local ok,plugin=pcall(function()
        local ps=LocalPlayer:WaitForChild("PlayerScripts",8)
        local gc=ps and ps:WaitForChild("GunController",8)
        local ev=gc and gc:WaitForChild("Events",8)
        local mod=ev and ev:WaitForChild("GunPlugin",8)
        return mod and require(mod)
    end)
    if ok and type(plugin)=="table" and type(plugin.OnHitmarker)=="function" then
        local ok2,sig=pcall(function() return plugin:OnHitmarker() end)
        if ok2 and sig and type(sig.Connect)=="function" then sig:Connect(function() hitUntil=os.clock()+.22 end) end
    end
end)

-- ==========================================================================
-- FPS BOOST: one chunked scan when enabled + incremental new-object handling.
-- ==========================================================================
local fpsEnabled=false
local fpsMode="Balanced"
local originals=setmetatable({}, {__mode="k"})
local function save(obj,prop)
    originals[obj]=originals[obj] or {}
    if originals[obj][prop]==nil then pcall(function() originals[obj][prop]=obj[prop] end) end
end
local function optimizeObject(obj)
    if not fpsEnabled then return end
    if obj:IsA("PostEffect") and obj~=cc then save(obj,"Enabled"); obj.Enabled=false
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then save(obj,"Enabled"); obj.Enabled=false
    elseif fpsMode=="Aggressive" and (obj:IsA("Decal") or obj:IsA("Texture")) then save(obj,"Transparency"); obj.Transparency=1 end
end
local function restoreFPS()
    for obj,props in pairs(originals) do
        if obj and obj.Parent then for prop,val in pairs(props) do pcall(function() obj[prop]=val end) end end
    end
    table.clear(originals)
end
local scanGeneration=0
local function applyFPS()
    scanGeneration+=1
    local myGen=scanGeneration
    if not fpsEnabled then restoreFPS(); return end
    if fpsMode~="Light" then save(Lighting,"GlobalShadows"); Lighting.GlobalShadows=false end
    task.spawn(function()
        local all=Workspace:GetDescendants()
        for i,obj in ipairs(all) do
            if myGen~=scanGeneration or not fpsEnabled then return end
            optimizeObject(obj)
            if i%600==0 then task.wait() end
        end
        for _,obj in ipairs(Lighting:GetChildren()) do if myGen==scanGeneration and fpsEnabled then optimizeObject(obj) end end
    end)
end
local FPS=Utility.CreateOptionsButton({Name=unique("FPS Boost",3),Function=function(v) fpsEnabled=v; applyFPS() end})
FPS.CreateDropdown({Name="Mode",List={"Light","Balanced","Aggressive"},Function=function(v) fpsMode=v; if fpsEnabled then restoreFPS(); applyFPS() end end})
Workspace.DescendantAdded:Connect(function(obj) if fpsEnabled then task.defer(optimizeObject,obj) end end)
Lighting.ChildAdded:Connect(function(obj) if fpsEnabled then task.defer(optimizeObject,obj) end end)

-- ==========================================================================
-- MENU OPTIMIZER: decorative-only; no buttons/functions are deleted.
-- ==========================================================================
local menuEnabled=false
local menuSaved=setmetatable({}, {__mode="k"})
local function decorativeGui(d)
    if not d:IsA("GuiObject") then return false end
    local n=d.Name:lower()
    return n:find("shadow",1,true)~=nil or n:find("blur",1,true)~=nil or n:find("glow",1,true)~=nil
end
local function handleMenuObject(d)
    if menuEnabled and decorativeGui(d) and menuSaved[d]==nil then menuSaved[d]=d.Visible; d.Visible=false end
end
local function optimizeMenu(v)
    menuEnabled=v
    local root=GuiLibrary.MainGui
    if not root then return end
    if v then
        for _,d in ipairs(root:GetDescendants()) do handleMenuObject(d) end
    else
        for d,val in pairs(menuSaved) do if d and d.Parent then pcall(function() d.Visible=val end) end end
        table.clear(menuSaved)
    end
end
Utility.CreateOptionsButton({Name=unique("Menu Optimizer",4),Function=optimizeMenu,HoverText="Disables decorative shadows/glows only; keeps all controls and callbacks."})
if GuiLibrary.MainGui then GuiLibrary.MainGui.DescendantAdded:Connect(function(d) if menuEnabled then task.defer(handleMenuObject,d) end end) end

-- ==========================================================================
-- CAR ESP: event-driven vehicle registration + 5 Hz updates while enabled only.
-- ==========================================================================
local carEnabled=false
local carColor=Color3.fromRGB(60,220,180)
local carDistance=2500
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
local function anchor(m) return m:FindFirstChildWhichIsA("VehicleSeat",true) or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true) end
local function addCar(m)
    if cars[m] or not isVehicle(m) then return end
    local a=anchor(m); if not a then return end
    local h=Instance.new("Highlight"); h.Name="YokaiPreservedCarESP"; h.Adornee=m; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.FillTransparency=.86; h.OutlineTransparency=.08; h.Enabled=false; h.Parent=m
    local bb=Instance.new("BillboardGui"); bb.Name="YokaiPreservedCarLabel"; bb.Adornee=a; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(180,28); bb.StudsOffsetWorldSpace=Vector3.new(0,3,0); bb.Enabled=false; bb.Parent=a
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
            local show=carEnabled and dist<=carDistance
            s.h.Enabled=show; s.bb.Enabled=show
            if show then
                s.h.FillColor=carColor; s.h.OutlineColor=carColor; s.t.TextColor3=carColor
                s.t.Text=string.format("%s  •  %d studs",m.Name:gsub("_"," "),math.floor(dist+.5))
            end
        end
    end
end
local function setCarEnabled(v)
    carEnabled=v; carLoopToken+=1
    local token=carLoopToken
    if not v then updateCarsOnce(); return end
    task.spawn(function()
        while carEnabled and token==carLoopToken and shared.YokaiExecuted~=false do
            if not vehicles then attachVehiclesFolder(Workspace:FindFirstChild("Vehicles")) end
            updateCarsOnce()
            task.wait(.20)
        end
    end)
end
local Car=Visuals.CreateOptionsButton({Name=unique("Car ESP",5),Function=setCarEnabled})
Car.CreateColorSlider({Name="Color",Function=function(h,s,v) carColor=Color3.fromHSV(h,s,v) end})
Car.CreateSlider({Name="Distance",Min=100,Max=5000,Default=2500,Function=function(v) carDistance=v end})

shared.YokaiPreservedLocalExtrasV15=true
