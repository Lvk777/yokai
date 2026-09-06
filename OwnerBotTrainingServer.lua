-- SERVER-SIDE developer training bridge for a Roblox experience you own.
-- Place this file in ServerScriptService in the live game.
-- It only authorizes the experience owner / high-rank owner-group admins and only damages NPCs.
-- It never targets Player characters and contains no anti-cheat bypass or ban evasion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("YokaiOwnerTraining")
if not folder then
    folder = Instance.new("Folder")
    folder.Name = "YokaiOwnerTraining"
    folder.Parent = ReplicatedStorage
end

local action = folder:FindFirstChild("Action") or Instance.new("RemoteEvent")
action.Name = "Action"
action.Parent = folder

local status = folder:FindFirstChild("Status") or Instance.new("RemoteFunction")
status.Name = "Status"
status.Parent = folder

local function isAuthorized(player)
    if not player then return false end
    if game.CreatorType == Enum.CreatorType.Group then
        local ok, rank = pcall(function()
            return player:GetRankInGroup(game.CreatorId)
        end)
        return ok and rank >= 250
    end
    return player.UserId == game.CreatorId
end

local function isPlayerCharacter(model)
    if not model or not model:IsA("Model") then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and (model == char or model:IsDescendantOf(char) or char:IsDescendantOf(model)) then
            return true
        end
    end
    return false
end

local function getHumanoid(model)
    if not model or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return nil end
    if isPlayerCharacter(model) then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return hum
end

local function playerRoot(player)
    local char = player.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function equippedTool(player)
    local char = player.Character
    return char and char:FindFirstChildOfClass("Tool") or nil
end

local function readNumber(container, names)
    if not container then return nil end
    for _, name in ipairs(names) do
        local attr = container:GetAttribute(name)
        if type(attr) == "number" then return attr end
        local obj = container:FindFirstChild(name, true)
        if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then return obj.Value end
    end
end

local function weaponDamage(player)
    local tool = equippedTool(player)
    local value = readNumber(tool, {"Damage", "BaseDamage", "BulletDamage", "WeaponDamage"})
    return math.clamp(tonumber(value) or 25, 1, 500)
end

local states = {}
local lastMagic = {}

local function stateFor(player)
    local s = states[player]
    if not s then
        s = {Magic=false, InfiniteAmmo=false, FastReload=false, NoRecoil=false, originals=setmetatable({}, {__mode="k"}), attrOriginals=setmetatable({}, {__mode="k"})}
        states[player] = s
    end
    return s
end

local ammoWords = {"ammo", "magazine", "bulletsinmagazine", "bullets", "clip", "reserveammo", "bulletsinreserve"}
local reloadWords = {"reloadtime", "reloadduration", "reloadspeed", "reload_delay", "reloaddelay"}
local recoilWords = {"recoil", "viewkick", "camerakick", "kickback", "verticalkick", "horizontalkick"}

local function lower(s) return string.lower(tostring(s)) end
local function containsAny(name, words)
    local n = lower(name)
    for _, w in ipairs(words) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

local function rememberValue(s, obj)
    if s.originals[obj] == nil then
        s.originals[obj] = obj.Value
    end
end

local function rememberAttr(s, obj, name)
    local map = s.attrOriginals[obj]
    if not map then map = {} s.attrOriginals[obj] = map end
    if map[name] == nil then map[name] = obj:GetAttribute(name) end
end

local function tuneContainer(player, s, root)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("IntValue") or obj:IsA("NumberValue") then
            if s.InfiniteAmmo and containsAny(obj.Name, ammoWords) then
                rememberValue(s, obj)
                obj.Value = math.max(obj.Value, 999)
            elseif s.FastReload and containsAny(obj.Name, reloadWords) then
                rememberValue(s, obj)
                obj.Value = math.min(obj.Value, 0.05)
            elseif s.NoRecoil and containsAny(obj.Name, recoilWords) then
                rememberValue(s, obj)
                obj.Value = 0
            end
        elseif obj:IsA("BoolValue") and s.FastReload and lower(obj.Name):find("reloading", 1, true) then
            rememberValue(s, obj)
            obj.Value = false
        end

        if obj:IsA("Instance") then
            for _, name in ipairs(obj:GetAttributes() and (function()
                local out = {}
                for k in pairs(obj:GetAttributes()) do table.insert(out, k) end
                return out
            end)() or {}) do
                local v = obj:GetAttribute(name)
                if type(v) == "number" then
                    if s.InfiniteAmmo and containsAny(name, ammoWords) then
                        rememberAttr(s, obj, name)
                        obj:SetAttribute(name, math.max(v, 999))
                    elseif s.FastReload and containsAny(name, reloadWords) then
                        rememberAttr(s, obj, name)
                        obj:SetAttribute(name, math.min(v, 0.05))
                    elseif s.NoRecoil and containsAny(name, recoilWords) then
                        rememberAttr(s, obj, name)
                        obj:SetAttribute(name, 0)
                    end
                elseif type(v) == "boolean" and s.FastReload and lower(name):find("reloading",1,true) then
                    rememberAttr(s, obj, name)
                    obj:SetAttribute(name, false)
                end
            end
        end
    end
end

local function restoreState(s)
    for obj, value in pairs(s.originals) do
        if obj and obj.Parent then pcall(function() obj.Value = value end) end
    end
    s.originals = setmetatable({}, {__mode="k"})
    for obj, attrs in pairs(s.attrOriginals) do
        if obj and obj.Parent then
            for name, value in pairs(attrs) do pcall(function() obj:SetAttribute(name, value) end) end
        end
    end
    s.attrOriginals = setmetatable({}, {__mode="k"})
end

status.OnServerInvoke = function(player)
    return {
        Authorized = isAuthorized(player),
        CreatorType = tostring(game.CreatorType),
        CreatorId = game.CreatorId,
    }
end

action.OnServerEvent:Connect(function(player, command, a, b)
    if not isAuthorized(player) then return end
    local s = stateFor(player)

    if command == "SetMagic" then
        s.Magic = a == true
    elseif command == "SetInfiniteAmmo" then
        if s.InfiniteAmmo and a ~= true then restoreState(s) end
        s.InfiniteAmmo = a == true
    elseif command == "SetFastReload" then
        if s.FastReload and a ~= true then restoreState(s) end
        s.FastReload = a == true
    elseif command == "SetNoRecoil" then
        if s.NoRecoil and a ~= true then restoreState(s) end
        s.NoRecoil = a == true
    elseif command == "MagicHit" then
        if not s.Magic then return end
        local now = os.clock()
        if now - (lastMagic[player] or 0) < 0.045 then return end
        lastMagic[player] = now

        local model = typeof(a) == "Instance" and a or nil
        local partName = tostring(b or "Torso")
        local hum = getHumanoid(model)
        local root = playerRoot(player)
        local targetRoot = model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso"))
        if not hum or not root or not targetRoot then return end
        if (root.Position - targetRoot.Position).Magnitude > 1800 then return end

        local dmg = weaponDamage(player)
        if partName == "Head" then dmg *= 1.5 end
        hum:TakeDamage(dmg)
    end
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.12 then return end
    acc = 0

    for player, s in pairs(states) do
        if player.Parent and isAuthorized(player) and (s.InfiniteAmmo or s.FastReload or s.NoRecoil) then
            tuneContainer(player, s, player.Character)
            tuneContainer(player, s, player:FindFirstChildOfClass("Backpack"))
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local s = states[player]
    if s then restoreState(s) end
    states[player] = nil
    lastMagic[player] = nil
end)
