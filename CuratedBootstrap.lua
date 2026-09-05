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

-- Install temporary GUI hooks before CuratedModules runs so Yokai's original
-- modules can initialize before the curated replacements are applied.
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

-- Compatibility layer kept before V2 so older profiles/settings can be read.
local localVisuals = game:HttpGet(BASE .. "LocalVisualTweaks.lua", true)
local localOk, localErr = pcall(function()
    loadstring(localVisuals)()
end)
if not localOk then
    warn("LocalVisualTweaks failed: " .. tostring(localErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Local visual tweaks failed to load: " .. tostring(localErr), 8)
    end)
end

-- Final visual layer: dedicated Visuals tab, unified ESPs, self chams,
-- smaller arrows, Trail glow, corrected Night/Brightness, extra skydomes,
-- hitsound presets and the replicated inventory viewer.
local visualsV2 = game:HttpGet(BASE .. "VisualsV2.lua", true)
local visualsOk, visualsErr = pcall(function()
    loadstring(visualsV2)()
end)
if not visualsOk then
    warn("VisualsV2 failed: " .. tostring(visualsErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Visuals V2 failed to load: " .. tostring(visualsErr), 8)
    end)
end
