-- Final UX layer for the owner's NPC-only practice map.
-- Replaces the bot Aimbot/BulletTracer UI so the FOV circle and shot visuals share one state.
-- No metamethod/namecall hooks. Player characters are always excluded from targeting/state.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local VisualsRec = objects["VisualsWindow"]
local WorldRec = objects["WorldWindow"]
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
local function removeOption(parentRec,name)
    local keys={}
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

pcall(function() RunService:UnbindFromRenderStep("YokaiOwnerBotV2Aimbot") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiOwnerBotV3Aimbot") end)
removeOption(CombatRec,"Aimbot")
removeOption(WorldRec,"BulletTracer")
removeOption(VisualsRec,"Custom Crosshair")

-- --------------------------------------------------------------------------
-- NPC registry
-- --------------------------------------------------------------------------
local function playerOwned(model)
    if not model or not model:IsA("Model") then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then
            return true
        end
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
local botConns={}
local botRoot=Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots") or Workspace
local hitFlashUntil=0
local lastShotEvidence=0
local lastShotBot=nil

local function visibleBot(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local filter={cam}
    if LocalPlayer.Character then table.insert(filter,LocalPlayer.Character) end
    rp.FilterDescendantsInstances=filter
    rp.IgnoreWater=true
    local res=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return res==nil or (res.Instance and res.Instance:IsDescendantOf(model))
end

local function nearestBot(radius,partName,requireVisible,maxDistance)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best,bestPart,bestPx=nil,nil,radius
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=(partName=="Head" and model:FindFirstChild("Head")) or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root
            if root and part and (root.Position-cam.CFrame.Position).Magnitude<=maxDistance then
                local p,on=cam:WorldToViewportPoint(part.Position)
                if on and p.Z>0 then
                    local px=(Vector2.new(p.X,p.Y)-center).Magnitude
                    if px<bestPx and (not requireVisible or visibleBot(model,part)) then
                        best,bestPart,bestPx=model,part,px
                    end
                end
            end
        end
    end
    return best,bestPart,bestPx
end

local function registerBot(model)
    if not isBot(model) then return end
    bots[model]=true
    if botConns[model] then return end
    local hum=humanoidOf(model)
    local prev=hum and hum.Health or 0
    if hum then
        botConns[model]=hum.HealthChanged:Connect(function(v)
            if v<prev and os.clock()-lastShotEvidence<.75 and (lastShotBot==nil or lastShotBot==model) then
                hitFlashUntil=os.clock()+.22
            end
            prev=v
        end)
    end
end
local function unregisterBot(model)
    bots[model]=nil
    local c=botConns[model]
    if c then c:Disconnect() botConns[model]=nil end
end
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
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(unregisterBot,d.Parent) end
end)

-- --------------------------------------------------------------------------
-- Shared HUD: visible FOV + animated custom crosshair
-- --------------------------------------------------------------------------
local parentGui=(gethui and gethui()) or CoreGui
local old=parentGui:FindFirstChild("YokaiOwnerBotAimUXV3")
if old then old:Destroy() end
local Hud=Instance.new("ScreenGui")
Hud.Name="YokaiOwnerBotAimUXV3"
Hud.ResetOnSpawn=false
Hud.IgnoreGuiInset=true
Hud.DisplayOrder=1002
Hud.Parent=parentGui

local FovRing=Instance.new("Frame")
FovRing.Name="FOV"
FovRing.AnchorPoint=Vector2.new(.5,.5)
FovRing.BackgroundTransparency=1
FovRing.Visible=false
FovRing.Parent=Hud
local fovCorner=Instance.new("UICorner")
fovCorner.CornerRadius=UDim.new(1,0)
fovCorner.Parent=FovRing
local fovStroke=Instance.new("UIStroke")
fovStroke.Thickness=1.25
fovStroke.Transparency=.2
fovStroke.Color=Color3.fromRGB(110,180,255)
fovStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
fovStroke.Parent=FovRing

local CrossRoot=Instance.new("Frame")
CrossRoot.Name="Crosshair"
CrossRoot.AnchorPoint=Vector2.new(.5,.5)
CrossRoot.Size=UDim2.fromOffset(1,1)
CrossRoot.BackgroundTransparency=1
CrossRoot.Visible=false
CrossRoot.Parent=Hud
local crossLines={}
for i=1,4 do
    local f=Instance.new("Frame")
    f.Name="Line"..i
    f.BorderSizePixel=0
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BackgroundColor3=Color3.fromRGB(210,235,255)
    f.Parent=CrossRoot
    crossLines[i]=f
end
local centerDot=Instance.new("Frame")
centerDot.Name="Dot"
centerDot.AnchorPoint=Vector2.new(.5,.5)
centerDot.Size=UDim2.fromOffset(2,2)
centerDot.BorderSizePixel=0
centerDot.BackgroundColor3=Color3.fromRGB(210,235,255)
centerDot.Parent=CrossRoot
local dotCorner=Instance.new("UICorner")
dotCorner.CornerRadius=UDim.new(1,0)
dotCorner.Parent=centerDot

local aimEnabled=false
local aimFov=320
local aimPartName="Head"
local aimSmooth=.9
local aimWall=true
local aimPrediction=true
local aimDistance=1800
local showFov=true
local fovColor=Color3.fromRGB(110,180,255)

local crossEnabled=true
local crossAnimated=true
local crossWall=true
local crossGap=6
local crossLength=8
local crossThickness=1
local crossSpeed=5
local crossBase=Color3.fromRGB(205,225,255)
local crossVisible=Color3.fromRGB(70,235,170)
local crossOccluded=Color3.fromRGB(220,105,105)
local crossHit=Color3.fromRGB(255,70,70)

local Aimbot=Combat.CreateOptionsButton({
    ["Name"]="Aimbot",
    ["Function"]=function(v) aimEnabled=v end,
    ["HoverText"]="NPC-only aim assist. FOV circle matches the configured pixel radius.",
})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=900,["Default"]=320,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Precision",["Min"]=10,["Max"]=100,["Default"]=90,["Function"]=function(v) aimSmooth=v/100 end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Distance",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) aimDistance=v end})
Aimbot.CreateToggle({["Name"]="Show FOV",["Default"]=true,["Function"]=function(v) showFov=v end})
Aimbot.CreateColorSlider({["Name"]="FOV Color",["Function"]=function(h,s,v) fovColor=Color3.fromHSV(h,s,v) end})

local Crosshair=Visuals.CreateOptionsButton({
    ["Name"]="Custom Crosshair",
    ["Function"]=function(v) crossEnabled=v end,
    ["HoverText"]="Animated center crosshair for NPC practice; flashes red on confirmed bot damage.",
})
Crosshair.CreateToggle({["Name"]="Animated",["Default"]=true,["Function"]=function(v) crossAnimated=v end})
Crosshair.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) crossWall=v end})
Crosshair.CreateSlider({["Name"]="Gap",["Min"]=2,["Max"]=20,["Default"]=6,["Function"]=function(v) crossGap=v end})
Crosshair.CreateSlider({["Name"]="Length",["Min"]=4,["Max"]=24,["Default"]=8,["Function"]=function(v) crossLength=v end})
Crosshair.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=4,["Default"]=1,["Function"]=function(v) crossThickness=v end})
Crosshair.CreateSlider({["Name"]="Animation Speed",["Min"]=1,["Max"]=12,["Default"]=5,["Function"]=function(v) crossSpeed=v end})
Crosshair.CreateColorSlider({["Name"]="Base Color",["Function"]=function(h,s,v) crossBase=Color3.fromHSV(h,s,v) end})
Crosshair.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) crossVisible=Color3.fromHSV(h,s,v) end})
Crosshair.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) crossOccluded=Color3.fromHSV(h,s,v) end})

RunService:BindToRenderStep("YokaiOwnerBotV3Aimbot",Enum.RenderPriority.Camera.Value+70,function(dt)
    local cam=Workspace.CurrentCamera
    if not cam then return end

    local center=cam.ViewportSize/2
    FovRing.Position=UDim2.fromOffset(center.X,center.Y)
    FovRing.Size=UDim2.fromOffset(aimFov*2,aimFov*2)
    FovRing.Visible=aimEnabled and showFov
    fovStroke.Color=fovColor

    CrossRoot.Position=UDim2.fromOffset(center.X,center.Y)
    CrossRoot.Visible=crossEnabled

    local nearModel,nearPart=nearestBot(math.max(90,math.min(aimFov,180)),"Head",false,aimDistance)
    local col=crossBase
    if crossWall and nearModel and nearPart then
        col=visibleBot(nearModel,nearPart) and crossVisible or crossOccluded
    end
    if os.clock()<hitFlashUntil then col=crossHit end

    local pulse=crossAnimated and (math.sin(os.clock()*crossSpeed)*1.6) or 0
    local gap=math.max(1,crossGap+pulse)
    local len=math.max(2,crossLength+(crossAnimated and math.cos(os.clock()*crossSpeed*.75)*.7 or 0))
    local t=math.max(1,crossThickness)
    local specs={
        {UDim2.fromOffset(-(gap+len/2),0),UDim2.fromOffset(len,t)},
        {UDim2.fromOffset((gap+len/2),0),UDim2.fromOffset(len,t)},
        {UDim2.fromOffset(0,-(gap+len/2)),UDim2.fromOffset(t,len)},
        {UDim2.fromOffset(0,(gap+len/2)),UDim2.fromOffset(t,len)},
    }
    for i,f in ipairs(crossLines) do
        f.Position=specs[i][1]
        f.Size=specs[i][2]
        f.BackgroundColor3=col
    end
    centerDot.BackgroundColor3=col

    if aimEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local model,part=nearestBot(aimFov,aimPartName,aimWall,aimDistance)
        if model and part then
            local pos=part.Position
            if aimPrediction then
                local root=rootOf(model)
                if root then
                    local distance=(root.Position-cam.CFrame.Position).Magnitude
                    pos += root.AssemblyLinearVelocity*math.clamp(distance/2500,0,.35)
                end
            end
            local goal=CFrame.lookAt(cam.CFrame.Position,pos)
            local alpha=math.clamp(aimSmooth*math.max(1,dt*60),.08,1)
            cam.CFrame=cam.CFrame:Lerp(goal,alpha)
        end
    end
end)

-- --------------------------------------------------------------------------
-- Persistent shot-driven BulletTracer
-- --------------------------------------------------------------------------
local tracerEnabled=false
local tracerColor=Color3.fromRGB(255,255,255)
local tracerMaterial="Neon"
local tracerLifetime=.35
local tracerThickness=.045
local tracerRange=1800
local tracerLast=0
local tracerActive={}
local watched=setmetatable({}, {__mode="k"})
local ammoLast=setmetatable({}, {__mode="k"})
local attrLast=setmetatable({}, {__mode="k"})
local mouseDown=false
local recentTrigger=0

local mats={Neon=Enum.Material.Neon,ForceField=Enum.Material.ForceField,Glass=Enum.Material.Glass,Metal=Enum.Material.Metal,SmoothPlastic=Enum.Material.SmoothPlastic}
local muzzleWords={"muzzle","barrel","firepoint","fire_point","muzzlepoint","muzzleflash","shootpoint","shotorigin","tip"}
local ammoWords={"ammo","clip","mag","magazine","bullet","round"}
local shotWords={"shot","shoot","fire","gunshot","rifle","pistol","smg","revolver","sniper","shotgun","muzzle"}
local impactWords={"bullethole","bullet_hole","impact","hit","projectile","tracer"}

local function contains(name,words)
    local n=string.lower(tostring(name))
    for _,w in ipairs(words) do if n:find(w,1,true) then return true end end
    return false
end

local function weaponRoots()
    local out,seen={},{}
    local function add(x)
        if x and not seen[x] then seen[x]=true table.insert(out,x) end
    end
    add(LocalPlayer.Character)
    add(LocalPlayer:FindFirstChildOfClass("Backpack"))
    add(Workspace.CurrentCamera)
    add(Workspace:FindFirstChild("WeaponSystem_Workspace"))
    add(Workspace:FindFirstChild("BulletHoles"))
    return out
end

local function muzzlePos()
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local best,bestScore=nil,nil
    for _,root in ipairs(weaponRoots()) do
        if root then
            for _,obj in ipairs(root:GetDescendants()) do
                if (obj:IsA("Attachment") or obj:IsA("BasePart")) and contains(obj.Name,muzzleWords) then
                    local p=obj:IsA("Attachment") and obj.WorldPosition or obj.Position
                    local score=(p-cam.CFrame.Position):Dot(cam.CFrame.LookVector)
                    if bestScore==nil or score>bestScore then best,bestScore=p,score end
                end
            end
        end
    end
    if best then return best end
    return cam.CFrame.Position+cam.CFrame.LookVector*2.1+cam.CFrame.RightVector*.35-cam.CFrame.UpVector*.25
end

local function centerDestination(origin)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local ray=cam:ViewportPointToRay(center.X,center.Y)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=false
    local res=Workspace:Raycast(origin,ray.Direction.Unit*tracerRange,rp)
    return res and res.Position or origin+ray.Direction.Unit*tracerRange
end

local function drawTracer(finish)
    if not tracerEnabled then return end
    local now=os.clock()
    if now-tracerLast<.028 then return end
    local origin=muzzlePos()
    if not origin then return end
    finish=finish or centerDestination(origin)
    if not finish then return end
    local d=finish-origin
    if d.Magnitude<.1 then return end
    tracerLast=now
    lastShotEvidence=now
    local model=nearestBot(math.max(aimFov,220),"Head",false,aimDistance)
    lastShotBot=model

    while #tracerActive>=18 do
        local oldPart=table.remove(tracerActive,1)
        if oldPart and oldPart.Parent then oldPart:Destroy() end
    end
    local p=Instance.new("Part")
    p.Name="YokaiPersistentBulletTracer"
    p.Anchored=true
    p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
    p.Material=mats[tracerMaterial] or Enum.Material.Neon
    p.Color=tracerColor
    p.Transparency=.03
    p.Size=Vector3.new(tracerThickness,tracerThickness,d.Magnitude)
    p.CFrame=CFrame.lookAt((origin+finish)/2,finish)
    p.Parent=Workspace
    table.insert(tracerActive,p)
    task.delay(tracerLifetime,function() if p and p.Parent then p:Destroy() end end)
end

local function signalShot(finish)
    recentTrigger=os.clock()
    drawTracer(finish)
end

local function impactPosition(obj)
    if obj:IsA("Attachment") then return obj.WorldPosition end
    if obj:IsA("BasePart") then return obj.Position end
    return nil
end

local function hookObj(obj)
    if watched[obj] then return end

    if obj:IsA("Sound") and contains(obj.Name,shotWords) then
        watched[obj]=obj.Played:Connect(function() signalShot() end)
        return
    end

    if obj:IsA("ParticleEmitter") and contains(obj.Name,{"muzzle","flash","fire","shot"}) then
        local ok,sig=pcall(function() return obj.OnEmitRequested end)
        if ok and typeof(sig)=="RBXScriptSignal" then
            watched[obj]=sig:Connect(function() signalShot() end)
        else
            watched[obj]=obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                if obj.Enabled then signalShot() end
            end)
        end
        return
    end

    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
        if contains(obj.Name,ammoWords) then
            ammoLast[obj]=tonumber(obj.Value)
            watched[obj]=obj.Changed:Connect(function(v)
                local n=tonumber(v)
                local oldv=ammoLast[obj]
                ammoLast[obj]=n
                if n and oldv and n<oldv then signalShot() end
            end)
        end
        return
    end

    local attrs=obj:GetAttributes()
    local hasAmmoAttr=false
    for name,v in pairs(attrs) do
        if type(v)=="number" and contains(name,ammoWords) then hasAmmoAttr=true break end
    end
    if hasAmmoAttr then
        attrLast[obj]={}
        for name,v in pairs(attrs) do
            if type(v)=="number" and contains(name,ammoWords) then
                attrLast[obj][name]=v
                obj:GetAttributeChangedSignal(name):Connect(function()
                    local n=obj:GetAttribute(name)
                    local oldv=attrLast[obj] and attrLast[obj][name]
                    if attrLast[obj] then attrLast[obj][name]=n end
                    if type(n)=="number" and type(oldv)=="number" and n<oldv then signalShot() end
                end)
            end
        end
        watched[obj]=true
    end
end

local function watchRoot(root)
    if not root then return end
    for _,d in ipairs(root:GetDescendants()) do hookObj(d) end
    if watched[root] then return end
    watched[root]=root.DescendantAdded:Connect(function(d)
        hookObj(d)
        if tracerEnabled and contains(d.Name,impactWords) and (mouseDown or os.clock()-recentTrigger<.18) then
            local pos=impactPosition(d)
            if pos then signalShot(pos) end
        end
    end)
end

for _,r in ipairs(weaponRoots()) do watchRoot(r) end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(function() watchRoot(Workspace.CurrentCamera) end)
end)

local rescan=0
RunService.Heartbeat:Connect(function(dt)
    rescan+=dt
    if rescan<.5 then return end
    rescan=0
    for _,r in ipairs(weaponRoots()) do watchRoot(r) end
end)

UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        mouseDown=true
        recentTrigger=os.clock()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then mouseDown=false end
end)

local BulletTracer=World.CreateOptionsButton({
    ["Name"]="BulletTracer",
    ["Function"]=function(v)
        tracerEnabled=v
        if not v then
            for _,p in ipairs(tracerActive) do if p and p.Parent then p:Destroy() end end
            table.clear(tracerActive)
        else
            for _,r in ipairs(weaponRoots()) do watchRoot(r) end
        end
    end,
    ["HoverText"]="Persistent local tracer: listens for ammo, fire sound, muzzle and impact evidence on every shot.",
})
BulletTracer.CreateDropdown({["Name"]="Material",["List"]={"Neon","ForceField","Glass","Metal","SmoothPlastic"},["Function"]=function(v) tracerMaterial=v end})
BulletTracer.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({["Name"]="Lifetime",["Min"]=1,["Max"]=15,["Default"]=4,["Function"]=function(v) tracerLifetime=v/10 end})
BulletTracer.CreateSlider({["Name"]="Thickness",["Min"]=2,["Max"]=15,["Default"]=5,["Function"]=function(v) tracerThickness=v/100 end})
BulletTracer.CreateSlider({["Name"]="Range",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) tracerRange=v end})

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Bot FOV, animated crosshair and persistent BulletTracer loaded",4) end)
