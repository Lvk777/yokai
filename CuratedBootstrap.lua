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

-- First-person local FOV + initial SelfChams runtime correction.
local localFixes = game:HttpGet(BASE .. "LocalRuntimeFixes.lua", true)
local fixesOk, fixesErr = pcall(function()
    loadstring(localFixes)()
end)
if not fixesOk then
    warn("LocalRuntimeFixes failed: " .. tostring(fixesErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Local runtime fixes failed: " .. tostring(fixesErr), 8)
    end)
end

-- Final SelfChams material pass. Loaded after LocalRuntimeFixes so it can replace
-- that SelfChams control and force actual Roblox materials on arms/viewmodels.
local armFixes = game:HttpGet(BASE .. "ArmMaterialFixes.lua", true)
local armOk, armErr = pcall(function()
    loadstring(armFixes)()
end)
if not armOk then
    warn("ArmMaterialFixes failed: " .. tostring(armErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Arm material fixes failed: " .. tostring(armErr), 8)
    end)
end

-- Final local World/Visual patch: local-only BulletTracer, HitSound in World with
-- preview/presets, World FOV removal, and optional GunChams glow.
local worldFixes = game:HttpGet(BASE .. "LocalWorldFixes.lua", true)
local worldOk, worldErr = pcall(function()
    loadstring(worldFixes)()
end)
if not worldOk then
    warn("LocalWorldFixes failed: " .. tostring(worldErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Local World fixes failed: " .. tostring(worldErr), 8)
    end)
end

-- Isolated final patch requested after runtime screenshots. This intentionally
-- replaces only SelfChams, ChangeSkydome and BulletTracer, leaving every other
-- module untouched. It must load last so earlier compatibility patches cannot
-- overwrite these three controls.
local finalLocal = game:HttpGet(BASE .. "FinalLocalVisualFixes.lua", true)
local finalOk, finalErr = pcall(function()
    loadstring(finalLocal)()
end)
if not finalOk then
    warn("FinalLocalVisualFixes failed: " .. tostring(finalErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Final local visual fixes failed: " .. tostring(finalErr), 8)
    end)
end
