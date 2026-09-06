-- Final UI/performance pass.
-- Keeps existing feature modules intact; only replaces the passive bot Tracers/Distance UI
-- and adds reversible local performance controls.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary.ObjectsThatCanBeSaved or {}
local VisualsRec = objects.VisualsWindow
local UtilityRec = objects.UtilityWindow
local CombatRec = objects.CombatWindow
local MovementRec = objects.MovementWindow
local RenderRec = objects.RenderWindow
local WorldRec = objects.WorldWindow
local Visuals = VisualsRec and VisualsRec.Api
local Utility = UtilityRec and UtilityRec.Api
if not (Visuals and Utility) then return end

local ZWSP = utf8.char(0x200B)
local function clean(v) return tostring(v or ""):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function under(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" then
            local ok,res=pcall(function() return rec.Object==root or rec.Object:IsDescendantOf(root) end)
            if ok and res then return true end
        end
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

-- Restore whichever main windows were open before the bot patch stack ran.
local function restoreWindowState()
    local saved=shared.YokaiPreBotWindowState
    if type(saved)~="table" then return end
    local map={Combat=CombatRec,Movement=MovementRec,Render=RenderRec,Utility=UtilityRec,Visuals=VisualsRec,World=WorldRec}
    for name,state in pairs(saved) do
        local rec=map[name]
        if rec and rec.Api and type(rec.Api.SetVisible)=="function" then
            pcall(function() rec.Api.SetVisible(state==true) end)
        end
    end
end

task.defer(function()
    task.wait(.15)
    restoreWindowState()
end)
task.delay(1.0,restoreWindowState)

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
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    local hum=humanoidOf(model)
    return hum and hum.Health>0 and rootOf(model)~=nil
end
local botRoot=Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots")
local bots={}
local function registerBot(model) if isBot(model) then bots[model]=true end end
local function seedBots()
    table.clear(bots)
    if not botRoot then return end
    for _,d in ipairs(botRoot:GetDescendants()) do
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then registerBot(d.Parent) end
    end
end
seedBots()
if botRoot then
    botRoot.DescendantAdded:Connect(function(d)
        if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then task.defer(registerBot,d.Parent) end
    end)
    botRoot.DescendantRemoving:Connect(function(d)
        if d:IsA("Humanoid") and d.Parent then bots[d.Parent]=nil end
    end)
end

-- ============================================================================
-- FINAL VISUAL TRACERS
-- Explicit control order: Origin -> Color -> Thickness -> Transparency.
-- ============================================================================
removeOption(VisualsRec,"Tracers")
removeOption(VisualsRec,"Distance")
pcall(function() RunService:UnbindFromRenderStep("YokaiBotVisualTracersV4") end)
pcall(function() RunService:UnbindFromRenderStep("YokaiFinalTracersV9") end)

local parentGui=(gethui and gethui()) or CoreGui
local old=parentGui:FindFirstChild("YokaiFinalTracersV9")
if old then old:Destroy() end
local Overlay=Instance.new("ScreenGui")
Overlay.Name="YokaiFinalTracersV9"
Overlay.ResetOnSpawn=false
Overlay.IgnoreGuiInset=true
Overlay.DisplayOrder=999
Overlay.Parent=parentGui

local tracerEnabled=false
local originMode="Top"
local tracerColor=Color3.fromRGB(0,230,170)
local tracerThickness=1
local tracerTransparency=0
local globalDistance=tonumber(shared.YokaiBotGlobalDistance) or tonumber(shared.YokaiTargetVisualDistance) or 1800
local lines={}

local function makeLine(model)
    local f=Instance.new("Frame")
    f.Name="Tracer"
    f.AnchorPoint=Vector2.new(.5,.5)
    f.BorderSizePixel=0
    f.BackgroundColor3=tracerColor
    f.BackgroundTransparency=tracerTransparency
    f.Visible=false
    f.Parent=Overlay
    lines[model]=f
    return f
end
local function setLine(f,a,b)
    local delta=b-a
    local len=delta.Magnitude
    if len<1 then f.Visible=false return end
    f.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    f.Size=UDim2.fromOffset(len,tracerThickness)
    f.Rotation=math.deg(math.atan2(delta.Y,delta.X))
    f.BackgroundColor3=tracerColor
    f.BackgroundTransparency=tracerTransparency
    f.Visible=true
end
local function originPoint(cam)
    local vp=cam.ViewportSize
    if originMode=="Bottom" then return Vector2.new(vp.X/2,vp.Y-2) end
    if originMode=="Center" then return vp/2 end
    if originMode=="Cursor" then
        local m=UserInputService:GetMouseLocation()
        local inset=GuiService:GetGuiInset()
        return Vector2.new(math.clamp(m.X-inset.X,0,vp.X),math.clamp(m.Y-inset.Y,0,vp.Y))
    end
    return Vector2.new(vp.X/2,2)
end

local Tracers=Visuals.CreateOptionsButton({
    Name="Tracers",
    Function=function(v)
        tracerEnabled=v
        if not v then for _,f in pairs(lines) do f.Visible=false end end
    end,
})
local OriginControl=Tracers.CreateDropdown({Name="Origin",List={"Top","Bottom","Cursor","Center"},Function=function(v) originMode=v end})
local ColorControl=Tracers.CreateColorSlider({Name="Color",Function=function(h,s,v) tracerColor=Color3.fromHSV(h,s,v) end})
local ThicknessControl=Tracers.CreateSlider({Name="Thickness",Min=1,Max=4,Default=1,Function=function(v) tracerThickness=v end})
local TransparencyControl=Tracers.CreateSlider({Name="Transparency",Min=0,Max=95,Default=0,Function=function(v) tracerTransparency=v/100 end})

local function controlObject(api)
    if typeof(api)=="Instance" then return api end
    if type(api)=="table" and typeof(api.Object)=="Instance" then return api.Object end
    return nil
end
local function forceTracerOrder()
    local ordered={{OriginControl,1},{ColorControl,2},{ThicknessControl,3},{TransparencyControl,4}}
    for _,pair in ipairs(ordered) do
        local obj=controlObject(pair[1])
        if obj and obj:IsA("GuiObject") then pcall(function() obj.LayoutOrder=pair[2] end) end
    end
    -- Fallback for Yokai builds where subcontrol APIs do not expose Object.
    local _,rec=optionRecord(VisualsRec,"Tracers")
    local root=rec and (rec.ChildrenObject or rec.Object)
    if root and typeof(root)=="Instance" then
        local ranks={origin=1,color=2,thickness=3,transparency=4}
        local done={}
        for _,d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t=clean(d.Text):lower()
                local rank=t:find("origin",1,true) and ranks.origin or t=="color" and ranks.color or t:find("thickness",1,true) and ranks.thickness or t:find("transparency",1,true) and ranks.transparency or nil
                if rank then
                    local cur=d
                    while cur and cur.Parent and cur.Parent~=root do cur=cur.Parent end
                    if cur and cur.Parent==root and not done[cur] then
                        done[cur]=true
                        pcall(function() cur.LayoutOrder=rank end)
                    end
                end
            end
        end
    end
end
task.defer(forceTracerOrder)
task.delay(.25,forceTracerOrder)
task.delay(1,forceTracerOrder)

local Distance=Visuals.CreateOptionsButton({Name="Distance",Function=function() end,HoverText="Global draw distance for bot visuals."})
Distance.CreateSlider({Name="Max Distance",Min=50,Max=5000,Default=math.clamp(globalDistance,50,5000),Function=function(v)
    globalDistance=v
    shared.YokaiBotGlobalDistance=v
    shared.YokaiTargetVisualDistance=v
    if shared.YokaiBotVisualState then shared.YokaiBotVisualState.MaxDistance=v end
    if shared.YokaiVisualPreviewState then shared.YokaiVisualPreviewState.MaxDistance=v end
end})

task.defer(function()
    local _,tr=optionRecord(VisualsRec,"Tracers")
    local _,dr=optionRecord(VisualsRec,"Distance")
    if tr and dr and tr.Object and dr.Object then
        pcall(function() dr.Object.LayoutOrder=tr.Object.LayoutOrder+1; dr.Object.Visible=true end)
    end
end)

RunService:BindToRenderStep("YokaiFinalTracersV9",Enum.RenderPriority.Last.Value,function()
    if not tracerEnabled or not botRoot then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local start=originPoint(cam)
    for model in pairs(bots) do
        local f=lines[model] or makeLine(model)
        if not isBot(model) then
            f.Visible=false
            bots[model]=nil
        else
            local root=rootOf(model)
            local dist=root and (root.Position-cam.CFrame.Position).Magnitude or math.huge
            if root and dist<=globalDistance then
                local p,on=cam:WorldToViewportPoint(root.Position)
                if on and p.Z>0 then setLine(f,start,Vector2.new(p.X,p.Y)) else f.Visible=false end
            else
                f.Visible=false
            end
        end
    end
end)

-- ============================================================================
-- REVERSIBLE FPS BOOST
-- ============================================================================
removeOption(UtilityRec,"FPS Boost")
removeOption(UtilityRec,"Menu Optimizer")

local fpsEnabled=false
local fpsMode="Balanced"
local saved=setmetatable({}, {__mode="k"})
local savedGlobalShadows=nil
local boostToken=0

local function isYokaiObject(obj)
    local cur=obj
    for _=1,5 do
        if not cur then break end
        if clean(cur.Name):lower():find("yokai",1,true) then return true end
        cur=cur.Parent
    end
    return false
end
local function remember(obj,prop)
    local rec=saved[obj]
    if not rec then rec={} saved[obj]=rec end
    if rec[prop]==nil then
        local ok,v=pcall(function() return obj[prop] end)
        if ok then rec[prop]=v end
    end
end
local function setProp(obj,prop,value)
    remember(obj,prop)
    pcall(function() obj[prop]=value end)
end
local function optimizeObject(obj)
    if isYokaiObject(obj) then return end
    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        setProp(obj,"Enabled",false)
    elseif obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
        setProp(obj,"Enabled",false)
    elseif obj:IsA("BasePart") and fpsMode~="Light" then
        setProp(obj,"CastShadow",false)
    elseif (obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")) and fpsMode=="Aggressive" then
        setProp(obj,"Enabled",false)
    elseif (obj:IsA("Decal") or obj:IsA("Texture")) and fpsMode=="Aggressive" then
        setProp(obj,"Transparency",1)
    end
end
local function applyBoost()
    boostToken+=1
    local token=boostToken
    if savedGlobalShadows==nil then savedGlobalShadows=Lighting.GlobalShadows end
    if fpsMode~="Light" then Lighting.GlobalShadows=false end
    local list={}
    for _,d in ipairs(Workspace:GetDescendants()) do table.insert(list,d) end
    for _,d in ipairs(Lighting:GetChildren()) do table.insert(list,d) end
    task.spawn(function()
        for i,obj in ipairs(list) do
            if token~=boostToken or not fpsEnabled then return end
            optimizeObject(obj)
            if i%180==0 then task.wait() end
        end
    end)
end
local function restoreBoost()
    boostToken+=1
    local list={}
    for obj in pairs(saved) do table.insert(list,obj) end
    task.spawn(function()
        for i,obj in ipairs(list) do
            local rec=saved[obj]
            if rec and obj then
                for prop,value in pairs(rec) do pcall(function() obj[prop]=value end) end
            end
            saved[obj]=nil
            if i%180==0 then task.wait() end
        end
    end)
    if savedGlobalShadows~=nil then pcall(function() Lighting.GlobalShadows=savedGlobalShadows end); savedGlobalShadows=nil end
end

local FPS=Utility.CreateOptionsButton({Name="FPS Boost",Function=function(v)
    fpsEnabled=v
    if v then applyBoost() else restoreBoost() end
end,HoverText="Reversible local graphics reduction; no continuous workspace scan."})
FPS.CreateDropdown({Name="Mode",List={"Light","Balanced","Aggressive"},Function=function(v)
    fpsMode=v
    if fpsEnabled then restoreBoost(); fpsEnabled=true; task.delay(.1,applyBoost) end
end})

Workspace.DescendantAdded:Connect(function(obj)
    if fpsEnabled then task.defer(function() if obj and obj.Parent then optimizeObject(obj) end end) end
end)
Lighting.ChildAdded:Connect(function(obj)
    if fpsEnabled then task.defer(function() if obj and obj.Parent then optimizeObject(obj) end end) end
end)

-- ============================================================================
-- MENU OPTIMIZER
-- Removes only decorative shadow/blur rendering from the Yokai menu.
-- Controls and feature objects are never removed.
-- ============================================================================
local menuOptimized=false
local menuSaved=setmetatable({}, {__mode="k"})
local function menuCandidate(obj)
    if not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then return false end
    local n=clean(obj.Name):lower()
    return n:find("shadow",1,true) or n:find("blur",1,true)
end
local function applyMenuOptimizer()
    local main=GuiLibrary.MainGui
    if not main then return end
    for _,d in ipairs(main:GetDescendants()) do
        if menuCandidate(d) then
            if menuSaved[d]==nil then menuSaved[d]=d.ImageTransparency end
            pcall(function() d.ImageTransparency=1 end)
        end
    end
end
local function restoreMenuOptimizer()
    for obj,value in pairs(menuSaved) do
        if obj then pcall(function() obj.ImageTransparency=value end) end
        menuSaved[obj]=nil
    end
end
local MenuOptimizer=Utility.CreateOptionsButton({Name="Menu Optimizer",Function=function(v)
    menuOptimized=v
    if v then applyMenuOptimizer() else restoreMenuOptimizer() end
end,HoverText="Disables only decorative Yokai shadow/blur images to reduce GUI render cost."})

if GuiLibrary.MainGui then
    GuiLibrary.MainGui.DescendantAdded:Connect(function(obj)
        if menuOptimized and menuCandidate(obj) then
            task.defer(function()
                if obj and obj.Parent then
                    if menuSaved[obj]==nil then menuSaved[obj]=obj.ImageTransparency end
                    obj.ImageTransparency=1
                end
            end)
        end
    end)
end

-- Keep critical menu groups visible; do not remove or recreate combat features here.
task.defer(function()
    for _,name in ipairs({"Tracers","Distance"}) do
        local _,rec=optionRecord(VisualsRec,name)
        if rec and rec.Object then pcall(function() rec.Object.Visible=true end) end
    end
    for _,name in ipairs({"FPS Boost","Menu Optimizer"}) do
        local _,rec=optionRecord(UtilityRec,name)
        if rec and rec.Object then pcall(function() rec.Object.Visible=true end) end
    end
end)
