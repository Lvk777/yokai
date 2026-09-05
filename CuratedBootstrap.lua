repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local HttpService = game:GetService("HttpService")
local BASE = "https://raw.githubusercontent.com/Lvk777/yokai/refs/heads/custom/curated-yokai-final/"

-- Prefer the whitelist owned by this repository instead of the upstream Askire-ux file.
pcall(function()
    if shared.yokaiwhitelist then
        local raw = game:HttpGet(BASE .. "whitelist2.json", true)
        shared.yokaiwhitelist.WhitelistTable = HttpService:JSONDecode(raw)
        shared.yokaiwhitelist.Loaded = true
    end
end)

-- Protect Yokai's original Render window before CuratedModules trims the other tabs.
local prepatch = game:HttpGet(BASE .. "CuratedPrePatch.lua", true)
loadstring(prepatch)()

local curated = game:HttpGet(BASE .. "CuratedModules.lua", true)
local ok, err = pcall(function()
    loadstring(curated)()
end)

if shared.YokaiCuratedRestoreGuiHooks then
    pcall(shared.YokaiCuratedRestoreGuiHooks)
end

if not ok then
    warn("CuratedModules failed: " .. tostring(err))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Curated modules failed to load: " .. tostring(err), 8)
    end)
end

-- Visuals V3 is the only post-visual layer.
-- LocalVisualTweaks.lua and VisualsV2.lua are intentionally not loaded anymore,
-- because they replaced/collided with original Render module names.
local visualsV3 = game:HttpGet(BASE .. "VisualsV3.lua", true)
local visualOk, visualErr = pcall(function()
    loadstring(visualsV3)()
end)
if not visualOk then
    warn("VisualsV3 failed: " .. tostring(visualErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Visuals V3 failed to load: " .. tostring(visualErr), 8)
    end)
end
