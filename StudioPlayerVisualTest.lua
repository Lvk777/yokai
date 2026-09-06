-- Authorized test-only player visuals.
-- This file intentionally does nothing outside Roblox Studio.

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then
    warn("StudioPlayerVisualTest: Visuals missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end

local function isUnder(rec, parentRec)
    if not rec or not rec["Object"] or not parentRec then return false end
    local obj = rec["Object"]
    for _, root in ipairs({parentRec["Object"], parentRec["ChildrenObject"]}) do
        if root and typeof(root) == "Instance" and (obj == root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end

local function findVisualOption(name)
    local found
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name and isUnder(rec, VisualsRec) then
            found = rec
        end
    end
    return found
end

local function enabled(name)
    local rec = findVisualOption(name)
    local api = rec and rec["Api"]
    return api and api["Enabled"] == true
end

local function removeVisualOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name and isUnder(rec, VisualsRec) then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api.Enabled and api.ToggleButton then api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- Disable the older live overlay only in Studio so the test layer does not double-render.
for _, root in ipairs({LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui}) do
    if root then
        local old = root:FindFirstChild("YokaiAttachedVisualsFunctional", true)
        if old and old:IsA("ScreenGui") then old.Enabled = false end
    end
end
pcall(function()
    if gethui then
        local old = gethui():FindFirstChild("YokaiAttachedVisualsFunctional", true)
        if old and old:IsA("ScreenGui") then old.Enabled = false end
    end
end)

-- Rebuild Skeleton in Studio so its actual player rendering uses the same controls.
removeVisualOption("Skeleton")
local skeletonState = {
    Enabled = false,
    Color = Color3.fromRGB(255,255,255),
    Transparency = 0,
    Thickness = 1,
}
shared.YokaiStudioSkeletonState = skeletonState

local Skeleton = Visuals.CreateOptionsButton({
    ["Name"] = "Skeleton",
    ["Function"] = function(v) skeletonState.Enabled = v end,
    ["HoverText"] = "Studio test players: skeleton color, transparency and thickness.",
})
Skeleton.CreateColorSlider({
    ["Name"] = "Color",
    ["Function"] = function(h,s,v) skeletonState.Color = Color3.fromHSV(h,s,v) end,
})
Skeleton.CreateSlider({
    ["Name"] = "Transparency",
    ["Min"] = 0,
    ["Max"] = 95,
    ["Default"] = 0,
    ["Function"] = function(v) skeletonState.Transparency = v / 100 end,
})
Skeleton.CreateSlider({
    ["Name"] = "Thickness",
    ["Min"] = 1,
    ["Max"] = 5,
    ["Default"] = 1,
    ["Function"] = function(v) skeletonState.Thickness = v end,
})

local overlay = Instance.new("ScreenGui")
overlay.Name = "YokaiStudioPlayerVisualsV1"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 996
pcall(function() overlay.Parent = (gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function newLine(parent)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(.5,.5)
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.new(1,1,1)
    f.Visible = false
    f.Parent = parent
    return f
end

local function setLine(line, a, b, thickness, color, transparency)
    local d = b - a
    if d.Magnitude < 0.01 then line.Visible = false return end
    line.Size = UDim2.fromOffset(d.Magnitude, thickness or 1)
    line.Position = UDim2.fromOffset((a.X+b.X)/2, (a.Y+b.Y)/2)
    line.Rotation = math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3 = color or Color3.new(1,1,1)
    line.BackgroundTransparency = transparency or 0
    line.Visible = true
end

local function hideLines(lines)
    for _, l in ipairs(lines or {}) do l.Visible = false end
end

local stores = {}
local function makeStore(plr)
    local s = {Player = plr}
    s.Highlight = Instance.new("Highlight")
    s.Highlight.Name = "YokaiStudioESPHighlight"
    s.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    s.Highlight.FillTransparency = .72
    s.Highlight.OutlineTransparency = 0
    s.Highlight.Enabled = false
    s.Highlight.Parent = Workspace

    s.Name = Instance.new("TextLabel")
    s.Name.BackgroundTransparency = 1
    s.Name.AnchorPoint = Vector2.new(.5,.5)
    s.Name.Size = UDim2.fromOffset(240,18)
    s.Name.Font = Enum.Font.Code
    s.Name.TextSize = 12
    s.Name.TextStrokeTransparency = 0
    s.Name.TextStrokeColor3 = Color3.new(0,0,0)
    s.Name.TextColor3 = Color3.new(1,1,1)
    s.Name.Visible = false
    s.Name.Parent = overlay

    s.Distance = s.Name:Clone()
    s.Distance.TextSize = 11
    s.Distance.Parent = overlay

    s.HealthBack = Instance.new("Frame")
    s.HealthBack.BorderSizePixel = 0
    s.HealthBack.BackgroundColor3 = Color3.new(0,0,0)
    s.HealthBack.Visible = false
    s.HealthBack.Parent = overlay

    s.Health = Instance.new("Frame")
    s.Health.BorderSizePixel = 0
    s.Health.BackgroundColor3 = Color3.new(1,1,1)
    s.Health.Visible = false
    s.Health.Parent = overlay
    s.HealthGradient = Instance.new("UIGradient")
    s.HealthGradient.Rotation = -90
    s.HealthGradient.Parent = s.Health

    s.HealthText = s.Name:Clone()
    s.HealthText.Size = UDim2.fromOffset(44,16)
    s.HealthText.TextSize = 11
    s.HealthText.Parent = overlay

    s.Corners = {}
    for i=1,8 do s.Corners[i] = newLine(overlay) end
    s.Skeleton = {}
    for i=1,15 do s.Skeleton[i] = newLine(overlay) end
    s.Tracer = newLine(overlay)

    stores[plr] = s
    return s
end

local function destroyStore(plr)
    local s = stores[plr]
    if not s then return end
    for _, v in pairs(s) do
        if typeof(v) == "Instance" then pcall(function() v:Destroy() end)
        elseif type(v) == "table" then
            for _, x in ipairs(v) do if typeof(x) == "Instance" then pcall(function() x:Destroy() end) end end
        end
    end
    stores[plr] = nil
end
Players.PlayerRemoving:Connect(destroyStore)

local function hideStore(s)
    s.Highlight.Enabled = false
    s.Name.Visible = false
    s.Distance.Visible = false
    s.HealthBack.Visible = false
    s.Health.Visible = false
    s.HealthText.Visible = false
    s.Tracer.Visible = false
    hideLines(s.Corners)
    hideLines(s.Skeleton)
end

local function bounds2D(char)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local ok, cf, size = pcall(function()
        local a,b = char:GetBoundingBox()
        return a,b
    end)
    if not ok or not cf or not size then return nil end
    local minX,minY = math.huge,math.huge
    local maxX,maxY = -math.huge,-math.huge
    local any = false
    for x=-1,1,2 do
        for y=-1,1,2 do
            for z=-1,1,2 do
                local world = (cf * CFrame.new(size.X*x/2, size.Y*y/2, size.Z*z/2)).Position
                local p = cam:WorldToViewportPoint(world)
                if p.Z > 0 then
                    any = true
                    minX = math.min(minX,p.X) minY = math.min(minY,p.Y)
                    maxX = math.max(maxX,p.X) maxY = math.max(maxY,p.Y)
                end
            end
        end
    end
    if not any or maxX < 0 or maxY < 0 or minX > cam.ViewportSize.X or minY > cam.ViewportSize.Y then return nil end
    return Vector2.new(minX,minY), Vector2.new(maxX,maxY)
end

local function targetVisible(char, targetPart)
    local cam = Workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local origin = cam.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, cam}
    params.IgnoreWater = true
    local hit = Workspace:Raycast(origin, direction, params)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(char))
end

local function updateCorners(lines, tl, br, color)
    local l,t,r,b = tl.X,tl.Y,br.X,br.Y
    local w,h = r-l,b-t
    local cw,ch = math.max(6,w*.24),math.max(6,h*.18)
    local seg = {
        {Vector2.new(l,t),Vector2.new(l+cw,t)}, {Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)}, {Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)}, {Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)}, {Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],1,color,0) end
end

local r15Bones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local r6Bones = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function updateSkeleton(s, char)
    if not skeletonState.Enabled then hideLines(s.Skeleton) return end
    local cam = Workspace.CurrentCamera
    if not cam then hideLines(s.Skeleton) return end
    local bones = char:FindFirstChild("UpperTorso") and r15Bones or r6Bones
    local used = 0
    for _, pair in ipairs(bones) do
        local a,b = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local pa,ona = cam:WorldToViewportPoint(a.Position)
            local pb,onb = cam:WorldToViewportPoint(b.Position)
            if ona and onb and pa.Z > 0 and pb.Z > 0 then
                used += 1
                setLine(s.Skeleton[used],Vector2.new(pa.X,pa.Y),Vector2.new(pb.X,pb.Y),skeletonState.Thickness,skeletonState.Color,skeletonState.Transparency)
            end
        end
    end
    for i=used+1,#s.Skeleton do s.Skeleton[i].Visible = false end
end

local function healthColors()
    local polish = shared.YokaiPreviewPolishState or {}
    if polish.HealthPalette == "Mint / Yellow / Red" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(230,55,55)),
            ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(120,255,205)),
        })
    end
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(220,40,50)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(50,110,255)),
    })
end

local function tracerOrigin()
    local cam = Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    local vp = cam.ViewportSize
    local state = shared.YokaiVisualPreviewState or {}
    local origin = state.TracerOrigin or "Bottom"
    if origin == "Top" then return Vector2.new(vp.X/2,0) end
    if origin == "Center" then return Vector2.new(vp.X/2,vp.Y/2) end
    if origin == "Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(vp.X/2,vp.Y)
end

RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera
    if not cam then return end

    local espOn = enabled("ESP")
    local healthOn = enabled("HealthBar") or espOn
    local namesOn = enabled("Name + Distance") or espOn
    local cornerOn = enabled("Corner Box") or espOn
    local tracerOn = enabled("Tracers")
    local state = shared.YokaiVisualPreviewState or {}
    local defaultColor = state.DefaultColor or Color3.fromRGB(119,120,255)
    local visibleColor = state.VisibleColor or Color3.fromRGB(35,235,95)
    local occludedColor = state.OccludedColor or Color3.fromRGB(245,55,55)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local s = stores[plr] or makeStore(plr)
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            if not char or not hum or not root or hum.Health <= 0 then
                hideStore(s)
                continue
            end

            local tl,br = bounds2D(char)
            if not tl then
                hideStore(s)
                continue
            end

            local visible = targetVisible(char, head or root)
            local color = defaultColor
            if espOn and state.WallCheck then color = visible and visibleColor or occludedColor end

            s.Highlight.Adornee = char
            s.Highlight.Enabled = espOn
            s.Highlight.FillColor = color
            s.Highlight.OutlineColor = color

            if cornerOn then updateCorners(s.Corners,tl,br,color) else hideLines(s.Corners) end

            local centerX = (tl.X+br.X)/2
            if namesOn then
                s.Name.Position = UDim2.fromOffset(centerX,tl.Y-11)
                s.Name.Text = plr.Name
                s.Name.TextColor3 = Color3.new(1,1,1)
                s.Name.Visible = true
                local dist = (cam.CFrame.Position-root.Position).Magnitude/3.5714285714
                s.Distance.Position = UDim2.fromOffset(centerX,br.Y+9)
                s.Distance.Text = string.format("%d meters",math.floor(dist))
                s.Distance.TextColor3 = Color3.new(1,1,1)
                s.Distance.Visible = true
            else
                s.Name.Visible = false s.Distance.Visible = false
            end

            if healthOn then
                local ratio = math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                local h = math.max(4,br.Y-tl.Y)
                s.HealthBack.Position = UDim2.fromOffset(tl.X-7,tl.Y)
                s.HealthBack.Size = UDim2.fromOffset(4,h)
                s.HealthBack.Visible = true
                s.Health.Position = UDim2.fromOffset(tl.X-7,tl.Y+h*(1-ratio))
                s.Health.Size = UDim2.fromOffset(4,h*ratio)
                s.HealthGradient.Color = healthColors()
                s.Health.Visible = true
                s.HealthText.Position = UDim2.fromOffset(tl.X-20,tl.Y+h*(1-ratio))
                s.HealthText.Text = tostring(math.floor(ratio*100))
                s.HealthText.TextColor3 = Color3.new(1,1,1)
                s.HealthText.Visible = true
            else
                s.HealthBack.Visible = false s.Health.Visible = false s.HealthText.Visible = false
            end

            updateSkeleton(s,char)

            if tracerOn then
                setLine(s.Tracer,tracerOrigin(),Vector2.new(centerX,br.Y),1,color,0)
            else
                s.Tracer.Visible = false
            end
        end
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai","Studio player ESP test mode enabled",4)
end)
