-- Configurable Arrow style patch.
-- Keeps Yokai's original off-screen targeting/position/rotation logic intact.
-- Replaces only the visual asset with a thin chevron and adds Size/Thickness
-- controls directly to the existing Render > Arrows module.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local RunService = game:GetService("RunService")

local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local arrowRecord = objects["ArrowsOptionsButton"]
local arrowApi = arrowRecord and arrowRecord["Api"]

local arrowSize = 42
local arrowThickness = 2
local folderConnection
local colorConnections = setmetatable({}, {__mode = "k"})
local lastScan = 0

local function getFolder()
    local main = GuiLibrary["MainGui"]
    if not main then return nil end
    return main:FindFirstChild("ArrowsFolder", true)
end

local function setLine(line, ax, ay, bx, by, thickness, color)
    local a = Vector2.new(ax, ay)
    local b = Vector2.new(bx, by)
    local d = b - a
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Size = UDim2.fromOffset(d.Magnitude, thickness)
    line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    line.Rotation = math.deg(math.atan2(d.Y, d.X))
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.Visible = true
end

local function ensureChevron(obj)
    if not obj or not obj:IsA("ImageLabel") then return end

    -- Hide the original thick bitmap but retain the parent object because the
    -- original Yokai RenderStep continues to control its position/rotation/color.
    obj.ImageTransparency = 1
    obj.Size = UDim2.fromOffset(arrowSize, arrowSize)

    local holder = obj:FindFirstChild("YokaiThinArrow")
    if not holder then
        holder = Instance.new("Frame")
        holder.Name = "YokaiThinArrow"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Size = UDim2.fromScale(1, 1)
        holder.Position = UDim2.fromScale(0, 0)
        holder.Parent = obj

        local upper = Instance.new("Frame")
        upper.Name = "Upper"
        upper.BorderSizePixel = 0
        upper.Parent = holder

        local lower = Instance.new("Frame")
        lower.Name = "Lower"
        lower.BorderSizePixel = 0
        lower.Parent = holder
    end

    local upper = holder:FindFirstChild("Upper")
    local lower = holder:FindFirstChild("Lower")
    if not upper or not lower then return end

    -- Asset orientation matches the original ArrowIndicator rotation: chevron
    -- points to the right at Rotation=0 and the parent is rotated by Yokai.
    local s = arrowSize
    local tailX = s * 0.30
    local tipX = s * 0.70
    local midY = s * 0.50
    local spread = s * 0.22
    local color = obj.ImageColor3

    setLine(upper, tailX, midY - spread, tipX, midY, arrowThickness, color)
    setLine(lower, tailX, midY + spread, tipX, midY, arrowThickness, color)

    if not colorConnections[obj] then
        colorConnections[obj] = obj:GetPropertyChangedSignal("ImageColor3"):Connect(function()
            if obj.Parent then
                local h = obj:FindFirstChild("YokaiThinArrow")
                if h then
                    local u = h:FindFirstChild("Upper")
                    local l = h:FindFirstChild("Lower")
                    if u then u.BackgroundColor3 = obj.ImageColor3 end
                    if l then l.BackgroundColor3 = obj.ImageColor3 end
                end
            end
        end)
    end
end

local function refreshAll()
    local folder = getFolder()
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        ensureChevron(obj)
    end
end

local function bindFolder()
    if folderConnection then
        folderConnection:Disconnect()
        folderConnection = nil
    end
    local folder = getFolder()
    if not folder then return end
    folderConnection = folder.ChildAdded:Connect(function(obj)
        task.defer(function()
            ensureChevron(obj)
        end)
    end)
    refreshAll()
end

-- Add the requested settings directly under Render > Arrows.
if arrowApi and not shared.YokaiArrowStyleControlsAdded then
    shared.YokaiArrowStyleControlsAdded = true

    arrowApi.CreateSlider({
        ["Name"] = "Size",
        ["Min"] = 20,
        ["Max"] = 120,
        ["Default"] = 42,
        ["Function"] = function(v)
            arrowSize = v
            refreshAll()
        end,
    })

    arrowApi.CreateSlider({
        ["Name"] = "Thickness",
        ["Min"] = 1,
        ["Max"] = 8,
        ["Default"] = 2,
        ["Function"] = function(v)
            arrowThickness = v
            refreshAll()
        end,
    })
end

bindFolder()

-- New arrow objects are recreated whenever Arrows toggles, so keep a lightweight
-- scan to style newly-created indicators without changing the original logic.
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastScan < 0.2 then return end
    lastScan = now
    if not getFolder() then
        bindFolder()
    else
        refreshAll()
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Arrows: Size + Thickness enabled", 3)
end)
