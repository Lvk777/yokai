-- Final UI/visual polish for the synthetic Yokai test target only.
-- Target-oriented rendering in this file never inspects or modifies real Player characters.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary and shared.YokaiSafeTargetVisualState

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec.Api
if not Visuals then return end

local visual = shared.YokaiSafeTargetVisualState
local espState = shared.YokaiSafeESPFinalState
local ZWSP = utf8.char(0x200B)

local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isDescendantRecord(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end

local function removeVisualOptionDeep(name)
    local targets = {}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isDescendantRecord(rec,VisualsRec) then
            table.insert(targets,{key=key,rec=rec})
        end
    end
    for _,target in ipairs(targets) do
        local childKeys={}
        for key,rec in pairs(objects) do
            if key~=target.key and rec and rec.Object and isDescendantRecord(rec,target.rec) then table.insert(childKeys,key) end
        end
        for _,key in ipairs(childKeys) do pcall(function() GuiLibrary["RemoveObject"](key) end) end
        pcall(function()
            local api=target.rec.Api
            if api and api.Enabled and api.ToggleButton then api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](target.key) end)
    end
end

local function roots()
    local t={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(t,gethui()) end end)
    return t
end
local function destroyNamed(name)
    for _,root in ipairs(roots()) do
        if root then
            local old=root:FindFirstChild(name,true)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end
local function newOverlay(name, order)
    destroyNamed(name)
    local g=Instance.new("ScreenGui")
    g.Name=name
    g.ResetOnSpawn=false
    g.IgnoreGuiInset=true
    g.DisplayOrder=order
    pcall(function() g.Parent=(gethui and gethui()) or CoreGui end)
    if not g.Parent then g.Parent=LocalPlayer:WaitForChild("PlayerGui") end
    return g
end
local function getTarget() return Workspace:FindFirstChild("YokaiSafeVisualTestTarget") end

local function bounds2D(model)
    local cam=Workspace.CurrentCamera
    if not cam or not model then return nil end
    local cf,size=model:GetBoundingBox()
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        if p.Z>0 then
            any=true
            minX=math.min(minX,p.X) minY=math.min(minY,p.Y)
            maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y)
        end
    end end end
    if not any or maxX<0 or maxY<0 or minX>cam.ViewportSize.X or minY>cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function wallVisible(target, part)
    local cam=Workspace.CurrentCamera
    if not cam or not target or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
end
local function lerp(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end

-- ---------------------------------------------------------------------------
-- Startup sidebar state: windows start closed AND their sidebar labels start neutral.
-- ---------------------------------------------------------------------------
local function accentColor()
    local rec=objects["Gui ColorSliderColor"]
    local api=rec and rec.Api
    if api and api.Hue~=nil then return Color3.fromHSV(api.Hue,api.Sat or 1,api.Value or 1) end
    return Color3.fromRGB(45,132,235)
end
local function paintSidebarButton(obj, selected, expectedText)
    if not obj or typeof(obj)~="Instance" then return end
    local on=accentColor()
    local off=Color3.fromRGB(162,162,162)
    local function paint(node)
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            if not expectedText or node.Text==expectedText then node.TextColor3=selected and on or off end
        elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
            local n=node.Name:lower()
            if n:find("icon",1,true) or n:find("image",1,true) then node.ImageColor3=selected and on or off end
        end
    end
    paint(obj)
    for _,d in ipairs(obj:GetDescendants()) do paint(d) end
end
local function neutralizeStartup()
    for _,name in ipairs({"Combat","Movement","Render","Utility","World","Friends","Profiles"}) do
        local win=objects[name.."Window"] and objects[name.."Window"].Api
        if win and win.SetVisible then pcall(function() win.SetVisible(false) end) end
        local b=objects[name.."Button"] and objects[name.."Button"].Object
        paintSidebarButton(b,false,name)
    end
    local vwin=objects["VisualsWindow"] and objects["VisualsWindow"].Api
    if vwin and vwin.SetVisible then pcall(function() vwin.SetVisible(false) end) end
    local main=GuiLibrary.MainGui
    if main then
        local vb=main:FindFirstChild("VisualsIndependentButton",true)
        if vb then paintSidebarButton(vb,false,"Visuals") end
    end
end
task.defer(function() task.wait(.65) neutralizeStartup() end)

-- ---------------------------------------------------------------------------
-- Distance: one clean config group at the bottom, directly after Tracers.
-- Old orphan slider/config children are removed together with the old group.
-- ---------------------------------------------------------------------------
removeVisualOptionDeep("Distance")
local globalDistance=shared.YokaiTargetVisualDistance or 300
local Distance=Visuals.CreateOptionsButton({
    ["Name"]="Distance",
    ["Function"]=function() end,
    ["HoverText"]="Global draw distance for the synthetic target visuals.",
})
local DistanceSlider=Distance.CreateSlider({
    ["Name"]="Max Distance",
    ["Min"]=25,
    ["Max"]=1000,
    ["Default"]=math.clamp(globalDistance,25,1000),
    ["Function"]=function(v)
        globalDistance=v
        shared.YokaiTargetVisualDistance=v
    end,
})
task.defer(function()
    task.wait(.05)
    local drec
    local trec
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and isDescendantRecord(rec,VisualsRec) then
            local n=optionName(key)
            if n=="Distance" then drec=rec elseif n=="Tracers" then trec=rec end
        end
    end
    if drec and drec.Object and drec.Object:IsA("GuiObject") then
        local order=(trec and trec.Object and trec.Object.LayoutOrder or 9000)+1
        drec.Object.LayoutOrder=order
        if DistanceSlider and DistanceSlider.Object and DistanceSlider.Object:IsA("GuiObject") then DistanceSlider.Object.LayoutOrder=order+1 end
        -- catch the saved slider object too, because some Yokai builds wrap the returned API.
        for _,rec in pairs(objects) do
            if rec and rec.Type=="Slider" and isDescendantRecord(rec,drec) and rec.Object and rec.Object:IsA("GuiObject") then rec.Object.LayoutOrder=order+1 end
        end
    end
end)

-- Keep the target visual layers on the same distance value.
RunService:BindToRenderStep("YokaiGlobalVisualDistanceV4",Enum.RenderPriority.Last.Value+55,function()
    visual.MaxDistance=globalDistance
    if espState then espState.MaxDistance=globalDistance end
end)

-- ---------------------------------------------------------------------------
-- Remove Thermal Corner completely.
-- ---------------------------------------------------------------------------
removeVisualOptionDeep("Thermal Corner")
for _,name in ipairs({"YokaiSafeThermalCornerV3","YokaiSafeThermalCornerV2"}) do destroyNamed(name) end

-- ---------------------------------------------------------------------------
-- Corner Box: exact supplied look on the synthetic target.
-- Normal: black 0.75 fill + white 1px corners.
-- WallCheck occluded: soft red fill + red corners.
-- ---------------------------------------------------------------------------
removeVisualOptionDeep("Corner Box")
visual.Corner=false
for _,name in ipairs({"YokaiSafeCornerBoxV2","YokaiSafeCornerBoxV3","YokaiSafeCornerBoxV4"}) do destroyNamed(name) end
local cornerEnabled=false
local CornerBox=Visuals.CreateOptionsButton({
    ["Name"]="Corner Box",
    ["Function"]=function(v) cornerEnabled=v visual.Corner=false end,
    ["HoverText"]="Black filled corner box with WallCheck color response on the synthetic target.",
})
local cornerOverlay=newOverlay("YokaiSafeCornerBoxV4",1012)
local cornerFill=Instance.new("Frame")
cornerFill.BorderSizePixel=0
cornerFill.BackgroundColor3=Color3.new(0,0,0)
cornerFill.BackgroundTransparency=.75
cornerFill.Visible=false
cornerFill.Parent=cornerOverlay
local cornerLines={}
for i=1,8 do
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=Color3.new(1,1,1)
    f.Visible=false
    f.Parent=cornerOverlay
    cornerLines[i]=f
end
local function setLine(f,a,b,color)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color
    f.Visible=true
end
local function hideCorner()
    cornerFill.Visible=false
    for _,f in ipairs(cornerLines) do f.Visible=false end
end
local function drawCorner(tl,br,lineColor,fillColor,fillTransparency)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(5,w/5),math.max(5,h/5)
    cornerFill.Position=UDim2.fromOffset(l,t)
    cornerFill.Size=UDim2.fromOffset(w,h)
    cornerFill.BackgroundColor3=fillColor
    cornerFill.BackgroundTransparency=fillTransparency
    cornerFill.Visible=true
    local s={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(s) do setLine(cornerLines[i],v[1],v[2],lineColor) end
end

-- ---------------------------------------------------------------------------
-- Chams: rebuilt from the supplied thermal Highlight style, but only for the dummy.
-- ---------------------------------------------------------------------------
removeVisualOptionDeep("Chams")
visual.Chams=false
local chamsEnabled=false
local chamsThermal=true
local chamsFill=Color3.fromRGB(119,120,255)
local chamsOutline=Color3.fromRGB(119,120,255)
local chamsFillTransparency=.55
local chamsOutlineTransparency=.12
local Chams=Visuals.CreateOptionsButton({
    ["Name"]="Chams",
    ["Function"]=function(v) chamsEnabled=v visual.Chams=false end,
    ["HoverText"]="Thermal Highlight styling for the synthetic target.",
})
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) chamsThermal=v end})
Chams.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) chamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) chamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=55,["Function"]=function(v) chamsFillTransparency=v/100 end})
Chams.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=12,["Function"]=function(v) chamsOutlineTransparency=v/100 end})
local oldChams=Workspace:FindFirstChild("YokaiSafeChamsV3",true)
if oldChams then pcall(function() oldChams:Destroy() end) end
local chams=Instance.new("Highlight")
chams.Name="YokaiSafeChamsV4"
chams.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
chams.Enabled=false
chams.Parent=Workspace

-- ---------------------------------------------------------------------------
-- Standalone HealthBar: rebuilt on the RIGHT side and kept independent from ESP HealthBar.
-- ---------------------------------------------------------------------------
removeVisualOptionDeep("HealthBar")
visual.Health=false
for _,name in ipairs({"YokaiSafeStandaloneHealthV3","YokaiSafeStandaloneHealthV4"}) do destroyNamed(name) end
local healthEnabled=false
local healthTextEnabled=true
local healthPalette="Blue / Red"
local HealthBar=Visuals.CreateOptionsButton({
    ["Name"]="HealthBar",
    ["Function"]=function(v) healthEnabled=v visual.Health=false end,
})
HealthBar.CreateDropdown({["Name"]="Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) healthPalette=v end})
HealthBar.CreateToggle({["Name"]="HealthText",["Default"]=true,["Function"]=function(v) healthTextEnabled=v end})
local healthOverlay=newOverlay("YokaiSafeStandaloneHealthV4",1013)
local healthBack=Instance.new("Frame") healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Visible=false healthBack.Parent=healthOverlay
local healthFill=Instance.new("Frame") healthFill.BorderSizePixel=0 healthFill.BackgroundColor3=Color3.new(1,1,1) healthFill.Visible=false healthFill.Parent=healthOverlay
local healthGrad=Instance.new("UIGradient") healthGrad.Rotation=90 healthGrad.Parent=healthFill
local healthText=Instance.new("TextLabel")
healthText.BackgroundTransparency=1 healthText.AnchorPoint=Vector2.new(.5,.5) healthText.Size=UDim2.fromOffset(42,16)
healthText.Font=Enum.Font.Code healthText.TextSize=11 healthText.TextStrokeTransparency=0 healthText.TextStrokeColor3=Color3.new(0,0,0)
healthText.TextColor3=Color3.new(1,1,1) healthText.Visible=false healthText.Parent=healthOverlay
local function healthSequence()
    if healthPalette=="Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55)),
        })
    end
    return ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(50,110,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(220,40,50))})
end

-- ---------------------------------------------------------------------------
-- Runtime for Corner, Chams and HealthBar.
-- ---------------------------------------------------------------------------
RunService:BindToRenderStep("YokaiSafeVisualPolishV4",Enum.RenderPriority.Last.Value+70,function()
    local target=getTarget()
    local cam=Workspace.CurrentCamera
    if not target or not cam then
        hideCorner() chams.Enabled=false healthBack.Visible=false healthFill.Visible=false healthText.Visible=false
        return
    end
    local hum=target:FindFirstChildOfClass("Humanoid")
    local root=target:FindFirstChild("HumanoidRootPart")
    local head=target:FindFirstChild("Head") or root
    if not hum or not root or hum.Health<=0 then
        hideCorner() chams.Enabled=false healthBack.Visible=false healthFill.Visible=false healthText.Visible=false
        return
    end
    local dist=(cam.CFrame.Position-root.Position).Magnitude
    local tl,br=bounds2D(target)
    if dist>globalDistance or not tl then
        hideCorner() chams.Enabled=false healthBack.Visible=false healthFill.Visible=false healthText.Visible=false
        return
    end

    local occluded=false
    if espState and espState.WallCheck then occluded=not wallVisible(target,head) end
    local occludedBase=(espState and espState.OccludedColor) or Color3.fromRGB(245,55,55)
    local cleanRed=lerp(occludedBase,Color3.fromRGB(45,35,40),.38)

    if cornerEnabled then
        if occluded then drawCorner(tl,br,occludedBase,cleanRed,.80)
        else drawCorner(tl,br,Color3.new(1,1,1),Color3.new(0,0,0),.75) end
    else hideCorner() end

    if chamsEnabled then
        chams.Adornee=target
        chams.Enabled=true
        local thermalWave=(math.atan(math.sin(os.clock()*2))*2/math.pi+1)/2
        local baseFill=chamsFillTransparency
        local baseOutline=chamsOutlineTransparency
        if chamsThermal then
            baseFill=math.clamp(chamsFillTransparency + (thermalWave-.5)*.22,0,1)
            baseOutline=math.clamp(chamsOutlineTransparency + (thermalWave-.5)*.10,0,1)
        end
        if occluded then
            chams.FillColor=cleanRed
            chams.OutlineColor=occludedBase
            chams.FillTransparency=math.clamp(baseFill+.08,0,1)
            chams.OutlineTransparency=baseOutline
        else
            chams.FillColor=chamsFill
            chams.OutlineColor=chamsOutline
            chams.FillTransparency=baseFill
            chams.OutlineTransparency=baseOutline
        end
    else chams.Enabled=false end

    if healthEnabled then
        local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
        local h=math.max(4,br.Y-tl.Y)
        local x=br.X+8
        healthBack.Position=UDim2.fromOffset(x,tl.Y)
        healthBack.Size=UDim2.fromOffset(4,h)
        healthBack.Visible=true
        healthFill.Position=UDim2.fromOffset(x+1,tl.Y+1+(h-2)*(1-ratio))
        healthFill.Size=UDim2.fromOffset(2,(h-2)*ratio)
        healthGrad.Color=healthSequence()
        healthFill.Visible=true
        healthText.Position=UDim2.fromOffset(x+20,tl.Y+h*(1-ratio))
        healthText.Text=tostring(math.floor(hum.Health))
        healthText.Visible=healthTextEnabled
    else
        healthBack.Visible=false healthFill.Visible=false healthText.Visible=false
    end
end)

-- ---------------------------------------------------------------------------
-- Original arrows: smaller/thinner, with a slightly larger visual ring only.
-- Enemy distance/visibility logic from the original module is not changed.
-- ---------------------------------------------------------------------------
local ARROW_SIZE=105
local ARROW_SPREAD=1.28
local arrowCache=setmetatable({}, {__mode="k"})
local function arrowFolder()
    local main=GuiLibrary.MainGui
    return main and main:FindFirstChild("ArrowsFolder",true)
end
local function adjustArrow(obj)
    if not obj:IsA("ImageLabel") then return end
    obj.Size=UDim2.fromOffset(ARROW_SIZE,ARROW_SIZE)
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    local p=obj.Position
    local cur=Vector2.new(p.X.Scale*vp.X+p.X.Offset,p.Y.Scale*vp.Y+p.Y.Offset)
    local cached=arrowCache[obj]
    local base=cur
    if cached and (cur-cached.applied).Magnitude<1 then base=cached.base end
    local center=vp/2
    local applied=center+(base-center)*ARROW_SPREAD
    arrowCache[obj]={base=base,applied=applied}
    obj.Position=UDim2.fromOffset(applied.X,applied.Y)
end
RunService:BindToRenderStep("YokaiArrowRingPolishV4",Enum.RenderPriority.Last.Value+80,function()
    local folder=arrowFolder()
    if not folder then return end
    for _,obj in ipairs(folder:GetChildren()) do adjustArrow(obj) end
end)
