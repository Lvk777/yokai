-- Bot arena adapter.
-- Targets ONLY non-player Humanoid models. Player characters are always excluded.
-- No remote calls, no anti-cheat bypass, no ban evasion.

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
    local targets={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key):lower()==name:lower() and isUnder(rec,parentRec) then
            table.insert(targets,{key=key,rec=rec})
        end
    end
    for _,t in ipairs(targets) do
        local childKeys={}
        for key,rec in pairs(objects) do
            if key~=t.key and rec and rec.Object and isUnder(rec,t.rec) then table.insert(childKeys,key) end
        end
        for _,key in ipairs(childKeys) do pcall(function() GuiLibrary["RemoveObject"](key) end) end
        pcall(function() if t.rec.Api and t.rec.Api.Enabled and t.rec.Api.ToggleButton then t.rec.Api.ToggleButton(false) end end)
        pcall(function() GuiLibrary["RemoveObject"](t.key) end)
    end
end

local function roots()
    local t={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(t,gethui()) end end)
    return t
end
local function destroyNamed(name)
    for _,root in ipairs(roots()) do
        if root then
            local old=root:FindFirstChild(name,true)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end
local function newOverlay(name,order)
    destroyNamed(name)
    local g=Instance.new("ScreenGui")
    g.Name=name g.ResetOnSpawn=false g.IgnoreGuiInset=true g.DisplayOrder=order
    pcall(function() g.Parent=(gethui and gethui()) or CoreGui end)
    if not g.Parent then g.Parent=LocalPlayer:WaitForChild("PlayerGui") end
    return g
end

-- ============================================================================
-- Bot discovery: direct Humanoid models only, and NEVER Player characters.
-- Some games wrap the visible player rig in another Model, so exclusion checks
-- exact characters, ancestors/descendants and Humanoid display names.
-- ============================================================================
local bots={}
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function belongsToPlayer(model,hum)
    if not model then return false end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char then
            if model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model) then return true end
            local root=rootOf(model)
            if root and root:IsDescendantOf(char) then return true end
        end
        local dn=hum and hum.DisplayName or ""
        if dn~="" and (dn==plr.Name or dn==plr.DisplayName) then return true end
        if model.Name==plr.Name or model.Name==plr.DisplayName then return true end
    end
    return false
end
local function looksGeneratedName(text)
    text=tostring(text or "")
    if text=="" then return true end
    local stripped=text:gsub("[{}%-]","")
    if #stripped>=24 and stripped:match("^%x+$") then return true end
    if #text>=28 and text:match("^[%w_%-{}]+$") and text:find("%-",1,true) then return true end
    return false
end
local function readableBotName(model,hum)
    local display=hum and tostring(hum.DisplayName or "") or ""
    if display~="" and not looksGeneratedName(display) then return display end
    for _,attr in ipairs({"DisplayName","BotName","NPCName","CharacterName"}) do
        local ok,value=pcall(function() return model:GetAttribute(attr) end)
        if ok and type(value)=="string" and value~="" and not looksGeneratedName(value) then return value end
    end
    for _,name in ipairs({"DisplayName","BotName","NPCName","CharacterName"}) do
        local value=model:FindFirstChild(name)
        if value and value:IsA("StringValue") and value.Value~="" and not looksGeneratedName(value.Value) then return value.Value end
    end
    if not looksGeneratedName(model.Name) then return model.Name end
    return "Bot"
end
local function isBot(model)
    if not model or not model:IsA("Model") then return false end
    if model.Name=="YokaiSafeVisualTestTarget" then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=rootOf(model)
    if not hum or not root or hum.Health<=0 then return false end
    if belongsToPlayer(model,hum) then return false end
    return true
end
local function rescanBots()
    local nextSet={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isBot(obj) then nextSet[obj]=true end
    end
    bots=nextSet
end
rescanBots()
local scanClock=0
RunService.Heartbeat:Connect(function(dt)
    scanClock+=dt
    if scanClock>=0.5 then scanClock=0 rescanBots() end
end)
Players.PlayerAdded:Connect(function() task.defer(rescanBots) end)
Players.PlayerRemoving:Connect(function() task.defer(rescanBots) end)
LocalPlayer.CharacterAdded:Connect(function() task.delay(.2,rescanBots) end)

local function aimPart(model,partName)
    if not model then return nil end
    if partName=="Head" then return model:FindFirstChild("Head") or rootOf(model) end
    return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)
end
local function visibleFromCamera(model,part)
    local cam=Workspace.CurrentCamera
    if not cam or not model or not part then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(cam.CFrame.Position,part.Position-cam.CFrame.Position,rp)
    return hit==nil or (hit.Instance and hit.Instance:IsDescendantOf(model))
end
local function nearestBotToMouse(maxPixels,maxStuds,partName,wallCheck)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local mouse=UserInputService:GetMouseLocation()
    local best,bestPart,bestPx=nil,nil,maxPixels or math.huge
    for model in pairs(bots) do
        if isBot(model) then
            local root=rootOf(model)
            local part=aimPart(model,partName)
            if root and part then
                local studs=(cam.CFrame.Position-root.Position).Magnitude
                if studs<=(maxStuds or math.huge) then
                    local p,on=cam:WorldToViewportPoint(part.Position)
                    if on and p.Z>0 then
                        local px=(Vector2.new(p.X,p.Y)-mouse).Magnitude
                        if px<bestPx and (not wallCheck or visibleFromCamera(model,part)) then
                            best,bestPart,bestPx=model,part,px
                        end
                    end
                end
            end
        end
    end
    return best,bestPart,bestPx
end

-- ============================================================================
-- Combat: bot-only versions.
-- ============================================================================
for _,name in ipairs({"Aimbot","SilentAim","HitBoxes"}) do removeOption(CombatRec,name) end

local combatDistance=1000
local aimEnabled=false
local aimFov=260
local aimSmooth=6
local aimPartName="Head"
local aimWall=true
local aimActivation="Mouse2"
local Aimbot=Combat.CreateOptionsButton({
    ["Name"]="Aimbot",
    ["Function"]=function(v) aimEnabled=v end,
    ["HoverText"]="Bots only. Player characters are excluded.",
})
Aimbot.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=900,["Default"]=260,["Function"]=function(v) aimFov=v end})
Aimbot.CreateSlider({["Name"]="Smoothness",["Min"]=1,["Max"]=20,["Default"]=6,["Function"]=function(v) aimSmooth=v end})
Aimbot.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) aimPartName=v end})
Aimbot.CreateDropdown({["Name"]="Activation",["List"]={"Mouse2","Mouse1","Always"},["Function"]=function(v) aimActivation=v end})
Aimbot.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) aimWall=v end})

local silentEnabled=false
local silentFov=280
local silentPartName="Head"
local silentWall=true
local SilentAim=Combat.CreateOptionsButton({
    ["Name"]="SilentAim",
    ["Function"]=function(v) silentEnabled=v end,
    ["HoverText"]="Bot-only click-time camera correction. No remote or metatable hooks.",
})
SilentAim.CreateSlider({["Name"]="FOV",["Min"]=25,["Max"]=900,["Default"]=280,["Function"]=function(v) silentFov=v end})
SilentAim.CreateDropdown({["Name"]="Aim Part",["List"]={"Head","Torso"},["Function"]=function(v) silentPartName=v end})
SilentAim.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) silentWall=v end})

local hitboxEnabled=false
local hitboxSize=5
local hitboxPartName="Head"
local originalSizes=setmetatable({}, {__mode="k"})
local HitBoxes=Combat.CreateOptionsButton({
    ["Name"]="HitBoxes",
    ["Function"]=function(v)
        hitboxEnabled=v
        if not v then
            for part,size in pairs(originalSizes) do
                if part and part.Parent then pcall(function() part.Size=size end) end
                originalSizes[part]=nil
            end
        end
    end,
    ["HoverText"]="Bots only. Enlarges the selected NPC body part locally.",
})
HitBoxes.CreateSlider({["Name"]="Size",["Min"]=2,["Max"]=12,["Default"]=5,["Function"]=function(v) hitboxSize=v end})
HitBoxes.CreateDropdown({["Name"]="Part",["List"]={"Head","Torso"},["Function"]=function(v) hitboxPartName=v end})

local function activationDown()
    if aimActivation=="Always" then return true end
    if aimActivation=="Mouse1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

RunService:BindToRenderStep("YokaiBotAimbot",Enum.RenderPriority.Camera.Value+5,function()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if aimEnabled and activationDown() then
        local _,part=nearestBotToMouse(aimFov,combatDistance,aimPartName,aimWall)
        if part then
            local desired=CFrame.lookAt(cam.CFrame.Position,part.Position)
            cam.CFrame=cam.CFrame:Lerp(desired,1/math.max(1,aimSmooth))
        end
    end
    if hitboxEnabled then
        for model in pairs(bots) do
            if isBot(model) then
                local part=aimPart(model,hitboxPartName)
                if part and part:IsA("BasePart") then
                    if not originalSizes[part] then originalSizes[part]=part.Size end
                    part.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize)
                    part.CanCollide=false
                end
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input,processed)
    if processed or not silentEnabled or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local _,part=nearestBotToMouse(silentFov,combatDistance,silentPartName,silentWall)
    if not part then return end
    local before=cam.CFrame
    cam.CFrame=CFrame.lookAt(before.Position,part.Position)
    task.defer(function()
        if cam and cam.Parent and silentEnabled then cam.CFrame=before end
    end)
end)

-- ============================================================================
-- Visuals: bot-only versions.
-- ============================================================================
for _,name in ipairs({"ESP","Chams","Corner Box","HealthBar","Name + Distance","Skeleton","Tracers","3D Box","Distance"}) do
    removeOption(VisualsRec,name)
end
removeOption(VisualsRec,"Thermal Corner")

local visualDistance=500
local wallCheck=true
local visibleColor=Color3.fromRGB(35,235,95)
local occludedColor=Color3.fromRGB(245,70,70)
local espColor=Color3.fromRGB(119,120,255)
local espEnabled=false
local espFillTransparency=.80
local espHealth=true
local espHealthText=true
local espPalette="Blue / Red"
local espNames=true
local espCorners=true

local chamsEnabled=false
local chamsThermal=true
local chamsFill=Color3.fromRGB(119,120,255)
local chamsOutline=Color3.fromRGB(119,120,255)
local chamsFillTransparency=.58
local chamsOutlineTransparency=.10

local cornerEnabled=false
local healthEnabled=false
local healthPalette="Blue / Red"
local healthTextEnabled=true
local namesEnabled=false
local skeletonEnabled=false
local skeletonColor=Color3.new(1,1,1)
local skeletonTransparency=0
local skeletonThickness=1
local tracersEnabled=false
local tracerColor=Color3.new(1,1,1)
local tracerThickness=1
local tracerTransparency=0
local tracerOrigin="Bottom"
local box3DEnabled=false
local box3DColor=Color3.new(1,1,1)
local box3DThickness=1

local ESP=Visuals.CreateOptionsButton({["Name"]="ESP",["Function"]=function(v) espEnabled=v end,["HoverText"]="Complete bot ESP pack; Players are excluded."})
ESP.CreateToggle({["Name"]="WallCheck",["Default"]=true,["Function"]=function(v) wallCheck=v end})
ESP.CreateColorSlider({["Name"]="ESP Color",["Function"]=function(h,s,v) espColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) visibleColor=Color3.fromHSV(h,s,v) end})
ESP.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) occludedColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=80,["Function"]=function(v) espFillTransparency=v/100 end})
ESP.CreateToggle({["Name"]="Corner",["Default"]=true,["Function"]=function(v) espCorners=v end})
ESP.CreateToggle({["Name"]="ESP HealthBar",["Default"]=true,["Function"]=function(v) espHealth=v end})
ESP.CreateDropdown({["Name"]="ESP Health Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) espPalette=v end})
ESP.CreateToggle({["Name"]="ESP HealthText",["Default"]=true,["Function"]=function(v) espHealthText=v end})
ESP.CreateToggle({["Name"]="Name + Distance",["Default"]=true,["Function"]=function(v) espNames=v end})

local Chams=Visuals.CreateOptionsButton({["Name"]="Chams",["Function"]=function(v) chamsEnabled=v end})
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) chamsThermal=v end})
Chams.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) chamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) chamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({["Name"]="Fill Transparency",["Min"]=0,["Max"]=100,["Default"]=58,["Function"]=function(v) chamsFillTransparency=v/100 end})
Chams.CreateSlider({["Name"]="Outline Transparency",["Min"]=0,["Max"]=100,["Default"]=10,["Function"]=function(v) chamsOutlineTransparency=v/100 end})

local CornerBox=Visuals.CreateOptionsButton({["Name"]="Corner Box",["Function"]=function(v) cornerEnabled=v end})

local HealthBar=Visuals.CreateOptionsButton({["Name"]="HealthBar",["Function"]=function(v) healthEnabled=v end})
HealthBar.CreateDropdown({["Name"]="Palette",["List"]={"Blue / Red","Mint / Yellow / Red"},["Function"]=function(v) healthPalette=v end})
HealthBar.CreateToggle({["Name"]="HealthText",["Default"]=true,["Function"]=function(v) healthTextEnabled=v end})

local NameDistance=Visuals.CreateOptionsButton({["Name"]="Name + Distance",["Function"]=function(v) namesEnabled=v end})

local Skeleton=Visuals.CreateOptionsButton({["Name"]="Skeleton",["Function"]=function(v) skeletonEnabled=v end})
Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) skeletonColor=Color3.fromHSV(h,s,v) end})
Skeleton.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=0,["Function"]=function(v) skeletonTransparency=v/100 end})
Skeleton.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) skeletonThickness=v end})

local Tracers=Visuals.CreateOptionsButton({["Name"]="Tracers",["Function"]=function(v) tracersEnabled=v end})
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Top","Bottom","Center","Mouse"},["Function"]=function(v) tracerOrigin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) tracerThickness=v end})
Tracers.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=95,["Default"]=0,["Function"]=function(v) tracerTransparency=v/100 end})

local Box3D=Visuals.CreateOptionsButton({["Name"]="3D Box",["Function"]=function(v) box3DEnabled=v end})
Box3D.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) box3DColor=Color3.fromHSV(h,s,v) end})
Box3D.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) box3DThickness=v end})

local Distance=Visuals.CreateOptionsButton({["Name"]="Distance",["Function"]=function() end})
Distance.CreateSlider({["Name"]="Max Distance",["Min"]=25,["Max"]=2000,["Default"]=500,["Function"]=function(v) visualDistance=v combatDistance=v end})

local overlay=newOverlay("YokaiBotArenaVisuals",1020)
local stores={}
local function newLine(parent)
    local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.BorderSizePixel=0 f.Visible=false f.Parent=parent return f
end
local function setLine(f,a,b,thickness,color,transparency)
    local d=b-a
    if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Rotation=math.deg(math.atan2(d.Y,d.X))
    f.BackgroundColor3=color
    f.BackgroundTransparency=transparency or 0
    f.Visible=true
end
local function hideLines(t) for _,v in ipairs(t) do v.Visible=false end end
local function palette(name)
    if name=="Mint / Yellow / Red" then
        return ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(120,255,205)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,226,120)),ColorSequenceKeypoint.new(1,Color3.fromRGB(230,55,55))})
    end
    return ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(50,110,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(220,40,50))})
end
local function newStore(model)
    local s={Model=model}
    s.Highlight=Instance.new("Highlight") s.Highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop s.Highlight.Enabled=false s.Highlight.Parent=Workspace
    s.Fill=Instance.new("Frame") s.Fill.BorderSizePixel=0 s.Fill.Visible=false s.Fill.Parent=overlay
    s.Corners={} for i=1,8 do s.Corners[i]=newLine(overlay) end
    s.HealthBack=Instance.new("Frame") s.HealthBack.BorderSizePixel=0 s.HealthBack.BackgroundColor3=Color3.new(0,0,0) s.HealthBack.Visible=false s.HealthBack.Parent=overlay
    s.Health=Instance.new("Frame") s.Health.BorderSizePixel=0 s.Health.BackgroundColor3=Color3.new(1,1,1) s.Health.Visible=false s.Health.Parent=overlay
    s.HealthGradient=Instance.new("UIGradient") s.HealthGradient.Rotation=90 s.HealthGradient.Parent=s.Health
    s.HealthText=Instance.new("TextLabel") s.HealthText.BackgroundTransparency=1 s.HealthText.Size=UDim2.fromOffset(44,16) s.HealthText.Font=Enum.Font.Code s.HealthText.TextSize=11 s.HealthText.TextColor3=Color3.new(1,1,1) s.HealthText.TextStrokeTransparency=0 s.HealthText.Visible=false s.HealthText.Parent=overlay
    s.Name=Instance.new("TextLabel") s.Name.BackgroundTransparency=1 s.Name.Size=UDim2.fromOffset(180,18) s.Name.Font=Enum.Font.Code s.Name.TextSize=11 s.Name.TextColor3=Color3.new(1,1,1) s.Name.TextStrokeTransparency=0 s.Name.Visible=false s.Name.Parent=overlay
    s.Skeleton={} for i=1,16 do s.Skeleton[i]=newLine(overlay) end
    s.Tracer=newLine(overlay)
    s.Box3D={} for i=1,12 do s.Box3D[i]=newLine(overlay) end
    stores[model]=s
    return s
end
local function hideStore(s)
    s.Highlight.Enabled=false s.Fill.Visible=false s.HealthBack.Visible=false s.Health.Visible=false s.HealthText.Visible=false s.Name.Visible=false s.Tracer.Visible=false
    hideLines(s.Corners) hideLines(s.Skeleton) hideLines(s.Box3D)
end
local function destroyStore(model)
    local s=stores[model] if not s then return end
    for _,v in pairs(s) do
        if typeof(v)=="Instance" then pcall(function() v:Destroy() end)
        elseif type(v)=="table" then for _,x in pairs(v) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end
    end
    stores[model]=nil
end

local function visualBounds(model)
    local cam=Workspace.CurrentCamera if not cam then return nil end
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for _,part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local size=originalSizes[part] or part.Size
            local cf=part.CFrame
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local p=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
                if p.Z>0 then any=true minX=math.min(minX,p.X) minY=math.min(minY,p.Y) maxX=math.max(maxX,p.X) maxY=math.max(maxY,p.Y) end
            end end end
        end
    end
    if not any then return nil end
    return Vector2.new(minX,minY),Vector2.new(maxX,maxY)
end
local function drawCorners(lines,tl,br,color,thickness)
    local l,t,r,b=tl.X,tl.Y,br.X,br.Y local w,h=r-l,b-t local cw,ch=math.max(4,w/5),math.max(4,h/5)
    local seg={
        {Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},
        {Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},
        {Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},
        {Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)},
    }
    for i,v in ipairs(seg) do setLine(lines[i],v[1],v[2],thickness or 1,color,0) end
end
local r15Bones={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local r6Bones={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local function drawSkeleton(s,model)
    hideLines(s.Skeleton)
    local cam=Workspace.CurrentCamera if not cam then return end
    local list=model:FindFirstChild("UpperTorso") and r15Bones or r6Bones
    for i,pair in ipairs(list) do
        if i>#s.Skeleton then break end
        local a=model:FindFirstChild(pair[1]) local b=model:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local ap,ao=cam:WorldToViewportPoint(a.Position) local bp,bo=cam:WorldToViewportPoint(b.Position)
            if ao and bo and ap.Z>0 and bp.Z>0 then setLine(s.Skeleton[i],Vector2.new(ap.X,ap.Y),Vector2.new(bp.X,bp.Y),skeletonThickness,skeletonColor,skeletonTransparency) end
        end
    end
end
local boxEdges={{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}}
local function draw3D(s,model)
    hideLines(s.Box3D)
    local cam=Workspace.CurrentCamera if not cam then return end
    local cf,size=model:GetBoundingBox()
    local points={}
    local idx=1
    for z=-1,1,2 do for y=-1,1,2 do for x=-1,1,2 do
        local p,on=cam:WorldToViewportPoint((cf*CFrame.new(size.X*x/2,size.Y*y/2,size.Z*z/2)).Position)
        points[idx]=on and p.Z>0 and Vector2.new(p.X,p.Y) or nil idx+=1
    end end end
    for i,e in ipairs(boxEdges) do local a,b=points[e[1]],points[e[2]] if a and b then setLine(s.Box3D[i],a,b,box3DThickness,box3DColor,0) end end
end
local function tracerStart()
    local cam=Workspace.CurrentCamera if not cam then return Vector2.zero end
    local vp=cam.ViewportSize
    if tracerOrigin=="Top" then return Vector2.new(vp.X/2,0) end
    if tracerOrigin=="Center" then return vp/2 end
    if tracerOrigin=="Mouse" then local m=UserInputService:GetMouseLocation() return Vector2.new(math.clamp(m.X,0,vp.X),math.clamp(m.Y,0,vp.Y)) end
    return Vector2.new(vp.X/2,vp.Y)
end

RunService:BindToRenderStep("YokaiBotVisuals",Enum.RenderPriority.Last.Value+100,function()
    local cam=Workspace.CurrentCamera if not cam then return end
    for model in pairs(stores) do if not bots[model] or not isBot(model) then destroyStore(model) end end
    for model in pairs(bots) do
        if isBot(model) then
            local s=stores[model] or newStore(model)
            local hum=model:FindFirstChildOfClass("Humanoid") local root=rootOf(model) local head=model:FindFirstChild("Head") or root
            local dist=root and (cam.CFrame.Position-root.Position).Magnitude or math.huge
            local tl,br=visualBounds(model)
            if not hum or not root or hum.Health<=0 or dist>visualDistance or not tl then hideStore(s) continue end
            local occluded=wallCheck and not visibleFromCamera(model,head)
            local stateColor=wallCheck and (occluded and occludedColor or visibleColor) or espColor
            local cleanRed=Color3.new((stateColor.R+.16)/1.16,(stateColor.G+.10)/1.10,(stateColor.B+.10)/1.10)
            local w,h=br.X-tl.X,br.Y-tl.Y
            local displayName=readableBotName(model,hum)

            if espEnabled then
                s.Fill.Position=UDim2.fromOffset(tl.X,tl.Y) s.Fill.Size=UDim2.fromOffset(w,h)
                s.Fill.BackgroundColor3=occluded and cleanRed or espColor s.Fill.BackgroundTransparency=espFillTransparency s.Fill.Visible=true
                if espCorners then drawCorners(s.Corners,tl,br,stateColor,1) else hideLines(s.Corners) end
                if espHealth then
                    local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                    local x=br.X+5
                    s.HealthBack.Position=UDim2.fromOffset(x,tl.Y) s.HealthBack.Size=UDim2.fromOffset(4,h) s.HealthBack.Visible=true
                    s.Health.Position=UDim2.fromOffset(x+1,tl.Y+1+(h-2)*(1-ratio)) s.Health.Size=UDim2.fromOffset(2,(h-2)*ratio) s.HealthGradient.Color=palette(espPalette) s.Health.Visible=true
                    s.HealthText.Position=UDim2.fromOffset(x+8,tl.Y+h*(1-ratio)-8) s.HealthText.Text=tostring(math.floor(hum.Health)) s.HealthText.Visible=espHealthText
                else s.HealthBack.Visible=false s.Health.Visible=false s.HealthText.Visible=false end
                if espNames then s.Name.Position=UDim2.fromOffset((tl.X+br.X)/2-90,tl.Y-18) s.Name.Text=displayName.." ["..math.floor(dist).."]" s.Name.Visible=true else s.Name.Visible=false end
            else
                s.Fill.Visible=false hideLines(s.Corners)
                if not healthEnabled then s.HealthBack.Visible=false s.Health.Visible=false s.HealthText.Visible=false end
                if not namesEnabled then s.Name.Visible=false end
            end

            if chamsEnabled then
                s.Highlight.Adornee=model s.Highlight.Enabled=true
                local wave=(math.atan(math.sin(os.clock()*2))*2/math.pi+1)/2
                local ft=chamsFillTransparency local ot=chamsOutlineTransparency
                if chamsThermal then ft=math.clamp(ft+(wave-.5)*.22,0,1) ot=math.clamp(ot+(wave-.5)*.10,0,1) end
                s.Highlight.FillColor=occluded and cleanRed or chamsFill
                s.Highlight.OutlineColor=occluded and occludedColor or chamsOutline
                s.Highlight.FillTransparency=ft s.Highlight.OutlineTransparency=ot
            else s.Highlight.Enabled=false end

            if cornerEnabled then
                s.Fill.Position=UDim2.fromOffset(tl.X,tl.Y) s.Fill.Size=UDim2.fromOffset(w,h)
                s.Fill.BackgroundColor3=occluded and cleanRed or Color3.new(0,0,0) s.Fill.BackgroundTransparency=occluded and .82 or .75 s.Fill.Visible=true
                drawCorners(s.Corners,tl,br,occluded and occludedColor or Color3.new(1,1,1),1)
            end

            if healthEnabled and not espEnabled then
                local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
                local x=br.X+7
                s.HealthBack.Position=UDim2.fromOffset(x,tl.Y) s.HealthBack.Size=UDim2.fromOffset(4,h) s.HealthBack.Visible=true
                s.Health.Position=UDim2.fromOffset(x+1,tl.Y+1+(h-2)*(1-ratio)) s.Health.Size=UDim2.fromOffset(2,(h-2)*ratio) s.HealthGradient.Color=palette(healthPalette) s.Health.Visible=true
                s.HealthText.Position=UDim2.fromOffset(x+8,tl.Y+h*(1-ratio)-8) s.HealthText.Text=tostring(math.floor(hum.Health)) s.HealthText.Visible=healthTextEnabled
            end
            if namesEnabled and not espEnabled then s.Name.Position=UDim2.fromOffset((tl.X+br.X)/2-90,tl.Y-18) s.Name.Text=displayName.." ["..math.floor(dist).."]" s.Name.Visible=true end
            if skeletonEnabled then drawSkeleton(s,model) else hideLines(s.Skeleton) end
            if tracersEnabled then setLine(s.Tracer,tracerStart(),Vector2.new((tl.X+br.X)/2,br.Y),tracerThickness,tracerColor,tracerTransparency) else s.Tracer.Visible=false end
            if box3DEnabled then draw3D(s,model) else hideLines(s.Box3D) end
        end
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai","Bot arena mode loaded: non-player Humanoids only",4)
end)
