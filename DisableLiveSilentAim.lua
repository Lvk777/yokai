-- Safety/compatibility patch for live executor profiles.
-- Removes the legacy SilentAim module that can trigger game-side protections.
-- Does not bypass anti-cheat and does not replace it with hidden hooks.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local function clean(v)
    return tostring(v):gsub(ZWSP, "")
end

local function optionName(key)
    return clean(key):gsub("OptionsButton$", "")
end

local combat = objects["CombatWindow"]
local function underCombat(rec)
    if not rec or not rec.Object or not combat then return false end
    for _,root in ipairs({combat.Object, combat.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then
            return true
        end
    end
    return false
end

local removed = false
local keys = {}
for key,rec in pairs(objects) do
    if rec and rec.Type=="OptionsButton" and optionName(key)=="SilentAim" and underCombat(rec) then
        table.insert(keys,key)
    end
end

for _,key in ipairs(keys) do
    local rec = objects[key]
    pcall(function()
        if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then
            rec.Api.ToggleButton(false)
        end
    end)
    pcall(function()
        GuiLibrary["RemoveObject"](key)
    end)
    removed = true
end

-- Clean up common stale render bindings from prior experimental SilentAim layers.
for _,name in ipairs({
    "YokaiBotSilentAim",
    "YokaiGunTestingSilentAim",
    "YokaiGunTestingSilentAimV2",
    "YokaiGunTestingSilentAimV3",
    "YokaiSilentAim",
}) do
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep(name) end)
end

if removed then
    pcall(function()
        GuiLibrary["CreateNotification"]("Yokai", "Legacy SilentAim disabled for live compatibility", 4)
    end)
end
