-- GunTestingLiteWorldStabilizerV3.lua
-- Persistent local world-visual controls for the standalone menu.
-- Event-driven re-application prevents game lighting scripts from restoring the
-- original values between frames; a slow watchdog is only a fallback.

if shared.GunTestingLiteWorldStabilizerV3 then return end
shared.GunTestingLiteWorldStabilizerV3 = true

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local parent = (gethui and gethui()) or CoreGui
local Gui = parent:FindFirstChild("GunTestingLiteV1", true)
if not Gui then
    for _ = 1, 100 do
        task.wait(.05)
        Gui = parent:FindFirstChild("GunTestingLiteV1", true)
        if Gui then break end
    end
end
if not Gui then return end

local function findPage(name)
    for _, d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name == name then return d end
    end
end
local World = findPage("World")
if not World then return end

-- Hide the V2 world rows. Their states default to false, so V3 becomes the
-- single visible owner of Fullbright / foliage / fog / shadows.
local oldLabels = {
    ["Fullbright"] = true,
    ["Fullbright Strength"] = true,
    ["No Leaves"] = true,
    ["No Fog"] = true,
    ["No Shadows"] = true,
}
for _, child in ipairs(World:GetChildren()) do
    if child:IsA("Frame") then
        local label = child:FindFirstChildOfClass("TextLabel")
        if label and oldLabels[label.Text] then child.Visible = false end
    elseif child:IsA("TextLabel") and tostring(child.Text):upper() == "WORLD VISUALS" then
        child.Visible = false
    end
end

local accent = Color3.fromRGB(125, 82, 235)
local W = {
    Fullbright = false,
    FullbrightStrength = 55,
    NoLeaves = false,
    NoFog = false,
    NoShadows = false,
}

local order = 15000
local function section(text)
    local l = Instance.new("TextLabel")
    l.Name = "WorldStabilizerV3Section"
    l.LayoutOrder = order; order += 1
    l.Size = UDim2.new(1, 0, 0, 22)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextColor3 = Color3.fromRGB(166, 159, 192)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = string.upper(text)
    l.Parent = World
end
local function row(label)
    local f = Instance.new("Frame")
    f.Name = "WorldStabilizerV3_" .. label:gsub("%W", "")
    f.LayoutOrder = order; order += 1
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 33)
    f.BorderSizePixel = 0
    f.Parent = World
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 7); c.Parent = f
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(10, 0)
    t.Size = UDim2.new(1, -20, 1, 0)
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.TextColor3 = Color3.fromRGB(230, 230, 240)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = label
    t.Parent = f
    return f
end
local function toggle(label, key, callback)
    local f = row(label)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(48, 24)
    b.Position = UDim2.new(1, -58, .5, -12)
    b.Text = ""
    b.BorderSizePixel = 0
    b.Parent = f
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = b
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(18, 18)
    dot.BorderSizePixel = 0
    dot.Parent = b
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
    local function paint()
        local on = W[key] == true
        b.BackgroundColor3 = on and accent or Color3.fromRGB(50, 50, 62)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.Position = on and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3)
    end
    b.MouseButton1Click:Connect(function()
        W[key] = not W[key]
        paint()
        if callback then task.defer(callback, W[key]) end
    end)
    paint()
end
local function number(label, key, min, max, callback)
    local f = row(label)
    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(88, 24)
    box.Position = UDim2.new(1, -98, .5, -12)
    box.BackgroundColor3 = Color3.fromRGB(34, 34, 45)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 12
    box.TextColor3 = Color3.new(1, 1, 1)
    box.ClearTextOnFocus = false
    box.Text = tostring(W[key])
    box.Parent = f
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = box
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then W[key] = math.clamp(n, min, max) end
        box.Text = tostring(W[key])
        if callback then task.defer(callback, W[key]) end
    end)
end

section("Persistent World Visuals")

-- FULLBRIGHT ----------------------------------------------------------------
local fx
local fxConnections = {}
local enforcingFx = false
local function clearFxConnections()
    for _, c in ipairs(fxConnections) do pcall(function() c:Disconnect() end) end
    table.clear(fxConnections)
end
local function desiredBrightness()
    return math.clamp(W.FullbrightStrength / 100, 0, 1) * .38
end
local function enforceFullbright()
    if enforcingFx then return end
    enforcingFx = true
    if not fx or not fx.Parent then
        clearFxConnections()
        fx = Instance.new("ColorCorrectionEffect")
        fx.Name = "GunTestingLiteFullbrightV3"
        fx.Parent = Lighting
        local function watch(prop)
            table.insert(fxConnections, fx:GetPropertyChangedSignal(prop):Connect(function()
                if W.Fullbright then task.defer(enforceFullbright) end
            end))
        end
        for _, prop in ipairs({"Enabled", "Brightness", "Contrast", "Saturation", "TintColor"}) do watch(prop) end
        table.insert(fxConnections, fx.AncestryChanged:Connect(function(_, newParent)
            if W.Fullbright and not newParent then task.defer(enforceFullbright) end
        end))
    end
    fx.Enabled = W.Fullbright
    if W.Fullbright then
        if fx.Brightness ~= desiredBrightness() then fx.Brightness = desiredBrightness() end
        if fx.Contrast ~= -.08 then fx.Contrast = -.08 end
        if fx.Saturation ~= .02 then fx.Saturation = .02 end
        local tint = Color3.fromRGB(255, 250, 242)
        if fx.TintColor ~= tint then fx.TintColor = tint end
    end
    enforcingFx = false
end

toggle("Fullbright (persistent)", "Fullbright", enforceFullbright)
number("Fullbright Strength", "FullbrightStrength", 0, 100, enforceFullbright)

-- NO LEAVES -----------------------------------------------------------------
local leafWords = {"leaf", "leaves", "foliage", "bush", "shrub", "canopy"}
local leafOriginal = setmetatable({}, {__mode = "k"})
local leafConnections = setmetatable({}, {__mode = "k"})
local leafApplying = setmetatable({}, {__mode = "k"})

local function nameLooksLeaf(text)
    text = tostring(text or ""):lower()
    for _, word in ipairs(leafWords) do
        if text:find(word, 1, true) then return true end
    end
    return false
end
local function looksLeaf(obj)
    if not obj or not obj:IsA("BasePart") then return false end
    if nameLooksLeaf(obj.Name) then return true end
    local p = obj.Parent
    for _ = 1, 2 do
        if not p then break end
        if nameLooksLeaf(p.Name) then return true end
        p = p.Parent
    end
    return false
end
local function enforceLeaf(obj)
    if not W.NoLeaves or not obj or not obj.Parent or not looksLeaf(obj) then return end
    if leafOriginal[obj] == nil then leafOriginal[obj] = obj.LocalTransparencyModifier end
    if obj.LocalTransparencyModifier ~= 1 then
        leafApplying[obj] = true
        obj.LocalTransparencyModifier = 1
        leafApplying[obj] = nil
    end
    if not leafConnections[obj] then
        leafConnections[obj] = obj:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
            if W.NoLeaves and not leafApplying[obj] then task.defer(enforceLeaf, obj) end
        end)
    end
end
local leafScanToken = 0
local function applyLeaves(on)
    leafScanToken += 1
    local token = leafScanToken
    if not on then
        for obj, old in pairs(leafOriginal) do
            if obj and obj.Parent then
                leafApplying[obj] = true
                pcall(function() obj.LocalTransparencyModifier = old end)
                leafApplying[obj] = nil
            end
            leafOriginal[obj] = nil
        end
        return
    end
    task.spawn(function()
        local all = Workspace:GetDescendants()
        for i, obj in ipairs(all) do
            if token ~= leafScanToken or not W.NoLeaves then return end
            if obj:IsA("BasePart") and looksLeaf(obj) then pcall(enforceLeaf, obj) end
            if i % 250 == 0 then task.wait() end
        end
    end)
end
Workspace.DescendantAdded:Connect(function(obj)
    if W.NoLeaves and obj:IsA("BasePart") then task.defer(enforceLeaf, obj) end
end)
toggle("No Leaves (persistent)", "NoLeaves", applyLeaves)

-- NO FOG --------------------------------------------------------------------
local fogBackup = nil
local atmosphereBackup = setmetatable({}, {__mode = "k"})
local atmosphereConnections = setmetatable({}, {__mode = "k"})
local enforcingFog = false
local function backupAtmosphere(a)
    if atmosphereBackup[a] == nil then
        atmosphereBackup[a] = {Density=a.Density, Haze=a.Haze, Glare=a.Glare}
    end
end
local function enforceAtmosphere(a)
    if not W.NoFog or not a or not a.Parent or not a:IsA("Atmosphere") then return end
    backupAtmosphere(a)
    if a.Density ~= 0 then a.Density = 0 end
    if a.Haze ~= 0 then a.Haze = 0 end
    if a.Glare ~= 0 then a.Glare = 0 end
    if not atmosphereConnections[a] then
        local cons = {}
        atmosphereConnections[a] = cons
        for _, prop in ipairs({"Density", "Haze", "Glare"}) do
            table.insert(cons, a:GetPropertyChangedSignal(prop):Connect(function()
                if W.NoFog and not enforcingFog then task.defer(function()
                    enforcingFog = true
                    pcall(enforceAtmosphere, a)
                    enforcingFog = false
                end) end
            end))
        end
    end
end
local function enforceFog()
    if enforcingFog then return end
    enforcingFog = true
    if W.NoFog then
        if not fogBackup then fogBackup = {Start=Lighting.FogStart, End=Lighting.FogEnd} end
        if Lighting.FogStart ~= 0 then Lighting.FogStart = 0 end
        if Lighting.FogEnd ~= 1000000 then Lighting.FogEnd = 1000000 end
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") then pcall(enforceAtmosphere, child) end
        end
    elseif fogBackup then
        Lighting.FogStart = fogBackup.Start
        Lighting.FogEnd = fogBackup.End
        fogBackup = nil
        for a, old in pairs(atmosphereBackup) do
            if a and a.Parent then
                pcall(function()
                    a.Density = old.Density
                    a.Haze = old.Haze
                    a.Glare = old.Glare
                end)
            end
            atmosphereBackup[a] = nil
        end
    end
    enforcingFog = false
end
Lighting:GetPropertyChangedSignal("FogStart"):Connect(function()
    if W.NoFog then task.defer(enforceFog) end
end)
Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if W.NoFog then task.defer(enforceFog) end
end)
Lighting.ChildAdded:Connect(function(child)
    if W.NoFog and child:IsA("Atmosphere") then task.defer(enforceAtmosphere, child) end
end)
toggle("No Fog (persistent)", "NoFog", enforceFog)

-- NO SHADOWS ----------------------------------------------------------------
local shadowBackup = nil
local enforcingShadows = false
local function enforceShadows()
    if enforcingShadows then return end
    enforcingShadows = true
    if W.NoShadows then
        if shadowBackup == nil then shadowBackup = Lighting.GlobalShadows end
        if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
    elseif shadowBackup ~= nil then
        Lighting.GlobalShadows = shadowBackup
        shadowBackup = nil
    end
    enforcingShadows = false
end
Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
    if W.NoShadows then task.defer(enforceShadows) end
end)
toggle("No Shadows (persistent)", "NoShadows", enforceShadows)

-- Slow fallback watchdog. Property-change listeners above do the immediate work,
-- so this does not fight the game every RenderStepped and does not flash.
local watchdog = 0
RunService.Heartbeat:Connect(function(dt)
    watchdog += dt
    if watchdog < .75 then return end
    watchdog = 0
    if W.Fullbright then enforceFullbright() end
    if W.NoFog then enforceFog() end
    if W.NoShadows then enforceShadows() end
    if W.NoLeaves then
        local checked = 0
        for obj in pairs(leafOriginal) do
            if obj and obj.Parent and obj.LocalTransparencyModifier ~= 1 then enforceLeaf(obj) end
            checked += 1
            if checked >= 250 then break end
        end
    end
end)

enforceFullbright()
