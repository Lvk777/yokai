-- Final UI visibility/order pass for the bot-practice profile.
-- No weapon/anti-cheat logic here; this only fixes Yokai menu layout/access.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec = objects.CombatWindow
local VisualsRec = objects.VisualsWindow
local WorldRec = objects.WorldWindow
local UtilityRec = objects.UtilityWindow
local MovementRec = objects.MovementWindow
local RenderRec = objects.RenderWindow

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
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end
local function optionRecord(parentRec,name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and (not parentRec or under(rec,parentRec)) then
            return key,rec
        end
    end
end
local function setTopOrder(parentRec,names)
    for i,name in ipairs(names) do
        local _,rec=optionRecord(parentRec,name)
        if rec and rec.Object then
            pcall(function()
                rec.Object.Visible=true
                rec.Object.LayoutOrder=i
            end)
        end
    end
end

-- Keep the important bot-practice controls grouped and visible.
task.defer(function()
    setTopOrder(CombatRec,{"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo"})
    setTopOrder(VisualsRec,{"ESP","Chams","Corner Box","Thermal Corner","HealthBar","Name + Distance","Skeleton","Tracers","Distance","Car ESP","Custom Crosshair","FOVChanger"})
    setTopOrder(WorldRec,{"BulletTracer","HitSound","HitMarker","FullBrightness"})
end)

-- Reorder controls INSIDE Tracers. Yokai's dropdown can otherwise be pushed below
-- sliders even when it was created first. Desired order:
-- Origin -> Color -> Thickness -> Transparency.
local function textOf(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return clean(obj.Text)
    end
    return ""
end
local function directContainer(root,obj)
    local cur=obj
    while cur and cur.Parent and cur.Parent~=root do cur=cur.Parent end
    if cur and cur.Parent==root then return cur end
    return nil
end
local function reorderTracerChildren()
    local _,rec=optionRecord(VisualsRec,"Tracers")
    if not rec then return end
    local roots={rec.ChildrenObject,rec.Object}
    local wanted={origin=1,color=2,thickness=3,transparency=4}
    for _,root in ipairs(roots) do
        if root and typeof(root)=="Instance" then
            local seen={}
            for _,d in ipairs(root:GetDescendants()) do
                local txt=textOf(d):lower()
                local rank=nil
                if txt:find("origin",1,true) then rank=wanted.origin
                elseif txt=="color" or txt:find("color",1,true) then rank=wanted.color
                elseif txt:find("thickness",1,true) then rank=wanted.thickness
                elseif txt:find("transparency",1,true) then rank=wanted.transparency end
                if rank then
                    local box=directContainer(root,d)
                    if box and not seen[box] then
                        seen[box]=true
                        pcall(function() box.LayoutOrder=rank end)
                    end
                end
            end
        end
    end
end

task.defer(reorderTracerChildren)
task.delay(.5,reorderTracerChildren)
task.delay(1.5,reorderTracerChildren)

-- Reliable wheel access for tall Yokai windows. If a window expands past the
-- viewport, hover it and use the wheel; the whole window is translated vertically.
local windows={CombatRec,MovementRec,RenderRec,UtilityRec,VisualsRec,WorldRec}
local function overWindow(gui,mouse)
    if not gui or not gui.Parent or not gui.Visible then return false end
    local p,s=gui.AbsolutePosition,gui.AbsoluteSize
    return mouse.X>=p.X-8 and mouse.X<=p.X+s.X+8 and mouse.Y>=math.max(0,p.Y-20) and mouse.Y<=math.min((Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y or 9999),p.Y+s.Y+20)
end
local function moveWindow(gui,z)
    local cam=Workspace.CurrentCamera
    if not cam or not gui then return end
    local vh=cam.ViewportSize.Y
    local h=gui.AbsoluteSize.Y
    if h<=vh-12 then return end
    local current=gui.AbsolutePosition.Y
    local desired=math.clamp(current + z*60, vh-h-8, 8)
    local delta=desired-current
    local p=gui.Position
    gui.Position=UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+delta)
end
UserInputService.InputChanged:Connect(function(input,gp)
    if gp or input.UserInputType~=Enum.UserInputType.MouseWheel then return end
    local mouse=UserInputService:GetMouseLocation()
    for _,rec in ipairs(windows) do
        local gui=rec and rec.Object
        if overWindow(gui,mouse) then
            moveWindow(gui,input.Position.Z)
            return
        end
    end
end)

pcall(function()
    GuiLibrary.CreateNotification("Yokai","Bot menu V6 loaded",3)
end)
