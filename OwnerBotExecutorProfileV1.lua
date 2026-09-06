-- Executor-only bot training profile for an experience owned by the user.
-- NPC-only targeting: any Model owned by a Player is excluded.
-- No anti-cheat bypass, ban evasion, executor hiding, or Player targeting.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec=objects["CombatWindow"]
local Combat=CombatRec and CombatRec.Api
if not Combat then return end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP,"") end
local function optionName(key) return clean(key):gsub("OptionsButton$","") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,CombatRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
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
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=rootOf(model)
    return hum~=nil and root~=nil and hum.Health>0
end

local bots={}
local function rescanBots()
    local t={}
    local root=Workspace:FindFirstChild("Zombies") or Workspace
    for _,obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then t[obj]=true end
    end
    bots=t
end
rescanBots()
task.spawn(function()
    while shared.YokaiExecuted~=false do task.wait(.5) rescanBots() end
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
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function predict(model,part,enabled,strength)
    if not enabled then return part.Position end
    local root=rootOf(model)
    if not root then return part.Position end
    return part.Position + root.AssemblyLinearVelocity*math.clamp(strength,0,2)*.055
end
local function nearestBot(fov,partName,wall,prediction,strength,maxDistance)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPos,bestPx=nil,nil,nil,fov
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,partName)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=maxDistance and (not wall or visible(model,part)) then
                local pos=predict(model,part,prediction,strength)
                local p,on=cam:WorldToViewportPoint(pos)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-center).Magnitude
                    if px<bestPx then best,bestPart,bestPos,bestPx=model,part,pos,px end
                end
            end
        end
    end
    return best,bestPart,bestPos,bestPx
end

-- AIMBOT: intentionally simple to configure.
removeOption("Aimbot")
for _,bind in ipairs({"YokaiOwnerBotAimbotV1","YokaiGunTestingAimbotV3"}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end
local aimEnabled=false
local aimFov=350
local aimPartName="Head"
local aimSmooth=.92
local aimWall=true
local aimPrediction=true
local aimPredictionStrength=1
local aimDistance=1600
local Aimbot=Combat.CreateOptionsButton({["Name"]="Aimbot",["Function"]=function(v) aimEnabled=v end,["HoverText"]="NPC-only aim assist for the owner's bot training game."})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=60,["Max"]=1000,["Default"]=350,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Precision",["Min"]=1,["Max"]=100,["Default"]=92,["Function"]=function(v) aimSmooth=v/100 end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Prediction",["Min"]=0,["Max"]=200,["Default"]=100,["Function"]=function(v) aimPredictionStrength=v/100 end})
Aimbot.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=1600,["Function"]=function(v) aimDistance=v end})
RunService:BindToRenderStep("YokaiOwnerBotAimbotV1",Enum.RenderPriority.Camera.Value+25,function(dt)
    if not aimEnabled or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local _,_,pos=nearestBot(aimFov,aimPartName,aimWall,aimPrediction,aimPredictionStrength,aimDistance)
    if pos then
        local target=CFrame.lookAt(cam.CFrame.Position,pos)
        local alpha=math.clamp(aimSmooth*math.max(1,dt*60),.08,1)
        cam.CFrame=cam.CFrame:Lerp(target,alpha)
    end
end)

-- MAGIC BULLETS: generic executor-only pre-shot camera redirect.
-- Works in weapons that sample CurrentCamera/look direction on the fire frame.
removeOption("Magic Bullets")
local magicEnabled=false
local magicFov=700
local magicPart="Head"
local magicWall=true
local magicPrediction=true
local magicPredictionStrength=1
local magicDistance=2000
local magicToken=0
local Magic=Combat.CreateOptionsButton({["Name"]="Magic Bullets",["Function"]=function(v) magicEnabled=v end,["HoverText"]="NPC-only generic shot redirect; no Player targets."})
Magic.CreateDropdown({["Name"]="Target",["List"]={"Head","Torso"},["Function"]=function(v) magicPart=v end})
Magic.CreateSlider({["Name"]="FOV",["Min"]=100,["Max"]=1600,["Default"]=700,["Function"]=function(v) magicFov=v end})
Magic.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) magicWall=v end})
Magic.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) magicPrediction=v end})
Magic.CreateSlider({["Name"]="Prediction",["Min"]=0,["Max"]=200,["Default"]=100,["Function"]=function(v) magicPredictionStrength=v/100 end})
Magic.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=2000,["Function"]=function(v) magicDistance=v end})
UserInputService.InputBegan:Connect(function(input,gp)
    if gp or not magicEnabled or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local _,_,pos=nearestBot(magicFov,magicPart,magicWall,magicPrediction,magicPredictionStrength,magicDistance)
    if not pos then return end
    magicToken+=1
    local token=magicToken
    local before=cam.CFrame
    cam.CFrame=CFrame.lookAt(before.Position,pos)
    RunService.RenderStepped:Wait()
    if token==magicToken and cam and cam.Parent then cam.CFrame=before end
end)

-- Local weapon-value cache for generic Infinite Ammo/Fast Reload.
local ammoWords={"ammo","magazine","clip","bullets","reserve"}
local reloadWords={"reloadtime","reloadduration","reloaddelay","reloadspeed"}
local cachedAmmo={}
local cachedReload={}
local function hasWord(name,list)
    local n=string.lower(tostring(name))
    for _,w in ipairs(list) do if n:find(w,1,true) then return true end end
    return false
end
local function addValue(list,obj)
    if obj:IsA("IntValue") or obj:IsA("NumberValue") then table.insert(list,{obj=obj,kind="Value"}) end
    for attr,v in pairs(obj:GetAttributes()) do
        if type(v)=="number" then table.insert(list,{obj=obj,kind="Attr",name=attr}) end
    end
end
local function refreshWeaponFields()
    cachedAmmo={} cachedReload={}
    local roots={LocalPlayer.Character,LocalPlayer:FindFirstChildOfClass("Backpack"),LocalPlayer:FindFirstChild("PlayerGui")}
    for _,root in ipairs(roots) do
        if root then
            for _,obj in ipairs(root:GetDescendants()) do
                if hasWord(obj.Name,ammoWords) then addValue(cachedAmmo,obj) end
                if hasWord(obj.Name,reloadWords) then addValue(cachedReload,obj) end
                for attr,v in pairs(obj:GetAttributes()) do
                    if type(v)=="number" then
                        if hasWord(attr,ammoWords) then table.insert(cachedAmmo,{obj=obj,kind="Attr",name=attr}) end
                        if hasWord(attr,reloadWords) then table.insert(cachedReload,{obj=obj,kind="Attr",name=attr}) end
                    end
                end
            end
        end
    end
end
refreshWeaponFields()
task.spawn(function() while shared.YokaiExecuted~=false do task.wait(1) refreshWeaponFields() end end)
local function setEntry(e,valueFn)
    if not e.obj or not e.obj.Parent then return end
    pcall(function()
        if e.kind=="Value" then e.obj.Value=valueFn(e.obj.Value) else e.obj:SetAttribute(e.name,valueFn(e.obj:GetAttribute(e.name))) end
    end)
end

removeOption("Infinite Ammo")
removeOption("Fast Reload")
removeOption("No Recoil")
local infiniteEnabled=false
local fastReloadEnabled=false
local noRecoilEnabled=false
Combat.CreateOptionsButton({["Name"]="Infinite Ammo",["Function"]=function(v) infiniteEnabled=v end,["HoverText"]="Keeps local ammo-like values filled when the weapon exposes them client-side."})
Combat.CreateOptionsButton({["Name"]="Fast Reload",["Function"]=function(v) fastReloadEnabled=v end,["HoverText"]="Reduces local reload-time values when exposed by the weapon."})
Combat.CreateOptionsButton({["Name"]="No Recoil",["Function"]=function(v) noRecoilEnabled=v end,["HoverText"]="Dampens local camera recoil while firing."})

local modClock=0
RunService.Heartbeat:Connect(function(dt)
    modClock+=dt
    if modClock<.10 then return end
    modClock=0
    if infiniteEnabled then for _,e in ipairs(cachedAmmo) do setEntry(e,function(v) return type(v)=="number" and math.max(v,999) or v end) end end
    if fastReloadEnabled then for _,e in ipairs(cachedReload) do setEntry(e,function(v) return type(v)=="number" and math.min(v,.05) or v end) end end
end)

local lastStableCF=nil
RunService:BindToRenderStep("YokaiOwnerBotNoRecoilV1",Enum.RenderPriority.Camera.Value+30,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local firing=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if not noRecoilEnabled or not firing then lastStableCF=cam.CFrame return end
    if lastStableCF then
        cam.CFrame=lastStableCF:Lerp(cam.CFrame,.12)
    end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Executor bot-training profile loaded",3) end)
