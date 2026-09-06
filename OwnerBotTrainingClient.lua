-- CLIENT-SIDE owner training controls for experiences that install OwnerBotTrainingServer.lua.
-- Only operates when the server bridge explicitly authorizes this player.
-- Targets NPC Humanoids only; Player characters are always excluded.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local folder = ReplicatedStorage:FindFirstChild("YokaiOwnerTraining")
if not folder then return end
local Action = folder:FindFirstChild("Action")
local Status = folder:FindFirstChild("Status")
if not Action or not Status then return end

local ok, info = pcall(function() return Status:InvokeServer() end)
if not ok or type(info) ~= "table" or info.Authorized ~= true then return end

local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local Combat = CombatRec and CombatRec.Api
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
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then table.insert(keys,key) end
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
    local nextSet={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then nextSet[obj]=true end
    end
    bots=nextSet
end
rescanBots()
task.spawn(function()
    while folder.Parent do task.wait(.5) rescanBots() end
end)

local function aimPart(model,name)
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function predicted(part,model,enabled,strength)
    if not enabled then return part.Position end
    local root=rootOf(model)
    if not root then return part.Position end
    return part.Position + root.AssemblyLinearVelocity * math.clamp(strength,0,2) * .055
end
local function nearestBot(fov,partName,prediction,strength,maxDistance)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPos,bestPx=nil,nil,nil,fov
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,partName)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude <= maxDistance then
                local pos=predicted(part,model,prediction,strength)
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

-- Simple precise owner-only bot aimbot.
removeOption(CombatRec,"Aimbot")
pcall(function() RunService:UnbindFromRenderStep("YokaiOwnerTrainingAimbot") end)
local aimEnabled=false
local aimFov=320
local aimPartName="Head"
local aimPrediction=true
local aimPredictionStrength=1
local aimDistance=1500
local aimActivation="Mouse2"
local Aimbot=Combat.CreateOptionsButton({
    ["Name"]="Aimbot",
    ["Function"]=function(v) aimEnabled=v end,
    ["HoverText"]="Owner training mode: precise NPC-only aim assist.",
})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=50,["Max"]=900,["Default"]=320,["Function"]=function(v) aimFov=v end})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateDropdown({["Name"]="Activation",["List"]={"Mouse2","Always"},["Function"]=function(v) aimActivation=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Prediction",["Min"]=0,["Max"]=200,["Default"]=100,["Function"]=function(v) aimPredictionStrength=v/100 end})
Aimbot.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=1500,["Function"]=function(v) aimDistance=v end})

RunService:BindToRenderStep("YokaiOwnerTrainingAimbot",Enum.RenderPriority.Camera.Value+20,function()
    if not aimEnabled then return end
    if aimActivation=="Mouse2" and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local _,_,pos=nearestBot(aimFov,aimPartName,aimPrediction,aimPredictionStrength,aimDistance)
    if pos then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,pos) end
end)

-- Magic Bullets: server-authorized NPC damage only.
removeOption(CombatRec,"Magic Bullets")
local magicEnabled=false
local magicPart="Head"
local magicFov=650
local magicPrediction=true
local magicPredictionStrength=1
local magicDistance=1800
local Magic=Combat.CreateOptionsButton({
    ["Name"]="Magic Bullets",
    ["Function"]=function(v) magicEnabled=v Action:FireServer("SetMagic",v) end,
    ["HoverText"]="Owner training mode: redirects confirmed test shots to NPCs only.",
})
Magic.CreateDropdown({["Name"]="Target",["List"]={"Head","Torso"},["Function"]=function(v) magicPart=v end})
Magic.CreateSlider({["Name"]="FOV",["Min"]=100,["Max"]=1500,["Default"]=650,["Function"]=function(v) magicFov=v end})
Magic.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) magicPrediction=v end})
Magic.CreateSlider({["Name"]="Prediction",["Min"]=0,["Max"]=200,["Default"]=100,["Function"]=function(v) magicPredictionStrength=v/100 end})
Magic.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) magicDistance=v end})

UserInputService.InputBegan:Connect(function(input,gp)
    if gp or not magicEnabled or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local model,part=nearestBot(magicFov,magicPart,magicPrediction,magicPredictionStrength,magicDistance)
    if model and part then Action:FireServer("MagicHit",model,magicPart) end
end)

-- Server-side developer weapon modifiers.
removeOption(CombatRec,"No Recoil")
removeOption(CombatRec,"Fast Reload")
removeOption(CombatRec,"Infinite Ammo")
Combat.CreateOptionsButton({
    ["Name"]="No Recoil",
    ["Function"]=function(v) Action:FireServer("SetNoRecoil",v) end,
    ["HoverText"]="Owner training mode: zeros common recoil/view-kick values on equipped tools.",
})
Combat.CreateOptionsButton({
    ["Name"]="Fast Reload",
    ["Function"]=function(v) Action:FireServer("SetFastReload",v) end,
    ["HoverText"]="Owner training mode: shortens common reload timers on equipped tools.",
})
Combat.CreateOptionsButton({
    ["Name"]="Infinite Ammo",
    ["Function"]=function(v) Action:FireServer("SetInfiniteAmmo",v) end,
    ["HoverText"]="Owner training mode: keeps common ammo/magazine values full.",
})

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Owner bot training controls authorized",4) end)
