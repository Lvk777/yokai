-- Quiet startup notification filter.
-- Loaded immediately after main.lua. It suppresses bootstrap/patch spam while
-- preserving useful gameplay feedback such as damage, hitmarker and inventory.

repeat task.wait() until shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
if shared.YokaiNotificationHygieneInstalled then return end
shared.YokaiNotificationHygieneInstalled=true

local original=GuiLibrary.CreateNotification
if type(original)~="function" then return end
shared.YokaiOriginalCreateNotification=shared.YokaiOriginalCreateNotification or original

local installedAt=os.clock()
local lastShown={}
local function lower(v) return string.lower(tostring(v or "")) end

local function useful(title,text)
    local s=lower(title).." "..lower(text)
    return s:find("damage",1,true)
        or s:find("headshot",1,true)
        or s:find("head ",1,true)
        or s:find("torso",1,true)
        or s:find("arm",1,true)
        or s:find("leg",1,true)
        or s:find("hitmarker",1,true)
        or s:find("inventory",1,true)
        or s:find("error",1,true)
        or s:find("warning",1,true)
        or s:find("rejoin",1,true)
        or s:find("serverhop",1,true)
end

local function startupSpam(title,text)
    local t=lower(title)
    local x=lower(text)
    local s=t.." "..x

    -- During bootstrap, generic Yokai status toasts are noise. Keep only the
    -- explicitly useful categories above.
    if os.clock()-installedAt<12 and t=="yokai" and not useful(title,text) then return true end

    -- Also suppress known patch/status wording if it occurs later.
    local patterns={
        " loaded","loaded ","fix loaded","runtime fixes","module set loaded",
        "finished loading","press rightshift","gun testing v","integration v",
        "polish loaded","bootstrap","menu v","visuals v","local world fixes",
        "material fix","layout fixes","cosmetic runtime","viewmodel fixes"
    }
    for _,p in ipairs(patterns) do if s:find(p,1,true) then return true end end
    return false
end

GuiLibrary.CreateNotification=function(title,text,duration,...)
    if startupSpam(title,text) then return nil end

    local key=lower(title).."\0"..lower(text)
    local now=os.clock()
    -- Deduplicate accidental repeated status messages, but never throttle gameplay
    -- damage/hit/inventory feedback requested by the user.
    if not useful(title,text) then
        local last=lastShown[key]
        if last and now-last<1.5 then return nil end
        lastShown[key]=now
    end

    return original(title,text,duration,...)
end
