-- Unified NPC/bot practice runtime for the owner's bot-only testing experience.
-- Final-layer replacement to avoid legacy modules fighting each other.
-- No __namecall/metamethod hooks, no Kick interception, and Player characters are excluded.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local RenderRec = objects["RenderWindow"]
local VisualsRec = objects["VisualsWindow"]
local UtilityRec = objects["UtilityWindow"]
local WorldRec = objects["WorldWindow"]
local Combat = CombatRec and CombatRec.Api
local Render = RenderRec and RenderRec.Api
local Visuals = VisualsRec and VisualsRec.Api
local Utility = UtilityRec and UtilityRec.Api
local World = WorldRec and WorldRec.Api
if not (Combat and Render and Visuals and Utility and World) then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function under(rec, parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object, parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function removeOption(parentRec, name)
    local keys = {}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and under(rec,parentRec) then
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
local function notify(title,text,dur)
    pcall(function() GuiLibrary["CreateNotification"](title,text,dur or 3) end)
end

-- Kill stale bindings/connections created by prior experimental layers where possible.
for _,name in ipairs({
    "YokaiOwnerBotAimbotV1","YokaiGunTestingAimbotV3","YokaiGunTestingAimbotV2",
    "YokaiOwnerBotNoRecoilV1","YokaiGunTestingNoRecoil","YokaiBotSilentAim",
    "YokaiGunTestingSilentAim","YokaiGunTestingSilentAimV2","YokaiGunTestingSilentAimV3",
    "YokaiFOVChangerLock","YokaiLocalFOVLock"
}) do pcall(function() RunService:UnbindFromRenderStep(name) end) end
pcall(function() ContextActionService:UnbindAction("YokaiBotSilentAimV2") end)

-- Remove conflicting legacy controls; these are recreated below for NPCs only.
for _,name in ipairs({"Aimbot","SilentAim","Magic Bullets","HitBoxes","No Recoil","Fast Reload","Infinite Ammo"}) do
    removeOption(CombatRec,name)
end
for _,name in ipairs({"ESP","Chams","Corner Box","Thermal Corner","HealthBar","Name + Distance","Skeleton","Tracers","Distance","FOVChanger"}) do
    removeOption(VisualsRec,name)
end
removeOption(RenderRec,"Arrows")
for _,name in ipairs({"HitSound","HitSoundPreview","HitMarker"}) do removeOption(WorldRec,name) end
removeOption(UtilityRec,"Inventory Viewer")
removeOption(VisualsRec,"Car ESP")

-- ==========================================================================
-- BOT REGISTRY
-- ==========================================================================
local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function humanoidOf(model)
    return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") or nil
end
local function rootOf(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local hum=humanoidOf(model)
    local root=rootOf(model)
    return hum~=nil and root~=nil and hum.Health>0
end
local bots={}
local botHumConns={}
local botRoot = Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots") or Workspace

local lastShotAt=0
local lastShotBot=nil
local lastShotPart=nil
local lastAimBot=nil
local lastAimPartName="Head"

-- ==========================================================================
-- OVERLAY / HIT UI
-- ==========================================================================
for _,root in ipairs({CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui")}) do
    if root then
        for _,name in ipairs({"YokaiOwnerBotOverlayV2","YokaiBotHitMarkerV2","YokaiBotInventoryV2"}) do
            local old=root:FindFirstChild(name)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end
local parentGui=(gethui and gethui()) or CoreGui
local Overlay=Instance.new("ScreenGui")
Overlay.Name="YokaiOwnerBotOverlayV2"
Overlay.ResetOnSpawn=false
Overlay.IgnoreGuiInset=true
Overlay.DisplayOrder=996
Overlay.Parent=parentGui

local function frame(parent)
    local f=Instance.new("Frame")
    f.BorderSizePixel=0
    f.BackgroundColor3=Color3.new(1,1,1)
    f.Visible=false
    f.Parent=parent
    return f
end
local function setLine(line,a,b,thickness,color,trans)
    local d=b-a
    local len=d.Magnitude
    line.AnchorPoint=Vector2.new(.5,.5)
    line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Size=UDim2.fromOffset(len,thickness or 1)
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3=color
    line.BackgroundTransparency=trans or 0
    line.Visible=true
end
local function hidePack(pack)
    if not pack then return end
    for _,obj in pairs(pack) do
        if typeof(obj)=="Instance" and obj:IsA("GuiObject") then obj.Visible=false end
        if type(obj)=="table" then for _,x in pairs(obj) do if typeof(x)=="Instance" and x:IsA("GuiObject") then x.Visible=false end end end
    end
end

local HitGui=Instance.new("ScreenGui")
HitGui.Name="YokaiBotHitMarkerV2"
HitGui.ResetOnSpawn=false
HitGui.IgnoreGuiInset=true
HitGui.DisplayOrder=1001
HitGui.Parent=parentGui
local hitLines={frame(HitGui),frame(HitGui),frame(HitGui),frame(HitGui)}
local hitSound=Instance.new("Sound")
hitSound.Name="YokaiBotHitSoundV2"
hitSound.SoundId="rbxassetid://91546829095879"
hitSound.Volume=.7
hitSound.Parent=SoundService
local hitMarkerEnabled=true
local hitSoundEnabled=true
local hitToken=0
local function showHit(partName,damage)
    if hitSoundEnabled then pcall(function() hitSound.TimePosition=0 hitSound:Play() end) end
    if hitMarkerEnabled then
        local cam=Workspace.CurrentCamera
        if cam then
            local c=cam.ViewportSize/2
            local col=partName=="Head" and Color3.fromRGB(255,210,90) or Color3.new(1,1,1)
            local pts={
                {c+Vector2.new(-18,-18),c+Vector2.new(-7,-7)},
                {c+Vector2.new(18,-18),c+Vector2.new(7,-7)},
                {c+Vector2.new(-18,18),c+Vector2.new(-7,7)},
                {c+Vector2.new(18,18),c+Vector2.new(7,7)},
            }
            for i,p in ipairs(pts) do setLine(hitLines[i],p[1],p[2],2,col,0) end
            hitToken+=1 local tk=hitToken
            task.delay(.16,function() if tk==hitToken then for _,l in ipairs(hitLines) do l.Visible=false end end end)
        end
    end
    notify("Hit",string.format("%s  •  -%d HP",partName or "Body",math.max(0,math.floor(damage+.5))),2)
end

local function partLabel(part)
    if not part then return "Body" end
    local n=part.Name:lower()
    if n:find("head",1,true) then return "Head" end
    if n:find("arm",1,true) or n:find("hand",1,true) then return n:find("left",1,true) and "Left Arm" or (n:find("right",1,true) and "Right Arm" or "Arm") end
    if n:find("leg",1,true) or n:find("foot",1,true) then return n:find("left",1,true) and "Left Leg" or (n:find("right",1,true) and "Right Leg" or "Leg") end
    return "Body"
end

local function connectBotHum(model)
    if botHumConns[model] then return end
    local hum=humanoidOf(model)
    if not hum then return end
    local prev=hum.Health
    botHumConns[model]=hum.HealthChanged:Connect(function(v)
        if v<prev and os.clock()-lastShotAt<.65 then
            local okTarget=(lastShotBot==nil or lastShotBot==model or lastAimBot==model)
            if okTarget then
                local label=(lastShotBot==model and partLabel(lastShotPart)) or lastAimPartName or "Body"
                showHit(label,prev-v)
            end
        end
        prev=v
    end)
end
local function registerBot(model)
    if isBot(model) then bots[model]=true connectBotHum(model) end
end
local function unregisterBot(model)
    bots[model]=nil
    local c=botHumConns[model]
    if c then c:Disconnect() botHumConns[model]=nil end
end
local function seedBots()
    bots={}
    local scanRoot=botRoot and botRoot.Parent and botRoot or Workspace
    for _,d in ipairs(scanRoot:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerBot(d.Parent) end
    end
end
seedBots()
botRoot.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerBot,d.Parent) end
end)
botRoot.DescendantRemoving:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(unregisterBot,d.Parent) end
end)

local function aimPart(model,name)
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function visibleFromCamera(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local filter={cam}
    if LocalPlayer.Character then table.insert(filter,LocalPlayer.Character) end
    rp.FilterDescendantsInstances=filter
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function predictedPos(model,part,enabled)
    if not enabled then return part.Position end
    local cam=Workspace.CurrentCamera
    local root=rootOf(model)
    if not cam or not root then return part.Position end
    local distance=(root.Position-cam.CFrame.Position).Magnitude
    local lead=math.clamp(distance/2500,0,.35)
    return part.Position + root.AssemblyLinearVelocity*lead
end
local function nearestBot(fov,partName,wall,prediction,maxDistance)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPos,bestPx=nil,nil,nil,fov
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,partName)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=maxDistance and (not wall or visibleFromCamera(model,part)) then
                local pos=predictedPos(model,part,prediction)
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

-- ==========================================================================
-- COMBAT: BOT-ONLY
-- ==========================================================================
local aimEnabled=false
local aimPartName="Head"
local aimFov=320
local aimSmooth=.88
local aimWall=true
local aimPrediction=true
local aimDistance=1800
local Aimbot=Combat.CreateOptionsButton({["Name"]="Aimbot",["Function"]=function(v) aimEnabled=v end,["HoverText"]="Precise NPC-only aim assist. Hold Mouse2."})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=900,["Default"]=320,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Precision",["Min"]=10,["Max"]=100,["Default"]=88,["Function"]=function(v) aimSmooth=v/100 end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) aimDistance=v end})
RunService:BindToRenderStep("YokaiOwnerBotV2Aimbot",Enum.RenderPriority.Camera.Value+60,function(dt)
    if not aimEnabled or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then lastAimBot=nil return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local model,part,pos=nearestBot(aimFov,aimPartName,aimWall,aimPrediction,aimDistance)
    lastAimBot=model lastAimPartName=aimPartName
    if model and pos then
        local goal=CFrame.lookAt(cam.CFrame.Position,pos)
        local alpha=math.clamp(aimSmooth*math.max(1,dt*60),.08,1)
        cam.CFrame=cam.CFrame:Lerp(goal,alpha)
    end
end)

-- Hook-free bot-only SilentAim: a brief camera redirect through ContextActionService.
-- This does not alter __namecall/metamethods. It works only with guns that sample camera direction on click.
local silentEnabled=false
local silentPart="Head"
local silentFov=520
local silentWall=true
local silentPrediction=true
local silentDistance=2000
local function silentAction(_,state,input)
    if state~=Enum.UserInputState.Begin or not silentEnabled then return Enum.ContextActionResult.Pass end
    local cam=Workspace.CurrentCamera
    if not cam then return Enum.ContextActionResult.Pass end
    local model,part,pos=nearestBot(silentFov,silentPart,silentWall,silentPrediction,silentDistance)
    if model and part and pos then
        lastAimBot=model lastAimPartName=silentPart
        local before=cam.CFrame
        cam.CFrame=CFrame.lookAt(before.Position,pos)
        task.defer(function()
            RunService.RenderStepped:Wait()
            if cam and cam.Parent then cam.CFrame=before end
        end)
    end
    return Enum.ContextActionResult.Pass
end
local SilentAim=Combat.CreateOptionsButton({["Name"]="SilentAim",["Function"]=function(v)
    silentEnabled=v
    pcall(function() ContextActionService:UnbindAction("YokaiBotSilentAimV2") end)
    if v then ContextActionService:BindActionAtPriority("YokaiBotSilentAimV2",silentAction,false,Enum.ContextActionPriority.High.Value+100,Enum.UserInputType.MouseButton1) end
end,["HoverText"]="NPC-only, hook-free shot direction assist."})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPart=v end})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=60,["Max"]=1200,["Default"]=520,["Function"]=function(v) silentFov=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWall=v end})
SilentAim.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) silentPrediction=v end})
SilentAim.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=2000,["Function"]=function(v) silentDistance=v end})

-- Local enlarged NPC parts. Whether a server accepts the enlarged area depends on the game's own hit validation.
local hitboxEnabled=false
local hitboxPartName="Head"
local hitboxSize=4
local hitboxTransparency=.75
local hitboxOriginal=setmetatable({}, {__mode="k"})
local function restoreHitboxes()
    for p,s in pairs(hitboxOriginal) do if p and p.Parent then pcall(function() p.Size=s.Size p.Transparency=s.Transparency p.CanCollide=s.CanCollide end) end end
    hitboxOriginal=setmetatable({}, {__mode="k"})
end
local HitBoxes=Combat.CreateOptionsButton({["Name"]="HitBoxes",["Function"]=function(v) hitboxEnabled=v if not v then restoreHitboxes() end end,["HoverText"]="Locally enlarges NPC Head/Torso for client-side raycast practice."})
HitBoxes.CreateDropdown({["Name"]="Part",["List"]={"Head","Torso"},["Function"]=function(v) hitboxPartName=v end})
HitBoxes.CreateSlider({["Name"]="Size",["Min"]=2,["Max"]=10,["Default"]=4,["Function"]=function(v) hitboxSize=v end})
HitBoxes.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=100,["Default"]=75,["Function"]=function(v) hitboxTransparency=v/100 end})

-- Generic local recoil stabilizer; does not hook weapon remotes.
local noRecoil=false
local recoilStrength=.92
local stableCF=nil
local NoRecoil=Combat.CreateOptionsButton({["Name"]="No Recoil",["Function"]=function(v) noRecoil=v stableCF=nil end})
NoRecoil.CreateSlider({["Name"]="Strength",["Min"]=10,["Max"]=100,["Default"]=92,["Function"]=function(v) recoilStrength=v/100 end})
RunService:BindToRenderStep("YokaiOwnerBotNoRecoilV2",Enum.RenderPriority.Camera.Value+90,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local firing=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if not noRecoil or not firing then stableCF=cam.CFrame return end
    if stableCF then
        local wanted=CFrame.new(cam.CFrame.Position)*stableCF.Rotation
        cam.CFrame=cam.CFrame:Lerp(wanted,recoilStrength)
        stableCF=stableCF:Lerp(cam.CFrame,.045)
    else stableCF=cam.CFrame end
end)

-- Generic weapon field indexer: Character/Backpack/PlayerGui/CurrentCamera/WeaponSystem_Workspace.
local ammoEntries={}
local reloadEntries={}
local entrySeen=setmetatable({}, {__mode="k"})
local ammoWords={"ammo","magazine","clip","bullet","reserve","round"}
local reloadWords={"reloadtime","reloadduration","reloaddelay","reloadspeed","reload"}
local weaponWords={"weapon","gun","rifle","pistol","shotgun","smg","ammo","mag","firearm"}
local function contains(name,list)
    local n=string.lower(tostring(name))
    for _,w in ipairs(list) do if n:find(w,1,true) then return true end end
    return false
end
local function weaponContext(obj)
    local cur=obj
    for _=1,5 do
        if not cur then break end
        if contains(cur.Name,weaponWords) then return true end
        cur=cur.Parent
    end
    return false
end
local function indexObject(obj)
    if entrySeen[obj] then return end
    entrySeen[obj]=true
    if obj:IsA("NumberValue") or obj:IsA("IntValue") then
        if contains(obj.Name,ammoWords) and weaponContext(obj) then table.insert(ammoEntries,{obj=obj,kind="Value"}) end
        if contains(obj.Name,reloadWords) and weaponContext(obj) then table.insert(reloadEntries,{obj=obj,kind="Value"}) end
    elseif obj:IsA("BoolValue") and contains(obj.Name,{"reloading","reload"}) and weaponContext(obj) then
        table.insert(reloadEntries,{obj=obj,kind="Bool"})
    end
    for attr,v in pairs(obj:GetAttributes()) do
        if type(v)=="number" then
            if contains(attr,ammoWords) and weaponContext(obj) then table.insert(ammoEntries,{obj=obj,kind="Attr",name=attr}) end
            if contains(attr,reloadWords) and weaponContext(obj) then table.insert(reloadEntries,{obj=obj,kind="Attr",name=attr}) end
        elseif type(v)=="boolean" and contains(attr,{"reloading","reload"}) and weaponContext(obj) then
            table.insert(reloadEntries,{obj=obj,kind="AttrBool",name=attr})
        end
    end
end
local function scanRoot(root)
    if not root then return end
    indexObject(root)
    local desc=root:GetDescendants()
    task.spawn(function()
        for i,obj in ipairs(desc) do indexObject(obj) if i%300==0 then task.wait() end end
    end)
    root.DescendantAdded:Connect(indexObject)
end
scanRoot(LocalPlayer.Character)
scanRoot(LocalPlayer:FindFirstChildOfClass("Backpack"))
scanRoot(LocalPlayer:FindFirstChild("PlayerGui"))
scanRoot(Workspace.CurrentCamera)
scanRoot(Workspace:FindFirstChild("WeaponSystem_Workspace"))
LocalPlayer.CharacterAdded:Connect(function(c) task.delay(1,function() scanRoot(c) end) end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.delay(.2,function() scanRoot(Workspace.CurrentCamera) end) end)

local infiniteAmmo=false
local fastReload=false
local function validEntry(e) return e and e.obj and e.obj.Parent~=nil end
local function setEntry(e,kind)
    if not validEntry(e) then return end
    pcall(function()
        if e.kind=="Value" then
            if kind=="ammo" then e.obj.Value=math.max(tonumber(e.obj.Value) or 0,999)
            elseif e.kind~="Bool" then e.obj.Value=math.min(tonumber(e.obj.Value) or 0,.03) end
        elseif e.kind=="Bool" then e.obj.Value=false
        elseif e.kind=="Attr" then
            local v=e.obj:GetAttribute(e.name)
            if kind=="ammo" then e.obj:SetAttribute(e.name,math.max(tonumber(v) or 0,999)) else e.obj:SetAttribute(e.name,math.min(tonumber(v) or 0,.03)) end
        elseif e.kind=="AttrBool" then e.obj:SetAttribute(e.name,false) end
    end)
end
local Infinite=Combat.CreateOptionsButton({["Name"]="Infinite Ammo",["Function"]=function(v)
    infiniteAmmo=v
    if v then notify("Infinite Ammo",string.format("%d ammo fields indexed",#ammoEntries),3) end
end})
local FastReload=Combat.CreateOptionsButton({["Name"]="Fast Reload",["Function"]=function(v)
    fastReload=v
    if v then notify("Fast Reload",string.format("%d reload fields indexed",#reloadEntries),3) end
end})
local fieldClock=0
RunService.Heartbeat:Connect(function(dt)
    fieldClock+=dt
    if fieldClock<.08 then return end
    fieldClock=0
    if infiniteAmmo then for i=#ammoEntries,1,-1 do local e=ammoEntries[i] if validEntry(e) then setEntry(e,"ammo") else table.remove(ammoEntries,i) end end end
    if fastReload then for i=#reloadEntries,1,-1 do local e=reloadEntries[i] if validEntry(e) then setEntry(e,"reload") else table.remove(reloadEntries,i) end end end
end)

-- ==========================================================================
-- VISUALS
-- ==========================================================================
local cfg={
    ESP=false, ESPColor=Color3.fromRGB(120,120,255), WallCheck=true,
    Visible=Color3.fromRGB(45,230,155), Occluded=Color3.fromRGB(205,78,78),
    Chams=false, ChamsThermal=false, Corner=false, ThermalCorner=false,
    Health=false, NameDistance=false, Skeleton=false, SkeletonColor=Color3.new(1,1,1), SkeletonTrans=.15, SkeletonThickness=1,
    Tracers=false, TracerColor=Color3.new(1,1,1), Distance=1800,
}
local packs={}
local function newPack(model)
    local p={}
    p.fill=frame(Overlay); p.fill.BackgroundTransparency=.86
    p.borders={frame(Overlay),frame(Overlay),frame(Overlay),frame(Overlay)}
    p.corners={} for i=1,8 do p.corners[i]=frame(Overlay) end
    p.thermal=frame(Overlay); p.thermal.BackgroundTransparency=.45
    p.gradient=Instance.new("UIGradient"); p.gradient.Color=ColorSequence.new(Color3.fromRGB(119,120,255),Color3.fromRGB(15,15,20)); p.gradient.Parent=p.thermal
    p.healthBG=frame(Overlay); p.healthBG.BackgroundColor3=Color3.fromRGB(10,10,10)
    p.health=frame(Overlay)
    p.healthGrad=Instance.new("UIGradient"); p.healthGrad.Rotation=90; p.healthGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(65,235,185)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,225,110)),ColorSequenceKeypoint.new(1,Color3.fromRGB(235,70,70))}); p.healthGrad.Parent=p.health
    p.label=Instance.new("TextLabel"); p.label.BackgroundTransparency=1; p.label.Font=Enum.Font.GothamSemibold; p.label.TextSize=12; p.label.TextColor3=Color3.new(1,1,1); p.label.TextStrokeTransparency=.35; p.label.Visible=false; p.label.Parent=Overlay
    p.skeleton={} for i=1,14 do p.skeleton[i]=frame(Overlay) end
    p.tracer=frame(Overlay)
    p.arrowA=frame(Overlay); p.arrowB=frame(Overlay)
    local hi=model:FindFirstChild("YokaiBotChamsV2")
    if hi then hi:Destroy() end
    hi=Instance.new("Highlight"); hi.Name="YokaiBotChamsV2"; hi.Adornee=model; hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hi.Enabled=false; hi.Parent=model
    p.highlight=hi
    packs[model]=p
    return p
end
local function destroyPack(model)
    local p=packs[model] if not p then return end
    for k,v in pairs(p) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in pairs(v) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end
    end
    packs[model]=nil
end
local function bounds2D(model)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local ok,cf,size=pcall(model.GetBoundingBox,model)
    if not ok then return nil end
    local hx,hy,hz=size.X/2,size.Y/2,size.Z/2
    local xs,ys={},{}
    local any=false
    for _,x in ipairs({-hx,hx}) do for _,y in ipairs({-hy,hy}) do for _,z in ipairs({-hz,hz}) do
        local w=(cf*CFrame.new(x,y,z)).Position
        local s,on=cam:WorldToViewportPoint(w)
        if s.Z>0 then table.insert(xs,s.X) table.insert(ys,s.Y) any=true end
    end end end
    if not any then return nil end
    table.sort(xs) table.sort(ys)
    local minx,maxx=xs[1],xs[#xs]
    local miny,maxy=ys[1],ys[#ys]
    return minx,miny,maxx,maxy
end
local function setRectBorder(lines,x1,y1,x2,y2,color,thick)
    setLine(lines[1],Vector2.new(x1,y1),Vector2.new(x2,y1),thick,color,0)
    setLine(lines[2],Vector2.new(x2,y1),Vector2.new(x2,y2),thick,color,0)
    setLine(lines[3],Vector2.new(x2,y2),Vector2.new(x1,y2),thick,color,0)
    setLine(lines[4],Vector2.new(x1,y2),Vector2.new(x1,y1),thick,color,0)
end
local function setCorners(lines,x1,y1,x2,y2,color,thick)
    local w,h=x2-x1,y2-y1 local cw,ch=w*.22,h*.22
    local seg={
        {Vector2.new(x1,y1),Vector2.new(x1+cw,y1)},{Vector2.new(x1,y1),Vector2.new(x1,y1+ch)},
        {Vector2.new(x2,y1),Vector2.new(x2-cw,y1)},{Vector2.new(x2,y1),Vector2.new(x2,y1+ch)},
        {Vector2.new(x1,y2),Vector2.new(x1+cw,y2)},{Vector2.new(x1,y2),Vector2.new(x1,y2-ch)},
        {Vector2.new(x2,y2),Vector2.new(x2-cw,y2)},{Vector2.new(x2,y2),Vector2.new(x2,y2-ch)},
    }
    for i,s in ipairs(seg) do setLine(lines[i],s[1],s[2],thick,color,0) end
end
local bones={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}
local bonesR6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local arrowsEnabled=false
local arrowColor=Color3.fromRGB(45,230,155)
local arrowRadius=.43
local arrowSize=12

local function hideVisualPack(p)
    p.fill.Visible=false p.thermal.Visible=false p.healthBG.Visible=false p.health.Visible=false p.label.Visible=false p.tracer.Visible=false p.highlight.Enabled=false p.arrowA.Visible=false p.arrowB.Visible=false
    for _,x in ipairs(p.borders) do x.Visible=false end for _,x in ipairs(p.corners) do x.Visible=false end for _,x in ipairs(p.skeleton) do x.Visible=false end
end

local ESP=Visuals.CreateOptionsButton({["Name"]="ESP",["Function"]=function(v) cfg.ESP=v end})
ESP.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) cfg.WallCheck=v end})
ESP.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.ESPColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) cfg.Visible=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) cfg.Occluded=Color3.fromHSV(h,s,v) end})
local Chams=Visuals.CreateOptionsButton({["Name"]="Chams",["Function"]=function(v) cfg.Chams=v end})
Chams.CreateToggle({["Name"]="Thermal",["Default"]=false,["Function"]=function(v) cfg.ChamsThermal=v end})
local Corner=Visuals.CreateOptionsButton({["Name"]="Corner Box",["Function"]=function(v) cfg.Corner=v end})
local Thermal=Visuals.CreateOptionsButton({["Name"]="Thermal Corner",["Function"]=function(v) cfg.ThermalCorner=v end})
local Health=Visuals.CreateOptionsButton({["Name"]="HealthBar",["Function"]=function(v) cfg.Health=v end})
local ND=Visuals.CreateOptionsButton({["Name"]="Name + Distance",["Function"]=function(v) cfg.NameDistance=v end})
local Skeleton=Visuals.CreateOptionsButton({["Name"]="Skeleton",["Function"]=function(v) cfg.Skeleton=v end})
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.SkeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=100,["Default"]=15,["Function"]=function(v) cfg.SkeletonTrans=v/100 end})
Skeleton.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=4,["Default"]=1,["Function"]=function(v) cfg.SkeletonThickness=v end})
local Tracers=Visuals.CreateOptionsButton({["Name"]="Tracers",["Function"]=function(v) cfg.Tracers=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.TracerColor=Color3.fromHSV(h,s,v) end})
local Distance=Visuals.CreateOptionsButton({["Name"]="Distance",["Function"]=function() end})
Distance.CreateSlider({["Name"]="Max Distance",["Min"]=100,["Max"]=4000,["Default"]=1800,["Function"]=function(v) cfg.Distance=v end})

local Arrows=Render.CreateOptionsButton({["Name"]="Arrows",["Function"]=function(v) arrowsEnabled=v end})
Arrows.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) arrowColor=Color3.fromHSV(h,s,v) end})
Arrows.CreateSlider({["Name"]="Radius",["Min"]=25,["Max"]=48,["Default"]=43,["Function"]=function(v) arrowRadius=v/100 end})
Arrows.CreateSlider({["Name"]="Size",["Min"]=7,["Max"]=18,["Default"]=12,["Function"]=function(v) arrowSize=v end})

-- FOV: single owner, no per-frame fight. Slider writes once; no forced loop => no shaking.
local fovEnabled=false
local fovValue=80
local fovOriginal=nil
local FOV=Visuals.CreateOptionsButton({["Name"]="FOVChanger",["Function"]=function(v)
    fovEnabled=v
    local cam=Workspace.CurrentCamera
    if v then
        if cam and not fovOriginal then fovOriginal=cam.FieldOfView end
        if cam then cam.FieldOfView=fovValue end
    elseif cam and fovOriginal then cam.FieldOfView=fovOriginal fovOriginal=nil end
end,["HoverText"]="Applies FOV once instead of fighting the game's camera every frame."})
FOV.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=120,["Default"]=80,["Function"]=function(v) fovValue=v if fovEnabled and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView=v end end})
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if fovEnabled then task.defer(function() if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView=fovValue end end) end end)

-- World hit feedback toggles.
World.CreateOptionsButton({["Name"]="HitSound",["Function"]=function(v) hitSoundEnabled=v end})
World.CreateOptionsButton({["Name"]="HitMarker",["Function"]=function(v) hitMarkerEnabled=v end})

-- ==========================================================================
-- INVENTORY VIEWER: BOTS, NOT LOCAL PLAYER
-- ==========================================================================
local InvGui=Instance.new("ScreenGui")
InvGui.Name="YokaiBotInventoryV2"; InvGui.ResetOnSpawn=false; InvGui.IgnoreGuiInset=true; InvGui.DisplayOrder=997; InvGui.Enabled=false; InvGui.Parent=parentGui
local invFrame=Instance.new("Frame"); invFrame.AnchorPoint=Vector2.new(1,0); invFrame.Position=UDim2.new(1,-18,0,120); invFrame.Size=UDim2.fromOffset(290,300); invFrame.BackgroundColor3=Color3.fromRGB(18,18,20); invFrame.BackgroundTransparency=.08; invFrame.BorderSizePixel=0; invFrame.Parent=InvGui
local invTitle=Instance.new("TextLabel"); invTitle.BackgroundTransparency=1; invTitle.Size=UDim2.new(1,-20,0,32); invTitle.Position=UDim2.fromOffset(10,6); invTitle.Font=Enum.Font.GothamSemibold; invTitle.TextSize=14; invTitle.TextColor3=Color3.new(1,1,1); invTitle.TextXAlignment=Enum.TextXAlignment.Left; invTitle.Text="Bot Inventory Viewer"; invTitle.Parent=invFrame
local invText=Instance.new("TextLabel"); invText.BackgroundTransparency=1; invText.Position=UDim2.fromOffset(10,42); invText.Size=UDim2.new(1,-20,1,-50); invText.Font=Enum.Font.Code; invText.TextSize=12; invText.TextColor3=Color3.fromRGB(220,220,225); invText.TextXAlignment=Enum.TextXAlignment.Left; invText.TextYAlignment=Enum.TextYAlignment.Top; invText.TextWrapped=false; invText.Text=""; invText.Parent=invFrame
local invEnabled=false
local function botWeapon(model)
    local tool=model:FindFirstChildWhichIsA("Tool",true)
    if tool then return tool.Name end
    for _,d in ipairs(model:GetDescendants()) do
        if d:IsA("StringValue") and contains(d.Name,{"weapon","gun","item"}) and d.Value~="" then return d.Value end
        if d:IsA("ObjectValue") and contains(d.Name,{"weapon","gun","item"}) and d.Value then return d.Value.Name end
        if d:IsA("Model") and contains(d.Name,{"rifle","pistol","shotgun","smg","gun","weapon"}) then return d.Name end
    end
    return "unknown"
end
Utility.CreateOptionsButton({["Name"]="Inventory Viewer",["Function"]=function(v) invEnabled=v InvGui.Enabled=v end,["HoverText"]="Shows nearby bot/NPC weapons only."})

-- ==========================================================================
-- CAR ESP
-- ==========================================================================
local vehiclesFolder=Workspace:FindFirstChild("Vehicles")
local carEnabled=false
local carColor=Color3.fromRGB(60,220,180)
local carDistance=2500
local cars={}
local function vehicleAnchor(m) return m and (m:FindFirstChildWhichIsA("VehicleSeat",true) or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)) end
local function isVehicle(m)
    if not m or not m:IsA("Model") then return false end
    if m:FindFirstChildWhichIsA("VehicleSeat",true) then return true end
    local n=m.Name:lower(); return n:find("car",1,true) or n:find("truck",1,true) or n:find("sedan",1,true) or n:find("vehicle",1,true) or n:find("pickup",1,true)
end
local function addCar(m)
    if cars[m] or not isVehicle(m) then return end
    local a=vehicleAnchor(m) if not a then return end
    local h=Instance.new("Highlight"); h.Name="YokaiCarESPV2"; h.Adornee=m; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.FillTransparency=.86; h.OutlineTransparency=.08; h.Enabled=false; h.Parent=m
    local bb=Instance.new("BillboardGui"); bb.Name="YokaiCarLabelV2"; bb.Adornee=a; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(180,28); bb.StudsOffsetWorldSpace=Vector3.new(0,3,0); bb.Enabled=false; bb.Parent=a
    local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Font=Enum.Font.GothamSemibold; t.TextSize=12; t.TextStrokeTransparency=.45; t.Parent=bb
    cars[m]={h=h,bb=bb,t=t,a=a}
end
local CarESP=Visuals.CreateOptionsButton({["Name"]="Car ESP",["Function"]=function(v) carEnabled=v end})
CarESP.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) carColor=Color3.fromHSV(h,s,v) end})
CarESP.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=5000,["Default"]=2500,["Function"]=function(v) carDistance=v end})
if vehiclesFolder then
    for _,m in ipairs(vehiclesFolder:GetChildren()) do addCar(m) end
    vehiclesFolder.ChildAdded:Connect(function(m) task.defer(addCar,m) end)
end

-- ==========================================================================
-- SHOT TRACKING + MAIN VISUAL LOOP
-- ==========================================================================
UserInputService.InputBegan:Connect(function(input,gp)
    if gp or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    lastShotAt=os.clock(); lastShotBot=nil; lastShotPart=nil
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local c=cam.ViewportSize/2
    local ray=cam:ViewportPointToRay(c.X,c.Y)
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={LocalPlayer.Character,cam}; rp.IgnoreWater=true
    local hit=Workspace:Raycast(ray.Origin,ray.Direction*4000,rp)
    if hit and hit.Instance then
        for model in pairs(bots) do if hit.Instance:IsDescendantOf(model) then lastShotBot=model; lastShotPart=hit.Instance; break end end
    end
end)

local renderClock=0
RunService.RenderStepped:Connect(function(dt)
    renderClock+=dt
    if renderClock<1/30 then return end
    renderClock=0
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local now=os.clock()
    for model in pairs(bots) do
        if not isBot(model) then if packs[model] then destroyPack(model) end bots[model]=nil continue end
        local root=rootOf(model)
        local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
        local p=packs[model] or newPack(model)
        hideVisualPack(p)
        if dist<=cfg.Distance then
            local x1,y1,x2,y2=bounds2D(model)
            local head=aimPart(model,"Head")
            local vis=head and visibleFromCamera(model,head) or false
            local stateColor=cfg.WallCheck and (vis and cfg.Visible or cfg.Occluded) or cfg.ESPColor
            if x1 then
                if cfg.ESP then
                    p.fill.Visible=true; p.fill.Position=UDim2.fromOffset(x1,y1); p.fill.Size=UDim2.fromOffset(x2-x1,y2-y1); p.fill.BackgroundColor3=stateColor; p.fill.BackgroundTransparency=.88
                    setRectBorder(p.borders,x1,y1,x2,y2,stateColor,1)
                end
                if cfg.Corner then setCorners(p.corners,x1,y1,x2,y2,cfg.WallCheck and stateColor or Color3.new(1,1,1),1) end
                if cfg.ThermalCorner then
                    p.thermal.Visible=true; p.thermal.Position=UDim2.fromOffset(x1,y1); p.thermal.Size=UDim2.fromOffset(x2-x1,y2-y1); p.gradient.Rotation=(now*55)%360
                    p.gradient.Color=ColorSequence.new(Color3.fromRGB(119,120,255),Color3.fromRGB(20,20,25))
                    setCorners(p.corners,x1,y1,x2,y2,cfg.WallCheck and stateColor or Color3.fromRGB(190,190,255),1)
                end
                if cfg.Health then
                    local hum=humanoidOf(model); local ratio=hum and math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1) or 0
                    local h=y2-y1
                    p.healthBG.Visible=true; p.healthBG.Position=UDim2.fromOffset(x2+6,y1); p.healthBG.Size=UDim2.fromOffset(4,h); p.healthBG.BackgroundTransparency=.15
                    p.health.Visible=true; p.health.Size=UDim2.fromOffset(2,h*ratio); p.health.Position=UDim2.fromOffset(x2+7,y2-h*ratio)
                end
                if cfg.NameDistance then
                    p.label.Visible=true; p.label.Position=UDim2.fromOffset(x1-20,y1-20); p.label.Size=UDim2.fromOffset((x2-x1)+40,18); p.label.Text=string.format("%s  [%d]",model.Name,math.floor(dist+.5))
                end
                if cfg.Tracers then
                    local start=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y-4); local finish=Vector2.new((x1+x2)/2,y2)
                    setLine(p.tracer,start,finish,1,cfg.TracerColor,.05)
                end
                if cfg.Skeleton then
                    local hum=humanoidOf(model); local list=(hum and hum.RigType==Enum.HumanoidRigType.R6) and bonesR6 or bones
                    local idx=0
                    for _,pair in ipairs(list) do
                        local a=model:FindFirstChild(pair[1]); local b=model:FindFirstChild(pair[2])
                        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                            local sa,ona=cam:WorldToViewportPoint(a.Position); local sb,onb=cam:WorldToViewportPoint(b.Position)
                            if sa.Z>0 and sb.Z>0 then idx+=1; setLine(p.skeleton[idx],Vector2.new(sa.X,sa.Y),Vector2.new(sb.X,sb.Y),cfg.SkeletonThickness,cfg.SkeletonColor,cfg.SkeletonTrans) end
                        end
                    end
                end
            end
            if cfg.Chams then
                p.highlight.Enabled=true
                local c=stateColor
                if cfg.ChamsThermal and (not cfg.WallCheck or vis) then c=Color3.fromHSV((now*.10)%1,.55,1) end
                p.highlight.FillColor=c; p.highlight.OutlineColor=stateColor; p.highlight.FillTransparency=.62; p.highlight.OutlineTransparency=.08
            end
        end

        -- Accurate offscreen arrows from camera-space yaw/pitch.
        if arrowsEnabled and root and dist<=cfg.Distance then
            local sp,on=cam:WorldToViewportPoint(root.Position)
            if not on or sp.Z<=0 or sp.X<0 or sp.Y<0 or sp.X>cam.ViewportSize.X or sp.Y>cam.ViewportSize.Y then
                local rel=cam.CFrame:PointToObjectSpace(root.Position)
                local yaw=math.atan2(rel.X,-rel.Z)
                local pitch=math.atan2(rel.Y,math.max(.001,math.sqrt(rel.X*rel.X+rel.Z*rel.Z)))
                local dir=Vector2.new(math.sin(yaw),-math.cos(yaw)-math.sin(pitch)*.55)
                if dir.Magnitude<.01 then dir=Vector2.new(0,-1) else dir=dir.Unit end
                local center=cam.ViewportSize/2
                local radius=math.min(cam.ViewportSize.X,cam.ViewportSize.Y)*arrowRadius
                local tip=center+dir*radius
                local perp=Vector2.new(-dir.Y,dir.X)
                local back=tip-dir*arrowSize
                setLine(p.arrowA,tip,back+perp*(arrowSize*.55),2,arrowColor,0)
                setLine(p.arrowB,tip,back-perp*(arrowSize*.55),2,arrowColor,0)
            end
        end

        if hitboxEnabled then
            local part=aimPart(model,hitboxPartName)
            if part and part:IsA("BasePart") then
                if not hitboxOriginal[part] then hitboxOriginal[part]={Size=part.Size,Transparency=part.Transparency,CanCollide=part.CanCollide} end
                local base=hitboxOriginal[part].Size
                part.Size=Vector3.new(math.max(base.X,hitboxSize),math.max(base.Y,hitboxSize),math.max(base.Z,hitboxSize))
                part.Transparency=hitboxTransparency; part.CanCollide=false
            end
        end
    end
end)

local miscClock=0
RunService.Heartbeat:Connect(function(dt)
    miscClock+=dt
    if miscClock<.25 then return end
    miscClock=0
    if invEnabled then
        local list={}
        for model in pairs(bots) do
            if isBot(model) then local r=rootOf(model) if r then table.insert(list,{m=model,d=(r.Position-(Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or r.Position)).Magnitude}) end end
        end
        table.sort(list,function(a,b) return a.d<b.d end)
        local lines={}
        for i=1,math.min(10,#list) do local e=list[i]; table.insert(lines,string.format("%-18s  %-18s  %4d",e.m.Name:sub(1,18),botWeapon(e.m):sub(1,18),math.floor(e.d+.5))) end
        invText.Text=#lines>0 and table.concat(lines,"\n") or "No bots detected"
    end
    for m,s in pairs(cars) do
        if not m.Parent or not s.a or not s.a.Parent then
            if s.h then s.h:Destroy() end if s.bb then s.bb:Destroy() end cars[m]=nil
        else
            local dist=(s.a.Position-(Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or s.a.Position)).Magnitude
            local show=carEnabled and dist<=carDistance
            s.h.Enabled=show; s.bb.Enabled=show
            if show then s.h.FillColor=carColor; s.h.OutlineColor=carColor; s.t.TextColor3=carColor; s.t.Text=string.format("%s  •  %d studs",m.Name:gsub("_"," "),math.floor(dist+.5)) end
        end
    end
end)

notify("Yokai","Bot practice runtime V2 loaded",4)
