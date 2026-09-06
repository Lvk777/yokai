-- Gun Testing safe UX polish: bot-only arrows color + bot inventory viewer.
-- Passive/local presentation only. Does not alter firing, recoil, reload, ammo, remotes,
-- anti-cheat state, or Player characters.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec = objects["UtilityWindow"]
local RenderRec = objects["RenderWindow"]
local Utility = UtilityRec and UtilityRec.Api

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then
            return true
        end
    end
    return false
end
local function findOption(parentRec,name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then
            return rec
        end
    end
end
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end
local function guiRoots()
    local roots={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(roots,gethui()) end end)
    return roots
end
local function destroyGuiNamed(name)
    for _,root in ipairs(guiRoots()) do
        if root then
            local old=root:FindFirstChild(name,true)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end

-- ============================================================================
-- Bot discovery. Never treat a Player character (or wrapper around one) as a bot.
-- ============================================================================
local function playerOwned(model)
    if not model then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then
            return true
        end
    end
    return false
end
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) or model.Name=="YokaiSafeVisualTestTarget" then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=rootOf(model)
    return hum~=nil and root~=nil and hum.Health>0
end
local function botName(model)
    local hum=model and model:FindFirstChildOfClass("Humanoid")
    local display=hum and hum.DisplayName or nil
    if display and display~="" and display~=model.Name then return display end
    local n=tostring(model and model.Name or "Bot")
    if n:match("^%b{}$") or (#n>26 and n:find("%-",1,true)) then return "Bot" end
    return n
end
local bots={}
local function rescanBots()
    local nextSet={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then nextSet[obj]=true end
    end
    bots=nextSet
end
rescanBots()
task.spawn(function()
    while shared.YokaiExecuted~=false do task.wait(.55) rescanBots() end
end)

-- ============================================================================
-- BOT INVENTORY VIEWER
-- Reads only data replicated under each NPC/model. It never reads LocalPlayer.GunInventory.
-- ============================================================================
local function addUnique(out,seen,value)
    value=tostring(value or "")
    if value=="" or value=="nil" then return end
    local low=value:lower()
    if low:find("attachment",1,true) or low:find("inventory",1,true) or low=="weapon" or low=="gun" then return end
    if not seen[value] then seen[value]=true table.insert(out,value) end
end
local function weaponNames(model)
    local out,seen={},{}
    if not model then return out end

    for _,attr in ipairs({"CurrentWeapon","Weapon","Gun","EquippedWeapon","WeaponName","GunName","Loadout"}) do
        local ok,v=pcall(function() return model:GetAttribute(attr) end)
        if ok and v~=nil then addUnique(out,seen,v) end
    end

    for _,obj in ipairs(model:GetDescendants()) do
        if obj:IsA("Tool") then
            addUnique(out,seen,obj.Name)
        elseif obj:IsA("StringValue") then
            local n=obj.Name:lower()
            if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("equipped",1,true) or n:find("loadout",1,true) then
                addUnique(out,seen,obj.Value)
            end
        elseif obj:IsA("ObjectValue") then
            local n=obj.Name:lower()
            if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("equipped",1,true) or n:find("slot",1,true) then
                local ok,v=pcall(function() return obj.Value end)
                if ok and v then addUnique(out,seen,v.Name) end
            end
        elseif obj:IsA("Model") then
            local n=obj.Name
            local low=n:lower()
            if (low:find("m4",1,true) or low:find("ak",1,true) or low:find("rifle",1,true) or low:find("pistol",1,true) or low:find("smg",1,true) or low:find("shotgun",1,true) or low:find("sniper",1,true) or low:find("revolver",1,true)) then
                addUnique(out,seen,n)
            end
        end
    end

    if #out==0 then
        -- Generic fallback: a replicated model named WorldModel/CurrentWeapon often holds the gun.
        for _,name in ipairs({"CurrentWeapon","WorldModelActive","WorldModelInactive","WeaponModel","GunModel"}) do
            local container=model:FindFirstChild(name,true)
            if container then
                for _,child in ipairs(container:GetChildren()) do
                    if child:IsA("Model") or child:IsA("Tool") then addUnique(out,seen,child.Name) end
                end
            end
        end
    end
    return out
end

if Utility then
    removeOption(UtilityRec,"Inventory Viewer")
    destroyGuiNamed("YokaiGunTestingInventoryViewer")
    destroyGuiNamed("YokaiBotInventoryViewerV4")

    local gui=Instance.new("ScreenGui")
    gui.Name="YokaiBotInventoryViewerV4"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=1021
    pcall(function() gui.Parent=(gethui and gethui()) or CoreGui end)
    if not gui.Parent then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(330,58)
    frame.Position=UDim2.new(1,-350,.5,-120)
    frame.BackgroundColor3=Color3.fromRGB(18,18,18)
    frame.BackgroundTransparency=.10
    frame.BorderSizePixel=0
    frame.Visible=false
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,7)

    local title=Instance.new("TextLabel")
    title.BackgroundTransparency=1
    title.Size=UDim2.new(1,-16,0,24)
    title.Position=UDim2.fromOffset(8,4)
    title.Font=Enum.Font.GothamSemibold
    title.TextSize=13
    title.TextColor3=Color3.new(1,1,1)
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Text="Bot Inventory"
    title.Parent=frame

    local body=Instance.new("TextLabel")
    body.BackgroundTransparency=1
    body.Size=UDim2.new(1,-16,1,-31)
    body.Position=UDim2.fromOffset(8,28)
    body.Font=Enum.Font.Gotham
    body.TextSize=11
    body.TextColor3=Color3.fromRGB(220,220,220)
    body.TextXAlignment=Enum.TextXAlignment.Left
    body.TextYAlignment=Enum.TextYAlignment.Top
    body.TextWrapped=false
    body.Text="No bots detected"
    body.Parent=frame

    local enabled=false
    local function refresh()
        if not enabled then return end
        local cam=Workspace.CurrentCamera
        local origin=cam and cam.CFrame.Position
        local ranked={}
        for model in pairs(bots) do
            if isBot(model) then
                local root=rootOf(model)
                if root then
                    table.insert(ranked,{model=model,dist=origin and (root.Position-origin).Magnitude or 0})
                end
            end
        end
        table.sort(ranked,function(a,b) return a.dist<b.dist end)
        local lines={}
        for i=1,math.min(6,#ranked) do
            local item=ranked[i]
            local guns=weaponNames(item.model)
            local weapon=#guns>0 and table.concat(guns,", ") or "weapon not exposed"
            table.insert(lines,string.format("%s  •  %d studs  •  %s",botName(item.model),math.floor(item.dist+.5),weapon))
        end
        body.Text=#lines>0 and table.concat(lines,"\n") or "No bots detected"
        frame.Size=UDim2.fromOffset(330,math.max(58,36+#lines*17))
    end

    Utility.CreateOptionsButton({
        ["Name"]="Inventory Viewer",
        ["Function"]=function(v) enabled=v frame.Visible=v if v then refresh() end end,
        ["HoverText"]="Shows replicated weapon/inventory information for nearby NPCs only.",
    })
    task.spawn(function()
        while gui.Parent do task.wait(.35) if enabled then refresh() end end
    end)
end

-- ============================================================================
-- BOT ARROWS COLOR
-- Replaces only the bot-arrow overlay. The Render > Arrows toggle still controls it.
-- ============================================================================
pcall(function() RunService:UnbindFromRenderStep("YokaiGunTestingBotArrowsV2") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiGunTestingBotArrowsV4") end)
destroyGuiNamed("YokaiBotArrows")
destroyGuiNamed("YokaiBotArrowsV2")
destroyGuiNamed("YokaiBotArrowsV4")

local arrowColor=Color3.new(1,1,1)
local arrowsRec=findOption(RenderRec,"Arrows")
local arrowsApi=arrowsRec and arrowsRec.Api
if arrowsApi and arrowsApi.CreateColorSlider then
    arrowsApi.CreateColorSlider({
        ["Name"]="Bot Color",
        ["Function"]=function(h,s,v) arrowColor=Color3.fromHSV(h,s,v) end,
    })
end

local arrowGui=Instance.new("ScreenGui")
arrowGui.Name="YokaiBotArrowsV4"
arrowGui.ResetOnSpawn=false
arrowGui.IgnoreGuiInset=true
arrowGui.DisplayOrder=1022
pcall(function() arrowGui.Parent=(gethui and gethui()) or CoreGui end)
if not arrowGui.Parent then arrowGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local arrowStore={}
local function newLine()
    local f=Instance.new("Frame")
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=arrowColor
    f.Visible=false
    f.Parent=arrowGui
    return f
end
local function ensureArrow(model)
    local s=arrowStore[model]
    if s then return s end
    s={newLine(),newLine()}
    arrowStore[model]=s
    return s
end
local function hideArrow(s)
    if s then for _,f in ipairs(s) do f.Visible=false end end
end
local function setLine(f,a,b)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.BackgroundColor3=arrowColor
    f.Size=UDim2.fromOffset(d.Magnitude,1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.Visible=true
end
local function arrowsEnabled()
    local rec=findOption(RenderRec,"Arrows")
    return rec and rec.Api and rec.Api.Enabled==true
end

RunService:BindToRenderStep("YokaiGunTestingBotArrowsV4",Enum.RenderPriority.Last.Value+145,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local enabled=arrowsEnabled()
    local live={}
    local vp=cam.ViewportSize
    local center=vp/2
    local radius=math.min(vp.X,vp.Y)*.31

    if enabled then
        for model in pairs(bots) do
            if isBot(model) then
                local root=rootOf(model)
                if root then
                    live[model]=true
                    local s=ensureArrow(model)
                    local p,on=cam:WorldToViewportPoint(root.Position)
                    if on and p.Z>0 then
                        hideArrow(s)
                    else
                        local dir=Vector2.new(p.X,p.Y)-center
                        if p.Z<0 then dir=-dir end
                        if dir.Magnitude<1 then
                            local rel=cam.CFrame:PointToObjectSpace(root.Position)
                            dir=Vector2.new(rel.X,rel.Z>0 and 1 or -1)
                        end
                        if dir.Magnitude>0 then
                            dir=dir.Unit
                            local tip=center+dir*radius
                            local base=tip-dir*13
                            local perp=Vector2.new(-dir.Y,dir.X)
                            setLine(s[1],tip,base+perp*5)
                            setLine(s[2],tip,base-perp*5)
                        else
                            hideArrow(s)
                        end
                    end
                end
            end
        end
    end

    for model,s in pairs(arrowStore) do
        if not live[model] then
            hideArrow(s)
            if not bots[model] then
                for _,f in ipairs(s) do if f then f:Destroy() end end
                arrowStore[model]=nil
            end
        end
    end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Bot arrows color + bot inventory viewer loaded",3) end)
