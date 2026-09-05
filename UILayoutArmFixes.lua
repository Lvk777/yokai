-- Final layout/self-only fixes.
-- Moves NoMenuFog to Utility, keeps GunChams on one fixed color, and improves
-- local first-person arm detection without revealing hidden viewmodel parts.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local VisualsRec = objects["VisualsWindow"]
local UtilityRec = objects["UtilityWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local Utility = UtilityRec and UtilityRec["Api"]
if not Visuals or not Utility then
    warn("UILayoutArmFixes: Visuals/Utility missing")
    return
end

local function clean(value)
    return tostring(value):gsub(ZWSP, "")
end

local function optionNameFromKey(key)
    return clean(key):gsub("OptionsButton$", "")
end

local function removeNormalizedOption(name)
    local toRemove = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionNameFromKey(key) == name then
            table.insert(toRemove, key)
        end
    end
    for _, key in ipairs(toRemove) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- ==========================================================================
-- NoMenuFog -> Utility only.
-- ==========================================================================
removeNormalizedOption("NoMenuFog")

local originalBlurSize
pcall(function()
    if GuiLibrary["MainBlur"] then originalBlurSize = GuiLibrary["MainBlur"].Size end
end)

local noMenuFogEnabled = false
local function applyNoMenuFog()
    pcall(function()
        if GuiLibrary["MainBlur"] then
            GuiLibrary["MainBlur"].Size = noMenuFogEnabled and 0 or (originalBlurSize or 25)
        end
        if noMenuFogEnabled then RunService:SetRobloxGuiFocused(false) end
    end)
end

local NoMenuFog = Utility.CreateOptionsButton({
    ["Name"] = "NoMenuFog",
    ["Function"] = function(v)
        noMenuFogEnabled = v
        applyNoMenuFog()
    end,
})

-- ==========================================================================
-- SelfChams: only visible local arms/hands in first person.
-- ==========================================================================
removeNormalizedOption("SelfChams")
pcall(function() RunService:UnbindFromRenderStep("YokaiArmMaterialFix") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiLocalSelfChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiFinalSelfChams") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiUILayoutArmChams") end)

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

local selfEnabled = false
local selfMaterial = "ForceField"
local selfColor = Color3.fromRGB(119,120,255)
local partState = setmetatable({}, {__mode="k"})
local textureState = setmetatable({}, {__mode="k"})
local meshState = setmetatable({}, {__mode="k"})
local surfaceState = setmetatable({}, {__mode="k"})

local function camera()
    return Workspace.CurrentCamera
end

local function isFirstPerson()
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = camera()
    return head and cam and (cam.CFrame.Position - head.Position).Magnitude <= 1.5 or false
end

local armWords = {"arm","hand","forearm","wrist","glove","sleeve","skin"}
local weaponWords = {"gun","weapon","barrel","muzzle","magazine","mag","scope","sight","bolt","ammo","bullet","receiver","stock","grip","slide","trigger","optic","rail"}

local function containsWord(name, words)
    local n = tostring(name):lower()
    for _, word in ipairs(words) do
        if n:find(word, 1, true) then return true end
    end
    return false
end

local function ancestorContains(part, words)
    local cam = camera()
    local cur = part.Parent
    while cur and cur ~= cam do
        if containsWord(cur.Name, words) then return true end
        cur = cur.Parent
    end
    return false
end

local function effectivelyVisible(part)
    -- Never change visibility here. We only style parts that the game already draws.
    return part.Transparency < 0.98 and part.LocalTransparencyModifier < 0.98
end

local function clearlyWeaponPart(part)
    if part:FindFirstAncestorWhichIsA("Tool") then return true end
    if containsWord(part.Name, weaponWords) then return true end
    if ancestorContains(part, weaponWords) then return true end
    return false
end

local function namedArmPart(part)
    return containsWord(part.Name, armWords) or ancestorContains(part, armWords)
end

local function lowerScreenFallback(part)
    local cam = camera()
    if not cam or not part:IsDescendantOf(cam) or clearlyWeaponPart(part) or not effectivelyVisible(part) then return false end

    -- Some FPS viewmodels use generic MeshPart names for arms. In that case,
    -- accept only visible non-weapon parts rendered in the lower half of screen.
    local ok, pos, onScreen = pcall(function()
        local p, visible = cam:WorldToViewportPoint(part.Position)
        return p, visible
    end)
    if not ok or not onScreen or pos.Z <= 0 then return false end
    local vp = cam.ViewportSize
    if vp.X <= 0 or vp.Y <= 0 then return false end
    if pos.Y < vp.Y * 0.43 then return false end

    -- Reject tiny decorative pieces and huge hidden shells.
    local mag = part.Size.Magnitude
    if mag < 0.35 or mag > 8 then return false end
    return true
end

local function wantedInFirstPerson(part)
    local cam = camera()
    local char = LocalPlayer.Character
    if not effectivelyVisible(part) then return false end

    if cam and part:IsDescendantOf(cam) then
        if clearlyWeaponPart(part) then return false end
        return namedArmPart(part) or lowerScreenFallback(part)
    end

    if char and part:IsDescendantOf(char) then
        if part:FindFirstAncestorWhichIsA("Tool") then return false end
        return namedArmPart(part)
    end

    return false
end

local function wantedInThirdPerson(part)
    local char = LocalPlayer.Character
    return char and part:IsDescendantOf(char)
        and part.Name ~= "HumanoidRootPart"
        and not part:FindFirstAncestorWhichIsA("Tool")
        and effectivelyVisible(part)
end

local function rememberPart(part)
    if partState[part] then return end
    local variant
    pcall(function() variant = part.MaterialVariant end)
    partState[part] = {
        Material = part.Material,
        MaterialVariant = variant,
        Color = part.Color,
        CastShadow = part.CastShadow,
        TextureID = part:IsA("MeshPart") and part.TextureID or nil,
    }
end

local function hideSurfaceLayers(part)
    for _, obj in ipairs(part:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if textureState[obj] == nil then textureState[obj] = obj.Transparency end
            obj.Transparency = 1
        elseif obj:IsA("SpecialMesh") then
            if meshState[obj] == nil then meshState[obj] = obj.TextureId end
            obj.TextureId = ""
        elseif obj:IsA("SurfaceAppearance") then
            if surfaceState[obj] == nil then surfaceState[obj] = obj.Parent end
            obj.Parent = nil
        end
    end
end

local function restoreLayersFor(part)
    for obj, value in pairs(textureState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.Transparency = value end)
            textureState[obj] = nil
        end
    end
    for obj, value in pairs(meshState) do
        if obj and obj.Parent and obj:IsDescendantOf(part) then
            pcall(function() obj.TextureId = value end)
            meshState[obj] = nil
        end
    end
    for obj, parent in pairs(surfaceState) do
        if obj and parent then
            pcall(function() obj.Parent = parent end)
            surfaceState[obj] = nil
        end
    end
end

local function stylePart(part)
    rememberPart(part)
    part.Material = materialMap[selfMaterial] or Enum.Material.ForceField
    pcall(function() part.MaterialVariant = "" end)
    part.Color = selfColor
    part.CastShadow = false
    -- Deliberately do NOT alter Transparency/LocalTransparencyModifier.
    if part:IsA("MeshPart") then part.TextureID = "" end
    hideSurfaceLayers(part)
end

local function restorePart(part, forget)
    local state = partState[part]
    if not state or not part or not part.Parent then return end
    pcall(function()
        part.Material = state.Material
        if state.MaterialVariant ~= nil then part.MaterialVariant = state.MaterialVariant end
        part.Color = state.Color
        part.CastShadow = state.CastShadow
        if part:IsA("MeshPart") and state.TextureID ~= nil then part.TextureID = state.TextureID end
    end)
    restoreLayersFor(part)
    if forget then partState[part] = nil end
end

local function restoreAll()
    for part in pairs(partState) do restorePart(part, true) end
    for obj, value in pairs(textureState) do if obj and obj.Parent then pcall(function() obj.Transparency=value end) end textureState[obj]=nil end
    for obj, value in pairs(meshState) do if obj and obj.Parent then pcall(function() obj.TextureId=value end) end meshState[obj]=nil end
    for obj, parent in pairs(surfaceState) do if obj and parent then pcall(function() obj.Parent=parent end) end surfaceState[obj]=nil end
end

local function applySelf()
    if not selfEnabled then return end
    local fp = isFirstPerson()
    local wanted = {}
    local cam = camera()
    local char = LocalPlayer.Character

    if fp then
        if cam then
            for _, obj in ipairs(cam:GetDescendants()) do
                if obj:IsA("BasePart") and wantedInFirstPerson(obj) then wanted[obj] = true end
            end
        end
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") and wantedInFirstPerson(obj) then wanted[obj] = true end
            end
        end
    elseif char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and wantedInThirdPerson(obj) then wanted[obj] = true end
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
        selfEnabled = v
        if v then applySelf() else restoreAll() end
    end,
})
SelfChams.CreateDropdown({
    ["Name"] = "Material",
    ["List"] = materialList,
    ["Function"] = function(v) selfMaterial=v if selfEnabled then applySelf() end end,
})
SelfChams.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) selfColor=Color3.fromHSV(h,s,v) if selfEnabled then applySelf() end end,
})

RunService:BindToRenderStep("YokaiUILayoutArmChams", Enum.RenderPriority.Camera.Value + 140, function()
    if selfEnabled then applySelf() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    restoreAll()
    task.wait(.45)
    if selfEnabled then applySelf() end
end)

-- ==========================================================================
-- GunChams: keep a single color. Do not reintroduce visible/occluded settings.
-- ==========================================================================
local function findGunRecord()
    for key, rec in pairs(objects) do
        if optionNameFromKey(key) == "GunChams" then return rec end
    end
end
local gunRec = findGunRecord()
if gunRec and gunRec["Object"] then
    -- Best-effort cleanup in case an old profile/session re-created visibility controls.
    local removeKeys = {}
    for key, rec in pairs(objects) do
        if key ~= "GunChamsOptionsButton" and rec and rec["Object"] and rec["Object"]:IsDescendantOf(gunRec["Object"]) then
            local texts = {}
            if rec["Object"]:IsA("TextLabel") or rec["Object"]:IsA("TextButton") then table.insert(texts,rec["Object"]) end
            for _, node in ipairs(rec["Object"]:GetDescendants()) do
                if node:IsA("TextLabel") or node:IsA("TextButton") then table.insert(texts,node) end
            end
            for _, node in ipairs(texts) do
                if node.Text == "Visibility Colors" or node.Text == "Occluded Color" or node.Text == "Preview State" then
                    table.insert(removeKeys,key)
                    break
                elseif node.Text == "Visible Color" then
                    node.Text = "Color"
                end
            end
        end
    end
    for _, key in ipairs(removeKeys) do pcall(function() GuiLibrary["RemoveObject"](key) end) end
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Utility/arm layout fixes loaded", 3)
end)
