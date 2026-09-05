repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local HttpService = game:GetService("HttpService")

-- Prefer the whitelist owned by this repository instead of the upstream Askire-ux file.
pcall(function()
    if shared.yokaiwhitelist then
        local raw = game:HttpGet("https://raw.githubusercontent.com/Lvk777/yokai/custom/curated-yokai-final/whitelist2.json", true)
        shared.yokaiwhitelist.WhitelistTable = HttpService:JSONDecode(raw)
        shared.yokaiwhitelist.Loaded = true
    end
end)

local curated = game:HttpGet("https://raw.githubusercontent.com/Lvk777/yokai/custom/curated-yokai-final/CuratedModules.lua", true)
loadstring(curated)()
