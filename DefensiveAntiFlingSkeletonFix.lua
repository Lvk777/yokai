-- Stronger local AntiFling + safe customizable Skeleton preview/Studio layer.
-- No live-player ESP/wallcheck behavior is added here.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec = objects["UtilityWindow"]
local VisualsRec = objects["VisualsWindow"]
local Utility = UtilityRec and UtilityRec["Api"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Utility or not Visuals then
    warn("DefensiveAntiFlingSkeletonFix: Utility/Visuals missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isUnder(rec, parentRec)
    if not rec or not rec["Object"] or not parentRec then return false end
    local obj = rec["Object"]
    for _, root in ipairs({parentRec["Object"], parentRec["ChildrenObject"]}) do
        if root and typeof(root) == "Instance" and (obj == root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOption(name, parentRec)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name and (not parentRec or isUnder(rec, parentRec)) then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- ==========================================================================
-- Utility > AntiFling (local/self defensive recovery)
-- ==========================================================================
if shared.YokaiHarmonyAntiFlingConnection then
    pcall(function() shared.YokaiHarmonyAntiFlingConnection:Disconnect() end)
    shared.YokaiHarmonyAntiFlingConnection = nil
end
if shared.YokaiDefensiveAntiFlingConnection then
    pcall(function() shared.YokaiDefensiveAntiFlingConnection:Disconnect() end)
    shared.YokaiDefensiveAntiFlingConnection = nil
end
removeOption("AntiFling", UtilityRec)

local antiFlingEnabled = false
local velocityLimit = 95
local angularLimit = 55
local displacementLimit = 16
local recoveryHold = 0.28
local groundedOnly = true
local lastSafeCFrame
local lastSafeAt = 0
local previousPosition
local recoveringUntil = 0
local recoveryCFrame

local function moduleEnabled(name)
    local rec = objects[name .. "OptionsButton"]
    local api = rec and rec["Api"]
    return api and api["Enabled"] == true
end
local function movementOverrideActive()
    return moduleEnabled("Fly") or moduleEnabled("CarFly")
end
local function characterState()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return char, hum, root
end
local function zeroCharacterVelocity(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end
local function maxBodyVelocity(char)
    local maxLinear, maxAngular = 0, 0
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local l = part.AssemblyLinearVelocity.Magnitude
            local a = part.AssemblyAngularVelocity.Magnitude
            if l > maxLinear then maxLinear = l end
            if a > maxAngular then maxAngular = a end
        end
    end
    return maxLinear, maxAngular
end
local function grounded(hum, root, char)
    if hum.FloorMaterial ~= Enum.Material.Air then return true end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {char}
    rp.IgnoreWater = true
    return Workspace:Raycast(root.Position, Vector3.new(0, -7, 0), rp) ~= nil
end
local function beginRecovery(char, hum, root)
    recoveryCFrame = lastSafeCFrame or root.CFrame
    recoveringUntil = os.clock() + recoveryHold
    zeroCharacterVelocity(char)
    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)
    if recoveryCFrame then pcall(function() root.CFrame = recoveryCFrame end) end
end

local AntiFling = Utility.CreateOptionsButton({
    ["Name"] = "AntiFling",
    ["Function"] = function(v)
        antiFlingEnabled = v
        previousPosition = nil
        recoveringUntil = 0
        if not v then lastSafeCFrame = nil recoveryCFrame = nil end
    end,
    ["HoverText"] = "Detects sudden local velocity/rotation/displacement and returns you to the last safe grounded position.",
})
AntiFling.CreateSlider({
    ["Name"] = "Velocity Limit",
    ["Min"] = 45,
    ["Max"] = 250,
    ["Default"] = 95,
    ["Function"] = function(v) velocityLimit = v end,
})
AntiFling.CreateSlider({
    ["Name"] = "Angular Limit",
    ["Min"] = 20,
    ["Max"] = 180,
    ["Default"] = 55,
    ["Function"] = function(v) angularLimit = v end,
})
AntiFling.CreateSlider({
    ["Name"] = "Displacement Limit",
    ["Min"] = 6,
    ["Max"] = 60,
    ["Default"] = 16,
    ["Function"] = function(v) displacementLimit = v end,
})
AntiFling.CreateSlider({
    ["Name"] = "Recovery Hold",
    ["Min"] = 10,
    ["Max"] = 70,
    ["Default"] = 28,
    ["Function"] = function(v) recoveryHold = v / 100 end,
})
AntiFling.CreateToggle({
    ["Name"] = "Grounded Safe Point",
    ["Default"] = true,
    ["Function"] = function(v) groundedOnly = v end,
})

shared.YokaiDefensiveAntiFlingConnection = RunService.Stepped:Connect(function()
    if not antiFlingEnabled or movementOverrideActive() then
        previousPosition = nil
        return
    end
    local char, hum, root = characterState()
    if not root or hum.SeatPart then
        previousPosition = nil
        return
    end

    local now = os.clock()
    if now < recoveringUntil then
        zeroCharacterVelocity(char)
        if recoveryCFrame then pcall(function() root.CFrame = recoveryCFrame end) end
        previousPosition = root.Position
        return
    end

    local rootLinear = root.AssemblyLinearVelocity.Magnitude
    local rootAngular = root.AssemblyAngularVelocity.Magnitude
    local maxLinear, maxAngular = maxBodyVelocity(char)
    local displacement = previousPosition and (root.Position - previousPosition).Magnitude or 0
    previousPosition = root.Position

    local safeGround = (not groundedOnly) or grounded(hum, root, char)
    if safeGround and rootLinear < math.min(velocityLimit * 0.42, 42) and rootAngular < math.min(angularLimit * 0.4, 22) then
        if now - lastSafeAt >= 0.08 then
            lastSafeCFrame = root.CFrame
            lastSafeAt = now
        end
    end

    local suspicious = rootLinear > velocityLimit
        or rootAngular > angularLimit
        or maxLinear > velocityLimit * 1.15
        or maxAngular > angularLimit * 1.15
        or displacement > displacementLimit

    if suspicious then
        beginRecovery(char, hum, root)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    lastSafeCFrame = nil
    lastSafeAt = 0
    previousPosition = nil
    recoveringUntil = 0
    recoveryCFrame = nil
end)

-- ==========================================================================
-- Visuals > Skeleton (Preview + Studio non-player dummies only)
-- ==========================================================================
removeOption("Skeleton", VisualsRec)

local skeletonEnabled = false
local skeletonColor = Color3.fromRGB(255,255,255)
local skeletonTransparency = 0
local skeletonThickness = 1

local Skeleton = Visuals.CreateOptionsButton({
    ["Name"] = "Skeleton",
    ["Function"] = function(v) skeletonEnabled = v end,
    ["HoverText"] = "Custom skeleton for the Visuals Preview and non-player Humanoid dummies in Roblox Studio.",
})
Skeleton.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) skeletonColor = Color3.fromHSV(h,s,v) end,
})
Skeleton.CreateSlider({
    ["Name"] = "Transparency",
    ["Min"] = 0,
    ["Max"] = 95,
    ["Default"] = 0,
    ["Function"] = function(v) skeletonTransparency = v / 100 end,
})
Skeleton.CreateSlider({
    ["Name"] = "Thickness",
    ["Min"] = 1,
    ["Max"] = 5,
    ["Default"] = 1,
    ["Function"] = function(v) skeletonThickness = v end,
})

local function createLine(parent, name)
    local f = Instance.new("Frame")
    f.Name = name or "SkeletonLine"
    f.AnchorPoint = Vector2.new(.5,.5)
    f.BorderSizePixel = 0
    f.BackgroundColor3 = skeletonColor
    f.BackgroundTransparency = skeletonTransparency
    f.Visible = false
    f.ZIndex = 30
    f.Parent = parent
    return f
end
local function setLine(line, a, b)
    local d = b - a
    if d.Magnitude < 0.01 then line.Visible = false return end
    line.Size = UDim2.fromOffset(d.Magnitude, skeletonThickness)
    line.Position = UDim2.fromOffset((a.X+b.X)/2, (a.Y+b.Y)/2)
    line.Rotation = math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3 = skeletonColor
    line.BackgroundTransparency = skeletonTransparency
    line.Visible = true
end

local previewLines = {}
local previewCanvas
local function findPreviewCanvas()
    for _, root in ipairs({LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui}) do
        if root then
            local gui = root:FindFirstChild("YokaiVisualPreviewV7", true)
            if gui then
                local window = gui:FindFirstChild("Window", true)
                if window then
                    for _, d in ipairs(window:GetDescendants()) do
                        if d:IsA("Frame") and d.ClipsDescendants then return d, gui end
                    end
                end
            end
        end
    end
    pcall(function()
        if gethui then
            local gui = gethui():FindFirstChild("YokaiVisualPreviewV7", true)
            if gui then
                local window = gui:FindFirstChild("Window", true)
                if window then
                    for _, d in ipairs(window:GetDescendants()) do
                        if d:IsA("Frame") and d.ClipsDescendants then previewCanvas = d return d, gui end
                    end
                end
            end
        end
    end)
    return previewCanvas
end
local function ensurePreviewLines(canvas)
    if previewCanvas ~= canvas then
        for _, l in ipairs(previewLines) do if l and l.Parent then l:Destroy() end end
        previewLines = {}
        previewCanvas = canvas
    end
    if #previewLines == 10 then return end
    for i=1,10 do previewLines[i] = createLine(canvas, "YokaiSafeSkeletonLine"..i) end
end
local function hidePreviewLines()
    for _, l in ipairs(previewLines) do if l then l.Visible = false end end
end

local studioGui = Instance.new("ScreenGui")
studioGui.Name = "YokaiSafeStudioSkeleton"
studioGui.ResetOnSpawn = false
studioGui.IgnoreGuiInset = true
studioGui.DisplayOrder = 996
studioGui.Enabled = RunService:IsStudio()
pcall(function() studioGui.Parent = (gethui and gethui()) or CoreGui end)
if not studioGui.Parent then studioGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local dummyLines = setmetatable({}, {__mode="k"})
local dummyCache = {}
local lastDummyRefresh = 0
local r15Bones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local r6Bones = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local function ensureDummyLines(model, count)
    local lines = dummyLines[model]
    if not lines then lines = {} dummyLines[model] = lines end
    while #lines < count do table.insert(lines, createLine(studioGui, "YokaiStudioSkeletonLine")) end
    return lines
end
local function refreshDummies()
    dummyCache = {}
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then table.insert(dummyCache, model) end
        end
    end
end

RunService.RenderStepped:Connect(function()
    -- Preview skeleton.
    local canvas, previewGui = findPreviewCanvas()
    if canvas then ensurePreviewLines(canvas) end
    if skeletonEnabled and canvas and previewGui and previewGui.Enabled then
        local sz = canvas.AbsoluteSize
        local center = Vector2.new(sz.X/2, sz.Y*.54)
        local pts = {
            center+Vector2.new(0,-92), center+Vector2.new(0,-36), center+Vector2.new(0,34),
            center+Vector2.new(-39,-38), center+Vector2.new(-39,10),
            center+Vector2.new(39,-38), center+Vector2.new(39,10),
            center+Vector2.new(-18,34), center+Vector2.new(-18,104),
            center+Vector2.new(18,34), center+Vector2.new(18,104),
        }
        local edges={{1,2},{2,3},{2,4},{4,5},{2,6},{6,7},{3,8},{8,9},{3,10},{10,11}}
        for i,e in ipairs(edges) do setLine(previewLines[i], pts[e[1]], pts[e[2]]) end
    else
        hidePreviewLines()
    end

    -- Studio non-player dummy skeletons.
    if not RunService:IsStudio() then return end
    if os.clock() - lastDummyRefresh > 0.45 then lastDummyRefresh = os.clock() refreshDummies() end
    local seen = {}
    local cam = Workspace.CurrentCamera
    if skeletonEnabled and cam then
        for _, model in ipairs(dummyCache) do
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                seen[model] = true
                local bones = model:FindFirstChild("UpperTorso") and r15Bones or r6Bones
                local lines = ensureDummyLines(model, #bones)
                for i,b in ipairs(bones) do
                    local p1, p2 = model:FindFirstChild(b[1]), model:FindFirstChild(b[2])
                    local line = lines[i]
                    if p1 and p2 then
                        local a, va = cam:WorldToViewportPoint(p1.Position)
                        local c, vc = cam:WorldToViewportPoint(p2.Position)
                        if va and vc and a.Z > 0 and c.Z > 0 then
                            setLine(line, Vector2.new(a.X,a.Y), Vector2.new(c.X,c.Y))
                        else line.Visible = false end
                    else line.Visible = false end
                end
                for i=#bones+1,#lines do lines[i].Visible = false end
            end
        end
    end
    for model, lines in pairs(dummyLines) do
        if not seen[model] or not skeletonEnabled then
            for _, l in ipairs(lines) do if l then l.Visible = false end end
        end
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Stronger AntiFling + customizable safe Skeleton loaded", 3)
end)
