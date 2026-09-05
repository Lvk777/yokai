-- Final Visuals UX pass.
-- Safe/local UI fixes only: robust NoMenuFog restore, one polished Preview,
-- configurable Preview/Studio wall-check colors, and a single tracer Origin control.
-- No live-player wall-check behavior is added here.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local VisualsRec = objects["VisualsWindow"]
local UtilityRec = objects["UtilityWindow"]
local Visuals = VisualsRec and VisualsRec["Api"]
local Utility = UtilityRec and UtilityRec["Api"]
if not Visuals or not Utility then
    warn("VisualsUXFinalFix: Visuals/Utility missing")
    return
end

local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end

local function isUnder(rec, parentRec)
    if not rec or not rec["Object"] or not parentRec then return false end
    local obj = rec["Object"]
    for _, root in ipairs({parentRec["Object"], parentRec["ChildrenObject"]}) do
        if root and typeof(root)=="Instance" then
            if obj==root or obj:IsDescendantOf(root) then return true end
        end
    end
    return false
end

local function findVisualOption(name)
    local found
    for key,rec in pairs(objects) do
        if rec and rec["Type"]=="OptionsButton" and optionName(key)==name and isUnder(rec,VisualsRec) then
            found=rec
        end
    end
    return found
end

local function removeNormalizedOption(name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec["Type"]=="OptionsButton" and optionName(key)==name then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do
        local rec=objects[key]
        pcall(function()
            local api=rec and rec["Api"]
            if api and api["Enabled"] and api["ToggleButton"] then api["ToggleButton"](false) end
        end)
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

local function removeControlsUnder(parentRec, names)
    if not parentRec then return end
    local wanted={}
    for _,n in ipairs(names) do wanted[n]=true end
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec["Object"] and isUnder(rec,parentRec) then
            local ck=clean(key)
            for name in pairs(wanted) do
                if ck:find(name,1,true) then
                    table.insert(keys,key)
                    break
                end
            end
        end
    end
    for _,key in ipairs(keys) do
        pcall(function() GuiLibrary["RemoveObject"](key) end)
    end
end

-- --------------------------------------------------------------------------
-- Utility > NoMenuFog: ON = no menu blur; OFF = restore the normal menu blur.
-- The older patch sometimes captured 0 as the "original" blur, so OFF could not
-- restore anything. Use a stable positive baseline and resync on ClickGui visibility.
-- --------------------------------------------------------------------------
removeNormalizedOption("NoMenuFog")

if shared.YokaiNoMenuFogVisibilityConnection then
    pcall(function() shared.YokaiNoMenuFogVisibilityConnection:Disconnect() end)
    shared.YokaiNoMenuFogVisibilityConnection=nil
end

local blurBaseline=25
pcall(function()
    local v=GuiLibrary["MainBlur"] and tonumber(GuiLibrary["MainBlur"].Size)
    if v and v>0 then blurBaseline=v end
end)

local noMenuFogEnabled=false
local clickGui=GuiLibrary["MainGui"] and GuiLibrary["MainGui"]:FindFirstChild("ClickGui",true)

local function applyMenuFogState()
    pcall(function()
        if GuiLibrary["MainBlur"] then GuiLibrary["MainBlur"].Size=noMenuFogEnabled and 0 or blurBaseline end
        if noMenuFogEnabled then
            RunService:SetRobloxGuiFocused(false)
        elseif clickGui and clickGui.Visible then
            RunService:SetRobloxGuiFocused(true)
        end
    end)
end

local NoMenuFog=Utility.CreateOptionsButton({
    ["Name"]="NoMenuFog",
    ["Function"]=function(v)
        noMenuFogEnabled=v
        applyMenuFogState()
    end,
    ["HoverText"]="Removes only Yokai's menu blur while enabled and restores it when disabled.",
})

if clickGui then
    shared.YokaiNoMenuFogVisibilityConnection=clickGui:GetPropertyChangedSignal("Visible"):Connect(function()
        task.defer(applyMenuFogState)
    end)
end

-- --------------------------------------------------------------------------
-- Replace old Preview controls and stale preview GUIs.
-- --------------------------------------------------------------------------
removeNormalizedOption("Preview")
removeNormalizedOption("Attached Preview")

local function guiRoots()
    local out,seen={},{}
    local function add(x) if x and typeof(x)=="Instance" and not seen[x] then seen[x]=true table.insert(out,x) end end
    add(LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    add(CoreGui)
    add(GuiLibrary["MainGui"])
    pcall(function() if gethui then add(gethui()) end end)
    return out
end

for _,root in ipairs(guiRoots()) do
    for _,obj in ipairs(root:GetDescendants()) do
        if obj:IsA("ScreenGui") and (
            obj.Name=="YokaiVisualPreviewV4" or obj.Name=="YokaiVisualPreviewV5" or
            obj.Name=="YokaiVisualPreviewV6" or obj.Name=="YokaiAttachedESPPreview"
        ) then pcall(function() obj:Destroy() end) end
    end
end

local espRec=findVisualOption("ESP")
local tracerRec=findVisualOption("Tracers")

-- Remove only our old/conflicting subcontrols. Keep the user's original Color and Thickness.
removeControlsUnder(espRec,{"WallCheck","Preview State","ESP Color","Visible Color","Occluded Color"})
removeControlsUnder(tracerRec,{"Start From Center","Origin"})

local state={
    Preview=false,
    WallCheck=false,
    PreviewState="Visible",
    DefaultColor=Color3.fromRGB(119,120,255),
    VisibleColor=Color3.fromRGB(35,235,95),
    OccludedColor=Color3.fromRGB(245,55,55),
    TracerOrigin="Bottom",
}
shared.YokaiVisualPreviewState=state

if espRec and espRec["Api"] then
    pcall(function()
        espRec["Api"].CreateToggle({
            ["Name"]="WallCheck",
            ["Default"]=false,
            ["Function"]=function(v) state.WallCheck=v end,
        })
        espRec["Api"].CreateDropdown({
            ["Name"]="Preview State",
            ["List"]={"Visible","Occluded"},
            ["Function"]=function(v) state.PreviewState=v end,
        })
        espRec["Api"].CreateColorSlider({
            ["Name"]="ESP Color",
            ["Function"]=function(h,s,v) state.DefaultColor=Color3.fromHSV(h,s,v) end,
        })
        espRec["Api"].CreateColorSlider({
            ["Name"]="Visible Color",
            ["Function"]=function(h,s,v) state.VisibleColor=Color3.fromHSV(h,s,v) end,
        })
        espRec["Api"].CreateColorSlider({
            ["Name"]="Occluded Color",
            ["Function"]=function(h,s,v) state.OccludedColor=Color3.fromHSV(h,s,v) end,
        })
    end)
end

if tracerRec and tracerRec["Api"] then
    pcall(function()
        tracerRec["Api"].CreateDropdown({
            ["Name"]="Origin",
            ["List"]={"Top","Bottom","Center","Mouse"},
            ["Function"]=function(v) state.TracerOrigin=v end,
        })
    end)
end

local function enabled(name)
    local rec=findVisualOption(name)
    local api=rec and rec["Api"]
    return api and api["Enabled"]==true
end

-- --------------------------------------------------------------------------
-- Polished single preview: humanoid silhouette + optional health/name/skeleton.
-- --------------------------------------------------------------------------
local gui=Instance.new("ScreenGui")
gui.Name="YokaiVisualPreviewV6"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=997
gui.Enabled=false
pcall(function() gui.Parent=(gethui and gethui()) or CoreGui end)
if not gui.Parent then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local frame=Instance.new("Frame")
frame.Name="Window"
frame.Size=UDim2.fromOffset(300,390)
frame.Position=UDim2.new(1,-320,0,72)
frame.BackgroundColor3=Color3.fromRGB(15,15,18)
frame.BorderSizePixel=0
frame.Parent=gui
local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(0,9) fc.Parent=frame
local fs=Instance.new("UIStroke") fs.Color=Color3.fromRGB(62,64,72) fs.Transparency=.25 fs.Parent=frame

local title=Instance.new("TextLabel")
title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(14,8) title.Size=UDim2.new(1,-28,0,25)
title.Font=Enum.Font.Code title.TextSize=13 title.TextColor3=Color3.fromRGB(235,235,240)
title.TextXAlignment=Enum.TextXAlignment.Left title.Text="Visuals Preview" title.Parent=frame
local drag=Instance.new("TextLabel")
drag.BackgroundTransparency=1 drag.AnchorPoint=Vector2.new(1,0) drag.Position=UDim2.new(1,-12,0,8)
drag.Size=UDim2.fromOffset(48,25) drag.Font=Enum.Font.Code drag.TextSize=10 drag.TextColor3=Color3.fromRGB(120,122,132)
drag.Text="DRAG" drag.Parent=frame

local canvas=Instance.new("Frame")
canvas.Position=UDim2.fromOffset(12,38) canvas.Size=UDim2.new(1,-24,1,-50)
canvas.BackgroundColor3=Color3.fromRGB(20,20,24) canvas.BorderSizePixel=0 canvas.ClipsDescendants=true canvas.Parent=frame
local cc=Instance.new("UICorner") cc.CornerRadius=UDim.new(0,6) cc.Parent=canvas

local dragging=false local dragStart,frameStart,dragInput
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
status.BackgroundTransparency=1 status.AnchorPoint=Vector2.new(.5,0) status.Position=UDim2.new(.5,0,0,8)
status.Size=UDim2.fromOffset(210,18) status.Font=Enum.Font.Code status.TextSize=10 status.TextColor3=state.DefaultColor status.Parent=canvas

local nameLabel=Instance.new("TextLabel")
nameLabel.BackgroundTransparency=1 nameLabel.AnchorPoint=Vector2.new(.5,.5) nameLabel.Position=UDim2.new(.5,0,.12,0)
nameLabel.Size=UDim2.fromOffset(180,18) nameLabel.Font=Enum.Font.Code nameLabel.TextSize=11 nameLabel.TextStrokeTransparency=0
nameLabel.TextColor3=Color3.new(1,1,1) nameLabel.Text="(F) Dummy [87]" nameLabel.Visible=false nameLabel.Parent=canvas
local distanceLabel=nameLabel:Clone()
distanceLabel.Position=UDim2.new(.5,0,.88,0) distanceLabel.Text="87 meters" distanceLabel.Parent=canvas

local bodyRoot=Instance.new("Frame")
bodyRoot.AnchorPoint=Vector2.new(.5,.5) bodyRoot.Position=UDim2.new(.5,0,.54,0) bodyRoot.Size=UDim2.fromOffset(150,230)
bodyRoot.BackgroundTransparency=1 bodyRoot.Parent=canvas

local parts={}
local function bodyPart(name,pos,size)
    local p=Instance.new("Frame") p.Name=name p.AnchorPoint=Vector2.new(.5,.5) p.Position=pos p.Size=size
    p.BorderSizePixel=0 p.BackgroundColor3=state.DefaultColor p.BackgroundTransparency=.12 p.Parent=bodyRoot
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,5) c.Parent=p
    local s=Instance.new("UIStroke") s.Name="Outline" s.Thickness=1.4 s.Color=state.DefaultColor s.Transparency=.05 s.Parent=p
    parts[name]=p return p
end
bodyPart("Head",UDim2.new(.5,0,.10,0),UDim2.fromOffset(40,40))
bodyPart("Torso",UDim2.new(.5,0,.40,0),UDim2.fromOffset(62,92))
bodyPart("LeftArm",UDim2.new(.25,0,.42,0),UDim2.fromOffset(18,92))
bodyPart("RightArm",UDim2.new(.75,0,.42,0),UDim2.fromOffset(18,92))
bodyPart("LeftLeg",UDim2.new(.40,0,.79,0),UDim2.fromOffset(22,88))
bodyPart("RightLeg",UDim2.new(.60,0,.79,0),UDim2.fromOffset(22,88))

local wall=Instance.new("Frame")
wall.AnchorPoint=Vector2.new(.5,.5) wall.Position=UDim2.new(.5,0,.54,0) wall.Size=UDim2.fromOffset(175,250)
wall.BackgroundColor3=Color3.fromRGB(55,56,62) wall.BackgroundTransparency=.72 wall.BorderSizePixel=0 wall.ZIndex=5 wall.Visible=false wall.Parent=canvas

local healthBack=Instance.new("Frame")
healthBack.BorderSizePixel=0 healthBack.BackgroundColor3=Color3.new(0,0,0) healthBack.Size=UDim2.fromOffset(5,210)
healthBack.Position=UDim2.new(.5,-92,.5,-105) healthBack.Visible=false healthBack.Parent=canvas
local health=Instance.new("Frame")
health.BorderSizePixel=0 health.BackgroundColor3=Color3.new(1,1,1) health.AnchorPoint=Vector2.new(0,1)
health.Position=UDim2.new(0,0,1,0) health.Size=UDim2.new(1,0,.76,0) health.Parent=healthBack
local grad=Instance.new("UIGradient") grad.Rotation=-90 grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(60,60,125)),ColorSequenceKeypoint.new(1,Color3.fromRGB(119,120,255))}) grad.Parent=health
local hpText=nameLabel:Clone() hpText.Size=UDim2.fromOffset(36,16) hpText.Position=UDim2.new(.5,-105,.5,-55) hpText.Text="76" hpText.Visible=false hpText.Parent=canvas

local tracer=Instance.new("Frame")
tracer.AnchorPoint=Vector2.new(.5,.5) tracer.BorderSizePixel=0 tracer.BackgroundColor3=Color3.new(1,1,1) tracer.Visible=false tracer.Parent=canvas
local skeletonLines={}
for i=1,10 do local l=tracer:Clone() l.Visible=false l.Parent=canvas skeletonLines[i]=l end
local function setLine(line,a,b,thickness,color)
    local d=b-a if d.Magnitude<.01 then line.Visible=false return end
    line.Size=UDim2.fromOffset(d.Magnitude,thickness or 1) line.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    line.Rotation=math.deg(math.atan2(d.Y,d.X)) line.BackgroundColor3=color or Color3.new(1,1,1) line.Visible=true
end

local Preview=Visuals.CreateOptionsButton({
    ["Name"]="Preview"..ZWSP..ZWSP..ZWSP..ZWSP..ZWSP,
    ["Function"]=function(v) state.Preview=v gui.Enabled=v end,
})

local function currentESPColor()
    if state.WallCheck then return state.PreviewState=="Occluded" and state.OccludedColor or state.VisibleColor end
    return state.DefaultColor
end

RunService.RenderStepped:Connect(function()
    if not state.Preview or not gui.Enabled then return end
    local espOn=enabled("ESP")
    local tracerOn=enabled("Tracers")
    local healthOn=enabled("HealthBar")
    local nameOn=enabled("Name + Distance")
    local skeletonOn=enabled("Skeleton")
    local c=espOn and currentESPColor() or Color3.fromRGB(86,88,98)

    for _,p in pairs(parts) do
        p.BackgroundColor3=c p.BackgroundTransparency=espOn and .12 or .38
        local s=p:FindFirstChild("Outline") if s then s.Color=c s.Transparency=espOn and .05 or .45 end
    end
    status.Text=state.WallCheck and ("WALLCHECK • "..string.upper(state.PreviewState)) or "ESP PREVIEW"
    status.TextColor3=c
    wall.Visible=espOn and state.WallCheck and state.PreviewState=="Occluded"

    nameLabel.Visible=nameOn nameLabel.TextColor3=Color3.new(1,1,1)
    distanceLabel.Visible=nameOn distanceLabel.TextColor3=Color3.new(1,1,1)
    healthBack.Visible=healthOn hpText.Visible=healthOn hpText.TextColor3=Color3.fromRGB(119,120,255)

    if skeletonOn then
        local center=Vector2.new(canvas.AbsoluteSize.X/2,canvas.AbsoluteSize.Y*.54)
        local pts={
            head=center+Vector2.new(0,-92), chest=center+Vector2.new(0,-36), hip=center+Vector2.new(0,34),
            ls=center+Vector2.new(-44,-34), lh=center+Vector2.new(-54,24), rs=center+Vector2.new(44,-34), rh=center+Vector2.new(54,24),
            lk=center+Vector2.new(-20,78), lf=center+Vector2.new(-22,112), rk=center+Vector2.new(20,78), rf=center+Vector2.new(22,112),
        }
        local edges={{"head","chest"},{"chest","hip"},{"chest","ls"},{"ls","lh"},{"chest","rs"},{"rs","rh"},{"hip","lk"},{"lk","lf"},{"hip","rk"},{"rk","rf"}}
        for i,e in ipairs(edges) do setLine(skeletonLines[i],pts[e[1]],pts[e[2]],1,Color3.new(1,1,1)) end
    else
        for _,l in ipairs(skeletonLines) do l.Visible=false end
    end

    if tracerOn then
        local sz=canvas.AbsoluteSize local start
        if state.TracerOrigin=="Top" then start=Vector2.new(sz.X/2,0)
        elseif state.TracerOrigin=="Center" then start=Vector2.new(sz.X/2,sz.Y/2)
        elseif state.TracerOrigin=="Mouse" then
            local m=UserInputService:GetMouseLocation() local a=canvas.AbsolutePosition
            start=Vector2.new(math.clamp(m.X-a.X,0,sz.X),math.clamp(m.Y-a.Y,0,sz.Y))
        else start=Vector2.new(sz.X/2,sz.Y) end
        setLine(tracer,start,Vector2.new(sz.X/2,sz.Y*.54),1,Color3.new(1,1,1))
    else tracer.Visible=false end
end)

-- --------------------------------------------------------------------------
-- Roblox Studio only: actual visibility test on non-player Humanoid dummies.
-- --------------------------------------------------------------------------
local studioHighlights=setmetatable({}, {__mode="k"})
local function clearStudio()
    for model,h in pairs(studioHighlights) do if h and h.Parent then h:Destroy() end studioHighlights[model]=nil end
end
local function dummyVisible(model,target)
    local cam=Workspace.CurrentCamera if not cam or not target then return false end
    local origin=cam.CFrame.Position local direction=target.Position-origin
    local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={LocalPlayer.Character,model,cam} rp.IgnoreWater=true
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
            local hum=model:FindFirstChildOfClass("Humanoid") local root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
            if hum and root and hum.Health>0 then
                seen[model]=true local h=studioHighlights[model]
                if not h or not h.Parent then
                    h=Instance.new("Highlight") h.Name="YokaiStudioESPWallCheck" h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency=.72 h.OutlineTransparency=0 h.Adornee=model h.Parent=model studioHighlights[model]=h
                end
                local c=state.DefaultColor
                if state.WallCheck then c=dummyVisible(model,root) and state.VisibleColor or state.OccludedColor end
                h.FillColor=c h.OutlineColor=c h.Enabled=true
            end
        end
    end
    for model,h in pairs(studioHighlights) do if not seen[model] then if h and h.Parent then h:Destroy() end studioHighlights[model]=nil end end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Visuals UX + menu fog restore loaded",3) end)
