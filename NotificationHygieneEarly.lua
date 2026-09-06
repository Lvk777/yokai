-- Notification hygiene loaded immediately after main.lua.
-- Keeps action/error/damage notifications, suppresses repetitive startup patch spam.

repeat task.wait() until shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
if shared.YokaiNotificationHygieneInstalled then return end
shared.YokaiNotificationHygieneInstalled = true

local original = GuiLibrary.CreateNotification
if type(original) ~= "function" then return end
shared.YokaiOriginalCreateNotification = shared.YokaiOriginalCreateNotification or original

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function isStartupSpam(title,text)
    local t = lower(title)
    local x = lower(text)
    local combined = t .. " " .. x

    -- Repetitive patch/bootstrap notices only. User-triggered status messages,
    -- warnings/errors, damage, rejoin and feature feedback are left untouched.
    if combined:find(" loaded",1,true) or combined:find("loaded ",1,true) then return true end
    if combined:find("fix loaded",1,true) then return true end
    if combined:find("runtime fixes",1,true) then return true end
    if combined:find("module set loaded",1,true) then return true end
    if combined:find("menu v",1,true) and combined:find("loaded",1,true) then return true end
    if combined:find("integration v",1,true) and combined:find("loaded",1,true) then return true end
    if combined:find("finished loading",1,true) then return true end
    if combined:find("press rightshift",1,true) then return true end
    return false
end

GuiLibrary.CreateNotification = function(title,text,duration,...)
    local t = lower(title)

    -- V5's old generic Hit popup is replaced by the richer Damage popup from V7.
    if t == "hit" then return nil end
    if isStartupSpam(title,text) then return nil end

    return original(title,text,duration,...)
end
