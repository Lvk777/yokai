-- Safe synthetic-target integration.
-- All target-oriented Combat/Visuals modules below act ONLY on YokaiSafeVisualTestTarget.
-- No other Player character is inspected or targeted by this file.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local VisualsRec = objects["VisualsWindow"]
local Combat = CombatRec and CombatRec["Api"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Combat or not Visuals then
    warn("SafeTargetAllInOne: Combat/Visuals missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isUnder(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    local obj = rec.Object
    for _, root in ipairs({parentRec.Object, parentRec.ChildrenObject}) do
        if root and typeof(root) == "Instance" and (obj == root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOption(parentRec, name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec.Type == "OptionsButton" and isUnder(rec, parentRec) then
            if optionName(key):lower() == name:lower() then table.insert(keys, key) end
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec.Api
            if api and api.Enabled and api.ToggleButton then api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end
local function destroyNamed(root, names)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        for _, n in ipairs(names) do
            if obj.Name == n then pcall(function() obj:Destroy() end) break end
        end
    end
end

-- Neutralize older target-oriented layers before rebuilding one deterministic test layer.
for _, n in ipairs({"Aimbot","SilentAim","Killaura","KillAura","Reach","HitBoxes"}) do removeOption(CombatRec, n) end
for _, n in ipairs({"ESP","Chams","HealthBar","Name + Distance","Corner Box","Tracers","3D Box","Skeleton"}) do removeOption(VisualsRec, n) end

local guiRoots = {LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui}
pcall(function() if gethui then table.insert(guiRoots, gethui()) end end)
for _, root in ipairs(guiRoots) do
    destroyNamed(root, {"YokaiSafeVisualTestOverlay","YokaiStudioSinglePlayerVisuals","YokaiStudioPlayerVisualsV1","YokaiAttachedVisualsFunctional"})
end
for _, n in ipairs({"YokaiSafeVisualTestTarget","YokaiStudioTestTarget"}) do
    local old = Workspace:FindFirstChild(n)
    if old then pcall(function() old:Destroy() end) end
end
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Highlight") and (obj.Name == "YokaiSafeVisualTestHighlight" or obj.Name == "YokaiStudioESPHighlight" or obj.Name == "YokaiStudioSingleHighlight") then
        pcall(function() obj:Destroy() end)
    end
end

-- ============================================================================
-- Synthetic target
-- ============================================================================
local function makePart(model, name, size, cf, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = true
    p.Material = Enum.Material.SmoothPlastic
    p.Color = Color3.fromRGB(150,150,160)
    p.Transparency = transparency or 0
    p.Parent = model
    return p
end
local function spawnCFrame()
    local cam = Workspace.CurrentCamera
    if cam then
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0,0,-1)
        local probe = cam.CFrame.Position + flat * 22 + Vector3.new(0,12,0)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {LocalPlayer.Character, cam}
        rp.IgnoreWater = true
        local hit = Workspace:Raycast(probe, Vector3.new(0,-120,0), rp)
        local pos = hit and (hit.Position + Vector3.new(0,3,0)) or (cam.CFrame.Position + flat*22 - Vector3.new(0,2,0))
        return CFrame.lookAt(pos, pos - flat)
    end
    return CFrame.new(0,4,-22)
end

local target = Instance.new("Model")
target.Name = "YokaiSafeVisualTestTarget"
target.Parent = Workspace
local hum = Instance.new("Humanoid")
hum.Name = "Humanoid"
hum.MaxHealth = 100
hum.Health = 76
hum.Parent = target
local base = spawnCFrame()
local hrp = makePart(target,"HumanoidRootPart",Vector3.new(2,2,1),base,1)
local torso = makePart(target,"Torso",Vector3.new(2,2,1),base)
local head = makePart(target,"Head",Vector3.new(2,1,1),base*CFrame.new(0,1.5,0))
makePart(target,"Left Arm",Vector3.new(1,2,1),base*CFrame.new(-1.5,0,0))
makePart(target,"Right Arm",Vector3.new(1,2,1),base*CFrame.new(1.5,0,0))
makePart(target,"Left Leg",Vector3.new(1,2,1),base*CFrame.new(-.5,-2,0))
makePart(target,"Right Leg",Vector3.new(1,2,1),base*CFrame.new(.5,-2,0))
target.PrimaryPart = hrp

local hitbox = Instance.new("Part")
hitbox.Name = "YokaiSafeHitbox"
hitbox.Anchored = true
hitbox.CanCollide = false
hitbox.CanTouch = false
hitbox.CanQuery = true
hitbox.Material = Enum.Material.ForceField
hitbox.Color = Color3.fromRGB(80,170,255)
hitbox.Transparency = 1
hitbox.Parent = target

local function targetRoot() return target and target.Parent and target:FindFirstChild("HumanoidRootPart") end
local function targetPart(name)
    if not target or not target.Parent then return nil end
    if name == "Torso" then return target:FindFirstChild("Torso") or targetRoot() end
    return target:FindFirstChild("Head") or targetRoot()
end
local function targetDistance()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local trg = targetRoot()
    if not root or not trg then return math.huge end
    return (root.Position - trg.Position).Magnitude
end
local function wallVisible(part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character, cam}
    rp.IgnoreWater = true
    local hit = Workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, rp)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(target))
end
local function screenDistance(part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return math.huge, false end
    local p, on = cam:WorldToViewportPoint(part.Position)
    if not on or p.Z <= 0 then return math.huge, false end
    local m = UserInputService:GetMouseLocation()
    return (Vector2.new(p.X,p.Y)-m).Magnitude, true
end
local resetQueued = false
local function damageTarget(amount)
    if not hum or hum.Health <= 0 then return end
    hum.Health = math.max(0, hum.Health - math.max(1, amount or 1))
    if hum.Health <= 0 and not resetQueued then
        resetQueued = true
        task.delay(0.8, function()
            if hum and hum.Parent then hum.Health = hum.MaxHealth end
            resetQueued = false
        end)
    end
end

-- ============================================================================
-- Combat: rebuilt as synthetic-target-only test modules
-- ============================================================================
local aimEnabled, aimFov, aimSmooth, aimPartName, aimWallCheck = false, 220, 5, "Head", true
local Aimbot = Combat.CreateOptionsButton({
    ["Name"] = "Aimbot",
    ["Function"] = function(v) aimEnabled = v end,
    ["HoverText"] = "Test-only: camera aim assist for YokaiSafeVisualTestTarget.",
})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=20,["Max"]=800,["Default"]=220,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Smoothness",["Min"]=1,["Max"]=20,["Default"]=5,["Function"]=function(v) aimSmooth=v end})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWallCheck=v end})

local silentEnabled, silentFov, silentDamage, silentChance, silentPartName, silentWallCheck = false, 260, 22, 100, "Head", true
local SilentAim = Combat.CreateOptionsButton({
    ["Name"] = "SilentAim",
    ["Function"] = function(v) silentEnabled = v end,
    ["HoverText"] = "Test-only: mouse shots are simulated against the synthetic target without moving the camera.",
})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=20,["Max"]=800,["Default"]=260,["Function"]=function(v) silentFov=v end})
SilentAim.CreateSlider({["Name"]="Hit Chance",["Min"]=1,["Max"]=100,["Default"]=100,["Function"]=function(v) silentChance=v end})
SilentAim.CreateSlider({["Name"]="Damage",["Min"]=1,["Max"]=100,["Default"]=22,["Function"]=function(v) silentDamage=v end})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPartName=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWallCheck=v end})

local reachEnabled, reachRange, reachDamage = false, 18, 18
local Reach = Combat.CreateOptionsButton({
    ["Name"] = "Reach",
    ["Function"] = function(v) reachEnabled=v end,
    ["HoverText"] = "Test-only melee reach against the synthetic target.",
})
Reach.CreateSlider({["Name"]="Range",["Min"]=4,["Max"]=40,["Default"]=18,["Function"]=function(v) reachRange=v end})
Reach.CreateSlider({["Name"]="Damage",["Min"]=1,["Max"]=100,["Default"]=18,["Function"]=function(v) reachDamage=v end})

local auraEnabled, auraRange, auraAPS, auraDamage, lastAura = false, 18, 6, 12, 0
local KillAura = Combat.CreateOptionsButton({
    ["Name"] = "KillAura",
    ["Function"] = function(v) auraEnabled=v end,
    ["HoverText"] = "Test-only automatic attacks against the synthetic target.",
})
KillAura.CreateSlider({["Name"]="Range",["Min"]=4,["Max"]=40,["Default"]=18,["Function"]=function(v) auraRange=v end})
KillAura.CreateSlider({["Name"]="APS",["Min"]=1,["Max"]=20,["Default"]=6,["Function"]=function(v) auraAPS=v end})
KillAura.CreateSlider({["Name"]="Damage",["Min"]=1,["Max"]=100,["Default"]=12,["Function"]=function(v) auraDamage=v end})

local hitboxEnabled, hitboxSize, hitboxVisible = false, 6, false
local HitBoxes = Combat.CreateOptionsButton({
    ["Name"] = "HitBoxes",
    ["Function"] = function(v) hitboxEnabled=v end,
    ["HoverText"] = "Test-only enlarged hitbox around the synthetic target.",
})
HitBoxes.CreateSlider({["Name"]="Size",["Min"]=2,["Max"]=20,["Default"]=6,["Function"]=function(v) hitboxSize=v end})
HitBoxes.CreateToggle({["Name"]="Show Hitbox",["Default"]=false,["Function"]=function(v) hitboxVisible=v end})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if silentEnabled then
        local part = targetPart(silentPartName)
        local dist, on = screenDistance(part)
        if on and dist <= silentFov and (not silentWallCheck or wallVisible(part)) and math.random(1,100) <= silentChance then
            damageTarget(silentDamage)
        end
    end
    if reachEnabled and targetDistance() <= reachRange then
        damageTarget(reachDamage)
    end
end)

-- ============================================================================
-- Visuals: all target-oriented options drive the same synthetic target
-- ============================================================================
local visual = {
    ESP=false,
    MaxDistance=300,
    WallCheck=true,
    ESPColor=Color3.fromRGB(119,120,255),
    VisibleColor=Color3.fromRGB(35,235,95),
    OccludedColor=Color3.fromRGB(245,55,55),
    Chams=false,
    ChamsFill=Color3.fromRGB(119,120,255),
    ChamsOutline=Color3.fromRGB(255,255,255),
    ChamsFillTransparency=.72,
    ChamsOutlineTransparency=0,
    Health=false,
    HealthPalette="Blue / Red",
    HealthText=true,
    Names=false,
    Corner=false,
    CornerColor=Color3.fromRGB(255,255,255),
    CornerFill=Color3.fromRGB(119,120,255),
    CornerFillSpin=true,
    CornerSpinSpeed=.18,
    CornerFillTransparency=.82,
    Tracers=false,
    TracerOrigin="Bottom",
    TracerColor=Color3.fromRGB(255,255,255),
    TracerThickness=1,
    TracerTransparency=0,
    Box3D=false,
    Box3DColor=Color3.fromRGB(255,255,255),
    Box3DThickness=1,
    Box3DTransparency=0,
    Skeleton=false,
    SkeletonColor=Color3.fromRGB(255,255,255),
    SkeletonTransparency=0,
    SkeletonThickness=1,
}
shared.YokaiSafeTargetVisualState = visual

local ESP = Visuals.CreateOptionsButton({["Name"]="ESP",["Function"]=function(v) visual.ESP=v end})
ESP.CreateSlider({["Name"]="Max Distance",["Min"]=25,["Max"]=1000,["Default"]=300,["Function"]=function(v) visual.MaxDistance=v end})
ESP.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) visual.WallCheck=v end})
ESP.CreateColorSlider({["Name"]="ESP Color",["Function"]=function(h,s,v) visual.ESPColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) visual.VisibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) visual.OccludedColor=Color3.fromHSV(h,s,v) end})

local Chams = Visuals.CreateOptionsButton({["Name"]="Chams",["Function"]=function(v) visual.Chams=v end})
Chams.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) visual.ChamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) visual.ChamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=72,["Function"]=function(v) visual.ChamsFillTransparency=v/100 end})
Chams.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=0,["Function"]=function(v) visual.ChamsOutlineTransparency=v/100 end})

local HealthBar = Visuals.CreateOptionsButton({["Name"]="HealthBar",["Function"]=function(v) visual.Health=v end})
HealthBar.CreateDropdown({["Name"]="Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) visual.HealthPalette=v end})
HealthBar.CreateToggle({["Name"]="HealthText",["Default"]=true,["Function"]=function(v) visual.HealthText=v end})

local NameDistance = Visuals.CreateOptionsButton({["Name"]="Name + Distance",["Function"]=function(v) visual.Names=v end})

local Corner = Visuals.CreateOptionsButton({["Name"]="Corner Box",["Function"]=function(v) visual.Corner=v end})
Corner.CreateColorSlider({["Name"]="Line Color",["Function"]=function(h,s,v) visual.CornerColor=Color3.fromHSV(h,s,v) end})
Corner.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) visual.CornerFill=Color3.fromHSV(h,s,v) end})
Corner.CreateToggle({["Name"]="Fill Spin",["Default"]=true,["Function"]=function(v) visual.CornerFillSpin=v end})
Corner.CreateSlider({["Name"]="Spin Speed",["Min"]=1,["Max"]=100,["Default"]=18,["Function"]=function(v) visual.CornerSpinSpeed=v/100 end})
Corner.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=82,["Function"]=function(v) visual.CornerFillTransparency=v/100 end})

local Tracers = Visuals.CreateOptionsButton({["Name"]="Tracers",["Function"]=function(v) visual.Tracers=v end})
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Top","Bottom","Center","Mouse"},["Function"]=function(v) visual.TracerOrigin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) visual.TracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) visual.TracerThickness=v end})
Tracers.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=0,["Function"]=function(v) visual.TracerTransparency=v/100 end})

local Box3D = Visuals.CreateOptionsButton({["Name"]="3D Box",["Function"]=function(v) visual.Box3D=v end})
Box3D.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) visual.Box3DColor=Color3.fromHSV(h,s,v) end})
Box3D.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) visual.Box3DThickness=v end})
Box3D.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"] =95,["Default"]=0,["Function"]=function(v) visual.Box3DTransparency=v/100 end})

local Skeleton = Visuals.CreateOptionsButton({["Name"]="Skeleton",["Function"]=function(v) visual.Skeleton=v end})
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) visual.SkeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=0,["Function"]=function(v) visual.SkeletonTransparency=v/100 end})
Skeleton.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) visual.SkeletonThickness=v end})

-- ============================================================================
-- Overlay drawing
-- ============================================================================
local overlay = Instance.new("ScreenGui")
overlay.Name = "YokaiSafeTargetAllInOneOverlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 999
pcall(function() overlay.Parent = (gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local highlight = Instance.new("Highlight")
highlight.Name = "YokaiSafeTargetHighlight"
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = Workspace

local function newLine()
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(.5,.5)
    f.BorderSizePixel = 0
    f.Visible = false
    f.Parent = overlay
    return f
end
local function setLine(f,a,b,thickness,color,transparency)
    local d = b-a
    if d.Magnitude < .01 then f.Visible=false return end
    f.Size = UDim2.fromOffset(d.Magnitude, thickness or 1)
    f.Position = UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation = math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3 = color or Color3.new(1,1,1)
    f.BackgroundTransparency = transparency or 0
    f.Visible = true
end
local function hideLines(t) for _,v in ipairs(t) do v.Visible=false end end

local corners = {} for i=1,8 do corners[i]=newLine() end
local skeleton = {} for i=1,5 do skeleton[i]=newLine() end
local box3d = {} for i=1,12 do box3d[i]=newLine() end
local tracer = newLine()

local cornerFill = Instance.new("Frame")
cornerFill.BorderSizePixel = 0
cornerFill.BackgroundColor3 = Color3.new(1,1,1)
cornerFill.Visible = false
cornerFill.ZIndex = 0
cornerFill.Parent = overlay
local cornerGradient = Instance.new("UIGradient")
cornerGradient.Parent = cornerFill

local name = Instance.new("TextLabel")
name.BackgroundTransparency = 1
name.AnchorPoint = Vector2.new(.5,.5)
name.Size = UDim2.fromOffset(260,18)
name.Font = Enum.Font.Code
name.TextSize = 12
name.TextStrokeTransparency = 0
name.TextStrokeColor3 = Color3.new(0,0,0)
name.TextColor3 = Color3.new(1,1,1)
name.Text = "YokaiSafeVisualTestTarget"
name.Visible = false
name.Parent = overlay
local distance = name:Clone() distance.TextSize=11 distance.Parent=overlay
local healthText = name:Clone() healthText.Size=UDim2.fromOffset(44,16) healthText.TextSize=11 healthText.Parent=overlay
local healthBack = Instance.new("Frame") healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Visible=false healthBack.Parent=overlay
local health = Instance.new("Frame") health.BorderSizePixel=0 health.BackgroundColor3=Color3.new(1,1,1) health.Visible=false health.Parent=overlay
local healthGradient = Instance.new("UIGradient") healthGradient.Rotation=90 healthGradient.Parent=health

local function healthPalette()
    if visual.HealthPalette == "Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55)),
        })
    end
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(50,110,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(220,40,50)),
    })
end
local function bounds2D(model)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local cf,size = model:GetBoundingBox()
    local minX,minY,maxX,maxY = math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p = cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
    end end end
    if not any or maxX<0 or maxY<0 or minX>cam.ViewportSize.X or minY>cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function updateCorners(tl,br,color)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y
    local w,h=r-l,b-t
    local cw,ch=math.max(6,w*.24),math.max(6,h*.18)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(corners[i],v[1],v[2],1,color,0) end
end
local function tracerOrigin()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    local vp=cam.ViewportSize
    if visual.TracerOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if visual.TracerOrigin=="Center" then return Vector2.new(vp.X/2,vp.Y/2) end
    if visual.TracerOrigin=="Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(vp.X/2,vp.Y)
end
local function updateSkeleton(cam)
    if not visual.Skeleton then hideLines(skeleton) return end
    local parts={head,torso,target:FindFirstChild("Left Arm"),target:FindFirstChild("Right Arm"),target:FindFirstChild("Left Leg"),target:FindFirstChild("Right Leg")}
    local pairs={{1,2},{2,3},{2,4},{2,5},{2,6}}
    for i,pair in ipairs(pairs) do
        local a,b=parts[pair[1]],parts[pair[2]]
        local pa,ona=cam:WorldToViewportPoint(a.Position)
        local pb,onb=cam:WorldToViewportPoint(b.Position)
        if ona and onb and pa.Z>0 and pb.Z>0 then
            setLine(skeleton[i],Vector2.new(pa.X,pa.Y),Vector2.new(pb.X,pb.Y),visual.SkeletonThickness,visual.SkeletonColor,visual.SkeletonTransparency)
        else skeleton[i].Visible=false end
    end
end
local function update3DBox(cam)
    if not visual.Box3D then hideLines(box3d) return end
    local cf,size=target:GetBoundingBox()
    local pts={}
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p,on=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        table.insert(pts,{p=Vector2.new(p.X,p.Y),z=p.Z,on=on})
    end end end
    local edges={{1,2},{1,3},{1,5},{2,4},{2,6},{3,4},{3,7},{4,8},{5,6},{5,7},{6,8},{7,8}}
    for i,e in ipairs(edges) do
        local a,b=pts[e[1]],pts[e[2]]
        if a and b and a.z>0 and b.z>0 then setLine(box3d[i],a.p,b.p,visual.Box3DThickness,visual.Box3DColor,visual.Box3DTransparency) else box3d[i].Visible=false end
    end
end
local function hideAll()
    highlight.Enabled=false
    name.Visible=false distance.Visible=false healthText.Visible=false healthBack.Visible=false health.Visible=false cornerFill.Visible=false tracer.Visible=false
    hideLines(corners) hideLines(skeleton) hideLines(box3d)
end

RunService.RenderStepped:Connect(function(dt)
    local cam=Workspace.CurrentCamera
    if not cam or not target.Parent then hideAll() return end

    -- Combat test behaviors.
    if aimEnabled then
        local part=targetPart(aimPartName)
        local d,on=screenDistance(part)
        if on and d<=aimFov and (not aimWallCheck or wallVisible(part)) then
            local goal=CFrame.lookAt(cam.CFrame.Position,part.Position)
            cam.CFrame=cam.CFrame:Lerp(goal,math.clamp(1/math.max(1,aimSmooth),.05,1))
        end
    end
    if auraEnabled and targetDistance()<=auraRange then
        local now=os.clock()
        if now-lastAura >= 1/math.max(1,auraAPS) then lastAura=now damageTarget(auraDamage) end
    end
    local trg=targetRoot()
    if trg then
        hitbox.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize)
        hitbox.CFrame=trg.CFrame
        hitbox.Transparency=(hitboxEnabled and hitboxVisible) and .78 or 1
        hitbox.CanQuery=hitboxEnabled
    end

    local tl,br=bounds2D(target)
    if not tl then hideAll() return end
    local distStuds=(cam.CFrame.Position-hrp.Position).Magnitude
    if distStuds>visual.MaxDistance then hideAll() return end

    local visible=wallVisible(head)
    local espColor=visual.ESPColor
    if visual.WallCheck then espColor=visible and visual.VisibleColor or visual.OccludedColor end

    -- ESP / Chams.
    highlight.Adornee=target
    highlight.Enabled=visual.ESP or visual.Chams
    highlight.FillColor=visual.Chams and visual.ChamsFill or espColor
    highlight.OutlineColor=visual.Chams and visual.ChamsOutline or espColor
    highlight.FillTransparency=visual.Chams and visual.ChamsFillTransparency or .72
    highlight.OutlineTransparency=visual.Chams and visual.ChamsOutlineTransparency or 0

    -- Name + distance are intentionally white.
    local cx=(tl.X+br.X)/2
    if visual.Names or visual.ESP then
        name.Position=UDim2.fromOffset(cx,tl.Y-12) name.TextColor3=Color3.new(1,1,1) name.Visible=true
        distance.Position=UDim2.fromOffset(cx,br.Y+10) distance.Text=string.format("%d studs",math.floor(distStuds)) distance.TextColor3=Color3.new(1,1,1) distance.Visible=true
    else name.Visible=false distance.Visible=false end

    -- HealthBar palette is controlled directly by this module.
    if visual.Health or visual.ESP then
        local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
        local h=math.max(4,br.Y-tl.Y)
        healthBack.Position=UDim2.fromOffset(tl.X-8,tl.Y) healthBack.Size=UDim2.fromOffset(5,h) healthBack.Visible=true
        health.Position=UDim2.fromOffset(tl.X-8,tl.Y+h*(1-ratio)) health.Size=UDim2.fromOffset(5,h*ratio)
        healthGradient.Color=healthPalette() health.Visible=true
        healthText.Position=UDim2.fromOffset(tl.X-24,tl.Y+h*(1-ratio)) healthText.Text=tostring(math.floor(hum.Health))
        healthText.TextColor3=Color3.new(1,1,1) healthText.Visible=visual.HealthText
    else healthBack.Visible=false health.Visible=false healthText.Visible=false end

    -- Corner Box + animated fill color only (geometry stays still).
    if visual.Corner or visual.ESP then
        updateCorners(tl,br,visual.CornerColor)
        cornerFill.Position=UDim2.fromOffset(tl.X,tl.Y)
        cornerFill.Size=UDim2.fromOffset(br.X-tl.X,br.Y-tl.Y)
        cornerFill.BackgroundTransparency=visual.CornerFillTransparency
        cornerFill.Visible=true
        local h=select(1,Color3.toHSV(visual.CornerFill))
        if visual.CornerFillSpin then h=(h+os.clock()*visual.CornerSpinSpeed)%1 end
        cornerGradient.Rotation=0
        cornerGradient.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromHSV(h,1,1)),
            ColorSequenceKeypoint.new(.5,visual.CornerFill),
            ColorSequenceKeypoint.new(1,Color3.fromHSV((h+.16)%1,1,1)),
        })
    else hideLines(corners) cornerFill.Visible=false end

    updateSkeleton(cam)
    update3DBox(cam)
    if visual.Tracers then setLine(tracer,tracerOrigin(),Vector2.new(cx,br.Y),visual.TracerThickness,visual.TracerColor,visual.TracerTransparency) else tracer.Visible=false end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Safe target: Combat + Visuals test integration loaded",4) end)
