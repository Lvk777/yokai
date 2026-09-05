-- Single Visuals preview + Preview/Studio-only ESP wall-check controls.
-- Does not add live-player wallhack behavior. WallCheck colors are demonstrated
-- in Preview and on non-player Humanoid dummies while running in Roblox Studio.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local VisualsRec = objects["VisualsWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
if not Visuals then
    warn("VisualsPreviewControlsFix: Visuals window missing")
    return
end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function underVisuals(rec)
    if not rec or not rec["Object"] then return false end
    local obj = rec["Object"]
    for _, root in ipairs({VisualsRec["Object"], VisualsRec["ChildrenObject"]}) do
        if root and typeof(root)=="Instance" and (obj==root or obj:IsDescendantOf(root)) then return true end
    end
    return false
end

local function findVisualOption(name)
    local best
    for key, rec in pairs(objects) do
        if rec and rec["Type"]=="OptionsButton" and optionName(key)==name and underVisuals(rec) then
            best=rec
        end
    end
    return best
end

local function removeVisualOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec["Type"]=="OptionsButton" and optionName(key)==name and underVisuals(rec) then
            table.insert(keys,key)
        end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            local api=rec and rec["Api"]
            if api and api.Enabled and api.ToggleButton then api.ToggleButton(false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

local function roots()
    local out,seen={},{}
    local function add(x)
        if x and typeof(x)=="Instance" and not seen[x] then seen[x]=true table.insert(out,x) end
    end
    add(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    add(CoreGui)
    add(GuiLibrary["MainGui"])
    pcall(function() if gethui then add(gethui()) end end)
    return out
end

local function destroyOldPreviews()
    for _,root in ipairs(roots()) do
        for _,obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ScreenGui") and (
                obj.Name=="YokaiVisualPreviewV4" or
                obj.Name=="YokaiVisualPreviewV5" or
                obj.Name=="YokaiAttachedESPPreview"
            ) then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

-- Replace every earlier Preview control with one definitive Preview.
removeVisualOption("Preview")
removeVisualOption("Attached Preview")
destroyOldPreviews()

local state={
    Preview=false,
    WallCheck=false,
    PreviewState="Visible",
    TracerOrigin="Bottom",
}
shared.YokaiVisualPreviewState=state

local espRec=findVisualOption("ESP")
local tracerRec=findVisualOption("Tracers")

-- Add safe preview/test controls to the existing modules.
if espRec and espRec.Api then
    pcall(function()
        espRec.Api.CreateToggle({
            ["Name"]="WallCheck",
            ["Default"]=false,
            ["Function"]=function(v) state.WallCheck=v end,
        })
        espRec.Api.CreateDropdown({
            ["Name"]="Preview State",
            ["List"]={"Visible","Occluded"},
            ["Function"]=function(v) state.PreviewState=v end,
        })
    end)
end

if tracerRec and tracerRec.Api then
    pcall(function()
        tracerRec.Api.CreateDropdown({
            ["Name"]="Origin",
            ["List"]={"Top","Bottom","Center","Mouse"},
            ["Function"]=function(v) state.TracerOrigin=v end,
        })
    end)
end

local gui=Instance.new("ScreenGui")
gui.Name="YokaiVisualPreviewV5"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=997
gui.Enabled=false
pcall(function() gui.Parent=(gethui and gethui()) or CoreGui end)
if not gui.Parent then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local frame=Instance.new("Frame")
frame.Name="Window"
frame.Size=UDim2.fromOffset(280,360)
frame.Position=UDim2.new(1,-300,0,72)
frame.BackgroundColor3=Color3.fromRGB(15,15,18)
frame.BorderSizePixel=0
frame.Parent=gui
local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,9) fc.Parent=frame
local fs=Instance.new("UIStroke") fs.Color=Color3.fromRGB(62,64,72) fs.Transparency=.25 fs.Parent=frame

local title=Instance.new("TextLabel")
title.BackgroundTransparency=1
title.Position=UDim2.fromOffset(14,8)
title.Size=UDim2.new(1,-28,0,25)
title.Font=Enum.Font.Code
title.TextSize=13
title.TextColor3=Color3.fromRGB(235,235,240)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Text="Visuals Preview"
title.Parent=frame

local drag=Instance.new("TextLabel")
drag.BackgroundTransparency=1
drag.AnchorPoint=Vector2.new(1,0)
drag.Position=UDim2.new(1,-12,0,8)
drag.Size=UDim2.fromOffset(48,25)
drag.Font=Enum.Font.Code
drag.TextSize=10
drag.TextColor3=Color3.fromRGB(120,122,132)
drag.Text="DRAG"
drag.Parent=frame

local canvas=Instance.new("Frame")
canvas.Position=UDim2.fromOffset(12,38)
canvas.Size=UDim2.new(1,-24,1,-50)
canvas.BackgroundColor3=Color3.fromRGB(20,20,24)
canvas.BorderSizePixel=0
canvas.ClipsDescendants=true
canvas.Parent=frame
local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=canvas

local dragging=false
local dragStart,frameStart,dragInput
local function startDrag(input)
    dragging=true dragStart=input.Position frameStart=frame.Position
    input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
end
for _,handle in ipairs({title,drag}) do
    handle.Active=true
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then startDrag(input) end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end)
end
UserInputService.InputChanged:Connect(function(input)
    if dragging and input==dragInput then
        local d=input.Position-dragStart
        frame.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
    end
end)

local status=Instance.new("TextLabel")
status.BackgroundTransparency=1
status.AnchorPoint=Vector2.new(.5,0)
status.Position=UDim2.new(.5,0,0,8)
status.Size=UDim2.fromOffset(190,18)
status.Font=Enum.Font.Code
status.TextSize=10
status.TextColor3=Color3.fromRGB(150,152,165)
status.Parent=canvas

local wall=Instance.new("Frame")
wall.AnchorPoint=Vector2.new(.5,.5)
wall.Position=UDim2.new(.5,0,.53,0)
wall.Size=UDim2.fromOffset(108,210)
wall.BackgroundColor3=Color3.fromRGB(45,46,52)
wall.BackgroundTransparency=.25
wall.BorderSizePixel=0
wall.Visible=false
wall.Parent=canvas

local dummy=Instance.new("Frame")
dummy.AnchorPoint=Vector2.new(.5,.5)
dummy.Position=UDim2.new(.5,0,.53,0)
dummy.Size=UDim2.fromOffset(66,174)
dummy.BackgroundColor3=Color3.fromRGB(119,120,255)
dummy.BackgroundTransparency=.16
dummy.BorderSizePixel=0
dummy.Parent=canvas
local dc=Instance.new("UICorner") dc.CornerRadius=UDim.new(0,5) dc.Parent=dummy
local outline=Instance.new("UIStroke") outline.Thickness=2 outline.Color=Color3.fromRGB(119,120,255) outline.Parent=dummy

local head=Instance.new("Frame")
head.AnchorPoint=Vector2.new(.5,.5)
head.Position=UDim2.new(.5,0,0,-25)
head.Size=UDim2.fromOffset(36,36)
head.BackgroundColor3=dummy.BackgroundColor3
head.BackgroundTransparency=dummy.BackgroundTransparency
head.BorderSizePixel=0
head.Parent=dummy
local hc=Instance.new("UICorner") hc.CornerRadius=UDim.new(0,5) hc.Parent=head
local ho=Instance.new("UIStroke") ho.Thickness=2 ho.Color=outline.Color ho.Parent=head

local tracer=Instance.new("Frame")
tracer.AnchorPoint=Vector2.new(.5,.5)
tracer.BorderSizePixel=0
tracer.BackgroundColor3=Color3.fromRGB(255,255,255)
tracer.Visible=false
tracer.Parent=canvas

local function setLine(line,a,b,thickness,color)
    local d=b-a
    if d.Magnitude<.01 then line.Visible=false return end
    line.Size=UDim2.fromOffset(d.Magnitude,thickness or 1)
    line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Rotation=math.deg(math.atan2(d.Y,d.X))
    line.BackgroundColor3=color or Color3.new(1,1,1)
    line.Visible=true
end

local Preview=Visuals.CreateOptionsButton({
    ["Name"]="Preview"..ZWSP..ZWSP..ZWSP..ZWSP,
    ["Function"]=function(v)
        state.Preview=v
        gui.Enabled=v
    end,
})

local function enabled(name)
    local rec=findVisualOption(name)
    local api=rec and rec.Api
    return api and api.Enabled==true
end

local purple=Color3.fromRGB(119,120,255)
local visibleGreen=Color3.fromRGB(35,235,95)
local occludedRed=Color3.fromRGB(245,55,55)

RunService.RenderStepped:Connect(function()
    if not state.Preview or not gui.Enabled then return end
    local espOn=enabled("ESP")
    local tracersOn=enabled("Tracers")

    local c=purple
    if espOn and state.WallCheck then
        c=(state.PreviewState=="Occluded") and occludedRed or visibleGreen
    end
    dummy.BackgroundColor3=c head.BackgroundColor3=c outline.Color=c ho.Color=c
    dummy.BackgroundTransparency=espOn and .18 or .58
    head.BackgroundTransparency=dummy.BackgroundTransparency
    outline.Transparency=espOn and 0 or .45
    ho.Transparency=outline.Transparency
    wall.Visible=espOn and state.WallCheck and state.PreviewState=="Occluded"
    status.Text=state.WallCheck and ("WALLCHECK • "..string.upper(state.PreviewState)) or "ESP • PURPLE"
    status.TextColor3=c

    if tracersOn then
        local sz=canvas.AbsoluteSize
        local start
        if state.TracerOrigin=="Top" then
            start=Vector2.new(sz.X/2,0)
        elseif state.TracerOrigin=="Center" then
            start=Vector2.new(sz.X/2,sz.Y/2)
        elseif state.TracerOrigin=="Mouse" then
            local m=UserInputService:GetMouseLocation()
            local a=canvas.AbsolutePosition
            start=Vector2.new(math.clamp(m.X-a.X,0,sz.X),math.clamp(m.Y-a.Y,0,sz.Y))
        else
            start=Vector2.new(sz.X/2,sz.Y)
        end
        setLine(tracer,start,Vector2.new(sz.X/2,sz.Y*.53),1,Color3.fromRGB(255,255,255))
    else
        tracer.Visible=false
    end
end)

-- Roblox Studio: WallCheck testing on non-player Humanoid dummies only.
local studioHighlights=setmetatable({}, {__mode="k"})
local function clearStudio()
    for model,h in pairs(studioHighlights) do
        if h and h.Parent then h:Destroy() end
        studioHighlights[model]=nil
    end
end
local function dummyVisible(model,target)
    local cam=Workspace.CurrentCamera
    if not cam or not target then return false end
    local origin=cam.CFrame.Position
    local direction=target.Position-origin
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,model,cam}
    rp.IgnoreWater=true
    return Workspace:Raycast(origin,direction,rp)==nil
end

local studioTick=0
RunService.Heartbeat:Connect(function(dt)
    if not RunService:IsStudio() then return end
    studioTick+=dt if studioTick<.12 then return end studioTick=0
    if not enabled("ESP") then clearStudio() return end
    local seen={}
    for _,model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
            local hum=model:FindFirstChildOfClass("Humanoid")
            local root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
            if hum and root and hum.Health>0 then
                seen[model]=true
                local h=studioHighlights[model]
                if not h or not h.Parent then
                    h=Instance.new("Highlight")
                    h.Name="YokaiStudioESPWallCheck"
                    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency=.72
                    h.OutlineTransparency=0
                    h.Adornee=model
                    h.Parent=model
                    studioHighlights[model]=h
                end
                local c=purple
                if state.WallCheck then c=dummyVisible(model,root) and visibleGreen or occludedRed end
                h.FillColor=c h.OutlineColor=c h.Enabled=true
            end
        end
    end
    for model,h in pairs(studioHighlights) do
        if not seen[model] then if h and h.Parent then h:Destroy() end studioHighlights[model]=nil end
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai","Visuals Preview restored • Tracer origins enabled",3)
end)
