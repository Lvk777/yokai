-- Final synthetic-target visual UX layer.
-- Only renders YokaiSafeVisualTestTarget; never inspects or targets other players.

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
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function findVisualOption(name)
    local found
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then found=rec end
    end
    return found
end
local function removeVisualOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end
local function guiRoots()
    local roots={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(roots,gethui()) end end)
    return roots
end
local function findGui(name)
    for _,root in ipairs(guiRoots()) do
        if root then
            local g=root:FindFirstChild(name,true)
            if g then return g end
        end
    end
end
local function getTarget() return Workspace:FindFirstChild("YokaiSafeVisualTestTarget") end
local function getCamera() return Workspace.CurrentCamera end

local function closeFeatureWindows()
    for _,key in ipairs({"CombatWindow","MovementWindow","RenderWindow","UtilityWindow","VisualsWindow","WorldWindow","FriendsWindow","ProfilesWindow"}) do
        local api=objects[key] and objects[key].Api
        if api and api.SetVisible then pcall(function() api.SetVisible(false) end) end
    end
end
task.defer(function() task.wait(.35) closeFeatureWindows() end)

local function newOverlay(name,order)
    for _,root in ipairs(guiRoots()) do
        if root then local old=root:FindFirstChild(name,true) if old then pcall(function() old:Destroy() end) end end
    end
    local g=Instance.new("ScreenGui")
    g.Name=name g.ResetOnSpawn=false g.IgnoreGuiInset=true g.DisplayOrder=order
    pcall(function() g.Parent=(gethui and gethui()) or CoreGui end)
    if not g.Parent then g.Parent=LocalPlayer:WaitForChild("PlayerGui") end
    return g
end
local function newLine(parent)
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5) f.BorderSizePixel=0 f.Visible=false f.Parent=parent
    return f
end
local function setLine(f,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color or Color3.new(1,1,1)
    f.BackgroundTransparency=transparency or 0
    f.Visible=true
end
local function hideLines(t) for _,v in ipairs(t) do v.Visible=false end end
local function bounds2D(model)
    local cam=getCamera() if not cam or not model then return nil end
    local cf,size=model:GetBoundingBox()
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
    end end end
    if not any or maxX<0 or maxY<0 or minX>cam.ViewportSize.X or minY>cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function wallVisible(target,part)
    local cam=getCamera() if not cam or not target or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
end
local function cornerSegments(tl,br)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(5,w/5),math.max(5,h/5)
    return {
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
end
local function drawCorners(lines,tl,br,color,thickness)
    for i,v in ipairs(cornerSegments(tl,br)) do setLine(lines[i],v[1],v[2],thickness or 1,color,0) end
end
local function seq2(a,b) return ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(1,b)}) end
local function seq3(a,b,c) return ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(.5,b),ColorSequenceKeypoint.new(1,c)}) end
local function lerpColor(a,b,t) return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end
local function blueRed() return seq2(Color3.fromRGB(50,110,255),Color3.fromRGB(220,40,50)) end
local function mintYellowRed()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),
        ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55)),
    })
end

-- Global visual distance. Clicking the row cycles useful presets; the three-dot menu keeps an exact slider.
local globalDistance=300
shared.YokaiTargetVisualDistance=globalDistance
removeVisualOption("Distance")
local distancePresets={100,200,300,500,750,1000}
local distanceBusy=false
local Distance
Distance=Visuals.CreateOptionsButton({
    ["Name"]="Distance",
    ["Function"]=function(v)
        if not v or distanceBusy then return end
        local nextValue=distancePresets[1]
        for _,p in ipairs(distancePresets) do if p>globalDistance then nextValue=p break end end
        globalDistance=nextValue
        shared.YokaiTargetVisualDistance=globalDistance
        pcall(function() GuiLibrary["CreateNotification"]("Distance",tostring(globalDistance).." studs",2) end)
        distanceBusy=true
        task.defer(function() pcall(function() Distance.ToggleButton(false) end) distanceBusy=false end)
    end,
    ["HoverText"]="Click to cycle distance presets; use the three dots for exact Max Distance.",
})
Distance.CreateSlider({["Name"]="Max Distance",["Min"]=25,["Max"]=1000,["Default"]=300,["Function"]=function(v) globalDistance=v shared.YokaiTargetVisualDistance=v end})
task.defer(function()
    task.wait(.05)
    local tr=findVisualOption("Tracers") local dr=findVisualOption("Distance")
    if tr and dr and tr.Object and dr.Object and tr.Object:IsA("GuiObject") and dr.Object:IsA("GuiObject") then dr.Object.LayoutOrder=tr.Object.LayoutOrder+1 end
end)

-- Standalone Corner Box: purple -> black gradient fill + white corners, matching the earlier supplied ESP pack.
removeVisualOption("Corner Box")
local cornerEnabled=false
local CornerBox=Visuals.CreateOptionsButton({["Name"]="Corner Box",["Function"]=function(v) cornerEnabled=v visual.Corner=false end})
local cornerOverlay=newOverlay("YokaiSafeCornerBoxV3",1003)
local cornerFill=Instance.new("Frame") cornerFill.BorderSizePixel=0 cornerFill.BackgroundColor3=Color3.new(1,1,1) cornerFill.BackgroundTransparency=.75 cornerFill.Visible=false cornerFill.Parent=cornerOverlay
local cornerGrad=Instance.new("UIGradient") cornerGrad.Color=seq2(Color3.fromRGB(119,120,255),Color3.fromRGB(0,0,0)) cornerGrad.Parent=cornerFill
local cornerLines={} for i=1,8 do cornerLines[i]=newLine(cornerOverlay) end

-- Thermal Corner: exact supplied thermal behavior: purple fill with breathing transparency 0.50 -> 0.80 and white corners.
removeVisualOption("Thermal Corner")
local thermalCornerEnabled=false
local ThermalCorner=Visuals.CreateOptionsButton({["Name"]="Thermal Corner",["Function"]=function(v) thermalCornerEnabled=v end})
local thermalOverlay=newOverlay("YokaiSafeThermalCornerV3",1004)
local thermalFill=Instance.new("Frame") thermalFill.BorderSizePixel=0 thermalFill.BackgroundColor3=Color3.fromRGB(119,120,255) thermalFill.Visible=false thermalFill.Parent=thermalOverlay
local thermalLines={} for i=1,8 do thermalLines[i]=newLine(thermalOverlay) end

-- Standalone HealthBar: independent from ESP and always on the right.
removeVisualOption("HealthBar")
visual.Health=false
local healthEnabled=false
local healthPalette="Blue / Red"
local healthTextEnabled=true
local HealthBar=Visuals.CreateOptionsButton({["Name"]="HealthBar",["Function"]=function(v) healthEnabled=v visual.Health=false end})
HealthBar.CreateDropdown({["Name"]="Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) healthPalette=v end})
HealthBar.CreateToggle({["Name"]="HealthText",["Default"]=true,["Function"]=function(v) healthTextEnabled=v end})
local healthOverlay=newOverlay("YokaiSafeStandaloneHealthV3",1005)
local healthBack=Instance.new("Frame") healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Visible=false healthBack.Parent=healthOverlay
local healthFill=Instance.new("Frame") healthFill.BorderSizePixel=0 healthFill.BackgroundColor3=Color3.new(1,1,1) healthFill.Visible=false healthFill.Parent=healthOverlay
local healthGrad=Instance.new("UIGradient") healthGrad.Rotation=90 healthGrad.Parent=healthFill
local healthText=Instance.new("TextLabel") healthText.BackgroundTransparency=1 healthText.AnchorPoint=Vector2.new(.5,.5) healthText.Size=UDim2.fromOffset(42,16) healthText.Font=Enum.Font.Code healthText.TextSize=11 healthText.TextStrokeTransparency=0 healthText.TextStrokeColor3=Color3.new(0,0,0) healthText.TextColor3=Color3.new(1,1,1) healthText.Visible=false healthText.Parent=healthOverlay

-- Chams rebuilt for the synthetic target so it cannot be overwritten by older layers.
removeVisualOption("Chams")
visual.Chams=false
local chamsEnabled=false
local chamsFill=Color3.fromRGB(119,120,255)
local chamsOutline=Color3.fromRGB(255,255,255)
local chamsFillTransparency=.72
local chamsOutlineTransparency=0
local Chams=Visuals.CreateOptionsButton({["Name"]="Chams",["Function"]=function(v) chamsEnabled=v visual.Chams=false end})
Chams.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) chamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) chamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=72,["Function"]=function(v) chamsFillTransparency=v/100 end})
Chams.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=0,["Function"]=function(v) chamsOutlineTransparency=v/100 end})
local chamsHighlight=Instance.new("Highlight") chamsHighlight.Name="YokaiSafeChamsV3" chamsHighlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop chamsHighlight.Enabled=false chamsHighlight.Parent=Workspace

-- ESP final overlay helpers. Keep ESP modes as a rectangle gradient, not body recoloring.
local espOverlay=findGui("YokaiSafeESPFinalOverlay")
local espModeFill=nil
local espModeGrad=nil
local oldEspCorners={}
local espHealth=nil
local espHealthBack=nil
if espOverlay then
    for _,obj in ipairs(espOverlay:GetChildren()) do
        if obj:IsA("Frame") then
            if obj.AnchorPoint==Vector2.new(.5,.5) then table.insert(oldEspCorners,obj) end
            local grad=obj:FindFirstChildOfClass("UIGradient")
            if grad and not espHealth then espHealth=obj end
            if not grad and obj.AnchorPoint~=Vector2.new(.5,.5) and obj.BackgroundColor3==Color3.new(0,0,0) and not espHealthBack then espHealthBack=obj end
        end
    end
end
local espUxOverlay=newOverlay("YokaiSafeESPVisualUXV3",1006)
espModeFill=Instance.new("Frame") espModeFill.BorderSizePixel=0 espModeFill.BackgroundColor3=Color3.new(1,1,1) espModeFill.Visible=false espModeFill.Parent=espUxOverlay
espModeGrad=Instance.new("UIGradient") espModeGrad.Parent=espModeFill
local espCornerLines={} for i=1,8 do espCornerLines[i]=newLine(espUxOverlay) end

local function disableBodyGradient(target)
    if not target then return end
    for _,obj in ipairs(target:GetDescendants()) do
        if obj:IsA("BoxHandleAdornment") and (obj.Name=="YokaiSafeESPFinalGradientAdornment" or obj.Name=="YokaiSafeGradientAdornment") then obj.Visible=false end
    end
end
local function applyEspGradient()
    if not espState then return end
    local mode=espState.ColorMode or "Solid"
    if mode=="Rainbow" then
        local h=(os.clock()*math.max(.01,espState.RainbowSpeed or .08))%1
        espModeGrad.Color=seq3(Color3.fromHSV(h,.48,1),Color3.fromHSV((h+.10)%1,.50,1),Color3.fromHSV((h+.20)%1,.48,1))
        espModeGrad.Rotation=0
    elseif mode=="Thermal" then
        local a=espState.ThermalA or Color3.fromRGB(70,190,255)
        local b=espState.ThermalB or Color3.fromRGB(255,105,90)
        local wave=(math.sin(os.clock()*math.max(.01,espState.ThermalSpeed or .16)*math.pi*2)+1)/2
        espModeGrad.Color=seq3(a,lerpColor(a,b,wave),b)
        espModeGrad.Rotation=(os.clock()*math.max(.01,espState.ThermalSpeed or .16)*90)%360
    elseif mode=="Health Gradient" then
        espModeGrad.Color=(espState.HealthPalette=="Mint / Yellow / Red") and mintYellowRed() or blueRed()
        espModeGrad.Rotation=90
    else
        local c=espState.SolidColor or Color3.fromRGB(119,120,255)
        espModeGrad.Color=seq2(c,c) espModeGrad.Rotation=0
    end
end

local function hideOwned()
    cornerFill.Visible=false hideLines(cornerLines)
    thermalFill.Visible=false hideLines(thermalLines)
    healthBack.Visible=false healthFill.Visible=false healthText.Visible=false
    chamsHighlight.Enabled=false
    espModeFill.Visible=false hideLines(espCornerLines)
end

pcall(function() RunService:UnbindFromRenderStep("YokaiSafeVisualUXV2") end)
RunService:BindToRenderStep("YokaiSafeVisualUXV2",Enum.RenderPriority.Last.Value+40,function()
    visual.ESP=false visual.Corner=false visual.Health=false visual.Chams=false
    visual.MaxDistance=globalDistance
    if espState then espState.MaxDistance=globalDistance end

    local target=getTarget() local cam=getCamera()
    if not target or not cam then hideOwned() return end
    local root=target:FindFirstChild("HumanoidRootPart")
    local head=target:FindFirstChild("Head") or root
    local hum=target:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then hideOwned() return end
    local dist=(cam.CFrame.Position-root.Position).Magnitude
    local tl,br=bounds2D(target)
    if not tl or dist>globalDistance then hideOwned() return end
    local visible=wallVisible(target,head)

    -- Disable every legacy target fill/corner/chams after they render.
    local legacyHighlight=Workspace:FindFirstChild("YokaiSafeTargetHighlight",true)
    if legacyHighlight and legacyHighlight:IsA("Highlight") then legacyHighlight.Enabled=false end
    for _,line in ipairs(oldEspCorners) do line.Visible=false end
    disableBodyGradient(target)

    -- Standalone Corner Box: purple/black animated gradient, white corners.
    if cornerEnabled then
        cornerFill.Position=UDim2.fromOffset(tl.X,tl.Y)
        cornerFill.Size=UDim2.fromOffset(br.X-tl.X,br.Y-tl.Y)
        cornerFill.BackgroundTransparency=.75
        cornerGrad.Color=seq2(Color3.fromRGB(119,120,255),Color3.fromRGB(0,0,0))
        cornerGrad.Rotation=(os.clock()*36)%360
        cornerFill.Visible=true
        drawCorners(cornerLines,tl,br,Color3.new(1,1,1),1)
    else cornerFill.Visible=false hideLines(cornerLines) end

    -- Thermal Corner: supplied breathing transparency effect.
    if thermalCornerEnabled then
        thermalFill.Position=UDim2.fromOffset(tl.X,tl.Y)
        thermalFill.Size=UDim2.fromOffset(br.X-tl.X,br.Y-tl.Y)
        local breathe=math.sin(os.clock()*2)
        thermalFill.BackgroundColor3=Color3.fromRGB(119,120,255)
        thermalFill.BackgroundTransparency=.5+(breathe+1)*.15
        thermalFill.Visible=true
        drawCorners(thermalLines,tl,br,Color3.new(1,1,1),1)
    else thermalFill.Visible=false hideLines(thermalLines) end

    -- Standalone HealthBar on the right; thinner than before.
    if healthEnabled then
        local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
        local h=math.max(4,br.Y-tl.Y)
        local offset=(espState and espState.Enabled and espState.Health) and 10 or 4
        healthBack.Position=UDim2.fromOffset(br.X+offset,tl.Y)
        healthBack.Size=UDim2.fromOffset(3,h)
        healthBack.Visible=true
        healthFill.Position=UDim2.fromOffset(br.X+offset,tl.Y+h*(1-ratio))
        healthFill.Size=UDim2.fromOffset(2,h*ratio)
        healthGrad.Color=(healthPalette=="Mint / Yellow / Red") and mintYellowRed() or blueRed()
        healthFill.Visible=true
        healthText.Position=UDim2.fromOffset(br.X+offset+13,tl.Y+h*(1-ratio))
        healthText.Text=tostring(math.floor(hum.Health))
        healthText.Visible=healthTextEnabled
    else healthBack.Visible=false healthFill.Visible=false healthText.Visible=false end

    -- Chams now works on the synthetic target. With ESP WallCheck ON, occluded = red; visible = ESP visible color.
    if chamsEnabled then
        chamsHighlight.Adornee=target chamsHighlight.Enabled=true
        if espState and espState.WallCheck then
            local wc=visible and espState.VisibleColor or espState.OccludedColor
            chamsHighlight.FillColor=wc chamsHighlight.OutlineColor=wc
        else
            chamsHighlight.FillColor=chamsFill chamsHighlight.OutlineColor=chamsOutline
        end
        chamsHighlight.FillTransparency=chamsFillTransparency
        chamsHighlight.OutlineTransparency=chamsOutlineTransparency
    else chamsHighlight.Enabled=false end

    -- ESP fill modes remain inside the 2D ESP rectangle; body parts never change color.
    if espState and espState.Enabled then
        local finalHighlight=Workspace:FindFirstChild("YokaiSafeESPFinalHighlight",true)
        if finalHighlight and finalHighlight:IsA("Highlight") then finalHighlight.FillTransparency=1 end
        espModeFill.Position=UDim2.fromOffset(tl.X,tl.Y)
        espModeFill.Size=UDim2.fromOffset(br.X-tl.X,br.Y-tl.Y)
        espModeFill.BackgroundTransparency=espState.FillTransparency or .72
        espModeFill.Visible=true
        applyEspGradient()
        if espState.Corners then
            local cc=espState.CornerColor or Color3.new(1,1,1)
            if espState.WallCheck and not visible then cc=espState.OccludedColor or Color3.fromRGB(245,55,55) end
            drawCorners(espCornerLines,tl,br,cc,espState.CornerThickness or 1)
        else hideLines(espCornerLines) end
    else espModeFill.Visible=false hideLines(espCornerLines) end

    -- Keep ESP HealthBar thin and on the right after its own renderer updates it.
    if espHealth then local s=espHealth.Size espHealth.Size=UDim2.new(s.X.Scale,2,s.Y.Scale,s.Y.Offset) end
    if espHealthBack then local s=espHealthBack.Size espHealthBack.Size=UDim2.new(s.X.Scale,3,s.Y.Scale,s.Y.Offset) end
end)
