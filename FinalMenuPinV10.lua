-- Final menu pin/order pass. UI-only: does not add weapon or anti-cheat logic.
repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec = objects.VisualsWindow
local CombatRec = objects.CombatWindow
local ZWSP = utf8.char(0x200B)

local function clean(v)
    return tostring(v or ""):gsub(ZWSP, "")
end
local function optionName(key)
    return clean(key):gsub("OptionsButton$", "")
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
local function findOption(parentRec,name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and (not parentRec or under(rec,parentRec)) then
            return key,rec
        end
    end
end
local function setOrder(parentRec,names,start)
    local base=start or 1
    for i,name in ipairs(names) do
        local _,rec=findOption(parentRec,name)
        if rec and rec.Object and rec.Object:IsA("GuiObject") then
            pcall(function()
                rec.Object.Visible=true
                rec.Object.LayoutOrder=base+i-1
            end)
        end
    end
end

local function textOf(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return clean(obj.Text)
    end
    return ""
end
local function directChild(root,obj)
    local cur=obj
    while cur and cur.Parent and cur.Parent~=root do cur=cur.Parent end
    if cur and cur.Parent==root then return cur end
end

local function forceTracerSubOrder()
    local _,rec=findOption(VisualsRec,"Tracers")
    if not rec then return end
    local root=rec.ChildrenObject or rec.Object
    if not root or typeof(root)~="Instance" then return end

    local seen={}
    for _,d in ipairs(root:GetDescendants()) do
        local text=textOf(d):lower()
        local rank=nil
        -- Exact requested order: Origin first, then Color, Thickness, Transparency.
        if text:find("origin",1,true) then rank=1
        elseif text=="color" or text:find("color",1,true) then rank=2
        elseif text:find("thickness",1,true) then rank=3
        elseif text:find("transparency",1,true) then rank=4 end
        if rank then
            local box=directChild(root,d)
            if box and not seen[box] then
                seen[box]=true
                pcall(function() box.LayoutOrder=rank end)
            end
        end
    end
end

local function pinAll()
    -- Combat controls are only made visible/reordered if they already exist.
    -- Nothing is deleted here.
    setOrder(CombatRec,{"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo","AntiAim","KillAura","Reach"},1)

    -- Tracers must sit ABOVE Thermal Corner, with Distance immediately after it.
    setOrder(VisualsRec,{
        "ESP","Chams","Corner Box","HealthBar","Name + Distance","Skeleton",
        "Tracers","Distance","Thermal Corner","Car ESP","Custom Crosshair","FOVChanger",
        "GunChams","SelfChams","Preview","3D Box"
    },1)
    forceTracerSubOrder()
end

-- Re-apply after delayed GUI layout callbacks from older Yokai modules.
pinAll()
task.defer(pinAll)
task.delay(.15,pinAll)
task.delay(.5,pinAll)
task.delay(1.2,pinAll)
task.delay(2.5,pinAll)
task.delay(5,pinAll)

-- If the UI list recalculates later, pin again without creating a permanent frame loop.
for _,rec in ipairs({VisualsRec,CombatRec}) do
    local root=rec and rec.ChildrenObject
    if root and typeof(root)=="Instance" then
        local layout=root:FindFirstChildWhichIsA("UIListLayout")
        if layout then
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                task.defer(pinAll)
            end)
        end
    end
end
