-- Chop Your Tree | Auto Chop TreeSpawn + Fluent UI
-- แก้ไข: ไม่ถอดอาวุธ + ตีช้าลงเหมือนคนจริง + Animation เหวี่ยงขวานปกติ + ถือขวานค้าง
-- เพิ่ม: Teleport กลับตำแหน่งเดิมหลังเก็บ Lucky Block ครบ

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

local farming = false
local DEBRIS = workspace:WaitForChild("Debris")
local autoChop = false
local lockBodyPos = nil
local lockBodyGyro = nil
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ตั้งค่าปรับแต่ง
local CHOP_COOLDOWN       = 1.2
local TELEPORT_DISTANCE   = 12
local SWING_HOLD_TIME     = 0.10
local EQUIP_WAIT_AFTER    = 0.5
local TP_OFFSET           = Vector3.new(0, 3, -1)
local lastChopTime = 0
local chopConnection

-- เพิ่มตัวแปรสำหรับ Lucky Block
local originalPosition = nil          -- ตำแหน่งก่อนเริ่มฟาร์ม Lucky
local isCollecting = false

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

-- หา Plot + TreeSpawn
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

-- Equip ขวานช่อง 1
local function equipAxeSlot1()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
    task.wait(0.06)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    task.wait(EQUIP_WAIT_AFTER)
end

local function isHoldingTool()
    return character:FindFirstChildWhichIsA("Tool") ~= nil
end

-- ตีแบบคนจริง
local SWINGS_PER_CYCLE = 4
local DELAY_BETWEEN_SWINGS = 0.20

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
    
    if not isHoldingTool() then
        equipAxeSlot1()
    end
    
    swingAxeLikeHuman()
    
    lastChopTime = tick()
end

local function startChopLoop()
    if chopConnection then chopConnection:Disconnect() end
    
    chopConnection = RunService.Heartbeat:Connect(function()
        if autoChop and character and hrp and hrp.Parent then
            pcall(performChop)
        end
    end)
end

-- Toggle Auto Chop
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

-- Lucky Block Functions
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

local function collectLuckyBlock(targetPart)
    if not targetPart or not targetPart.Parent then return end
    
    local targetPos = targetPart.Position + Vector3.new(0, 3.5, 0)
    hrp.CFrame = CFrame.new(targetPos)
    
    task.wait(0.15)
    
    local prompt = targetPart.Parent:FindFirstChildWhichIsA("ProximityPrompt") 
                or targetPart:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
    end
end

local function returnToOriginalPosition()
    if originalPosition and hrp and hrp.Parent then
        hrp.CFrame = originalPosition
    end
end

-- Lucky Block Main Loop
task.spawn(function()
    while true do
        task.wait(0.6)

        if not farming then
            originalPosition = nil
            continue
        end

        if not player.Character or not hrp or not humanoid or humanoid.Health <= 0 then
            continue
        end

        -- บันทึกตำแหน่งครั้งแรกเมื่อเปิด
        if not originalPosition then
            originalPosition = hrp.CFrame
        end

        if isCollecting then continue end

        local luckyBlocks = getLuckyBlocks()
        if #luckyBlocks == 0 then
            if originalPosition then
                task.spawn(returnToOriginalPosition)
            end
            continue
        end

        table.sort(luckyBlocks, function(a, b)
            return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
        end)

        isCollecting = true

        for _, block in ipairs(luckyBlocks) do
            if not farming then break end
            if not block or not block.Parent then continue end

            collectLuckyBlock(block)
            task.wait(0.28)  -- เวลาระหว่างการเก็บแต่ละชิ้น
        end

        isCollecting = false

        -- หลังเก็บรอบนี้เสร็จ → กลับตำแหน่งเดิม
        task.wait(0.4)
        task.spawn(returnToOriginalPosition)
    end
end)

-- UI Toggle Lucky Farm
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

-- WalkSpeed
local defaultWalkSpeed = 16
local customWalkSpeed = 50
local speedEnabled = false

local function updateWalkSpeed()
    if not character or not humanoid then return end
    humanoid.WalkSpeed = speedEnabled and customWalkSpeed or defaultWalkSpeed
end

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    unlockPosition()
    task.wait(0.3)
    updateWalkSpeed()
    Fluent:Notify({Title = "Respawn", Content = "ตัวละครใหม่ + อัปเดตความเร็ววิ่ง", Duration = 3})
end)

local function onSpeedValueChanged(newValue)
    customWalkSpeed = tonumber(newValue) or 50
    if customWalkSpeed < 0 then customWalkSpeed = 0 end
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
    Numeric = true,
    Finished = false,
    Callback = function(Value)
        onSpeedValueChanged(Value)
    end
})

-- Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("ChopYourTreeAutoChop")
SaveManager:SetFolder("ChopYourTreeAutoChop/Config")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "พร้อมใช้งาน – มีระบบกลับตำแหน่งหลังฟาร์ม Lucky",
    Content = "เปิด toggle Lucky → จะบันทึกตำแหน่ง แล้วกลับมาหลังเก็บครบ",
    Duration = 8
})

SaveManager:LoadAutoloadConfig()

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "FluentToggleGui"
ToggleGui.ResetOnSpawn = false  -- ไม่รีเซ็ตตอน respawn
ToggleGui.Parent = PlayerGui  -- หรือ game.CoreGui ถ้า exploit ของคุณอนุญาต (เพื่ออยู่ด้านบนสุด)

-- สร้าง Frame หลักสำหรับ draggable (ทำให้ลากง่าย)
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Size = UDim2.fromOffset(30, 30)  -- ขนาดปุ่ม
ToggleFrame.Position = UDim2.new(0.02, 0, 0.4, 0)  -- ตำแหน่งเริ่มต้น (ซ้ายบนหน่อย ๆ ปรับได้)
ToggleFrame.BackgroundTransparency = 1  -- โปร่งใส ไม่มีพื้นหลัง
ToggleFrame.Parent = ToggleGui

-- สร้าง ImageButton (ปุ่มรูปภาพ)
local ToggleButton = Instance.new("ImageButton")
ToggleButton.Size = UDim2.fromScale(1, 1)  -- เต็ม Frame
ToggleButton.BackgroundTransparency = 0.3  -- พื้นหลังกึ่งโปร่งใส
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)  -- สีพื้นหลังเข้ม
ToggleButton.Image = "rbxassetid://15307540148"  -- เปลี่ยน ID รูปภาพตรงนี้ได้! (gear icon เป็นตัวอย่าง)
ToggleButton.ImageTransparency = 0.1
ToggleButton.ScaleType = Enum.ScaleType.Fit
ToggleButton.Parent = ToggleFrame

-- ทำให้ปุ่มกลม (Corner)
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0.5, 0)  -- กลม 50%
UICorner.Parent = ToggleButton

-- เพิ่ม Stroke เพื่อสวยงาม (ขอบ)
local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(100, 255, 200)
UIStroke.Thickness = 2
UIStroke.Transparency = 0.5
UIStroke.Parent = ToggleButton

-- ระบบ Draggable (ลากวางได้ทั้ง PC และ Mobile)
local UserInputService = game:GetService("UserInputService")
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function updateDrag(input)
    local delta = input.Position - dragStart
    ToggleFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- เมื่อกดปุ่ม -> Toggle Fluent UI
ToggleButton.Activated:Connect(function()
    if Window then
        Window:Minimize()  -- ใช้ method มาตรฐานของ Fluent เพื่อเปิด/ปิด (toggle minimize)
    else
        warn("Window not found! Fluent UI อาจโหลดไม่สำเร็จ")
    end
end)
