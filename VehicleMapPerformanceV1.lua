-- Vehicle-map local utilities: lightweight Car ESP + reversible FPS Boost.
-- Passive/local only: no remotes, weapon mutation, anti-cheat bypass, or player targeting.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local UtilityRec = objects["UtilityWindow"]
local Visuals = VisualsRec and VisualsRec.Api
local Utility = UtilityRec and UtilityRec.Api
if not Visuals or not Utility then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- ==========================================================================
-- CAR ESP
-- Uses Workspace.Vehicles directly instead of scanning Workspace every frame.
-- ==========================================================================
removeOption(VisualsRec,"Car ESP")
local vehiclesFolder = Workspace:FindFirstChild("Vehicles")
local carEnabled=false
local carColor=Color3.fromRGB(0,220,170)
local carFillTransparency=.82
local carOutlineTransparency=.08
local carMaxDistance=2500
local carShowName=true
local carShowDistance=true
local carShowOccupancy=true
local tracked={}

local function vehicleAnchor(model)
    if not model or not model:IsA("Model") then return nil end
    return model:FindFirstChildWhichIsA("VehicleSeat",true)
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart",true)
end
local function vehiclePosition(model)
    local anchor=vehicleAnchor(model)
    return anchor and anchor.Position or nil
end
local function isVehicleModel(obj)
    if not obj or not obj:IsA("Model") then return false end
    if obj:FindFirstChildWhichIsA("VehicleSeat",true) then return true end
    local n=obj.Name:lower()
    return n:find("truck",1,true) or n:find("sedan",1,true) or n:find("car",1,true) or n:find("vehicle",1,true) or n:find("pickup",1,true)
end
local function displayName(model)
    return tostring(model.Name):gsub("_"," ")
end
local function occupancy(model)
    local seat=model:FindFirstChildWhichIsA("VehicleSeat",true)
    if not seat then return nil end
    local hum=seat.Occupant
    if not hum then return "empty" end
    local char=hum.Parent
    local plr=char and Players:GetPlayerFromCharacter(char)
    return plr and plr.DisplayName or "occupied"
end
local function destroyCar(model)
    local s=tracked[model]
    if not s then return end
    if s.Highlight then pcall(function() s.Highlight:Destroy() end) end
    if s.Billboard then pcall(function() s.Billboard:Destroy() end) end
    tracked[model]=nil
end
local function ensureCar(model)
    if tracked[model] or not isVehicleModel(model) then return end
    local anchor=vehicleAnchor(model)
    if not anchor then return end

    local hi=Instance.new("Highlight")
    hi.Name="YokaiCarESPHighlight"
    hi.Adornee=model
    hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hi.FillColor=carColor
    hi.OutlineColor=carColor
    hi.FillTransparency=carFillTransparency
    hi.OutlineTransparency=carOutlineTransparency
    hi.Enabled=false
    hi.Parent=model

    local bb=Instance.new("BillboardGui")
    bb.Name="YokaiCarESPLabel"
    bb.Adornee=anchor
    bb.AlwaysOnTop=true
    bb.Size=UDim2.fromOffset(220,38)
    bb.StudsOffsetWorldSpace=Vector3.new(0,3.4,0)
    bb.Enabled=false
    bb.Parent=anchor

    local label=Instance.new("TextLabel")
    label.BackgroundTransparency=1
    label.Size=UDim2.fromScale(1,1)
    label.Font=Enum.Font.GothamSemibold
    label.TextSize=12
    label.TextColor3=carColor
    label.TextStrokeTransparency=.45
    label.Text=""
    label.Parent=bb

    tracked[model]={Highlight=hi,Billboard=bb,Label=label,Anchor=anchor}
end
local function seedVehicles()
    if not vehiclesFolder or not vehiclesFolder.Parent then vehiclesFolder=Workspace:FindFirstChild("Vehicles") end
    if not vehiclesFolder then return end
    for _,obj in ipairs(vehiclesFolder:GetChildren()) do if obj:IsA("Model") then ensureCar(obj) end end
end
seedVehicles()
if vehiclesFolder then
    vehiclesFolder.ChildAdded:Connect(function(obj) if obj:IsA("Model") then task.defer(ensureCar,obj) end end)
    vehiclesFolder.ChildRemoved:Connect(function(obj) destroyCar(obj) end)
end
Workspace.ChildAdded:Connect(function(obj)
    if obj.Name=="Vehicles" then
        vehiclesFolder=obj
        task.defer(seedVehicles)
        obj.ChildAdded:Connect(function(v) if v:IsA("Model") then task.defer(ensureCar,v) end end)
        obj.ChildRemoved:Connect(function(v) destroyCar(v) end)
    end
end)

local CarESP=Visuals.CreateOptionsButton({
    ["Name"]="Car ESP",
    ["Function"]=function(v)
        carEnabled=v
        if v then seedVehicles() end
        if not v then
            for _,s in pairs(tracked) do s.Highlight.Enabled=false s.Billboard.Enabled=false end
        end
    end,
    ["HoverText"]="Lightweight vehicle ESP using Workspace.Vehicles only.",
})
CarESP.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) carColor=Color3.fromHSV(h,s,v) end})
CarESP.CreateSlider({["Name"]="Max Distance",["Min"]=100,["Max"]=5000,["Default"]=2500,["Function"]=function(v) carMaxDistance=v end})
CarESP.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=82,["Function"]=function(v) carFillTransparency=v/100 end})
CarESP.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=8,["Function"]=function(v) carOutlineTransparency=v/100 end})
CarESP.CreateToggle({["Name"]="Name",["Default"]=true,["Function"]=function(v) carShowName=v end})
CarESP.CreateToggle({["Name"]="Distance",["Default"]=true,["Function"]=function(v) carShowDistance=v end})
CarESP.CreateToggle({["Name"]="Occupancy",["Default"]=true,["Function"]=function(v) carShowOccupancy=v end})

local carClock=0
RunService.Heartbeat:Connect(function(dt)
    if not carEnabled then return end
    carClock+=dt
    if carClock<.10 then return end
    carClock=0
    local cam=Workspace.CurrentCamera
    if not cam then return end
    for model,s in pairs(tracked) do
        if not model.Parent or not s.Anchor or not s.Anchor.Parent then destroyCar(model) continue end
        local pos=s.Anchor.Position
        local dist=(cam.CFrame.Position-pos).Magnitude
        local show=dist<=carMaxDistance
        s.Highlight.Enabled=show
        s.Billboard.Enabled=show
        s.Highlight.FillColor=carColor
        s.Highlight.OutlineColor=carColor
        s.Highlight.FillTransparency=carFillTransparency
        s.Highlight.OutlineTransparency=carOutlineTransparency
        s.Label.TextColor3=carColor
        if show then
            local bits={}
            if carShowName then table.insert(bits,displayName(model)) end
            if carShowDistance then table.insert(bits,tostring(math.floor(dist+.5)).." studs") end
            if carShowOccupancy then
                local occ=occupancy(model)
                if occ then table.insert(bits,occ) end
            end
            s.Label.Text=table.concat(bits,"  •  ")
        end
    end
end)

-- ==========================================================================
-- FPS BOOST
-- Reversible, chunked application to avoid a big single-frame hitch.
-- Light: post effects + particles. Balanced: also disables CastShadow.
-- Aggressive: also hides Decal/Texture locally.
-- ==========================================================================
removeOption(UtilityRec,"FPS Boost")
local fpsEnabled=false
local fpsMode="Balanced"
local saved=setmetatable({}, {__mode="k"})
local lightingSaved=nil
local applyingToken=0

local function remember(obj,prop)
    local rec=saved[obj]
    if not rec then rec={} saved[obj]=rec end
    if rec[prop]==nil then
        local ok,v=pcall(function() return obj[prop] end)
        if ok then rec[prop]=v end
    end
end
local function setProp(obj,prop,value)
    remember(obj,prop)
    pcall(function() obj[prop]=value end)
end
local function optimizeObject(obj,mode)
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        setProp(obj,"Enabled",false)
    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        if mode~="Light" then setProp(obj,"Enabled",false) end
    elseif obj:IsA("BasePart") then
        if mode=="Balanced" or mode=="Aggressive" then setProp(obj,"CastShadow",false) end
    elseif (obj:IsA("Decal") or obj:IsA("Texture")) and mode=="Aggressive" then
        setProp(obj,"Transparency",1)
    end
end
local function restoreAll()
    applyingToken+=1
    local list={}
    for obj in pairs(saved) do table.insert(list,obj) end
    task.spawn(function()
        for i,obj in ipairs(list) do
            local rec=saved[obj]
            if rec and obj and obj.Parent then
                for prop,value in pairs(rec) do pcall(function() obj[prop]=value end) end
            end
            saved[obj]=nil
            if i%250==0 then task.wait() end
        end
    end)
    if lightingSaved then
        pcall(function() Lighting.GlobalShadows=lightingSaved.GlobalShadows end)
        lightingSaved=nil
    end
end
local function applyBoost()
    applyingToken+=1
    local token=applyingToken
    if not lightingSaved then lightingSaved={GlobalShadows=Lighting.GlobalShadows} end
    if fpsMode~="Light" then Lighting.GlobalShadows=false end
    for _,fx in ipairs(Lighting:GetChildren()) do
        if fx:IsA("PostEffect") then setProp(fx,"Enabled",false) end
    end
    local desc=Workspace:GetDescendants()
    task.spawn(function()
        for i,obj in ipairs(desc) do
            if token~=applyingToken or not fpsEnabled then return end
            optimizeObject(obj,fpsMode)
            if i%250==0 then task.wait() end
        end
    end)
end

local FPS=Utility.CreateOptionsButton({
    ["Name"]="FPS Boost",
    ["Function"]=function(v)
        fpsEnabled=v
        if v then applyBoost() else restoreAll() end
    end,
    ["HoverText"]="Reversible local graphics/effects reduction. No hidden flags or bypasses.",
})
FPS.CreateDropdown({
    ["Name"]="Mode",
    ["List"]={"Light","Balanced","Aggressive"},
    ["Function"]=function(v)
        fpsMode=v
        if fpsEnabled then restoreAll() task.delay(.15,function() if fpsEnabled then applyBoost() end end) end
    end,
})

Workspace.DescendantAdded:Connect(function(obj)
    if fpsEnabled then task.defer(function() if fpsEnabled and obj.Parent then optimizeObject(obj,fpsMode) end end) end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Vehicle profile loaded: Car ESP + FPS Boost",3) end)
