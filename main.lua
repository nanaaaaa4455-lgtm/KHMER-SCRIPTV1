local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- =============================================
-- CONFIG
-- =============================================
local CFG = {
    AutoFarm = {
        Enabled = false,
        TargetMob = "ទីតាំងស្វ័យប្រវត្តិ",
        AutoLevel = true,
        UseAura = true,
        AttackRange = 30,
        WalkSpeed = 25,
    },
    AutoQuest = {
        Enabled = false,
        AutoAccept = true,
        AutoComplete = true,
    },
    FruitSniper = {
        Enabled = false,
        NotifyOnly = false,
        AutoCollect = true,
        AlertSound = true,
    },
    Teleport = {
        SavedPositions = {},
    },
    Visual = {
        ESPEnabled = false,
        ESPColor = Color3.fromRGB(255, 50, 50),
        FillColor = Color3.fromRGB(255, 50, 50),
        FillTransparency = 0.7,
        ShowHealth = true,
        ShowName = true,
        ShowDistance = true,
    },
    Speed = {
        Enabled = false,
        Value = 35,
    },
    AutoSkill = {
        Enabled = false,
        Keys = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V},
        Delay = 0.15,
    },
}

-- =============================================
-- UTILITIES
-- =============================================
local function GetDistance(a, b)
    return (a.Position - b.Position).Magnitude
end

local function SafeTeleport(position)
    if HumanoidRootPart and position then
        HumanoidRootPart.CFrame = CFrame.new(position)
    end
end

local function GetNearestMob(range)
    local nearest, nearestDist = nil, range or 999
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj ~= Character then
            local hum = obj.Humanoid
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("RootPart")
            if hum and hum.Health &gt; 0 and root then
                local dist = GetDistance(HumanoidRootPart, root)
                if dist &lt; nearestDist then
                    nearest = obj
                    nearestDist = dist
                end
            end
        end
    end
    return nearest, nearestDist
end

local function AttackTarget(target)
    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("RootPart")
    if not root then return end
    HumanoidRootPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 2, -4))
    if CFG.AutoSkill.Enabled then
        for _, key in ipairs(CFG.AutoSkill.Keys) do
            local input = Instance.new("InputObject")
            input.KeyCode = key
            input.UserInputType = Enum.UserInputType.Keyboard
            UserInputService.InputBegan:Fire(input, false)
            task.wait(CFG.AutoSkill.Delay)
        end
    end
end

-- =============================================
-- ESP ENGINE
-- =============================================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "DeltaESP"
ESPFolder.Parent = workspace

local ESPObjects = {}

local function CreateESP(character)
    if ESPObjects[character] then return end
    local highlight = Instance.new("Highlight")
    highlight.Adornee = character
    highlight.OutlineColor = CFG.Visual.ESPColor
    highlight.FillColor = CFG.Visual.FillColor
    highlight.FillTransparency = CFG.Visual.FillTransparency
    highlight.OutlineTransparency = 0
    highlight.Parent = ESPFolder

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Adornee = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
    billboardGui.Size = UDim2.new(0, 120, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = character.Name
    nameLabel.Parent = billboardGui

    local infoLabel = Instance.new("TextLabel")
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
    infoLabel.TextStrokeTransparency = 0
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "HP: 100"
    infoLabel.Parent = billboardGui

    ESPObjects[character] = {highlight = highlight, billboard = billboardGui, info = infoLabel}
end

local function RemoveESP(character)
    if ESPObjects[character] then
        for _, obj in pairs(ESPObjects[character]) do
            if obj and obj.Parent then obj:Destroy() end
        end
        ESPObjects[character] = nil
    end
end

local function UpdateESP()
    if not CFG.Visual.ESPEnabled then
        for char, _ in pairs(ESPObjects) do RemoveESP(char) end
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            CreateESP(player.Character)
            if ESPObjects[player.Character] then
                local hum = player.Character:FindFirstChild("Humanoid")
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if hum and root then
                    local dist = math.floor(GetDistance(HumanoidRootPart, root))
                    local info = string.format("HP: %d | ចម្ងាយ: %dm", math.floor(hum.Health), dist)
                    ESPObjects[player.Character].info.Text = info
                end
            end
        end
    end
    for char, _ in pairs(ESPObjects) do
        if not char.Parent then RemoveESP(char) end
    end
end

-- =============================================
-- FRUIT SNIPER
-- =============================================
local function ScanFruits()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:find("Fruit") or obj.Name:find("Devil") then
            if CFG.FruitSniper.AlertSound then
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://9120473568"
                sound.Volume = 1
                sound.Parent = workspace
                sound:Play()
                game:GetService("Debris"):AddItem(sound, 3)
            end
            if CFG.FruitSniper.AutoCollect then
                local root = obj:FindFirstChild("Handle") or obj.PrimaryPart
                if root then SafeTeleport(root.Position + Vector3.new(0, 3, 0)) end
            end
        end
    end
end

-- =============================================
-- AUTO FARM LOOP
-- =============================================
local farmConnection
local function StartAutoFarm()
    if farmConnection then farmConnection:Disconnect() end
    farmConnection = RunService.Heartbeat:Connect(function()
        if not CFG.AutoFarm.Enabled then return end
        Character = LocalPlayer.Character
        if not Character then return end
        HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        Humanoid = Character:FindFirstChild("Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid.Health &lt;= 0 then return end

        local mob, dist = GetNearestMob(CFG.AutoFarm.AttackRange)
        if mob then
            AttackTarget(mob)
        end
    end)
end

-- =============================================
-- SPEED HACK
-- =============================================
local speedConnection
local function ApplySpeed()
    if speedConnection then speedConnection:Disconnect() end
    speedConnection = RunService.Heartbeat:Connect(function()
        if not CFG.Speed.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = CFG.Speed.Value end
    end)
end

-- =============================================
-- UI BUILDER
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaBloxFruitKH"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 500)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(180, 50, 255)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = Color3.fromRGB(25, 10, 40)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Size = UDim2.new(1, -60, 1, 0)
HeaderLabel.Position = UDim2.new(0, 15, 0, 0)
HeaderLabel.BackgroundTransparency = 1
HeaderLabel.Text = "🌊 Delta Blox Fruit | ខ្មែរ"
HeaderLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
HeaderLabel.TextSize = 16
HeaderLabel.Font = Enum.Font.GothamBold
HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
HeaderLabel.Parent = Header

local SubLabel = Instance.new("TextLabel")
SubLabel.Size = UDim2.new(1, -60, 0, 14)
SubLabel.Position = UDim2.new(0, 15, 0, 32)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = "v2.4 | ប្រព័ន្ធស្វ័យប្រវត្តិ"
SubLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
SubLabel.TextSize = 11
SubLabel.Font = Enum.Font.Gotham
SubLabel.TextXAlignment = Enum.TextXAlignment.Left
SubLabel.Parent = Header

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -42, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 35, 0, 35)
MinBtn.Position = UDim2.new(1, -82, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child.Name ~= "Header" then
            child.Visible = not minimized
        end
    end
    MainFrame.Size = minimized and UDim2.new(0, 380, 0, 50) or UDim2.new(0, 380, 0, 500)
end)

-- Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -20, 0, 35)
TabBar.Position = UDim2.new(0, 10, 0, 58)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.Parent = TabBar

-- Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -20, 1, -105)
ContentArea.Position = UDim2.new(0, 10, 0, 100)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- =============================================
-- UI COMPONENTS
-- =============================================
local function MakeToggle(parent, labelText, yPos, cfg_table, cfg_key, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(210, 210, 230)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -54, 0.5, -11)
    toggle.BorderSizePixel = 0
    toggle.Text = ""
    toggle.Parent = row
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = cfg_table[cfg_key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function Refresh()
        local on = cfg_table[cfg_key]
        toggle.BackgroundColor3 = on and Color3.fromRGB(130, 60, 220) or Color3.fromRGB(50, 50, 70)
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        }):Play()
    end
    Refresh()

    toggle.MouseButton1Click:Connect(function()
        cfg_table[cfg_key] = not cfg_table[cfg_key]
        Refresh()
        if callback then callback(cfg_table[cfg_key]) end
    end)

    return row
end

local function MakeSlider(parent, labelText, yPos, cfg_table, cfg_key, minVal, maxVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.Position = UDim2.new(0, 0, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 0, 22)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(210, 210, 230)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.3, -12, 0, 22)
    valLabel.Position = UDim2.new(0.7, 0, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(cfg_table[cfg_key])
    valLabel.TextColor3 = Color3.fromRGB(180, 100, 255)
    valLabel.TextSize = 13
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(130, 60, 220)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((cfg_table[cfg_key] - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((cfg_table[cfg_key] - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local trackPos = track.AbsolutePosition.X
            local trackWidth = track.AbsoluteSize.X
            local relX = math.clamp((inp.Position.X - trackPos) / trackWidth, 0, 1)
            local val = math.floor(minVal + relX * (maxVal - minVal))
            cfg_table[cfg_key] = val
            fill.Size = UDim2.new(relX, 0, 1, 0)
            knob.Position = UDim2.new(relX, 0, 0.5, 0)
            valLabel.Text = tostring(val)
            if callback then callback(val) end
        end
    end)

    return row
end

local function MakeButton(parent, labelText, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(90, 40, 160)
    btn.Text = labelText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(120, 55, 210)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(90, 40, 160)}):Play()
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function MakeSectionLabel(parent, text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.Position = UDim2.new(0, 0, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = "— " .. text .. " —"
    lbl.TextColor3 = Color3.fromRGB(160, 80, 240)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = parent
    return lbl
end

-- =============================================
-- TAB SYSTEM
-- =============================================
local tabs = {}
local tabPages = {}
local activeTab = nil

local tabDefs = {
    {name = "ស្វ័យប្រវត្តិ", icon = "⚔️"},
    {name = "ភ្នែក ESP",     icon = "👁"},
    {name = "លឿន/ផ្សេង",    icon = "⚡"},
    {name = "ផ្លែឈើ",       icon = "🍎"},
}

local function SetActiveTab(idx)
    activeTab = idx
    for i, page in ipairs(tabPages) do
        page.Visible = (i == idx)
    end
    for i, btn in ipairs(tabs) do
        btn.BackgroundColor3 = (i == idx) and Color3.fromRGB(100, 45, 180) or Color3.fromRGB(30, 30, 45)
        btn.TextColor3 = (i == idx) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 160)
    end
end

for i, def in ipairs(tabDefs) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 82, 1, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    tabBtn.Text = def.icon .. " " .. def.name
    tabBtn.TextColor3 = Color3.fromRGB(140, 140, 160)
    tabBtn.TextSize = 11
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.BorderSizePixel = 0
    tabBtn.Parent = TabBar
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 7)
    tabs[i] = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page" .. i
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(130, 60, 220)
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = ContentArea
    tabPages[i] = page

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = page

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)

    local idx = i
    tabBtn.MouseButton1Click:Connect(function() SetActiveTab(idx) end)
end

-- =============================================
-- PAGE 1: ស្វ័យប្រវត្តិ (Auto Farm)
-- =============================================
local p1 = tabPages[1]

local function AddP1()
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.Parent = p1

    -- Auto Farm Section
    local sec1 = Instance.new("Frame")
    sec1.Size = UDim2.new(1, 0, 0, 22)
    sec1.BackgroundTransparency = 1
    sec1.LayoutOrder = 1
    sec1.Parent = p1
    MakeSectionLabel(sec1, "ប្រព័ន្ធ Auto Farm", 0)

    local farmToggle = Instance.new("Frame")
    farmToggle.Size = UDim2.new(1, 0, 0, 38)
    farmToggle.BackgroundTransparency = 1
    farmToggle.LayoutOrder = 2
    farmToggle.Parent = p1
    MakeToggle(farmToggle, "⚔️ Auto Farm ស្វ័យប្រវត្តិ", 0, CFG.AutoFarm, "Enabled", function(val)
        if val then StartAutoFarm() end
    end)

    local auraToggle = Instance.new("Frame")
    auraToggle.Size = UDim2.new(1, 0, 0, 38)
    auraToggle.BackgroundTransparency = 1
    auraToggle.LayoutOrder = 3
    auraToggle.Parent = p1
    MakeToggle(auraToggle, "✨ Auto Aura", 0, CFG.AutoFarm, "UseAura")

    local levelToggle = Instance.new("Frame")
    levelToggle.Size = UDim2.new(1, 0, 0, 38)
    levelToggle.BackgroundTransparency = 1
    levelToggle.LayoutOrder = 4
    levelToggle.Parent = p1
    MakeToggle(levelToggle, "📈 Auto Level Up", 0, CFG.AutoFarm, "AutoLevel")

    local rangeSlider = Instance.new("Frame")
    rangeSlider.Size = UDim2.new(1, 0, 0, 52)
    rangeSlider.BackgroundTransparency = 1
    rangeSlider.LayoutOrder = 5
    rangeSlider.Parent = p1
    MakeSlider(rangeSlider, "🎯 វិស័យវាយប្រហារ", 0, CFG.AutoFarm, "AttackRange", 10, 100)

    -- Auto Quest Section
    local sec2 = Instance.new("Frame")
    sec2.Size = UDim2.new(1, 0, 0, 22)
    sec2.BackgroundTransparency = 1
    sec2.LayoutOrder = 6
    sec2.Parent = p1
    MakeSectionLabel(sec2, "ប្រព័ន្ធ Auto Quest", 0)

    local questToggle = Instance.new("Frame")
    questToggle.Size = UDim2.new(1, 0, 0, 38)
    questToggle.BackgroundTransparency = 1
    questToggle.LayoutOrder = 7
    questToggle.Parent = p1
    MakeToggle(questToggle, "📜 Auto Accept Quest", 0, CFG.AutoQuest, "AutoAccept")

    local completeToggle = Instance.new("Frame")
    completeToggle.Size = UDim2.new(1, 0, 0, 38)
    completeToggle.BackgroundTransparency = 1
    completeToggle.LayoutOrder = 8
    completeToggle.Parent = p1
    MakeToggle(completeToggle, "✅ Auto Complete Quest", 0, CFG.AutoQuest, "AutoComplete")

    -- Skill Section
    local sec3 = Instance.new("Frame")
    sec3.Size = UDim2.new(1, 0, 0, 22)
    sec3.BackgroundTransparency = 1
    sec3.LayoutOrder = 9
    sec3.Parent = p1
    MakeSectionLabel(sec3, "ប្រព័ន្ធ Auto Skill", 0)

    local skillToggle = Instance.new("Frame")
    skillToggle.Size = UDim2.new(1, 0, 0, 38)
    skillToggle.BackgroundTransparency = 1
    skillToggle.LayoutOrder = 10
    skillToggle.Parent = p1
    MakeToggle(skillToggle, "🌀 Auto Skill (Z X C V)", 0, CFG.AutoSkill, "Enabled")
end

-- =============================================
-- PAGE 2: ESP
-- =============================================
local p2 = tabPages[2]

local function AddP2()
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.Parent = p2

    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 22)
    sec.BackgroundTransparency = 1
    sec.LayoutOrder = 1
    sec.Parent = p2
    MakeSectionLabel(sec, "ភ្នែក ESP Player", 0)

    local espToggle = Instance.new("Frame")
    espToggle.Size = UDim2.new(1, 0, 0, 38)
    espToggle.BackgroundTransparency = 1
    espToggle.LayoutOrder = 2
    espToggle.Parent = p2
    MakeToggle(espToggle, "👁 ESP Player", 0, CFG.Visual, "ESPEnabled")

    local nameToggle = Instance.new("Frame")
    nameToggle.Size = UDim2.new(1, 0, 0, 38)
    nameToggle.BackgroundTransparency = 1
    nameToggle.LayoutOrder = 3
    nameToggle.Parent = p2
    MakeToggle(nameToggle, "🏷️ បង្ហាញឈ្មោះ", 0, CFG.Visual, "ShowName")

    local hpToggle = Instance.new("Frame")
    hpToggle.Size = UDim2.new(1, 0, 0, 38)
    hpToggle.BackgroundTransparency = 1
    hpToggle.LayoutOrder = 4
    hpToggle.Parent = p2
    MakeToggle(hpToggle, "❤️ បង្ហាញ HP", 0, CFG.Visual, "ShowHealth")

    local distToggle = Instance.new("Frame")
    distToggle.Size = UDim2.new(1, 0, 0, 38)
    distToggle.BackgroundTransparency = 1
    distToggle.LayoutOrder = 5
    distToggle.Parent = p2
    MakeToggle(distToggle, "📏 បង្ហាញចម្ងាយ", 0, CFG.Visual, "ShowDistance")
end

-- =============================================
-- PAGE 3: Speed &amp; Extra
-- =============================================
local p3 = tabPages[3]

local function AddP3()
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.Parent = p3

    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 22)
    sec.BackgroundTransparency = 1
    sec.LayoutOrder = 1
    sec.Parent = p3
    MakeSectionLabel(sec, "ប្រព័ន្ធ Speed &amp; Extra", 0)

    local speedToggle = Instance.new("Frame")
    speedToggle.Size = UDim2.new(1, 0, 0, 38)
    speedToggle.BackgroundTransparency = 1
    speedToggle.LayoutOrder = 2
    speedToggle.Parent = p3
    MakeToggle(speedToggle, "⚡ Speed Hack", 0, CFG.Speed, "Enabled", function()
        ApplySpeed()
    end)

    local speedSlider = Instance.new("Frame")
    speedSlider.Size = UDim2.new(1, 0, 0, 52)
    speedSlider.BackgroundTransparency = 1
    speedSlider.LayoutOrder = 3
    speedSlider.Parent = p3
    MakeSlider(speedSlider, "🏃 លឿន", 0, CFG.Speed, "Value", 16, 150)

    local sec2 = Instance.new("Frame")
    sec2.Size = UDim2.new(1, 0, 0, 22)
    sec2.BackgroundTransparency = 1
    sec2.LayoutOrder = 4
    sec2.Parent = p3
    MakeSectionLabel(sec2, "ទីតាំង Teleport", 0)

    local savePosBtn = Instance.new("Frame")
    savePosBtn.Size = UDim2.new(1, 0, 0, 36)
    savePosBtn.BackgroundTransparency = 1
    savePosBtn.LayoutOrder = 5
    savePosBtn.Parent = p3
    MakeButton(savePosBtn, "💾 រក្សាទុក Position", 0, function()
        if HumanoidRootPart then
            local pos = HumanoidRootPart.Position
            table.insert(CFG.Teleport.SavedPositions, pos)
            print("[Delta] Position saved: " .. tostring(pos))
        end
    end)

    local tpLastBtn = Instance.new("Frame")
    tpLastBtn.Size = UDim2.new(1, 0, 0, 36)
    tpLastBtn.BackgroundTransparency = 1
    tpLastBtn.LayoutOrder = 6
    tpLastBtn.Parent = p3
    MakeButton(tpLastBtn, "🚀 Teleport ទៅ Position ចុងក្រោយ", 0, function()
        local saved = CFG.Teleport.SavedPositions
        if #saved &gt; 0 then
            SafeTeleport(saved[#saved])
        end
    end)

    local clearPosBtn = Instance.new("Frame")
    clearPosBtn.Size = UDim2.new(1, 0, 0, 36)
    clearPosBtn.BackgroundTransparency = 1
    clearPosBtn.LayoutOrder = 7
    clearPosBtn.Parent = p3
    MakeButton(clearPosBtn, "🗑️ លុប Position ទាំងអស់", 0, function()
        CFG.Teleport.SavedPositions = {}
    end)
end

-- =============================================
-- PAGE 4: Fruit Sniper
-- =============================================
local p4 = tabPages[4]

local function AddP4()
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.Parent = p4

    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 22)
    sec.BackgroundTransparency = 1
    sec.LayoutOrder = 1
    sec.Parent = p4
    MakeSectionLabel(sec, "ភ្នែក Fruit Sniper", 0)

    local sniperToggle = Instance.new("Frame")
    sniperToggle.Size = UDim2.new(1, 0, 0, 38)
    sniperToggle.BackgroundTransparency = 1
    sniperToggle.LayoutOrder = 2
    sniperToggle.Parent = p4
    MakeToggle(sniperToggle, "🍎 Fruit Sniper", 0, CFG.FruitSniper, "Enabled")

    local collectToggle = Instance.new("Frame")
    collectToggle.Size = UDim2.new(1, 0, 0, 38)
    collectToggle.BackgroundTransparency = 1
    collectToggle.LayoutOrder = 3
    collectToggle.Parent = p4
    MakeToggle(collectToggle, "🤏 Auto Collect Fruit", 0, CFG.FruitSniper, "AutoCollect")

    local soundToggle = Instance.new("Frame")
    soundToggle.Size = UDim2.new(1, 0, 0, 38)
    soundToggle.BackgroundTransparency = 1
    soundToggle.LayoutOrder = 4
    soundToggle.Parent = p4
    MakeToggle(soundToggle, "🔔 បន្លឺសំឡេងជូនដំណឹង", 0, CFG.FruitSniper, "AlertSound")

    local scanBtn = Instance.new("Frame")
    scanBtn.Size = UDim2.new(1, 0, 0, 36)
    scanBtn.BackgroundTransparency = 1
    scanBtn.LayoutOrder = 5
    scanBtn.Parent = p4
    MakeButton(scanBtn, "🔍 Scan ផ្លែឈើឥឡូវ", 0, function()
        ScanFruits()
    end)
end

AddP1()
AddP2()
AddP3()
AddP4()
SetActiveTab(1)

-- =============================================
-- OPEN BUTTON (ប្រសិនបើ UI ត្រូវបានបិទ)
-- =============================================
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 36, 0, 36)
openBtn.Position = UDim2.new(0, 10, 0.5, -18)
openBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 160)
openBtn.Text = "🌊"
openBtn.TextSize = 18
openBtn.Font = Enum.Font.GothamBold
openBtn.BorderSizePixel = 0
openBtn.Visible = false
openBtn.ZIndex = 10
openBtn.Parent = ScreenGui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)

CloseBtn.MouseButton1Click:Connect(function()
    openBtn.Visible = true
end)
openBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    openBtn.Visible = false
end)

-- =============================================
-- MAIN HEARTBEAT LOOP
-- =============================================
StartAutoFarm()
ApplySpeed()

RunService.Heartbeat:Connect(function()
    UpdateESP()
    if CFG.FruitSniper.Enabled then
        ScanFruits()
    end
    -- Character respawn sync
    local char = LocalPlayer.Character
    if char then
        HumanoidRootPart = char:FindFirstChild("HumanoidRootPart")
        Humanoid = char:FindFirstChild("Humanoid")
    end
end)

-- Respawn handler
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    task.wait(1)
    if CFG.AutoFarm.Enabled then StartAutoFarm() end
    if CFG.Speed.Enabled then ApplySpeed() end
end)
