-- Compatibility guard for live games with anti-cheat.
-- Removes modules that install __namecall / kick-block hooks. This does not bypass detection;
-- it prevents Yokai from installing those hooks in the first place.

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

local blocked = {
    SilentAim = true,
    ClientKickDisable = true,
}

local keys = {}
for key, rec in pairs(objects) do
    if rec and rec.Type == "OptionsButton" and blocked[optionName(key)] then
        table.insert(keys, key)
    end
end

for _, key in ipairs(keys) do
    local rec = objects[key]
    pcall(function()
        if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then
            rec.Api.ToggleButton(false)
        end
    end)
    pcall(function()
        GuiLibrary["RemoveObject"](key)
    end)
end

for _, name in ipairs({
    "YokaiBotSilentAim",
    "YokaiGunTestingSilentAim",
    "YokaiGunTestingSilentAimV2",
    "YokaiGunTestingSilentAimV3",
    "YokaiSilentAim",
}) do
    pcall(function()
        game:GetService("RunService"):UnbindFromRenderStep(name)
    end)
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Unsafe client hook modules disabled", 3)
end)
