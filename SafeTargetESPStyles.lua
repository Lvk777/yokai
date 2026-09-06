-- Synthetic-target-only ESP style extension.
-- This file only touches YokaiSafeVisualTestTarget and its local visual state.

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
local function isUnder(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    local obj = rec.Object
    for _, root in ipairs({parentRec.Object, parentRec.ChildrenObject}) do
        if root and typeof(root) == "Instance" and (obj == root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end
local function findVisualOption(name)
    local found
    for key, rec in pairs(objects) do
        if rec and rec.Type == "OptionsButton" and optionName(key) == name and isUnder(rec, VisualsRec) then
            found = rec
        end
    end
    return found
end

local espRec = findVisualOption("ESP")
local ESP = espRec and espRec.Api
if not ESP then
    warn("SafeTargetESPStyles: ESP option missing")
    return
end

local visual = shared.YokaiSafeTargetVisualState
visual.ESPStyle = visual.ESPStyle or "Filled"
visual.ESPFillColor = visual.ESPFillColor or visual.ESPColor or Color3.fromRGB(119,120,255)
visual.ESPOutlineColor = visual.ESPOutlineColor or Color3.fromRGB(255,255,255)
visual.ESPFillTransparency = visual.ESPFillTransparency or .72
visual.ESPOutlineTransparency = visual.ESPOutlineTransparency or 0
visual.ThermalColorA = visual.ThermalColorA or Color3.fromRGB(0,210,255)
visual.ThermalColorB = visual.ThermalColorB or Color3.fromRGB(255,80,30)
visual.ThermalSpeed = visual.ThermalSpeed or .22
visual.GradientTransparency = visual.GradientTransparency or .48

ESP.CreateDropdown({
    ["Name"] = "Style",
    ["List"] = {"Outline","Filled","Thermal","Health Gradient"},
    ["Function"] = function(v) visual.ESPStyle = v end,
})
ESP.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) visual.ESPFillColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) visual.ESPOutlineColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=72,["Function"]=function(v) visual.ESPFillTransparency=v/100 end})
ESP.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=0,["Function"]=function(v) visual.ESPOutlineTransparency=v/100 end})
ESP.CreateColorSlider({["Name"]="Thermal Color A",["Function"]=function(h,s,v) visual.ThermalColorA=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Thermal Color B",["Function"]=function(h,s,v) visual.ThermalColorB=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Thermal Speed",["Min"]=1,["Max"]=100,["Default"]=22,["Function"]=function(v) visual.ThermalSpeed=v/100 end})
ESP.CreateSlider({["Name"]="Gradient Transparency",["Min"]=0,["Max"]=95,["Default"]=48,["Function"]=function(v) visual.GradientTransparency=v/100 end})

local function findHighlight()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Highlight") and obj.Name == "YokaiSafeTargetHighlight" then return obj end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Highlight") and obj.Name == "YokaiSafeTargetHighlight" then return obj end
    end
end

local adornments = {}
local function clearAdornments()
    for part, adorn in pairs(adornments) do
        if adorn then pcall(function() adorn:Destroy() end) end
        adornments[part] = nil
    end
end

local function ensureAdornment(part)
    local old = adornments[part]
    if old and old.Parent then return old end
    local a = Instance.new("BoxHandleAdornment")
    a.Name = "YokaiSafeGradientAdornment"
    a.Adornee = part
    a.AlwaysOnTop = true
    a.ZIndex = 9
    a.Size = part.Size + Vector3.new(.035,.035,.035)
    a.Transparency = visual.GradientTransparency
    a.Parent = part
    adornments[part] = a
    return a
end

local function lerpColor(a,b,t)
    return Color3.new(
        a.R + (b.R-a.R)*t,
        a.G + (b.G-a.G)*t,
        a.B + (b.B-a.B)*t
    )
end

local function gradientColor(t)
    t = math.clamp(t,0,1)
    if visual.HealthPalette == "Mint / Yellow / Red" then
        local bottom = Color3.fromRGB(230,55,55)
        local middle = Color3.fromRGB(255,226,120)
        local top = Color3.fromRGB(120,255,205)
        if t <= .5 then return lerpColor(bottom,middle,t/.5) end
        return lerpColor(middle,top,(t-.5)/.5)
    end
    local bottom = Color3.fromRGB(220,40,50)
    local top = Color3.fromRGB(50,110,255)
    return lerpColor(bottom,top,t)
end

local function applyGradient(target)
    local cf,size = target:GetBoundingBox()
    local minY = cf.Position.Y - size.Y/2
    local height = math.max(.01,size.Y)
    local seen = {}
    for _, part in ipairs(target:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "YokaiSafeHitbox" and part.Transparency < 1 then
            local a = ensureAdornment(part)
            a.Size = part.Size + Vector3.new(.035,.035,.035)
            a.Transparency = visual.GradientTransparency
            local t = (part.Position.Y-minY)/height
            a.Color3 = gradientColor(t)
            a.Visible = true
            seen[part] = true
        end
    end
    for part, a in pairs(adornments) do
        if not seen[part] then
            if a then a.Visible=false end
            if not part.Parent then adornments[part]=nil end
        end
    end
end

local function wallVisible(target, part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character, cam}
    rp.IgnoreWater = true
    local hit = Workspace:Raycast(cam.CFrame.Position, part.Position-cam.CFrame.Position, rp)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
end

RunService.RenderStepped:Connect(function()
    local target = Workspace:FindFirstChild("YokaiSafeVisualTestTarget")
    local highlight = findHighlight()
    if not target or not highlight or not visual.ESP then
        clearAdornments()
        return
    end

    local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
    local visible = wallVisible(target,head)
    local wallColor = visual.WallCheck and (visible and visual.VisibleColor or visual.OccludedColor) or visual.ESPColor
    local style = visual.ESPStyle or "Filled"

    highlight.Adornee = target
    highlight.Enabled = true
    highlight.OutlineTransparency = visual.ESPOutlineTransparency

    if style == "Outline" then
        clearAdornments()
        highlight.FillTransparency = 1
        highlight.OutlineColor = visual.WallCheck and wallColor or visual.ESPOutlineColor
        return
    end

    if style == "Filled" then
        clearAdornments()
        highlight.FillColor = visual.WallCheck and wallColor or visual.ESPFillColor
        highlight.OutlineColor = visual.WallCheck and wallColor or visual.ESPOutlineColor
        highlight.FillTransparency = visual.ESPFillTransparency
        return
    end

    if style == "Thermal" then
        clearAdornments()
        local wave = (math.sin(os.clock()*math.max(.01,visual.ThermalSpeed)*math.pi*2)+1)/2
        local thermal = lerpColor(visual.ThermalColorA,visual.ThermalColorB,wave)
        if visual.WallCheck and not visible then thermal = lerpColor(thermal,visual.OccludedColor,.58) end
        highlight.FillColor = thermal
        highlight.OutlineColor = visual.WallCheck and wallColor or visual.ESPOutlineColor
        highlight.FillTransparency = visual.ESPFillTransparency
        return
    end

    -- Health Gradient: body-part fill follows the exact HealthBar palette.
    highlight.FillTransparency = 1
    highlight.OutlineColor = visual.WallCheck and wallColor or visual.ESPOutlineColor
    applyGradient(target)
end)
