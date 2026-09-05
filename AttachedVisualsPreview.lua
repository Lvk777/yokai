-- Visuals harmony + exact attached ESP-style integrations.
-- The attached visual styles are implemented as real Yokai Visuals modules.
-- Also keeps Visuals behavior aligned with the native sidebar, enforces FullBrightness
-- while enabled, and leaves local/self visual modules untouched.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then
    warn("AttachedVisualsPreview: Visuals window missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v)
    return tostring(v):gsub(ZWSP, "")
end
local function optionNameFromKey(key)
    return clean(key):gsub("OptionsButton$", "")
end

local function underVisuals(rec)
    if not rec or not rec["Object"] then return false end
    local obj = rec["Object"]
    for _, root in ipairs({VisualsRec["Object"], VisualsRec["ChildrenObject"]}) do
        if root and typeof(root) == "Instance" then
            if obj == root or obj:IsDescendantOf(root) then return true end
        end
    end
    return false
end

local function removeVisualOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionNameFromKey(key) == name and underVisuals(rec) then
            table.insert(keys, key)
        end
    end
    for _, key in ipairs(keys) do
        local rec = objects[key]
        pcall(function()
            local api = rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

for _, name in ipairs({
    "Attached Preview", "Chams Style", "Corner Box", "Thermal Corner", "HealthBar",
    "Name + Distance", "Skeleton Style", "Tracers Style", "3D Box Style", "ESP Pack",
    "Chams", "ESP", "Tracers"
}) do
    removeVisualOption(name)
end

local oldPreview = LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("YokaiAttachedESPPreview")
if oldPreview then oldPreview:Destroy() end

-- Make Visuals act like the native Yokai sidebar entries.
do
    local main = GuiLibrary["MainGui"]
    if main then
        for _, n in ipairs({"VisualsV4Button", "VisualsHarmonyButton"}) do
            local old = main:FindFirstChild(n, true)
            if old then old:Destroy() end
        end
        local renderRec = objects["RenderButton"]
        local source = renderRec and renderRec["Object"]
        if source and typeof(source) == "Instance" then
            local button = source:Clone()
            button.Name = "VisualsHarmonyButton"
            button.LayoutOrder = (source.LayoutOrder or 0) + 1
            local function rename(node)
                if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text == "Render" then node.Text = "Visuals" end
            end
            rename(button)
            for _, d in ipairs(button:GetDescendants()) do rename(d) end
            button.Parent = source.Parent
            local clickTarget = button:IsA("TextButton") and button or button:FindFirstChildWhichIsA("TextButton", true)
            local visualOpen = false
            local nativeWindows = {"Combat", "Movement", "Render", "Utility", "World", "Friends", "Profiles"}
            local function hideNativeWindows()
                for _, name in ipairs(nativeWindows) do
                    local rec = objects[name .. "Window"]
                    local api = rec and rec["Api"]
                    if api and api["SetVisible"] then pcall(function() api.SetVisible(false) end) end
                end
            end
            local function setVisuals(v)
                visualOpen = v
                if v then hideNativeWindows() end
                pcall(function() Visuals.SetVisible(v) end)
            end
            if clickTarget then clickTarget.MouseButton1Click:Connect(function() setVisuals(not visualOpen) end) end
            for _, name in ipairs(nativeWindows) do
                local rec = objects[name .. "Button"]
                local obj = rec and rec["Object"]
                if obj and typeof(obj) == "Instance" then
                    local target = obj:IsA("TextButton") and obj or obj:FindFirstChildWhichIsA("TextButton", true)
                    if target then target.MouseButton1Click:Connect(function() if visualOpen then setVisuals(false) end end) end
                end
            end
        end
    end
end

-- FullBrightness enforced continuously while enabled.
local brightnessAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
    brightnessAccumulator += dt
    if brightnessAccumulator < 0.03 then return end
    brightnessAccumulator = 0
    local rec = objects["FullBrightnessOptionsButton"]
    local api = rec and rec["Api"]
    if api and api["Enabled"] then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(180,180,180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
    end
end)

local overlay = Instance.new("ScreenGui")
overlay.Name = "YokaiAttachedVisualsFunctional"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 998
pcall(function() overlay.Parent = (gethui and gethui()) or CoreGui end)
if not overlay.Parent then overlay.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local function unique(name) return name .. ZWSP .. ZWSP .. ZWSP end
local function makeOption(name, fn) return Visuals.CreateOptionsButton({["Name"] = unique(name), ["Function"] = fn}) end
local function createLine(parent, color)
    local f=Instance.new("Frame") f.BorderSizePixel=0 f.AnchorPoint=Vector2.new(.5,.5) f.BackgroundColor3=color or Color3.new(1,1,1) f.Visible=false f.Parent=parent return f
end
local function setLine(f,a,b,thickness,color)
    if not f then return end
    local d=b-a if d.Magnitude<.01 then f.Visible=false return end
    f.Size=UDim2.fromOffset(d.Magnitude,thickness or 1) f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2) f.Rotation=math.deg(math.atan2(d.Y,d.X))
    if color then f.BackgroundColor3=color end f.Visible=true
end
local function hideList(list) if list then for _,x in ipairs(list) do if x then x.Visible=false end end end end
local function validPlayer(plr)
    if not plr or plr==LocalPlayer then return nil end
    local char=plr.Character local hum=char and char:FindFirstChildOfClass("Humanoid") local root=char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not root or hum.Health<=0 then return nil end
    return char,hum,root
end
local function teamPass(plr) if LocalPlayer.Team and plr.Team then return LocalPlayer.Team~=plr.Team end return plr~=LocalPlayer end
local function screenData(root)
    local cam=Workspace.CurrentCamera if not cam then return nil end
    local p,on=cam:WorldToViewportPoint(root.Position) if not on or p.Z<=0 then return nil end
    local scale=(root.Size.Y*cam.ViewportSize.Y)/(p.Z*2)
    return Vector2.new(p.X,p.Y),3*scale,4.5*scale,(cam.CFrame.Position-root.Position).Magnitude/3.5714285714
end
local function friend(plr) local ok,v=pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end) return ok and v or false end

local cfg={
 Chams=false,ChamsMaxDistance=200,ChamsThermal=true,ChamsFill=Color3.fromRGB(119,120,255),ChamsOutline=Color3.fromRGB(119,120,255),
 Corner=false,CornerMaxDistance=200,CornerLine=Color3.fromRGB(255,255,255),CornerFill=Color3.fromRGB(0,0,0),
 ThermalCorner=false,ThermalCornerMaxDistance=200,ThermalCornerLine=Color3.fromRGB(255,255,255),ThermalCornerFill=Color3.fromRGB(119,120,255),
 Health=false,HealthMaxDistance=200,HealthText=true,HealthTextColor=Color3.fromRGB(119,120,255),HealthWidth=2.5,
 NameDistance=false,NameMaxDistance=200,FriendCheck=true,FriendColor=Color3.fromRGB(0,255,0),NameColor=Color3.fromRGB(255,255,255),DistanceColor=Color3.fromRGB(255,255,255),DistancePosition="Text",
 Skeleton=false,SkeletonColor=Color3.fromRGB(255,255,255),
 Tracers=false,TracerColor=Color3.fromRGB(255,255,255),TracerThickness=1,TracerCenter=false,
 Box3D=false,Box3DColor=Color3.fromRGB(255,255,255),ESP=false,ESPMaxDistance=200,
}

local stores={}
local function newCornerSet() local t={} for i=1,8 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end
local function newSkeletonSet() local t={} for i=1,14 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end
local function newBox3DSet() local t={} for i=1,12 do t[i]=createLine(overlay,Color3.new(1,1,1)) end return t end

local function newStore(plr)
    local s={Player=plr}
    s.Chams=Instance.new("Highlight") s.Chams.Name="AttachedChams" s.Chams.FillTransparency=1 s.Chams.OutlineTransparency=0 s.Chams.OutlineColor=Color3.fromRGB(119,120,255) s.Chams.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop s.Chams.Enabled=false s.Chams.Parent=overlay
    s.CornerFill=Instance.new("Frame") s.CornerFill.BorderSizePixel=0 s.CornerFill.BackgroundColor3=Color3.fromRGB(0,0,0) s.CornerFill.BackgroundTransparency=.75 s.CornerFill.Visible=false s.CornerFill.Parent=overlay s.Corner=newCornerSet()
    s.ThermalFill=Instance.new("Frame") s.ThermalFill.BorderSizePixel=0 s.ThermalFill.BackgroundColor3=Color3.fromRGB(119,120,255) s.ThermalFill.BackgroundTransparency=.75 s.ThermalFill.Visible=false s.ThermalFill.Parent=overlay s.ThermalCorner=newCornerSet()
    s.HealthBack=Instance.new("Frame") s.HealthBack.BorderSizePixel=0 s.HealthBack.BackgroundColor3=Color3.fromRGB(0,0,0) s.HealthBack.Visible=false s.HealthBack.Parent=overlay
    s.Health=Instance.new("Frame") s.Health.BorderSizePixel=0 s.Health.BackgroundColor3=Color3.fromRGB(255,255,255) s.Health.Visible=false s.Health.Parent=overlay
    s.HealthGradient=Instance.new("UIGradient") s.HealthGradient.Rotation=-90 s.HealthGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(60,60,125)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,120,255))}) s.HealthGradient.Parent=s.Health
    s.HealthText=Instance.new("TextLabel") s.HealthText.BackgroundTransparency=1 s.HealthText.AnchorPoint=Vector2.new(.5,.5) s.HealthText.Size=UDim2.fromOffset(100,20) s.HealthText.Font=Enum.Font.Code s.HealthText.TextSize=11 s.HealthText.TextStrokeTransparency=0 s.HealthText.TextStrokeColor3=Color3.fromRGB(0,0,0) s.HealthText.Visible=false s.HealthText.Parent=overlay
    s.Name=s.HealthText:Clone() s.Name.RichText=true s.Name.Parent=overlay s.Distance=s.HealthText:Clone() s.Distance.RichText=true s.Distance.Parent=overlay
    s.Skeleton=newSkeletonSet() s.Tracer=createLine(overlay,Color3.fromRGB(255,255,255)) s.Box3D=newBox3DSet()
    s.PackChams=s.Chams:Clone() s.PackChams.Name="AttachedESPPackChams" s.PackChams.Parent=overlay
    s.PackBox=Instance.new("Frame") s.PackBox.BorderSizePixel=1 s.PackBox.BorderColor3=Color3.fromRGB(255,255,255) s.PackBox.BackgroundColor3=Color3.fromRGB(255,255,255) s.PackBox.BackgroundTransparency=.75 s.PackBox.Visible=false s.PackBox.Parent=overlay
    s.PackGradient=Instance.new("UIGradient") s.PackGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(119,120,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}) s.PackGradient.Parent=s.PackBox s.PackCorners=newCornerSet()
    s.PackHealthBack=s.HealthBack:Clone() s.PackHealthBack.Parent=overlay s.PackHealth=s.Health:Clone() s.PackHealth.Parent=overlay s.PackHealthText=s.HealthText:Clone() s.PackHealthText.Parent=overlay
    s.PackName=s.Name:Clone() s.PackName.Parent=overlay s.PackDistance=s.Distance:Clone() s.PackDistance.Parent=overlay s.PackWeapon=s.HealthText:Clone() s.PackWeapon.TextColor3=Color3.fromRGB(119,120,255) s.PackWeapon.Parent=overlay
    stores[plr]=s return s
end
local function hideStore(s)
 if not s then return end s.Chams.Enabled=false s.PackChams.Enabled=false s.CornerFill.Visible=false s.ThermalFill.Visible=false s.Health.Visible=false s.HealthBack.Visible=false s.HealthText.Visible=false s.Name.Visible=false s.Distance.Visible=false s.Tracer.Visible=false s.PackBox.Visible=false s.PackHealth.Visible=false s.PackHealthBack.Visible=false s.PackHealthText.Visible=false s.PackName.Visible=false s.PackDistance.Visible=false s.PackWeapon.Visible=false hideList(s.Corner) hideList(s.ThermalCorner) hideList(s.Skeleton) hideList(s.Box3D) hideList(s.PackCorners)
end
local function destroyStore(plr)
 local s=stores[plr] if not s then return end
 for _,v in pairs(s) do if typeof(v)=="Instance" then pcall(function() v:Destroy() end) elseif type(v)=="table" then for _,x in pairs(v) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) end end end end stores[plr]=nil
end
Players.PlayerRemoving:Connect(destroyStore)

local bones={{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local function updateCorners(lines,pos,w,h,color)
 local l,r,t,b=pos.X-w/2,pos.X+w/2,pos.Y-h/2,pos.Y+h/2 local cw,ch=w/5,h/5
 local p={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
 for i,v in ipairs(p) do setLine(lines[i],v[1],v[2],1,color) end
end
local function updateSkeleton(lines,char,color)
 local cam=Workspace.CurrentCamera if not cam then hideList(lines) return end
 for i,b in ipairs(bones) do local p1,p2=char:FindFirstChild(b[1]),char:FindFirstChild(b[2]) local line=lines[i] if p1 and p2 and line then local a,va=cam:WorldToViewportPoint(p1.Position) local c,vc=cam:WorldToViewportPoint(p2.Position) if va and vc and a.Z>0 and c.Z>0 then setLine(line,Vector2.new(a.X,a.Y),Vector2.new(c.X,c.Y),1,color) else line.Visible=false end elseif line then line.Visible=false end end
end
local function update3D(lines,root,color)
 local cam=Workspace.CurrentCamera if not cam then hideList(lines) return end local cf=root.CFrame*CFrame.new(0,-.5,0) local sz=Vector3.new(3,5,3)/2 local corners={}
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(corners,(cf*CFrame.new(sz*Vector3.new(x,y,z))).Position) end end end
 local screen={} local all=true for i,p in ipairs(corners) do local s,v=cam:WorldToViewportPoint(p) screen[i]=Vector2.new(s.X,s.Y) if not v or s.Z<=0 then all=false end end
 local edges={{1,2},{2,4},{4,3},{3,1},{5,6},{6,8},{8,7},{7,5},{1,5},{2,6},{3,7},{4,8}} if not all then hideList(lines) return end for i,e in ipairs(edges) do setLine(lines[i],screen[e[1]],screen[e[2]],1,color) end
end
local function updateHealth(bar,back,text,hum,pos,w,h,width,textColor)
 local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1) back.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2) back.Size=UDim2.fromOffset(width,h) back.Visible=true bar.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2+h*(1-ratio)) bar.Size=UDim2.fromOffset(width,h*ratio) bar.Visible=true text.Position=UDim2.fromOffset(pos.X-w/2-15,pos.Y-h/2+h*(1-ratio)) text.Text=tostring(math.floor(ratio*100)) text.TextColor3=textColor text.Visible=cfg.HealthText and hum.Health<hum.MaxHealth
end
local function updateNameDistance(nameLabel,distanceLabel,plr,pos,w,h,dist)
 local isFriend=cfg.FriendCheck and friend(plr) local r,g,b if isFriend then r,g,b=math.floor(cfg.FriendColor.R*255),math.floor(cfg.FriendColor.G*255),math.floor(cfg.FriendColor.B*255) else r,g,b=255,0,0 end
 if cfg.DistancePosition=="Text" then nameLabel.Text=string.format('(<font color="rgb(%d, %d, %d)">%s</font>) %s [%d]',r,g,b,isFriend and "F" or "E",plr.Name,math.floor(dist)) distanceLabel.Visible=false else nameLabel.Text=string.format('(<font color="rgb(%d, %d, %d)">%s</font>) %s',r,g,b,isFriend and "F" or "E",plr.Name) distanceLabel.Position=UDim2.fromOffset(pos.X,pos.Y+h/2+7) distanceLabel.Text=string.format("%d meters",math.floor(dist)) distanceLabel.TextColor3=cfg.DistanceColor distanceLabel.Visible=true end
 nameLabel.Position=UDim2.fromOffset(pos.X,pos.Y-h/2-15) nameLabel.TextColor3=cfg.NameColor nameLabel.Visible=true
end

local activeLast=false
RunService.RenderStepped:Connect(function()
 local any=cfg.Chams or cfg.Corner or cfg.ThermalCorner or cfg.Health or cfg.NameDistance or cfg.Skeleton or cfg.Tracers or cfg.Box3D or cfg.ESP
 if not any then if activeLast then for _,s in pairs(stores) do hideStore(s) end activeLast=false end return end activeLast=true
 local cam=Workspace.CurrentCamera if not cam then return end
 for _,plr in ipairs(Players:GetPlayers()) do if plr~=LocalPlayer then
  local char,hum,root=validPlayer(plr) local s=stores[plr] or newStore(plr) local pos,w,h,dist if root then pos,w,h,dist=screenData(root) end
  if not char or not pos then hideStore(s) else
   if cfg.Chams and dist<=cfg.ChamsMaxDistance then s.Chams.Adornee=char s.Chams.Enabled=true s.Chams.FillColor=cfg.ChamsFill s.Chams.OutlineColor=cfg.ChamsOutline if cfg.ChamsThermal then local t=math.clamp(math.atan(math.sin(os.clock()*2))*2/math.pi,0,1) s.Chams.FillTransparency=t s.Chams.OutlineTransparency=t else s.Chams.FillTransparency=1 s.Chams.OutlineTransparency=0 end else s.Chams.Enabled=false end
   if cfg.Corner and dist<=cfg.CornerMaxDistance and teamPass(plr) then s.CornerFill.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2) s.CornerFill.Size=UDim2.fromOffset(w,h) s.CornerFill.BackgroundColor3=cfg.CornerFill s.CornerFill.BackgroundTransparency=.75 s.CornerFill.Visible=true updateCorners(s.Corner,pos,w,h,cfg.CornerLine) else s.CornerFill.Visible=false hideList(s.Corner) end
   if cfg.ThermalCorner and dist<=cfg.ThermalCornerMaxDistance and teamPass(plr) then local breathe=.5+(math.sin(os.clock()*2)+1)*.15 s.ThermalFill.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2) s.ThermalFill.Size=UDim2.fromOffset(w,h) s.ThermalFill.BackgroundColor3=cfg.ThermalCornerFill s.ThermalFill.BackgroundTransparency=breathe s.ThermalFill.Visible=true updateCorners(s.ThermalCorner,pos,w,h,cfg.ThermalCornerLine) else s.ThermalFill.Visible=false hideList(s.ThermalCorner) end
   if cfg.Health and dist<=cfg.HealthMaxDistance then updateHealth(s.Health,s.HealthBack,s.HealthText,hum,pos,w,h,cfg.HealthWidth,cfg.HealthTextColor) else s.Health.Visible=false s.HealthBack.Visible=false s.HealthText.Visible=false end
   if cfg.NameDistance and dist<=cfg.NameMaxDistance then updateNameDistance(s.Name,s.Distance,plr,pos,w,h,dist) else s.Name.Visible=false s.Distance.Visible=false end
   if cfg.Skeleton then updateSkeleton(s.Skeleton,char,cfg.SkeletonColor) else hideList(s.Skeleton) end
   if cfg.Tracers then local vp=cam.ViewportSize local start=cfg.TracerCenter and Vector2.new(vp.X/2,vp.Y/2) or Vector2.new(vp.X/2,vp.Y) setLine(s.Tracer,start,pos,cfg.TracerThickness,cfg.TracerColor) else s.Tracer.Visible=false end
   if cfg.Box3D then update3D(s.Box3D,root,cfg.Box3DColor) else hideList(s.Box3D) end
   if cfg.ESP and dist<=cfg.ESPMaxDistance and teamPass(plr) then
    local breathe=math.clamp(math.atan(math.sin(os.clock()*2))*2/math.pi,0,1) s.PackChams.Adornee=char s.PackChams.Enabled=true s.PackChams.FillColor=Color3.fromRGB(119,120,255) s.PackChams.OutlineColor=Color3.fromRGB(119,120,255) s.PackChams.FillTransparency=breathe s.PackChams.OutlineTransparency=breathe
    s.PackBox.Position=UDim2.fromOffset(pos.X-w/2,pos.Y-h/2) s.PackBox.Size=UDim2.fromOffset(w,h) s.PackBox.Visible=true s.PackGradient.Rotation=(os.clock()*300)%360 updateCorners(s.PackCorners,pos,w,h,Color3.fromRGB(255,255,255))
    local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1) s.PackHealthBack.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2) s.PackHealthBack.Size=UDim2.fromOffset(2.5,h) s.PackHealthBack.Visible=true s.PackHealth.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2+h*(1-ratio)) s.PackHealth.Size=UDim2.fromOffset(2.5,h*ratio) s.PackHealth.Visible=true s.PackHealthText.Position=UDim2.fromOffset(pos.X-w/2-6,pos.Y-h/2+h*(1-ratio)+3) s.PackHealthText.Text=tostring(math.floor(ratio*100)) s.PackHealthText.TextColor3=Color3.fromRGB(119,120,255) s.PackHealthText.Visible=hum.Health<hum.MaxHealth
    local f=friend(plr) s.PackName.Position=UDim2.fromOffset(pos.X,pos.Y-h/2-9) s.PackName.Text=string.format('(<font color="rgb(%d, %d, %d)">%s</font>) %s [%d]',f and 0 or 255,f and 255 or 0,0,f and "F" or "E",plr.Name,math.floor(dist)) s.PackName.Visible=true s.PackDistance.Visible=false s.PackWeapon.Position=UDim2.fromOffset(pos.X,pos.Y+h/2+8) s.PackWeapon.Text="none" s.PackWeapon.Visible=true
   else s.PackChams.Enabled=false s.PackBox.Visible=false hideList(s.PackCorners) s.PackHealthBack.Visible=false s.PackHealth.Visible=false s.PackHealthText.Visible=false s.PackName.Visible=false s.PackDistance.Visible=false s.PackWeapon.Visible=false end
  end
 end end
end)

local Chams=makeOption("Chams",function(v) cfg.Chams=v end)
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) cfg.ChamsThermal=v end})
Chams.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) cfg.ChamsFill=Color3.fromHSV(h,s,v) end})
Chams.CreateColorSlider({["Name"]="Outline Color",["Function"]=function(h,s,v) cfg.ChamsOutline=Color3.fromHSV(h,s,v) end})
Chams.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.ChamsMaxDistance=v end})
local Corner=makeOption("Corner Box",function(v) cfg.Corner=v end)
Corner.CreateColorSlider({["Name"]="Corner Color",["Function"]=function(h,s,v) cfg.CornerLine=Color3.fromHSV(h,s,v) end}) Corner.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) cfg.CornerFill=Color3.fromHSV(h,s,v) end}) Corner.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.CornerMaxDistance=v end})
local Thermal=makeOption("Thermal Corner",function(v) cfg.ThermalCorner=v end)
Thermal.CreateColorSlider({["Name"]="Corner Color",["Function"]=function(h,s,v) cfg.ThermalCornerLine=Color3.fromHSV(h,s,v) end}) Thermal.CreateColorSlider({["Name"]="Fill Color",["Function"]=function(h,s,v) cfg.ThermalCornerFill=Color3.fromHSV(h,s,v) end}) Thermal.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.ThermalCornerMaxDistance=v end})
local Health=makeOption("HealthBar",function(v) cfg.Health=v end)
Health.CreateToggle({["Name"]="Health Text",["Default"]=true,["Function"]=function(v) cfg.HealthText=v end}) Health.CreateColorSlider({["Name"]="Health Text Color",["Function"]=function(h,s,v) cfg.HealthTextColor=Color3.fromHSV(h,s,v) end}) Health.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.HealthMaxDistance=v end})
local NameDistance=makeOption("Name + Distance",function(v) cfg.NameDistance=v end)
NameDistance.CreateToggle({["Name"]="Friend Check",["Default"]=true,["Function"]=function(v) cfg.FriendCheck=v end}) NameDistance.CreateDropdown({["Name"]="Distance Position",["List"]={"Text","Bottom"},["Function"]=function(v) cfg.DistancePosition=v end}) NameDistance.CreateColorSlider({["Name"]="Name Color",["Function"]=function(h,s,v) cfg.NameColor=Color3.fromHSV(h,s,v) end}) NameDistance.CreateColorSlider({["Name"]="Friend Color",["Function"]=function(h,s,v) cfg.FriendColor=Color3.fromHSV(h,s,v) end}) NameDistance.CreateColorSlider({["Name"]="Distance Color",["Function"]=function(h,s,v) cfg.DistanceColor=Color3.fromHSV(h,s,v) end}) NameDistance.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.NameMaxDistance=v end})
local Skeleton=makeOption("Skeleton",function(v) cfg.Skeleton=v end) Skeleton.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.SkeletonColor=Color3.fromHSV(h,s,v) end})
local Tracers=makeOption("Tracers",function(v) cfg.Tracers=v end) Tracers.CreateToggle({["Name"]="Start From Center",["Default"]=false,["Function"]=function(v) cfg.TracerCenter=v end}) Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.TracerColor=Color3.fromHSV(h,s,v) end}) Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=5,["Default"]=1,["Function"]=function(v) cfg.TracerThickness=v end})
local Box3D=makeOption("3D Box",function(v) cfg.Box3D=v end) Box3D.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) cfg.Box3DColor=Color3.fromHSV(h,s,v) end})
local ESP=makeOption("ESP",function(v) cfg.ESP=v end) ESP.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=1000,["Default"]=200,["Function"]=function(v) cfg.ESPMaxDistance=v end})

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Visuals integrated and functional",3) end)
