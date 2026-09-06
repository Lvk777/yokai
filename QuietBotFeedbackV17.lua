-- Final lightweight bot feedback for Gun Testing.
-- Keeps only useful feedback: damage + hitmarker + bot inventory viewer.
-- Player characters are explicitly excluded.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local UtilityRec=objects.UtilityWindow
local WorldRec=objects.WorldWindow
local Utility=UtilityRec and UtilityRec.Api
local World=WorldRec and WorldRec.Api
if not Utility then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP,"") end
local function optionName(key,rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$","")
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
local function removeOption(parentRec,name)
    if not parentRec then return end
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and under(rec,parentRec) and optionName(key,rec)==name then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function humanoidOf(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isBot(model)
    local hum=humanoidOf(model)
    return model and model:IsA("Model") and not playerOwned(model) and model.Name~="YokaiSafeVisualTestTarget" and hum and hum.Health>0 and rootOf(model)~=nil
end
local function botFromPart(part)
    local cur=part
    while cur and cur~=Workspace do
        if cur:IsA("Model") and isBot(cur) then return cur end
        cur=cur.Parent
    end
end

local function normalizePart(name)
    local n=clean(name):lower()
    if n:find("head",1,true) then return "Head" end
    if n:find("torso",1,true) or n:find("chest",1,true) or n:find("body",1,true) then return "Torso" end
    if n:find("left",1,true) and n:find("arm",1,true) then return "Left Arm" end
    if n:find("right",1,true) and n:find("arm",1,true) then return "Right Arm" end
    if n:find("left",1,true) and n:find("leg",1,true) then return "Left Leg" end
    if n:find("right",1,true) and n:find("leg",1,true) then return "Right Leg" end
    if n:find("arm",1,true) then return "Arm" end
    if n:find("leg",1,true) then return "Leg" end
    return clean(name)~="" and clean(name) or "Body"
end

-- ---------------------------------------------------------------------------
-- Lightweight custom hitmarker.
-- ---------------------------------------------------------------------------
local parentGui=(gethui and gethui()) or CoreGui
local old=parentGui:FindFirstChild("YokaiUsefulHitmarkerV17")
if old then old:Destroy() end
local HitGui=Instance.new("ScreenGui")
HitGui.Name="YokaiUsefulHitmarkerV17"; HitGui.ResetOnSpawn=false; HitGui.IgnoreGuiInset=true; HitGui.DisplayOrder=1100; HitGui.Parent=parentGui
local HitRoot=Instance.new("Frame")
HitRoot.AnchorPoint=Vector2.new(.5,.5); HitRoot.Size=UDim2.fromOffset(1,1); HitRoot.BackgroundTransparency=1; HitRoot.Visible=false; HitRoot.Parent=HitGui
local hitLines={}
for i=1,4 do
    local f=Instance.new("Frame"); f.BorderSizePixel=0; f.AnchorPoint=Vector2.new(.5,.5); f.Parent=HitRoot; hitLines[i]=f
end
local hitMarkerEnabled=true
local markerUntil=0
local markerHead=false
local markerConn=nil
local function renderMarker()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    HitRoot.Position=UDim2.fromOffset(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
    local show=hitMarkerEnabled and os.clock()<markerUntil
    HitRoot.Visible=show
    if not show then return end
    local col=markerHead and Color3.fromRGB(255,78,78) or Color3.fromRGB(240,240,240)
    local gap,len,t=7,8,2
    local s={
        {UDim2.fromOffset(-(gap+len/2),-(gap+len/2)),UDim2.fromOffset(len,t),45},
        {UDim2.fromOffset((gap+len/2),-(gap+len/2)),UDim2.fromOffset(len,t),-45},
        {UDim2.fromOffset(-(gap+len/2),(gap+len/2)),UDim2.fromOffset(len,t),-45},
        {UDim2.fromOffset((gap+len/2),(gap+len/2)),UDim2.fromOffset(len,t),45},
    }
    for i,f in ipairs(hitLines) do f.Position=s[i][1]; f.Size=s[i][2]; f.Rotation=s[i][3]; f.BackgroundColor3=col end
end
local function ensureMarkerLoop()
    if markerConn then return end
    markerConn=RunService.RenderStepped:Connect(renderMarker)
end
ensureMarkerLoop()

if World then
    removeOption(WorldRec,"HitMarker")
    local HitOpt=World.CreateOptionsButton({Name="HitMarker",Function=function(v) hitMarkerEnabled=v if not v then HitRoot.Visible=false end end})
end

-- ---------------------------------------------------------------------------
-- Bot registry + health delta tracking.
-- ---------------------------------------------------------------------------
local bots=setmetatable({}, {__mode="k"})
local healthConnections=setmetatable({}, {__mode="k"})
local lastHealth=setmetatable({}, {__mode="k"})
local lastHitBot=nil
local lastHitPart="Body"
local lastHitAt=0
local pendingMarkerAt=0
local damageNotifications=true

local function bestBotFromCrosshair()
    local cam=Workspace.CurrentCamera
    if not cam then return nil,nil end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local filter={cam}
    if LocalPlayer.Character then table.insert(filter,LocalPlayer.Character) end
    rp.FilterDescendantsInstances=filter
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,cam.CFrame.LookVector*5000,rp)
    if hit then return botFromPart(hit.Instance),hit.Instance end
end

local function resolveRecentAim()
    local sharedAim=shared.YokaiGunTestingLastAimPart
    if type(sharedAim)=="table" and tonumber(sharedAim.At) and os.clock()-sharedAim.At<.6 and isBot(sharedAim.Model) then
        local part=sharedAim.Model:FindFirstChild(sharedAim.Part,true)
        return sharedAim.Model,part,normalizePart(sharedAim.Part)
    end
    local bot,part=bestBotFromCrosshair()
    return bot,part,part and normalizePart(part.Name) or "Body"
end

local function registerBot(model)
    if not isBot(model) or bots[model] then return end
    bots[model]=true
    local hum=humanoidOf(model)
    if not hum then return end
    lastHealth[model]=hum.Health
    healthConnections[model]=hum:GetPropertyChangedSignal("Health"):Connect(function()
        local oldHp=tonumber(lastHealth[model]) or hum.Health
        local newHp=tonumber(hum.Health) or oldHp
        lastHealth[model]=newHp
        if newHp>=oldHp then return end
        local delta=math.max(0,oldHp-newHp)
        if delta<=0 then return end
        -- Only attribute the popup to the local player when a local hitmarker was
        -- received very recently and it resolves to this same bot.
        if os.clock()-lastHitAt<=.45 and (lastHitBot==nil or lastHitBot==model) then
            lastHitBot=model
            if damageNotifications then
                pcall(function()
                    GuiLibrary.CreateNotification("Damage",string.format("%s  •  -%d HP  •  %s",lastHitPart,math.floor(delta+.5),model.Name),2.2)
                end)
            end
        end
    end)
end

for _,d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerBot(d.Parent) end
end
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerBot,d.Parent) end
end)

-- ---------------------------------------------------------------------------
-- Use GunPlugin's real local hitmarker signal when available.
-- ---------------------------------------------------------------------------
task.spawn(function()
    local ok,plugin=pcall(function()
        local ps=LocalPlayer:WaitForChild("PlayerScripts",8)
        local gc=ps and ps:WaitForChild("GunController",8)
        local ev=gc and gc:WaitForChild("Events",8)
        local mod=ev and ev:WaitForChild("GunPlugin",8)
        return mod and require(mod)
    end)
    if not (ok and type(plugin)=="table" and type(plugin.OnHitmarker)=="function") then return end
    local ok2,sig=pcall(function() return plugin:OnHitmarker() end)
    if not (ok2 and sig and type(sig.Connect)=="function") then return end
    sig:Connect(function(headshot)
        local bot,part,label=resolveRecentAim()
        lastHitAt=os.clock()
        lastHitBot=bot
        lastHitPart=headshot==true and "Head" or label
        markerHead=headshot==true
        markerUntil=os.clock()+.20
    end)
end)

if World then
    removeOption(WorldRec,"Damage Notification")
    World.CreateOptionsButton({Name="Damage Notification",Function=function(v) damageNotifications=v end})
end

-- ---------------------------------------------------------------------------
-- BOT Inventory Viewer. Shows the most recently hit bot; otherwise the bot under
-- the crosshair. It never displays LocalPlayer inventory.
-- ---------------------------------------------------------------------------
removeOption(UtilityRec,"Inventory Viewer")
for _,root in ipairs({LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui,parentGui}) do
    if root then
        local oldViewer=root:FindFirstChild("YokaiBotInventoryViewerV17",true)
        if oldViewer then pcall(function() oldViewer:Destroy() end) end
        local oldLocal=root:FindFirstChild("YokaiGunTestingInventoryViewer",true)
        if oldLocal then pcall(function() oldLocal:Destroy() end) end
    end
end

local InvGui=Instance.new("ScreenGui")
InvGui.Name="YokaiBotInventoryViewerV17"; InvGui.ResetOnSpawn=false; InvGui.IgnoreGuiInset=true; InvGui.DisplayOrder=1040; InvGui.Parent=parentGui
local frame=Instance.new("Frame")
frame.Size=UDim2.fromOffset(340,86); frame.Position=UDim2.new(1,-360,.5,-43); frame.BackgroundColor3=Color3.fromRGB(17,17,19); frame.BackgroundTransparency=.08; frame.BorderSizePixel=0; frame.Visible=false; frame.Parent=InvGui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,7); corner.Parent=frame
local title=Instance.new("TextLabel")
title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,20); title.Font=Enum.Font.GothamSemibold; title.TextSize=13; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="Bot Inventory"; title.Parent=frame
local body=Instance.new("TextLabel")
body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(12,31); body.Size=UDim2.new(1,-24,1,-39); body.Font=Enum.Font.Gotham; body.TextSize=12; body.TextColor3=Color3.fromRGB(210,210,215); body.TextXAlignment=Enum.TextXAlignment.Left; body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true; body.Text="Aim at or hit a bot"; body.Parent=frame

local inventoryEnabled=false
local function collectInventory(model)
    if not isBot(model) then return "No bot selected" end
    local hum=humanoidOf(model)
    local items={}
    local seen={}
    local function add(name)
        name=clean(name)
        if name~="" and not seen[name] then seen[name]=true; table.insert(items,name) end
    end
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("Tool") then add(d.Name)
        elseif d:IsA("ObjectValue") then
            local n=d.Name:lower()
            if (n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true)) and d.Value then add(d.Value.Name) end
        elseif d:IsA("StringValue") then
            local n=d.Name:lower()
            if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true) then add(d.Value) end
        elseif d:IsA("Model") then
            local n=d.Name:lower()
            if n:find("rifle",1,true) or n:find("pistol",1,true) or n:find("shotgun",1,true) or n:find("weapon",1,true) or n:find("gun",1,true) then add(d.Name) end
        end
        if #items>=6 then break end
    end
    local hp=hum and string.format("%d/%d HP",math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5)) or "HP ?"
    local gear=#items>0 and table.concat(items,", ") or "No exposed weapon/item"
    return hp.."\n"..gear
end

local function selectedBot()
    if isBot(lastHitBot) and os.clock()-lastHitAt<8 then return lastHitBot end
    local b=select(1,bestBotFromCrosshair())
    return b
end

Utility.CreateOptionsButton({Name="Inventory Viewer",Function=function(v) inventoryEnabled=v; frame.Visible=v end,HoverText="Shows the inventory/equipment exposed by the bot you last hit or aim at."})

task.spawn(function()
    while InvGui.Parent do
        if inventoryEnabled then
            local bot=selectedBot()
            if bot then title.Text="Bot Inventory  •  "..bot.Name; body.Text=collectInventory(bot)
            else title.Text="Bot Inventory"; body.Text="Aim at or hit a bot" end
            task.wait(.25)
        else task.wait(.5) end
    end
end)

shared.YokaiQuietBotFeedbackV17=true
