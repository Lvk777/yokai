-- Final persistence guard for the custom Yokai profile.
-- UI/state only: prevents late profile/layout cleanup from deleting the final controls.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local RunService = game:GetService("RunService")
local ZWSP = utf8.char(0x200B)

local function clean(v)
    return tostring(v or ""):gsub(ZWSP, "")
end

local protected = {
    Combat = {
        ["Aimbot"]=true,["SilentAim"]=true,["HitBoxes"]=true,["No Recoil"]=true,
        ["Fast Reload"]=true,["Infinite Ammo"]=true,
    },
    Visuals = {
        ["ESP"]=true,["Chams"]=true,["Corner Box"]=true,["HealthBar"]=true,
        ["Name + Distance"]=true,["Skeleton"]=true,["Tracers"]=true,["Distance"]=true,
        ["Thermal Corner"]=true,["Car ESP"]=true,["Custom Crosshair"]=true,
        ["FOVChanger"]=true,["GunChams"]=true,["SelfChams"]=true,["Preview"]=true,
        ["3D Box"]=true,
    },
    World = {
        ["BulletTracer"]=true,["HitSound"]=true,["HitMarker"]=true,["FullBrightness"]=true,
    },
    Utility = {
        ["FPS Boost"]=true,["Menu Optimizer"]=true,["Inventory Viewer"]=true,
    },
}

local function objects()
    return GuiLibrary.ObjectsThatCanBeSaved or {}
end

local function optionName(key,rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$", "")
end

local function windowRec(name)
    return objects()[name.."Window"]
end

local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function()
                return rec.Object==root or rec.Object:IsDescendantOf(root)
            end)
            if ok and res then return true end
        end
    end
    return false
end

local function protectedRecord(key,rec)
    if not rec or rec.Type~="OptionsButton" then return false end
    local name=optionName(key,rec)
    for win,names in pairs(protected) do
        if names[name] then
            local w=windowRec(win)
            if w and under(rec,w) then return true end
        end
    end
    return false
end

-- Install once, after every intentional replacement has already happened.
if not shared.YokaiPersistentRemoveGuardInstalled then
    shared.YokaiPersistentRemoveGuardInstalled=true
    local originalRemove=GuiLibrary.RemoveObject
    shared.YokaiOriginalRemoveObject=shared.YokaiOriginalRemoveObject or originalRemove

    if type(originalRemove)=="function" then
        GuiLibrary.RemoveObject=function(key,...)
            local rec=objects()[key]
            if not shared.YokaiAllowProtectedRemoval and protectedRecord(key,rec) then
                return rec
            end
            return originalRemove(key,...)
        end
    end
end

local combatOrder={"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo","AntiAim","KillAura","Reach"}
local visualsOrder={
    "ESP","Chams","Corner Box","HealthBar","Name + Distance","Skeleton",
    "Tracers","Distance","Thermal Corner","Car ESP","Custom Crosshair","FOVChanger",
    "GunChams","SelfChams","Preview","3D Box"
}
local worldOrder={"BulletTracer","HitSound","HitMarker","FullBrightness"}
local utilityOrder={"AntiAFK","AntiFling","NoMenuFog","Rejoin","ServerHop","Inventory Viewer","FPS Boost","Menu Optimizer"}

local function findOption(parentRec,name)
    for key,rec in pairs(objects()) do
        if rec and rec.Type=="OptionsButton" and optionName(key,rec)==name and (not parentRec or under(rec,parentRec)) then
            return key,rec
        end
    end
end

local function applyOrder(parentRec,list)
    if not parentRec then return end
    for i,name in ipairs(list) do
        local _,rec=findOption(parentRec,name)
        if rec and rec.Object and typeof(rec.Object)=="Instance" then
            pcall(function()
                -- Some late profile loads only hide the object instead of deleting it.
                rec.Object.Visible=true
                rec.Object.LayoutOrder=i
                if not rec.Object.Parent and parentRec.ChildrenObject then
                    rec.Object.Parent=parentRec.ChildrenObject
                end
            end)
        end
    end
end

local function textOf(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return clean(obj.Text):lower()
    end
    return ""
end

local function directChild(root,obj)
    local cur=obj
    while cur and cur.Parent and cur.Parent~=root do cur=cur.Parent end
    if cur and cur.Parent==root then return cur end
end

local function fixTracerOrder()
    local _,rec=findOption(windowRec("Visuals"),"Tracers")
    if not rec then return end
    local root=rec.ChildrenObject or rec.Object
    if not root or typeof(root)~="Instance" then return end
    local seen={}
    for _,d in ipairs(root:GetDescendants()) do
        local t=textOf(d)
        local rank
        if t:find("origin",1,true) then rank=1
        elseif t=="color" or t:find("color",1,true) then rank=2
        elseif t:find("thickness",1,true) then rank=3
        elseif t:find("transparency",1,true) then rank=4 end
        if rank then
            local box=directChild(root,d)
            if box and not seen[box] then
                seen[box]=true
                pcall(function() box.LayoutOrder=rank end)
            end
        end
    end
end

local function repair()
    applyOrder(windowRec("Combat"),combatOrder)
    applyOrder(windowRec("Visuals"),visualsOrder)
    applyOrder(windowRec("World"),worldOrder)
    applyOrder(windowRec("Utility"),utilityOrder)
    fixTracerOrder()
end

repair()
for _,delayTime in ipairs({.1,.35,.75,1.5,3,6,10}) do
    task.delay(delayTime,repair)
end

-- Re-assert only after settings/profile refreshes or structural UI changes; no per-frame loop.
pcall(function()
    if GuiLibrary.LoadSettingsEvent and GuiLibrary.LoadSettingsEvent.Event then
        GuiLibrary.LoadSettingsEvent.Event:Connect(function()
            task.defer(repair)
            task.delay(.15,repair)
            task.delay(.8,repair)
        end)
    end
end)

for _,win in ipairs({"Combat","Visuals","World","Utility"}) do
    local rec=windowRec(win)
    local root=rec and rec.ChildrenObject
    if root and typeof(root)=="Instance" then
        root.ChildRemoved:Connect(function()
            task.defer(repair)
        end)
        local layout=root:FindFirstChildWhichIsA("UIListLayout")
        if layout then
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                task.defer(repair)
            end)
        end
    end
end

-- Very low-cost sanity check: catches delayed profile cleanup without touching rendering.
task.spawn(function()
    while shared.YokaiExecuted~=false do
        task.wait(2)
        repair()
    end
end)
