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

-- Visuals V4 is the base Visuals layer.
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

local localFixes = game:HttpGet(BASE .. "LocalRuntimeFixes.lua", true)
local fixesOk, fixesErr = pcall(function()
    loadstring(localFixes)()
end)
if not fixesOk then
    warn("LocalRuntimeFixes failed: " .. tostring(fixesErr))
end

local armFixes = game:HttpGet(BASE .. "ArmMaterialFixes.lua", true)
local armOk, armErr = pcall(function()
    loadstring(armFixes)()
end)
if not armOk then
    warn("ArmMaterialFixes failed: " .. tostring(armErr))
end

local worldFixes = game:HttpGet(BASE .. "LocalWorldFixes.lua", true)
local worldOk, worldErr = pcall(function()
    loadstring(worldFixes)()
end)
if not worldOk then
    warn("LocalWorldFixes failed: " .. tostring(worldErr))
end

local finalLocal = game:HttpGet(BASE .. "FinalLocalVisualFixes.lua", true)
local finalOk, finalErr = pcall(function()
    loadstring(finalLocal)()
end)
if not finalOk then
    warn("FinalLocalVisualFixes failed: " .. tostring(finalErr))
end

local gunColorFix = game:HttpGet(BASE .. "GunChamsColorFix.lua", true)
local gunColorOk, gunColorErr = pcall(function()
    loadstring(gunColorFix)()
end)
if not gunColorOk then
    warn("GunChamsColorFix failed: " .. tostring(gunColorErr))
end

local uiArmFixes = game:HttpGet(BASE .. "UILayoutArmFixes.lua", true)
local uiArmOk, uiArmErr = pcall(function()
    loadstring(uiArmFixes)()
end)
if not uiArmOk then
    warn("UILayoutArmFixes failed: " .. tostring(uiArmErr))
end

local cosmeticFixes = game:HttpGet(BASE .. "CosmeticRuntimeFixes.lua", true)
local cosmeticOk, cosmeticErr = pcall(function()
    loadstring(cosmeticFixes)()
end)
if not cosmeticOk then
    warn("CosmeticRuntimeFixes failed: " .. tostring(cosmeticErr))
end

-- Original ArrowIndicator asset, scaled down only.
local arrowStyle = game:HttpGet(BASE .. "ArrowStyleFix.lua", true)
local arrowOk, arrowErr = pcall(function()
    loadstring(arrowStyle)()
end)
if not arrowOk then
    warn("ArrowStyleFix failed: " .. tostring(arrowErr))
end

local viewmodelAudio = game:HttpGet(BASE .. "ViewmodelAudioFixes.lua", true)
local viewmodelAudioOk, viewmodelAudioErr = pcall(function()
    loadstring(viewmodelAudio)()
end)
if not viewmodelAudioOk then
    warn("ViewmodelAudioFixes failed: " .. tostring(viewmodelAudioErr))
end

-- Shot-driven local tracer only.
local shotTracer = game:HttpGet(BASE .. "ShotDrivenTracerFix.lua", true)
local shotTracerOk, shotTracerErr = pcall(function()
    loadstring(shotTracer)()
end)
if not shotTracerOk then
    warn("ShotDrivenTracerFix failed: " .. tostring(shotTracerErr))
end

-- Attached visual styles integrated into the Visuals window.
local attachedVisuals = game:HttpGet(BASE .. "AttachedVisualsPreview.lua", true)
local attachedVisualsOk, attachedVisualsErr = pcall(function()
    loadstring(attachedVisuals)()
end)
if not attachedVisualsOk then
    warn("AttachedVisualsPreview failed: " .. tostring(attachedVisualsErr))
end

-- Final harmony pass: removes stale duplicate previews and adds local Utility
-- protections. Loaded last so it does not get overwritten by earlier layers.
local harmony = game:HttpGet(BASE .. "RuntimeHarmonyFix.lua", true)
local harmonyOk, harmonyErr = pcall(function()
    loadstring(harmony)()
end)
if not harmonyOk then
    warn("RuntimeHarmonyFix failed: " .. tostring(harmonyErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Runtime harmony failed: " .. tostring(harmonyErr), 8)
    end)
end

-- Final UI-only pass: Visuals opens independently and never closes the other windows.
local visualsIndependent = game:HttpGet(BASE .. "VisualsIndependentWindowFix.lua", true)
local visualsIndependentOk, visualsIndependentErr = pcall(function()
    loadstring(visualsIndependent)()
end)
if not visualsIndependentOk then
    warn("VisualsIndependentWindowFix failed: " .. tostring(visualsIndependentErr))
end

-- Preview/Studio-only wallcheck colors and tracer-origin controls.
local previewControls = game:HttpGet(BASE .. "VisualsPreviewControlsFix.lua", true)
local previewControlsOk, previewControlsErr = pcall(function()
    loadstring(previewControls)()
end)
if not previewControlsOk then
    warn("VisualsPreviewControlsFix failed: " .. tostring(previewControlsErr))
end

-- Definitive Visuals UX pass: one polished preview, configurable Preview/Studio
-- wallcheck colors, a single tracer Origin selector and robust NoMenuFog restore.
-- This intentionally loads last so older UI states cannot override it.
local visualsUX = game:HttpGet(BASE .. "VisualsUXFinalFix.lua", true)
local visualsUXOk, visualsUXErr = pcall(function()
    loadstring(visualsUX)()
end)
if not visualsUXOk then
    warn("VisualsUXFinalFix failed: " .. tostring(visualsUXErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Visuals UX final fix failed: " .. tostring(visualsUXErr), 8)
    end)
end

-- Final safe polish: Utility Rejoin plus Preview/Studio name, corner-fill animation,
-- health palettes/text and wallcheck color behavior. Loaded last by design.
local rejoinPreview = game:HttpGet(BASE .. "UtilityRejoinPreviewPolish.lua", true)
local rejoinPreviewOk, rejoinPreviewErr = pcall(function()
    loadstring(rejoinPreview)()
end)
if not rejoinPreviewOk then
    warn("UtilityRejoinPreviewPolish failed: " .. tostring(rejoinPreviewErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Rejoin/preview polish failed: " .. tostring(rejoinPreviewErr), 8)
    end)
end

-- Stronger local AntiFling and fully customizable safe Skeleton for Preview/Studio.
-- Loaded last so the old AntiFling/Skeleton controls cannot override it.
local defensiveFinal = game:HttpGet(BASE .. "DefensiveAntiFlingSkeletonFix.lua", true)
local defensiveFinalOk, defensiveFinalErr = pcall(function()
    loadstring(defensiveFinal)()
end)
if not defensiveFinalOk then
    warn("DefensiveAntiFlingSkeletonFix failed: " .. tostring(defensiveFinalErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Defensive AntiFling/Skeleton fix failed: " .. tostring(defensiveFinalErr), 8)
    end)
end
