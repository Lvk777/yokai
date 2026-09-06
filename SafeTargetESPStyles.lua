-- Synthetic-target-only ESP color/style extension.
-- Only YokaiSafeVisualTestTarget is affected. No real player is inspected here.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary and shared.YokaiSafeTargetVisualState

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
if not VisualsRec then return end

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

local espRec=findVisualOption("ESP")
local ESP=espRec and espRec.Api
if not ESP then return end

local visual=shared.YokaiSafeTargetVisualState
visual.ESPColorMode=visual.ESPColorMode or "Solid"
visual.ESPFillEnabled=(visual.ESPFillEnabled==nil) and true or visual.ESPFillEnabled
visual.ESPFillColor=visual.ESPFillColor or visual.ESPColor or Color3.fromRGB(119,120,255)
visual.ESPOutlineColor=visual.ESPOutlineColor or Color3.fromRGB(255,255,255)
visual.ESPFillTransparency=visual.ESPFillTransparency or .72
visual.ESPOutlineTransparency=visual.ESPOutlineTransparency or 0
visual.RainbowSpeed=visual.RainbowSpeed or .08
visual.ThermalColorA=visual.ThermalColorA or Color3.fromRGB(80,210,255)
visual.ThermalColorB=visual.ThermalColorB or Color3.fromRGB(255,110,95)
visual.ThermalSpeed=visual.ThermalSpeed or .15

ESP.CreateDropdown({["Name"]="Color Mode",["List"]={"Solid","Rainbow","Thermal","Health Gradient"},["Function"]=function(v) visual.ESPColorMode=v end})
ESP.CreateToggle({["Name"]="Filled",["Default"]=true,["Function"]=function(v) visual.ESPFillEnabled=v end})
ESP.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) visual.ESPFillColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) visual.ESPOutlineColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=72,["Function"]=function(v) visual.ESPFillTransparency=v/100 end})
ESP.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=0,["Function"]=function(v) visual.ESPOutlineTransparency=v/100 end})
ESP.CreateSlider({["Name"]="Rainbow Speed",["Min"]=1,["Max"]=50,["Default"]=8,["Function"]=function(v) visual.RainbowSpeed=v/100 end})
ESP.CreateColorSlider({["Name"]="Thermal Color A",["Function"]=function(h,s,v) visual.ThermalColorA=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Thermal Color B",["Function"]=function(h,s,v) visual.ThermalColorB=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Thermal Speed",["Min"]=1,["Max"]=50,["Default"]=15,["Function"]=function(v) visual.ThermalSpeed=v/100 end})

-- Remove body adornments created by the previous gradient implementation.
for _,obj in ipairs(Workspace:GetDescendants()) do
    if obj.Name=="YokaiSafeGradientAdornment" then pcall(function() obj:Destroy() end) end
end

local function findHighlight()
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Highlight") and obj.Name=="YokaiSafeTargetHighlight" then return obj end
    end
end

local function lerpColor(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end

local function paletteColor(t)
    t=math.clamp(t,0,1)
    if visual.HealthPalette=="Mint / Yellow / Red" then
        local red=Color3.fromRGB(230,55,55)
        local yellow=Color3.fromRGB(255,226,120)
        local mint=Color3.fromRGB(120,255,205)
        if t<.5 then return lerpColor(red,yellow,t*2) end
        return lerpColor(yellow,mint,(t-.5)*2)
    end
    return lerpColor(Color3.fromRGB(220,40,50),Color3.fromRGB(50,110,255),t)
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

RunService.RenderStepped:Connect(function()
    local target=Workspace:FindFirstChild("YokaiSafeVisualTestTarget")
    local highlight=findHighlight()
    if not target or not highlight or not visual.ESP then return end

    -- Keep the ESP geometry exactly as a normal Highlight. Only its colors change.
    local mode=visual.ESPColorMode or "Solid"
    local fill=visual.ESPFillColor
    if mode=="Rainbow" then
        local hue=(os.clock()*math.max(.01,visual.RainbowSpeed))%1
        -- Lower saturation + slight whitening makes the rainbow cleaner/less neon.
        fill=Color3.fromHSV(hue,.62,1):Lerp(Color3.new(1,1,1),.10)
    elseif mode=="Thermal" then
        local wave=(math.sin(os.clock()*math.max(.01,visual.ThermalSpeed)*math.pi*2)+1)/2
        fill=lerpColor(visual.ThermalColorA,visual.ThermalColorB,wave)
    elseif mode=="Health Gradient" then
        -- Color-only gradient cycle using the exact HealthBar palette.
        local wave=(math.sin(os.clock()*.7)+1)/2
        fill=paletteColor(wave)
    end

    local head=target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
    local visible=wallVisible(target,head)
    local outline=visual.ESPOutlineColor
    if visual.WallCheck then outline=visible and visual.VisibleColor or visual.OccludedColor end

    highlight.Adornee=target
    highlight.Enabled=true
    highlight.FillColor=fill
    highlight.OutlineColor=outline
    highlight.FillTransparency=visual.ESPFillEnabled and visual.ESPFillTransparency or 1
    highlight.OutlineTransparency=visual.ESPOutlineTransparency
end)
