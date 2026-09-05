-- Compatibility shim for CuratedModules.lua
-- Preserve Yokai's original Render window exactly as loaded by AnyGame.lua.
-- CuratedModules is still allowed to change Combat/Movement/Utility/World,
-- but it must not delete or replace original Render modules.

repeat task.wait() until shared.GuiLibrary and shared.YokaiFullyLoaded

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary["ObjectsThatCanBeSaved"]
local renderRecord = objects["RenderWindow"]
local renderWindow = renderRecord and renderRecord["Api"]

if not renderWindow then
    warn("CuratedPrePatch: RenderWindow not found")
    return
end

local oldRemoveObject = GuiLibrary["RemoveObject"]
local oldCreateOptionsButton = renderWindow["CreateOptionsButton"]

local function belongsToOriginalRender(objname)
    local rec = objects[objname]
    local obj = rec and rec["Object"]
    if not obj or typeof(obj) ~= "Instance" then return false end

    local roots = {
        renderRecord and renderRecord["Object"],
        renderRecord and renderRecord["ChildrenObject"],
    }

    for _, root in ipairs(roots) do
        if root and typeof(root) == "Instance" then
            if obj == root or obj:IsDescendantOf(root) then
                return true
            end
        end
    end
    return false
end

-- CuratedModules removes every OptionsButton that is not in its keep table.
-- Block deletion of anything that already belongs to the original Render window.
GuiLibrary["RemoveObject"] = function(objname)
    if belongsToOriginalRender(objname) then
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
    dummy.CreateTwoSlider = function(args)
        return {Value = (args and args.Default) or 0, Value2 = (args and args.Default2) or 0, Object = nil}
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
    dummy.CreateTextList = function()
        return {ObjectList = {}, Object = nil}
    end
    dummy.CreateTargetWindow = function()
        return {Players = {Enabled = true}}
    end
    return dummy
end

-- CuratedModules previously recreated these visual modules in Render.
-- Swallow those replacement creations so the original Render implementation
-- remains untouched. Visuals V3 creates its own uniquely-named modules later.
local curatedRenderReplacements = {
    ESP = true,
    Chams = true,
    Health = true,
    Name = true,
    Distance = true,
    Box = true,
    Tracers = true,
    GunChams = true,
}

renderWindow["CreateOptionsButton"] = function(args)
    if args and curatedRenderReplacements[args["Name"]] then
        return makeDummyOptionsApi(args["Name"])
    end
    return oldCreateOptionsButton(args)
end

shared.YokaiCuratedRestoreGuiHooks = function()
    GuiLibrary["RemoveObject"] = oldRemoveObject
    renderWindow["CreateOptionsButton"] = oldCreateOptionsButton
    shared.YokaiCuratedRestoreGuiHooks = nil
end
