-- Gun Testing map polish. Local UI/cosmetics + bot-only helpers.
-- Uses the game's LOCAL GunInventory and GunPlugin hitmarker signal when available.
-- No remotes, anti-cheat bypass, ban evasion, or Player targeting.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local HttpService=game:GetService("HttpService")

local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec=objects["UtilityWindow"]
local RenderRec=objects["RenderWindow"]
local VisualsRec=objects["VisualsWindow"]
local Utility=UtilityRec and UtilityRec.Api
local Visuals=VisualsRec and VisualsRec.Api

local ZWSP=utf8.char(0x200B)
local function clean(v) return tostring(v):gsub(ZWSP,"") end
local function optionName(key) return clean(key):gsub("OptionsButton$","") end
local function isUnder(rec,parentRec)
    if not rec or not rec.Object or not parentRec then return false end
    for _,root in ipairs({parentRec.Object,parentRec.ChildrenObject}) do
        if root and typeof(root)=="Instance" and (rec.Object==root or rec.Object:IsDescendantOf(root)) then return true end
    end
    return false
end
local function findOption(parentRec,name)
    local found
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then found=rec end
    end
    return found
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

local function guiRoots()
    local t={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(t,gethui()) end end)
    return t
end
local function destroyGuiNamed(name)
    for _,root in ipairs(guiRoots()) do
        if root then
            local old=root:FindFirstChild(name,true)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end

-- ============================================================================
-- Window state + Visuals position.
-- Capture the state loaded by Yokai BEFORE older delayed closers run, then restore it.
-- This removes the "window looks open internally but needs two clicks" mismatch.
-- ============================================================================
local windowNames={"Combat","Movement","Render","Utility","World","Friends","Profiles"}
local startup={}
for _,name in ipairs(windowNames) do
    local rec=objects[name.."Window"]
    local obj=rec and rec.Object
    startup[name]={
        Visible=(obj and obj:IsA("GuiObject")) and obj.Visible or false,
        Position=(obj and obj:IsA("GuiObject")) and obj.Position or nil,
    }
end
local vObj=VisualsRec and VisualsRec.Object
local startupVisualVisible=(vObj and vObj:IsA("GuiObject")) and vObj.Visible or false
local startupVisualPosition=(vObj and vObj:IsA("GuiObject")) and vObj.Position or nil

local positionFile="yokai/guntesting_visuals_position.json"
local function readVisualPosition()
    if not (isfile and readfile) then return nil end
    local ok,raw=pcall(function() return isfile(positionFile) and readfile(positionFile) or nil end)
    if not ok or not raw or raw=="" then return nil end
    local ok2,data=pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data)~="table" then return nil end
    if type(data.xs)~="number" or type(data.xo)~="number" or type(data.ys)~="number" or type(data.yo)~="number" then return nil end
    return UDim2.new(data.xs,data.xo,data.ys,data.yo)
end
local function saveVisualPosition(pos)
    if not writefile or typeof(pos)~="UDim2" then return end
    local payload={xs=pos.X.Scale,xo=pos.X.Offset,ys=pos.Y.Scale,yo=pos.Y.Offset}
    pcall(function() writefile(positionFile,HttpService:JSONEncode(payload)) end)
end
local savedVisualPosition=readVisualPosition() or startupVisualPosition

-- Replace the custom Visuals sidebar button with a final controller whose state follows
-- the ACTUAL Visuals window visibility.
local visualButton
local visualClick
local visualWanted=startupVisualVisible
local function accentColor()
    local rec=objects["Gui ColorSliderColor"]
    local api=rec and rec.Api
    if api and api.Hue~=nil then return Color3.fromHSV(api.Hue,api.Sat or 1,api.Value or 1) end
    return Color3.fromRGB(45,132,235)
end
local function paintVisualButton(selected)
    if not visualButton then return end
    local accent=accentColor()
    local off=Color3.fromRGB(162,162,162)
    local function paint(node)
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            if node.Text=="Visuals" then node.TextColor3=selected and accent or off end
        elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
            local n=node.Name:lower()
            if n:find("icon",1,true) or n:find("image",1,true) then node.ImageColor3=selected and accent or off end
        end
    end
    paint(visualButton)
    for _,d in ipairs(visualButton:GetDescendants()) do paint(d) end
end
local function installVisualButton()
    local main=GuiLibrary.MainGui
    local source=objects["RenderButton"] and objects["RenderButton"].Object
    if not main or not source or typeof(source)~="Instance" then return end
    for _,name in ipairs({"VisualsV4Button","VisualsHarmonyButton","VisualsIndependentButton","VisualsGunTestingButton"}) do
        local old=main:FindFirstChild(name,true)
        if old then pcall(function() old:Destroy() end) end
    end
    visualButton=source:Clone()
    visualButton.Name="VisualsGunTestingButton"
    visualButton.LayoutOrder=(source.LayoutOrder or 0)+1
    local function rename(node)
        if (node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text=="Render" then node.Text="Visuals" end
    end
    rename(visualButton)
    for _,d in ipairs(visualButton:GetDescendants()) do rename(d) end
    visualButton.Parent=source.Parent
    visualClick=visualButton:IsA("GuiButton") and visualButton or visualButton:FindFirstChildWhichIsA("GuiButton",true)
    if visualClick then
        visualClick.MouseButton1Click:Connect(function()
            visualWanted=not visualWanted
            if Visuals and Visuals.SetVisible then pcall(function() Visuals.SetVisible(visualWanted) end) end
            paintVisualButton(visualWanted)
        end)
    end
    paintVisualButton(visualWanted)
end
installVisualButton()

if vObj and vObj:IsA("GuiObject") then
    vObj:GetPropertyChangedSignal("Visible"):Connect(function()
        visualWanted=vObj.Visible
        paintVisualButton(visualWanted)
    end)
    local saveClock=0
    vObj:GetPropertyChangedSignal("Position"):Connect(function()
        saveClock+=1
        local id=saveClock
        task.delay(.35,function()
            if id==saveClock and vObj and vObj.Parent then saveVisualPosition(vObj.Position) end
        end)
    end)
end

task.defer(function()
    -- Let all older one-shot startup patches finish, then put the saved state back.
    task.wait(2.1)
    for _,name in ipairs(windowNames) do
        local rec=objects[name.."Window"]
        local obj=rec and rec.Object
        local api=rec and rec.Api
        local state=startup[name]
        if state then
            if obj and obj:IsA("GuiObject") and state.Position then obj.Position=state.Position end
            if api and api.SetVisible then pcall(function() api.SetVisible(state.Visible) end)
            elseif obj and obj:IsA("GuiObject") then obj.Visible=state.Visible end
        end
    end
    if vObj and vObj:IsA("GuiObject") and savedVisualPosition then vObj.Position=savedVisualPosition end
    visualWanted=startupVisualVisible
    if Visuals and Visuals.SetVisible then pcall(function() Visuals.SetVisible(visualWanted) end) end
    paintVisualButton(visualWanted)
end)

-- ============================================================================
-- Remove synthetic/legacy target layers from this map so LocalPlayer cannot inherit
-- the old GUID/ESP overlay. BotArenaAdapter remains the only target renderer.
-- ============================================================================
for _,bind in ipairs({
    "YokaiSafeVisualPolishV4","YokaiGlobalVisualDistanceV4","YokaiSafeTargetESPFinal",
    "YokaiSafeTargetAllInOne","YokaiSafeVisualTestTarget","YokaiArrowRingPolishV4"
}) do pcall(function() RunService:UnbindFromRenderStep(bind) end) end

local staleNames={
    "YokaiAttachedVisualsFunctional","YokaiSafeESPFinalOverlay","YokaiSafeTargetAllInOneOverlay",
    "YokaiSafeCornerBoxV2","YokaiSafeCornerBoxV3","YokaiSafeCornerBoxV4",
    "YokaiSafeStandaloneHealthV3","YokaiSafeStandaloneHealthV4","YokaiSafeVisualTestOverlay",
    "YokaiSafeESPVisualUXV3","YokaiSafeThermalCornerV3"
}
for _,name in ipairs(staleNames) do destroyGuiNamed(name) end
local synthetic=Workspace:FindFirstChild("YokaiSafeVisualTestTarget")
if synthetic then pcall(function() synthetic:Destroy() end) end
for _,obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Highlight") and obj.Name:find("YokaiSafe",1,true) then
        pcall(function() obj:Destroy() end)
    end
end

-- ============================================================================
-- Gun Testing Inventory Viewer: reads Players.LocalPlayer.GunInventory directly.
-- Screenshot-confirmed structure: each slot stores Active, BulletsInMagazine,
-- BulletsInReserve, Firemode, attachments, and an ObjectValue whose Value names gun.
-- ============================================================================
if Utility then
    removeOption(UtilityRec,"Inventory Viewer")
    destroyGuiNamed("YokaiGunTestingInventoryViewer")

    local invGui=Instance.new("ScreenGui")
    invGui.Name="YokaiGunTestingInventoryViewer"
    invGui.ResetOnSpawn=false
    invGui.IgnoreGuiInset=true
    invGui.DisplayOrder=1019
    pcall(function() invGui.Parent=(gethui and gethui()) or CoreGui end)
    if not invGui.Parent then invGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(360,44)
    frame.Position=UDim2.new(.5,-180,1,-148)
    frame.BackgroundColor3=Color3.fromRGB(18,18,18)
    frame.BackgroundTransparency=.12
    frame.BorderSizePixel=0
    frame.Visible=false
    frame.Parent=invGui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,6)

    local label=Instance.new("TextLabel")
    label.BackgroundTransparency=1
    label.Size=UDim2.new(1,-14,1,0)
    label.Position=UDim2.fromOffset(7,0)
    label.Font=Enum.Font.Gotham
    label.TextSize=12
    label.TextColor3=Color3.new(1,1,1)
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.Text="Inventory: loading..."
    label.Parent=frame

    local enabled=false
    local function valueOf(container,name)
        local obj=container and container:FindFirstChild(name)
        if not obj then return nil end
        local ok,v=pcall(function() return obj.Value end)
        return ok and v or nil
    end
    local function weaponName(slot)
        local ok,v=pcall(function() return slot.Value end)
        if ok and v~=nil then
            if typeof(v)=="Instance" then return v.Name end
            local s=tostring(v)
            if s~="" and s~="nil" then return s end
        end
        for _,key in ipairs({"WeaponName","GunName","DisplayName","Name"}) do
            local x=valueOf(slot,key)
            if x~=nil and tostring(x)~="" then return tostring(x) end
        end
        return "Weapon"
    end
    local function refreshInventory()
        if not enabled then return end
        local gunInventory=LocalPlayer:FindFirstChild("GunInventory")
        local entries={}
        if gunInventory then
            for _,slot in ipairs(gunInventory:GetChildren()) do
                local name=weaponName(slot)
                local active=valueOf(slot,"Active")
                local mag=valueOf(slot,"BulletsInMagazine")
                local reserve=valueOf(slot,"BulletsInReserve")
                local firemode=valueOf(slot,"Firemode")
                local text=(active==true and "[E] " or "")..name
                if mag~=nil then text..=" "..tostring(mag) end
                if reserve~=nil then text..="/"..tostring(reserve) end
                if firemode~=nil and tostring(firemode)~="" then text..=" ("..tostring(firemode)..")" end
                table.insert(entries,text)
            end
        end
        if #entries==0 then
            local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
            for _,root in ipairs({LocalPlayer.Character,backpack}) do
                if root then for _,obj in ipairs(root:GetChildren()) do if obj:IsA("Tool") then table.insert(entries,obj.Name) end end end
            end
        end
        label.Text=#entries>0 and ("Inventory: "..table.concat(entries,"  |  ")) or "Inventory: empty"
        local width=math.clamp(#label.Text*6.2+22,300,980)
        frame.Size=UDim2.fromOffset(width,44)
        frame.Position=UDim2.new(.5,-width/2,1,-148)
    end

    Utility.CreateOptionsButton({
        ["Name"]="Inventory Viewer",
        ["Function"]=function(v) enabled=v frame.Visible=v if v then refreshInventory() end end,
        ["HoverText"]="Gun Testing: reads your local GunInventory slots/ammo/firemode.",
    })
    task.spawn(function()
        while invGui.Parent do task.wait(.25) if enabled then refreshInventory() end end
    end)
end

-- ============================================================================
-- Bot helpers shared by hitmarker and arrows. Player characters are always excluded.
-- ============================================================================
local function playerOwned(model)
    if not model then return true end
    for _,plr in ipairs(Players:GetPlayers()) do
        local char=plr.Character
        if char and (model==char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then return true end
    end
    return false
end
local function findBotFromPart(part)
    local cur=part
    while cur and cur~=Workspace do
        if cur:IsA("Model") then
            local hum=cur:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 and not playerOwned(cur) and cur.Name~="YokaiSafeVisualTestTarget" then return cur,hum end
        end
        cur=cur.Parent
    end
end
local function normalizePartName(name)
    local n=tostring(name)
    local l=n:lower()
    if l:find("head",1,true) then return "Head" end
    if l:find("torso",1,true) or l:find("chest",1,true) or l:find("body",1,true) then return "Torso" end
    if l:find("left",1,true) and (l:find("arm",1,true) or l:find("hand",1,true)) then return "Left Arm" end
    if l:find("right",1,true) and (l:find("arm",1,true) or l:find("hand",1,true)) then return "Right Arm" end
    if l:find("left",1,true) and (l:find("leg",1,true) or l:find("foot",1,true)) then return "Left Leg" end
    if l:find("right",1,true) and (l:find("leg",1,true) or l:find("foot",1,true)) then return "Right Leg" end
    return "Body"
end

local lastShot={Part="Body",At=0,Model=nil,Health=nil}
local function sampleCrosshairTarget()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    local ray=cam:ViewportPointToRay(vp.X/2,vp.Y/2)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(ray.Origin,ray.Direction*5000,rp)
    if not hit then lastShot={Part="Body",At=os.clock(),Model=nil,Health=nil} return end
    local model,hum=findBotFromPart(hit.Instance)
    lastShot={Part=normalizePartName(hit.Instance.Name),At=os.clock(),Model=model,Health=hum and hum.Health or nil}
end
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    sampleCrosshairTarget()
end)

-- Connect to the game's own LOCAL hitmarker signal shown in HitmarkerGuiController:
-- PlayerScripts.GunController.Events.GunPlugin -> require -> :OnHitmarker():Connect(...)
local hitmarkerConnected=false
local function connectGameHitmarker()
    if hitmarkerConnected then return true end
    local playerScripts=LocalPlayer:FindFirstChild("PlayerScripts")
    local gunController=playerScripts and playerScripts:FindFirstChild("GunController")
    local events=gunController and gunController:FindFirstChild("Events")
    local gunPluginModule=events and events:FindFirstChild("GunPlugin")
    if not gunPluginModule or not gunPluginModule:IsA("ModuleScript") then return false end
    local ok,plugin=pcall(require,gunPluginModule)
    if not ok or type(plugin)~="table" or type(plugin.OnHitmarker)~="function" then return false end
    local ok2,signal=pcall(function() return plugin:OnHitmarker() end)
    if not ok2 or not signal or type(signal.Connect)~="function" then return false end
    signal:Connect(function(headshot)
        local part
        if headshot==true then
            part="Head"
        elseif os.clock()-lastShot.At<=.40 then
            part=lastShot.Part or "Body"
            if part=="Head" then part="Body" end
        else
            part="Body"
        end
        pcall(function() GuiLibrary["CreateNotification"]("Hit",part,2) end)
    end)
    hitmarkerConnected=true
    return true
end

task.spawn(function()
    for _=1,40 do
        if connectGameHitmarker() then break end
        task.wait(.25)
    end
end)

-- Fallback only if GunPlugin cannot be connected: confirm a hit by bot health drop.
RunService.Heartbeat:Connect(function()
    if hitmarkerConnected then return end
    if os.clock()-lastShot.At>.45 or not lastShot.Model or lastShot.Health==nil then return end
    local hum=lastShot.Model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health<lastShot.Health then
        pcall(function() GuiLibrary["CreateNotification"]("Hit",lastShot.Part or "Body",2) end)
        lastShot.At=0
    end
end)

-- ============================================================================
-- Bot arrows. Tied to Render > Arrows toggle; only off-screen non-player Humanoids.
-- ============================================================================
destroyGuiNamed("YokaiBotArrows")
local arrowGui=Instance.new("ScreenGui")
arrowGui.Name="YokaiBotArrows"
arrowGui.ResetOnSpawn=false
arrowGui.IgnoreGuiInset=true
arrowGui.DisplayOrder=1018
pcall(function() arrowGui.Parent=(gethui and gethui()) or CoreGui end)
if not arrowGui.Parent then arrowGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end

local arrowByModel={}
local getasset=getsynasset or getcustomasset
local arrowImage=""
pcall(function()
    if getasset and isfile and isfile("yokai/assets/ArrowIndicator.png") then arrowImage=getasset("yokai/assets/ArrowIndicator.png") end
end)
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    if model.Name=="YokaiSafeVisualTestTarget" then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart
    return hum and root and hum.Health>0,root
end
local function arrowsEnabled()
    local rec=findOption(RenderRec,"Arrows")
    return rec and rec.Api and rec.Api.Enabled==true
end
local function ensureArrow(model)
    local a=arrowByModel[model]
    if a and a.Parent then return a end
    a=Instance.new("ImageLabel")
    a.Name="BotArrow"
    a.BackgroundTransparency=1
    a.AnchorPoint=Vector2.new(.5,.5)
    a.Size=UDim2.fromOffset(105,105)
    a.Image=arrowImage~="" and arrowImage or "rbxassetid://6031091002"
    a.Visible=false
    a.Parent=arrowGui
    arrowByModel[model]=a
    return a
end
local scanTimer=0
RunService.RenderStepped:Connect(function(dt)
    scanTimer+=dt
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local enabled=arrowsEnabled()
    if scanTimer>.65 then
        scanTimer=0
        local live={}
        if enabled then
            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") then local ok=isBot(obj) if ok then live[obj]=true ensureArrow(obj) end end
            end
        end
        for model,a in pairs(arrowByModel) do
            if not live[model] then if a then a:Destroy() end arrowByModel[model]=nil end
        end
    end
    if not enabled then
        for _,a in pairs(arrowByModel) do a.Visible=false end
        return
    end
    local vp=cam.ViewportSize
    local center=vp/2
    local radius=math.min(vp.X,vp.Y)*.31
    for model,a in pairs(arrowByModel) do
        local ok,root=isBot(model)
        if not ok or not root then a.Visible=false continue end
        local p,on=cam:WorldToViewportPoint(root.Position)
        if on and p.Z>0 then a.Visible=false continue end
        local dir=cam.CFrame:PointToObjectSpace(root.Position)
        local angle=math.atan2(dir.X,-dir.Z)
        local pos=center+Vector2.new(math.sin(angle),-math.cos(angle))*radius
        a.Position=UDim2.fromOffset(pos.X,pos.Y)
        a.Rotation=math.deg(angle)
        a.Size=UDim2.fromOffset(105,105)
        a.Visible=true
    end
end)

pcall(function()
    GuiLibrary["CreateNotification"]("Yokai","Gun Testing adapter: GunInventory + game hitmarker connected",3)
end)
