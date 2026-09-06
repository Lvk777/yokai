-- Stable runtime for the WeaponSystem-based bot practice map.
-- Targets only non-player Humanoid NPCs. No anti-cheat bypass, kick hooks or ban evasion.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary
if shared.YokaiWeaponSystemBotRuntimeV19 then return end
shared.YokaiWeaponSystemBotRuntimeV19 = true

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec = objects.CombatWindow
local VisualsRec = objects.VisualsWindow
local WorldRec = objects.WorldWindow
local UtilityRec = objects.UtilityWindow
local Combat = CombatRec and CombatRec.Api
local Visuals = VisualsRec and VisualsRec.Api
local World = WorldRec and WorldRec.Api
local Utility = UtilityRec and UtilityRec.Api
if not (Combat and Visuals and World) then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP, "") end
local function optionName(key, rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$", "")
end
local function under(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _, root in ipairs({parentRec.Object, parentRec.ChildrenObject}) do
        if root and typeof(root) == "Instance" then
            local ok, yes = pcall(function() return rec.Object == root or rec.Object:IsDescendantOf(root) end)
            if ok and yes then return true end
        end
    end
    return false
end
local function removeOption(parentRec, name)
    if not parentRec then return end
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec.Type == "OptionsButton" and under(rec, parentRec) and optionName(key, rec) == name then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

-- --------------------------------------------------------------------------
-- Detect the current WeaponSystem modules without waiting on the old GunPlugin.
-- --------------------------------------------------------------------------
local ps = LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 8)
local client = ps and ps:FindFirstChild("Client")
local systems = client and client:FindFirstChild("Systems")
local gunSystem = systems and systems:FindFirstChild("GunSystem")
local viewController = gunSystem and gunSystem:FindFirstChild("WeaponViewmodelController")
local shotBuilderModule = viewController and viewController:FindFirstChild("WeaponShotBuilder")
local ShotBuilder
if shotBuilderModule and shotBuilderModule:IsA("ModuleScript") then
    local ok, result = pcall(require, shotBuilderModule)
    if ok and type(result) == "table" then ShotBuilder = result end
end

-- --------------------------------------------------------------------------
-- NPC registry: one initial scan, then event-driven. Player characters excluded.
-- --------------------------------------------------------------------------
local bots = setmetatable({}, {__mode = "k"})
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and (model == char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) or model.Name == "YokaiSafeVisualTestTarget" then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0 and rootOf(model) ~= nil
end
local function register(model)
    if isBot(model) then bots[model] = true end
end
for _, d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end
end
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(register, d.Parent)
    elseif d:IsA("Model") then task.defer(register, d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then bots[d] = nil
    elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent] = nil end
end)

local function partOf(model, name)
    if name == "Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function visible(model, part)
    local cam = Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local f = {cam}
    if LocalPlayer.Character then table.insert(f, LocalPlayer.Character) end
    rp.FilterDescendantsInstances = f
    rp.IgnoreWater = true
    local hit = Workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, rp)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function predictedPosition(model, part, enabled, speed, gravity)
    if not enabled then return part.Position end
    local cam = Workspace.CurrentCamera
    local root = rootOf(model)
    if not cam or not root then return part.Position end
    local dist = (part.Position - cam.CFrame.Position).Magnitude
    local t = dist / math.max(100, speed or 1800)
    return part.Position + root.AssemblyLinearVelocity * t + Vector3.new(0, (gravity or 0) * t * t * 0.5, 0)
end
local function nearestBot(maxPx, maxStuds, partName, wall, prediction, bulletSpeed, gravity, useCenter)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local ref
    if useCenter then ref = cam.ViewportSize / 2 else
        local m = UserInputService:GetMouseLocation(); ref = Vector2.new(m.X, m.Y)
    end
    local best, bestPart, bestPos, bestPx = nil, nil, nil, maxPx or math.huge
    for model in pairs(bots) do
        if isBot(model) then
            local root = rootOf(model)
            local part = partOf(model, partName)
            if root and part and (root.Position - cam.CFrame.Position).Magnitude <= (maxStuds or math.huge) and (not wall or visible(model, part)) then
                local pos = predictedPosition(model, part, prediction, bulletSpeed, gravity)
                local p, on = cam:WorldToViewportPoint(pos)
                if on and p.Z > 0 then
                    local px = (Vector2.new(p.X, p.Y) - ref).Magnitude
                    if px < bestPx then best, bestPart, bestPos, bestPx = model, part, pos, px end
                end
            end
        end
    end
    return best, bestPart, bestPos, bestPx
end

-- ============================================================================
-- COMBAT: one controller for this map.
-- ============================================================================
for _, n in ipairs({"Aimbot", "SilentAim", "Magic Bullets", "HitBoxes", "No Recoil", "Fast Reload", "Infinite Ammo", "AntiAim", "KillAura", "Reach"}) do
    removeOption(CombatRec, n)
end
for _, bind in ipairs({"YokaiBotAimbot", "YokaiGunTestingAimbotV2", "YokaiGunTestingAimbotV3", "YokaiReferenceAimbotV18", "YokaiGunTestingNoRecoilV16", "YokaiGunTestingAntiAimV16", "YokaiWeaponSystemAimbotV19", "YokaiWeaponSystemNoRecoilV19"}) do
    pcall(function() RunService:UnbindFromRenderStep(bind) end)
end

local aimEnabled, aimFov, aimSensitivity, aimPartName, aimWall, aimPrediction, aimSpeed, aimGravity, aimDistance = false, 300, .72, "Head", true, true, 1800, 0, 2500
local silentEnabled, silentFov, silentPartName, silentWall = false, 350, "Head", true
local magicEnabled, magicPartName, magicWall = false, "Head", true
local hitboxEnabled, hitboxRadius, hitboxPartName, hitboxWall = false, 120, "Head", true
local noRecoilEnabled, recoilStrength = false, 1
local fastReloadEnabled, reloadMultiplier = false, 3
local infiniteEnabled, ammoAmount = false, 999
local antiEnabled, antiMode, antiSpeed = false, "Jitter", 8
local rightHeld = false
local mover = rawget((getgenv and getgenv()) or _G, "mousemoverel") or rawget(_G, "mousemoverel")

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then rightHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then rightHeld = false end
end)

local Aimbot = Combat.CreateOptionsButton({Name = "Aimbot", Function = function(v) aimEnabled = v end})
Aimbot.CreateSlider({Name = "FOV", Min = 40, Max = 1000, Default = 300, Function = function(v) aimFov = v end})
Aimbot.CreateSlider({Name = "Sensitivity", Min = 5, Max = 100, Default = 72, Function = function(v) aimSensitivity = v / 100 end})
Aimbot.CreateDropdown({Name = "Aim Part", List = {"Head", "Torso"}, Function = function(v) aimPartName = v end})
Aimbot.CreateToggle({Name = "WallCheck", Default = true, Function = function(v) aimWall = v end})
Aimbot.CreateToggle({Name = "Prediction", Default = true, Function = function(v) aimPrediction = v end})
Aimbot.CreateSlider({Name = "Bullet Speed", Min = 300, Max = 4000, Default = 1800, Function = function(v) aimSpeed = v end})
Aimbot.CreateSlider({Name = "Bullet Gravity", Min = 0, Max = 200, Default = 0, Function = function(v) aimGravity = v end})
Aimbot.CreateSlider({Name = "Distance", Min = 100, Max = 5000, Default = 2500, Function = function(v) aimDistance = v end})

local Silent = Combat.CreateOptionsButton({Name = "SilentAim", Function = function(v) silentEnabled = v end})
Silent.CreateSlider({Name = "FOV", Min = 40, Max = 1200, Default = 350, Function = function(v) silentFov = v end})
Silent.CreateDropdown({Name = "Aim Part", List = {"Head", "Torso"}, Function = function(v) silentPartName = v end})
Silent.CreateToggle({Name = "WallCheck", Default = true, Function = function(v) silentWall = v end})

local Magic = Combat.CreateOptionsButton({Name = "Magic Bullets", Function = function(v) magicEnabled = v end})
Magic.CreateDropdown({Name = "Aim Part", List = {"Head", "Torso"}, Function = function(v) magicPartName = v end})
Magic.CreateToggle({Name = "WallCheck", Default = true, Function = function(v) magicWall = v end})

local HitBoxes = Combat.CreateOptionsButton({Name = "HitBoxes", Function = function(v) hitboxEnabled = v end, HoverText = "Bot-only acquisition radius; shot still resolves to the real body part."})
HitBoxes.CreateSlider({Name = "Size", Min = 30, Max = 350, Default = 120, Function = function(v) hitboxRadius = v end})
HitBoxes.CreateDropdown({Name = "Part", List = {"Head", "Torso"}, Function = function(v) hitboxPartName = v end})
HitBoxes.CreateToggle({Name = "WallCheck", Default = true, Function = function(v) hitboxWall = v end})

local NoRecoil = Combat.CreateOptionsButton({Name = "No Recoil", Function = function(v) noRecoilEnabled = v end})
NoRecoil.CreateSlider({Name = "Strength", Min = 0, Max = 100, Default = 100, Function = function(v) recoilStrength = v / 100 end})
local FastReload = Combat.CreateOptionsButton({Name = "Fast Reload", Function = function(v) fastReloadEnabled = v end})
FastReload.CreateSlider({Name = "Multiplier", Min = 1, Max = 10, Default = 3, Function = function(v) reloadMultiplier = v end})
local Infinite = Combat.CreateOptionsButton({Name = "Infinite Ammo", Function = function(v) infiniteEnabled = v end})
Infinite.CreateSlider({Name = "Amount", Min = 30, Max = 999, Default = 999, Function = function(v) ammoAmount = v end})
local Anti = Combat.CreateOptionsButton({Name = "AntiAim", Function = function(v) antiEnabled = v end})
Anti.CreateDropdown({Name = "Mode", List = {"Jitter", "Spin", "Backwards"}, Function = function(v) antiMode = v end})
Anti.CreateSlider({Name = "Speed", Min = 1, Max = 20, Default = 8, Function = function(v) antiSpeed = v end})

RunService:BindToRenderStep("YokaiWeaponSystemAimbotV19", Enum.RenderPriority.Camera.Value + 40, function()
    if not aimEnabled or not rightHeld then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local model, part, pos = nearestBot(aimFov, aimDistance, aimPartName, aimWall, aimPrediction, aimSpeed, aimGravity, true)
    if not model or not pos then return end
    shared.YokaiGunTestingLastAimPart = {Part = part and part.Name or aimPartName, At = os.clock(), Model = model}
    local p, on = cam:WorldToViewportPoint(pos)
    if not on or p.Z <= 0 then return end
    local center = cam.ViewportSize / 2
    local dx, dy = (p.X - center.X) * aimSensitivity, (p.Y - center.Y) * aimSensitivity
    if type(mover) == "function" then pcall(mover, dx, dy)
    else cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, pos), math.clamp(aimSensitivity, .05, 1)) end
end)

-- ShotBuilder integration: no metamethod hooks. It only changes the local shot direction returned by the game's own module.
local originalResolve, originalOrigin, originalSpread
local shotPulseUntil, recoilBase = 0, nil
if ShotBuilder then
    if type(ShotBuilder.ResolveBaseDirection) == "function" then
        originalResolve = ShotBuilder.ResolveBaseDirection
        ShotBuilder.ResolveBaseDirection = function(ctx, ...)
            local origin = ctx and (ctx.shotOrigin or ctx.serverShotOrigin) or nil
            local cam = Workspace.CurrentCamera
            origin = origin or (cam and cam.CFrame.Position)
            local targetModel, targetPart, targetPos
            if magicEnabled then
                targetModel, targetPart, targetPos = nearestBot(5000, aimDistance, magicPartName, magicWall, aimPrediction, aimSpeed, aimGravity, true)
            elseif silentEnabled then
                targetModel, targetPart, targetPos = nearestBot(silentFov, aimDistance, silentPartName, silentWall, aimPrediction, aimSpeed, aimGravity, true)
            elseif hitboxEnabled then
                targetModel, targetPart, targetPos = nearestBot(hitboxRadius, aimDistance, hitboxPartName, hitboxWall, false, aimSpeed, 0, true)
            end
            if origin and targetPos and (targetPos - origin).Magnitude > .01 then
                shared.YokaiGunTestingLastAimPart = {Part = targetPart and targetPart.Name or "Body", At = os.clock(), Model = targetModel}
                return (targetPos - origin).Unit
            end
            return originalResolve(ctx, ...)
        end
    end
    if type(ShotBuilder.GetSpreadDegrees) == "function" then
        originalSpread = ShotBuilder.GetSpreadDegrees
        ShotBuilder.GetSpreadDegrees = function(ctx, ...)
            if noRecoilEnabled then return 0 end
            return originalSpread(ctx, ...)
        end
    end
    if type(ShotBuilder.GetShotOriginAndDirection) == "function" then
        originalOrigin = ShotBuilder.GetShotOriginAndDirection
    end
end

-- Local camera stabilization after a detected shot.
RunService:BindToRenderStep("YokaiWeaponSystemNoRecoilV19", Enum.RenderPriority.Last.Value + 100, function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if noRecoilEnabled and recoilBase and os.clock() < shotPulseUntil then
        cam.CFrame = cam.CFrame:Lerp(recoilBase, recoilStrength)
    end
end)

-- Ammo/reload helpers are only active while toggled.
local function numericTargets(root, out)
    if not root then return end
    local function add(obj)
        if obj:IsA("IntValue") or obj:IsA("NumberValue") then
            local n = obj.Name:lower():gsub("[%s_%-]", "")
            if n:find("ammo",1,true) or n:find("bullet",1,true) or n:find("mag",1,true) or n:find("reserve",1,true) then out[obj] = true end
        elseif obj:IsA("ObjectValue") and obj.Value then add(obj.Value) end
    end
    add(root)
    for _, d in ipairs(root:GetDescendants()) do add(d) end
end
local function patchReload(root)
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ModuleScript") and d.Name:lower():find("weaponconfig", 1, true) then
            local ok, cfg = pcall(require, d)
            if ok and type(cfg) == "table" then
                for k, v in pairs(cfg) do
                    local lk = tostring(k):lower()
                    if fastReloadEnabled and type(v) == "number" then
                        if lk:find("reloadspeed",1,true) then cfg[k] = math.max(v, reloadMultiplier)
                        elseif lk:find("reloadtime",1,true) or lk:find("reloadduration",1,true) then cfg[k] = math.max(.02, v / reloadMultiplier) end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while shared.YokaiExecuted ~= false do
        if infiniteEnabled or fastReloadEnabled then
            local roots = {LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")}
            if infiniteEnabled then
                local targets = setmetatable({}, {__mode = "k"})
                for _, r in ipairs(roots) do numericTargets(r, targets) end
                for obj in pairs(targets) do pcall(function() if obj.Value < ammoAmount then obj.Value = ammoAmount end end) end
            end
            if fastReloadEnabled then for _, r in ipairs(roots) do patchReload(r) end end
            task.wait(.12)
        else task.wait(.4) end
    end
end)

-- AntiAim is local visual pose only; uses Transform, not C0, so it does not touch the game's LookToCamera C0 writes.
RunService:BindToRenderStep("YokaiWeaponSystemAntiAimV19", Enum.RenderPriority.Last.Value + 120, function()
    if not antiEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local yaw = antiMode == "Backwards" and math.pi or (antiMode == "Spin" and os.clock() * antiSpeed or math.rad(35) * ((math.floor(os.clock() * antiSpeed) % 2 == 0) and 1 or -1))
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and (d.Name == "Waist" or d.Name == "RootJoint") then pcall(function() d.Transform = CFrame.Angles(0, yaw, 0) end) end
    end
end)

-- ============================================================================
-- GUN / SELF CHAMS for camera viewmodels.
-- ============================================================================
for _, n in ipairs({"GunChams", "SelfChams"}) do removeOption(VisualsRec, n) end
local materialMap = {ForceField = Enum.Material.ForceField, Neon = Enum.Material.Neon, SmoothPlastic = Enum.Material.SmoothPlastic, Metal = Enum.Material.Metal}
local materialList = {"ForceField", "Neon", "SmoothPlastic", "Metal"}
local gunEnabled, selfEnabled = false, false
local gunMaterial, selfMaterial = "ForceField", "ForceField"
local gunColor, selfColor = Color3.fromRGB(45,110,255), Color3.fromRGB(119,120,255)
local gunTransparency, selfTransparency = 0, 0
local originals = setmetatable({}, {__mode = "k"})
local function remember(p)
    if originals[p] then return end
    originals[p] = {Material = p.Material, Color = p.Color, Transparency = p.Transparency, CastShadow = p.CastShadow}
end
local function restoreAll()
    for p, st in pairs(originals) do
        if p and p.Parent then pcall(function() p.Material = st.Material; p.Color = st.Color; p.Transparency = st.Transparency; p.CastShadow = st.CastShadow end) end
        originals[p] = nil
    end
end
local function isArmPart(p)
    local cur = p
    while cur and cur ~= Workspace.CurrentCamera do
        local n = cur.Name:lower():gsub("[%s_%-]", "")
        if n:find("leftarm",1,true) or n:find("rightarm",1,true) or n == "arms" then return true end
        cur = cur.Parent
    end
    return false
end
local Gun = Visuals.CreateOptionsButton({Name = "GunChams", Function = function(v) gunEnabled = v; if not v and not selfEnabled then restoreAll() end end})
Gun.CreateDropdown({Name = "Material", List = materialList, Function = function(v) gunMaterial = v end})
Gun.CreateColorSlider({Name = "Color", Function = function(h,s,v) gunColor = Color3.fromHSV(h,s,v) end})
Gun.CreateSlider({Name = "Transparency", Min = 0, Max = 80, Default = 0, Function = function(v) gunTransparency = v / 100 end})
local Self = Visuals.CreateOptionsButton({Name = "SelfChams", Function = function(v) selfEnabled = v; if not v and not gunEnabled then restoreAll() end end})
Self.CreateDropdown({Name = "Material", List = materialList, Function = function(v) selfMaterial = v end})
Self.CreateColorSlider({Name = "Color", Function = function(h,s,v) selfColor = Color3.fromHSV(h,s,v) end})
Self.CreateSlider({Name = "Transparency", Min = 0, Max = 80, Default = 0, Function = function(v) selfTransparency = v / 100 end})

RunService:BindToRenderStep("YokaiWeaponSystemViewmodelV19", Enum.RenderPriority.Last.Value + 80, function()
    if not gunEnabled and not selfEnabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local root = cam:FindFirstChild("CurrentWeapon") or cam:FindFirstChild("Rig") or cam
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < .98 and p.Size.Magnitude > .05 then
            local arm = isArmPart(p)
            if (arm and selfEnabled) or (not arm and gunEnabled) then
                remember(p)
                local mat, col, tr = arm and selfMaterial or gunMaterial, arm and selfColor or gunColor, arm and selfTransparency or gunTransparency
                p.Material = materialMap[mat] or Enum.Material.ForceField; p.Color = col; p.Transparency = tr; p.CastShadow = false
            end
        end
    end
end)

-- ============================================================================
-- VISUALS: lightweight event-driven bot ESP in one overlay.
-- ============================================================================
for _, n in ipairs({"ESP", "Chams", "Corner Box", "Thermal Corner", "HealthBar", "Name + Distance", "Skeleton", "Tracers", "Distance"}) do removeOption(VisualsRec, n) end

local parentGui = (gethui and gethui()) or CoreGui
local old = parentGui:FindFirstChild("YokaiWeaponSystemESP19")
if old then old:Destroy() end
local Overlay = Instance.new("ScreenGui")
Overlay.Name = "YokaiWeaponSystemESP19"; Overlay.ResetOnSpawn = false; Overlay.IgnoreGuiInset = true; Overlay.DisplayOrder = 1020; Overlay.Parent = parentGui

local visualDistance = 1200
local espEnabled, cornerEnabled, thermalEnabled, healthEnabled, namesEnabled, skeletonEnabled, tracersEnabled, chamsEnabled = false, false, false, false, false, false, false, false
local espColor = Color3.fromRGB(119,120,255)
local visibleColor, occludedColor = Color3.fromRGB(35,235,95), Color3.fromRGB(245,70,70)
local wallCheck = true
local tracerColor, tracerThickness, tracerTransparency, tracerOrigin = Color3.new(1,1,1), 1, 0, "Bottom"
local skeletonColor, skeletonTransparency = Color3.new(1,1,1), 0
local records = setmetatable({}, {__mode = "k"})
local function makeFrame(parent, z)
    local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = espColor; f.ZIndex = z or 5; f.Parent = parent; return f
end
local function recFor(model)
    local r = records[model]
    if r then return r end
    local folder = Instance.new("Folder"); folder.Name = "Bot"; folder.Parent = Overlay
    local box = Instance.new("Frame"); box.BackgroundTransparency = 1; box.BorderSizePixel = 0; box.Parent = folder
    local fill = makeFrame(box, 1); fill.BackgroundTransparency = .83
    local l,t,rr,b = makeFrame(box,5), makeFrame(box,5), makeFrame(box,5), makeFrame(box,5)
    local health = makeFrame(box,7); health.AnchorPoint = Vector2.new(0,1)
    local name = Instance.new("TextLabel"); name.BackgroundTransparency = 1; name.Font = Enum.Font.GothamSemibold; name.TextSize = 12; name.TextColor3 = Color3.new(1,1,1); name.TextStrokeTransparency = .45; name.TextXAlignment = Enum.TextXAlignment.Center; name.Parent = folder
    local tracer = makeFrame(folder,4); tracer.AnchorPoint = Vector2.new(0,.5)
    local hi = Instance.new("Highlight"); hi.Name = "YokaiWeaponSystemChams19"; hi.Adornee = model; hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hi.Enabled = false; hi.Parent = model
    r = {folder=folder,box=box,fill=fill,l=l,t=t,r=rr,b=b,health=health,name=name,tracer=tracer,hi=hi}
    records[model] = r
    return r
end
local function hideRec(r)
    if not r then return end
    r.box.Visible=false; r.name.Visible=false; r.tracer.Visible=false; if r.hi then r.hi.Enabled=false end
end
local function originPoint(cam)
    local v=cam.ViewportSize
    if tracerOrigin=="Top" then return Vector2.new(v.X/2,0) end
    if tracerOrigin=="Center" then return v/2 end
    if tracerOrigin=="Mouse" then local m=UserInputService:GetMouseLocation(); return Vector2.new(m.X,m.Y) end
    return Vector2.new(v.X/2,v.Y)
end
local function lineFrame(frame, a, b, thickness, color, transparency)
    local d = b-a; local len=d.Magnitude
    frame.Position=UDim2.fromOffset(a.X,a.Y); frame.Size=UDim2.fromOffset(len,math.max(1,thickness)); frame.Rotation=math.deg(math.atan2(d.Y,d.X)); frame.BackgroundColor3=color; frame.BackgroundTransparency=transparency; frame.Visible=true
end

local ESP = Visuals.CreateOptionsButton({Name="ESP", Function=function(v) espEnabled=v end})
ESP.CreateToggle({Name="WallCheck", Default=true, Function=function(v) wallCheck=v end})
ESP.CreateColorSlider({Name="Color", Function=function(h,s,v) espColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({Name="Visible Color", Function=function(h,s,v) visibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({Name="Occluded Color", Function=function(h,s,v) occludedColor=Color3.fromHSV(h,s,v) end})
local Chams = Visuals.CreateOptionsButton({Name="Chams", Function=function(v) chamsEnabled=v end})
local Corner = Visuals.CreateOptionsButton({Name="Corner Box", Function=function(v) cornerEnabled=v end})
local Thermal = Visuals.CreateOptionsButton({Name="Thermal Corner", Function=function(v) thermalEnabled=v end})
local Health = Visuals.CreateOptionsButton({Name="HealthBar", Function=function(v) healthEnabled=v end})
local Names = Visuals.CreateOptionsButton({Name="Name + Distance", Function=function(v) namesEnabled=v end})
local Skeleton = Visuals.CreateOptionsButton({Name="Skeleton", Function=function(v) skeletonEnabled=v end})
Skeleton.CreateColorSlider({Name="Color", Function=function(h,s,v) skeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({Name="Transparency", Min=0, Max=100, Default=0, Function=function(v) skeletonTransparency=v/100 end})
local Tracers = Visuals.CreateOptionsButton({Name="Tracers", Function=function(v) tracersEnabled=v end})
Tracers.CreateDropdown({Name="Origin", List={"Top","Bottom","Center","Mouse"}, Function=function(v) tracerOrigin=v end})
Tracers.CreateColorSlider({Name="Color", Function=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({Name="Thickness", Min=1, Max=5, Default=1, Function=function(v) tracerThickness=v end})
Tracers.CreateSlider({Name="Transparency", Min=0, Max=100, Default=0, Function=function(v) tracerTransparency=v/100 end})
local Distance = Visuals.CreateOptionsButton({Name="Distance", Function=function() end})
Distance.CreateSlider({Name="Max Distance", Min=100, Max=5000, Default=1200, Function=function(v) visualDistance=v end})

local function partScreen(cam, part)
    if not part then return nil end
    local p,on=cam:WorldToViewportPoint(part.Position); if not on or p.Z<=0 then return nil end; return Vector2.new(p.X,p.Y),p.Z
end

RunService:BindToRenderStep("YokaiWeaponSystemESP19", Enum.RenderPriority.Last.Value + 40, function()
    local active = espEnabled or cornerEnabled or thermalEnabled or healthEnabled or namesEnabled or skeletonEnabled or tracersEnabled or chamsEnabled
    if not active then
        for _,r in pairs(records) do hideRec(r) end
        return
    end
    local cam=Workspace.CurrentCamera; if not cam then return end
    local nowSeen={}
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model); local hum=model:FindFirstChildOfClass("Humanoid")
            local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
            local r=recFor(model); nowSeen[model]=true
            if root and hum and dist<=visualDistance then
                local head=model:FindFirstChild("Head") or root
                local torso=model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root
                local hp,_=partScreen(cam,head); local tp,z=partScreen(cam,torso)
                if hp and tp then
                    local height=math.clamp(math.abs(hp.Y-tp.Y)*3.7,30,420); local width=height*.58
                    local x,y=tp.X-width/2,tp.Y-height*.40
                    r.box.Position=UDim2.fromOffset(x,y); r.box.Size=UDim2.fromOffset(width,height); r.box.Visible=espEnabled or cornerEnabled or thermalEnabled or healthEnabled
                    local vis=not wallCheck or visible(model,head); local c=wallCheck and (vis and visibleColor or occludedColor) or espColor
                    r.fill.Position=UDim2.fromScale(0,0); r.fill.Size=UDim2.fromScale(1,1); r.fill.BackgroundColor3=thermalEnabled and Color3.fromHSV((os.clock()*.08)%1,.45,1) or c; r.fill.BackgroundTransparency=(espEnabled or thermalEnabled) and .84 or 1
                    local seg=math.max(6,width*.24); local th=1
                    r.l.Position=UDim2.fromOffset(0,0); r.l.Size=UDim2.fromOffset(th,height); r.r.Position=UDim2.new(1,-th,0,0); r.r.Size=UDim2.fromOffset(th,height)
                    r.t.Position=UDim2.fromOffset(0,0); r.t.Size=UDim2.fromOffset(width,th); r.b.Position=UDim2.new(0,0,1,-th); r.b.Size=UDim2.fromOffset(width,th)
                    for _,f in ipairs({r.l,r.r,r.t,r.b}) do f.BackgroundColor3=c; f.Visible=espEnabled or cornerEnabled or thermalEnabled end
                    r.health.Visible=espEnabled or healthEnabled; if r.health.Visible then local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1); r.health.Position=UDim2.new(1,4,1,0); r.health.Size=UDim2.fromOffset(2,-height*ratio); r.health.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(220*ratio),70) end
                    r.name.Visible=espEnabled or namesEnabled; if r.name.Visible then r.name.Position=UDim2.fromOffset(x-30,y-20); r.name.Size=UDim2.fromOffset(width+60,18); r.name.Text=string.format("%s  [%d]", model.Name, math.floor(dist+.5)) end
                    if tracersEnabled then lineFrame(r.tracer,originPoint(cam),Vector2.new(tp.X,y+height),tracerThickness,tracerColor,tracerTransparency) else r.tracer.Visible=false end
                    if r.hi then r.hi.Enabled=chamsEnabled; if chamsEnabled then r.hi.FillColor=c; r.hi.OutlineColor=c; r.hi.FillTransparency=.72; r.hi.OutlineTransparency=.08 end end
                else hideRec(r) end
            else hideRec(r) end
        end
    end
    for model,r in pairs(records) do if not nowSeen[model] or not model.Parent then if r.folder then r.folder:Destroy() end; if r.hi then r.hi:Destroy() end; records[model]=nil end end
end)

-- ============================================================================
-- BULLET TRACER: uses the real WeaponShotBuilder call on every shot.
-- ============================================================================
removeOption(WorldRec, "BulletTracer")
local tracerEnabled=false
local bulletColor=Color3.fromRGB(60,210,255)
local bulletThickness=.06
local bulletLifetime=.28
local BulletTracer=World.CreateOptionsButton({Name="BulletTracer", Function=function(v) tracerEnabled=v end})
BulletTracer.CreateColorSlider({Name="Color", Function=function(h,s,v) bulletColor=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({Name="Thickness", Min=1, Max=10, Default=3, Function=function(v) bulletThickness=v/50 end})
BulletTracer.CreateSlider({Name="Lifetime", Min=5, Max=80, Default=28, Function=function(v) bulletLifetime=v/100 end})

local function spawnTracer(origin, direction)
    if not tracerEnabled or not origin or not direction then return end
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={LocalPlayer.Character,Workspace.CurrentCamera}; rp.IgnoreWater=true
    local hit=Workspace:Raycast(origin,direction.Unit*5000,rp); local dest=hit and hit.Position or origin+direction.Unit*1200
    local len=(dest-origin).Magnitude; if len<.1 then return end
    local p=Instance.new("Part"); p.Name="YokaiBulletTracer19"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.Material=Enum.Material.Neon; p.Color=bulletColor; p.Transparency=.08; p.Size=Vector3.new(bulletThickness,bulletThickness,len); p.CFrame=CFrame.lookAt((origin+dest)/2,dest); p.Parent=Workspace
    task.delay(bulletLifetime,function() if p and p.Parent then p:Destroy() end end)
end

if ShotBuilder and originalOrigin then
    ShotBuilder.GetShotOriginAndDirection=function(...)
        local origin,dir,cf=originalOrigin(...)
        if origin and dir then
            recoilBase=Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or recoilBase; shotPulseUntil=os.clock()+.10
            task.defer(spawnTracer,origin,dir)
        end
        return origin,dir,cf
    end
end

-- Optional optimizer for the game's broken NPC LookToCamera scripts that flood the console.
if Utility then
    local suppressEnabled=false
    local suppressed=setmetatable({}, {__mode="k"})
    local function applySuppress()
        if not suppressEnabled then return end
        for _,d in ipairs(Workspace:GetDescendants()) do
            if (d:IsA("LocalScript") or d:IsA("Script")) and d.Name=="LookToCamera" and not playerOwned(d.Parent) then
                pcall(function() if not suppressed[d] then suppressed[d]=d.Disabled end; d.Disabled=true end)
            end
        end
    end
    local Suppress=Utility.CreateOptionsButton({Name="Suppress Broken NPC Look", Function=function(v)
        suppressEnabled=v
        if v then applySuppress() else for s,oldState in pairs(suppressed) do if s and s.Parent then pcall(function() s.Disabled=oldState end) end end; table.clear(suppressed) end
    end, HoverText="Optional FPS fix for NPC LookToCamera scripts that are flooding Developer Console with C0 read-only errors."})
    Workspace.DescendantAdded:Connect(function(d) if suppressEnabled and d.Name=="LookToCamera" then task.defer(applySuppress) end end)
end

shared.YokaiWeaponSystemBotRuntimeV19Loaded=true
