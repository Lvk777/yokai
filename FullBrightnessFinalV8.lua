-- Final single-owner FullBrightness for the bot-practice profile.
-- Replaces older duplicate Fullbright controls and writes Lighting only at the
-- end of the render pipeline so a day/night controller cannot visibly alternate
-- with Yokai between frames.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec = objects.VisualsWindow
local Visuals = VisualsRec and VisualsRec.Api
if not Visuals then return end

local ZWSP = utf8.char(0x200B)
local function clean(v)
    return tostring(v or ""):gsub(ZWSP, "")
end
local function optionName(key)
    return clean(key):gsub("OptionsButton$", "")
end

-- Disable every older Fullbright API before removing its GUI object. Anonymous
-- legacy render connections may still exist, but their API.Enabled state remains
-- false, so they stop writing Lighting properties.
local oldKeys={}
for key,rec in pairs(objects) do
    if rec and rec.Type=="OptionsButton" then
        local n=optionName(key)
        if n=="FullBrightness" or n=="Fullbright" or n=="Full Brightness" then
            table.insert(oldKeys,key)
        end
    end
end
for _,key in ipairs(oldKeys) do
    local rec=objects[key]
    pcall(function()
        if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then
            rec.Api.ToggleButton(false)
        end
    end)
    pcall(function() GuiLibrary.RemoveObject(key) end)
end

pcall(function() RunService:UnbindFromRenderStep("YokaiFullBrightnessFinalV8") end)
local previousFx=Lighting:FindFirstChild("YokaiFullBrightnessFinalV8")
if previousFx then previousFx:Destroy() end

local enabled=false
local strength=72
local fx=nil
local snapshot=nil

local function capture()
    return {
        Brightness=Lighting.Brightness,
        ClockTime=Lighting.ClockTime,
        Ambient=Lighting.Ambient,
        OutdoorAmbient=Lighting.OutdoorAmbient,
        ExposureCompensation=Lighting.ExposureCompensation,
        GlobalShadows=Lighting.GlobalShadows,
        ShadowSoftness=Lighting.ShadowSoftness,
        EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale,
    }
end

local function ensureFx()
    if fx and fx.Parent==Lighting then return fx end
    local old=Lighting:FindFirstChild("YokaiFullBrightnessFinalV8")
    if old and old:IsA("ColorCorrectionEffect") then
        fx=old
    else
        if old then old:Destroy() end
        fx=Instance.new("ColorCorrectionEffect")
        fx.Name="YokaiFullBrightnessFinalV8"
        fx.Parent=Lighting
    end
    return fx
end

local function enforce()
    if not enabled then return end

    local t=math.clamp(strength/100,0,1)
    local ambient=math.floor(150 + 75*t)

    -- The game can keep updating its night cycle; this pass happens after the
    -- normal render priorities, so the visible frame receives only this state.
    Lighting.Brightness=2.4 + 1.1*t
    Lighting.ClockTime=14
    Lighting.Ambient=Color3.fromRGB(ambient,ambient,ambient)
    Lighting.OutdoorAmbient=Color3.fromRGB(ambient,ambient,ambient)
    Lighting.ExposureCompensation=0.15 + 0.45*t
    Lighting.GlobalShadows=false
    Lighting.ShadowSoftness=0
    Lighting.EnvironmentDiffuseScale=1
    Lighting.EnvironmentSpecularScale=1

    local cc=ensureFx()
    cc.Enabled=true
    cc.Brightness=0.06 + 0.18*t
    cc.Contrast=-0.08
    cc.Saturation=0.01
    cc.TintColor=Color3.fromRGB(255,253,249)
end

local function stop()
    pcall(function() RunService:UnbindFromRenderStep("YokaiFullBrightnessFinalV8") end)
    if fx then pcall(function() fx:Destroy() end); fx=nil end
    local old=Lighting:FindFirstChild("YokaiFullBrightnessFinalV8")
    if old then pcall(function() old:Destroy() end) end

    -- Restore once, then immediately give control back to the game's own cycle.
    if snapshot then
        local s=snapshot
        pcall(function() Lighting.Brightness=s.Brightness end)
        pcall(function() Lighting.ClockTime=s.ClockTime end)
        pcall(function() Lighting.Ambient=s.Ambient end)
        pcall(function() Lighting.OutdoorAmbient=s.OutdoorAmbient end)
        pcall(function() Lighting.ExposureCompensation=s.ExposureCompensation end)
        pcall(function() Lighting.GlobalShadows=s.GlobalShadows end)
        pcall(function() Lighting.ShadowSoftness=s.ShadowSoftness end)
        pcall(function() Lighting.EnvironmentDiffuseScale=s.EnvironmentDiffuseScale end)
        pcall(function() Lighting.EnvironmentSpecularScale=s.EnvironmentSpecularScale end)
        snapshot=nil
    end
end

local FullBrightness=Visuals.CreateOptionsButton({
    ["Name"]="FullBrightness",
    ["Function"]=function(v)
        enabled=v
        if v then
            snapshot=capture()
            pcall(function() RunService:UnbindFromRenderStep("YokaiFullBrightnessFinalV8") end)
            -- Run well after Camera/Last so the game's day-night writer cannot be
            -- the final visible writer for the frame.
            RunService:BindToRenderStep("YokaiFullBrightnessFinalV8",Enum.RenderPriority.Last.Value+1000,enforce)
            enforce()
        else
            stop()
        end
    end,
    ["HoverText"]="Stable local daylight/fullbright with one final render owner.",
})

FullBrightness.CreateSlider({
    ["Name"]="Strength",
    ["Min"]=20,
    ["Max"]=100,
    ["Default"]=72,
    ["Function"]=function(v)
        strength=v
        if enabled then enforce() end
    end,
})

-- Keep FullBrightness visible near the other primary Visuals controls.
task.defer(function()
    local rec=nil
    for key,r in pairs(objects) do
        if r and r.Type=="OptionsButton" and optionName(key)=="FullBrightness" then rec=r break end
    end
    if rec and rec.Object then
        pcall(function() rec.Object.Visible=true end)
    end
end)
