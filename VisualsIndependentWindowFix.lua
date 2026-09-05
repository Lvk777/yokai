-- Final UI-only fix: Visuals behaves independently from the other Yokai windows.
-- Opening Visuals no longer closes Combat/Movement/Render/Utility/World/Friends/Profiles,
-- and opening those windows no longer forces Visuals closed.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local visualsRec = objects["VisualsWindow"]
local Visuals = visualsRec and visualsRec["Api"]
if not Visuals then
    warn("VisualsIndependentWindowFix: Visuals window missing")
    return
end

local main = GuiLibrary["MainGui"]
if not main then return end

-- Remove the old custom Visuals buttons whose click callbacks closed other windows.
for _, name in ipairs({"VisualsV4Button", "VisualsHarmonyButton", "VisualsIndependentButton"}) do
    local old = main:FindFirstChild(name, true)
    if old then pcall(function() old:Destroy() end) end
end

local renderRec = objects["RenderButton"]
local source = renderRec and renderRec["Object"]
if not source or typeof(source) ~= "Instance" then
    warn("VisualsIndependentWindowFix: Render sidebar button missing")
    return
end

local button = source:Clone()
button.Name = "VisualsIndependentButton"
button.LayoutOrder = (source.LayoutOrder or 0) + 1

local function rename(node)
    if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text == "Render" then
        node.Text = "Visuals"
    end
end
rename(button)
for _, d in ipairs(button:GetDescendants()) do rename(d) end
button.Parent = source.Parent

local clickTarget = button:IsA("TextButton") and button or button:FindFirstChildWhichIsA("TextButton", true)
local visualsWanted = false

local function setVisuals(v)
    visualsWanted = v
    pcall(function() Visuals.SetVisible(v) end)
end

if clickTarget then
    clickTarget.MouseButton1Click:Connect(function()
        setVisuals(not visualsWanted)
    end)
end

-- Older harmony code attached callbacks to the native buttons that hide Visuals.
-- Re-apply the user's independent Visuals state after those callbacks run.
for _, name in ipairs({"Combat", "Movement", "Render", "Utility", "World", "Friends", "Profiles"}) do
    local rec = objects[name .. "Button"]
    local obj = rec and rec["Object"]
    if obj and typeof(obj) == "Instance" then
        local target = obj:IsA("TextButton") and obj or obj:FindFirstChildWhichIsA("TextButton", true)
        if target then
            target.MouseButton1Click:Connect(function()
                task.defer(function()
                    if visualsWanted then
                        pcall(function() Visuals.SetVisible(true) end)
                    end
                end)
            end)
        end
    end
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Visuals now opens independently", 3)
end)
