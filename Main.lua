--[[
    Xeno Client Fling (Collision Trigger)
    - Client-sided fling utility with polished toggle UI.
    - Fling triggers when another player's character collides with your character.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    return
end

-- Cleanup previous run
if _G.XenoCollisionFling and _G.XenoCollisionFling.Destroy then
    pcall(function()
        _G.XenoCollisionFling:Destroy()
    end)
end

local Controller = {}
Controller.Enabled = false
Controller.Connections = {}
Controller.LastFling = {}
Controller.Cooldown = 0.7
Controller.GuiName = "XenoCollisionFlingUI"

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Controller.Connections, connection)
    return connection
end

local function cleanupConnections()
    for _, c in ipairs(Controller.Connections) do
        if c and c.Disconnect then
            c:Disconnect()
        end
    end
    table.clear(Controller.Connections)
end

local function getCharacterParts(character)
    local parts = {}
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        end
    end
    return parts
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isAlive(character)
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function setStatus(text, color)
    if Controller.StatusLabel then
        Controller.StatusLabel.Text = text
        TweenService:Create(Controller.StatusLabel, TweenInfo.new(0.2), {
            TextColor3 = color or Color3.fromRGB(225, 225, 225)
        }):Play()
    end
end

local function flingTarget(targetPlayer)
    if not Controller.Enabled or targetPlayer == LocalPlayer then
        return
    end

    local now = tick()
    local last = Controller.LastFling[targetPlayer]
    if last and now - last < Controller.Cooldown then
        return
    end
    Controller.LastFling[targetPlayer] = now

    local myCharacter = LocalPlayer.Character
    local targetCharacter = targetPlayer.Character

    if not (isAlive(myCharacter) and isAlive(targetCharacter)) then
        return
    end

    local myRoot = getRoot(myCharacter)
    local targetRoot = getRoot(targetCharacter)
    if not (myRoot and targetRoot) then
        return
    end

    -- Client fling impulse trick: burst spin + velocity while intersecting target's root.
    local originalCF = myRoot.CFrame
    local originalVel = myRoot.AssemblyLinearVelocity
    local originalRot = myRoot.AssemblyAngularVelocity

    setStatus("Flung: " .. targetPlayer.Name, Color3.fromRGB(120, 255, 180))

    local start = tick()
    while tick() - start < 0.16 and Controller.Enabled and myRoot.Parent and targetRoot.Parent do
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0.3, 0)
        myRoot.AssemblyLinearVelocity = Vector3.new(0, 420, 0)
        myRoot.AssemblyAngularVelocity = Vector3.new(9e4, 9e4, 9e4)
        RunService.Heartbeat:Wait()
    end

    if myRoot and myRoot.Parent then
        myRoot.CFrame = originalCF
        myRoot.AssemblyLinearVelocity = originalVel
        myRoot.AssemblyAngularVelocity = originalRot
    end
end

local function resolvePlayerFromHit(hitPart)
    if not hitPart or not hitPart.Parent then
        return nil
    end

    local model = hitPart:FindFirstAncestorOfClass("Model")
    if not model then
        return nil
    end

    return Players:GetPlayerFromCharacter(model)
end

local function bindCollisionHandlers(character)
    for _, part in ipairs(getCharacterParts(character)) do
        connect(part.Touched, function(hit)
            if not Controller.Enabled then
                return
            end

            local hitPlayer = resolvePlayerFromHit(hit)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                flingTarget(hitPlayer)
            end
        end)
    end

    connect(character.DescendantAdded, function(desc)
        if desc:IsA("BasePart") then
            connect(desc.Touched, function(hit)
                if not Controller.Enabled then
                    return
                end

                local hitPlayer = resolvePlayerFromHit(hit)
                if hitPlayer and hitPlayer ~= LocalPlayer then
                    flingTarget(hitPlayer)
                end
            end)
        end
    end)
end

local function refreshCharacterBinding()
    cleanupConnections()

    if LocalPlayer.Character then
        bindCollisionHandlers(LocalPlayer.Character)
    end

    connect(LocalPlayer.CharacterAdded, function(char)
        task.wait(0.2)
        refreshCharacterBinding()
        if Controller.Enabled then
            setStatus("Enabled - waiting for collision", Color3.fromRGB(120, 255, 180))
        end
    end)
end

local function createGui()
    local old = game:GetService("CoreGui"):FindFirstChild(Controller.GuiName)
    if old then
        old:Destroy()
    end

    local parentGui
    if gethui then
        parentGui = gethui()
    else
        parentGui = game:GetService("CoreGui")
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = Controller.GuiName
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Parent = gui
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.56)
    shadow.Size = UDim2.fromOffset(356, 168)
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.45
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 0
    Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 18)

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Parent = gui
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.55)
    panel.Size = UDim2.fromOffset(340, 150)
    panel.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
    panel.BorderSizePixel = 0
    panel.ZIndex = 1
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = panel
    stroke.Thickness = 1.2
    stroke.Transparency = 0.15
    stroke.Color = Color3.fromRGB(105, 140, 255)

    local gradient = Instance.new("UIGradient")
    gradient.Parent = panel
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 39, 59)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 27))
    })
    gradient.Rotation = 130

    local title = Instance.new("TextLabel")
    title.Parent = panel
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 10)
    title.Size = UDim2.fromOffset(200, 26)
    title.Font = Enum.Font.GothamBold
    title.Text = "Collision Fling"
    title.TextSize = 19
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(240, 243, 255)
    title.ZIndex = 2

    local subtitle = Instance.new("TextLabel")
    subtitle.Parent = panel
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.fromOffset(14, 34)
    subtitle.Size = UDim2.fromOffset(280, 20)
    subtitle.Font = Enum.Font.Gotham
    subtitle.Text = "Client-side • Auto fling on collision"
    subtitle.TextSize = 13
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(165, 173, 215)
    subtitle.ZIndex = 2

    local status = Instance.new("TextLabel")
    status.Parent = panel
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(14, 112)
    status.Size = UDim2.fromOffset(300, 20)
    status.Font = Enum.Font.GothamMedium
    status.Text = "Disabled"
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = Color3.fromRGB(255, 140, 140)
    status.ZIndex = 2
    Controller.StatusLabel = status

    local toggleButton = Instance.new("TextButton")
    toggleButton.Parent = panel
    toggleButton.BackgroundColor3 = Color3.fromRGB(45, 52, 88)
    toggleButton.Position = UDim2.fromOffset(14, 66)
    toggleButton.Size = UDim2.fromOffset(312, 36)
    toggleButton.AutoButtonColor = false
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.TextColor3 = Color3.fromRGB(238, 241, 255)
    toggleButton.Text = "Enable Fling"
    toggleButton.ZIndex = 2
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 12)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Parent = toggleButton
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.2
    btnStroke.Color = Color3.fromRGB(125, 153, 255)

    local dragging, dragStart, startPos
    connect(panel.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            shadow.Position = UDim2.new(
                panel.Position.X.Scale,
                panel.Position.X.Offset,
                panel.Position.Y.Scale,
                panel.Position.Y.Offset + 3
            )
        end
    end)

    local function updateToggleVisual()
        local targetColor = Controller.Enabled and Color3.fromRGB(55, 170, 112) or Color3.fromRGB(45, 52, 88)
        local targetText = Controller.Enabled and "Disable Fling" or "Enable Fling"

        toggleButton.Text = targetText
        TweenService:Create(toggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = targetColor
        }):Play()

        if Controller.Enabled then
            setStatus("Enabled - waiting for collision", Color3.fromRGB(120, 255, 180))
        else
            setStatus("Disabled", Color3.fromRGB(255, 140, 140))
        end
    end

    connect(toggleButton.MouseButton1Click, function()
        Controller.Enabled = not Controller.Enabled
        updateToggleVisual()
    end)

    connect(toggleButton.MouseEnter, function()
        TweenService:Create(toggleButton, TweenInfo.new(0.12), {
            Size = UDim2.fromOffset(314, 38)
        }):Play()
    end)

    connect(toggleButton.MouseLeave, function()
        TweenService:Create(toggleButton, TweenInfo.new(0.12), {
            Size = UDim2.fromOffset(312, 36)
        }):Play()
    end)

    updateToggleVisual()

    gui.Parent = parentGui
    Controller.Gui = gui
end

function Controller:Destroy()
    cleanupConnections()
    if self.Gui then
        self.Gui:Destroy()
    end
end

createGui()
refreshCharacterBinding()

_G.XenoCollisionFling = Controller
