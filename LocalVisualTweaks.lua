-- Local-only visual / quality-of-life module pack.
-- Intentionally does not target, reveal, or modify other players.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"]
local Render = objects["RenderWindow"] and objects["RenderWindow"]["Api"]
local Utility = objects["UtilityWindow"] and objects["UtilityWindow"]["Api"]
local World = objects["WorldWindow"] and objects["WorldWindow"]["Api"]

if not (Render and Utility and World) then
    warn("LocalVisualTweaks: Yokai windows were not found")
    return
end

local function removeModule(name)
    local key = name .. "OptionsButton"
    local obj = objects[key]
    if not obj then return end
    pcall(function()
        if obj["Api"] and obj["Api"]["Enabled"] then
            obj["Api"]["ToggleButton"](false)
        end
    end)
    pcall(function()
        GuiLibrary["RemoveObject"](key)
    end)
end

-- Replace the old lighting toggles so Brightness never forces daytime.
removeModule("FullBrightness")
removeModule("Night")

-- =========================
-- LOCAL CHAMS
-- =========================
local localChamsEnabled = false
local localChamsMaterialName = "ForceField"
local localChamsColor = Color3.fromRGB(255, 110, 190)
local localChamsTransparency = 0.2
local localPartState = {}

local materialMap = {
    ForceField = Enum.Material.ForceField,
    Neon = Enum.Material.Neon,
    SmoothPlastic = Enum.Material.SmoothPlastic,
    Glass = Enum.Material.Glass,
    Foil = Enum.Material.Foil,
    Metal = Enum.Material.Metal,
    Plastic = Enum.Material.Plastic,
}

local function rememberLocalPart(part)
    if localPartState[part] then return end
    localPartState[part] = {
        Material = part.Material,
        Color = part.Color,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
    }
end

local function shouldStyleLocalPart(part, character)
    return part:IsA("BasePart")
        and part.Parent == character
        and part.Name ~= "HumanoidRootPart"
end

local function applyLocalChams()
    local character = LocalPlayer.Character
    if not character then return end

    for _, child in ipairs(character:GetChildren()) do
        if shouldStyleLocalPart(child, character) then
            rememberLocalPart(child)
            if localChamsEnabled then
                child.Material = materialMap[localChamsMaterialName] or Enum.Material.ForceField
                child.Color = localChamsColor
                child.LocalTransparencyModifier = localChamsTransparency
            else
                local state = localPartState[child]
                if state then
                    child.Material = state.Material
                    child.Color = state.Color
                    child.LocalTransparencyModifier = state.LocalTransparencyModifier
                end
            end
        end
    end
end

local function restoreLocalChams()
    for part, state in pairs(localPartState) do
        if part and part.Parent then
            pcall(function()
                part.Material = state.Material
                part.Color = state.Color
                part.LocalTransparencyModifier = state.LocalTransparencyModifier
            end)
        end
    end
    table.clear(localPartState)
end

local SelfChams
SelfChams = Render.CreateOptionsButton({
    ["Name"] = "LocalChams",
    ["Function"] = function(enabled)
        localChamsEnabled = enabled
        if enabled then
            applyLocalChams()
        else
            restoreLocalChams()
        end
    end,
})
SelfChams.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = {"ForceField", "Neon", "SmoothPlastic", "Glass", "Foil", "Metal", "Plastic"},
    ["Function"] = function(value)
        localChamsMaterialName = value
        if localChamsEnabled then applyLocalChams() end
    end,
})
SelfChams.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h, s, v)
        localChamsColor = Color3.fromHSV(h, s, v)
        if localChamsEnabled then applyLocalChams() end
    end,
})
SelfChams.CreateSlider({
    ["Name"] = "Transparency",
    ["Min"] = 0,
    ["Max"] = 100,
    ["Default"] = 20,
    ["Function"] = function(value)
        localChamsTransparency = math.clamp(value / 100, 0, 1)
        if localChamsEnabled then applyLocalChams() end
    end,
})

LocalPlayer.CharacterAdded:Connect(function()
    table.clear(localPartState)
    task.wait(0.4)
    if localChamsEnabled then applyLocalChams() end
end)

-- =========================
-- FOV CHANGER (LOCAL CAMERA)
-- =========================
local fovEnabled = false
local desiredFov = 70
local cameraOriginalFov = setmetatable({}, {__mode = "k"})

local function currentCamera()
    return Workspace.CurrentCamera
end

local function rememberCamera(cam)
    if cam and cameraOriginalFov[cam] == nil then
        cameraOriginalFov[cam] = cam.FieldOfView
    end
end

local function applyFov()
    local cam = currentCamera()
    if not cam then return end
    rememberCamera(cam)
    if fovEnabled then
        cam.FieldOfView = math.clamp(desiredFov, 40, 120)
    else
        cam.FieldOfView = cameraOriginalFov[cam] or 70
    end
end

local FOVChanger
FOVChanger = Render.CreateOptionsButton({
    ["Name"] = "FOVChanger",
    ["Function"] = function(enabled)
        fovEnabled = enabled
        applyFov()
    end,
})
FOVChanger.CreateSlider({
    ["Name"] = "Field Of View",
    ["Min"] = 40,
    ["Max"] = 120,
    ["Default"] = 70,
    ["Function"] = function(value)
        desiredFov = value
        if fovEnabled then applyFov() end
    end,
})

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait()
    applyFov()
end)

-- =========================
-- NIGHT + BRIGHTNESS
-- =========================
local lightingOriginal = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    ExposureCompensation = Lighting.ExposureCompensation,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
}

local originalSky = Lighting:FindFirstChildOfClass("Sky")
local skyOriginal = originalSky and {
    StarCount = originalSky.StarCount,
    MoonAngularSize = originalSky.MoonAngularSize,
    SunAngularSize = originalSky.SunAngularSize,
    CelestialBodiesShown = originalSky.CelestialBodiesShown,
} or nil

local nightEnabled = false
local brightnessEnabled = false
local brightnessLevel = 3
local exposureBoost = 0.5
local nightPreset = "Starry"

local nightPresets = {
    ["Starry"] = {
        ClockTime = 0,
        Ambient = Color3.fromRGB(88, 94, 125),
        OutdoorAmbient = Color3.fromRGB(55, 63, 95),
        Top = Color3.fromRGB(15, 25, 55),
        Bottom = Color3.fromRGB(8, 12, 30),
        Stars = 3000,
        Moon = 10,
        Celestial = true,
    },
    ["Deep Blue"] = {
        ClockTime = 1,
        Ambient = Color3.fromRGB(58, 76, 118),
        OutdoorAmbient = Color3.fromRGB(35, 48, 82),
        Top = Color3.fromRGB(7, 28, 75),
        Bottom = Color3.fromRGB(4, 12, 40),
        Stars = 2200,
        Moon = 8,
        Celestial = true,
    },
    ["Purple Night"] = {
        ClockTime = 0.5,
        Ambient = Color3.fromRGB(100, 70, 125),
        OutdoorAmbient = Color3.fromRGB(61, 40, 88),
        Top = Color3.fromRGB(52, 20, 82),
        Bottom = Color3.fromRGB(22, 10, 46),
        Stars = 2600,
        Moon = 9,
        Celestial = true,
    },
    ["Moonless"] = {
        ClockTime = 0,
        Ambient = Color3.fromRGB(50, 54, 72),
        OutdoorAmbient = Color3.fromRGB(28, 32, 48),
        Top = Color3.fromRGB(5, 8, 18),
        Bottom = Color3.fromRGB(2, 4, 10),
        Stars = 1400,
        Moon = 0,
        Celestial = true,
    },
    ["Soft Night"] = {
        ClockTime = 2,
        Ambient = Color3.fromRGB(116, 122, 145),
        OutdoorAmbient = Color3.fromRGB(84, 91, 116),
        Top = Color3.fromRGB(32, 46, 78),
        Bottom = Color3.fromRGB(18, 26, 48),
        Stars = 1800,
        Moon = 12,
        Celestial = true,
    },
}

local function getSky()
    return Lighting:FindFirstChildOfClass("Sky")
end

local function restoreSky()
    local sky = getSky()
    if not (sky and skyOriginal) then return end
    sky.StarCount = skyOriginal.StarCount
    sky.MoonAngularSize = skyOriginal.MoonAngularSize
    sky.SunAngularSize = skyOriginal.SunAngularSize
    sky.CelestialBodiesShown = skyOriginal.CelestialBodiesShown
end

local function applyLightingState()
    if nightEnabled then
        local preset = nightPresets[nightPreset] or nightPresets.Starry
        Lighting.ClockTime = preset.ClockTime
        Lighting.Ambient = preset.Ambient
        Lighting.OutdoorAmbient = preset.OutdoorAmbient
        Lighting.ColorShift_Top = preset.Top
        Lighting.ColorShift_Bottom = preset.Bottom

        local sky = getSky()
        if sky then
            sky.StarCount = preset.Stars
            sky.MoonAngularSize = preset.Moon
            sky.SunAngularSize = 0
            sky.CelestialBodiesShown = preset.Celestial
        end
    else
        Lighting.ClockTime = lightingOriginal.ClockTime
        Lighting.Ambient = lightingOriginal.Ambient
        Lighting.OutdoorAmbient = lightingOriginal.OutdoorAmbient
        Lighting.ColorShift_Top = lightingOriginal.ColorShift_Top
        Lighting.ColorShift_Bottom = lightingOriginal.ColorShift_Bottom
        restoreSky()
    end

    -- Brightness is deliberately independent from ClockTime / sky state.
    if brightnessEnabled then
        Lighting.Brightness = brightnessLevel
        Lighting.ExposureCompensation = lightingOriginal.ExposureCompensation + exposureBoost
    elseif nightEnabled then
        Lighting.Brightness = 1.55
        Lighting.ExposureCompensation = lightingOriginal.ExposureCompensation + 0.05
    else
        Lighting.Brightness = lightingOriginal.Brightness
        Lighting.ExposureCompensation = lightingOriginal.ExposureCompensation
    end
end

local Night
Night = World.CreateOptionsButton({
    ["Name"] = "Night",
    ["Function"] = function(enabled)
        nightEnabled = enabled
        applyLightingState()
    end,
})
Night.CreateDropdown({
    ["Name"] = "Night Sky",
    ["List"] = {"Starry", "Deep Blue", "Purple Night", "Moonless", "Soft Night"},
    ["Function"] = function(value)
        nightPreset = value
        if nightEnabled then applyLightingState() end
    end,
})

local Brightness
Brightness = World.CreateOptionsButton({
    ["Name"] = "Brightness",
    ["Function"] = function(enabled)
        brightnessEnabled = enabled
        applyLightingState()
    end,
})
Brightness.CreateSlider({
    ["Name"] = "Level",
    ["Min"] = 1,
    ["Max"] = 6,
    ["Default"] = 3,
    ["Function"] = function(value)
        brightnessLevel = value
        if brightnessEnabled then applyLightingState() end
    end,
})
Brightness.CreateSlider({
    ["Name"] = "Exposure",
    ["Min"] = 0,
    ["Max"] = 20,
    ["Default"] = 5,
    ["Function"] = function(value)
        exposureBoost = value / 10
        if brightnessEnabled then applyLightingState() end
    end,
})

-- =========================
-- LOCAL INVENTORY VIEWER
-- =========================
local inventoryEnabled = false
local inventoryGui
local inventoryList
local inventoryConnection
local inventoryAccumulator = 0

local function makeInventoryGui()
    if inventoryGui and inventoryGui.Parent then return end

    inventoryGui = Instance.new("ScreenGui")
    inventoryGui.Name = "YokaiLocalInventoryViewer"
    inventoryGui.ResetOnSpawn = false
    inventoryGui.IgnoreGuiInset = false
    inventoryGui.DisplayOrder = 997

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -18, 0, 80)
    frame.Size = UDim2.fromOffset(320, 260)
    frame.BackgroundColor3 = Color3.fromRGB(17, 17, 20)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Parent = inventoryGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 78)
    stroke.Transparency = 0.25
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.new(1, -28, 0, 28)
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(235, 235, 240)
    title.Text = LocalPlayer.Name .. "'s Inventory"
    title.Parent = frame

    local divider = Instance.new("Frame")
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
    divider.BackgroundTransparency = 0.35
    divider.Position = UDim2.fromOffset(12, 44)
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.Parent = frame

    inventoryList = Instance.new("TextLabel")
    inventoryList.Name = "Items"
    inventoryList.BackgroundTransparency = 1
    inventoryList.Position = UDim2.fromOffset(14, 54)
    inventoryList.Size = UDim2.new(1, -28, 1, -68)
    inventoryList.Font = Enum.Font.Code
    inventoryList.TextSize = 14
    inventoryList.TextXAlignment = Enum.TextXAlignment.Left
    inventoryList.TextYAlignment = Enum.TextYAlignment.Top
    inventoryList.TextColor3 = Color3.fromRGB(210, 212, 218)
    inventoryList.RichText = true
    inventoryList.TextWrapped = false
    inventoryList.Text = "No tools equipped."
    inventoryList.Parent = frame

    inventoryGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function readToolAmmo(tool)
    local mag = tool:FindFirstChild("BulletsInMagazine", true)
        or tool:FindFirstChild("Ammo", true)
        or tool:FindFirstChild("Magazine", true)
    local reserve = tool:FindFirstChild("BulletsInReserve", true)
        or tool:FindFirstChild("Reserve", true)

    local function numericValue(obj)
        if not obj then return nil end
        if obj:IsA("IntValue") or obj:IsA("NumberValue") then return obj.Value end
        return nil
    end

    return numericValue(mag), numericValue(reserve)
end

local function collectLocalTools()
    local result = {}
    local seen = {}

    local function addFrom(container, equipped)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and not seen[child] then
                seen[child] = true
                local mag, reserve = readToolAmmo(child)
                table.insert(result, {
                    Name = child.Name,
                    Equipped = equipped,
                    Magazine = mag,
                    Reserve = reserve,
                })
            end
        end
    end

    addFrom(LocalPlayer:FindFirstChildOfClass("Backpack"), false)
    addFrom(LocalPlayer.Character, true)
    table.sort(result, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return result
end

local function refreshLocalInventory()
    if not (inventoryEnabled and inventoryList) then return end
    local tools = collectLocalTools()
    if #tools == 0 then
        inventoryList.Text = "<font color=\"rgb(160,162,170)\">No tools in Backpack / Character.</font>"
        return
    end

    local lines = {}
    for index, item in ipairs(tools) do
        local state = item.Equipped and "<font color=\"rgb(98,220,145)\">[EQUIPPED]</font>" or "[BAG]"
        local ammo = ""
        if item.Magazine ~= nil or item.Reserve ~= nil then
            ammo = string.format("  <font color=\"rgb(120,170,255)\">[%s/%s]</font>", tostring(item.Magazine or "--"), tostring(item.Reserve or "--"))
        end
        lines[#lines + 1] = string.format("%02d -> %s %s%s", index, state, item.Name, ammo)
    end
    inventoryList.Text = table.concat(lines, "\n")
end

local LocalInventory
LocalInventory = Utility.CreateOptionsButton({
    ["Name"] = "LocalInventoryViewer",
    ["Function"] = function(enabled)
        inventoryEnabled = enabled
        if enabled then
            makeInventoryGui()
            inventoryGui.Enabled = true
            refreshLocalInventory()
            if inventoryConnection then inventoryConnection:Disconnect() end
            inventoryAccumulator = 0
            inventoryConnection = RunService.Heartbeat:Connect(function(dt)
                inventoryAccumulator += dt
                if inventoryAccumulator >= 0.35 then
                    inventoryAccumulator = 0
                    refreshLocalInventory()
                end
            end)
        else
            if inventoryConnection then
                inventoryConnection:Disconnect()
                inventoryConnection = nil
            end
            if inventoryGui then inventoryGui.Enabled = false end
        end
    end,
})

-- Defensive restore when the script environment is reloaded.
shared.YokaiLocalVisualCleanup = function()
    pcall(function()
        localChamsEnabled = false
        restoreLocalChams()
    end)
    pcall(function()
        fovEnabled = false
        applyFov()
    end)
    pcall(function()
        nightEnabled = false
        brightnessEnabled = false
        applyLightingState()
    end)
    pcall(function()
        if inventoryConnection then inventoryConnection:Disconnect() end
        if inventoryGui then inventoryGui:Destroy() end
    end)
end
