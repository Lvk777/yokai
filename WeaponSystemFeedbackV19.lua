-- Feedback layer for the WeaponSystem bot-practice runtime.
-- Uses local shot-builder calls + NPC health deltas. Player characters are excluded.
repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary
if shared.YokaiWeaponSystemFeedbackV19 then return end
shared.YokaiWeaponSystemFeedbackV19=true

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local UserInputService=game:GetService("UserInputService")
local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local WorldRec=objects.WorldWindow
local UtilityRec=objects.UtilityWindow
local World=WorldRec and WorldRec.Api
local Utility=UtilityRec and UtilityRec.Api
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
        if rec and rec.Type=="OptionsButton" and under(rec,parentRec) and optionName(key,rec)==name then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do pcall(function() GuiLibrary.RemoveObject(key) end) end
end

local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local c=plr.Character
        if c and (model==c or model:IsDescendantOf(c) or c:IsDescendantOf(model)) then return true end
    end
    return false
end
local function rootOf(model) return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart) end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local h=model:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0 and rootOf(model)~=nil
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
    if n:find("torso",1,true) or n:find("chest",1,true) then return "Torso" end
    if n:find("left",1,true) and n:find("arm",1,true) then return "Left Arm" end
    if n:find("right",1,true) and n:find("arm",1,true) then return "Right Arm" end
    if n:find("left",1,true) and n:find("leg",1,true) then return "Left Leg" end
    if n:find("right",1,true) and n:find("leg",1,true) then return "Right Leg" end
    return clean(name)~="" and clean(name) or "Body"
end

-- Hook the already-patched ShotBuilder only to record local shot context.
local ps=LocalPlayer:FindFirstChild("PlayerScripts")
local client=ps and ps:FindFirstChild("Client")
local systems=client and client:FindFirstChild("Systems")
local gunSystem=systems and systems:FindFirstChild("GunSystem")
local view=gunSystem and gunSystem:FindFirstChild("WeaponViewmodelController")
local shotModule=view and view:FindFirstChild("WeaponShotBuilder")
if shotModule and shotModule:IsA("ModuleScript") then
    local ok,builder=pcall(require,shotModule)
    if ok and type(builder)=="table" and type(builder.GetShotOriginAndDirection)=="function" and not shared.YokaiWeaponSystemFeedbackWrapped19 then
        shared.YokaiWeaponSystemFeedbackWrapped19=true
        local previous=builder.GetShotOriginAndDirection
        builder.GetShotOriginAndDirection=function(...)
            local origin,dir,cf=previous(...)
            if origin and dir then
                local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={LocalPlayer.Character,Workspace.CurrentCamera}; rp.IgnoreWater=true
                local hit=Workspace:Raycast(origin,dir.Unit*5000,rp)
                local bot=hit and botFromPart(hit.Instance) or nil
                shared.YokaiWeaponSystemShotContext={At=os.clock(),Model=bot,Part=hit and normalizePart(hit.Instance.Name) or "Body"}
            end
            return origin,dir,cf
        end
    end
end

-- Lightweight hitmarker.
local parent=(gethui and gethui()) or CoreGui
local old=parent:FindFirstChild("YokaiWeaponSystemHitmarker19")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui"); gui.Name="YokaiWeaponSystemHitmarker19"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1110; gui.Parent=parent
local root=Instance.new("Frame"); root.AnchorPoint=Vector2.new(.5,.5); root.Size=UDim2.fromOffset(1,1); root.BackgroundTransparency=1; root.Visible=false; root.Parent=gui
local lines={}
for i=1,4 do local f=Instance.new("Frame"); f.AnchorPoint=Vector2.new(.5,.5); f.BorderSizePixel=0; f.BackgroundColor3=Color3.new(1,1,1); f.Parent=root; lines[i]=f end
local markerEnabled=true
local markerUntil=0
local markerHead=false
local function showMarker(head)
    markerHead=head; markerUntil=os.clock()+.20
end
RunService.RenderStepped:Connect(function()
    local cam=Workspace.CurrentCamera; if not cam then return end
    root.Position=UDim2.fromOffset(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
    local show=markerEnabled and os.clock()<markerUntil; root.Visible=show; if not show then return end
    local c=markerHead and Color3.fromRGB(255,70,70) or Color3.new(1,1,1)
    local gap,len,t=7,8,2
    local specs={{-1,-1,45},{1,-1,-45},{-1,1,-45},{1,1,45}}
    for i,f in ipairs(lines) do local sx,sy,rot=table.unpack(specs[i]); f.Position=UDim2.fromOffset(sx*(gap+len/2),sy*(gap+len/2)); f.Size=UDim2.fromOffset(len,t); f.Rotation=rot; f.BackgroundColor3=c end
end)
if World then
    removeOption(WorldRec,"HitMarker")
    World.CreateOptionsButton({Name="HitMarker",Function=function(v) markerEnabled=v if not v then root.Visible=false end end})
end

-- Event-driven bot health tracking.
local lastHealth=setmetatable({}, {__mode="k"})
local watched=setmetatable({}, {__mode="k"})
local lastHitBot=nil
local lastHitAt=0
local damageEnabled=true
local function watch(model)
    if not isBot(model) or watched[model] then return end
    local hum=model:FindFirstChildOfClass("Humanoid"); if not hum then return end
    watched[model]=true; lastHealth[model]=hum.Health
    hum:GetPropertyChangedSignal("Health"):Connect(function()
        local oldHp=tonumber(lastHealth[model]) or hum.Health
        local newHp=tonumber(hum.Health) or oldHp
        lastHealth[model]=newHp
        if newHp>=oldHp then return end
        local delta=oldHp-newHp
        local ctx=shared.YokaiWeaponSystemShotContext
        if type(ctx)=="table" and tonumber(ctx.At) and os.clock()-ctx.At<.55 and (ctx.Model==nil or ctx.Model==model) then
            local part=normalizePart(ctx.Part)
            lastHitBot=model; lastHitAt=os.clock(); showMarker(part=="Head")
            if damageEnabled then pcall(function() GuiLibrary.CreateNotification("Damage",string.format("%s  •  -%d HP  •  %s",part,math.floor(delta+.5),model.Name),2.2) end) end
        end
    end)
end
for _,d in ipairs(Workspace:GetDescendants()) do if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then watch(d.Parent) end end
Workspace.DescendantAdded:Connect(function(d) if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(watch,d.Parent) end end)
if World then
    removeOption(WorldRec,"Damage Notification")
    World.CreateOptionsButton({Name="Damage Notification",Function=function(v) damageEnabled=v end})
end

-- Bot inventory viewer: last hit bot, otherwise bot nearest to cursor.
removeOption(UtilityRec,"Inventory Viewer")
local oldInv=parent:FindFirstChild("YokaiWeaponSystemBotInventory19")
if oldInv then oldInv:Destroy() end
local inv=Instance.new("ScreenGui"); inv.Name="YokaiWeaponSystemBotInventory19"; inv.ResetOnSpawn=false; inv.IgnoreGuiInset=true; inv.DisplayOrder=1050; inv.Parent=parent
local frame=Instance.new("Frame"); frame.Size=UDim2.fromOffset(360,94); frame.Position=UDim2.new(1,-380,.5,-47); frame.BackgroundColor3=Color3.fromRGB(17,17,19); frame.BackgroundTransparency=.08; frame.BorderSizePixel=0; frame.Visible=false; frame.Parent=inv
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,7)
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,20); title.Font=Enum.Font.GothamSemibold; title.TextSize=13; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=frame
local body=Instance.new("TextLabel"); body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(12,31); body.Size=UDim2.new(1,-24,1,-39); body.Font=Enum.Font.Gotham; body.TextSize=12; body.TextColor3=Color3.fromRGB(210,210,215); body.TextXAlignment=Enum.TextXAlignment.Left; body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true; body.Parent=frame
local invEnabled=false
local function nearestCursorBot()
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local m=UserInputService:GetMouseLocation(); local ref=Vector2.new(m.X,m.Y); local best,bestPx=nil,500
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and isBot(d.Parent) then
            local r=rootOf(d.Parent); local p,on=cam:WorldToViewportPoint(r.Position)
            if on and p.Z>0 then local px=(Vector2.new(p.X,p.Y)-ref).Magnitude; if px<bestPx then best,bestPx=d.Parent,px end end
        end
    end
    return best
end
local function inventoryText(model)
    if not isBot(model) then return "No bot selected" end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local items,seen={},{}
    local function add(x) x=clean(x); if x~="" and not seen[x] then seen[x]=true; table.insert(items,x) end end
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("Tool") then add(d.Name)
        elseif d:IsA("StringValue") then local n=d.Name:lower(); if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true) then add(d.Value) end
        elseif d:IsA("ObjectValue") and d.Value then local n=d.Name:lower(); if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true) then add(d.Value.Name) end end
        if #items>=7 then break end
    end
    return string.format("%d/%d HP\n%s",math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5),#items>0 and table.concat(items,", ") or "No exposed weapon/item")
end
Utility.CreateOptionsButton({Name="Inventory Viewer",Function=function(v) invEnabled=v; frame.Visible=v end})
task.spawn(function()
    while inv.Parent do
        if invEnabled then
            local bot=(lastHitBot and isBot(lastHitBot) and os.clock()-lastHitAt<8) and lastHitBot or nearestCursorBot()
            title.Text=bot and ("Bot Inventory  •  "..bot.Name) or "Bot Inventory"
            body.Text=bot and inventoryText(bot) or "Aim at or hit a bot"
            task.wait(.30)
        else task.wait(.6) end
    end
end)

shared.YokaiWeaponSystemFeedbackV19Loaded=true
