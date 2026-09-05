-- Cosmetic-only Arrow sizing patch.
-- Keeps Yokai's original Arrows behavior, image, rotation and colors intact.
-- Only reduces the indicator canvas so the arrow appears smaller/thinner.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local RunService = game:GetService("RunService")

local TARGET_SIZE = 170
local lastScan = 0
local connection

local function getFolder()
    local main = GuiLibrary["MainGui"]
    if not main then return nil end
    return main:FindFirstChild("ArrowsFolder", true)
end

local function applyTo(obj)
    if obj and obj:IsA("ImageLabel") then
        obj.Size = UDim2.fromOffset(TARGET_SIZE, TARGET_SIZE)
    end
end

local function scan()
    local folder = getFolder()
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        applyTo(obj)
    end
end

local function bindFolder()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    local folder = getFolder()
    if not folder then return end
    connection = folder.ChildAdded:Connect(function(obj)
        task.defer(applyTo, obj)
    end)
    scan()
end

bindFolder()

RunService.Heartbeat:Connect(function()
    if os.clock() - lastScan < 0.35 then return end
    lastScan = os.clock()
    if not getFolder() then
        bindFolder()
    else
        scan()
    end
end)
