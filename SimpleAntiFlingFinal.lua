-- Final simple local AntiFling: one toggle, no configuration.
-- Defensive behavior only: locally disables player-to-player body collision while enabled
-- and recovers the local character from abnormal physics impulses/displacement.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec = objects["UtilityWindow"]
local Utility = UtilityRec and UtilityRec["Api"]
if not Utility then
    warn("SimpleAntiFlingFinal: Utility missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end

local function removeAntiFlingOptions()
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == "AntiFling" then
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

for _, name in ipairs({
    "YokaiHarmonyAntiFlingConnection",
    "YokaiDefensiveAntiFlingConnection",
    "YokaiSimpleAntiFlingStepped",
    "YokaiSimpleAntiFlingHeartbeat",
}) do
    if shared[name] then
        pcall(function() shared[name]:Disconnect() end)
        shared[name] = nil
    end
end
removeAntiFlingOptions()

local enabled = false
local lastSafeCFrame
local lastSafeAt = 0
local previousPosition
local recoveryUntil = 0
local recoveryCFrame
local foreignCollisionState = setmetatable({}, {__mode = "k"})

local VELOCITY_LIMIT = 90
local ANGULAR_LIMIT = 50
local DISPLACEMENT_LIMIT = 18
local RECOVERY_TIME = 0.32

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

local function zeroVelocity(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function grounded(char, hum, root)
    if hum.FloorMaterial ~= Enum.Material.Air then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    return Workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params) ~= nil
end

local function maxBodyVelocity(char)
    local linear, angular = 0, 0
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            linear = math.max(linear, obj.AssemblyLinearVelocity.Magnitude)
            angular = math.max(angular, obj.AssemblyAngularVelocity.Magnitude)
        end
    end
    return linear, angular
end

local function restoreForeignCollision()
    for part, old in pairs(foreignCollisionState) do
        if part and part.Parent then
            pcall(function() part.CanCollide = old end)
        end
        foreignCollisionState[part] = nil
    end
end

local function suppressForeignCollision()
    if not enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if foreignCollisionState[part] == nil then
                            foreignCollisionState[part] = part.CanCollide
                        end
                        if part.CanCollide then
                            pcall(function() part.CanCollide = false end)
                        end
                    end
                end
            end
        end
    end
end

local function recover(char, hum, root)
    recoveryCFrame = lastSafeCFrame or root.CFrame
    recoveryUntil = os.clock() + RECOVERY_TIME
    zeroVelocity(char)
    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)
    if recoveryCFrame then
        pcall(function() root.CFrame = recoveryCFrame end)
    end
end

local AntiFling = Utility.CreateOptionsButton({
    ["Name"] = "AntiFling",
    ["Function"] = function(v)
        enabled = v
        previousPosition = nil
        recoveryUntil = 0
        if v then
            local char, hum, root = characterState()
            if root then
                lastSafeCFrame = root.CFrame
                lastSafeAt = os.clock()
            end
            suppressForeignCollision()
        else
            restoreForeignCollision()
            lastSafeCFrame = nil
            recoveryCFrame = nil
        end
    end,
    ["HoverText"] = "Simple local anti-fling protection. Disables body collision from other players locally and recovers abnormal physics automatically.",
})

shared.YokaiSimpleAntiFlingStepped = RunService.Stepped:Connect(function()
    if not enabled then return end
    suppressForeignCollision()

    if movementOverrideActive() then
        previousPosition = nil
        return
    end

    local char, hum, root = characterState()
    if not root or hum.SeatPart then
        previousPosition = nil
        return
    end

    local now = os.clock()
    if now < recoveryUntil then
        zeroVelocity(char)
        if recoveryCFrame then pcall(function() root.CFrame = recoveryCFrame end) end
        previousPosition = root.Position
        return
    end

    local displacement = previousPosition and (root.Position - previousPosition).Magnitude or 0
    previousPosition = root.Position

    local rootLinear = root.AssemblyLinearVelocity.Magnitude
    local rootAngular = root.AssemblyAngularVelocity.Magnitude
    local bodyLinear, bodyAngular = maxBodyVelocity(char)

    if grounded(char, hum, root)
        and rootLinear < 34
        and rootAngular < 18
        and bodyLinear < 45
        and bodyAngular < 24 then
        if now - lastSafeAt >= 0.08 then
            lastSafeCFrame = root.CFrame
            lastSafeAt = now
        end
    end

    local fallenHeight = Workspace.FallenPartsDestroyHeight
    local belowMap = typeof(fallenHeight) == "number" and root.Position.Y < fallenHeight + 35
    local suspicious = rootLinear > VELOCITY_LIMIT
        or rootAngular > ANGULAR_LIMIT
        or bodyLinear > VELOCITY_LIMIT * 1.15
        or bodyAngular > ANGULAR_LIMIT * 1.15
        or displacement > DISPLACEMENT_LIMIT
        or belowMap

    if suspicious then
        recover(char, hum, root)
    end
end)

shared.YokaiSimpleAntiFlingHeartbeat = RunService.Heartbeat:Connect(function()
    if enabled then suppressForeignCollision() end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if enabled then task.delay(0.15, suppressForeignCollision) end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function()
    lastSafeCFrame = nil
    lastSafeAt = 0
    previousPosition = nil
    recoveryUntil = 0
    recoveryCFrame = nil
    if enabled then task.delay(0.35, suppressForeignCollision) end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Simple AntiFling loaded", 3)
end)
