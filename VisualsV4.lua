-- Yokai Visuals V4
-- Keeps Yokai's original Render implementation intact, except for explicitly
-- hidden legacy modules (Cape / Disguise / Search).
-- Local/self visuals work normally. Target-style visual testing is limited to
-- the Preview and non-player Humanoid dummies while running in Roblox Studio.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local STUDIO = RunService:IsStudio()
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local function notify(title, text)
    pcall(function() GuiLibrary["CreateNotification"](title, text, 4) end)
end

local function removeModule(name)
    local key = name .. "OptionsButton"
    local rec = objects[key]
    if not rec then return end
    pcall(function()
        local api = rec["Api"]
        if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
    end)
    pcall(function() GuiLibrary["RemoveObject"](key) end)
end

-- Render remains original, with only these legacy entries removed as requested.
for _, name in ipairs({"Cape", "Disguise", "Search"}) do removeModule(name) end

-- --------------------------------------------------------------------------
-- Original Breadcrumbs -> Trail + real glow layer.
-- --------------------------------------------------------------------------
local trailGlowEnabled = false
local trailGlowCopies = setmetatable({}, {__mode="k"})
local bloom

local function isOriginalLocalTrail(obj)
    if not obj:IsA("Trail") or obj.Name == "YokaiTrailGlow" then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local a0, a1 = obj.Attachment0, obj.Attachment1
    return (a0 and a0:IsDescendantOf(char)) or (a1 and a1:IsDescendantOf(char))
end

local function ensureBloom()
    if bloom and bloom.Parent then return end
    bloom = Lighting:FindFirstChild("YokaiTrailBloom")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "YokaiTrailBloom"
        bloom.Intensity = 0.55
        bloom.Size = 18
        bloom.Threshold = 0.92
        bloom.Parent = Lighting
    end
end

local function destroyTrailGlow()
    for original, copy in pairs(trailGlowCopies) do
        if copy and copy.Parent then copy:Destroy() end
        trailGlowCopies[original] = nil
    end
    if bloom and bloom.Parent then bloom:Destroy() end
    bloom = nil
end

local function syncGlowCopy(original)
    if not original or not original.Parent then return end
    local copy = trailGlowCopies[original]
    if not copy or not copy.Parent then
        copy = original:Clone()
        copy.Name = "YokaiTrailGlow"
        copy.Attachment0 = original.Attachment0
        copy.Attachment1 = original.Attachment1
        copy.Parent = original.Parent
        trailGlowCopies[original] = copy
    end
    copy.Enabled = original.Enabled
    copy.Attachment0 = original.Attachment0
    copy.Attachment1 = original.Attachment1
    copy.Color = original.Color
    copy.Lifetime = original.Lifetime
    copy.FaceCamera = original.FaceCamera
    copy.LightEmission = 1
    copy.LightInfluence = 0
    copy.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.58),
        NumberSequenceKeypoint.new(1, 0.92),
    })
    pcall(function() copy.WidthScale = NumberSequence.new(1.7) end)
end

local function applyTrailGlow()
    if not trailGlowEnabled then destroyTrailGlow() return end
    ensureBloom()
    local seen = {}
    local containers = {Workspace, Workspace.CurrentCamera}
    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if isOriginalLocalTrail(obj) then
                    seen[obj] = true
                    obj.LightEmission = 1
                    obj.LightInfluence = 0
                    syncGlowCopy(obj)
                end
            end
        end
    end
    for original, copy in pairs(trailGlowCopies) do
        if not seen[original] or not original.Parent then
            if copy and copy.Parent then copy:Destroy() end
            trailGlowCopies[original] = nil
        end
    end
end

local breadcrumbs = objects["BreadcrumbsOptionsButton"]
if breadcrumbs and breadcrumbs["Api"] then
    local root = breadcrumbs["Object"]
    if root and typeof(root) == "Instance" then
        for _, node in ipairs(root:GetDescendants()) do
            if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text == "Breadcrumbs" then node.Text = "Trail" end
        end
        if (root:IsA("TextLabel") or root:IsA("TextButton")) and root.Text == "Breadcrumbs" then root.Text = "Trail" end
    end
    pcall(function()
        breadcrumbs["Api"].CreateToggle({
            ["Name"] = "Glow",
            ["Default"] = false,
            ["Function"] = function(v)
                trailGlowEnabled = v
                applyTrailGlow()
            end,
        })
    end)
end

local glowTick = 0
RunService.Heartbeat:Connect(function(dt)
    if not trailGlowEnabled then return end
    glowTick += dt
    if glowTick >= 0.12 then glowTick = 0 applyTrailGlow() end
end)

-- --------------------------------------------------------------------------
-- Dedicated Visuals tab. Zero-width suffix keeps object keys unique without
-- displaying duplicate text.
-- --------------------------------------------------------------------------
local ZWSP = utf8.char(0x200B)
local function uniqueName(name) return name .. ZWSP end

local Visuals = GuiLibrary.CreateWindow({
    ["Name"] = "Visuals",
    ["Icon"] = "yokai/assets/RenderIcon.png",
    ["IconSize"] = 17,
})
pcall(function() Visuals.SetVisible(false) end)

local visualsOpen = false
local function createVisualsButton()
    local template = objects["RenderButton"] or objects["WorldButton"] or objects["UtilityButton"]
    local source = template and template["Object"]
    if not source then return end
    local button = source:Clone()
    button.Name = "VisualsV4Button"
    button.LayoutOrder = (source.LayoutOrder or 0) + 1
    local changed = false
    if button:IsA("TextButton") or button:IsA("TextLabel") then
        if button.Text == "Render" then button.Text = "Visuals" changed = true end
    end
    for _, node in ipairs(button:GetDescendants()) do
        if not changed and (node:IsA("TextButton") or node:IsA("TextLabel")) and node.Text == "Render" then
            node.Text = "Visuals"
            changed = true
        end
    end
    button.Parent = source.Parent
    button.MouseButton1Click:Connect(function()
        visualsOpen = not visualsOpen
        pcall(function() Visuals.SetVisible(visualsOpen) end)
    end)
end
task.defer(createVisualsButton)

local function makeOption(name, fn)
    return Visuals.CreateOptionsButton({["Name"] = uniqueName(name), ["Function"] = fn})
end

local materialMap = {
    ForceField=Enum.Material.ForceField,
    Neon=Enum.Material.Neon,
    SmoothPlastic=Enum.Material.SmoothPlastic,
    Glass=Enum.Material.Glass,
    Foil=Enum.Material.Foil,
    Metal=Enum.Material.Metal,
    Plastic=Enum.Material.Plastic,
}
local materialList={"ForceField","Neon","SmoothPlastic","Glass","Foil","Metal","Plastic"}

-- --------------------------------------------------------------------------
-- SelfChams (no Aura / no rotating circle).
-- --------------------------------------------------------------------------
local selfEnabled=false
local selfMaterial="ForceField"
local selfColor=Color3.fromRGB(119,120,255)
local selfTransparency=.15
local selfParts=setmetatable({}, {__mode="k"})
local selfTextures=setmetatable({}, {__mode="k"})

local function rememberSelf(part)
    if selfParts[part] then return end
    selfParts[part]={Material=part.Material,Color=part.Color,Transparency=part.Transparency,LocalTransparencyModifier=part.LocalTransparencyModifier,CastShadow=part.CastShadow,TextureID=part:IsA("MeshPart") and part.TextureID or nil}
end

local function applySelf()
    local char=LocalPlayer.Character
    if not char then return end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name~="HumanoidRootPart" and not obj:FindFirstAncestorWhichIsA("Tool") then
            rememberSelf(obj)
            obj.Material=materialMap[selfMaterial] or Enum.Material.ForceField
            obj.Color=selfColor
            obj.Transparency=selfTransparency
            obj.LocalTransparencyModifier=0
            obj.CastShadow=false
            if obj:IsA("MeshPart") then obj.TextureID="" end
        elseif (obj:IsA("Decal") or obj:IsA("Texture")) and not obj:FindFirstAncestorWhichIsA("Tool") then
            if not selfTextures[obj] then selfTextures[obj]=obj.Transparency end
            obj.Transparency=1
        end
    end
    local head=char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        rememberSelf(head)
        head.Material=materialMap[selfMaterial] or Enum.Material.ForceField
        head.Color=selfColor
        head.Transparency=selfTransparency
        head.LocalTransparencyModifier=0
        head.CastShadow=false
        if head:IsA("MeshPart") then head.TextureID="" end
    end
end

local function restoreSelf()
    for part,state in pairs(selfParts) do
        if part and part.Parent then pcall(function()
            part.Material=state.Material part.Color=state.Color part.Transparency=state.Transparency part.LocalTransparencyModifier=state.LocalTransparencyModifier part.CastShadow=state.CastShadow
            if part:IsA("MeshPart") and state.TextureID~=nil then part.TextureID=state.TextureID end
        end) end
    end
    for obj,t in pairs(selfTextures) do if obj and obj.Parent then pcall(function() obj.Transparency=t end) end end
    table.clear(selfParts) table.clear(selfTextures)
end

local SelfChams=makeOption("SelfChams",function(v) selfEnabled=v if v then applySelf() else restoreSelf() end end)
SelfChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) selfMaterial=v if selfEnabled then applySelf() end end})
SelfChams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) selfColor=Color3.fromHSV(h,s,v) if selfEnabled then applySelf() end end})
SelfChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=90,["Default"]=15,["Function"]=function(v) selfTransparency=v/100 if selfEnabled then applySelf() end end})

local selfTimer=0
RunService.Heartbeat:Connect(function(dt)
    if selfEnabled then selfTimer+=dt if selfTimer>=.25 then selfTimer=0 applySelf() end end
end)
LocalPlayer.CharacterAdded:Connect(function() restoreSelf() task.wait(.45) if selfEnabled then applySelf() end end)

-- --------------------------------------------------------------------------
-- Local GunChams.
-- --------------------------------------------------------------------------
local gunEnabled=false
local gunMaterial="ForceField"
local gunVisibleColor=Color3.fromRGB(40,235,90)
local gunOccludedColor=Color3.fromRGB(245,55,55)
local gunUseVisibility=true
local gunTransparency=0
local gunPreviewState="Visible"
local gunState=setmetatable({}, {__mode="k"})
local gunTextures=setmetatable({}, {__mode="k"})

local function isGunPart(part)
    if not part:IsA("BasePart") then return false end
    local char=LocalPlayer.Character
    if char and part:IsDescendantOf(char) and part:FindFirstAncestorWhichIsA("Tool") then return true end
    if Camera and part:IsDescendantOf(Camera) then
        local cur=part.Parent
        while cur and cur~=Camera do
            if cur:IsA("Tool") then return true end
            if cur:IsA("Model") then
                local n=cur.Name:lower()
                if n:find("view") or n:find("weapon") or n:find("gun") or n:find("arms") then return true end
            end
            cur=cur.Parent
        end
    end
    return false
end

local function gunVisible(part)
    if not Camera or part:IsDescendantOf(Camera) then return true end
    local origin=Camera.CFrame.Position
    local direction=part.Position-origin
    if direction.Magnitude<.1 then return true end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,Camera}
    rp.IgnoreWater=true
    local result=Workspace:Raycast(origin,direction,rp)
    return result==nil
end

local function applyGun()
    if not gunEnabled then return end
    local active={}
    local roots={LocalPlayer.Character,Camera}
    for _,root in ipairs(roots) do
        if root then
            for _,obj in ipairs(root:GetDescendants()) do
                if isGunPart(obj) then
                    active[obj]=true
                    if not gunState[obj] then gunState[obj]={Material=obj.Material,Color=obj.Color,Transparency=obj.Transparency,CastShadow=obj.CastShadow,TextureID=obj:IsA("MeshPart") and obj.TextureID or nil} end
                    local visible=(not gunUseVisibility) or gunVisible(obj)
                    obj.Material=materialMap[gunMaterial] or Enum.Material.ForceField
                    obj.Color=visible and gunVisibleColor or gunOccludedColor
                    obj.Transparency=gunTransparency
                    obj.CastShadow=false
                    if obj:IsA("MeshPart") then obj.TextureID="" end
                    for _,d in ipairs(obj:GetDescendants()) do
                        if d:IsA("Decal") or d:IsA("Texture") then if gunTextures[d]==nil then gunTextures[d]=d.Transparency end d.Transparency=1 end
                    end
                end
            end
        end
    end
    for part,state in pairs(gunState) do
        if not active[part] and part and part.Parent then pcall(function()
            part.Material=state.Material part.Color=state.Color part.Transparency=state.Transparency part.CastShadow=state.CastShadow
            if part:IsA("MeshPart") and state.TextureID~=nil then part.TextureID=state.TextureID end
        end) gunState[part]=nil end
    end
end

local function restoreGun()
    for part,state in pairs(gunState) do if part and part.Parent then pcall(function()
        part.Material=state.Material part.Color=state.Color part.Transparency=state.Transparency part.CastShadow=state.CastShadow
        if part:IsA("MeshPart") and state.TextureID~=nil then part.TextureID=state.TextureID end
    end) end end
    for obj,t in pairs(gunTextures) do if obj and obj.Parent then pcall(function() obj.Transparency=t end) end end
    table.clear(gunState) table.clear(gunTextures)
end

local GunChams=makeOption("GunChams",function(v) gunEnabled=v if v then applyGun() else restoreGun() end end)
GunChams.CreateDropdown({["Name"]="Material",["List"]=materialList,["Function"]=function(v) gunMaterial=v if gunEnabled then applyGun() end end})
GunChams.CreateToggle({["Name"]="Visibility Colors",["Default"]=true,["Function"]=function(v) gunUseVisibility=v if gunEnabled then applyGun() end end})
GunChams.CreateColorSlider({["Name"]="Visible Color",["Function"]=function(h,s,v) gunVisibleColor=Color3.fromHSV(h,s,v) end})
GunChams.CreateColorSlider({["Name"]="Occluded Color",["Function"]=function(h,s,v) gunOccludedColor=Color3.fromHSV(h,s,v) end})
GunChams.CreateSlider({["Name"]="Transparency",["Min"]=0,["Max"]=90,["Default"]=0,["Function"]=function(v) gunTransparency=v/100 end})
GunChams.CreateDropdown({["Name"]="Preview State",["List"]={"Visible","Occluded"},["Function"]=function(v) gunPreviewState=v end})
local gunTimer=0
RunService.Heartbeat:Connect(function(dt) if gunEnabled then gunTimer+=dt if gunTimer>=.08 then gunTimer=0 applyGun() end end end)

-- --------------------------------------------------------------------------
-- Preview / Studio dummy visual settings.
-- --------------------------------------------------------------------------
local target={
    Chams=false,ChamsColor=Color3.fromRGB(119,120,255),Thermal=true,
    ESP=false,Box=true,BoxColor=Color3.fromRGB(235,235,240),Health=true,HealthText=true,Name=true,Distance=true,Skeleton=false,SkeletonColor=Color3.fromRGB(235,235,240),
    Tracers=false,TracerOrigin="Bottom",TracerColor=Color3.fromRGB(235,235,240),TracerThickness=1,MaxDistance=1000,
}

local warned=false
local function studioNotice()
    if not STUDIO and not warned then warned=true notify("Visuals","ESP-style target testing is shown in Preview outside Studio; Roblox Studio also supports non-player Humanoid dummies.") end
end

local Chams=makeOption("Chams",function(v) target.Chams=v if v then studioNotice() end end)
Chams.CreateToggle({["Name"]="Thermal",["Default"]=true,["Function"]=function(v) target.Thermal=v end})
Chams.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) target.ChamsColor=Color3.fromHSV(h,s,v) end})

local ESP=makeOption("ESP",function(v) target.ESP=v if v then studioNotice() end end)
ESP.CreateToggle({["Name"]="Box",["Default"]=true,["Function"]=function(v) target.Box=v end})
ESP.CreateColorSlider({["Name"]="Box Color",["Function"]=function(h,s,v) target.BoxColor=Color3.fromHSV(h,s,v) end})
ESP.CreateToggle({["Name"]="Health",["Default"]=true,["Function"]=function(v) target.Health=v end})
ESP.CreateToggle({["Name"]="Health Text",["Default"]=true,["Function"]=function(v) target.HealthText=v end})
ESP.CreateToggle({["Name"]="Name",["Default"]=true,["Function"]=function(v) target.Name=v end})
ESP.CreateToggle({["Name"]="Distance",["Default"]=true,["Function"]=function(v) target.Distance=v end})
ESP.CreateToggle({["Name"]="Skeleton",["Default"]=false,["Function"]=function(v) target.Skeleton=v end})
ESP.CreateColorSlider({["Name"]="Skeleton Color",["Function"]=function(h,s,v) target.SkeletonColor=Color3.fromHSV(h,s,v) end})
ESP.CreateSlider({["Name"]="Max Distance",["Min"]=50,["Max"]=2000,["Default"]=1000,["Function"]=function(v) target.MaxDistance=v end})

local Tracers=makeOption("Tracers",function(v) target.Tracers=v if v then studioNotice() end end)
Tracers.CreateDropdown({["Name"]="Origin",["List"]={"Bottom","Center","Mouse","Top"},["Function"]=function(v) target.TracerOrigin=v end})
Tracers.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) target.TracerColor=Color3.fromHSV(h,s,v) end})
Tracers.CreateSlider({["Name"]="Thickness",["Min"]=1,["Max"]=3,["Default"]=1,["Function"]=function(v) target.TracerThickness=v end})

-- Local camera options.
local fovEnabled=false
local fovValue=70
local originalFov=setmetatable({}, {__mode="k"})
local function applyFov()
    local cam=Workspace.CurrentCamera if not cam then return end
    if originalFov[cam]==nil then originalFov[cam]=cam.FieldOfView end
    cam.FieldOfView=fovEnabled and fovValue or (originalFov[cam] or 70)
end
local FOV=makeOption("FOVChanger",function(v) fovEnabled=v applyFov() end)
FOV.CreateSlider({["Name"]="FOV",["Min"]=40,["Max"]=120,["Default"]=70,["Function"]=function(v) fovValue=v if fovEnabled then applyFov() end end})

local noMenuFog=false
local function applyNoMenuFog()
    pcall(function()
        if GuiLibrary["MainBlur"] then GuiLibrary["MainBlur"].Size=noMenuFog and 0 or 25 end
        if noMenuFog then RunService:SetRobloxGuiFocused(false) end
    end)
end
local NoMenuFog=makeOption("NoMenuFog",function(v) noMenuFog=v applyNoMenuFog() end)

-- --------------------------------------------------------------------------
-- Refined draggable Preview.
-- --------------------------------------------------------------------------
local previewEnabled=false
local previewGui,previewFrame,canvas
local preview={body={},corners={},skeleton={}}

local function newLabel(parent,size,textSize)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1 t.AnchorPoint=Vector2.new(.5,.5) t.Size=size or UDim2.fromOffset(140,18)
    t.Font=Enum.Font.Code t.TextSize=textSize or 11 t.TextStrokeTransparency=0 t.TextColor3=Color3.fromRGB(235,235,240) t.Visible=false t.Parent=parent
    return t
end
local function newLine(parent)
    local f=Instance.new("Frame") f.BorderSizePixel=0 f.AnchorPoint=Vector2.new(.5,.5) f.Size=UDim2.fromOffset(0,1) f.BackgroundColor3=Color3.new(1,1,1) f.Visible=false f.Parent=parent return f
end
local function setLine(line,a,b,thickness,color)
    local d=b-a if d.Magnitude<.01 then line.Visible=false return end
    line.Size=UDim2.fromOffset(d.Magnitude,thickness or 1) line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2) line.Rotation=math.deg(math.atan2(d.Y,d.X)) line.BackgroundColor3=color or Color3.new(1,1,1) line.Visible=true
end

local function draggable(handle,frame)
    local dragging=false local startMouse local startPos local dragInput
    handle.Active=true
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true startMouse=input.Position startPos=frame.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    handle.InputChanged:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input==dragInput then local d=input.Position-startMouse frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end
    end)
end

local function bodyPart(pos,size)
    local f=Instance.new("Frame") f.AnchorPoint=Vector2.new(.5,.5) f.Position=pos f.Size=size f.BorderSizePixel=0 f.BackgroundColor3=Color3.fromRGB(88,90,100) f.Parent=canvas
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,4) c.Parent=f table.insert(preview.body,f) return f
end

local function buildPreview()
    if previewGui and previewGui.Parent then return end
    previewGui=Instance.new("ScreenGui") previewGui.Name="YokaiVisualPreviewV4" previewGui.ResetOnSpawn=false previewGui.IgnoreGuiInset=true previewGui.DisplayOrder=997 previewGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
    previewFrame=Instance.new("Frame") previewFrame.Position=UDim2.new(1,-300,0,72) previewFrame.Size=UDim2.fromOffset(270,350) previewFrame.BackgroundColor3=Color3.fromRGB(15,15,18) previewFrame.BorderSizePixel=0 previewFrame.Parent=previewGui
    local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,9) fc.Parent=previewFrame
    local fs=Instance.new("UIStroke") fs.Color=Color3.fromRGB(62,64,72) fs.Transparency=.25 fs.Parent=previewFrame
    local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(14,8) title.Size=UDim2.new(1,-28,0,25) title.Font=Enum.Font.Code title.TextSize=13 title.TextColor3=Color3.fromRGB(235,235,240) title.TextXAlignment=Enum.TextXAlignment.Left title.Text="Visuals Preview" title.Parent=previewFrame
    local drag=Instance.new("TextLabel") drag.BackgroundTransparency=1 drag.AnchorPoint=Vector2.new(1,0) drag.Position=UDim2.new(1,-12,0,8) drag.Size=UDim2.fromOffset(48,25) drag.Font=Enum.Font.Code drag.TextSize=10 drag.TextColor3=Color3.fromRGB(120,122,132) drag.Text="DRAG" drag.Parent=previewFrame
    draggable(title,previewFrame) draggable(drag,previewFrame)
    canvas=Instance.new("Frame") canvas.Position=UDim2.fromOffset(12,38) canvas.Size=UDim2.new(1,-24,1,-50) canvas.BackgroundColor3=Color3.fromRGB(20,20,24) canvas.BorderSizePixel=0 canvas.ClipsDescendants=true canvas.Parent=previewFrame
    local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=canvas

    preview.badge=newLabel(canvas,UDim2.fromOffset(120,16),9) preview.badge.AnchorPoint=Vector2.new(.5,0) preview.badge.Position=UDim2.new(.5,0,0,6) preview.badge.Text=STUDIO and "STUDIO DUMMY" or "PREVIEW" preview.badge.TextColor3=Color3.fromRGB(145,148,160) preview.badge.Visible=true
    preview.name=newLabel(canvas) preview.distance=newLabel(canvas)
    preview.healthBack=Instance.new("Frame") preview.healthBack.BorderSizePixel=0 preview.healthBack.BackgroundColor3=Color3.fromRGB(8,8,9) preview.healthBack.Visible=false preview.healthBack.Parent=canvas
    preview.health=Instance.new("Frame") preview.health.BorderSizePixel=0 preview.health.BackgroundColor3=Color3.fromRGB(45,220,95) preview.health.Visible=false preview.health.Parent=canvas
    preview.healthText=newLabel(canvas,UDim2.fromOffset(44,15),10)
    preview.tracer=newLine(canvas)
    for i=1,8 do preview.corners[i]=newLine(canvas) end
    for i=1,8 do preview.skeleton[i]=newLine(canvas) end

    preview.head=bodyPart(UDim2.new(.5,0,.27,0),UDim2.fromOffset(32,32))
    preview.torso=bodyPart(UDim2.new(.5,0,.48,0),UDim2.fromOffset(44,70))
    preview.la=bodyPart(UDim2.new(.36,0,.48,0),UDim2.fromOffset(14,66))
    preview.ra=bodyPart(UDim2.new(.64,0,.48,0),UDim2.fromOffset(14,66))
    preview.ll=bodyPart(UDim2.new(.45,0,.75,0),UDim2.fromOffset(16,70))
    preview.rl=bodyPart(UDim2.new(.55,0,.75,0),UDim2.fromOffset(16,70))
    preview.gun=Instance.new("Frame") preview.gun.AnchorPoint=Vector2.new(.5,.5) preview.gun.Position=UDim2.new(.72,0,.47,0) preview.gun.Size=UDim2.fromOffset(42,7) preview.gun.BorderSizePixel=0 preview.gun.Visible=false preview.gun.Parent=canvas
    local gc=Instance.new("UICorner") gc.CornerRadius=UDim.new(0,2) gc.Parent=preview.gun
end

local Preview=makeOption("Preview",function(v) previewEnabled=v buildPreview() previewGui.Enabled=v end)

local function updatePreview()
    if not previewEnabled or not canvas or not canvas.Parent then return end
    local sz=canvas.AbsoluteSize if sz.X<5 or sz.Y<5 then return end
    local cx,cy=sz.X*.5,sz.Y*.53 local w,h=70,184
    local base=selfEnabled and selfColor or (target.Chams and target.ChamsColor or Color3.fromRGB(88,90,100))
    local trans=selfEnabled and selfTransparency or (target.Chams and (target.Thermal and .28 or .08) or .08)
    for _,part in ipairs(preview.body) do part.BackgroundColor3=base part.BackgroundTransparency=trans end

    preview.name.Position=UDim2.fromOffset(cx,cy-h/2-12) preview.name.Text="Dummy" preview.name.Visible=target.ESP and target.Name
    preview.distance.Position=UDim2.fromOffset(cx,cy+h/2+10) preview.distance.Text="87 studs" preview.distance.Visible=target.ESP and target.Distance
    local ratio=.76 local bx=cx-w/2-7
    preview.healthBack.Position=UDim2.fromOffset(bx,cy-h/2) preview.healthBack.Size=UDim2.fromOffset(3,h) preview.healthBack.Visible=target.ESP and target.Health
    preview.health.Position=UDim2.fromOffset(bx,cy-h/2+h*(1-ratio)) preview.health.Size=UDim2.fromOffset(3,h*ratio) preview.health.Visible=target.ESP and target.Health
    preview.healthText.Position=UDim2.fromOffset(bx-18,cy-h/2+h*(1-ratio)) preview.healthText.Text="76%" preview.healthText.Visible=target.ESP and target.Health and target.HealthText

    local l,r,t,b=cx-w/2,cx+w/2,cy-h/2,cy+h/2 local cw,ch=17,26
    local pts={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
    for i,p in ipairs(pts) do if target.ESP and target.Box then setLine(preview.corners[i],p[1],p[2],1,target.BoxColor) else preview.corners[i].Visible=false end end

    local points={Vector2.new(cx,cy-70),Vector2.new(cx,cy-34),Vector2.new(cx,cy+10),Vector2.new(cx-25,cy-30),Vector2.new(cx+25,cy-30),Vector2.new(cx-14,cy+78),Vector2.new(cx+14,cy+78)}
    local edges={{1,2},{2,3},{2,4},{2,5},{3,6},{3,7}}
    for i,line in ipairs(preview.skeleton) do local e=edges[i] if target.ESP and target.Skeleton and e then setLine(line,points[e[1]],points[e[2]],1,target.SkeletonColor) else line.Visible=false end end

    if target.Tracers then
        local origin
        if target.TracerOrigin=="Center" then origin=Vector2.new(sz.X/2,sz.Y/2)
        elseif target.TracerOrigin=="Top" then origin=Vector2.new(sz.X/2,1)
        elseif target.TracerOrigin=="Mouse" then local m=UserInputService:GetMouseLocation()-canvas.AbsolutePosition origin=Vector2.new(math.clamp(m.X,0,sz.X),math.clamp(m.Y,0,sz.Y))
        else origin=Vector2.new(sz.X/2,sz.Y-1) end
        setLine(preview.tracer,origin,Vector2.new(cx,cy),target.TracerThickness,target.TracerColor)
    else preview.tracer.Visible=false end

    preview.gun.Visible=gunEnabled
    if gunEnabled then preview.gun.BackgroundColor3=(gunPreviewState=="Visible") and gunVisibleColor or gunOccludedColor preview.gun.BackgroundTransparency=gunTransparency end
end

-- --------------------------------------------------------------------------
-- Studio-only non-player dummy rendering.
-- --------------------------------------------------------------------------
local studioGui=Instance.new("ScreenGui") studioGui.Name="YokaiVisualsV4StudioTargets" studioGui.ResetOnSpawn=false studioGui.IgnoreGuiInset=true studioGui.DisplayOrder=996 studioGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
local packs={}
local function isDummy(model)
    return STUDIO and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) and model~=LocalPlayer.Character and model:FindFirstChildOfClass("Humanoid") and model:FindFirstChild("HumanoidRootPart")
end
local function makePack(model)
    local p={model=model,corners={}}
    p.highlight=Instance.new("Highlight") p.highlight.Enabled=false p.highlight.Parent=Workspace
    p.healthBack=Instance.new("Frame") p.healthBack.BorderSizePixel=0 p.healthBack.BackgroundColor3=Color3.new(0,0,0) p.healthBack.Visible=false p.healthBack.Parent=studioGui
    p.health=Instance.new("Frame") p.health.BorderSizePixel=0 p.health.BackgroundColor3=Color3.fromRGB(45,220,95) p.health.Visible=false p.health.Parent=studioGui
    p.healthText=newLabel(studioGui,UDim2.fromOffset(44,15),10) p.name=newLabel(studioGui) p.distance=newLabel(studioGui) p.tracer=newLine(studioGui)
    for i=1,8 do p.corners[i]=newLine(studioGui) end
    packs[model]=p return p
end
local function hidePack(p)
    p.highlight.Enabled=false p.healthBack.Visible=false p.health.Visible=false p.healthText.Visible=false p.name.Visible=false p.distance.Visible=false p.tracer.Visible=false for _,x in ipairs(p.corners) do x.Visible=false end
end
local function scanDummies()
    if not STUDIO then return end local seen={}
    for _,obj in ipairs(Workspace:GetDescendants()) do if isDummy(obj) then seen[obj]=true if not packs[obj] then makePack(obj) end end end
    for model,p in pairs(packs) do if not seen[model] or not model.Parent then
        for _,x in pairs(p) do if typeof(x)=="Instance" then pcall(function() x:Destroy() end) elseif type(x)=="table" then for _,q in ipairs(x) do pcall(function() q:Destroy() end) end end end packs[model]=nil
    end end
end
local function studioTracerOrigin(vp)
    if target.TracerOrigin=="Center" then return Vector2.new(vp.X/2,vp.Y/2) end
    if target.TracerOrigin=="Top" then return Vector2.new(vp.X/2,1) end
    if target.TracerOrigin=="Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(vp.X/2,vp.Y-1)
end
local function updateStudio()
    if not STUDIO or not Camera then return end local vp=Camera.ViewportSize
    for model,p in pairs(packs) do
        local hum=model:FindFirstChildOfClass("Humanoid") local root=model:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health<=0 then hidePack(p) continue end
        local dist=(Camera.CFrame.Position-root.Position).Magnitude if dist>target.MaxDistance then hidePack(p) continue end
        local sp,on=Camera:WorldToViewportPoint(root.Position)
        if target.Chams then p.highlight.Adornee=model p.highlight.Enabled=true p.highlight.FillColor=target.ChamsColor p.highlight.OutlineColor=target.ChamsColor p.highlight.FillTransparency=target.Thermal and .45 or .65 p.highlight.OutlineTransparency=.05 else p.highlight.Enabled=false end
        if on and sp.Z>0 then
            local scale=(root.Size.Y*vp.Y)/(sp.Z*2) local w,h=math.max(22,3*scale),math.max(42,4.5*scale) local x,y=sp.X,sp.Y
            local l,r,t,b=x-w/2,x+w/2,y-h/2,y+h/2 local cw,ch=math.max(5,w/5),math.max(5,h/5)
            local pts={{Vector2.new(l,t),Vector2.new(l+cw,t)},{Vector2.new(l,t),Vector2.new(l,t+ch)},{Vector2.new(r,t),Vector2.new(r-cw,t)},{Vector2.new(r,t),Vector2.new(r,t+ch)},{Vector2.new(l,b),Vector2.new(l+cw,b)},{Vector2.new(l,b),Vector2.new(l,b-ch)},{Vector2.new(r,b),Vector2.new(r-cw,b)},{Vector2.new(r,b),Vector2.new(r,b-ch)}}
            for i,q in ipairs(pts) do if target.ESP and target.Box then setLine(p.corners[i],q[1],q[2],1,target.BoxColor) else p.corners[i].Visible=false end end
            local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1) local bx=x-w/2-7
            p.healthBack.Position=UDim2.fromOffset(bx,y-h/2) p.healthBack.Size=UDim2.fromOffset(3,h) p.healthBack.Visible=target.ESP and target.Health
            p.health.Position=UDim2.fromOffset(bx,y-h/2+h*(1-ratio)) p.health.Size=UDim2.fromOffset(3,h*ratio) p.health.Visible=target.ESP and target.Health
            p.healthText.Position=UDim2.fromOffset(bx-18,y-h/2+h*(1-ratio)) p.healthText.Text=string.format("%d%%",math.floor(ratio*100)) p.healthText.Visible=target.ESP and target.Health and target.HealthText
            p.name.Position=UDim2.fromOffset(x,y-h/2-12) p.name.Text=model.Name p.name.Visible=target.ESP and target.Name
            p.distance.Position=UDim2.fromOffset(x,y+h/2+10) p.distance.Text=string.format("%d studs",math.floor(dist)) p.distance.Visible=target.ESP and target.Distance
            if target.Tracers then setLine(p.tracer,studioTracerOrigin(vp),Vector2.new(x,y),target.TracerThickness,target.TracerColor) else p.tracer.Visible=false end
        else hidePack(p) if target.Chams then p.highlight.Enabled=true end end
    end
end

local scanTimer=0
RunService.RenderStepped:Connect(function() updatePreview() updateStudio() end)
RunService.Heartbeat:Connect(function(dt) if STUDIO then scanTimer+=dt if scanTimer>=.6 then scanTimer=0 scanDummies() end end end)
if STUDIO then scanDummies() end

notify("Yokai", STUDIO and "Visuals V4 loaded • Studio dummy mode" or "Visuals V4 loaded")
