-- Adapted from the user-provided LvkHub reference, but scoped to NPC/bot practice.
-- Aimbot uses the same mouse-relative/prediction style, Fly keeps the same control feel,
-- and Inventory Viewer follows the nearest-to-cursor viewer idea. Player characters are excluded.
-- No remotes, anti-cheat bypass, kick hooks or ban-evasion.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec=objects.CombatWindow
local MovementRec=objects.MovementWindow
local UtilityRec=objects.UtilityWindow
local Combat=CombatRec and CombatRec.Api
local Movement=MovementRec and MovementRec.Api
local Utility=UtilityRec and UtilityRec.Api
if not (Combat and Movement and Utility) then return end

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
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and under(rec,parentRec) and optionName(key,rec)==name then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

-- ==========================================================================
-- Shared event-driven bot registry. One initial scan only.
-- ==========================================================================
local bots=setmetatable({}, {__mode="k"})
local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) or model.Name=="YokaiSafeVisualTestTarget" then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    return hum~=nil and hum.Health>0 and rootOf(model)~=nil
end
local function register(model)
    if isBot(model) then bots[model]=true end
end
for _,d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then register(d.Parent) end
end
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(register,d.Parent)
    elseif d:IsA("Model") then task.defer(register,d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then bots[d]=nil
    elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
end)

local function aimPart(model,name)
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function visible(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local f={cam}
    if LocalPlayer.Character then table.insert(f,LocalPlayer.Character) end
    rp.FilterDescendantsInstances=f
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end

-- ==========================================================================
-- AIMBOT: adapted from the supplied script's center-FOV + mousemoverel model.
-- Uses target velocity + travel time and optional bullet-drop compensation.
-- ==========================================================================
removeOption(CombatRec,"Aimbot")
for _,bind in ipairs({"YokaiBotAimbot","YokaiGunTestingAimbotV2","YokaiGunTestingAimbotV3","YokaiReferenceAimbotV18"}) do
    pcall(function() RunService:UnbindFromRenderStep(bind) end)
end

local aimEnabled=false
local aimFov=275
local sensitivity=.70
local aimPartName="Head"
local wallCheck=true
local prediction=true
local bulletSpeed=2250
local bulletGravity=50
local maxDistance=2500
local rightHeld=false
local mover=rawget((getgenv and getgenv()) or _G,"mousemoverel") or rawget(_G,"mousemoverel")

local function weaponStats()
    local speed,gravity=bulletSpeed,bulletGravity
    -- Same lookup idea as the reference script, but optional so the module remains portable.
    local selected=LocalPlayer:FindFirstChild("CurrentSelectedObject")
    local weaponName=nil
    pcall(function()
        local v=selected and selected.Value
        if typeof(v)=="Instance" then
            local vv=v:FindFirstChild("Value")
            weaponName=vv and vv.Value and vv.Value.Name or v.Name
        end
    end)
    local gunData=ReplicatedStorage:FindFirstChild("GunData")
    local weapon=gunData and weaponName and gunData:FindFirstChild(weaponName)
    local bs=weapon and weapon:FindFirstChild("Stats") and weapon.Stats:FindFirstChild("BulletSettings")
    if bs then
        local s=bs:FindFirstChild("BulletSpeed")
        local g=bs:FindFirstChild("BulletGravity")
        if s and tonumber(s.Value) then speed=tonumber(s.Value) end
        if g and tonumber(g.Value) then gravity=tonumber(g.Value) end
    end
    return math.max(100,speed),tonumber(gravity) or 0
end
local function predicted(part,root)
    if not prediction then return part.Position end
    local cam=Workspace.CurrentCamera
    if not cam then return part.Position end
    local speed,gravity=weaponStats()
    local distance=(part.Position-cam.CFrame.Position).Magnitude
    local travel=distance/speed
    local velocity=root and root.AssemblyLinearVelocity or Vector3.zero
    local pos=part.Position + velocity*travel
    -- Keep the reference script's drop convention.
    local drop=(gravity*travel*travel)/2
    return pos + Vector3.new(0,-drop,0)
end
local function nearestTarget()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPos,bestPx=nil,nil,nil,aimFov
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,aimPartName)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=maxDistance and (not wallCheck or visible(model,part)) then
                local pos=predicted(part,root)
                local p,on=cam:WorldToViewportPoint(pos)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-center).Magnitude
                    if px<bestPx then best,bestPart,bestPos,bestPx=model,part,pos,px end
                end
            end
        end
    end
    return best,bestPart,bestPos
end

UserInputService.InputBegan:Connect(function(input,processed)
    if not processed and input.UserInputType==Enum.UserInputType.MouseButton2 then rightHeld=true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then rightHeld=false end
end)

local Aimbot=Combat.CreateOptionsButton({Name="Aimbot",Function=function(v) aimEnabled=v end,HoverText="Reference-style bot aimbot: Mouse2, center FOV, prediction and relative mouse movement."})
Aimbot.CreateSlider({Name="FOV",Min=40,Max=900,Default=275,Function=function(v) aimFov=v end})
Aimbot.CreateSlider({Name="Sensitivity",Min=5,Max=100,Default=70,Function=function(v) sensitivity=v/100 end})
Aimbot.CreateDropdown({Name="Aim Part",List={"Head","Torso"},Function=function(v) aimPartName=v end})
Aimbot.CreateToggle({Name="WallCheck",Default=true,Function=function(v) wallCheck=v end})
Aimbot.CreateToggle({Name="Prediction",Default=true,Function=function(v) prediction=v end})
Aimbot.CreateSlider({Name="Bullet Speed",Min=300,Max=4000,Default=2250,Function=function(v) bulletSpeed=v end})
Aimbot.CreateSlider({Name="Bullet Gravity",Min=0,Max=200,Default=50,Function=function(v) bulletGravity=v end})
Aimbot.CreateSlider({Name="Max Distance",Min=100,Max=5000,Default=2500,Function=function(v) maxDistance=v end})

RunService:BindToRenderStep("YokaiReferenceAimbotV18",Enum.RenderPriority.Camera.Value+20,function()
    if not aimEnabled or not rightHeld then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local model,part,pos=nearestTarget()
    if not model or not pos then return end
    shared.YokaiGunTestingLastAimPart={Part=part and part.Name or aimPartName,At=os.clock(),Model=model}
    local p,on=cam:WorldToViewportPoint(pos)
    if not on or p.Z<=0 then return end
    local center=cam.ViewportSize/2
    local dx=(p.X-center.X)*sensitivity
    local dy=(p.Y-center.Y)*sensitivity
    if type(mover)=="function" then
        pcall(mover,dx,dy)
    else
        local desired=CFrame.lookAt(cam.CFrame.Position,pos)
        cam.CFrame=cam.CFrame:Lerp(desired,math.clamp(sensitivity,.05,1))
    end
end)

-- ==========================================================================
-- FLY: reference control feel, but optimized to one connection and no part spam.
-- Menu toggle arms the feature; J toggles actual flight. Shift up / Ctrl down.
-- ==========================================================================
removeOption(MovementRec,"Fly")
local flyModuleEnabled=false
local flyActive=false
local flySpeed=70
local flyConn=nil
local savedAutoRotate=nil

local function characterParts()
    local c=LocalPlayer.Character
    if not c then return nil end
    return c,c:FindFirstChildOfClass("Humanoid"),c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
end
local function setFlyActive(v)
    flyActive=v and flyModuleEnabled
    local _,hum,root=characterParts()
    if flyActive then
        if hum and savedAutoRotate==nil then savedAutoRotate=hum.AutoRotate end
        if hum then hum.AutoRotate=false; hum.PlatformStand=true end
    else
        if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
        if hum then hum.PlatformStand=false; hum.AutoRotate=(savedAutoRotate==nil) and true or savedAutoRotate end
        savedAutoRotate=nil
    end
end
local function flyVector()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector3.zero end
    local forward=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z)
    local right=Vector3.new(cam.CFrame.RightVector.X,0,cam.CFrame.RightVector.Z)
    if forward.Magnitude>.01 then forward=forward.Unit end
    if right.Magnitude>.01 then right=right.Unit end
    local v=Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then v+=forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then v-=forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then v+=right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then v-=right end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v+=Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then v-=Vector3.yAxis end
    return v
end
local function ensureFlyConnection()
    if flyConn then return end
    flyConn=RunService.Heartbeat:Connect(function()
        if not flyModuleEnabled or not flyActive then return end
        local _,hum,root=characterParts()
        if not root then return end
        if hum then hum.PlatformStand=true; hum.AutoRotate=false end
        local v=flyVector()
        root.AssemblyLinearVelocity=v.Magnitude>0 and v.Unit*flySpeed or Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
    end)
end
local Fly=Movement.CreateOptionsButton({Name="Fly",Function=function(v)
    flyModuleEnabled=v
    if v then ensureFlyConnection(); setFlyActive(true) else setFlyActive(false) end
end,HoverText="Reference-style Fly. Menu enables it; J toggles. WASD, Shift up, Ctrl down."})
Fly.CreateSlider({Name="Speed",Min=20,Max=220,Default=70,Function=function(v) flySpeed=v end})
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or input.KeyCode~=Enum.KeyCode.J or not flyModuleEnabled then return end
    setFlyActive(not flyActive)
end)
LocalPlayer.CharacterAdded:Connect(function() task.wait(.25); if flyModuleEnabled and flyActive then setFlyActive(true) end end)

-- ==========================================================================
-- BOT INVENTORY VIEWER: nearest-to-cursor target selection from the reference IV,
-- but updates at 6 Hz instead of RenderStepped and never selects Players.
-- ==========================================================================
removeOption(UtilityRec,"Inventory Viewer")
local parentGui=(gethui and gethui()) or CoreGui
for _,name in ipairs({"YokaiBotInventoryViewerV17","YokaiReferenceBotInventoryV18","YokaiGunTestingInventoryViewer"}) do
    local old=parentGui:FindFirstChild(name,true)
    if old then pcall(function() old:Destroy() end) end
end
local InvGui=Instance.new("ScreenGui")
InvGui.Name="YokaiReferenceBotInventoryV18"; InvGui.ResetOnSpawn=false; InvGui.IgnoreGuiInset=true; InvGui.DisplayOrder=1040; InvGui.Parent=parentGui
local frame=Instance.new("Frame")
frame.Size=UDim2.fromOffset(390,132); frame.Position=UDim2.new(1,-410,.5,-66); frame.BackgroundColor3=Color3.fromRGB(17,17,19); frame.BackgroundTransparency=.08; frame.BorderSizePixel=0; frame.Visible=false; frame.Parent=InvGui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,7); corner.Parent=frame
local title=Instance.new("TextLabel")
title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,22); title.Font=Enum.Font.GothamSemibold; title.TextSize=13; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="Bot Inventory"; title.Parent=frame
local body=Instance.new("TextLabel")
body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(12,34); body.Size=UDim2.new(1,-24,1,-42); body.Font=Enum.Font.Code; body.TextSize=12; body.TextColor3=Color3.fromRGB(217,218,219); body.TextXAlignment=Enum.TextXAlignment.Left; body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true; body.RichText=true; body.Text="Aim near a bot"; body.Parent=frame

local invEnabled=false
local invRadius=500
local function nearestBotToCursor()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local mouse=UserInputService:GetMouseLocation()
    local ref=Vector2.new(mouse.X,mouse.Y)
    local best,bestPx=nil,invRadius
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            if root then
                local p,on=cam:WorldToViewportPoint(root.Position)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-ref).Magnitude
                    if px<bestPx then best,bestPx=model,px end
                end
            end
        end
    end
    return best
end
local function valueText(obj)
    local ok,v=pcall(function() return obj.Value end)
    if not ok then return nil end
    if typeof(v)=="Instance" then return v.Name end
    return v~=nil and tostring(v) or nil
end
local function inventoryLines(model)
    if not isBot(model) then return {"No bot selected"} end
    local lines={}
    local hum=model:FindFirstChildOfClass("Humanoid")
    if hum then table.insert(lines,string.format("HP  %d/%d",math.floor(hum.Health+.5),math.floor(hum.MaxHealth+.5))) end
    local inv=model:FindFirstChild("GunInventory",true)
    if inv then
        for _,slot in ipairs(inv:GetChildren()) do
            if slot.Name~="Slot0" and slot.Name~="Slot50" then
                local item=valueText(slot) or slot.Name
                local mag=slot:FindFirstChild("BulletsInMagazine")
                local reserve=slot:FindFirstChild("BulletsInReserve")
                local ammo=""
                if mag or reserve then ammo=string.format("  [%s/%s]",mag and tostring(mag.Value) or "--",reserve and tostring(reserve.Value) or "--") end
                table.insert(lines,string.format("%s -> %s%s",slot.Name,item,ammo))
                if #lines>=7 then break end
            end
        end
    end
    if #lines<=1 then
        local seen={}
        for _,d in ipairs(model:GetDescendants()) do
            local add=nil
            if d:IsA("Tool") then add=d.Name
            elseif d:IsA("ObjectValue") then
                local n=d.Name:lower(); if (n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true)) and d.Value then add=d.Value.Name end
            elseif d:IsA("StringValue") then
                local n=d.Name:lower(); if n:find("weapon",1,true) or n:find("gun",1,true) or n:find("item",1,true) then add=d.Value end
            end
            if add and add~="" and not seen[add] then seen[add]=true; table.insert(lines,add) end
            if #lines>=7 then break end
        end
    end
    if #lines==1 then table.insert(lines,"No exposed inventory") end
    return lines
end
local Inv=Utility.CreateOptionsButton({Name="Inventory Viewer",Function=function(v) invEnabled=v; frame.Visible=v end,HoverText="Reference-style nearest-to-cursor inventory viewer, adapted to bots only."})
Inv.CreateSlider({Name="Cursor Radius",Min=100,Max=900,Default=500,Function=function(v) invRadius=v end})

task.spawn(function()
    while InvGui.Parent do
        if invEnabled then
            local bot=nearestBotToCursor()
            if bot then title.Text="Bot Inventory  •  "..bot.Name; body.Text=table.concat(inventoryLines(bot),"\n")
            else title.Text="Bot Inventory"; body.Text="Aim near a bot" end
            task.wait(.16)
        else
            task.wait(.45)
        end
    end
end)

shared.YokaiReferenceBotAdaptersV18=true
