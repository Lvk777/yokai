-- Stable snapshot of the FINAL custom controls.
-- Unlike the old guard, this keeps references to the actual records/instances that
-- were created by the final bot profile. If an old profile refresh overwrites an
-- ObjectsThatCanBeSaved key, the final record is put back instead of rediscovering
-- whichever legacy row currently owns that name.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local ZWSP=utf8.char(0x200B)

local function clean(v) return tostring(v or ""):gsub(ZWSP,"") end
local function optionName(key,rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$","")
end
local function windowRec(name) return objects[name.."Window"] end
local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end

local wanted={
    Combat={"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo","AntiAim","KillAura","Reach"},
    Visuals={"ESP","Chams","Corner Box","HealthBar","Name + Distance","Skeleton","Tracers","Distance","Thermal Corner","Car ESP","Custom Crosshair","FOVChanger","GunChams","SelfChams","Preview","3D Box"},
    World={"BulletTracer","HitSound","HitMarker","FullBrightness","ChangeSkydome","Night","NoFog","NoLeaves"},
    Utility={"AntiAFK","AntiFling","NoMenuFog","Rejoin","ServerHop","Inventory Viewer","FPS Boost","Menu Optimizer"},
}

local function findOption(win,name)
    local w=windowRec(win)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key,rec)==name and under(rec,w) then
            return key,rec
        end
    end
end

local snapshot={}
local tops={}
local protectedKeys={}

local function belongsToTop(rec,top)
    if not rec or not rec.Object or not top then return false end
    for _,root in ipairs({top.Object,top.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end

local function captureTop(win,name,order)
    local key,top=findOption(win,name)
    if not key or not top then return end
    local pack={win=win,name=name,order=order,key=key,top=top,records={}}
    tops[win]=tops[win] or {}
    tops[win][name]=pack

    for childKey,rec in pairs(objects) do
        if rec and rec.Object and (childKey==key or belongsToTop(rec,top)) then
            pack.records[childKey]={
                rec=rec,
                object=rec.Object,
                parent=rec.Object.Parent,
            }
            protectedKeys[childKey]=true
        end
    end
    snapshot[key]=pack
end

for win,list in pairs(wanted) do
    for i,name in ipairs(list) do captureTop(win,name,i) end
end

-- Block normal RemoveObject calls for exactly the records captured above. This is
-- intentionally installed only after all intentional replacements are complete.
if not shared.YokaiStableSnapshotRemoveGuard then
    shared.YokaiStableSnapshotRemoveGuard=true
    local previous=GuiLibrary.RemoveObject
    shared.YokaiStableSnapshotPreviousRemove=previous
    GuiLibrary.RemoveObject=function(key,...)
        if protectedKeys[key] and not shared.YokaiAllowFinalControlRemoval then
            local item
            for _,pack in pairs(snapshot) do
                if pack.records[key] then item=pack.records[key].rec break end
            end
            return item
        end
        return previous(key,...)
    end
end

local function rowText(row)
    if not row or typeof(row)~="Instance" then return "" end
    local best=""
    local function read(node)
        if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text and #node.Text>0 then
            local t=clean(node.Text):gsub("^%s+",""):gsub("%s+$","")
            if #t>#best then best=t end
        end
    end
    read(row)
    for _,d in ipairs(row:GetDescendants()) do read(d) end
    return best
end

local function fixTracerChildren(pack)
    if not pack or not pack.top then return end
    local root=pack.top.ChildrenObject or pack.top.Object
    if not root or typeof(root)~="Instance" then return end
    local ranks={origin=1,color=2,thickness=3,transparency=4}
    local seen={}
    local function direct(obj)
        local cur=obj
        while cur and cur.Parent and cur.Parent~=root do cur=cur.Parent end
        return cur and cur.Parent==root and cur or nil
    end
    for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local t=clean(d.Text):lower()
            local rank=t:find("origin",1,true) and ranks.origin
                or (t=="color" or t:find("color",1,true)) and ranks.color
                or t:find("thickness",1,true) and ranks.thickness
                or t:find("transparency",1,true) and ranks.transparency
                or nil
            if rank then
                local row=direct(d)
                if row and not seen[row] then
                    seen[row]=true
                    pcall(function() row.LayoutOrder=rank end)
                end
            end
        end
    end
end

local repairing=false
local function repairPack(pack)
    if not pack or not pack.top then return end
    local w=windowRec(pack.win)
    if not w or not w.ChildrenObject then return end

    -- Restore every captured registry record if a late callback overwrote it.
    for key,item in pairs(pack.records) do
        if objects[key]~=item.rec then
            local stale=objects[key]
            if stale and stale.Object and stale.Object~=item.object then
                pcall(function() stale.Object.Visible=false end)
            end
            objects[key]=item.rec
        end
        if item.object and typeof(item.object)=="Instance" and not item.object.Parent and item.parent then
            pcall(function() item.object.Parent=item.parent end)
        end
    end

    local obj=pack.top.Object
    if obj and typeof(obj)=="Instance" then
        pcall(function()
            if not obj.Parent then obj.Parent=w.ChildrenObject end
            obj.Visible=true
            obj.LayoutOrder=pack.order
        end)
    end
end

local function hideLegacyDuplicates(win)
    local w=windowRec(win)
    local byName=tops[win]
    if not w or not w.ChildrenObject or not byName then return end
    for _,row in ipairs(w.ChildrenObject:GetChildren()) do
        if row:IsA("GuiObject") then
            local text=rowText(row)
            local pack=byName[text]
            if pack and pack.top and pack.top.Object~=row then
                pcall(function() row.Visible=false end)
            end
        end
    end
end

local function repair()
    if repairing then return end
    repairing=true
    for _,byName in pairs(tops) do
        for _,pack in pairs(byName) do repairPack(pack) end
    end
    -- Requested top-level ordering: Tracers before Thermal Corner; Distance directly after.
    local visualTops=tops.Visuals
    if visualTops then
        if visualTops.Tracers and visualTops.Tracers.top.Object then pcall(function() visualTops.Tracers.top.Object.LayoutOrder=7 end) end
        if visualTops.Distance and visualTops.Distance.top.Object then pcall(function() visualTops.Distance.top.Object.LayoutOrder=8 end) end
        if visualTops["Thermal Corner"] and visualTops["Thermal Corner"].top.Object then pcall(function() visualTops["Thermal Corner"].top.Object.LayoutOrder=9 end) end
        fixTracerChildren(visualTops.Tracers)
    end
    for win in pairs(tops) do hideLegacyDuplicates(win) end
    repairing=false
end

-- Settings loading can overwrite registry entries with same-named legacy records.
-- Run repair immediately after the library finishes applying a profile.
if type(GuiLibrary.LoadSettings)=="function" and not shared.YokaiStableLoadSettingsWrapped then
    shared.YokaiStableLoadSettingsWrapped=true
    local originalLoad=GuiLibrary.LoadSettings
    GuiLibrary.LoadSettings=function(...)
        local out=table.pack(originalLoad(...))
        task.defer(repair)
        task.delay(.1,repair)
        return table.unpack(out,1,out.n)
    end
end

pcall(function()
    if GuiLibrary.LoadSettingsEvent and GuiLibrary.LoadSettingsEvent.Event then
        GuiLibrary.LoadSettingsEvent.Event:Connect(function()
            task.defer(repair)
            task.delay(.12,repair)
        end)
    end
end)

for win in pairs(tops) do
    local w=windowRec(win)
    local root=w and w.ChildrenObject
    if root and typeof(root)=="Instance" then
        root.ChildAdded:Connect(function() task.defer(repair) end)
        root.ChildRemoved:Connect(function() task.defer(repair) end)
    end
end

repair()
for _,t in ipairs({.1,.35,.8,1.5,3,6,10,15}) do task.delay(t,repair) end

-- Cheap structural watchdog only; it does not touch rendering or scan Workspace.
task.spawn(function()
    while shared.YokaiExecuted~=false do
        task.wait(2)
        repair()
    end
end)

shared.YokaiFinalMenuSnapshot=snapshot
