-- Final GunChams color correction.
-- Keeps the existing GunChams implementation/glow, but disables visibility-based
-- green/red switching and simplifies the controls to one user-selected color.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local function clean(s)
    return tostring(s):gsub(ZWSP, "")
end

local function findGunRecord()
    for key, rec in pairs(objects) do
        if clean(key) == "GunChamsOptionsButton" then
            return key, rec
        end
    end
end

local gunKey, gunRec = findGunRecord()
if not gunRec then
    warn("GunChamsColorFix: GunChams option not found")
    return
end

local gunRoot = gunRec["Object"]
local function underGun(obj)
    if not gunRoot or not obj or typeof(obj) ~= "Instance" then return false end
    return obj == gunRoot or obj:IsDescendantOf(gunRoot)
end

local function getTexts(root)
    local texts = {}
    if not root or typeof(root) ~= "Instance" then return texts end
    local function add(node)
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            table.insert(texts, node)
        end
    end
    add(root)
    for _, node in ipairs(root:GetDescendants()) do add(node) end
    return texts
end

local function hasText(root, wanted)
    for _, node in ipairs(getTexts(root)) do
        if node.Text == wanted then return true end
    end
    return false
end

local function renameText(root, fromText, toText)
    for _, node in ipairs(getTexts(root)) do
        if node.Text == fromText then node.Text = toText end
    end
end

local removeKeys = {}
local visibilityApi

for key, rec in pairs(objects) do
    if key ~= gunKey and rec and underGun(rec["Object"]) then
        local obj = rec["Object"]
        if hasText(obj, "Visibility Colors") then
            visibilityApi = rec["Api"]
            if visibilityApi and visibilityApi["ToggleButton"] then
                pcall(function() visibilityApi["ToggleButton"](false) end)
            end
            table.insert(removeKeys, key)
        elseif hasText(obj, "Occluded Color") or hasText(obj, "Preview State") then
            table.insert(removeKeys, key)
        elseif hasText(obj, "Visible Color") then
            renameText(obj, "Visible Color", "Color")
        end
    end
end

-- Force the callback once more after profile/config state has had a chance to settle.
if visibilityApi and visibilityApi["ToggleButton"] then
    task.defer(function()
        pcall(function() visibilityApi["ToggleButton"](false) end)
    end)
    task.delay(0.5, function()
        pcall(function() visibilityApi["ToggleButton"](false) end)
    end)
end

-- Remove only the visibility-specific controls from the UI/config registry.
for _, key in ipairs(removeKeys) do
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end

-- Also catch any label that may be nested directly in the GunChams option frame
-- rather than registered separately.
if gunRoot and typeof(gunRoot) == "Instance" then
    renameText(gunRoot, "Visible Color", "Color")
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "GunChams fixed: single selected color", 3)
end)
