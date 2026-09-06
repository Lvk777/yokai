-- GunTestingLiteESPDiagnosticsV7.lua
-- Safe diagnostics for ESP rendering and bot-folder detection.
-- Tests only the LocalPlayer character plus non-player bot-shaped rigs in Workspace.Players.
-- Does not target other real Roblox players.

if shared.GunTestingLiteESPDiagnosticsV7 then return end
shared.GunTestingLiteESPDiagnosticsV7=true

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local Workspace=game:GetService("Workspace")

local LP=Players.LocalPlayer
local parent=(gethui and gethui()) or CoreGui
local Gui=parent:FindFirstChild("GunTestingLiteV1",true)
if not Gui then
    for _=1,100 do task.wait(.05); Gui=parent:FindFirstChild("GunTestingLiteV1",true); if Gui then break end end
end
if not Gui then return end

local function findPage(name)
    for _,d in ipairs(Gui:GetDescendants()) do
        if d:IsA("ScrollingFrame") and d.Name==name then return d end
    end
end
local Visuals=findPage("Visuals")
if not Visuals then return end

local accent=Color3.fromRGB(125,82,235)
local order=39000
local function section(text)
    local l=Instance.new("TextLabel")
    l.LayoutOrder=order; order+=1; l.Size=UDim2.new(1,0,0,22); l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextColor3=Color3.fromRGB(166,159,192)
    l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=string.upper(text); l.Parent=Visuals
    return l
end
local function row(label)
    local f=Instance.new("Frame")
    f.LayoutOrder=order; order+=1; f.Size=UDim2.new(1,0,0,36); f.BackgroundColor3=Color3.fromRGB(24,24,33); f.BorderSizePixel=0; f.Parent=Visuals
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1; t.Position=UDim2.fromOffset(10,0); t.Size=UDim2.new(1,-20,1,0)
    t.Font=Enum.Font.Gotham; t.TextSize=13; t.TextColor3=Color3.fromRGB(230,230,240); t.TextXAlignment=Enum.TextXAlignment.Left; t.Text=label; t.Parent=f
    return f,t
end
local function toggle(label,get,set)
    local f=row(label)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(48,24); b.Position=UDim2.new(1,-58,.5,-12); b.Text=""; b.BorderSizePixel=0; b.Parent=f
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=b
    local dot=Instance.new("Frame"); dot.Size=UDim2.fromOffset(18,18); dot.BorderSizePixel=0; dot.Parent=b
    local dc=Instance.new("UICorner"); dc.CornerRadius=UDim.new(1,0); dc.Parent=dot
    local function paint()
        local on=get(); b.BackgroundColor3=on and accent or Color3.fromRGB(50,50,62)
        dot.BackgroundColor3=Color3.new(1,1,1); dot.Position=on and UDim2.fromOffset(27,3) or UDim2.fromOffset(3,3)
    end
    b.MouseButton1Click:Connect(function() set(not get()); paint() end); paint(); return f
end

section("ESP Diagnostics V7")
local _,status=row("Workspace.Players: checking...")
status.TextColor3=Color3.fromRGB(168,210,255)
local _,counts=row("Direct models: 0  •  bot-shaped: 0")
counts.TextColor3=Color3.fromRGB(168,210,255)

local selfEnabled=false
local selfHighlight=nil
local selfBillboard=nil
local selfChar=nil

local function clearSelf()
    if selfHighlight then selfHighlight:Destroy(); selfHighlight=nil end
    if selfBillboard then selfBillboard:Destroy(); selfBillboard=nil end
    selfChar=nil
end
local function applySelf()
    clearSelf()
    if not selfEnabled then return end
    local ch=LP.Character
    if not ch then return end
    selfChar=ch
    local h=Instance.new("Highlight")
    h.Name="GunTestingLiteSelfESPTest"; h.Adornee=ch; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency=.75; h.OutlineTransparency=0; h.FillColor=Color3.fromRGB(80,190,255); h.OutlineColor=Color3.fromRGB(255,255,255)
    h.Parent=ch; selfHighlight=h
    local a=ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")
    if a then
        local bb=Instance.new("BillboardGui")
        bb.Name="GunTestingLiteSelfESPLabel"; bb.Adornee=a; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(170,28); bb.StudsOffsetWorldSpace=Vector3.new(0,3.5,0); bb.Parent=a
        local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Font=Enum.Font.GothamBold; t.TextSize=13
        t.TextColor3=Color3.fromRGB(110,210,255); t.TextStrokeTransparency=.35; t.Text="SELF ESP RENDER TEST"; t.Parent=bb
        selfBillboard=bb
    end
end

toggle("Self ESP Render Test",function() return selfEnabled end,function(v) selfEnabled=v; applySelf() end)
LP.CharacterAdded:Connect(function() if selfEnabled then task.wait(.5); applySelf() end end)

local probeEnabled=false
local probeHighlight=nil
local probeBillboard=nil
local probeModel=nil
local function isRealPlayerModel(m)
    if not m then return false end
    for _,p in ipairs(Players:GetPlayers()) do
        local c=p.Character
        if c and (m==c or m:IsDescendantOf(c) or c:IsDescendantOf(m)) then return true end
        if m.Name==p.Name then return true end
        for _,attr in ipairs({"UserId","PlayerUserId","OwnerUserId"}) do
            local ok,v=pcall(function() return m:GetAttribute(attr) end)
            if ok and tonumber(v)==p.UserId then return true end
        end
    end
    return false
end
local function rootOf(m)
    return m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
end
local function botCandidate(m,folder)
    if not m or not m:IsA("Model") or m.Parent~=folder or isRealPlayerModel(m) then return false end
    local hum=m:FindFirstChildOfClass("Humanoid")
    return hum~=nil and hum.Health>0 and rootOf(m)~=nil
end
local function clearProbe()
    if probeHighlight then probeHighlight:Destroy(); probeHighlight=nil end
    if probeBillboard then probeBillboard:Destroy(); probeBillboard=nil end
    probeModel=nil
end
local function applyProbe()
    clearProbe()
    if not probeEnabled then return end
    local folder=Workspace:FindFirstChild("Players")
    if not folder then return end
    local candidate=nil
    for _,m in ipairs(folder:GetChildren()) do if botCandidate(m,folder) then candidate=m; break end end
    if not candidate then return end
    probeModel=candidate
    local h=Instance.new("Highlight")
    h.Name="GunTestingLiteBotProbe"; h.Adornee=candidate; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency=.7; h.OutlineTransparency=0; h.FillColor=Color3.fromRGB(255,200,70); h.OutlineColor=Color3.fromRGB(255,255,255)
    h.Parent=candidate; probeHighlight=h
    local a=candidate:FindFirstChild("Head") or rootOf(candidate)
    if a then
        local bb=Instance.new("BillboardGui")
        bb.Name="GunTestingLiteBotProbeLabel"; bb.Adornee=a; bb.AlwaysOnTop=true; bb.Size=UDim2.fromOffset(180,28); bb.StudsOffsetWorldSpace=Vector3.new(0,3.5,0); bb.Parent=a
        local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Font=Enum.Font.GothamBold; t.TextSize=13
        t.TextColor3=Color3.fromRGB(255,215,100); t.TextStrokeTransparency=.35; t.Text="BOT ESP PROBE"; t.Parent=bb
        probeBillboard=bb
    end
end

toggle("First Bot ESP Probe",function() return probeEnabled end,function(v) probeEnabled=v; applyProbe() end)

local function refreshStatus()
    local folder=Workspace:FindFirstChild("Players")
    if not folder then
        status.Text="Workspace.Players: NOT FOUND"
        counts.Text="Direct models: 0  •  bot-shaped: 0"
        if probeEnabled then clearProbe() end
        return
    end
    local direct=0; local shaped=0; local real=0
    for _,m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            direct+=1
            if isRealPlayerModel(m) then real+=1 elseif botCandidate(m,folder) then shaped+=1 end
        end
    end
    status.Text="Workspace.Players: FOUND  •  real-player-shaped: "..real
    counts.Text="Direct models: "..direct.."  •  bot-shaped: "..shaped
    if probeEnabled and (not probeModel or not probeModel.Parent) then applyProbe() end
end

refreshStatus()
task.spawn(function()
    while shared.GunTestingLiteESPDiagnosticsV7 do
        task.wait(1)
        refreshStatus()
    end
end)
