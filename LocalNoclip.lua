-- Local/self Noclip only. Does not call remotes or bypass anti-cheat systems.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary["ObjectsThatCanBeSaved"] or {}
local MovementRec=objects["MovementWindow"]
local Movement=MovementRec and MovementRec.Api
if not Movement then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP,"") end
local function optionName(key) return clean(key):gsub("OptionsButton$","") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOld(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,MovementRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end
removeOld("Noclip")

local enabled=false
local original=setmetatable({}, {__mode="k"})
local conn

local function restore()
    for part,value in pairs(original) do
        if part and part.Parent then pcall(function() part.CanCollide=value end) end
        original[part]=nil
    end
end

local function step()
    local char=LocalPlayer.Character
    if not char then return end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if original[obj]==nil then original[obj]=obj.CanCollide end
            if obj.CanCollide then obj.CanCollide=false end
        end
    end
end

local Noclip=Movement.CreateOptionsButton({
    ["Name"]="Noclip",
    ["Function"]=function(v)
        enabled=v
        if conn then conn:Disconnect() conn=nil end
        if v then
            step()
            conn=RunService.Stepped:Connect(step)
        else
            restore()
        end
    end,
    ["HoverText"]="Local character collision off while enabled.",
})

LocalPlayer.CharacterAdded:Connect(function()
    restore()
    if enabled then task.wait(.2) step() end
end)
