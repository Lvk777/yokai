-- Curated Yokai module pack
-- Keeps only the requested original modules and replaces the visual modules
-- with the standalone ESP implementations supplied by the repository owner.

repeat task.wait() until shared.GuiLibrary and shared.YokaiFullyLoaded

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local objects = GuiLibrary["ObjectsThatCanBeSaved"]
local Combat = objects["CombatWindow"] and objects["CombatWindow"]["Api"]
local Movement = objects["MovementWindow"] and objects["MovementWindow"]["Api"]
local Render = objects["RenderWindow"] and objects["RenderWindow"]["Api"]
local Utility = objects["UtilityWindow"] and objects["UtilityWindow"]["Api"]
local World = objects["WorldWindow"] and objects["WorldWindow"]["Api"]

if not (Combat and Movement and Render and Utility and World) then
    warn("CuratedModules: Yokai windows were not found")
    return
end

local function notify(title, text)
    pcall(function()
        GuiLibrary["CreateNotification"](title, text, 3)
    end)
end

local function removeModule(name)
    local key = name .. "OptionsButton"
    local obj = objects[key]
    if not obj then return end
    pcall(function()
        if obj["Api"] and obj["Api"]["Enabled"] then
            obj["Api"]["ToggleButton"](false)
        end
    end)
    pcall(function()
        GuiLibrary["RemoveObject"](key)
    end)
end

-- Preserve only the requested original modules. Visual replacements are recreated below.
local keepOriginal = {
    HitBoxes = true,
    Killaura = true,
    Reach = true,
    SilentAim = true,
    Fly = true,
    MouseTP = true,
    Speed = true,
    Arrows = true,
    Breadcrumbs = true,
}

local removeList = {}
for key, obj in pairs(objects) do
    if obj["Type"] == "OptionsButton" then
        local name = key:gsub("OptionsButton$", "")
        if not keepOriginal[name] then
            table.insert(removeList, name)
        end
    end
end
for _, name in ipairs(removeList) do
    removeModule(name)
end

-- Normalize the visible KillAura label while keeping the original implementation.
pcall(function()
    local old = objects["KillauraOptionsButton"]
    local txt = old and old["Object"] and old["Object"]:FindFirstChild("ButtonText")
    if txt then txt.Text = "KillAura" end
end)

local function isEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root and hum.Health > 0) then return false end
    if LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team then return false end
    return true
end

local function closestToMouse(maxPixels)
    if not Camera then return nil end
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local aimPart = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            if aimPart then
                local pos, visible = Camera:WorldToViewportPoint(aimPart.Position)
                if visible and pos.Z > 0 then
                    local dist = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                    if dist <= maxPixels and (not bestDist or dist < bestDist) then
                        best, bestDist = aimPart, dist
                    end
                end
            end
        end
    end
    return best
end

-- =========================
-- COMBAT
-- =========================
local antiAimSpeed = 18
local AntiAim
AntiAim = Combat.CreateOptionsButton({
    ["Name"] = "AntiAim",
    ["Function"] = function(enabled)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = not enabled end
        if enabled then
            RunService:BindToRenderStep("YokaiCuratedAntiAim", Enum.RenderPriority.Character.Value + 1, function(dt)
                local current = LocalPlayer.Character
                local root = current and current:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(antiAimSpeed * 60 * dt), 0)
                end
            end)
        else
            pcall(function() RunService:UnbindFromRenderStep("YokaiCuratedAntiAim") end)
        end
    end,
})
AntiAim.CreateSlider({
    ["Name"] = "Spin Speed",
    ["Min"] = 1,
    ["Max"] = 60,
    ["Default"] = 18,
    ["Function"] = function(v) antiAimSpeed = v end,
})

local aimFov = 180
local aimSmooth = 5
local aimConnection
local Aimbot
Aimbot = Combat.CreateOptionsButton({
    ["Name"] = "Aimbot",
    ["Function"] = function(enabled)
        if aimConnection then aimConnection:Disconnect(); aimConnection = nil end
        if enabled then
            aimConnection = RunService.RenderStepped:Connect(function()
                if not Camera then return end
                local target = closestToMouse(aimFov)
                if target then
                    local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
                    local alpha = math.clamp(1 / math.max(1, aimSmooth), 0.05, 1)
                    Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
                end
            end)
        end
    end,
})
Aimbot.CreateSlider({["Name"]="FOV", ["Min"]=20, ["Max"]=800, ["Default"]=180, ["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Smoothness", ["Min"]=1, ["Max"]=20, ["Default"]=5, ["Function"]=function(v) aimSmooth=v end})

-- =========================
-- MOVEMENT
-- =========================
local carFlySpeed = 90
local carFlyConnection
local CarFly
CarFly = Movement.CreateOptionsButton({
    ["Name"] = "CarFly",
    ["Function"] = function(enabled)
        if carFlyConnection then carFlyConnection:Disconnect(); carFlyConnection = nil end
        if enabled then
            carFlyConnection = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local seat = hum and hum.SeatPart
                if not seat then return end

                local carrier = seat.AssemblyRootPart or seat
                local forward = Camera and Camera.CFrame.LookVector or Vector3.new(0,0,-1)
                local right = Camera and Camera.CFrame.RightVector or Vector3.new(1,0,0)
                local move = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += forward end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= forward end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end

                carrier.AssemblyLinearVelocity = move.Magnitude > 0 and move.Unit * carFlySpeed or Vector3.zero
                carrier.AssemblyAngularVelocity = Vector3.zero
                if Camera then
                    local flat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
                    if flat.Magnitude > 0.01 then
                        carrier.CFrame = CFrame.lookAt(carrier.Position, carrier.Position + flat.Unit)
                    end
                end
            end)
        end
    end,
})
CarFly.CreateSlider({["Name"]="Speed", ["Min"]=10, ["Max"]=250, ["Default"]=90, ["Function"]=function(v) carFlySpeed=v end})

-- =========================
-- RENDER / ESP CORE
-- =========================
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "YokaiCuratedESP"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.DisplayOrder = 998
pcall(function() OverlayGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not OverlayGui.Parent then OverlayGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function newLine(parent, color, thickness)
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.AnchorPoint = Vector2.new(0.5,0.5)
    line.BackgroundColor3 = color or Color3.new(1,1,1)
    line.Size = UDim2.fromOffset(0, thickness or 1)
    line.Visible = false
    line.Parent = parent or OverlayGui
    return line
end

local function setLine(line, a, b, thickness)
    local delta = b - a
    local length = delta.Magnitude
    line.Size = UDim2.fromOffset(length, thickness or 1)
    line.Position = UDim2.fromOffset((a.X+b.X)/2, (a.Y+b.Y)/2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.Visible = true
end

local function screenRoot(plr)
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum and hum.Health > 0 and Camera) then return end
    local pos, visible = Camera:WorldToViewportPoint(root.Position)
    if not visible or pos.Z <= 0 then return end
    local scale = (root.Size.Y * Camera.ViewportSize.Y) / (pos.Z * 2)
    return root, hum, Vector2.new(pos.X,pos.Y), 3*scale, 4.5*scale
end

-- Skeleton ESP (the requested generic ESP toggle)
local skeletonEnabled = false
local skeletonColor = Color3.new(1,1,1)
local skeletonLines = {}
local skeletonBonesR15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local skeletonBonesR6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function clearSkeleton(plr)
    if skeletonLines[plr] then
        for _, l in ipairs(skeletonLines[plr]) do l:Destroy() end
        skeletonLines[plr] = nil
    end
end

local ESP
ESP = Render.CreateOptionsButton({
    ["Name"]="ESP",
    ["Function"]=function(enabled)
        skeletonEnabled = enabled
        if not enabled then
            for plr in pairs(skeletonLines) do clearSkeleton(plr) end
        end
    end,
})
ESP.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) skeletonColor=Color3.fromHSV(h,s,v) end})

-- Chams replacement based on the supplied thermal Highlight implementation.
local chamsEnabled = false
local chamsColor = Color3.fromRGB(119,120,255)
local chamsThermal = true
local chamsVisibleCheck = false
local chams = {}
local Chams
Chams = Render.CreateOptionsButton({
    ["Name"]="Chams",
    ["Function"]=function(enabled)
        chamsEnabled = enabled
        if not enabled then
            for _, h in pairs(chams) do h:Destroy() end
            table.clear(chams)
        end
    end,
})
Chams.CreateToggle({["Name"]="Thermal", ["Default"]=true, ["Function"]=function(v) chamsThermal=v end})
Chams.CreateToggle({["Name"]="Visible Check", ["Default"]=false, ["Function"]=function(v) chamsVisibleCheck=v end})
Chams.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) chamsColor=Color3.fromHSV(h,s,v) end})

-- Health replacement based on the supplied gradient healthbar.
local healthEnabled = false
local healthObjects = {}
local Health
Health = Render.CreateOptionsButton({
    ["Name"]="Health",
    ["Function"]=function(enabled)
        healthEnabled=enabled
        if not enabled then
            for _, pack in pairs(healthObjects) do
                for _, obj in pairs(pack) do if typeof(obj)=="Instance" then obj:Destroy() end end
            end
            table.clear(healthObjects)
        end
    end,
})

-- Name and Distance replacements, separated into independent toggles.
local nameEnabled, distanceEnabled = false, false
local nameColor, distanceColor = Color3.new(1,1,1), Color3.new(1,1,1)
local labels = {}
local NameESP = Render.CreateOptionsButton({["Name"]="Name", ["Function"]=function(v) nameEnabled=v end})
NameESP.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) nameColor=Color3.fromHSV(h,s,v) end})
local DistanceESP = Render.CreateOptionsButton({["Name"]="Distance", ["Function"]=function(v) distanceEnabled=v end})
DistanceESP.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) distanceColor=Color3.fromHSV(h,s,v) end})

-- Box replacement: Corner / Thermal Corner / 3D, covering the three supplied box scripts.
local boxEnabled = false
local boxMode = "Corner"
local boxColor = Color3.new(1,1,1)
local boxFill = Color3.fromRGB(119,120,255)
local boxes = {}
local BoxESP
BoxESP = Render.CreateOptionsButton({
    ["Name"]="Box",
    ["Function"]=function(v)
        boxEnabled=v
        if not v then
            for _, pack in pairs(boxes) do for _, obj in ipairs(pack) do obj:Destroy() end end
            table.clear(boxes)
        end
    end,
})
BoxESP.CreateDropdown({["Name"]="Mode", ["List"]={"Corner","Thermal Corner","3D"}, ["Function"]=function(v) boxMode=v end})
BoxESP.CreateColorSlider({["Name"]="Line Color", ["Function"]=function(h,s,v) boxColor=Color3.fromHSV(h,s,v) end})
BoxESP.CreateColorSlider({["Name"]="Fill Color", ["Function"]=function(h,s,v) boxFill=Color3.fromHSV(h,s,v) end})

-- Tracers replacement based on the supplied bottom/center ScreenGui tracer.
local tracersEnabled = false
local tracerColor = Color3.new(1,1,1)
local tracerThickness = 1
local tracerFromCenter = false
local tracerLines = {}
local Tracers
Tracers = Render.CreateOptionsButton({
    ["Name"]="Tracers",
    ["Function"]=function(v)
        tracersEnabled=v
        if not v then
            for _, line in pairs(tracerLines) do line:Destroy() end
            table.clear(tracerLines)
        end
    end,
})
Tracers.CreateToggle({["Name"]="From Center", ["Default"]=false, ["Function"]=function(v) tracerFromCenter=v end})
Tracers.CreateSlider({["Name"]="Thickness", ["Min"]=1, ["Max"]=5, ["Default"]=1, ["Function"]=function(v) tracerThickness=v end})
Tracers.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})

-- Gun Chams: local equipped tools, with configurable color and Roblox material.
local gunChamsEnabled = false
local gunChamsColor = Color3.fromRGB(119,120,255)
local gunChamsMaterial = "ForceField"
local gunOriginals = {}
local materialNames = {"ForceField","Neon","Glass","Metal","SmoothPlastic"}

local function restoreGunChams()
    for part, old in pairs(gunOriginals) do
        if part and part.Parent then
            pcall(function()
                part.Color = old.Color
                part.Material = old.Material
            end)
        end
    end
    table.clear(gunOriginals)
end

local function applyGunChams()
    if not gunChamsEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj:FindFirstAncestorOfClass("Tool") then
            if not gunOriginals[obj] then gunOriginals[obj] = {Color=obj.Color, Material=obj.Material} end
            obj.Color = gunChamsColor
            obj.Material = Enum.Material[gunChamsMaterial] or Enum.Material.ForceField
        end
    end
end

local GunChams
GunChams = Render.CreateOptionsButton({
    ["Name"]="GunChams",
    ["Function"]=function(v)
        gunChamsEnabled=v
        if v then applyGunChams() else restoreGunChams() end
    end,
})
GunChams.CreateDropdown({["Name"]="Material", ["List"]=materialNames, ["Function"]=function(v) gunChamsMaterial=v; applyGunChams() end})
GunChams.CreateColorSlider({["Name"]="Color", ["Function"]=function(h,s,v) gunChamsColor=Color3.fromHSV(h,s,v); applyGunChams() end})

-- Single render loop for the replacement ESP set.
RunService.RenderStepped:Connect(function()
    if gunChamsEnabled then applyGunChams() end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local enemy = isEnemy(plr)
            local root, hum, pos, w, h = enemy and screenRoot(plr) or nil

            -- Chams
            if chamsEnabled and enemy and plr.Character then
                local hi = chams[plr]
                if not hi then
                    hi = Instance.new("Highlight")
                    hi.Name = "YokaiCuratedChams"
                    hi.Parent = OverlayGui
                    chams[plr] = hi
                end
                hi.Adornee = plr.Character
                hi.Enabled = true
                hi.FillColor = chamsColor
                hi.OutlineColor = chamsColor
                hi.DepthMode = chamsVisibleCheck and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
                local breathe = chamsThermal and (0.55 + (math.sin(tick()*2)+1)*0.15) or 0.75
                hi.FillTransparency = breathe
                hi.OutlineTransparency = chamsThermal and math.clamp(breathe-0.2,0,1) or 0
            elseif chams[plr] then
                chams[plr].Enabled = false
            end

            -- Skeleton
            if skeletonEnabled and enemy and plr.Character then
                local bones = plr.Character:FindFirstChild("UpperTorso") and skeletonBonesR15 or skeletonBonesR6
                if not skeletonLines[plr] or #skeletonLines[plr] ~= #bones then
                    clearSkeleton(plr)
                    skeletonLines[plr] = {}
                    for i=1,#bones do skeletonLines[plr][i]=newLine(OverlayGui,skeletonColor,1) end
                end
                for i, pair in ipairs(bones) do
                    local a, b = plr.Character:FindFirstChild(pair[1]), plr.Character:FindFirstChild(pair[2])
                    local line = skeletonLines[plr][i]
                    if a and b and Camera then
                        local sa, va = Camera:WorldToViewportPoint(a.Position)
                        local sb, vb = Camera:WorldToViewportPoint(b.Position)
                        if va and vb and sa.Z>0 and sb.Z>0 then
                            line.BackgroundColor3=skeletonColor
                            setLine(line,Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),1)
                        else line.Visible=false end
                    else line.Visible=false end
                end
            elseif skeletonLines[plr] then
                for _, line in ipairs(skeletonLines[plr]) do line.Visible=false end
            end

            -- Name / distance labels
            if (nameEnabled or distanceEnabled) and root then
                local pack = labels[plr]
                if not pack then
                    local n = Instance.new("TextLabel")
                    n.BackgroundTransparency=1; n.Font=Enum.Font.Code; n.TextSize=11; n.TextStrokeTransparency=0; n.Size=UDim2.fromOffset(220,18); n.AnchorPoint=Vector2.new(0.5,0.5); n.Parent=OverlayGui
                    local d=n:Clone(); d.Parent=OverlayGui
                    pack={Name=n,Distance=d}; labels[plr]=pack
                end
                pack.Name.Visible=nameEnabled
                pack.Distance.Visible=distanceEnabled
                if nameEnabled then
                    pack.Name.Text=plr.Name
                    pack.Name.TextColor3=nameColor
                    pack.Name.Position=UDim2.fromOffset(pos.X,pos.Y-h/2-12)
                end
                if distanceEnabled then
                    local dist=(Camera.CFrame.Position-root.Position).Magnitude
                    pack.Distance.Text=string.format("%d studs",math.floor(dist))
                    pack.Distance.TextColor3=distanceColor
                    pack.Distance.Position=UDim2.fromOffset(pos.X,pos.Y+h/2+10)
                end
            elseif labels[plr] then
                labels[plr].Name.Visible=false; labels[plr].Distance.Visible=false
            end

            -- Healthbar
            if healthEnabled and root then
                local pack=healthObjects[plr]
                if not pack then
                    local bg=Instance.new("Frame"); bg.BorderSizePixel=0; bg.BackgroundColor3=Color3.new(0,0,0); bg.Parent=OverlayGui
                    local bar=Instance.new("Frame"); bar.BorderSizePixel=0; bar.BackgroundColor3=Color3.new(1,1,1); bar.Parent=OverlayGui
                    local grad=Instance.new("UIGradient"); grad.Rotation=-90; grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,0,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(60,60,125)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,120,255))}); grad.Parent=bar
                    local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.Font=Enum.Font.Code; text.TextSize=10; text.TextStrokeTransparency=0; text.Size=UDim2.fromOffset(40,14); text.Parent=OverlayGui
                    pack={Bg=bg,Bar=bar,Text=text}; healthObjects[plr]=pack
                end
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                pack.Bg.Visible=true; pack.Bar.Visible=true
                pack.Bg.Position=UDim2.fromOffset(pos.X-w/2-7,pos.Y-h/2); pack.Bg.Size=UDim2.fromOffset(4,h)
                pack.Bar.Position=UDim2.fromOffset(pos.X-w/2-7,pos.Y-h/2+h*(1-ratio)); pack.Bar.Size=UDim2.fromOffset(4,h*ratio)
                pack.Text.Text=tostring(math.floor(ratio*100)); pack.Text.TextColor3=Color3.new(1,1,1); pack.Text.Position=UDim2.fromOffset(pos.X-w/2-28,pos.Y-h/2+h*(1-ratio)-5); pack.Text.Visible=ratio<1
            elseif healthObjects[plr] then
                healthObjects[plr].Bg.Visible=false; healthObjects[plr].Bar.Visible=false; healthObjects[plr].Text.Visible=false
            end

            -- Box
            if boxEnabled and root then
                local needed = boxMode=="3D" and 12 or 9
                if not boxes[plr] or #boxes[plr] ~= needed then
                    if boxes[plr] then for _,o in ipairs(boxes[plr]) do o:Destroy() end end
                    boxes[plr]={}
                    for i=1,needed do boxes[plr][i]=newLine(OverlayGui,boxColor,1) end
                end
                local pack=boxes[plr]
                if boxMode=="3D" then
                    local corners={}
                    local cf=root.CFrame*CFrame.new(0,-0.5,0)
                    local sz=Vector3.new(3,5,3)/2
                    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(corners,(cf*CFrame.new(sz*Vector3.new(x,y,z))).Position) end end end
                    local sp={}; local okay=true
                    for i,c in ipairs(corners) do local p,v=Camera:WorldToViewportPoint(c); sp[i]=Vector2.new(p.X,p.Y); if not v or p.Z<=0 then okay=false end end
                    local edges={{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}
                    for i,e in ipairs(edges) do pack[i].BackgroundColor3=boxColor; if okay then setLine(pack[i],sp[e[1]],sp[e[2]],1) else pack[i].Visible=false end end
                else
                    local left,right,top,bottom=pos.X-w/2,pos.X+w/2,pos.Y-h/2,pos.Y+h/2
                    local cw,ch=w/5,h/5
                    local pts={{Vector2.new(left,top),Vector2.new(left+cw,top)},{Vector2.new(left,top),Vector2.new(left,top+ch)},{Vector2.new(right,top),Vector2.new(right-cw,top)},{Vector2.new(right,top),Vector2.new(right,top+ch)},{Vector2.new(left,bottom),Vector2.new(left+cw,bottom)},{Vector2.new(left,bottom),Vector2.new(left,bottom-ch)},{Vector2.new(right,bottom),Vector2.new(right-cw,bottom)},{Vector2.new(right,bottom),Vector2.new(right,bottom-ch)}}
                    for i,pair in ipairs(pts) do pack[i].BackgroundColor3=boxColor; setLine(pack[i],pair[1],pair[2],1) end
                    local fill=pack[9]; fill.Rotation=0; fill.Size=UDim2.fromOffset(w,h); fill.Position=UDim2.fromOffset(pos.X,pos.Y); fill.BackgroundColor3=boxMode=="Thermal Corner" and boxFill or Color3.new(0,0,0); fill.BackgroundTransparency=boxMode=="Thermal Corner" and (0.5+(math.sin(tick()*2)+1)*0.15) or 0.75; fill.Visible=true
                end
            elseif boxes[plr] then
                for _,o in ipairs(boxes[plr]) do o.Visible=false end
            end

            -- Tracers
            if tracersEnabled and root then
                local line=tracerLines[plr]
                if not line then line=newLine(OverlayGui,tracerColor,tracerThickness); tracerLines[plr]=line end
                local vp=Camera.ViewportSize
                local start=tracerFromCenter and Vector2.new(vp.X/2,vp.Y/2) or Vector2.new(vp.X/2,vp.Y)
                line.BackgroundColor3=tracerColor
                setLine(line,start,pos,tracerThickness)
            elseif tracerLines[plr] then tracerLines[plr].Visible=false end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    clearSkeleton(plr)
    if chams[plr] then chams[plr]:Destroy(); chams[plr]=nil end
    if labels[plr] then labels[plr].Name:Destroy(); labels[plr].Distance:Destroy(); labels[plr]=nil end
    if healthObjects[plr] then for _,o in pairs(healthObjects[plr]) do if typeof(o)=="Instance" then o:Destroy() end end; healthObjects[plr]=nil end
    if boxes[plr] then for _,o in ipairs(boxes[plr]) do o:Destroy() end; boxes[plr]=nil end
    if tracerLines[plr] then tracerLines[plr]:Destroy(); tracerLines[plr]=nil end
end)

-- =========================
-- UTILITY
-- =========================
local ServerHop
ServerHop = Utility.CreateOptionsButton({
    ["Name"]="ServerHop",
    ["Function"]=function(enabled)
        if not enabled then return end
        task.spawn(function()
            local ok, err = pcall(function()
                local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
                local data = HttpService:JSONDecode(raw)
                local choices={}
                for _,s in ipairs(data.data or {}) do
                    if s.id ~= game.JobId and s.playing < s.maxPlayers then table.insert(choices,s) end
                end
                if #choices==0 then error("No available server") end
                local pick=choices[math.random(1,#choices)]
                TeleportService:TeleportToPlaceInstance(game.PlaceId,pick.id,LocalPlayer)
            end)
            if not ok then notify("ServerHop", tostring(err)) end
            pcall(function() ServerHop.ToggleButton(false) end)
        end)
    end,
})

local hitSoundEnabled=false
local hitSoundId="rbxassetid://9118823106"
local hitSoundVolume=1
local watchedHumanoids={}
local sound=Instance.new("Sound")
sound.Name="YokaiHitSound"; sound.Parent=game:GetService("SoundService"); sound.SoundId=hitSoundId; sound.Volume=hitSoundVolume
local function watchHumanoid(plr)
    if plr==LocalPlayer then return end
    local char=plr.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum or watchedHumanoids[hum] then return end
    watchedHumanoids[hum]=hum.Health
    hum.HealthChanged:Connect(function(newHealth)
        local old=watchedHumanoids[hum] or newHealth
        watchedHumanoids[hum]=newHealth
        if hitSoundEnabled and newHealth<old then
            local mychar=LocalPlayer.Character
            if mychar and mychar:FindFirstChildOfClass("Tool") then sound:Play() end
        end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do if p.Character then watchHumanoid(p) end; p.CharacterAdded:Connect(function() task.wait(.2); watchHumanoid(p) end) end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(.2); watchHumanoid(p) end) end)
local HitSound=Utility.CreateOptionsButton({["Name"]="HitSound",["Function"]=function(v) hitSoundEnabled=v end})
HitSound.CreateSlider({["Name"]="Volume",["Min"]=1,["Max"]=10,["Default"]=5,["Function"]=function(v) hitSoundVolume=v/5; sound.Volume=hitSoundVolume end})

local kickBlockEnabled=false
local kickHookInstalled=false
local ClientKickDisable
ClientKickDisable=Utility.CreateOptionsButton({
    ["Name"]="ClientKickDisable",
    ["Function"]=function(v)
        kickBlockEnabled=v
        if v and not kickHookInstalled then
            kickHookInstalled=true
            if hookmetamethod and getnamecallmethod then
                local old
                old=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
                    if kickBlockEnabled and self==LocalPlayer and getnamecallmethod()=="Kick" then return nil end
                    return old(self,...)
                end))
            else
                notify("ClientKickDisable","Executor does not expose hookmetamethod")
            end
        end
    end,
})

-- =========================
-- WORLD
-- =========================
local lightingOriginal={Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogStart=Lighting.FogStart,FogEnd=Lighting.FogEnd,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient}

local FullBrightness=World.CreateOptionsButton({
    ["Name"]="FullBrightness",
    ["Function"]=function(v)
        if v then
            Lighting.Brightness=3; Lighting.ClockTime=14; Lighting.Ambient=Color3.fromRGB(180,180,180); Lighting.OutdoorAmbient=Color3.fromRGB(180,180,180)
        else
            Lighting.Brightness=lightingOriginal.Brightness; Lighting.ClockTime=lightingOriginal.ClockTime; Lighting.Ambient=lightingOriginal.Ambient; Lighting.OutdoorAmbient=lightingOriginal.OutdoorAmbient
        end
    end,
})

local Night=World.CreateOptionsButton({
    ["Name"]="Night",
    ["Function"]=function(v)
        if v then
            Lighting.ClockTime=0; Lighting.Brightness=2.2; Lighting.Ambient=Color3.fromRGB(115,120,145); Lighting.OutdoorAmbient=Color3.fromRGB(90,95,120)
        else
            Lighting.ClockTime=lightingOriginal.ClockTime; Lighting.Brightness=lightingOriginal.Brightness; Lighting.Ambient=lightingOriginal.Ambient; Lighting.OutdoorAmbient=lightingOriginal.OutdoorAmbient
        end
    end,
})

local fogOriginal={}
local NoFog=World.CreateOptionsButton({
    ["Name"]="NoFog",
    ["Function"]=function(v)
        if v then
            Lighting.FogStart=1e6; Lighting.FogEnd=1e7
            for _,a in ipairs(Lighting:GetChildren()) do
                if a:IsA("Atmosphere") then fogOriginal[a]={Density=a.Density,Haze=a.Haze}; a.Density=0; a.Haze=0 end
            end
        else
            Lighting.FogStart=lightingOriginal.FogStart; Lighting.FogEnd=lightingOriginal.FogEnd
            for a,old in pairs(fogOriginal) do if a.Parent then a.Density=old.Density; a.Haze=old.Haze end end
            table.clear(fogOriginal)
        end
    end,
})

local leafCache={}
local terrainDecoration
pcall(function() terrainDecoration=Workspace.Terrain.Decoration end)
local NoLeaves=World.CreateOptionsButton({
    ["Name"]="NoLeaves",
    ["Function"]=function(v)
        pcall(function() Workspace.Terrain.Decoration=not v and terrainDecoration or false end)
        if v then
            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name:lower():find("leaf") or obj.Name:lower():find("leaves")) then
                    leafCache[obj]=obj.LocalTransparencyModifier; obj.LocalTransparencyModifier=1
                end
            end
        else
            for obj,old in pairs(leafCache) do if obj.Parent then obj.LocalTransparencyModifier=old end end
            table.clear(leafCache)
        end
    end,
})

local oldSkies={}
for _,s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") then table.insert(oldSkies,s:Clone()) end end
local skyPreset="Purple Nebula"
local skyIds={
    ["Purple Nebula"]={"159454299","159454296","159454293","159454286","159454300","159454288"},
    ["Blue"]={"271042310","271042516","271077243","271042556","271042467","271077958"},
}
local function applySky(name)
    for _,s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") and s.Name=="YokaiCuratedSky" then s:Destroy() end end
    if name=="Default" then
        for _,s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") then s:Destroy() end end
        for _,s in ipairs(oldSkies) do s:Clone().Parent=Lighting end
        return
    end
    local ids=skyIds[name]; if not ids then return end
    local sky=Instance.new("Sky"); sky.Name="YokaiCuratedSky"
    sky.SkyboxBk="rbxassetid://"..ids[1]; sky.SkyboxDn="rbxassetid://"..ids[2]; sky.SkyboxFt="rbxassetid://"..ids[3]; sky.SkyboxLf="rbxassetid://"..ids[4]; sky.SkyboxRt="rbxassetid://"..ids[5]; sky.SkyboxUp="rbxassetid://"..ids[6]
    sky.Parent=Lighting
end
local ChangeSkydome=World.CreateOptionsButton({["Name"]="ChangeSkydome",["Function"]=function(v) if v then applySky(skyPreset) else applySky("Default") end end})
ChangeSkydome.CreateDropdown({["Name"]="Preset",["List"]={"Purple Nebula","Blue","Default"},["Function"]=function(v) skyPreset=v; if ChangeSkydome.Enabled then applySky(v) end end})

local fovValue=90
local FOV=World.CreateOptionsButton({
    ["Name"]="FOV",
    ["Function"]=function(v)
        if v and Camera then Camera.FieldOfView=fovValue end
    end,
})
FOV.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=120,["Default"]=90,["Function"]=function(v) fovValue=v; if FOV.Enabled and Camera then Camera.FieldOfView=v end end})
RunService.RenderStepped:Connect(function() if FOV.Enabled and Camera then Camera.FieldOfView=fovValue end end)

-- Bullet tracer: generic projectile-part tracker. Material and color are configurable.
local bulletTracerEnabled=false
local bulletTracerColor=Color3.fromRGB(255,255,255)
local bulletTracerMaterial="Neon"
local bulletLife=1
local bulletNames={bullet=true,projectile=true,tracer=true,shell=false}
local function looksLikeProjectile(obj)
    if not obj:IsA("BasePart") then return false end
    local n=obj.Name:lower()
    for word,enabled in pairs(bulletNames) do if enabled and n:find(word) then return true end end
    return false
end
local function makeBulletTrace(part)
    if not bulletTracerEnabled or not part.Parent then return end
    local start=part.Position
    local line=Instance.new("Part")
    line.Name="YokaiBulletTracer"; line.Anchored=true; line.CanCollide=false; line.CanQuery=false; line.CanTouch=false; line.CastShadow=false
    line.Material=Enum.Material[bulletTracerMaterial] or Enum.Material.Neon; line.Color=bulletTracerColor; line.Size=Vector3.new(0.05,0.05,0.05); line.Parent=Workspace
    local born=tick(); local conn
    conn=RunService.Heartbeat:Connect(function()
        if not bulletTracerEnabled or not part.Parent or tick()-born>bulletLife then
            if conn then conn:Disconnect() end; line:Destroy(); return
        end
        local finish=part.Position; local delta=finish-start; local len=math.max(delta.Magnitude,0.05)
        line.Material=Enum.Material[bulletTracerMaterial] or Enum.Material.Neon; line.Color=bulletTracerColor
        line.Size=Vector3.new(0.05,0.05,len); line.CFrame=CFrame.lookAt((start+finish)/2,finish)
    end)
end
Workspace.DescendantAdded:Connect(function(obj) if bulletTracerEnabled and looksLikeProjectile(obj) then task.defer(makeBulletTrace,obj) end end)
local BulletTracer=World.CreateOptionsButton({["Name"]="BulletTracer",["Function"]=function(v) bulletTracerEnabled=v end})
BulletTracer.CreateDropdown({["Name"]="Material",["List"]=materialNames,["Function"]=function(v) bulletTracerMaterial=v end})
BulletTracer.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) bulletTracerColor=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({["Name"]="Lifetime",["Min"]=1,["Max"]=30,["Default"]=10,["Function"]=function(v) bulletLife=v/10 end})

notify("Yokai", "Curated module set loaded")
