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

-- Visuals V4 is the only post-visual layer.
-- Older VisualsV2/V3 and LocalVisualTweaks are intentionally not loaded so
-- they cannot collide with the original Render module names.
local visualsV4 = game:HttpGet(BASE .. "VisualsV4.lua", true)
local visualOk, visualErr = pcall(function()
    loadstring(visualsV4)()
end)
if not visualOk then
    warn("VisualsV4 failed: " .. tostring(visualErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Visuals V4 failed to load: " .. tostring(visualErr), 8)
    end)
end
