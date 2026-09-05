-- Rebuilds SelfChams so material changes are actually visible on avatar/viewmodel arms.
-- Third person: local character. First person: arms/hands/sleeves/gloves only.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then
    warn("ArmMaterialFixes: Visuals window not found")
    return
end

local function removeOption(key)
    local rec = objects[key]
    if not rec then return end
    pcall(function()
        local api = rec["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
    end)
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end
removeOption("SelfChamsOptionsButton")
removeOption("SelfChams" .. utf8.char(0x200B) .. "OptionsButton")

local materialMap = {
    ForceField = Enum.Material.ForceField,
    Neon = Enum.Material.Neon,
    SmoothPlastic = Enum.Material.SmoothPlastic,
    Glass = Enum.Material.Glass,
    Foil = Enum.Material.Foil,
    Metal = Enum.Material.Metal,
    Plastic = Enum.Material.Plastic,
}
local materialList = {"ForceField","Neon","SmoothPlastic","Glass","Foil","Metal","Plastic"}

local enabled = false
local materialName = "ForceField"
local color = Color3.fromRGB(119,120,255)
local transparency = 0.12

local partState = setmetatable({}, {__mode="k"})
local decalState = setmetatable({}, {__mode="k"})
local specialMeshState = setmetatable({}, {__mode="k"})
local surfaceState = setmetatable({}, {__mode="k"})

local function camera()
    return Workspace.CurrentCamera
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = camera()
    if not head or not cam then return false end
    return (cam.CFrame.Position - head.Position).Magnitude <= 1.4
end

local function armish(name)
    local n = name:lower()
    return n:find("arm",1,true) or n:find("hand",1,true) or n:find("glove",1,true) or n:find("sleeve",1,true) or n:find("forearm",1,true)
end

local function weaponish(name)
    local n = name:lower()
    local words = {"gun","weapon","barrel","muzzle","mag","magazine","scope","sight","bolt","ammo","bullet","receiver","stock","grip"}
    for _,w in ipairs(words) do if n:find(w,1,true) then return true end end
    return false
end

local function underNamedArmContainer(part)
    local cam = camera()
    local cur = part.Parent
    while cur and cam and cur ~= cam do
        local n = cur.Name:lower()
        if n:find("arms",1,true) or n:find("hands",1,true) then return true end
        if weaponish(cur.Name) then return false end
        cur = cur.Parent
    end
    return false
end

local function isViewmodelArm(part)
    local cam = camera()
    if not cam or not part:IsDescendantOf(cam) then return false end
    if weaponish(part.Name) then return false end
    if armish(part.Name) then return true end
    return underNamedArmContainer(part)
end

local function desiredPart(part, firstPerson)
    if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return false end
    if part:FindFirstAncestorWhichIsA("Tool") then return false end

    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) then
        if not firstPerson then return true end
        return armish(part.Name)
    end

    return firstPerson and isViewmodelArm(part)
end

local function rememberPart(part)
    if partState[part] then return end
    local materialVariant
    pcall(function() materialVariant = part.MaterialVariant end)
    partState[part] = {
        Material = part.Material,
        MaterialVariant = materialVariant,
        Color = part.Color,
        Transparency = part.Transparency,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
        CastShadow = part.CastShadow,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function hideVisualLayers(part)
    for _,obj in ipairs(part:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if decalState[obj] == nil then decalState[obj] = obj.Transparency end
            obj.Transparency = 1
        elseif obj:IsA("SpecialMesh") then
            if specialMeshState[obj] == nil then specialMeshState[obj] = obj.TextureId end
            obj.TextureId = ""
        elseif obj:IsA("SurfaceAppearance") then
            if surfaceState[obj] == nil then surfaceState[obj] = obj.Parent end
            obj.Parent = nil
        end
    end
end

local function restoreVisualLayers(part)
    for obj,value in pairs(decalState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.Transparency = value end)
            decalState[obj] = nil
        end
    end
    for obj,value in pairs(specialMeshState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.TextureId = value end)
            specialMeshState[obj] = nil
        end
    end
    for obj,parent in pairs(surfaceState) do
        if obj and parent and parent:IsDescendantOf(part) then
            pcall(function() obj.Parent = parent end)
            surfaceState[obj] = nil
        end
    end
end

local function stylePart(part)
    rememberPart(part)
    part.Material = materialMap[materialName] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = color
    part.Transparency = transparency
    part.LocalTransparencyModifier = 0
    part.CastShadow = false
    if part:IsA("MeshPart") then part.TextureID = "" end
    hideVisualLayers(part)
end

local function restorePart(part, forget)
    local state = partState[part]
    if not state or not part or not part.Parent then return end
    pcall(function()
        part.Material = state.Material
        if state.MaterialVariant ~= nil then part.MaterialVariant = state.MaterialVariant end
        part.Color = state.Color
        part.Transparency = state.Transparency
        part.LocalTransparencyModifier = state.LocalTransparencyModifier
        part.CastShadow = state.CastShadow
        if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
    end)
    restoreVisualLayers(part)
    if forget then partState[part] = nil end
end

local function restoreAll()
    for part in pairs(partState) do restorePart(part, true) end
    for obj,value in pairs(decalState) do if obj and obj.Parent then pcall(function() obj.Transparency=value end) end decalState[obj]=nil end
    for obj,value in pairs(specialMeshState) do if obj and obj.Parent then pcall(function() obj.TextureId=value end) end specialMeshState[obj]=nil end
    for obj,parent in pairs(surfaceState) do if obj and parent then pcall(function() obj.Parent=parent end) end surfaceState[obj]=nil end
end

local function apply()
    if not enabled then return end
    local fp = isFirstPerson()
    local wanted = {}
    local char = LocalPlayer.Character
    local cam = camera()

    if char then
        for _,obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and desiredPart(obj, fp) then wanted[obj]=true end
        end
    end
    if fp and cam then
        for _,obj in ipairs(cam:GetDescendants()) do
            if obj:IsA("BasePart") and desiredPart(obj, true) then wanted[obj]=true end
        end
    end

    for part in pairs(partState) do
        if not wanted[part] then restorePart(part, true) end
    end
    for part in pairs(wanted) do stylePart(part) end
end

local SelfChams = Visuals.CreateOptionsButton({
    ["Name"] = "SelfChams",
    ["Function"] = function(v)
        enabled = v
        if v then apply() else restoreAll() end
    end,
})
SelfChams.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = materialList,
    ["Function"] = function(v) materialName=v if enabled then apply() end end,
})
SelfChams.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) color=Color3.fromHSV(h,s,v) if enabled then apply() end end,
})
SelfChams.CreateSlider({
    ["Name"] = "Transparency",
    ["Min"] = 0,
    ["Max"] = 80,
    ["Default"] = 12,
    ["Function"] = function(v) transparency=v/100 if enabled then apply() end end,
})

pcall(function() RunService:UnbindFromRenderStep("YokaiArmMaterialFix") end)
RunService:BindToRenderStep("YokaiArmMaterialFix", Enum.RenderPriority.Camera.Value + 120, function()
    if enabled then apply() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    restoreAll()
    task.wait(.45)
    if enabled then apply() end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","SelfChams material fix loaded",3) end)
