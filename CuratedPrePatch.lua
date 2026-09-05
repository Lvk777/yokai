-- Compatibility shim for CuratedModules.lua
-- Preserve Yokai's original ESP (including the original 2D / 3D / Skeleton modes)
-- and prevent the replacement ESP/3D box option from being exposed.

repeat task.wait() until shared.GuiLibrary and shared.YokaiFullyLoaded

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary["ObjectsThatCanBeSaved"]
local renderWindow = objects["RenderWindow"] and objects["RenderWindow"]["Api"]

if not renderWindow then
    warn("CuratedPrePatch: RenderWindow not found")
    return
end

local oldRemoveObject = GuiLibrary["RemoveObject"]
local oldCreateOptionsButton = renderWindow["CreateOptionsButton"]

-- CuratedModules removes every OptionsButton that is not in its keep table.
-- Do not allow it to remove the original ESP module.
GuiLibrary["RemoveObject"] = function(objname)
    if objname == "ESPOptionsButton" then
        return
    end
    return oldRemoveObject(objname)
end

local function makeDummyOptionsApi(name)
    local dummy = {
        Name = name,
        Enabled = false,
        Object = nil,
    }
    dummy.ToggleButton = function() end
    dummy.SetKeybind = function() end
    dummy.ExpandToggle = function() end
    dummy.CreateColorSlider = function()
        return {Hue = 0, Sat = 0, Value = 1, Object = nil}
    end
    dummy.CreateSlider = function(args)
        return {Value = (args and args.Default) or 0, Object = nil}
    end
    dummy.CreateToggle = function(args)
        return {Enabled = (args and args.Default) or false, Object = nil}
    end
    dummy.CreateDropdown = function(args)
        local list = (args and args.List) or {}
        return {Value = list[1], Object = nil}
    end
    dummy.CreateTextBox = function()
        return {Value = "", Object = nil}
    end
    dummy.CreateTargetWindow = function()
        return {Players = {Enabled = true}}
    end
    return dummy
end

renderWindow["CreateOptionsButton"] = function(args)
    -- CuratedModules used to replace the original ESP with a custom Skeleton ESP.
    -- Swallow that creation so the real original ESP remains untouched.
    if args and args["Name"] == "ESP" and objects["ESPOptionsButton"] then
        return makeDummyOptionsApi("ESP")
    end

    local api = oldCreateOptionsButton(args)

    -- Keep the new Box replacement limited to the supplied Corner/Thermal styles.
    -- The original Yokai ESP remains responsible for 3D ESP.
    if args and args["Name"] == "Box" and api and api.CreateDropdown then
        local oldCreateDropdown = api.CreateDropdown
        api.CreateDropdown = function(dropArgs)
            if dropArgs and dropArgs["Name"] == "Mode" and type(dropArgs["List"]) == "table" then
                local filtered = {}
                for _, value in ipairs(dropArgs["List"]) do
                    if value ~= "3D" then
                        table.insert(filtered, value)
                    end
                end
                dropArgs["List"] = filtered
            end
            return oldCreateDropdown(dropArgs)
        end
    end

    return api
end

shared.YokaiCuratedRestoreGuiHooks = function()
    GuiLibrary["RemoveObject"] = oldRemoveObject
    renderWindow["CreateOptionsButton"] = oldCreateOptionsButton
    shared.YokaiCuratedRestoreGuiHooks = nil
end
