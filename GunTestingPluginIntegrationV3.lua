-- Gun Testing V3: uses the game's public local GunPlugin API for bot-only aim helpers
-- and exact CurrentWeapon viewmodel styling. Player characters are always excluded.
-- No RemoteEvent firing, anti-cheat bypass, or ban-evasion.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local VisualsRec = objects["VisualsWindow"]
local Combat = CombatRec and CombatRec.Api
local Visuals = VisualsRec and VisualsRec.Api
if not Combat or not Visuals then return end

local gunController = LocalPlayer:WaitForChild("PlayerScripts", 10) and LocalPlayer.PlayerScripts:WaitForChild("GunController", 10)
local events = gunController and gunController:WaitForChild("Events", 10)
local gunPluginModule = events and events:WaitForChild("GunPlugin", 10)
local GunPlugin
if gunPluginModule and gunPluginModule:IsA("ModuleScript") then
    local ok, result = pcall(require, gunPluginModule)
    if ok and type(result) == "table" then GunPlugin = result end
end
if not GunPlugin then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
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

-- ============================================================================
-- Bot discovery
-- ============================================================================
local bots={}
local function playerOwned(model)
    if not model then return true end
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
    local root=rootOf(model)
    return hum~=nil and root~=nil and hum.Health>0
end
local function rescanBots()
    local t={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then t[obj]=true end
    end
    bots=t
end
rescanBots()
task.spawn(function()
    while shared.YokaiExecuted ~= false do task.wait(.45) rescanBots() end
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
local function pluginAimed()
    local ok,v=pcall(function() return GunPlugin:IsAimed() end)
    return ok and v==true
end
local function referencePoint()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    -- Gun Testing locks ADS to screen center. Using mouse position while aimed was
    -- the reason the previous aimbot selected the wrong candidate during ADS.
    if pluginAimed() or UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter then
        return cam.ViewportSize/2
    end
    local m=UserInputService:GetMouseLocation()
    return Vector2.new(m.X,m.Y)
end
local function predictedPosition(model,part,enabled,bulletSpeed,strength)
    if not enabled then return part.Position end
    local cam=Workspace.CurrentCamera
    local root=rootOf(model)
    if not cam or not root then return part.Position end
    local dist=(cam.CFrame.Position-part.Position).Magnitude
    local lead=math.clamp(dist/math.max(100,bulletSpeed),0,.35)*(strength or 1)
    return part.Position + root.AssemblyLinearVelocity*lead
end
local function nearestBot(fov,maxStuds,partName,wallCheck,prediction,bulletSpeed,predictionStrength,current)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local ref=referencePoint()
    local function score(model)
        if not isBot(model) then return nil end
        local root=rootOf(model)
        local part=aimPart(model,partName)
        if not root or not part then return nil end
        if (cam.CFrame.Position-root.Position).Magnitude>(maxStuds or math.huge) then return nil end
        if wallCheck and not visible(model,part) then return nil end
        local pos=predictedPosition(model,part,prediction,bulletSpeed,predictionStrength)
        local p,on=cam:WorldToViewportPoint(pos)
        if not on or p.Z<=0 then return nil end
        local px=(Vector2.new(p.X,p.Y)-ref).Magnitude
        if px>(fov or math.huge) then return nil end
        return px,part,pos
    end
    if current then
        local px,part,pos=score(current)
        if px and px<=(fov or math.huge)*1.35 then return current,part,pos,px end
    end
    local best,bestPart,bestPos,bestPx=nil,nil,nil,fov or math.huge
    for model in pairs(bots) do
        local px,part,pos=score(model)
        if px and px<bestPx then best,bestPart,bestPos,bestPx=model,part,pos,px end
    end
    return best,bestPart,bestPos,bestPx
end

-- ============================================================================
-- Aimbot: bot-only, ADS aware, stronger lock + prediction
-- ============================================================================
removeOption(CombatRec,"Aimbot")
for _,bind in ipairs({"YokaiBotAimbot","YokaiGunTestingAimbotV2","YokaiGunTestingAimbotV3"}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end

local aimEnabled=false
local aimFov=520
local aimAggression=94
local aimPartName="Head"
local aimWall=true
local aimActivation="Mouse2"
local aimPrediction=true
local aimBulletSpeed=1400
local aimPredictionStrength=1
local aimDistance=2200
local aimSticky=true
local lockedTarget=nil

local Aimbot=Combat.CreateOptionsButton({["Name"]="Aimbot",["Function"]=function(v) aimEnabled=v if not v then lockedTarget=nil end end,["HoverText"]="Gun Testing bots only; ADS-aware target reference."})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=1200,["Default"]=520,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Aggressiveness",["Min"]=1,["Max"]=100,["Default"]=94,["Function"]=function(v) aimAggression=v end})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v lockedTarget=nil end})
Aimbot.CreateDropdown({["Name"]="Activation",["List"]={"Mouse2","Mouse1","Always"},["Function"]=function(v) aimActivation=v end})
Aimbot.CreateToggle({["Name"]="Sticky Target",["Default"]=true,["Function"]=function(v) aimSticky=v if not v then lockedTarget=nil end end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Prediction Speed",["Min"]=300,["Max"]=4000,["Default"]=1400,["Function"]=function(v) aimBulletSpeed=v end})
Aimbot.CreateSlider({["Name"]="Prediction Strength",["Min"]=25,["Max"]=200,["Default"]=100,["Function"]=function(v) aimPredictionStrength=v/100 end})
Aimbot.CreateSlider({["Name"]="Max Distance",["Min"]=100,["Max"]=4000,["Default"]=2200,["Function"]=function(v) aimDistance=v end})

local function activationDown()
    if aimActivation=="Always" then return true end
    if aimActivation=="Mouse1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end
RunService:BindToRenderStep("YokaiGunTestingAimbotV3",Enum.RenderPriority.Last.Value+500,function(dt)
    if not aimEnabled or not activationDown() then lockedTarget=nil return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local model,part,pos=nearestBot(aimFov,aimDistance,aimPartName,aimWall,aimPrediction,aimBulletSpeed,aimPredictionStrength,aimSticky and lockedTarget or nil)
    if not model or not pos then lockedTarget=nil return end
    if aimSticky then lockedTarget=model end
    shared.YokaiGunTestingLastAimPart={Part=part and part.Name or aimPartName,At=os.clock(),Model=model}
    local desired=CFrame.lookAt(cam.CFrame.Position,pos)
    local alpha=math.clamp((aimAggression/100)*math.max(1,dt*75),.03,1)
    if pluginAimed() then alpha=math.min(1,alpha*1.18) end
    if aimAggression>=98 then alpha=1 end
    cam.CFrame=cam.CFrame:Lerp(desired,alpha)
end)

-- ============================================================================
-- SilentAim + Magic Bullets using GunPlugin:GetWorldLookAtPos override.
-- This only changes the local aim point returned to the game's gun code and can
-- only select non-player Humanoid bots from the selector above.
-- ============================================================================
removeOption(CombatRec,"SilentAim")
removeOption(CombatRec,"Magic Bullets")
local silentEnabled=false
local silentFov=600
local silentPartName="Head"
local silentWall=true
local silentPrediction=true
local silentBulletSpeed=1400
local silentPredictionStrength=1
local silentDistance=2200
local magicEnabled=false
local magicPartName="Head"
local magicWall=true
local magicPrediction=true
local magicBulletSpeed=1400
local magicPredictionStrength=1
local magicDistance=2600

local SilentAim=Combat.CreateOptionsButton({["Name"]="SilentAim",["Function"]=function(v) silentEnabled=v end,["HoverText"]="Bots only. Overrides GunPlugin world aim point when the game asks for it."})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=1600,["Default"]=600,["Function"]=function(v) silentFov=v end})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPartName=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWall=v end})
SilentAim.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) silentPrediction=v end})
SilentAim.CreateSlider({["Name"]="Prediction Speed",["Min"]=300,["Max"]=4000,["Default"]=1400,["Function"]=function(v) silentBulletSpeed=v end})
SilentAim.CreateSlider({["Name"]="Prediction Strength",["Min"]=25,["Max"]=200,["Default"]=100,["Function"]=function(v) silentPredictionStrength=v/100 end})

local Magic=Combat.CreateOptionsButton({["Name"]="Magic Bullets",["Function"]=function(v) magicEnabled=v end,["HoverText"]="Bots only. Uses a wider target search through the game's local world-look API."})
Magic.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) magicPartName=v end})
Magic.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) magicWall=v end})
Magic.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) magicPrediction=v end})
Magic.CreateSlider({["Name"]="Prediction Speed",["Min"]=300,["Max"]=4000,["Default"]=1400,["Function"]=function(v) magicBulletSpeed=v end})
Magic.CreateSlider({["Name"]="Prediction Strength",["Min"]=25,["Max"]=200,["Default"]=100,["Function"]=function(v) magicPredictionStrength=v/100 end})
Magic.CreateSlider({["Name"]="Max Distance",["Min"]=100,["Max"]=4000,["Default"]=2600,["Function"]=function(v) magicDistance=v end})

if not shared.YokaiGunTestingOriginalGetWorldLookAtPos then
    shared.YokaiGunTestingOriginalGetWorldLookAtPos=GunPlugin.GetWorldLookAtPos
end
local originalGetWorldLookAtPos=shared.YokaiGunTestingOriginalGetWorldLookAtPos
GunPlugin.GetWorldLookAtPos=function(self,...)
    if magicEnabled then
        local model,part,pos=nearestBot(5000,magicDistance,magicPartName,magicWall,magicPrediction,magicBulletSpeed,magicPredictionStrength,nil)
        if model and pos then
            shared.YokaiGunTestingLastAimPart={Part=part and part.Name or magicPartName,At=os.clock(),Model=model}
            return pos
        end
    elseif silentEnabled then
        local model,part,pos=nearestBot(silentFov,silentDistance,silentPartName,silentWall,silentPrediction,silentBulletSpeed,silentPredictionStrength,nil)
        if model and pos then
            shared.YokaiGunTestingLastAimPart={Part=part and part.Name or silentPartName,At=os.clock(),Model=model}
            return pos
        end
    end
    return originalGetWorldLookAtPos(self,...)
end

-- ============================================================================
-- Exact Gun Testing viewmodel structure:
-- CurrentCamera.CurrentWeapon -> Weapon, LeftArm, RightArm
-- GunPlugin:GetGunViewModel() is preferred; CurrentWeapon is the confirmed fallback.
-- ============================================================================
removeOption(VisualsRec,"SelfChams")
removeOption(VisualsRec,"GunChams")
for _,bind in ipairs({"YokaiUniversalArmChams","YokaiGunChamsExact","YokaiGunTestingViewmodelV2","YokaiGunTestingViewmodelV3"}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end

local materialMap={ForceField=Enum.Material.ForceField,Neon=Enum.Material.Neon,SmoothPlastic=Enum.Material.SmoothPlastic,Glass=Enum.Material.Glass,Foil=Enum.Material.Foil,Metal=Enum.Material.Metal,Plastic=Enum.Material.Plastic}
local materialList={"ForceField","Neon","SmoothPlastic","Glass","Foil","Metal","Plastic"}
local function currentWeaponRoot()
    local ok,vm=pcall(function() return GunPlugin:GetGunViewModel() end)
    if ok and typeof(vm)=="Instance" and vm.Parent then return vm end
    local cam=Workspace.CurrentCamera
    return cam and (cam:FindFirstChild("CurrentWeapon") or cam:FindFirstChild("Rig")) or nil
end
local function armRoots(root)
    if not root then return {} end
    local t={}
    for _,name in ipairs({"LeftArm","RightArm","Left Arm","Right Arm"}) do
        local x=root:FindFirstChild(name,true)
        if x then t[x]=true end
    end
    return t
end
local function weaponRoot(root)
    if not root then return nil end
    return root:FindFirstChild("Weapon") or root:FindFirstChild("Gun") or root
end
local function descendantOfAny(obj,set)
    for root in pairs(set) do if obj==root or obj:IsDescendantOf(root) then return true end end
    return false
end
local function visiblePart(p)
    return p:IsA("BasePart") and p.Transparency<.98 and p.LocalTransparencyModifier<.98 and p.Size.Magnitude>.06
end
local function remember(store,p)
    if store[p] then return end
    store[p]={Material=p.Material,Color=p.Color,Transparency=p.Transparency,CastShadow=p.CastShadow,Reflectance=p.Reflectance}
end
local function restoreOne(store,highlights,p)
    local st=store[p]
    if st and p and p.Parent then pcall(function() p.Material=st.Material p.Color=st.Color p.Transparency=st.Transparency p.CastShadow=st.CastShadow p.Reflectance=st.Reflectance end) end
    store[p]=nil
    local hi=highlights[p]
    if hi and hi.Parent then hi:Destroy() end
    highlights[p]=nil
end
local function restoreAll(store,highlights)
    local list={}
    for p in pairs(store) do table.insert(list,p) end
    for _,p in ipairs(list) do restoreOne(store,highlights,p) end
end
local function style(store,highlights,p,material,color,transparency,glow)
    remember(store,p)
    p.Material=materialMap[material] or Enum.Material.ForceField
    p.Color=color
    p.Transparency=math.clamp(transparency,0,.9)
    p.CastShadow=false
    p.Reflectance=0
    local hi=highlights[p]
    if not hi or not hi.Parent then
        hi=Instance.new("Highlight")
        hi.Name="YokaiGunTestingViewmodelChams"
        hi.Adornee=p
        hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hi.Parent=p
        highlights[p]=hi
    end
    hi.FillColor=color hi.OutlineColor=color
    hi.FillTransparency=glow and .76 or 1
    hi.OutlineTransparency=glow and .08 or 1
    hi.Enabled=glow
end

local selfEnabled=false
local selfMaterial="ForceField"
local selfColor=Color3.fromRGB(119,120,255)
local selfTransparency=0
local selfGlow=true
local selfStore=setmetatable({}, {__mode="k"})
local selfHighlights=setmetatable({}, {__mode="k"})
local SelfChams=Visuals.CreateOptionsButton({["Name"]="SelfChams",["Function"]=function(v) selfEnabled=v if not v then restoreAll(selfStore,selfHighlights) end end})
SelfChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) selfMaterial=v end})
SelfChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) selfColor=Color3.fromHSV(h,s,v) end})
SelfChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=80,["Default"]=0,["Function"]=function(v) selfTransparency=v/100 end})
SelfChams.CreateToggle({["Name"]="Glow",["Default"]=true,["Function"]=function(v) selfGlow=v end})

local gunEnabled=false
local gunMaterial="ForceField"
local gunColor=Color3.fromRGB(45,110,255)
local gunTransparency=0
local gunGlow=true
local gunStore=setmetatable({}, {__mode="k"})
local gunHighlights=setmetatable({}, {__mode="k"})
local GunChams=Visuals.CreateOptionsButton({["Name"]="GunChams",["Function"]=function(v) gunEnabled=v if not v then restoreAll(gunStore,gunHighlights) end end})
GunChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) gunMaterial=v end})
GunChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) gunColor=Color3.fromHSV(h,s,v) end})
GunChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=80,["Default"]=0,["Function"]=function(v) gunTransparency=v/100 end})
GunChams.CreateToggle({["Name"]="Glow",["Default"]=true,["Function"]=function(v) gunGlow=v end})

RunService:BindToRenderStep("YokaiGunTestingViewmodelV3",Enum.RenderPriority.Last.Value+520,function()
    local root=currentWeaponRoot()
    local arms=armRoots(root)
    local gun=weaponRoot(root)
    local wantSelf,wantGun={},{}
    if root then
        for _,obj in ipairs(root:GetDescendants()) do
            if visiblePart(obj) then
                if descendantOfAny(obj,arms) then
                    wantSelf[obj]=true
                elseif gun and (obj==gun or obj:IsDescendantOf(gun)) then
                    wantGun[obj]=true
                end
            end
        end
    end
    local stale={}
    for p in pairs(selfStore) do if not selfEnabled or not wantSelf[p] then table.insert(stale,p) end end
    for _,p in ipairs(stale) do restoreOne(selfStore,selfHighlights,p) end
    stale={}
    for p in pairs(gunStore) do if not gunEnabled or not wantGun[p] then table.insert(stale,p) end end
    for _,p in ipairs(stale) do restoreOne(gunStore,gunHighlights,p) end
    if selfEnabled then for p in pairs(wantSelf) do style(selfStore,selfHighlights,p,selfMaterial,selfColor,selfTransparency,selfGlow) end end
    if gunEnabled then for p in pairs(wantGun) do style(gunStore,gunHighlights,p,gunMaterial,gunColor,gunTransparency,gunGlow) end end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Gun Testing V3: GunPlugin ADS + bot aim + exact CurrentWeapon chams",3) end)
