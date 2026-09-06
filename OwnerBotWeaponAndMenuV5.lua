-- Final bot-practice access + weapon-system integration.
-- Targets NPCs under Workspace.Zombies/NPCs/Bots only; Player characters are excluded.
-- No __namecall/metamethod hooks and no anti-cheat bypass logic.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec = objects.CombatWindow
local VisualsRec = objects.VisualsWindow
local UtilityRec = objects.UtilityWindow
local WorldRec = objects.WorldWindow
local RenderRec = objects.RenderWindow
local MovementRec = objects.MovementWindow
local Combat = CombatRec and CombatRec.Api
local Visuals = VisualsRec and VisualsRec.Api
local World = WorldRec and WorldRec.Api
if not (Combat and Visuals and World) then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
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
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and (not parentRec or under(rec,parentRec)) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end
local function notify(title,text,dur)
    pcall(function() GuiLibrary.CreateNotification(title,text,dur or 3) end)
end

-- ============================================================================
-- WINDOW WHEEL SCROLL
-- Yokai windows grow taller than the viewport when an option is expanded.
-- Rather than changing the GUI library hierarchy, wheel-scroll moves the window
-- vertically within safe viewport bounds. This keeps every existing control usable.
-- ============================================================================
local scrollWindows={CombatRec,MovementRec,RenderRec,UtilityRec,VisualsRec,WorldRec}
local function mouseInsideX(gui,mouse)
    if not gui or not gui.Parent or not gui.Visible then return false end
    local x1=gui.AbsolutePosition.X
    local x2=x1+gui.AbsoluteSize.X
    return mouse.X>=x1-8 and mouse.X<=x2+8
end
local function scrollWindow(gui,z)
    if not gui or not gui.Parent then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vh=cam.ViewportSize.Y
    local h=gui.AbsoluteSize.Y
    if h<=vh-16 then return end
    local pos=gui.Position
    local current=gui.AbsolutePosition.Y
    local desired=current + z*52
    local minY=vh-h-8
    local maxY=8
    desired=math.clamp(desired,minY,maxY)
    local delta=desired-current
    gui.Position=UDim2.new(pos.X.Scale,pos.X.Offset,pos.Y.Scale,pos.Y.Offset+delta)
end
UserInputService.InputChanged:Connect(function(input,gp)
    if gp or input.UserInputType~=Enum.UserInputType.MouseWheel then return end
    local mouse=UserInputService:GetMouseLocation()
    for _,rec in ipairs(scrollWindows) do
        local gui=rec and rec.Object
        if mouseInsideX(gui,mouse) then
            scrollWindow(gui,input.Position.Z)
            break
        end
    end
end)

local function setOrder(parentRec,names,start)
    local order=start or 1
    for _,name in ipairs(names) do
        local _,rec=optionRecord(parentRec,name)
        if rec and rec.Object then
            pcall(function()
                rec.Object.Visible=true
                rec.Object.LayoutOrder=order
            end)
            order+=1
        end
    end
end

task.defer(function()
    setOrder(CombatRec,{"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo"},1)
    setOrder(VisualsRec,{"ESP","Chams","Corner Box","Thermal Corner","HealthBar","Name + Distance","Skeleton","Tracers","Distance","Car ESP","Custom Crosshair","FOVChanger"},1)
    setOrder(WorldRec,{"BulletTracer","HitSound","HitMarker","FullBrightness"},1)
end)

-- ============================================================================
-- BOT REGISTRY
-- ============================================================================
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
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local hum=humanoidOf(model)
    return hum~=nil and rootOf(model)~=nil
end
local botRoot=Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots") or Workspace
local bots={}
local function registerBot(model) if isBot(model) then bots[model]=true end end
local function seedBots()
    table.clear(bots)
    for _,d in ipairs(botRoot:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerBot(d.Parent) end
    end
end
seedBots()
botRoot.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerBot,d.Parent) end
end)
botRoot.DescendantRemoving:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
end)

local function botPart(model,name)
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or rootOf(model)
end
local function visibleBot(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function nearestBot(radius,partName,wall,maxDistance,prediction)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPos,bestPx=nil,nil,nil,radius
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=botPart(model,partName)
            if root and part then
                local dist=(root.Position-cam.CFrame.Position).Magnitude
                if dist<=maxDistance and (not wall or visibleBot(model,part)) then
                    local pos=part.Position
                    if prediction then pos += root.AssemblyLinearVelocity*math.clamp(dist/2600,0,.35) end
                    local sp,on=cam:WorldToViewportPoint(pos)
                    if on and sp.Z>0 then
                        local px=(Vector2.new(sp.X,sp.Y)-center).Magnitude
                        if px<bestPx then best,bestPart,bestPos,bestPx=model,part,pos,px end
                    end
                end
            end
        end
    end
    return best,bestPart,bestPos,bestPx
end

-- ============================================================================
-- GAME WEAPON MODULES
-- ============================================================================
local gunSystem=nil
pcall(function()
    gunSystem=LocalPlayer.PlayerScripts.Client.Systems.GunSystem
end)
local WeaponShotBuilder=nil
local WeaponStats=nil
local BridgeRegistry=nil
pcall(function()
    WeaponShotBuilder=require(gunSystem.WeaponViewmodelController.WeaponShotBuilder)
end)
pcall(function()
    WeaponStats=require(ReplicatedStorage.WeaponSystemAssets.Modules.WeaponStats)
end)
pcall(function()
    BridgeRegistry=require(gunSystem.BridgeRegistry)
end)

-- ============================================================================
-- SILENT AIM + WORKING BOT HITBOX THROUGH WeaponShotBuilder.ResolveBaseDirection
-- The game itself calls this exported function before spread and ShotFired.
-- No metamethod hooks are used.
-- ============================================================================
removeOption(CombatRec,"SilentAim")
removeOption(CombatRec,"HitBoxes")

local silentEnabled=false
local silentPart="Head"
local silentFov=420
local silentWall=true
local silentDistance=2200
local silentPrediction=true

local hitboxEnabled=false
local hitboxPart="Head"
local hitboxStuds=5
local hitboxWall=true
local hitboxDistance=1800

local originalResolve=WeaponShotBuilder and WeaponShotBuilder.ResolveBaseDirection or nil
local function screenRadiusForStuds(part,studs)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return 0 end
    local dist=(part.Position-cam.CFrame.Position).Magnitude
    if dist<=.01 then return 0 end
    local focal=(cam.ViewportSize.Y/2)/math.tan(math.rad(cam.FieldOfView/2))
    return math.clamp((studs/2)*focal/dist,4,300)
end
local function hitboxTarget()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bp,bpos,bpx=nil,nil,nil,math.huge
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=botPart(model,hitboxPart)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=hitboxDistance and (not hitboxWall or visibleBot(model,part)) then
                local sp,on=cam:WorldToViewportPoint(part.Position)
                if on and sp.Z>0 then
                    local px=(Vector2.new(sp.X,sp.Y)-center).Magnitude
                    local allowed=screenRadiusForStuds(part,hitboxStuds)
                    if px<=allowed and px<bpx then best,bp,bpos,bpx=model,part,part.Position,px end
                end
            end
        end
    end
    return best,bp,bpos
end
local function installResolve()
    if not (WeaponShotBuilder and originalResolve) then return end
    WeaponShotBuilder.ResolveBaseDirection=function(ctx)
        local origin=ctx and (ctx.shotOrigin or ctx.serverShotOrigin)
        if typeof(origin)~="Vector3" and ctx and ctx.camera then origin=ctx.camera.CFrame.Position end
        if hitboxEnabled then
            local model,part,pos=hitboxTarget()
            if model and part and pos and typeof(origin)=="Vector3" then
                local d=pos-origin
                if d.Magnitude>.001 then return d.Unit end
            end
        end
        if silentEnabled then
            local model,part,pos=nearestBot(silentFov,silentPart,silentWall,silentDistance,silentPrediction)
            if model and part and pos and typeof(origin)=="Vector3" then
                local d=pos-origin
                if d.Magnitude>.001 then return d.Unit end
            end
        end
        return originalResolve(ctx)
    end
end
local function restoreResolveIfIdle()
    if WeaponShotBuilder and originalResolve and not silentEnabled and not hitboxEnabled then
        WeaponShotBuilder.ResolveBaseDirection=originalResolve
    else
        installResolve()
    end
end

local SilentAim=Combat.CreateOptionsButton({["Name"]="SilentAim",["Function"]=function(v) silentEnabled=v; restoreResolveIfIdle() end,["HoverText"]="NPC-only shot direction using the game's WeaponShotBuilder."})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPart=v end})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=30,["Max"]=1000,["Default"]=420,["Function"]=function(v) silentFov=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWall=v end})
SilentAim.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) silentPrediction=v end})
SilentAim.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3500,["Default"]=2200,["Function"]=function(v) silentDistance=v end})

local HitBoxes=Combat.CreateOptionsButton({["Name"]="HitBoxes",["Function"]=function(v) hitboxEnabled=v; restoreResolveIfIdle() end,["HoverText"]="Expands the NPC targeting area but redirects the shot to the real Head/Torso."})
HitBoxes.CreateDropdown({["Name"]="Part",["List"]={"Head","Torso"},["Function"]=function(v) hitboxPart=v end})
HitBoxes.CreateSlider({["Name"]="Size",["Min"]=2,["Max"]=14,["Default"]=5,["Function"]=function(v) hitboxStuds=v end})
HitBoxes.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) hitboxWall=v end})
HitBoxes.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3500,["Default"]=1800,["Function"]=function(v) hitboxDistance=v end})

-- ============================================================================
-- WEAPON STATS: NO RECOIL / FAST RELOAD / INFINITE AMMO
-- WeaponViewmodelController obtains WeaponStats.Get(tool) and then reads
-- recoil, gunRecoil, reloadSpeedModifier and infiniteAmmo from that table.
-- ============================================================================
removeOption(CombatRec,"No Recoil")
removeOption(CombatRec,"Fast Reload")
removeOption(CombatRec,"Infinite Ammo")

local noRecoil=false
local fastReload=false
local infiniteAmmo=false
local reloadMultiplier=6
local savedStats=setmetatable({}, {__mode="k"})

local function currentTools()
    local out={}
    local seen={}
    for _,root in ipairs({LocalPlayer.Character,LocalPlayer:FindFirstChildOfClass("Backpack")}) do
        if root then
            for _,obj in ipairs(root:GetChildren()) do
                if obj:IsA("Tool") and obj:FindFirstChild("WeaponConfig") and not seen[obj] then
                    seen[obj]=true; table.insert(out,obj)
                end
            end
        end
    end
    return out
end
local function copyStats(stats)
    if savedStats[stats] then return end
    local s={reloadSpeedModifier=stats.reloadSpeedModifier,infiniteAmmo=stats.infiniteAmmo}
    if type(stats.recoil)=="table" then
        s.recoil={vertical=stats.recoil.vertical,horizontal=stats.recoil.horizontal,camShake=stats.recoil.camShake,aimReduction=stats.recoil.aimReduction}
    end
    if type(stats.gunRecoil)=="table" then
        s.gunRecoil={vertical=stats.gunRecoil.vertical,horizontal=stats.gunRecoil.horizontal,punchMultiplier=stats.gunRecoil.punchMultiplier}
    end
    savedStats[stats]=s
end
local function applyStats(stats)
    if type(stats)~="table" then return end
    copyStats(stats)
    local orig=savedStats[stats]
    if noRecoil then
        if type(stats.recoil)=="table" then
            stats.recoil.vertical=0; stats.recoil.horizontal=0; stats.recoil.camShake=0
        end
        if type(stats.gunRecoil)=="table" then
            stats.gunRecoil.vertical=0; stats.gunRecoil.horizontal=0; stats.gunRecoil.punchMultiplier=0
        end
    elseif orig then
        if orig.recoil and type(stats.recoil)=="table" then
            stats.recoil.vertical=orig.recoil.vertical; stats.recoil.horizontal=orig.recoil.horizontal; stats.recoil.camShake=orig.recoil.camShake
        end
        if orig.gunRecoil and type(stats.gunRecoil)=="table" then
            stats.gunRecoil.vertical=orig.gunRecoil.vertical; stats.gunRecoil.horizontal=orig.gunRecoil.horizontal; stats.gunRecoil.punchMultiplier=orig.gunRecoil.punchMultiplier
        end
    end
    if fastReload then stats.reloadSpeedModifier=reloadMultiplier elseif orig then stats.reloadSpeedModifier=orig.reloadSpeedModifier end
    if infiniteAmmo then stats.infiniteAmmo=true elseif orig then stats.infiniteAmmo=orig.infiniteAmmo end
end
local function resolveAmmoNode(obj)
    if not obj then return nil end
    if obj:IsA("IntValue") or obj:IsA("NumberValue") then return obj end
    if obj:IsA("ObjectValue") and obj.Value and (obj.Value:IsA("IntValue") or obj.Value:IsA("NumberValue")) then return obj.Value end
    return nil
end
local function refillTool(tool)
    local ammo=tool and tool:FindFirstChild("Ammo")
    if not ammo then return end
    local mag=resolveAmmoNode(ammo:FindFirstChild("MagAmmo"))
    local pool=resolveAmmoNode(ammo:FindFirstChild("ArcadeAmmoPool"))
    if mag then pcall(function() mag.Value=mag.MaxValue end) end
    if pool then pcall(function() pool.Value=math.max(pool.Value,999) end) end
end
local function refreshWeaponState()
    if not WeaponStats then return end
    for _,tool in ipairs(currentTools()) do
        local ok,stats=pcall(function() return WeaponStats.Get(tool) end)
        if ok and stats then applyStats(stats) end
        if infiniteAmmo then refillTool(tool) end
    end
end

local NoRecoil=Combat.CreateOptionsButton({["Name"]="No Recoil",["Function"]=function(v) noRecoil=v; refreshWeaponState() end,["HoverText"]="Uses this game's WeaponStats recoil tables."})
local FastReload=Combat.CreateOptionsButton({["Name"]="Fast Reload",["Function"]=function(v) fastReload=v; refreshWeaponState() end,["HoverText"]="Speeds the game's reload animation/marker flow through reloadSpeedModifier."})
FastReload.CreateSlider({["Name"]="Speed",["Min"]=2,["Max"]=12,["Default"]=6,["Function"]=function(v) reloadMultiplier=v; if fastReload then refreshWeaponState() end end})
local InfiniteAmmo=Combat.CreateOptionsButton({["Name"]="Infinite Ammo",["Function"]=function(v) infiniteAmmo=v; refreshWeaponState() end,["HoverText"]="Sets WeaponStats.infiniteAmmo and replenishes MagAmmo/ArcadeAmmoPool locally."})

local weaponClock=0
RunService.Heartbeat:Connect(function(dt)
    weaponClock+=dt
    if weaponClock<.12 then return end
    weaponClock=0
    if noRecoil or fastReload or infiniteAmmo then refreshWeaponState() end
end)

-- ============================================================================
-- STABLE FOV: use the game's ClientSettingsController fpFov setting when possible.
-- ============================================================================
removeOption(VisualsRec,"FOVChanger")
pcall(function() RunService:UnbindFromRenderStep("YokaiFOVChangerLock") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiLocalFOVLock") end)

local ClientSettingsController=nil
local Setting=nil
pcall(function() ClientSettingsController=require(ReplicatedStorage.Shared.Systems.ClientSettingsController) end)
pcall(function() Setting=require(ReplicatedStorage.Shared.common.enums.Setting) end)
local fovEnabled=false
local fovValue=80
local fovOriginal=nil
local fovGuard=false
local function setClientFov(v)
    if ClientSettingsController and Setting and Setting.fpFov then
        for _,name in ipairs({"Set","set","SetValue","setValue"}) do
            local fn=ClientSettingsController[name]
            if type(fn)=="function" then
                local ok=pcall(fn,Setting.fpFov,v)
                if not ok then ok=pcall(fn,ClientSettingsController,Setting.fpFov,v) end
                if ok then return true end
            end
        end
    end
    return false
end
local function applyFov()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if setClientFov(fovValue) then return end
    fovGuard=true
    cam.FieldOfView=fovValue
    task.defer(function() fovGuard=false end)
end
local FOV=Visuals.CreateOptionsButton({["Name"]="FOVChanger",["Function"]=function(v)
    fovEnabled=v
    local cam=Workspace.CurrentCamera
    if v then
        if cam and not fovOriginal then fovOriginal=cam.FieldOfView end
        applyFov()
    elseif fovOriginal then
        if not setClientFov(fovOriginal) and cam then cam.FieldOfView=fovOriginal end
        fovOriginal=nil
    end
end,["HoverText"]="Changes the game's fpFov setting instead of fighting Camera.FieldOfView every frame."})
FOV.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=120,["Default"]=80,["Function"]=function(v) fovValue=v; if fovEnabled then applyFov() end end})
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if fovEnabled then task.delay(.1,applyFov) end end)

-- ============================================================================
-- HIT FEEDBACK: watch both Humanoid.Health and the game's separate Health value.
-- ShotFired is used when BridgeRegistry exposes it; Mouse1 is a fallback only.
-- ============================================================================
removeOption(WorldRec,"HitSound")
removeOption(WorldRec,"HitMarker")

local hitSoundEnabled=false
local hitMarkerEnabled=false
local lastShotAt=0
local lastShotTarget=nil
local hitSound=Instance.new("Sound")
hitSound.Name="YokaiWeaponV5HitSound"
hitSound.SoundId="rbxassetid://91546829095879"
hitSound.Volume=.7
hitSound.Parent=SoundService

local parentGui=(gethui and gethui()) or CoreGui
local oldHit=parentGui:FindFirstChild("YokaiWeaponV5HitMarker")
if oldHit then oldHit:Destroy() end
local HitGui=Instance.new("ScreenGui")
HitGui.Name="YokaiWeaponV5HitMarker"; HitGui.ResetOnSpawn=false; HitGui.IgnoreGuiInset=true; HitGui.DisplayOrder=1006; HitGui.Parent=parentGui
local hitLines={}
for i=1,4 do local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(255,70,70); f.Visible=false; f.Parent=HitGui; hitLines[i]=f end
local hitToken=0
local function line(f,a,b)
    local d=b-a
    f.AnchorPoint=Vector2.new(.5,.5); f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2); f.Size=UDim2.fromOffset(d.Magnitude,2); f.Rotation=math.deg(math.atan2(d.Y,d.X)); f.Visible=true
end
local function flashHit(model,amount)
    if hitSoundEnabled then pcall(function() hitSound.TimePosition=0; hitSound:Play() end) end
    if hitMarkerEnabled then
        local cam=Workspace.CurrentCamera
        if cam then
            local c=cam.ViewportSize/2
            line(hitLines[1],c+Vector2.new(-18,-18),c+Vector2.new(-7,-7))
            line(hitLines[2],c+Vector2.new(18,-18),c+Vector2.new(7,-7))
            line(hitLines[3],c+Vector2.new(-18,18),c+Vector2.new(-7,7))
            line(hitLines[4],c+Vector2.new(18,18),c+Vector2.new(7,7))
            hitToken+=1 local tk=hitToken
            task.delay(.18,function() if tk==hitToken then for _,f in ipairs(hitLines) do f.Visible=false end end end)
        end
    end
    notify("Hit",string.format("%s  -%d",model and model.Name or "Bot",math.max(0,math.floor((amount or 0)+.5))),2)
end
local healthConns={}
local function watchHealth(model)
    if healthConns[model] then return end
    healthConns[model]={}
    local function bindValue(obj)
        if not obj then return end
        if obj:IsA("Humanoid") then
            local prev=obj.Health
            table.insert(healthConns[model],obj.HealthChanged:Connect(function(v)
                if v<prev and os.clock()-lastShotAt<.8 and (not lastShotTarget or lastShotTarget==model) then flashHit(model,prev-v) end
                prev=v
            end))
        elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
            local prev=obj.Value
            table.insert(healthConns[model],obj.Changed:Connect(function(v)
                local n=tonumber(v)
                if n and n<prev and os.clock()-lastShotAt<.8 and (not lastShotTarget or lastShotTarget==model) then flashHit(model,prev-n) end
                if n then prev=n end
            end))
        end
    end
    bindValue(humanoidOf(model))
    bindValue(model:FindFirstChild("Health"))
end
for model in pairs(bots) do watchHealth(model) end
botRoot.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.delay(.1,function() watchHealth(d.Parent) end) end
end)

local function markShot()
    lastShotAt=os.clock()
    lastShotTarget=nil
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local center=cam.ViewportSize/2
    local ray=cam:ViewportPointToRay(center.X,center.Y)
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={LocalPlayer.Character,cam}; rp.IgnoreWater=true
    local h=Workspace:Raycast(ray.Origin,ray.Direction*4000,rp)
    if h and h.Instance then
        for model in pairs(bots) do if h.Instance:IsDescendantOf(model) then lastShotTarget=model break end end
    end
end
local shotConnected=false
pcall(function()
    local ev=BridgeRegistry and BridgeRegistry.ShotFired
    if typeof(ev)=="Instance" and ev:IsA("BindableEvent") then ev.Event:Connect(function() markShot() end); shotConnected=true
    elseif type(ev)=="table" and type(ev.Connect)=="function" then ev:Connect(function() markShot() end); shotConnected=true
    elseif typeof(ev)=="RBXScriptSignal" then ev:Connect(function() markShot() end); shotConnected=true end
end)
if not shotConnected then
    UserInputService.InputBegan:Connect(function(input,gp) if not gp and input.UserInputType==Enum.UserInputType.MouseButton1 then markShot() end end)
end

World.CreateOptionsButton({["Name"]="HitSound",["Function"]=function(v) hitSoundEnabled=v end})
World.CreateOptionsButton({["Name"]="HitMarker",["Function"]=function(v) hitMarkerEnabled=v end})

-- Final ordering after replacements.
task.defer(function()
    setOrder(CombatRec,{"Aimbot","SilentAim","HitBoxes","No Recoil","Fast Reload","Infinite Ammo"},1)
    setOrder(VisualsRec,{"ESP","Chams","Corner Box","Thermal Corner","HealthBar","Name + Distance","Skeleton","Tracers","Distance","Car ESP","Custom Crosshair","FOVChanger"},1)
    setOrder(WorldRec,{"BulletTracer","HitSound","HitMarker","FullBrightness"},1)
end)

notify("Yokai","Bot menu + weapon integration V5 loaded",4)
