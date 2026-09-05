-- Final local runtime harmony pass.
-- Keeps a single Visuals preview and adds Utility AntiAFK / AntiFling without
-- fighting the existing local movement modules.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec = objects["UtilityWindow"]
local Utility = UtilityRec and UtilityRec["Api"]
if not Utility then
    warn("RuntimeHarmonyFix: Utility window missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end

local function removeOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name then
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

-- --------------------------------------------------------------------------
-- Preview cleanup: keep only VisualsV4's current preview.
-- Older Attached ESP Preview versions could live in PlayerGui, CoreGui or gethui.
-- --------------------------------------------------------------------------
local function guiRoots()
    local out, seen = {}, {}
    local function add(root)
        if root and typeof(root) == "Instance" and not seen[root] then
            seen[root] = true
            table.insert(out, root)
        end
    end
    add(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    add(CoreGui)
    add(GuiLibrary["MainGui"])
    pcall(function() if gethui then add(gethui()) end end)
    return out
end

local function isLegacyPreviewRoot(obj)
    if not obj or typeof(obj) ~= "Instance" then return false end
    local n = obj.Name:lower()
    if n:find("yokaiattachedesppreview", 1, true) or n:find("attachedesppreview", 1, true) then
        return true
    end
    return false
end

local function destroyLegacyPreview()
    for _, root in ipairs(guiRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if isLegacyPreviewRoot(obj) then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("TextLabel") and obj.Text and obj.Text:find("Attached ESP Preview", 1, true) then
                local cur = obj
                local candidate
                while cur and cur ~= root do
                    if cur:IsA("ScreenGui") then candidate = cur break end
                    if cur:IsA("Frame") and cur.Parent and cur.Parent:IsA("ScreenGui") then candidate = cur.Parent break end
                    cur = cur.Parent
                end
                if candidate and candidate.Name ~= "YokaiVisualPreviewV4" then
                    pcall(function() candidate:Destroy() end)
                else
                    local frame = obj:FindFirstAncestorWhichIsA("Frame")
                    if frame then pcall(function() frame:Destroy() end) end
                end
            end
        end
    end
end

-- Remove any obsolete Attached Preview control from saved objects as well.
removeOption("Attached Preview")
destroyLegacyPreview()
task.delay(1, destroyLegacyPreview)
task.delay(3, destroyLegacyPreview)

-- --------------------------------------------------------------------------
-- Utility > AntiAFK
-- --------------------------------------------------------------------------
if shared.YokaiHarmonyAntiAFKConnection then
    pcall(function() shared.YokaiHarmonyAntiAFKConnection:Disconnect() end)
    shared.YokaiHarmonyAntiAFKConnection = nil
end
removeOption("AntiAFK")

local antiAFKEnabled = false
local antiAFK = Utility.CreateOptionsButton({
    ["Name"] = "AntiAFK",
    ["Function"] = function(v)
        antiAFKEnabled = v
    end,
    ["HoverText"] = "Prevents the local client from being disconnected for inactivity.",
})

shared.YokaiHarmonyAntiAFKConnection = LocalPlayer.Idled:Connect(function()
    if not antiAFKEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        local cam = Workspace.CurrentCamera
        VirtualUser:Button2Down(Vector2.new(0,0), cam and cam.CFrame or CFrame.new())
        task.wait(0.05)
        VirtualUser:Button2Up(Vector2.new(0,0), cam and cam.CFrame or CFrame.new())
    end)
end)

-- --------------------------------------------------------------------------
-- Utility > AntiFling
-- Local/self-only velocity protection. It intentionally pauses while Fly or
-- CarFly is enabled so it cannot fight those movement modules.
-- --------------------------------------------------------------------------
if shared.YokaiHarmonyAntiFlingConnection then
    pcall(function() shared.YokaiHarmonyAntiFlingConnection:Disconnect() end)
    shared.YokaiHarmonyAntiFlingConnection = nil
end
removeOption("AntiFling")

local antiFlingEnabled = false
local velocityLimit = 300
local angularLimit = 120
local lastSafeCFrame
local lastSafeAt = 0

local function enabledModule(name)
    local rec = objects[name .. "OptionsButton"]
    local api = rec and rec["Api"]
    return api and api["Enabled"] == true
end

local function movementOverrideActive()
    return enabledModule("Fly") or enabledModule("CarFly")
end

local function getCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return char, hum, root
end

local antiFling = Utility.CreateOptionsButton({
    ["Name"] = "AntiFling",
    ["Function"] = function(v)
        antiFlingEnabled = v
        if not v then lastSafeCFrame = nil end
    end,
    ["HoverText"] = "Limits extreme local velocity/rotation without interfering with Fly or CarFly.",
})
antiFling.CreateSlider({
    ["Name"] = "Velocity Limit",
    ["Min"] = 120,
    ["Max"] = 600,
    ["Default"] = 300,
    ["Function"] = function(v) velocityLimit = v end,
})
antiFling.CreateSlider({
    ["Name"] = "Angular Limit",
    ["Min"] = 40,
    ["Max"] = 300,
    ["Default"] = 120,
    ["Function"] = function(v) angularLimit = v end,
})

shared.YokaiHarmonyAntiFlingConnection = RunService.Heartbeat:Connect(function()
    if not antiFlingEnabled or movementOverrideActive() then return end
    local char, hum, root = getCharacterParts()
    if not root then return end
    if hum.SeatPart then return end

    local linear = root.AssemblyLinearVelocity.Magnitude
    local angular = root.AssemblyAngularVelocity.Magnitude
    local now = os.clock()

    if linear <= velocityLimit * 0.55 and angular <= angularLimit * 0.55 then
        if now - lastSafeAt > 0.12 then
            lastSafeCFrame = root.CFrame
            lastSafeAt = now
        end
        return
    end

    if linear > velocityLimit or angular > angularLimit then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        if lastSafeCFrame and (root.Position - lastSafeCFrame.Position).Magnitude < 80 then
            pcall(function() root.CFrame = lastSafeCFrame end)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    lastSafeCFrame = nil
    lastSafeAt = 0
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Runtime harmony: single preview + Utility protections loaded", 3)
end)
