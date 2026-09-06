-- Clears legacy Combat option rows before the Gun Testing V3 integration rebuilds
-- the bot-practice Combat panel. UI cleanup only; does not touch other windows.
repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local RunService=game:GetService("RunService")
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec=objects.CombatWindow
if not CombatRec then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP,"") end
local function under(rec)
    if not rec or not rec.Object then return false end
    for _,root in ipairs({CombatRec.Object,CombatRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end

-- Disable known render-step owners from previous Combat revisions so they do not
-- keep doing work after their menu row is removed. V3 recreates its own Aimbot.
for _,name in ipairs({
    "YokaiBotAimbot","YokaiGunTestingAimbotV2","YokaiGunTestingAimbotV3",
    "YokaiOwnerBotV2Aimbot","YokaiOwnerBotV3Aimbot","YokaiOwnerBotNoRecoilV1",
    "YokaiGunTestingNoRecoil","YokaiBotSilentAim"
}) do pcall(function() RunService:UnbindFromRenderStep(name) end) end

local keys={}
for key,rec in pairs(objects) do
    if rec and rec.Type=="OptionsButton" and under(rec) then
        table.insert(keys,key)
    end
end
for _,key in ipairs(keys) do
    local rec=objects[key]
    pcall(function()
        if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
    end)
    pcall(function() GuiLibrary.RemoveObject(key) end)
end

shared.YokaiGunTestingCombatResetV16=true
