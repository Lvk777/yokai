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

-- GunChams should use one fixed user-selected color. This loads last so saved
-- visibility-color state cannot make the local weapon switch red/green near walls.
local gunColorFix = game:HttpGet(BASE .. "GunChamsColorFix.lua", true)
local gunColorOk, gunColorErr = pcall(function()
    loadstring(gunColorFix)()
end)
if not gunColorOk then
    warn("GunChamsColorFix failed: " .. tostring(gunColorErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "GunChams color fix failed: " .. tostring(gunColorErr), 8)
    end)
end

-- Last-pass UI/self fix: moves NoMenuFog to Utility and replaces SelfChams with
-- stricter local first-person arm detection. It also keeps GunChams single-color.
local uiArmFixes = game:HttpGet(BASE .. "UILayoutArmFixes.lua", true)
local uiArmOk, uiArmErr = pcall(function()
    loadstring(uiArmFixes)()
end)
if not uiArmOk then
    warn("UILayoutArmFixes failed: " .. tostring(uiArmErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Utility/arm fixes failed: " .. tostring(uiArmErr), 8)
    end)
end

-- Final cosmetic-only runtime correction. This deliberately loads after every
-- compatibility layer so SelfChams, muzzle-only BulletTracer and HitSound cannot
-- be overwritten by older implementations.
local cosmeticFixes = game:HttpGet(BASE .. "CosmeticRuntimeFixes.lua", true)
local cosmeticOk, cosmeticErr = pcall(function()
    loadstring(cosmeticFixes)()
end)
if not cosmeticOk then
    warn("CosmeticRuntimeFixes failed: " .. tostring(cosmeticErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Cosmetic runtime fixes failed: " .. tostring(cosmeticErr), 8)
    end)
end

-- Keep the original Arrows logic/asset, only scale the indicator down so the
-- chevrons are smaller and visually thinner like the earlier appearance.
local arrowStyle = game:HttpGet(BASE .. "ArrowStyleFix.lua", true)
local arrowOk, arrowErr = pcall(function()
    loadstring(arrowStyle)()
end)
if not arrowOk then
    warn("ArrowStyleFix failed: " .. tostring(arrowErr))
end

-- Final viewmodel/audio pass. This intentionally loads last and replaces only
-- SelfChams, GunChams and HitSound so weapon changes cannot reintroduce the old
-- arm classification or the game's native hit-confirm sound.
local viewmodelAudio = game:HttpGet(BASE .. "ViewmodelAudioFixes.lua", true)
local viewmodelAudioOk, viewmodelAudioErr = pcall(function()
    loadstring(viewmodelAudio)()
end)
if not viewmodelAudioOk then
    warn("ViewmodelAudioFixes failed: " .. tostring(viewmodelAudioErr))
    pcall(function()
        shared.GuiLibrary["CreateNotification"]("Yokai", "Viewmodel/audio fixes failed: " .. tostring(viewmodelAudioErr), 8)
    end)
end
