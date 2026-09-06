-- Final Combat completion layer for the Gun Testing bot-practice profile.
-- Keeps the V3 Aimbot/SilentAim/Magic Bullets and adds bot-only HitBoxes plus
-- local No Recoil, local ammo refill and local AntiAim pose. Player characters
-- are explicitly excluded from target acquisition. No remotes, kick hooks,
-- anti-cheat bypass or ban-evasion logic are used here.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary.ObjectsThatCanBeSaved or {}
local CombatRec=objects.CombatWindow
local Combat=CombatRec and CombatRec.Api
if not Combat then return end

local ps=LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts",8)
local gc=ps and (ps:FindFirstChild("GunController") or ps:WaitForChild("GunController",8))
local events=gc and (gc:FindFirstChild("Events") or gc:WaitForChild("Events",8))
local pluginModule=events and (events:FindFirstChild("GunPlugin") or events:WaitForChild("GunPlugin",8))
local GunPlugin=nil
if pluginModule and pluginModule:IsA("ModuleScript") then
    local ok,res=pcall(require,pluginModule)
    if ok and type(res)=="table" then GunPlugin=res end
end

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP,"") end
local function optionName(key,rec)
    if rec and rec.Api and rec.Api.Name then return clean(rec.Api.Name) end
    return clean(key):gsub("OptionsButton$","")
end
local function under(rec)
    if not rec or not rec.Object then return false end
    for _,root in ipairs({CombatRec.Object,CombatRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
    end
    return false
end
local function findOption(name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and under(rec) and optionName(key,rec)==name then
            return key,rec
        end
    end
end
local function removeOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and under(rec) and optionName(key,rec)==name then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary.RemoveObject(key) end)
    end
end

-- ---------------------------------------------------------------------------
-- Event-driven bot registry. One initial scan only; no Workspace:GetDescendants()
-- polling loop, which keeps the practice Combat much lighter than older layers.
-- ---------------------------------------------------------------------------
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
local function registerModel(model)
    if isBot(model) then bots[model]=true end
end
for _,d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerModel(d.Parent) end
end
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerModel,d.Parent)
    elseif d:IsA("Model") then task.defer(registerModel,d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Model") then bots[d]=nil
    elseif d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
end)

local function aimPart(model,name)
    if not model then return nil end
    if name=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function visible(model,part)
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
local function referencePoint()
    local cam=Workspace.CurrentCamera
    if not cam then return Vector2.zero end
    local aimed=false
    if GunPlugin and type(GunPlugin.IsAimed)=="function" then
        local ok,v=pcall(function() return GunPlugin:IsAimed() end)
        aimed=ok and v==true
    end
    if aimed then return cam.ViewportSize/2 end
    local UIS=game:GetService("UserInputService")
    if UIS.MouseBehavior==Enum.MouseBehavior.LockCenter then return cam.ViewportSize/2 end
    local m=UIS:GetMouseLocation()
    return Vector2.new(m.X,m.Y)
end

-- ---------------------------------------------------------------------------
-- HITBOX ASSIST: enlarges the acquisition area on-screen, but redirects the shot
-- to the bot's real Head/Torso. No physical Player hitbox is changed.
-- ---------------------------------------------------------------------------
removeOption("HitBoxes")
local hitboxEnabled=false
local hitboxPartName="Head"
local hitboxRadius=95
local hitboxWall=true
local hitboxDistance=1800

local function hitboxTarget()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local ref=referencePoint()
    local best,bestPart,bestPx=nil,nil,hitboxRadius
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,hitboxPartName)
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=hitboxDistance and (not hitboxWall or visible(model,part)) then
                local p,on=cam:WorldToViewportPoint(part.Position)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-ref).Magnitude
                    if px<bestPx then best,bestPart,bestPx=model,part,px end
                end
            end
        end
    end
    return best,bestPart
end

if GunPlugin and type(GunPlugin.GetWorldLookAtPos)=="function" then
    local previousGetWorldLookAtPos=GunPlugin.GetWorldLookAtPos
    GunPlugin.GetWorldLookAtPos=function(self,...)
        if hitboxEnabled then
            local model,part=hitboxTarget()
            if model and part then
                shared.YokaiGunTestingLastAimPart={Part=part.Name,At=os.clock(),Model=model}
                return part.Position
            end
        end
        return previousGetWorldLookAtPos(self,...)
    end
end

local HitBoxes=Combat.CreateOptionsButton({Name="HitBoxes",Function=function(v) hitboxEnabled=v end,HoverText="Bots only: expands the on-screen acquisition radius and returns the real bot body part."})
HitBoxes.CreateDropdown({Name="Part",List={"Head","Torso"},Function=function(v) hitboxPartName=v end})
HitBoxes.CreateSlider({Name="Size",Min=20,Max=260,Default=95,Function=function(v) hitboxRadius=v end})
HitBoxes.CreateToggle({Name="WallCheck",Default=true,Function=function(v) hitboxWall=v end})
HitBoxes.CreateSlider({Name="Distance",Min=100,Max=4000,Default=1800,Function=function(v) hitboxDistance=v end})

-- ---------------------------------------------------------------------------
-- SHOT / AMMO SIGNALS shared by No Recoil and Infinite Ammo.
-- Gun Testing exposes BulletsInMagazine/BulletsInReserve in local GunInventory.
-- ---------------------------------------------------------------------------
local watchedAmmo=setmetatable({}, {__mode="k"})
local ammoValues=setmetatable({}, {__mode="k"})
local noRecoilEnabled=false
local noRecoilStrength=1
local recoilUntil=0
local recoilBase=nil
local lastCam=nil

local function ammoName(name)
    local n=clean(name):lower():gsub("[%s_%-]","")
    return n=="bulletsinmagazine" or n=="bulletsinreserve" or n=="magammo" or n=="ammo" or n=="reserveammo" or n=="currentammo"
end
local function watchAmmo(obj)
    if not obj or watchedAmmo[obj] then return end
    if not (obj:IsA("IntValue") or obj:IsA("NumberValue")) or not ammoName(obj.Name) then return end
    watchedAmmo[obj]=true; ammoValues[obj]=true
    local prev=tonumber(obj.Value) or 0
    obj:GetPropertyChangedSignal("Value"):Connect(function()
        local now=tonumber(obj.Value) or prev
        if now<prev and noRecoilEnabled then
            recoilBase=lastCam or (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame)
            recoilUntil=os.clock()+.10
        end
        prev=now
    end)
end
local function scanAmmoRoot(root)
    if not root then return end
    if root:IsA("IntValue") or root:IsA("NumberValue") then watchAmmo(root) end
    for _,d in ipairs(root:GetDescendants()) do watchAmmo(d) end
    root.DescendantAdded:Connect(function(d) task.defer(watchAmmo,d) end)
end
scanAmmoRoot(LocalPlayer:FindFirstChild("GunInventory"))
scanAmmoRoot(LocalPlayer:FindFirstChildOfClass("Backpack"))
scanAmmoRoot(LocalPlayer.Character)
LocalPlayer.CharacterAdded:Connect(function(c) task.defer(scanAmmoRoot,c) end)
LocalPlayer.ChildAdded:Connect(function(c) if c.Name=="GunInventory" or c:IsA("Backpack") then task.defer(scanAmmoRoot,c) end end)

-- ---------------------------------------------------------------------------
-- NO RECOIL: local camera pitch stabilization for the short interval after the
-- magazine counter decreases. It preserves current yaw so aiming remains usable.
-- ---------------------------------------------------------------------------
removeOption("No Recoil")
local NoRecoil=Combat.CreateOptionsButton({Name="No Recoil",Function=function(v) noRecoilEnabled=v if not v then recoilUntil=0 recoilBase=nil end end,HoverText="Local recoil stabilizer driven by the gun's magazine decrease."})
NoRecoil.CreateSlider({Name="Strength",Min=0,Max=100,Default=100,Function=function(v) noRecoilStrength=v/100 end})

RunService:BindToRenderStep("YokaiGunTestingNoRecoilV16",Enum.RenderPriority.Last.Value+650,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if noRecoilEnabled and recoilBase and os.clock()<recoilUntil then
        local current=cam.CFrame
        local bx=select(1,recoilBase:ToOrientation())
        local _,cy,cz=current:ToOrientation()
        local goal=CFrame.new(current.Position)*CFrame.fromOrientation(bx,cy,cz)
        cam.CFrame=current:Lerp(goal,math.clamp(noRecoilStrength,0,1))
    else
        lastCam=cam.CFrame
    end
end)

-- ---------------------------------------------------------------------------
-- INFINITE AMMO: local refill only. If a server owns ammo authoritatively it may
-- overwrite these values; no RemoteEvent is fired to bypass that validation.
-- ---------------------------------------------------------------------------
removeOption("Infinite Ammo")
local infiniteEnabled=false
local refillAmount=999
local Infinite=Combat.CreateOptionsButton({Name="Infinite Ammo",Function=function(v) infiniteEnabled=v end,HoverText="Refills local GunInventory/tool ammo values; server-authoritative ammo can still override it."})
Infinite.CreateSlider({Name="Amount",Min=30,Max=999,Default=999,Function=function(v) refillAmount=v end})

task.spawn(function()
    while shared.YokaiExecuted~=false do
        if infiniteEnabled then
            for obj in pairs(ammoValues) do
                if obj and obj.Parent then
                    pcall(function() if tonumber(obj.Value) and obj.Value<refillAmount then obj.Value=refillAmount end end)
                else ammoValues[obj]=nil end
            end
            task.wait(.10)
        else
            task.wait(.35)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- ANTIAIM: local visual practice pose only. It modifies Motor6D.Transform late in
-- the render pipeline and does not spoof remotes/network ownership.
-- ---------------------------------------------------------------------------
removeOption("AntiAim")
local antiEnabled=false
local antiMode="Jitter"
local antiSpeed=8
local antiAngle=35
local joints=setmetatable({}, {__mode="k"})
local function collectJoints(char)
    table.clear(joints)
    if not char then return end
    for _,d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and (d.Name=="Waist" or d.Name=="RootJoint" or d.Name=="Neck") then joints[d]=true end
    end
end
collectJoints(LocalPlayer.Character)
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(.4) collectJoints(c) end)

local AntiAim=Combat.CreateOptionsButton({Name="AntiAim",Function=function(v)
    antiEnabled=v
    if not v then for j in pairs(joints) do if j and j.Parent then pcall(function() j.Transform=CFrame.identity end) end end end
end,HoverText="Local visual practice pose; does not alter server aim validation."})
AntiAim.CreateDropdown({Name="Mode",List={"Jitter","Spin","Backwards"},Function=function(v) antiMode=v end})
AntiAim.CreateSlider({Name="Speed",Min=1,Max=20,Default=8,Function=function(v) antiSpeed=v end})
AntiAim.CreateSlider({Name="Angle",Min=10,Max=90,Default=35,Function=function(v) antiAngle=v end})

RunService:BindToRenderStep("YokaiGunTestingAntiAimV16",Enum.RenderPriority.Last.Value+700,function()
    if not antiEnabled then return end
    local yaw=0
    if antiMode=="Backwards" then yaw=math.pi
    elseif antiMode=="Spin" then yaw=os.clock()*antiSpeed
    else yaw=math.rad(antiAngle)*((math.floor(os.clock()*antiSpeed)%2==0) and 1 or -1) end
    for j in pairs(joints) do
        if j and j.Parent then pcall(function() j.Transform=CFrame.Angles(0,yaw,0) end) else joints[j]=nil end
    end
end)

-- ---------------------------------------------------------------------------
-- Keep exactly the requested Combat rows and pin them in a deterministic order.
-- The first three are provided by GunTestingPluginIntegrationV3.
-- ---------------------------------------------------------------------------
local requested={"SilentAim","Magic Bullets","No Recoil","Infinite Ammo","HitBoxes","Aimbot","AntiAim"}
local keep={}
for _,n in ipairs(requested) do keep[n]=true end

-- Remove any legacy row that appeared late between reset and this final pass.
local removeKeys={}
for key,rec in pairs(objects) do
    if rec and rec.Type=="OptionsButton" and under(rec) then
        local n=optionName(key,rec)
        if not keep[n] then table.insert(removeKeys,key) end
    end
end
for _,key in ipairs(removeKeys) do
    local rec=objects[key]
    pcall(function() if rec and rec.Api and rec.Api.Enabled and rec.Api.ToggleButton then rec.Api.ToggleButton(false) end end)
    pcall(function() GuiLibrary.RemoveObject(key) end)
end

local function pinOrder()
    for i,name in ipairs(requested) do
        local _,rec=findOption(name)
        if rec and rec.Object and rec.Object:IsA("GuiObject") then
            rec.Object.Visible=true
            rec.Object.LayoutOrder=i
        end
    end
end
pinOrder(); task.defer(pinOrder); task.delay(.2,pinOrder); task.delay(.8,pinOrder)

shared.YokaiGunTestingCombatFinalV16=true
