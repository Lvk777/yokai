-- Final synthetic-target visual UX layer.
-- This file only renders YokaiSafeVisualTestTarget and never inspects other players.

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
    local obj=rec.Object
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (obj==root or obj:IsDescendantOf(root)) then return true end
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

-- ---------------------------------------------------------------------------
-- Startup: leave the sidebar visible but start every feature window closed.
-- Opening windows afterwards remains independent.
-- ---------------------------------------------------------------------------
local function closeFeatureWindows()
    for _,key in ipairs({
        "CombatWindow","MovementWindow","RenderWindow","UtilityWindow","VisualsWindow","WorldWindow","FriendsWindow","ProfilesWindow"
    }) do
        local rec=objects[key]
        local api=rec and rec.Api
        if api and api.SetVisible then pcall(function() api.SetVisible(false) end) end
    end
end
task.defer(function()
    task.wait(.35)
    closeFeatureWindows()
end)

-- ---------------------------------------------------------------------------
-- One global target-visual distance control.
-- ---------------------------------------------------------------------------
local globalDistance=300
local distanceEnabled=true
shared.YokaiTargetVisualDistance=globalDistance

removeVisualOption("Distance")
local Distance=Visuals.CreateOptionsButton({
    ["Name"]="Distance",
    ["Function"]=function(v) distanceEnabled=v end,
    ["HoverText"]="Global draw distance for synthetic-target Visuals.",
})
Distance.CreateSlider({
    ["Name"]="Max Distance",
    ["Min"]=25,
    ["Max"]=1000,
    ["Default"]=300,
    ["Function"]=function(v)
        globalDistance=v
        shared.YokaiTargetVisualDistance=v
    end,
})
task.defer(function()
    pcall(function() if Distance.ToggleButton then Distance.ToggleButton(true) end end)
    task.wait()
    local tracerRec=findVisualOption("Tracers")
    local distanceRec=findVisualOption("Distance")
    if tracerRec and distanceRec and tracerRec.Object and distanceRec.Object and tracerRec.Object:IsA("GuiObject") and distanceRec.Object:IsA("GuiObject") then
        local base=tracerRec.Object.LayoutOrder
        for _,rec in pairs(objects) do
            if rec and rec.Type=="OptionsButton" and rec~=distanceRec and isUnder(rec,VisualsRec) and rec.Object and rec.Object:IsA("GuiObject") and rec.Object.LayoutOrder>base then
                rec.Object.LayoutOrder=rec.Object.LayoutOrder+1
            end
        end
        distanceRec.Object.LayoutOrder=base+1
    end
end)

-- ---------------------------------------------------------------------------
-- Standalone Corner Box: exactly the attached-script look adapted to the dummy.
-- Black 0.75 fill, white 1px corners, corner lengths = 1/5 of box width/height.
-- ---------------------------------------------------------------------------
removeVisualOption("Corner Box")
local cornerEnabled=false
local CornerBox=Visuals.CreateOptionsButton({
    ["Name"]="Corner Box",
    ["Function"]=function(v)
        cornerEnabled=v
        visual.Corner=false -- legacy renderer stays off; this layer owns standalone Corner Box.
    end,
    ["HoverText"]="Attached-script Corner Box style: black fill + white corners.",
})

local cornerOverlay=Instance.new("ScreenGui")
cornerOverlay.Name="YokaiSafeCornerBoxV2"
cornerOverlay.ResetOnSpawn=false
cornerOverlay.IgnoreGuiInset=true
cornerOverlay.DisplayOrder=1002
pcall(function() cornerOverlay.Parent=(gethui and gethui()) or CoreGui end)
if not cornerOverlay.Parent then cornerOverlay.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local cornerFill=Instance.new("Frame")
cornerFill.Name="CornerFill"
cornerFill.BorderSizePixel=0
cornerFill.BackgroundColor3=Color3.fromRGB(0,0,0)
cornerFill.BackgroundTransparency=.75
cornerFill.Visible=false
cornerFill.Parent=cornerOverlay

local function newLine(parent)
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=Color3.fromRGB(255,255,255)
    f.Visible=false
    f.Parent=parent
    return f
end
local function setLine(line,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then line.Visible=false return end
    line.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3=color or Color3.new(1,1,1)
    line.BackgroundTransparency=transparency or 0
    line.Visible=true
end
local function hideLines(lines) for _,v in ipairs(lines) do v.Visible=false end end
local standaloneCorners={} for i=1,8 do standaloneCorners[i]=newLine(cornerOverlay) end

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
local function drawStandaloneCorner(tl,br)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(5,w/5),math.max(5,h/5)
    cornerFill.Position=UDim2.fromOffset(l,t)
    cornerFill.Size=UDim2.fromOffset(w,h)
    cornerFill.BackgroundColor3=Color3.fromRGB(0,0,0)
    cornerFill.BackgroundTransparency=.75
    cornerFill.Visible=true
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(standaloneCorners[i],v[1],v[2],1,Color3.new(1,1,1),0) end
end
local function hideStandaloneCorner()
    cornerFill.Visible=false
    hideLines(standaloneCorners)
end

-- Hide the legacy Corner Box objects permanently so only the attached-style renderer is visible.
local legacyOverlay=findGui("YokaiSafeTargetAllInOneOverlay")
local legacyCornerFill=nil
local legacyCornerLines={}
local legacyHealth=nil
local legacyHealthBack=nil
if legacyOverlay then
    local looseLines={}
    for _,obj in ipairs(legacyOverlay:GetChildren()) do
        if obj:IsA("Frame") then
            local grad=obj:FindFirstChildOfClass("UIGradient")
            if grad and obj.ZIndex==0 and not legacyCornerFill then
                legacyCornerFill=obj
            elseif grad and obj.ZIndex~=0 and not legacyHealth then
                legacyHealth=obj
            elseif not grad and obj.AnchorPoint==Vector2.new(.5,.5) then
                table.insert(looseLines,obj)
            elseif not grad and obj.BackgroundColor3==Color3.new(0,0,0) and not legacyHealthBack then
                legacyHealthBack=obj
            end
        end
    end
    for i=1,math.min(8,#looseLines) do legacyCornerLines[i]=looseLines[i] end
end

-- ---------------------------------------------------------------------------
-- ESP color modes: gradient fill INSIDE the ESP rectangle; never recolor body parts.
-- ---------------------------------------------------------------------------
local espOverlay=findGui("YokaiSafeESPFinalOverlay")
local espModeFill=nil
local espModeGradient=nil
local espHealth=nil
local espHealthBack=nil
if espOverlay then
    -- Capture the existing ESP health frame before creating the new gradient-fill frame.
    for _,obj in ipairs(espOverlay:GetChildren()) do
        if obj:IsA("Frame") then
            local grad=obj:FindFirstChildOfClass("UIGradient")
            if grad and not espHealth then espHealth=obj end
            if not grad and obj.BackgroundColor3==Color3.new(0,0,0) and not espHealthBack then espHealthBack=obj end
        end
    end
    espModeFill=Instance.new("Frame")
    espModeFill.Name="YokaiESPModeFillV2"
    espModeFill.BorderSizePixel=0
    espModeFill.BackgroundColor3=Color3.new(1,1,1)
    espModeFill.BackgroundTransparency=.72
    espModeFill.Visible=false
    espModeFill.ZIndex=0
    espModeFill.Parent=espOverlay
    espModeGradient=Instance.new("UIGradient")
    espModeGradient.Name="YokaiESPModeGradientV2"
    espModeGradient.Parent=espModeFill
end

local function lerpColor(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
local function seq2(a,b)
    return ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(1,b)})
end
local function seq3(a,b,c)
    return ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(.5,b),ColorSequenceKeypoint.new(1,c)})
end
local function espPaletteSequence()
    if espState and espState.HealthPalette=="Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55)),
        })
    end
    return seq2(Color3.fromRGB(50,110,255),Color3.fromRGB(220,40,50))
end
local function applyModeGradient()
    if not espState or not espModeFill or not espModeGradient then return end
    local mode=espState.ColorMode or "Solid"
    if mode=="Rainbow" then
        local h=(os.clock()*math.max(.01,espState.RainbowSpeed or .08))%1
        local a=Color3.fromHSV(h,.48,1)
        local b=Color3.fromHSV((h+.10)%1,.52,1)
        local c=Color3.fromHSV((h+.20)%1,.48,1)
        espModeGradient.Color=seq3(a,b,c)
        espModeGradient.Rotation=0
    elseif mode=="Thermal" then
        local a=espState.ThermalA or Color3.fromRGB(70,190,255)
        local b=espState.ThermalB or Color3.fromRGB(255,105,90)
        local wave=(math.sin(os.clock()*math.max(.01,espState.ThermalSpeed or .16)*math.pi*2)+1)/2
        local mid=lerpColor(a,b,wave)
        espModeGradient.Color=seq3(a,mid,b)
        espModeGradient.Rotation=(os.clock()*math.max(.01,espState.ThermalSpeed or .16)*90)%360
    elseif mode=="Health Gradient" then
        espModeGradient.Color=espPaletteSequence()
        espModeGradient.Rotation=90
    else
        local c=espState.SolidColor or Color3.fromRGB(119,120,255)
        espModeGradient.Color=seq2(c,c)
        espModeGradient.Rotation=0
    end
end

local function findFinalHighlight()
    return Workspace:FindFirstChild("YokaiSafeESPFinalHighlight",true)
end
local function disableBodyGradient(target)
    if not target then return end
    for _,obj in ipairs(target:GetDescendants()) do
        if obj:IsA("BoxHandleAdornment") and (obj.Name=="YokaiSafeESPFinalGradientAdornment" or obj.Name=="YokaiSafeGradientAdornment") then
            obj.Visible=false
        end
    end
end

-- Slightly thinner standalone and ESP health bars.
local function setWidth(frame,width)
    if frame and frame:IsA("GuiObject") then
        local s=frame.Size
        frame.Size=UDim2.new(s.X.Scale,width,s.Y.Scale,s.Y.Offset)
    end
end

RunService:BindToRenderStep("YokaiSafeVisualUXV2",Enum.RenderPriority.Last.Value+20,function()
    visual.ESP=false
    local effectiveDistance=distanceEnabled and globalDistance or 1000000
    visual.MaxDistance=effectiveDistance
    if espState then espState.MaxDistance=effectiveDistance end

    -- Legacy standalone corner is never allowed to show.
    if legacyCornerFill then legacyCornerFill.Visible=false end
    for _,line in ipairs(legacyCornerLines) do line.Visible=false end

    -- Thin healthbars after older renderers have assigned their normal width.
    setWidth(legacyHealth,3)
    setWidth(legacyHealthBack,4)
    setWidth(espHealth,3)
    setWidth(espHealthBack,4)

    local target=getTarget()
    local cam=Workspace.CurrentCamera
    if not target or not cam then
        hideStandaloneCorner()
        if espModeFill then espModeFill.Visible=false end
        return
    end
    local root=target:FindFirstChild("HumanoidRootPart")
    local hum=target:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health<=0 then
        hideStandaloneCorner()
        if espModeFill then espModeFill.Visible=false end
        return
    end
    local dist=(cam.CFrame.Position-root.Position).Magnitude
    local tl,br=bounds2D(target)

    if cornerEnabled and dist<=effectiveDistance and tl then drawStandaloneCorner(tl,br) else hideStandaloneCorner() end

    if espState and espState.Enabled and dist<=effectiveDistance and tl and espModeFill then
        -- Keep Highlight outline/wallcheck, but never recolor the body itself.
        local h=findFinalHighlight()
        if h then h.FillTransparency=1 end
        disableBodyGradient(target)

        espModeFill.Position=UDim2.fromOffset(tl.X,tl.Y)
        espModeFill.Size=UDim2.fromOffset(br.X-tl.X,br.Y-tl.Y)
        espModeFill.BackgroundTransparency=espState.FillTransparency or .72
        espModeFill.Visible=true
        applyModeGradient()
    else
        if espModeFill then espModeFill.Visible=false end
        disableBodyGradient(target)
    end
end)
