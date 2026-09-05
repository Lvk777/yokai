-- Shot-driven local BulletTracer.
-- No mouse/hold polling: a tracer is emitted only after a local weapon signal
-- such as ammo decrease, local gunshot sound, muzzle emission, or native tracer activation.

repeat task.wait() until shared.YokaiFullyLoaded and shared.GuiLibrary

local GuiLibrary = shared.GuiLibrary
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local objects = GuiLibrary["ObjectsThatCanBeSaved"] or {}
local ZWSP = utf8.char(0x200B)

local WorldRec = objects["WorldWindow"]
local World = WorldRec and WorldRec["Api"]
if not World then
    warn("ShotDrivenTracerFix: World window missing")
    return
end

local function clean(v) return tostring(v):gsub(ZWSP, "") end
local function optionName(key) return clean(key):gsub("OptionsButton$", "") end
local function removeOption(name)
    local keys = {}
    for key, rec in pairs(objects) do
        if rec and rec["Type"] == "OptionsButton" and optionName(key) == name then
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

removeOption("BulletTracer")

local enabled = false
local color = Color3.fromRGB(255,255,255)
local materialName = "Neon"
local lifetime = 0.35
local thickness = 0.045
local range = 1800
local maxActive = 12
local active = {}
local lastShot = 0
local watched = setmetatable({}, {__mode="k"})
local ammoLast = setmetatable({}, {__mode="k"})
local suppressing = setmetatable({}, {__mode="k"})

local materials = {
    Neon=Enum.Material.Neon,
    ForceField=Enum.Material.ForceField,
    Glass=Enum.Material.Glass,
    Metal=Enum.Material.Metal,
    SmoothPlastic=Enum.Material.SmoothPlastic,
}

local muzzleWords = {"muzzle","muzzlepoint","muzzleflash","firepoint","fire_point","barrelend","barrel_end","tip","shootpoint","shotorigin","projectileorigin"}
local tracerWords = {"tracer","bullet","projectile","beam","streak","laser"}
local shotWords = {"shot","shoot","fire","gunshot","muzzle","rifle","pistol","smg","ak","m4","revolver","sniper","shotgun"}
local ammoWords = {"ammo","clip","magazine","mag","bullets","rounds"}
local armWords = {"arm","hand","forearm","wrist","glove","sleeve"}

local function hasWord(name, words)
    local n = tostring(name):lower()
    for _, w in ipairs(words) do if n:find(w,1,true) then return true end end
    return false
end

local function camera() return Workspace.CurrentCamera end

local function roots()
    local out, seen = {}, {}
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then table.insert(out, tool) seen[tool]=true end
    local cam = camera()
    if cam then
        for _, child in ipairs(cam:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder") or child:IsA("Tool")) and not seen[child] then
                local parts = 0
                for _, d in ipairs(child:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
                if parts >= 2 then table.insert(out, child) seen[child]=true end
            end
        end
    end
    return out
end

local function explicitMuzzle(root)
    if not root then return nil end
    local cam = camera()
    local best, score
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("Attachment") or obj:IsA("BasePart") then
            if hasWord(obj.Name, muzzleWords) then
                local p = obj:IsA("Attachment") and obj.WorldPosition or obj.Position
                local s = cam and (p-cam.CFrame.Position):Dot(cam.CFrame.LookVector) or 0
                if score == nil or s > score then best,score=p,s end
            end
        end
    end
    return best
end

local function estimatedMuzzle(root)
    local cam = camera()
    if not cam or not root then return nil end
    local best, score
    for _, part in ipairs(root:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < .96 and part.LocalTransparencyModifier < .96 and not hasWord(part.Name,armWords) then
            local screen, vis = cam:WorldToViewportPoint(part.Position)
            if vis and screen.Z > 0 then
                local half = part.Size/2
                for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                    local p=(part.CFrame*CFrame.new(half*Vector3.new(x,y,z))).Position
                    local s=(p-cam.CFrame.Position):Dot(cam.CFrame.LookVector)
                    if score==nil or s>score then best,score=p,s end
                end end end
            end
        end
    end
    return best
end

local function muzzle()
    local r = roots()
    for _, root in ipairs(r) do
        local p=explicitMuzzle(root)
        if p then return p end
    end
    local best,score
    local cam=camera()
    for _, root in ipairs(r) do
        local p=estimatedMuzzle(root)
        if p and cam then
            local s=(p-cam.CFrame.Position):Dot(cam.CFrame.LookVector)
            if score==nil or s>score then best,score=p,s end
        end
    end
    return best
end

local function destination(origin)
    local cam=camera()
    if not cam then return nil end
    local vp=cam.ViewportSize
    local ray=cam:ViewportPointToRay(vp.X/2,vp.Y/2)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={LocalPlayer.Character,cam}
    params.IgnoreWater=false
    local result=Workspace:Raycast(origin,ray.Direction.Unit*range,params)
    return result and result.Position or origin+ray.Direction.Unit*range
end

local function trim()
    for i=#active,1,-1 do if not active[i] or not active[i].Parent then table.remove(active,i) end end
    while #active>=maxActive do
        local p=table.remove(active,1)
        if p and p.Parent then p:Destroy() end
    end
end

local function draw(origin, finish)
    if not origin or not finish then return end
    local delta=finish-origin
    if delta.Magnitude < .05 then return end
    trim()
    local p=Instance.new("Part")
    p.Name="YokaiShotDrivenTracer"
    p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false
    p.Material=materials[materialName] or Enum.Material.Neon
    p.Color=color p.Transparency=.02
    p.Size=Vector3.new(thickness,thickness,delta.Magnitude)
    p.CFrame=CFrame.lookAt((origin+finish)/2,finish)
    p.Parent=Workspace
    table.insert(active,p)
    task.delay(lifetime,function() if p and p.Parent then p:Destroy() end end)
end

local function actualShot()
    if not enabled then return end
    local now=os.clock()
    if now-lastShot < .045 then return end
    local origin=muzzle()
    if not origin then return end
    lastShot=now
    draw(origin,destination(origin))
end

local function nearMuzzle(pos,radius)
    local m=muzzle()
    return m and (pos-m).Magnitude <= radius
end

local function localNativeTracer(obj)
    if not (obj:IsA("Beam") or obj:IsA("Trail")) then return false end
    if obj.Name=="YokaiShotDrivenTracer" then return false end
    local a0,a1=obj.Attachment0,obj.Attachment1
    if a0 and nearMuzzle(a0.WorldPosition,18) then return true end
    if a1 and nearMuzzle(a1.WorldPosition,18) then return true end
    return hasWord(obj.Name,tracerWords) and ((a0 and nearMuzzle(a0.WorldPosition,28)) or (a1 and nearMuzzle(a1.WorldPosition,28)))
end

local function suppressNative(obj)
    if not enabled or suppressing[obj] then return end
    suppressing[obj]=true
    pcall(function() obj.Enabled=false end)
    task.defer(function() suppressing[obj]=nil end)
end

local function hook(obj)
    if watched[obj] then return end

    if obj:IsA("Beam") or obj:IsA("Trail") then
        watched[obj]=obj:GetPropertyChangedSignal("Enabled"):Connect(function()
            if enabled and obj.Enabled and localNativeTracer(obj) then
                actualShot()
                suppressNative(obj)
            end
        end)
        if enabled and obj.Enabled and localNativeTracer(obj) then
            task.defer(actualShot)
            suppressNative(obj)
        end
        return
    end

    if obj:IsA("ParticleEmitter") and hasWord(obj.Name,{"muzzle","flash","fire","shot"}) then
        local ok, signal = pcall(function() return obj.OnEmitRequested end)
        if ok and typeof(signal)=="RBXScriptSignal" then
            watched[obj]=signal:Connect(function() actualShot() end)
        else
            watched[obj]=obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                if enabled and obj.Enabled then actualShot() end
            end)
        end
        return
    end

    if obj:IsA("Sound") and hasWord(obj.Name,shotWords) then
        watched[obj]=obj.Played:Connect(function() actualShot() end)
        return
    end

    if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and hasWord(obj.Name,ammoWords) then
        ammoLast[obj]=tonumber(obj.Value)
        watched[obj]=obj.Changed:Connect(function(v)
            local n=tonumber(v)
            local old=ammoLast[obj]
            ammoLast[obj]=n
            if enabled and n and old and n < old then actualShot() end
        end)
    end
end

local function watchRoot(root)
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do hook(d) end
    if not watched[root] then
        watched[root]=root.DescendantAdded:Connect(function(d)
            hook(d)
            if enabled and (d:IsA("Beam") or d:IsA("Trail")) then
                task.defer(function()
                    if d.Parent and localNativeTracer(d) then actualShot() suppressNative(d) end
                end)
            end
        end)
    end
end

local scanClock=0
RunService.Heartbeat:Connect(function(dt)
    scanClock += dt
    if scanClock < .35 then return end
    scanClock=0
    for _, root in ipairs(roots()) do watchRoot(root) end
end)
for _, root in ipairs(roots()) do watchRoot(root) end

local BulletTracer=World.CreateOptionsButton({["Name"]="BulletTracer",["Function"]=function(v)
    enabled=v
    if not v then
        for _,p in ipairs(active) do if p and p.Parent then p:Destroy() end end
        table.clear(active)
    else
        for _, root in ipairs(roots()) do watchRoot(root) end
    end
end})
BulletTracer.CreateDropdown({["Name"]="Material",["List"]={"Neon","ForceField","Glass","Metal","SmoothPlastic"},["Function"]=function(v) materialName=v end})
BulletTracer.CreateColorSlider({["Name"]="Color",["Function"]=function(h,s,v) color=Color3.fromHSV(h,s,v) end})
BulletTracer.CreateSlider({["Name"]="Lifetime",["Min"]=1,["Max"]=15,["Default"]=4,["Function"]=function(v) lifetime=v/10 end})
BulletTracer.CreateSlider({["Name"]="Thickness",["Min"]=2,["Max"]=15,["Default"]=5,["Function"]=function(v) thickness=v/100 end})
BulletTracer.CreateSlider({["Name"]="Range",["Min"]=100,["Max"]=3000,["Default"]=1800,["Function"]=function(v) range=v end})

pcall(function() GuiLibrary["CreateNotification"]("Yokai","Shot-driven BulletTracer loaded",3) end)
