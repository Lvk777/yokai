-- Final local visual polish for the bot-practice profile.
-- Keeps this layer passive: no metamethod/namecall hooks and no server calls.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local WorldRec = objects["WorldWindow"]
local RenderRec = objects["RenderWindow"]
local Visuals = VisualsRec and VisualsRec.Api
local World = WorldRec and WorldRec.Api
if not (Visuals and World) then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function optionRecord(parentRec,name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and (not parentRec or under(rec,parentRec)) then
            return key,rec
        end
    end
end
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and (not parentRec or under(rec,parentRec)) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- ---------------------------------------------------------------------------
-- FULLBRIGHTNESS: one owner, no RenderStepped property fight.
-- ---------------------------------------------------------------------------
-- Disable/remove every older Fullbright variant first. Their callbacks are toggled
-- off before removal so older render loops stop writing Lighting properties.
for _,name in ipairs({"FullBrightness","Fullbright","Full Brightness"}) do
    removeOption(nil,name)
end

local oldFx=Lighting:FindFirstChild("YokaiStableFullBrightnessV4")
if oldFx then oldFx:Destroy() end

local fullEnabled=false
local fullStrength=28
local fullFx=nil
local function applyFullbright()
    if not fullEnabled then
        if fullFx then fullFx:Destroy(); fullFx=nil end
        local old=Lighting:FindFirstChild("YokaiStableFullBrightnessV4")
        if old then old:Destroy() end
        return
    end
    if not fullFx or not fullFx.Parent then
        fullFx=Instance.new("ColorCorrectionEffect")
        fullFx.Name="YokaiStableFullBrightnessV4"
        fullFx.Parent=Lighting
    end
    -- Post-processing instead of repeatedly fighting Brightness/ClockTime/Ambient.
    -- This is intentionally event-driven so it does not flicker.
    fullFx.Enabled=true
    fullFx.Brightness=math.clamp(fullStrength/100,0,.55)
    fullFx.Contrast=-0.06
    fullFx.Saturation=0.02
    fullFx.TintColor=Color3.fromRGB(255,252,248)
end

local FullBrightness=World.CreateOptionsButton({
    ["Name"]="FullBrightness",
    ["Function"]=function(v) fullEnabled=v; applyFullbright() end,
    ["HoverText"]="Stable local brightness without per-frame Lighting fights.",
})
FullBrightness.CreateSlider({
    ["Name"]="Strength",
    ["Min"]=5,
    ["Max"]=50,
    ["Default"]=28,
    ["Function"]=function(v) fullStrength=v; if fullEnabled then applyFullbright() end end,
})

-- ---------------------------------------------------------------------------
-- VISUAL TRACERS: bot-only, configurable origin/transparency.
-- ---------------------------------------------------------------------------
removeOption(VisualsRec,"Tracers")

local parentGui=(gethui and gethui()) or CoreGui
local oldGui=parentGui:FindFirstChild("YokaiBotVisualTracersV4")
if oldGui then oldGui:Destroy() end
local Overlay=Instance.new("ScreenGui")
Overlay.Name="YokaiBotVisualTracersV4"
Overlay.ResetOnSpawn=false
Overlay.IgnoreGuiInset=true
Overlay.DisplayOrder=998
Overlay.Parent=parentGui

local enabled=false
local originMode="Bottom"
local tracerColor=Color3.fromRGB(255,255,255)
local tracerThickness=1
local tracerTransparency=.10
local fallbackDistance=1800
local lines={}

local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function humanoidOf(model)
    return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") or nil
end
local function rootOf(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local hum=humanoidOf(model)
    return hum and hum.Health>0 and rootOf(model)~=nil
end

local botRoot=Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots") or Workspace
local bots={}
local function register(model) if isBot(model) then bots[model]=true end end
local function seed()
    table.clear(bots)
    for _,d in ipairs(botRoot:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end
    end
end
seed()
botRoot.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(register,d.Parent) end
end)
botRoot.DescendantRemoving:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
end)

local function makeLine(model)
    local f=Instance.new("Frame")
    f.Name="Tracer"
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=tracerColor
    f.BackgroundTransparency=tracerTransparency
    f.Visible=false
    f.Parent=Overlay
    lines[model]=f
    return f
end
local function setLine(line,a,b)
    local delta=b-a
    local len=delta.Magnitude
    if len<1 then line.Visible=false return end
    line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Size=UDim2.fromOffset(len,tracerThickness)
    line.Rotation=math.deg(math.atan2(delta.Y,delta.X))
    line.BackgroundColor3=tracerColor
    line.BackgroundTransparency=tracerTransparency
    line.Visible=true
end
local function startPoint(cam)
    local vp=cam.ViewportSize
    if originMode=="Top" then return Vector2.new(vp.X/2,2) end
    if originMode=="Center" then return vp/2 end
    if originMode=="Cursor" then
        local mouse=UserInputService:GetMouseLocation()
        local inset=GuiService:GetGuiInset()
        return Vector2.new(
            math.clamp(mouse.X-inset.X,0,vp.X),
            math.clamp(mouse.Y-inset.Y,0,vp.Y)
        )
    end
    return Vector2.new(vp.X/2,vp.Y-2)
end

-- Keep the existing V2 Distance option because its slider already controls the
-- global ESP/Chams/Corner/Skeleton distance. We only read that slider's value for
-- this replacement tracer so every visual uses the same limit.
local _,distanceRec=optionRecord(VisualsRec,"Distance")
local function currentDistance()
    if distanceRec then
        local root=distanceRec.Object
        for _,rec in pairs(objects) do
            if rec and rec.Type=="Slider" and rec.Api and typeof(rec.Object)=="Instance" then
                local isChild=false
                pcall(function()
                    isChild=(root and rec.Object:IsDescendantOf(root)) or false
                end)
                local keyText=clean(rec.Object.Name).." "..clean(tostring(rec.Api.Name or ""))
                if isChild or keyText:lower():find("max distance",1,true) then
                    local value=tonumber(rec.Api.Value)
                    if value then return value end
                end
            end
        end
    end
    return fallbackDistance
end

local Tracers=Visuals.CreateOptionsButton({
    ["Name"]="Tracers",
    ["Function"]=function(v)
        enabled=v
        if not v then for _,line in pairs(lines) do line.Visible=false end end
    end,
})
Tracers.CreateDropdown({
    ["Name"]="Origin",
    ["List"]={"Bottom","Top","Cursor","Center"},
    ["Function"]=function(v) originMode=v end,
})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=4,["Default"]=1,["Function"]=function(v) tracerThickness=v end})
Tracers.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=10,["Function"]=function(v) tracerTransparency=v/100 end})

-- Make sure Distance sits immediately below Tracers in the Visuals list.
task.defer(function()
    local _,drec=optionRecord(VisualsRec,"Distance")
    if Tracers.Object and drec and drec.Object then
        pcall(function()
            local base=Tracers.Object.LayoutOrder
            drec.Object.LayoutOrder=base+1
            drec.Object.Visible=true
        end)
    end
end)

RunService:BindToRenderStep("YokaiBotVisualTracersV4",Enum.RenderPriority.Last.Value,function()
    if not enabled then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local start=startPoint(cam)
    local maxDist=currentDistance()
    for model in pairs(bots) do
        local line=lines[model] or makeLine(model)
        if not isBot(model) then
            line.Visible=false
            bots[model]=nil
        else
            local root=rootOf(model)
            local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
            if root and dist<=maxDist then
                local p,on=cam:WorldToViewportPoint(root.Position)
                if on and p.Z>0 then
                    setLine(line,start,Vector2.new(p.X,p.Y))
                else
                    line.Visible=false
                end
            else
                line.Visible=false
            end
        end
    end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Stable FullBrightness + Visual Tracers V4 loaded",3) end)
