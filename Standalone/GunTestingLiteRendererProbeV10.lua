-- GunTestingLiteRendererProbeV10.lua
-- Self-only renderer diagnostics. Does NOT draw ESP on other real players.
-- Purpose: isolate ScreenGui, WorldToViewportPoint and Highlight support.

if shared.GunTestingLiteRendererProbeV10 then return end
shared.GunTestingLiteRendererProbeV10=true

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
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
local order=50000
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
    b.MouseButton1Click:Connect(function() set(not get()); paint() end); paint()
end

section("Renderer Probe V10 - self only")
local _,status=row("Camera: checking...")
status.TextColor3=Color3.fromRGB(168,210,255)
local _,project=row("Self projection: checking...")
project.TextColor3=Color3.fromRGB(168,210,255)
local _,folderInfo=row("Workspace.Players models: 0")
folderInfo.TextColor3=Color3.fromRGB(168,210,255)

local testGui=Instance.new("ScreenGui")
testGui.Name="GunTestingLiteRendererProbeV10"; testGui.IgnoreGuiInset=true; testGui.ResetOnSpawn=false; testGui.DisplayOrder=7000; testGui.Parent=parent

local staticEnabled=false
local static=Instance.new("Frame")
static.Name="StaticOverlayProbe"; static.Size=UDim2.fromOffset(160,70); static.Position=UDim2.new(1,-190,0,70)
static.BackgroundTransparency=1; static.BorderSizePixel=0; static.Visible=false; static.Parent=testGui
local st=Instance.new("UIStroke"); st.Thickness=3; st.Color=Color3.fromRGB(255,80,210); st.Parent=static
local sl=Instance.new("TextLabel"); sl.BackgroundTransparency=1; sl.Size=UDim2.fromScale(1,1); sl.Font=Enum.Font.GothamBold; sl.TextSize=13
sl.TextColor3=Color3.fromRGB(255,120,220); sl.TextStrokeTransparency=.2; sl.Text="STATIC OVERLAY TEST"; sl.Parent=static

toggle("Static Overlay Test",function() return staticEnabled end,function(v) staticEnabled=v; static.Visible=v end)

local self2D=false
local edges={}
for i=1,4 do
    local f=Instance.new("Frame"); f.Name="Self2DEdge"..i; f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(80,210,255); f.Visible=false; f.Parent=testGui; edges[i]=f
end
local nameLabel=Instance.new("TextLabel")
nameLabel.BackgroundTransparency=1; nameLabel.Size=UDim2.fromOffset(220,20); nameLabel.Font=Enum.Font.GothamBold; nameLabel.TextSize=12
nameLabel.TextColor3=Color3.fromRGB(80,210,255); nameLabel.TextStrokeTransparency=.2; nameLabel.Text="SELF 2D PROJECTION TEST"; nameLabel.Visible=false; nameLabel.Parent=testGui

toggle("Self 2D Box Test",function() return self2D end,function(v)
    self2D=v
    if not v then for _,e in ipairs(edges) do e.Visible=false end; nameLabel.Visible=false end
end)

local selfHighlight=false
local hi=nil
local function clearHighlight()
    if hi then pcall(function() hi:Destroy() end); hi=nil end
end
local function refreshHighlight()
    clearHighlight()
    if not selfHighlight then return end
    local ch=LP.Character
    if not ch then return end
    hi=Instance.new("Highlight")
    hi.Name="GunTestingLiteSelfHighlightV10"; hi.Adornee=ch; hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hi.FillColor=Color3.fromRGB(80,210,255); hi.OutlineColor=Color3.new(1,1,1); hi.FillTransparency=.65; hi.OutlineTransparency=0
    hi.Parent=ch
end

toggle("Self Highlight Test",function() return selfHighlight end,function(v) selfHighlight=v; refreshHighlight() end)
LP.CharacterAdded:Connect(function() if selfHighlight then task.wait(.5); refreshHighlight() end end)

local function hideSelf2D()
    for _,e in ipairs(edges) do e.Visible=false end
    nameLabel.Visible=false
end
local function setRect(x,y,w,h)
    local t=2
    edges[1].Position=UDim2.fromOffset(x,y); edges[1].Size=UDim2.fromOffset(w,t)
    edges[2].Position=UDim2.fromOffset(x,y+h-t); edges[2].Size=UDim2.fromOffset(w,t)
    edges[3].Position=UDim2.fromOffset(x,y); edges[3].Size=UDim2.fromOffset(t,h)
    edges[4].Position=UDim2.fromOffset(x+w-t,y); edges[4].Size=UDim2.fromOffset(t,h)
    for _,e in ipairs(edges) do e.Visible=true end
    nameLabel.Position=UDim2.fromOffset(x+w/2-110,y-20); nameLabel.Visible=true
end

RunService.RenderStepped:Connect(function()
    local cam=Workspace.CurrentCamera
    local ch=LP.Character
    local root=ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso"))
    local head=ch and (ch:FindFirstChild("Head") or root)

    status.Text="Camera: "..(cam and cam.ClassName or "nil").."  •  Character: "..(ch and "FOUND" or "nil")

    local folder=Workspace:FindFirstChild("Players")
    local models=0
    if folder then for _,x in ipairs(folder:GetChildren()) do if x:IsA("Model") then models+=1 end end end
    folderInfo.Text="Workspace.Players models: "..models..(folder and "  •  FOUND" or "  •  NOT FOUND")

    if not cam or not root then
        project.Text="Self projection: NO CAMERA/ROOT"
        if self2D then hideSelf2D() end
        return
    end

    local rp,on=cam:WorldToViewportPoint(root.Position)
    project.Text=string.format("Self projection: x=%d y=%d z=%.1f on=%s",math.floor(rp.X),math.floor(rp.Y),rp.Z,tostring(on))

    if not self2D then return end
    if not on or rp.Z<=0 then hideSelf2D(); return end

    local hp=head and cam:WorldToViewportPoint(head.Position+Vector3.new(0,1,0)) or rp
    local foot=cam:WorldToViewportPoint(root.Position-Vector3.new(0,3.2,0))
    if hp.Z<=0 or foot.Z<=0 then hideSelf2D(); return end
    local h=math.max(40,math.abs(foot.Y-hp.Y))
    local w=math.max(24,h*.55)
    setRect(rp.X-w/2,hp.Y,w,h)
end)
