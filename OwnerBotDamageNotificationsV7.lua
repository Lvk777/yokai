-- Rich bot hit notification: damage + body part.
-- Passive/local observer only; no remotes, no metamethod hooks.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local botRoot = Workspace:FindFirstChild("Zombies") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Bots")
if not botRoot then return end

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

local function isBot(model)
    if not model or not model:IsA("Model") or playerOwned(model) then return false end
    return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function classifyPart(inst,model)
    if not inst then return "Body" end
    local cur=inst
    while cur and cur~=model do
        local n=string.lower(cur.Name)
        if n=="head" or n:find("head",1,true) then return "Head" end
        if n:find("left",1,true) and (n:find("arm",1,true) or n:find("hand",1,true)) then return "Left Arm" end
        if n:find("right",1,true) and (n:find("arm",1,true) or n:find("hand",1,true)) then return "Right Arm" end
        if n:find("left",1,true) and (n:find("leg",1,true) or n:find("foot",1,true)) then return "Left Leg" end
        if n:find("right",1,true) and (n:find("leg",1,true) or n:find("foot",1,true)) then return "Right Leg" end
        if n:find("torso",1,true) or n:find("body",1,true) or n:find("chest",1,true) then return "Torso" end
        cur=cur.Parent
    end
    return "Body"
end

local lastShotAt=0
local lastShotModel=nil
local lastShotPart="Body"
local lastNoticeAt=setmetatable({}, {__mode="k"})
local lastNoticeDamage=setmetatable({}, {__mode="k"})

local function markShot()
    lastShotAt=os.clock()
    lastShotModel=nil
    lastShotPart="Body"

    local cam=Workspace.CurrentCamera
    if not cam then return end
    local center=cam.ViewportSize/2
    local ray=cam:ViewportPointToRay(center.X,center.Y)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,cam}
    rp.IgnoreWater=true

    local hit=Workspace:Raycast(ray.Origin,ray.Direction*5000,rp)
    if not (hit and hit.Instance) then return end

    local cur=hit.Instance
    while cur and cur~=Workspace do
        if cur:IsA("Model") and isBot(cur) then
            lastShotModel=cur
            lastShotPart=classifyPart(hit.Instance,cur)
            return
        end
        cur=cur.Parent
    end
end

UserInputService.InputBegan:Connect(function(input,gp)
    if not gp and input.UserInputType==Enum.UserInputType.MouseButton1 then
        markShot()
    end
end)

local function botLabel(model)
    local hum=model and model:FindFirstChildOfClass("Humanoid")
    local display=hum and tostring(hum.DisplayName or "") or ""
    if display~="" and display~=hum.Name then return display end
    local n=model and tostring(model.Name) or "Bot"
    if #n>32 or n:match("^%b{}$") or n:match("^[%x%-]+$") and #n>20 then return "Bot" end
    return n
end

local function notifyDamage(model,damage)
    if os.clock()-lastShotAt>.9 then return end
    if lastShotModel and lastShotModel~=model then return end

    local now=os.clock()
    local rounded=math.max(0,math.floor((damage or 0)+.5))
    if (lastNoticeAt[model] and now-lastNoticeAt[model]<.09) and lastNoticeDamage[model]==rounded then
        return
    end
    lastNoticeAt[model]=now
    lastNoticeDamage[model]=rounded

    local part=(lastShotModel==model and lastShotPart) or "Body"
    local text=string.format("%s  •  -%d HP  •  %s",part,rounded,botLabel(model))
    pcall(function()
        GuiLibrary.CreateNotification("Damage",text,2.1)
    end)
end

local bound=setmetatable({}, {__mode="k"})
local conns=setmetatable({}, {__mode="k"})
local function bindBot(model)
    if bound[model] or not isBot(model) then return end
    bound[model]=true
    conns[model]={}

    local hum=model:FindFirstChildOfClass("Humanoid")
    if hum then
        local prev=hum.Health
        table.insert(conns[model],hum.HealthChanged:Connect(function(v)
            if v<prev then notifyDamage(model,prev-v) end
            prev=v
        end))
    end

    local health=model:FindFirstChild("Health")
    if health and (health:IsA("NumberValue") or health:IsA("IntValue")) then
        local prev=health.Value
        table.insert(conns[model],health.Changed:Connect(function(v)
            local n=tonumber(v)
            if n and n<prev then notifyDamage(model,prev-n) end
            if n then prev=n end
        end))
    end
end

for _,d in ipairs(botRoot:GetDescendants()) do
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
        bindBot(d.Parent)
    end
end
botRoot.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
        task.defer(bindBot,d.Parent)
    end
end)
