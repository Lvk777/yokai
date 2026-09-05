-- Final UI-only fix: Visuals behaves independently from the other Yokai windows.
-- Opening Visuals does not close any native window, and its sidebar highlight now
-- follows the actual open/closed state instead of staying permanently selected.

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
local hovering = false

local function accentColor()
    local rec = objects["Gui ColorSliderColor"]
    local api = rec and rec["Api"]
    if api and api["Hue"] ~= nil then
        return Color3.fromHSV(api["Hue"], api["Sat"] or 1, api["Value"] or 1)
    end
    return Color3.fromRGB(45, 132, 235)
end

local function styleButton(selected)
    local accent = accentColor()
    local textOff = hovering and Color3.fromRGB(207,207,207) or Color3.fromRGB(162,162,162)
    local imageOff = hovering and Color3.fromRGB(207,207,207) or Color3.fromRGB(162,162,162)

    pcall(function()
        if button:IsA("GuiObject") then
            button.BackgroundColor3 = selected and Color3.fromRGB(31,30,31) or (hovering and Color3.fromRGB(31,30,31) or Color3.fromRGB(26,25,26))
        end
    end)

    local function paint(node)
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            if node.Text == "Visuals" then
                node.TextColor3 = selected and accent or textOff
            end
        elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
            local n = node.Name:lower()
            if n:find("icon",1,true) or n:find("image",1,true) then
                node.ImageColor3 = selected and accent or imageOff
            end
        end
    end
    paint(button)
    for _, d in ipairs(button:GetDescendants()) do paint(d) end
end

local function setVisuals(v)
    visualsWanted = v
    pcall(function() Visuals.SetVisible(v) end)
    styleButton(v)
end

-- Force a neutral initial state even if Render happened to be highlighted at clone time.
styleButton(false)

if clickTarget then
    clickTarget.MouseButton1Click:Connect(function()
        setVisuals(not visualsWanted)
    end)
    clickTarget.MouseEnter:Connect(function()
        hovering = true
        styleButton(visualsWanted)
    end)
    clickTarget.MouseLeave:Connect(function()
        hovering = false
        styleButton(visualsWanted)
    end)
end

-- Keep the accent synced if the user changes Yokai's GUI color while Visuals is open.
local guiColor = objects["Gui ColorSliderColor"]
local guiColorApi = guiColor and guiColor["Api"]
if guiColorApi and guiColorApi["Object"] and typeof(guiColorApi["Object"]) == "Instance" then
    pcall(function()
        guiColorApi["Object"].Changed:Connect(function() styleButton(visualsWanted) end)
    end)
end

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai", "Visuals independent state synced", 3)
end)
