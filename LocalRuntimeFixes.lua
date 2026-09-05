-- Local/self runtime fixes for Yokai curated build.
-- Replaces only the local FOV and SelfChams controls from Visuals V4.
-- No player-targeting logic is added here.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local function removeOption(key)
    local rec = objects[key]
    if not rec then return end
    pcall(function()
        local api = rec["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
    end)
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end

-- Remove V4's local controls before installing the corrected versions.
removeOption("FOVChanger" .. ZWSP .. "OptionsButton")
removeOption("SelfChams" .. ZWSP .. "OptionsButton")

local visualRec = objects["VisualsWindow"]
local Visuals = visualRec and visualRec["Api"]
if not Visuals then
    warn("LocalRuntimeFixes: Visuals window not found")
    return
end

-- --------------------------------------------------------------------------
-- FOV: lock after the camera step so first-person weapon/camera scripts cannot
-- immediately overwrite the configured value.
-- --------------------------------------------------------------------------
local fovEnabled = false
local fovValue = 70
local originalFov = setmetatable({}, {__mode = "k"})

local function currentCamera()
    return Workspace.CurrentCamera
end

local function rememberFov(cam)
    if cam and originalFov[cam] == nil then originalFov[cam] = cam.FieldOfView end
end

local function enforceFov()
    if not fovEnabled then return end
    local cam = currentCamera()
    if not cam then return end
    rememberFov(cam)
    cam.FieldOfView = math.clamp(fovValue, 40, 120)
end

local function startFovLock()
    pcall(function() RunService:UnbindFromRenderStep("YokaiLocalFOVLock") end)
    RunService:BindToRenderStep("YokaiLocalFOVLock", Enum.RenderPriority.Camera.Value + 100, enforceFov)
    enforceFov()
end

local function stopFovLock()
    pcall(function() RunService:UnbindFromRenderStep("YokaiLocalFOVLock") end)
    local cam = currentCamera()
    if cam and originalFov[cam] ~= nil then cam.FieldOfView = originalFov[cam] end
end

local FOV = Visuals.CreateOptionsButton({
    ["Name"] = "FOVChanger",
    ["Function"] = function(v)
        fovEnabled = v
        if v then startFovLock() else stopFovLock() end
    end,
})
FOV.CreateSlider({
    ["Name"] = "FOV",
    ["Min"] = 40,
    ["Max"] = 120,
    ["Default"] = 70,
    ["Function"] = function(v)
        fovValue = v
        if fovEnabled then enforceFov() end
    end,
})

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait()
    local cam = currentCamera()
    if cam then rememberFov(cam) end
    if fovEnabled then startFovLock() end
end)

-- --------------------------------------------------------------------------
-- SelfChams: full local character in third person; arms/hands only while the
-- local camera is in first person. Camera viewmodel arms are included too.
-- --------------------------------------------------------------------------
local materialMap = {
    ForceField = Enum.Material.ForceField,
    Neon = Enum.Material.Neon,
    SmoothPlastic = Enum.Material.SmoothPlastic,
    Glass = Enum.Material.Glass,
    Foil = Enum.Material.Foil,
    Metal = Enum.Material.Metal,
    Plastic = Enum.Material.Plastic,
}
local materialList = {"ForceField", "Neon", "SmoothPlastic", "Glass", "Foil", "Metal", "Plastic"}

local selfEnabled = false
local selfMaterial = "ForceField"
local selfColor = Color3.fromRGB(119, 120, 255)
local selfTransparency = 0.15
local partState = setmetatable({}, {__mode = "k"})
local textureState = setmetatable({}, {__mode = "k"})

local function rememberPart(part)
    if partState[part] then return end
    partState[part] = {
        Material = part.Material,
        Color = part.Color,
        Transparency = part.Transparency,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
        CastShadow = part.CastShadow,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function restorePart(part)
    local state = partState[part]
    if not state or not part or not part.Parent then return end
    pcall(function()
        part.Material = state.Material
        part.Color = state.Color
        part.Transparency = state.Transparency
        part.LocalTransparencyModifier = state.LocalTransparencyModifier
        part.CastShadow = state.CastShadow
        if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
    end)
end

local function rememberTexture(obj)
    if textureState[obj] == nil then textureState[obj] = obj.Transparency end
end

local function restoreTexture(obj)
    local value = textureState[obj]
    if value ~= nil and obj and obj.Parent then pcall(function() obj.Transparency = value end) end
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = currentCamera()
    if not (head and cam) then return false end
    return (cam.CFrame.Position - head.Position).Magnitude <= 1.35
end

local function isArmName(name)
    local n = name:lower()
    return n:find("arm", 1, true) ~= nil or n:find("hand", 1, true) ~= nil
end

local function belongsToLocalViewmodel(part)
    local cam = currentCamera()
    if not cam or not part:IsDescendantOf(cam) then return false end
    if isArmName(part.Name) then return true end
    local cur = part.Parent
    while cur and cur ~= cam do
        local n = cur.Name:lower()
        if n:find("arms", 1, true) or n:find("viewmodel", 1, true) then
            return isArmName(part.Name)
        end
        cur = cur.Parent
    end
    return false
end

local function shouldStylePart(part, firstPerson)
    if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return false end
    if part:FindFirstAncestorWhichIsA("Tool") then return false end

    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) then
        return (not firstPerson) or isArmName(part.Name)
    end

    if firstPerson and belongsToLocalViewmodel(part) then return true end
    return false
end

local function stylePart(part)
    rememberPart(part)
    part.Material = materialMap[selfMaterial] or Enum.Material.ForceField
    part.Color = selfColor
    part.Transparency = selfTransparency
    part.LocalTransparencyModifier = 0
    part.CastShadow = false
    if part:IsA("MeshPart") then part.TextureID = "" end
end

local function applySelf()
    if not selfEnabled then return end
    local firstPerson = isFirstPerson()
    local char = LocalPlayer.Character
    local cam = currentCamera()
    local candidates = {}

    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then candidates[obj] = true end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                rememberTexture(obj)
                if firstPerson then restoreTexture(obj) else obj.Transparency = 1 end
            end
        end
    end
    if firstPerson and cam then
        for _, obj in ipairs(cam:GetDescendants()) do
            if obj:IsA("BasePart") and belongsToLocalViewmodel(obj) then candidates[obj] = true end
        end
    end

    -- Restore any previously styled body part that should no longer be styled
    -- after switching between third and first person.
    for part in pairs(partState) do
        if part and part.Parent and not shouldStylePart(part, firstPerson) then restorePart(part) end
    end

    for part in pairs(candidates) do
        if shouldStylePart(part, firstPerson) then stylePart(part) else restorePart(part) end
    end
end

local function restoreSelf()
    for part in pairs(partState) do restorePart(part) end
    for obj in pairs(textureState) do restoreTexture(obj) end
    table.clear(partState)
    table.clear(textureState)
end

local SelfChams = Visuals.CreateOptionsButton({
    ["Name"] = "SelfChams",
    ["Function"] = function(v)
        selfEnabled = v
        if v then applySelf() else restoreSelf() end
    end,
})
SelfChams.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = materialList,
    ["Function"] = function(v) selfMaterial = v if selfEnabled then applySelf() end end,
})
SelfChams.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h, s, v) selfColor = Color3.fromHSV(h, s, v) if selfEnabled then applySelf() end end,
})
SelfChams.CreateSlider({
    ["Name"] = "Transparency",
    ["Min"] = 0,
    ["Max"] = 90,
    ["Default"] = 15,
    ["Function"] = function(v) selfTransparency = v / 100 if selfEnabled then applySelf() end end,
})

RunService:BindToRenderStep("YokaiLocalSelfChams", Enum.RenderPriority.Camera.Value + 110, function()
    if selfEnabled then applySelf() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    restoreSelf()
    task.wait(0.45)
    if selfEnabled then applySelf() end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Local runtime fixes loaded", 3)
end)
