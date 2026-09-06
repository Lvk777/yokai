-- Gun Testing map-specific bot aim + local viewmodel cosmetics.
-- Bot targeting only: every target candidate is rejected if it belongs to a Player.
-- No RemoteEvent hooks, ban-evasion, or anti-cheat bypass.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local CombatRec = objects["CombatWindow"]
local VisualsRec = objects["VisualsWindow"]
local RenderRec = objects["RenderWindow"]
local Combat = CombatRec and CombatRec.Api
local Visuals = VisualsRec and VisualsRec.Api
if not Combat or not Visuals then return end

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
local function findOption(parentRec,name)
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then return rec end
    end
end

-- ============================================================================
-- Bot discovery. Characters belonging to any Player are rejected, including wrappers.
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
    local nextSet={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then nextSet[obj]=true end
    end
    bots=nextSet
end
rescanBots()
task.spawn(function()
    while shared.YokaiExecuted ~= false do
        task.wait(.55)
        rescanBots()
    end
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
local function predictedPosition(model,part,prediction,bulletSpeed)
    if not prediction then return part.Position end
    local cam=Workspace.CurrentCamera
    local root=rootOf(model)
    if not cam or not root then return part.Position end
    local dist=(cam.CFrame.Position-part.Position).Magnitude
    local lead=math.clamp(dist/math.max(100,bulletSpeed),0,.30)
    local velocity=root.AssemblyLinearVelocity
    return part.Position + velocity*lead
end
local function nearestBot(maxPixels,maxStuds,partName,wallCheck,prediction,bulletSpeed,current)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local mouse=UserInputService:GetMouseLocation()
    local function score(model)
        if not isBot(model) then return nil end
        local root=rootOf(model)
        local part=aimPart(model,partName)
        if not root or not part then return nil end
        local studs=(cam.CFrame.Position-root.Position).Magnitude
        if studs>(maxStuds or math.huge) then return nil end
        if wallCheck and not visible(model,part) then return nil end
        local targetPos=predictedPosition(model,part,prediction,bulletSpeed)
        local p,on=cam:WorldToViewportPoint(targetPos)
        if not on or p.Z<=0 then return nil end
        local px=(Vector2.new(p.X,p.Y)-mouse).Magnitude
        if px>(maxPixels or math.huge) then return nil end
        return px,part,targetPos
    end
    if current then
        local px,part,pos=score(current)
        if px and px<=(maxPixels or math.huge)*1.30 then return current,part,pos,px end
    end
    local best,bestPart,bestPos,bestPx=nil,nil,nil,maxPixels or math.huge
    for model in pairs(bots) do
        local px,part,pos=score(model)
        if px and px<bestPx then best,bestPart,bestPos,bestPx=model,part,pos,px end
    end
    return best,bestPart,bestPos,bestPx
end

-- ============================================================================
-- Aggressive bot-only Aimbot. Runs after the game's camera/ADS controller.
-- ============================================================================
removeOption(CombatRec,"Aimbot")
pcall(function() RunService:UnbindFromRenderStep("YokaiBotAimbot") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiGunTestingAimbotV2") end)

local aimEnabled=false
local aimFov=420
local aimAggression=88
local aimPartName="Head"
local aimWall=true
local aimActivation="Mouse2"
local aimPrediction=true
local aimBulletSpeed=1400
local aimDistance=1800
local aimSticky=true
local lockedTarget=nil

local Aimbot=Combat.CreateOptionsButton({
    ["Name"]="Aimbot",
    ["Function"]=function(v) aimEnabled=v if not v then lockedTarget=nil end end,
    ["HoverText"]="Gun Testing bot-only aim. Player characters are excluded.",
})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=1000,["Default"]=420,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Aggressiveness",["Min"]=1,["Max"]=100,["Default"]=88,["Function"]=function(v) aimAggression=v end})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v lockedTarget=nil end})
Aimbot.CreateDropdown({["Name"]="Activation",["List"]={"Mouse2","Mouse1","Always"},["Function"]=function(v) aimActivation=v end})
Aimbot.CreateToggle({["Name"]="Sticky Target",["Default"]=true,["Function"]=function(v) aimSticky=v if not v then lockedTarget=nil end end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})
Aimbot.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) aimPrediction=v end})
Aimbot.CreateSlider({["Name"]="Prediction Speed",["Min"]=300,["Max"]=3000,["Default"]=1400,["Function"]=function(v) aimBulletSpeed=v end})
Aimbot.CreateSlider({["Name"]="Max Distance",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) aimDistance=v end})

local function activationDown()
    if aimActivation=="Always" then return true end
    if aimActivation=="Mouse1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

RunService:BindToRenderStep("YokaiGunTestingAimbotV2",Enum.RenderPriority.Last.Value+120,function(dt)
    if not aimEnabled or not activationDown() then lockedTarget=nil return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local model,_,pos=nearestBot(aimFov,aimDistance,aimPartName,aimWall,aimPrediction,aimBulletSpeed,aimSticky and lockedTarget or nil)
    if not model or not pos then lockedTarget=nil return end
    if aimSticky then lockedTarget=model end
    local desired=CFrame.lookAt(cam.CFrame.Position,pos)
    local alpha=math.clamp((aimAggression/100)*math.max(1,dt*60),.02,1)
    if aimAggression>=98 then alpha=1 end
    cam.CFrame=cam.CFrame:Lerp(desired,alpha)
end)

-- ============================================================================
-- Bot-only SilentAim attempt: high-priority pre-shot camera correction, restored quickly.
-- This avoids remote/metatable hooks and works only if the gun samples camera direction
-- during the input/fire frame. Player characters are never selected.
-- ============================================================================
removeOption(CombatRec,"SilentAim")
pcall(function() ContextActionService:UnbindAction("YokaiBotSilentAimPreShot") end)
local silentEnabled=false
local silentFov=500
local silentPartName="Head"
local silentWall=true
local silentPrediction=true
local silentBulletSpeed=1400
local silentDistance=1800
local silentRestoreToken=0

local SilentAim=Combat.CreateOptionsButton({
    ["Name"]="SilentAim",
    ["Function"]=function(v) silentEnabled=v end,
    ["HoverText"]="Bot-only pre-shot correction; no Player targets or remote hooks.",
})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=1000,["Default"]=500,["Function"]=function(v) silentFov=v end})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPartName=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWall=v end})
SilentAim.CreateToggle({["Name"]="Prediction",["Default"]=true,["Function"]=function(v) silentPrediction=v end})
SilentAim.CreateSlider({["Name"]="Prediction Speed",["Min"]=300,["Max"]=3000,["Default"]=1400,["Function"]=function(v) silentBulletSpeed=v end})

ContextActionService:BindActionAtPriority("YokaiBotSilentAimPreShot",function(_,state)
    if state~=Enum.UserInputState.Begin or not silentEnabled or aimEnabled then return Enum.ContextActionResult.Pass end
    local cam=Workspace.CurrentCamera
    if not cam then return Enum.ContextActionResult.Pass end
    local _,_,pos=nearestBot(silentFov,silentDistance,silentPartName,silentWall,silentPrediction,silentBulletSpeed,nil)
    if not pos then return Enum.ContextActionResult.Pass end
    silentRestoreToken+=1
    local token=silentRestoreToken
    local before=cam.CFrame
    cam.CFrame=CFrame.lookAt(before.Position,pos)
    task.delay(.045,function()
        if token==silentRestoreToken and cam and cam.Parent and silentEnabled then
            cam.CFrame=before
        end
    end)
    return Enum.ContextActionResult.Pass
end,false,3000,Enum.UserInputType.MouseButton1)

-- ============================================================================
-- Viewmodel detection for this map: Workspace.CurrentCamera contains a Rig.
-- GunChams styles every visible viewmodel piece that is not classified as an arm.
-- SelfChams styles explicit arms + lower side geometry / body-color matches.
-- ============================================================================
removeOption(VisualsRec,"SelfChams")
removeOption(VisualsRec,"GunChams")
for _,bind in ipairs({"YokaiUniversalArmChams","YokaiGunChamsExact","YokaiGunTestingViewmodelV2"}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end

local materialMap={ForceField=Enum.Material.ForceField,Neon=Enum.Material.Neon,SmoothPlastic=Enum.Material.SmoothPlastic,Glass=Enum.Material.Glass,Foil=Enum.Material.Foil,Metal=Enum.Material.Metal,Plastic=Enum.Material.Plastic}
local materialList={"ForceField","Neon","SmoothPlastic","Glass","Foil","Metal","Plastic"}
local armWords={"arm","hand","forearm","wrist","glove","sleeve","skin","leftarm","rightarm","left_arm","right_arm","lefthand","righthand"}
local helperWords={"root","camera","origin","pivot","helper","hitbox","collider","collision","aimpart","aim_part","proxy","invisible","muzzleflash","flash"}
local function contains(name,list)
    local n=tostring(name):lower()
    for _,w in ipairs(list) do if n:find(w,1,true) then return true end end
    return false
end
local function ancestorContains(part,list,depth)
    local cur=part.Parent
    for _=1,(depth or 4) do
        if not cur or cur==Workspace.CurrentCamera then break end
        if contains(cur.Name,list) then return true end
        cur=cur.Parent
    end
    return false
end
local function visiblePart(part)
    return part:IsA("BasePart") and part.Transparency<.97 and part.LocalTransparencyModifier<.97 and part.Size.Magnitude>.08
end
local function characterArmColors()
    local colors={}
    local char=LocalPlayer.Character
    if not char then return colors end
    for _,name in ipairs({"LeftHand","RightHand","LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","Left Arm","Right Arm"}) do
        local p=char:FindFirstChild(name)
        if p and p:IsA("BasePart") then table.insert(colors,p.Color) end
    end
    return colors
end
local function closeColor(a,b)
    local dr=a.R-b.R local dg=a.G-b.G local db=a.B-b.B
    return math.sqrt(dr*dr+dg*dg+db*db)<.16
end
local function onLowerSide(part)
    local cam=Workspace.CurrentCamera
    if not cam then return false,false end
    local p,on=cam:WorldToViewportPoint(part.Position)
    if not on or p.Z<=0 then return false,false end
    local vp=cam.ViewportSize
    local x,y=p.X/vp.X,p.Y/vp.Y
    return y>.47 and (x<.47 or x>.53), y>.62
end
local function isArmPiece(part,colors)
    if contains(part.Name,armWords) or ancestorContains(part,armWords,4) then return true end
    local side,deep=onLowerSide(part)
    if not side and not deep then return false end
    for _,c in ipairs(colors) do if closeColor(part.Color,c) then return true end end
    local longest=math.max(part.Size.X,part.Size.Y,part.Size.Z)
    return side and deep and longest>=.65 and longest<=7
end
local function isGunPiece(part,colors)
    if not visiblePart(part) or contains(part.Name,helperWords) then return false end
    if isArmPiece(part,colors) then return false end
    local cam=Workspace.CurrentCamera
    if not cam or not part:IsDescendantOf(cam) then return false end
    local rig=cam:FindFirstChild("Rig")
    if rig and part:IsDescendantOf(rig) then return true end
    local p,on=cam:WorldToViewportPoint(part.Position)
    if not on or p.Z<=0 then return false end
    local vp=cam.ViewportSize
    return p.Y/vp.Y>.34 and p.X/vp.X>.18 and p.X/vp.X<.82
end

local function remember(store,part)
    if store[part] then return end
    store[part]={Material=part.Material,Color=part.Color,Transparency=part.Transparency,CastShadow=part.CastShadow,Reflectance=part.Reflectance}
end
local function restoreOne(store,highlights,part)
    local st=store[part]
    if st and part and part.Parent then pcall(function() part.Material=st.Material part.Color=st.Color part.Transparency=st.Transparency part.CastShadow=st.CastShadow part.Reflectance=st.Reflectance end) end
    store[part]=nil
    local hi=highlights[part]
    if hi and hi.Parent then hi:Destroy() end
    highlights[part]=nil
end
local function restoreAll(store,highlights)
    local parts={}
    for p in pairs(store) do table.insert(parts,p) end
    for _,p in ipairs(parts) do restoreOne(store,highlights,p) end
end
local function stylePiece(store,highlights,part,material,color,transparency,glow)
    remember(store,part)
    part.Material=materialMap[material] or Enum.Material.ForceField
    part.Color=color
    part.Transparency=math.clamp(transparency,0,.9)
    part.CastShadow=false
    part.Reflectance=0
    local hi=highlights[part]
    if not hi or not hi.Parent then
        hi=Instance.new("Highlight")
        hi.Name="YokaiGunTestingChams"
        hi.Adornee=part
        hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hi.Parent=part
        highlights[part]=hi
    end
    hi.FillColor=color
    hi.OutlineColor=color
    hi.FillTransparency=glow and .72 or 1
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

RunService:BindToRenderStep("YokaiGunTestingViewmodelV2",Enum.RenderPriority.Last.Value+130,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local colors=characterArmColors()
    local wantedSelf,wantedGun={},{}
    for _,obj in ipairs(cam:GetDescendants()) do
        if obj:IsA("BasePart") and visiblePart(obj) then
            if isArmPiece(obj,colors) then wantedSelf[obj]=true
            elseif isGunPiece(obj,colors) then wantedGun[obj]=true end
        end
    end
    local stale={}
    for p in pairs(selfStore) do if not wantedSelf[p] or not selfEnabled then table.insert(stale,p) end end
    for _,p in ipairs(stale) do restoreOne(selfStore,selfHighlights,p) end
    stale={}
    for p in pairs(gunStore) do if not wantedGun[p] or not gunEnabled then table.insert(stale,p) end end
    for _,p in ipairs(stale) do restoreOne(gunStore,gunHighlights,p) end
    if selfEnabled then for p in pairs(wantedSelf) do stylePiece(selfStore,selfHighlights,p,selfMaterial,selfColor,selfTransparency,selfGlow) end end
    if gunEnabled then for p in pairs(wantedGun) do stylePiece(gunStore,gunHighlights,p,gunMaterial,gunColor,gunTransparency,gunGlow) end end
end)

-- ============================================================================
-- Correct bot arrows: screen-projection direction, no bitmap rotation ambiguity.
-- Each arrow is a small two-line chevron whose TIP always points at the bot.
-- ============================================================================
local function destroyGuiNamed(name)
    for _,root in ipairs({LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}) do
        if root then local old=root:FindFirstChild(name,true) if old then pcall(function() old:Destroy() end) end end
    end
    pcall(function() if gethui then local r=gethui() local old=r and r:FindFirstChild(name,true) if old then old:Destroy() end end end)
end
destroyGuiNamed("YokaiBotArrows")
destroyGuiNamed("YokaiBotArrowsV2")
local arrowGui=Instance.new("ScreenGui")
arrowGui.Name="YokaiBotArrowsV2"
arrowGui.ResetOnSpawn=false
arrowGui.IgnoreGuiInset=true
arrowGui.DisplayOrder=1022
pcall(function() arrowGui.Parent=(gethui and gethui()) or CoreGui end)
if not arrowGui.Parent then arrowGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end
local arrowStore={}
local function newLine(parent)
    local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.BorderSizePixel=0 f.BackgroundColor3=Color3.new(1,1,1) f.Visible=false f.Parent=parent return f
end
local function setLine(f,a,b)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.Visible=true
end
local function ensureArrow(model)
    local s=arrowStore[model]
    if s then return s end
    s={newLine(arrowGui),newLine(arrowGui)}
    arrowStore[model]=s
    return s
end
local function hideArrow(s) for _,f in ipairs(s) do f.Visible=false end end
local function arrowsEnabled()
    local rec=findOption(RenderRec,"Arrows")
    return rec and rec.Api and rec.Api.Enabled==true
end
RunService:BindToRenderStep("YokaiGunTestingBotArrowsV2",Enum.RenderPriority.Last.Value+140,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local enabled=arrowsEnabled()
    local vp=cam.ViewportSize
    local center=vp/2
    local radius=math.min(vp.X,vp.Y)*.31
    local live={}
    if enabled then
        for model in pairs(bots) do
            if isBot(model) then
                live[model]=true
                local s=ensureArrow(model)
                local root=rootOf(model)
                local p,on=cam:WorldToViewportPoint(root.Position)
                if on and p.Z>0 then hideArrow(s) else
                    local dir=Vector2.new(p.X,p.Y)-center
                    if p.Z<0 then dir=-dir end
                    if dir.Magnitude<1 then
                        local rel=cam.CFrame:PointToObjectSpace(root.Position)
                        dir=Vector2.new(rel.X,rel.Z>0 and 1 or -1)
                    end
                    dir=dir.Unit
                    local tip=center+dir*radius
                    local base=tip-dir*13
                    local perp=Vector2.new(-dir.Y,dir.X)
                    setLine(s[1],tip,base+perp*5)
                    setLine(s[2],tip,base-perp*5)
                end
            end
        end
    end
    for model,s in pairs(arrowStore) do
        if not live[model] then hideArrow(s) if not bots[model] then for _,f in ipairs(s) do f:Destroy() end arrowStore[model]=nil end end
    end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Gun Testing V2: ADS aim + prediction + viewmodel + arrows",3) end)
