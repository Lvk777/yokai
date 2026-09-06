-- Final synthetic-target ESP controller.
-- Applies ONLY to YokaiSafeVisualTestTarget. It never inspects or renders real players.

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

-- Keep the standalone Corner Box exactly on its previous palette and independent from ESP.
visual.CornerColor = Color3.new(1,1,1)
visual.CornerFill = Color3.fromRGB(119,120,255)
visual.CornerFillSpin = true
visual.CornerSpinSpeed = .18
visual.CornerFillTransparency = .82

-- The older renderer couples ESP to the standalone HealthBar/Corner Box.
-- Force that old ESP state off. The new ESP below owns its own state and drawing.
visual.ESP = false

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
local function removeVisualOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            if rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- Remove every older ESP menu so there is only one source of truth.
removeVisualOption("ESP")

local state={
    Enabled=false,
    MaxDistance=300,
    WallCheck=true,
    ColorMode="Solid",
    SolidColor=Color3.fromRGB(119,120,255),
    VisibleColor=Color3.fromRGB(35,235,95),
    OccludedColor=Color3.fromRGB(245,55,55),
    FillTransparency=.72,
    OutlineTransparency=0,
    RainbowSpeed=.08,
    ThermalA=Color3.fromRGB(70,190,255),
    ThermalB=Color3.fromRGB(255,105,90),
    ThermalSpeed=.16,
    Corners=true,
    CornerColor=Color3.fromRGB(255,255,255),
    CornerThickness=1,
    Names=true,
    Health=true,
    HealthPalette="Blue / Red",
    HealthText=true,
}
shared.YokaiSafeESPFinalState=state

local ESP=Visuals.CreateOptionsButton({
    ["Name"]="ESP",
    ["Function"]=function(v)
        state.Enabled=v
        -- Never let the legacy renderer re-couple ESP with standalone modules.
        visual.ESP=false
    end,
    ["HoverText"]="Synthetic target ESP pack. Independent from standalone HealthBar and Corner Box.",
})
ESP.CreateSlider({["Name"]="Max Distance",["Min"]=25,["Max"]=1000,["Default"]=300,["Function"]=function(v) state.MaxDistance=v end})
ESP.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) state.WallCheck=v end})
ESP.CreateDropdown({["Name"]="Color Mode",["List"]={"Solid","Rainbow","Thermal","Health Gradient"},["Function"]=function(v) state.ColorMode=v end})
ESP.CreateColorSlider({["Name"]="Solid Color",["Function"]=function(h,s,v) state.SolidColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) state.VisibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) state.OccludedColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=72,["Function"]=function(v) state.FillTransparency=v/100 end})
ESP.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=0,["Function"]=function(v) state.OutlineTransparency=v/100 end})
ESP.CreateSlider({["Name"]="Rainbow Speed",["Min"]=1,["Max"]=40,["Default"]=8,["Function"]=function(v) state.RainbowSpeed=v/100 end})
ESP.CreateColorSlider({["Name"]="Thermal Color A",["Function"]=function(h,s,v) state.ThermalA=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Thermal Color B",["Function"]=function(h,s,v) state.ThermalB=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Thermal Speed",["Min"]=1,["Max"]=60,["Default"]=16,["Function"]=function(v) state.ThermalSpeed=v/100 end})
ESP.CreateToggle({["Name"]="Corners",["Default"]=true,["Function"]=function(v) state.Corners=v end})
ESP.CreateColorSlider({["Name"]="Corner Color",["Function"]=function(h,s,v) state.CornerColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Corner Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) state.CornerThickness=v end})
ESP.CreateToggle({["Name"]="Name + Distance",["Default"]=true,["Function"]=function(v) state.Names=v end})
ESP.CreateToggle({["Name"]="ESP HealthBar",["Default"]=true,["Function"]=function(v) state.Health=v end})
ESP.CreateDropdown({["Name"]="ESP Health Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) state.HealthPalette=v end})
ESP.CreateToggle({["Name"]="ESP HealthText",["Default"]=true,["Function"]=function(v) state.HealthText=v end})

-- Remove old ESP style adornments/overlay remnants.
local roots={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
pcall(function() if gethui then table.insert(roots,gethui()) end end)
for _,root in ipairs(roots) do
    if root then
        local old=root:FindFirstChild("YokaiSafeESPFinalOverlay",true)
        if old then pcall(function() old:Destroy() end) end
    end
end
for _,obj in ipairs(Workspace:GetDescendants()) do
    if obj.Name=="YokaiSafeESPFinalHighlight" or obj.Name=="YokaiSafeGradientAdornment" then
        pcall(function() obj:Destroy() end)
    end
end

local overlay=Instance.new("ScreenGui")
overlay.Name="YokaiSafeESPFinalOverlay"
overlay.ResetOnSpawn=false
overlay.IgnoreGuiInset=true
overlay.DisplayOrder=1001
pcall(function() overlay.Parent=(gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local highlight=Instance.new("Highlight")
highlight.Name="YokaiSafeESPFinalHighlight"
highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled=false
highlight.Parent=Workspace

local function newLine()
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.Visible=false
    f.Parent=overlay
    return f
end
local function setLine(f,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color
    f.BackgroundTransparency=transparency or 0
    f.Visible=true
end
local function hideLines(t) for _,v in ipairs(t) do v.Visible=false end end

local corners={} for i=1,8 do corners[i]=newLine() end

local name=Instance.new("TextLabel")
name.BackgroundTransparency=1
name.AnchorPoint=Vector2.new(.5,.5)
name.Size=UDim2.fromOffset(260,18)
name.Font=Enum.Font.Code
name.TextSize=12
name.TextStrokeTransparency=0
name.TextStrokeColor3=Color3.new(0,0,0)
name.TextColor3=Color3.new(1,1,1)
name.Visible=false
name.Parent=overlay
local distance=name:Clone() distance.TextSize=11 distance.Parent=overlay

-- ESP HealthBar is deliberately on the RIGHT side. Standalone HealthBar stays on the left.
local espHealthBack=Instance.new("Frame")
espHealthBack.BorderSizePixel=0
espHealthBack.BackgroundColor3=Color3.new(0,0,0)
espHealthBack.Visible=false
espHealthBack.Parent=overlay
local espHealth=Instance.new("Frame")
espHealth.BorderSizePixel=0
espHealth.BackgroundColor3=Color3.new(1,1,1)
espHealth.Visible=false
espHealth.Parent=overlay
local espHealthGradient=Instance.new("UIGradient")
espHealthGradient.Rotation=90
espHealthGradient.Parent=espHealth
local espHealthText=name:Clone()
espHealthText.Size=UDim2.fromOffset(44,16)
espHealthText.TextSize=11
espHealthText.Parent=overlay

local adornments={}
local function clearAdornments()
    for part,a in pairs(adornments) do
        if a then pcall(function() a:Destroy() end) end
        adornments[part]=nil
    end
end
local function ensureAdornment(part)
    local a=adornments[part]
    if a and a.Parent then return a end
    a=Instance.new("BoxHandleAdornment")
    a.Name="YokaiSafeESPFinalGradientAdornment"
    a.Adornee=part
    a.AlwaysOnTop=true
    a.ZIndex=10
    a.Parent=part
    adornments[part]=a
    return a
end

local function lerpColor(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
local function paletteSequence(palette)
    if palette=="Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55)),
        })
    end
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(50,110,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(220,40,50)),
    })
end
local function gradientColor(palette,t)
    t=math.clamp(t,0,1)
    if palette=="Mint / Yellow / Red" then
        local bottom=Color3.fromRGB(230,55,55)
        local middle=Color3.fromRGB(255,226,120)
        local top=Color3.fromRGB(120,255,205)
        if t<=.5 then return lerpColor(bottom,middle,t/.5) end
        return lerpColor(middle,top,(t-.5)/.5)
    end
    return lerpColor(Color3.fromRGB(220,40,50),Color3.fromRGB(50,110,255),t)
end
local function softRainbow()
    local h=(os.clock()*state.RainbowSpeed)%1
    return Color3.fromHSV(h,.55,1)
end
local function thermalColor()
    local t=(math.sin(os.clock()*math.max(.01,state.ThermalSpeed)*math.pi*2)+1)/2
    return lerpColor(state.ThermalA,state.ThermalB,t)
end
local function modeColor()
    if state.ColorMode=="Rainbow" then return softRainbow() end
    if state.ColorMode=="Thermal" then return thermalColor() end
    return state.SolidColor
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
        if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
    end end end
    if not any or maxX<0 or maxY<0 or minX>cam.ViewportSize.X or minY>cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function wallVisible(target,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
end
local function updateCorners(tl,br)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(6,w*.24),math.max(6,h*.18)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(corners[i],v[1],v[2],state.CornerThickness,state.CornerColor,0) end
end
local function applyHealthGradient(target)
    local cf,size=target:GetBoundingBox()
    local minY=cf.Position.Y-size.Y/2
    local height=math.max(.01,size.Y)
    local seen={}
    for _,part in ipairs(target:GetChildren()) do
        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and part.Transparency<1 then
            local a=ensureAdornment(part)
            a.Size=part.Size+Vector3.new(.035,.035,.035)
            a.Transparency=state.FillTransparency
            a.Color3=gradientColor(state.HealthPalette,(part.Position.Y-minY)/height)
            a.Visible=true
            seen[part]=true
        end
    end
    for part,a in pairs(adornments) do
        if not seen[part] then
            if a then a.Visible=false end
            if not part.Parent then adornments[part]=nil end
        end
    end
end
local function hideAll()
    highlight.Enabled=false
    name.Visible=false distance.Visible=false
    espHealthBack.Visible=false espHealth.Visible=false espHealthText.Visible=false
    hideLines(corners)
    clearAdornments()
end

-- High-priority final renderer. Legacy visual.ESP is held false every frame.
RunService:BindToRenderStep("YokaiSafeESPFinalRenderer",Enum.RenderPriority.Last.Value,function()
    visual.ESP=false
    local target=getTarget()
    local cam=Workspace.CurrentCamera
    if not state.Enabled or not target or not cam then hideAll() return end
    local hum=target:FindFirstChildOfClass("Humanoid")
    local root=target:FindFirstChild("HumanoidRootPart")
    local head=target:FindFirstChild("Head") or root
    if not hum or not root or hum.Health<=0 then hideAll() return end

    local dist=(cam.CFrame.Position-root.Position).Magnitude
    if dist>state.MaxDistance then hideAll() return end
    local tl,br=bounds2D(target)
    if not tl then hideAll() return end

    local visible=wallVisible(target,head)
    local wallColor=visible and state.VisibleColor or state.OccludedColor
    local fill=modeColor()

    highlight.Adornee=target
    highlight.Enabled=true
    highlight.OutlineColor=state.WallCheck and wallColor or state.SolidColor
    highlight.OutlineTransparency=state.OutlineTransparency

    if state.ColorMode=="Health Gradient" then
        highlight.FillTransparency=1
        applyHealthGradient(target)
    else
        clearAdornments()
        highlight.FillColor=fill
        highlight.FillTransparency=state.FillTransparency
    end

    if state.Corners then updateCorners(tl,br) else hideLines(corners) end

    local cx=(tl.X+br.X)/2
    if state.Names then
        name.Position=UDim2.fromOffset(cx,tl.Y-12)
        name.Text="YokaiSafeVisualTestTarget"
        name.TextColor3=Color3.new(1,1,1)
        name.Visible=true
        distance.Position=UDim2.fromOffset(cx,br.Y+10)
        distance.Text=string.format("%d studs",math.floor(dist))
        distance.TextColor3=Color3.new(1,1,1)
        distance.Visible=true
    else
        name.Visible=false distance.Visible=false
    end

    if state.Health then
        local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
        local h=math.max(4,br.Y-tl.Y)
        espHealthBack.Position=UDim2.fromOffset(br.X+4,tl.Y)
        espHealthBack.Size=UDim2.fromOffset(5,h)
        espHealthBack.Visible=true
        espHealth.Position=UDim2.fromOffset(br.X+4,tl.Y+h*(1-ratio))
        espHealth.Size=UDim2.fromOffset(5,h*ratio)
        espHealthGradient.Color=paletteSequence(state.HealthPalette)
        espHealth.Visible=true
        espHealthText.Position=UDim2.fromOffset(br.X+18,tl.Y+h*(1-ratio))
        espHealthText.Text=tostring(math.floor(hum.Health))
        espHealthText.TextColor3=Color3.new(1,1,1)
        espHealthText.Visible=state.HealthText
    else
        espHealthBack.Visible=false espHealth.Visible=false espHealthText.Visible=false
    end
end)
