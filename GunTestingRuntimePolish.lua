-- Gun Testing map polish. Local UI/cosmetics + bot-only helpers.
repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary=shared.GuiLibrary
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local CoreGui=game:GetService("CoreGui")
local LocalPlayer=Players.LocalPlayer
local objects=GuiLibrary["ObjectsThatCanBeSaved"] or {}
local UtilityRec=objects["UtilityWindow"]
local Utility=UtilityRec and UtilityRec.Api

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
local function removeOption(parentRec,name)
    local keys={}
    for key,rec in pairs(objects) do
        if rec and rec.Type=="OptionsButton" and optionName(key)==name and isUnder(rec,parentRec) then table.insert(keys,key) end
    end
    for _,key in ipairs(keys) do pcall(function() GuiLibrary["RemoveObject"](key) end) end
end

-- ---------------------------------------------------------------------------
-- Window state: stop the "two clicks" issue after delayed startup closers.
-- Synchronize sidebar button state with the actual window after all loaders finish.
-- ---------------------------------------------------------------------------
local function windowVisible(rec)
    if not rec then return false end
    local o=rec.Object
    if o and o:IsA("GuiObject") then return o.Visible end
    return false
end
local function syncNative(name)
    local win=objects[name.."Window"]
    local btn=objects[name.."Button"]
    local visible=windowVisible(win)
    local api=btn and btn.Api
    if api and api.Enabled~=nil and api.ToggleButton and api.Enabled~=visible then
        pcall(function() api.ToggleButton(visible) end)
    end
end
local function placeVisuals()
    local vr=objects["VisualsWindow"]
    local rr=objects["RenderWindow"]
    if not vr or not rr or not vr.Object or not rr.Object then return end
    if vr.Object:IsA("GuiObject") and rr.Object:IsA("GuiObject") then
        local p=rr.Object.Position
        local w=rr.Object.AbsoluteSize.X>0 and rr.Object.AbsoluteSize.X or 190
        vr.Object.Position=UDim2.new(p.X.Scale,p.X.Offset+w+10,p.Y.Scale,p.Y.Offset)
    end
end
task.defer(function()
    task.wait(1.15)
    for _,name in ipairs({"Combat","Movement","Render","Utility","World","Friends","Profiles"}) do syncNative(name) end
    placeVisuals()
end)

-- Keep Visuals at a stable spot relative to Render only when GUI is freshly loaded.
task.defer(function() task.wait(1.5) placeVisuals() end)

-- ---------------------------------------------------------------------------
-- Clean legacy synthetic/self overlays that can draw a GUID over LocalPlayer.
-- BotArenaAdapter remains intact.
-- ---------------------------------------------------------------------------
local staleNames={
    "YokaiAttachedVisualsFunctional","YokaiSafeESPFinalOverlay","YokaiSafeTargetAllInOneOverlay",
    "YokaiSafeCornerBoxV2","YokaiSafeCornerBoxV3","YokaiSafeCornerBoxV4",
    "YokaiSafeStandaloneHealthV3","YokaiSafeStandaloneHealthV4","YokaiSafeVisualTestOverlay"
}
local function guiRoots()
    local t={LocalPlayer:FindFirstChildOfClass("PlayerGui"),CoreGui}
    pcall(function() if gethui then table.insert(t,gethui()) end end)
    return t
end
for _,root in ipairs(guiRoots()) do
    if root then
        for _,name in ipairs(staleNames) do
            local old=root:FindFirstChild(name,true)
            if old then pcall(function() old:Destroy() end) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Inventory Viewer (local Backpack/Character only).
-- ---------------------------------------------------------------------------
if Utility then
    removeOption(UtilityRec,"Inventory Viewer")
    local invGui=Instance.new("ScreenGui")
    invGui.Name="YokaiInventoryViewer"
    invGui.ResetOnSpawn=false
    invGui.IgnoreGuiInset=true
    pcall(function() invGui.Parent=(gethui and gethui()) or CoreGui end)
    if not invGui.Parent then invGui.Parent=LocalPlayer:WaitForChild("PlayerGui") end
    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(230,38)
    frame.Position=UDim2.new(.5,-115,1,-145)
    frame.BackgroundColor3=Color3.fromRGB(18,18,18)
    frame.BackgroundTransparency=.12
    frame.BorderSizePixel=0
    frame.Visible=false
    frame.Parent=invGui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,6)
    local label=Instance.new("TextLabel")
    label.BackgroundTransparency=1
    label.Size=UDim2.new(1,-12,1,0)
    label.Position=UDim2.fromOffset(6,0)
    label.Font=Enum.Font.Gotham
    label.TextSize=12
    label.TextColor3=Color3.new(1,1,1)
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.Text="Inventory: empty"
    label.Parent=frame
    local enabled=false
    local function refreshInventory()
        if not enabled then return end
        local names={}
        local seen={}
        local function scan(root,equipped)
            if not root then return end
            for _,obj in ipairs(root:GetChildren()) do
                if obj:IsA("Tool") then
                    local txt=(equipped and "[E] " or "")..obj.Name
                    if not seen[txt] then seen[txt]=true table.insert(names,txt) end
                end
            end
        end
        scan(LocalPlayer.Character,true)
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"),false)
        label.Text=#names>0 and ("Inventory: "..table.concat(names,"  |  ")) or "Inventory: empty"
        local width=math.clamp(#label.Text*6.5+18,230,700)
        frame.Size=UDim2.fromOffset(width,38)
        frame.Position=UDim2.new(.5,-width/2,1,-145)
    end
    local InventoryViewer=Utility.CreateOptionsButton({
        ["Name"]="Inventory Viewer",
        ["Function"]=function(v) enabled=v frame.Visible=v if v then refreshInventory() end end,
        ["HoverText"]="Shows your equipped/local Backpack tools.",
    })
    task.spawn(function()
        while invGui.Parent do task.wait(.5) if enabled then refreshInventory() end end
    end)
end

-- ---------------------------------------------------------------------------
-- Bot-only hit-part notification.
-- Uses center-screen ray + Humanoid health decrease; never inspects Player health.
-- ---------------------------------------------------------------------------
local pending=nil
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
    return n
end
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    local ray=cam:ViewportPointToRay(vp.X/2,vp.Y/2)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true
    local hit=Workspace:Raycast(ray.Origin,ray.Direction*4000,rp)
    if not hit then pending=nil return end
    local model,hum=findBotFromPart(hit.Instance)
    if model and hum then
        pending={Model=model,Hum=hum,Part=normalizePartName(hit.Instance.Name),Health=hum.Health,Expires=os.clock()+.45}
    else
        pending=nil
    end
end)
RunService.Heartbeat:Connect(function()
    if not pending then return end
    if os.clock()>pending.Expires or not pending.Hum or not pending.Hum.Parent then pending=nil return end
    if pending.Hum.Health < pending.Health then
        local damage=math.max(1,math.floor(pending.Health-pending.Hum.Health+.5))
        pcall(function() GuiLibrary["CreateNotification"]("Hit",pending.Part.."  •  -"..damage.." HP",2) end)
        pending=nil
    end
end)

-- ---------------------------------------------------------------------------
-- Bot arrows: original ArrowIndicator asset when available, smaller and farther apart.
-- Only non-player Humanoids; Player characters are excluded.
-- ---------------------------------------------------------------------------
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
pcall(function() if getasset and isfile and isfile("yokai/assets/ArrowIndicator.png") then arrowImage=getasset("yokai/assets/ArrowIndicator.png") end end)
local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    if model.Name=="YokaiSafeVisualTestTarget" then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart
    return hum and root and hum.Health>0,root
end
local function ensureArrow(model)
    local a=arrowByModel[model]
    if a and a.Parent then return a end
    a=Instance.new("ImageLabel")
    a.Name="BotArrow"
    a.BackgroundTransparency=1
    a.AnchorPoint=Vector2.new(.5,.5)
    a.Size=UDim2.fromOffset(105,105)
    a.Image=arrowImage
    a.Visible=false
    a.Parent=arrowGui
    if arrowImage=="" then
        a.Image="rbxassetid://6031091002"
    end
    arrowByModel[model]=a
    return a
end
local scanTimer=0
RunService.RenderStepped:Connect(function(dt)
    scanTimer+=dt
    local cam=Workspace.CurrentCamera
    if not cam then return end
    if scanTimer>.8 then
        scanTimer=0
        local live={}
        for _,obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") then local ok=isBot(obj) if ok then live[obj]=true ensureArrow(obj) end end
        end
        for model,a in pairs(arrowByModel) do if not live[model] then if a then a:Destroy() end arrowByModel[model]=nil end end
    end
    local vp=cam.ViewportSize
    local center=vp/2
    local radius=math.min(vp.X,vp.Y)*.31
    for model,a in pairs(arrowByModel) do
        local ok,root=isBot(model)
        if not ok or not root then a.Visible=false continue end
        local p,on=cam:WorldToViewportPoint(root.Position)
        if on and p.Z>0 then a.Visible=false continue end
        local dir=(cam.CFrame:PointToObjectSpace(root.Position))
        local angle=math.atan2(dir.X,-dir.Z)
        local pos=center+Vector2.new(math.sin(angle),-math.cos(angle))*radius
        a.Position=UDim2.fromOffset(pos.X,pos.Y)
        a.Rotation=math.deg(angle)
        a.Size=UDim2.fromOffset(105,105)
        a.Visible=true
    end
end)

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Gun Testing runtime polish loaded",3) end)
