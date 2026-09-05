-- Restore Yokai's original ArrowIndicator visual and logic.
-- Only scales the original bitmap down so it stays the same arrow, just smaller
-- and proportionally thinner. No replacement chevron, no extra arrow logic.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local RunService = game:GetService("RunService")

local TARGET_SIZE = 150
local folderConnection
local lastScan = 0

local function getFolder()
    local main = GuiLibrary["MainGui"]
    if not main then return nil end
    return main:FindFirstChild("ArrowsFolder", true)
end

local function restoreOriginal(obj)
    if not obj or not obj:IsA("ImageLabel") then return end
    local custom = obj:FindFirstChild("YokaiThinArrow")
    if custom then custom:Destroy() end
    obj.ImageTransparency = 0
    obj.Size = UDim2.fromOffset(TARGET_SIZE, TARGET_SIZE)
end

local function scan()
    local folder = getFolder()
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        restoreOriginal(obj)
    end
end

local function bindFolder()
    if folderConnection then folderConnection:Disconnect() folderConnection=nil end
    local folder = getFolder()
    if not folder then return end
    folderConnection = folder.ChildAdded:Connect(function(obj)
        task.defer(restoreOriginal, obj)
    end)
    scan()
end

bindFolder()
RunService.Heartbeat:Connect(function()
    if os.clock()-lastScan < .25 then return end
    lastScan=os.clock()
    if not getFolder() then bindFolder() else scan() end
end)
