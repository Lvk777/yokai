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
-- ESP (including its original 3D mode) is preserved.
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
