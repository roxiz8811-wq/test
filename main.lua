-- Chop Your Tree | Auto Chop TreeSpawn + Fluent UI
-- แก้ไข: ไม่ถอดอาวุธ + ตีช้าลงเหมือนคนจริง + Animation เหวี่ยงขวานปกติ + ถือขวานค้าง

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "☘️Chop Your Tree☘️ | Gifmegamer123",
    SubTitle = "Project Beta",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 420),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "axe" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Services & Vars
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- AxeSwing ไม่ใช้แล้ว (เปลี่ยนไปจำลองคลิกซ้ายเพื่อ animation)

local farming = false
local DEBRIS = workspace:WaitForChild("Debris")

local autoChop = false
local lockBodyPos = nil
local lockBodyGyro = nil

local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ตั้งค่าปรับแต่ง (ทำให้ตีช้าลง + animation ชัด)
local CHOP_COOLDOWN       = 1.0      -- ตีทุก 1 วินาที (เหมือนคนตีปกติ ไม่เร็วเกิน)
local TELEPORT_DISTANCE   = 12
local SWING_HOLD_TIME     = 0.12     -- ค้างคลิกนานขึ้น ให้เหวี่ยงเต็ม
local EQUIP_WAIT_AFTER    = 0.5      -- รอหลัง equip ให้ขวานพร้อม animation
local TP_OFFSET           = Vector3.new(0, 3, -1)

local lastChopTime = 0
local chopConnection

-- ล็อกตำแหน่ง
local function lockPosition(targetCFrame)
    if lockBodyPos then lockBodyPos:Destroy() end
    if lockBodyGyro then lockBodyGyro:Destroy() end
    
    lockBodyPos = Instance.new("BodyPosition")
    lockBodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    lockBodyPos.Position = targetCFrame.Position
    lockBodyPos.P = 15000
    lockBodyPos.D = 1000
    lockBodyPos.Parent = hrp
    
    lockBodyGyro = Instance.new("BodyGyro")
    lockBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    lockBodyGyro.CFrame = targetCFrame
    lockBodyGyro.P = 15000
    lockBodyGyro.D = 1000
    lockBodyGyro.Parent = hrp
end

local function unlockPosition()
    if lockBodyPos then lockBodyPos:Destroy() lockBodyPos = nil end
    if lockBodyGyro then lockBodyGyro:Destroy() lockBodyGyro = nil end
end

-- Update character เมื่อ respawn
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    unlockPosition()
    Fluent:Notify({Title = "Respawn", Content = "อัพเดทตัวละครใหม่ + ล้างล็อกตำแหน่ง", Duration = 3})
end)

-- หา Plot + TreeSpawn (เหมือนเดิม)
local function findMyPlot()
    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder then return nil end
    
    for _, plot in ipairs(plotsFolder:GetDescendants()) do
        local owner = plot:FindFirstChild("Owner")
        if owner then
            if (owner:IsA("StringValue") and owner.Value == player.Name) or
               (owner:IsA("ObjectValue") and owner.Value == player) then
                return plot
            end
        end
        
        for _, descendant in ipairs(plot:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
                local text = descendant.Text or ""
                if text:find(player.Name, 1, true) then
                    return plot
                end
            end
        end
    end
    return nil
end

local function getTreeSpawn()
    local plot = findMyPlot()
    if not plot then return nil end
    
    local contents = plot:FindFirstChild("PlotContents")
    if contents then
        local tree = contents:FindFirstChild("TreeSpawn")
        if tree and tree:IsA("BasePart") then
            return tree
        end
    end
    return nil
end

-- Equip ขวานช่อง 1 (ไม่ถอดก่อน)
local function equipAxeSlot1()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
    task.wait(0.06)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    task.wait(EQUIP_WAIT_AFTER)
end

-- ตรวจว่าถือ Tool อยู่ไหม
local function isHoldingTool()
    return character:FindFirstChildWhichIsA("Tool") ~= nil
end

-- ตีแบบคนจริง (มี animation เหวี่ยงขวาน)
local CHOP_COOLDOWN = 1.2          -- รอบใหญ่ทุก 1.2 วินาที
local SWINGS_PER_CYCLE = 4
local DELAY_BETWEEN_SWINGS = 0.20
local SWING_HOLD_TIME = 0.10

local function swingAxeLikeHuman()
    for i = 1, SWINGS_PER_CYCLE do
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(SWING_HOLD_TIME)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        if i < SWINGS_PER_CYCLE then
            task.wait(DELAY_BETWEEN_SWINGS)
        end
    end
end

-- ฟังก์ชัน chop 1 ครั้ง
local function performChop()
    if tick() - lastChopTime < CHOP_COOLDOWN then
        return
    end
    
    local treeSpawn = getTreeSpawn()
    if not treeSpawn then return end
    
    local dist = (hrp.Position - treeSpawn.Position).Magnitude
    local targetCFrame
    
    if dist > TELEPORT_DISTANCE then
        local tpPos = treeSpawn.Position + TP_OFFSET
        targetCFrame = CFrame.lookAt(tpPos, treeSpawn.Position)
        hrp.CFrame = targetCFrame
        task.wait(0.12)
    else
        targetCFrame = hrp.CFrame
    end
    
    lockPosition(targetCFrame)
    
    -- ถ้าไม่ถือ tool → equip ใหม่ (ปกติถือค้างอยู่แล้ว)
    if not isHoldingTool() then
        equipAxeSlot1()
    end
    
    swingAxeLikeHuman()
    
    lastChopTime = tick()
end

-- Loop
local function startChopLoop()
    if chopConnection then chopConnection:Disconnect() end
    
    chopConnection = RunService.Heartbeat:Connect(function()
        if autoChop and character and hrp and hrp.Parent then
            pcall(performChop)
        end
    end)
end



-- Toggle
local ToggleChop = Tabs.Main:AddToggle("AutoChop", {
    Title = "🌳 Auto Chop Tree",
    Default = false,
    Callback = function(Value)
        autoChop = Value
        if Value then
            equipAxeSlot1()
            startChopLoop()
            Fluent:Notify({
                Title = "🌳 Auto Chop Tree",
                Content = "เปิดใช้งานแล้ว",
                Duration = 5
            })
        else
            if chopConnection then chopConnection:Disconnect() chopConnection = nil end
            unlockPosition()
            Fluent:Notify({
                Title = "🌳 Auto Chop Tree",
                Content = "ปิดใช้งานแล้ว",
                Duration = 3
            })
        end
    end
})

-- Function หา Lucky Blocks
local function getLuckyBlocks()
    local blocks = {}
    for _, obj in ipairs(DEBRIS:GetDescendants()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("normal") or nameLower:find("rainbow") or nameLower:find("🍀") then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") or obj
            if part and part:IsA("BasePart") then
                table.insert(blocks, part)
            end
        end
    end
    return blocks
end

-- Teleport ไปหา + พยายามเก็บ
local function collectLuckyBlock(targetPart)
    if not targetPart or not targetPart.Parent then return end
    
    -- Teleport ไปใกล้ ๆ
    hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
    
    -- ถ้ามี ProximityPrompt (บางเกมใช้ prompt เก็บ)
    local prompt = targetPart.Parent:FindFirstChildWhichIsA("ProximityPrompt") 
                or targetPart:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
    end
    
    -- หรือบางเกมแค่ชนก็เก็บได้ (teleport ใกล้มาก ๆ ก็พอ)
end

-- Main Loop
task.spawn(function()
    while true do
        task.wait(0.5)  -- ทุก 0.5 วินาทีเช็ค (ไม่หนักเกิน)
        
        if not farming then continue end
        if not player.Character or not hrp then continue end
        
        local luckyBlocks = getLuckyBlocks()
        if #luckyBlocks == 0 then continue end
        
        -- เรียงตามใกล้ที่สุด
        table.sort(luckyBlocks, function(a, b)
            return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
        end)
        
        collectLuckyBlock(luckyBlocks[1])
    end
end)

-- UI Elements
local ToggleFarm = Tabs.Main:AddToggle("AutoLuckyFarm", {
    Title = "🎁 Auto Farm Lucky Blocks",
    Default = false,
    Callback = function(Value)
        farming = Value
        Fluent:Notify({
            Title = "🎁 Lucky Block Farm",
            Content = Value and "เปิดใช้งานแล้ว กำลังฟาร์ม Lucky Blocks..." or "ปิดใช้งานแล้ว",
            Duration = 4
        })
    end
})

local defaultWalkSpeed = 16          -- ความเร็วปกติของ Roblox (เก็บไว้เผื่อรีเซ็ต)
local customWalkSpeed = 50           -- ค่าเริ่มต้น (จะเปลี่ยนได้จาก Input)
local speedEnabled = false

-- ฟังก์ชันอัปเดตความเร็ว
local function updateWalkSpeed()
    if not character or not humanoid then return end
    
    if speedEnabled then
        humanoid.WalkSpeed = customWalkSpeed
    else
        humanoid.WalkSpeed = defaultWalkSpeed
    end
end

-- เมื่อตัวละครเกิดใหม่ → รีเซ็ต + ใส่ความเร็วใหม่ถ้าเปิดอยู่
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    unlockPosition()  -- จากโค้ดเดิม
    
    -- รอให้ Humanoid พร้อม แล้วอัปเดต WalkSpeed
    task.wait(0.3)
    updateWalkSpeed()
    
    Fluent:Notify({Title = "Respawn", Content = "ตัวละครใหม่ + อัปเดตความเร็ววิ่ง", Duration = 3})
end)

-- ถ้าเปลี่ยนค่าใน Input → อัปเดตทันที (ถ้าเปิดอยู่)
local function onSpeedValueChanged(newValue)
    customWalkSpeed = tonumber(newValue) or 50
    if customWalkSpeed < 0 then customWalkSpeed = 0 end  -- ป้องกันติดลบ
    updateWalkSpeed()
end

local ToggleSpeed = Tabs.Main:AddToggle("SpeedHack", {
    Title = "🚀 Movement Speed",
    Default = false,
    Callback = function(Value)
        speedEnabled = Value
        updateWalkSpeed()
        
        Fluent:Notify({
            Title = "Speed Hack",
            Content = Value and ("เปิดแล้ว – ความเร็ว " .. customWalkSpeed) or "ปิดแล้ว – กลับมาความเร็วปกติ",
            Duration = 4
        })
    end
})

local InputSpeed = Tabs.Main:AddInput("SpeedValue", {
    Title = "ความเร็ววิ่ง (WalkSpeed)",
    Placeholder = "ใส่ตัวเลข เช่น 50, 100, 200",
    Default = tostring(customWalkSpeed),
    Numeric = true,              -- อนุญาตเฉพาะตัวเลข
    Finished = false,            -- อัปเดตแบบ real-time (ทุกครั้งที่พิมพ์)
    Callback = function(Value)
        onSpeedValueChanged(Value)
    end
})

-- Settings (เหมือนเดิม)
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("ChopYourTreeAutoChop")
SaveManager:SetFolder("ChopYourTreeAutoChop/Config")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "พร้อมใช้งาน – ตีช้า + Animation ปกติ",
    Content = "เปิด toggle → equip ขวานครั้งเดียว + ตีแบบคนจริง (มีเหวี่ยงขวาน) กด Debug ทดสอบก่อน",
    Duration = 8
})

SaveManager:LoadAutoloadConfig()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Toggleui"
ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local Toggle = Instance.new("TextButton")
Toggle.Name = "Toggle"
Toggle.Parent = ScreenGui
Toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Toggle.BackgroundTransparency = 0.5
Toggle.Position = UDim2.new(0, 0, 0.454706937, 0)
Toggle.Size = UDim2.new(0, 50, 0, 50)
Toggle.Font = Enum.Font.SourceSans
Toggle.Text = ""
Toggle.TextColor3 = Color3.fromRGB(248, 248, 248)
Toggle.TextSize = 18.000
Toggle.Draggable = true

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0.2, 0)
Corner.Parent = Toggle

local Image = Instance.new("ImageLabel")
Image.Name = "Icon"
Image.Parent = Toggle
Image.Size = UDim2.new(1, 0, 1, 0)
Image.BackgroundTransparency = 1
Image.Image = "rbxassetid://117239677500065" 

local Corner2 = Instance.new("UICorner")
Corner2.CornerRadius = UDim.new(0.2, 0)
Corner2.Parent = Image

Toggle.MouseButton1Click:Connect(function()
    if gethui():FindFirstChild("ScreenGui") then
        gethui().ScreenGui.Enabled = not gethui().ScreenGui.Enabled
    end
end)
