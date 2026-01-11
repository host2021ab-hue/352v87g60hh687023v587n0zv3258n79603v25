-- Rayfield laden mit Fehlerbehandlung
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end)

if not success then
    warn("Rayfield konnte nicht geladen werden, versuche alternative URL...")
    success, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
end

if not success or not Rayfield then
    game.StarterGui:SetCore("SendNotification", {
        Title = "Fehler";
        Text = "GUI konnte nicht geladen werden!";
        Duration = 5;
    })
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Movement + FPS Controls",
    LoadingTitle = "Lade GUI...",
    LoadingSubtitle = "by Assistant",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "MovementConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Movement", 4483362458)
local TargetTab = Window:CreateTab("Target", 4483362458)
local FPSTab = Window:CreateTab("FPS Shooter", 4483362458)

-- Variablen
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local WalkSpeedEnabled = false
local FlyEnabled = false
local WalkSpeedValue = 50
local FlySpeed = 50

local Flying = false
local BodyVelocity
local BodyGyro

-- Target System Variablen
local ClickToSelectEnabled = false
local SelectedTargetPlayer = nil
local TargetConnection = nil
local HighlightInstance = nil

-- Underground Spectate Variablen
local SpectateEnabled = false
local UndergroundDepth = 20
local SpectateConnection = nil

-- Fling Variablen
local FlingEnabled = false
local FlingPower = 500
local Flinging = false
local FlingBodyVelocity
local FlingBodyGyro

-- Headsit Variablen
local HeadsitEnabled = false
local Headsitting = false
local HeadsitConnection = nil
local HeadsitHeight = 2

-- Auto Headsit Variablen
_G.AutoHeadsitEnabled = false

-- ============================================
-- MOVEMENT TAB
-- ============================================

-- Walkspeed Section
local WalkSpeedSection = MainTab:CreateSection("Walkspeed Controls")

local WalkSpeedToggle = MainTab:CreateToggle({
    Name = "Walkspeed aktivieren",
    CurrentValue = false,
    Flag = "WalkSpeedToggle",
    Callback = function(Value)
        WalkSpeedEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Walkspeed aktiviert",
                Content = "Drücke 'C' um Speed zu ändern",
                Duration = 3,
                Image = 4483362458
            })
        else
            Humanoid.WalkSpeed = 16
            Rayfield:Notify({
                Title = "Walkspeed deaktiviert",
                Content = "Normale Geschwindigkeit wiederhergestellt",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

local WalkSpeedSlider = MainTab:CreateSlider({
    Name = "Walkspeed Wert",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 50,
    Flag = "WalkSpeedSlider",
    Callback = function(Value)
        WalkSpeedValue = Value
    end
})

-- Fly Section
local FlySection = MainTab:CreateSection("Fly Controls")

local FlyToggle = MainTab:CreateToggle({
    Name = "Fly aktivieren",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(Value)
        FlyEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Fly aktiviert",
                Content = "Drücke 'X' um zu fliegen",
                Duration = 3,
                Image = 4483362458
            })
        else
            if Flying then
                StopFlying()
            end
            Rayfield:Notify({
                Title = "Fly deaktiviert",
                Content = "Fly-Modus ausgeschaltet",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

local FlySpeedSlider = MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 1,
    CurrentValue = 50,
    Flag = "FlySpeedSlider",
    Callback = function(Value)
        FlySpeed = Value
    end
})

-- ============================================
-- TARGET TAB
-- ============================================

local TargetSelectionSection = TargetTab:CreateSection("Target Auswahl")

-- Click to Select Toggle
local ClickToSelectToggle = TargetTab:CreateToggle({
    Name = "Click to Select aktivieren",
    CurrentValue = false,
    Flag = "ClickToSelectToggle",
    Callback = function(Value)
        ClickToSelectEnabled = Value
        if Value then
            EnableClickToSelect()
            Rayfield:Notify({
                Title = "Click to Select aktiviert",
                Content = "Klicke auf einen Spieler um ihn auszuwählen",
                Duration = 3,
                Image = 4483362458
            })
        else
            DisableClickToSelect()
            Rayfield:Notify({
                Title = "Click to Select deaktiviert",
                Content = "Manuelle Auswahl wieder aktiv",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Funktion zum Finden eines Spielers basierend auf teilweisem Namen
local function FindPlayerByPartialName(partialName)
    if not partialName or partialName == "" then return nil end
    
    partialName = partialName:lower()
    local bestMatch = nil
    local shortestMatch = math.huge
    
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= Player then
            local playerNameLower = player.Name:lower()
            local displayNameLower = player.DisplayName:lower()
            
            if playerNameLower:sub(1, #partialName) == partialName then
                if #player.Name < shortestMatch then
                    bestMatch = player
                    shortestMatch = #player.Name
                end
            elseif displayNameLower:sub(1, #partialName) == partialName then
                if #player.DisplayName < shortestMatch then
                    bestMatch = player
                    shortestMatch = #player.DisplayName
                end
            elseif playerNameLower:find(partialName, 1, true) then
                if #player.Name < shortestMatch then
                    bestMatch = player
                    shortestMatch = #player.Name
                end
            elseif displayNameLower:find(partialName, 1, true) then
                if #player.DisplayName < shortestMatch then
                    bestMatch = player
                    shortestMatch = #player.DisplayName
                end
            end
        end
    end
    
    return bestMatch
end

-- Manueller Target Input
local TargetPlayerInput = TargetTab:CreateInput({
    Name = "Target Namen eingeben",
    PlaceholderText = "z.B. 'Alex' für 'Alexander123'",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local foundPlayer = FindPlayerByPartialName(Text)
        if foundPlayer then
            SetTargetPlayer(foundPlayer)
        else
            SelectedTargetPlayer = nil
            RemoveHighlight()
            if Text ~= "" then
                Rayfield:Notify({
                    Title = "Kein Spieler gefunden",
                    Content = "Versuche einen anderen Namen",
                    Duration = 3,
                    Image = 4483362458
                })
            end
        end
    end
})

-- Button um aktuellen Target zu löschen
local ClearTargetButton = TargetTab:CreateButton({
    Name = "Target löschen",
    Callback = function()
        SelectedTargetPlayer = nil
        RemoveHighlight()
        Rayfield:Notify({
            Title = "Target gelöscht",
            Content = "Kein Spieler mehr ausgewählt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Underground Spectate Section
local SpectateSection = TargetTab:CreateSection("Underground Spectate")

local DepthSlider = TargetTab:CreateSlider({
    Name = "Tiefe unter Spieler",
    Range = {5, 100},
    Increment = 1,
    CurrentValue = 20,
    Flag = "DepthSlider",
    Callback = function(Value)
        UndergroundDepth = Value
    end
})

local SpectateToggle = TargetTab:CreateToggle({
    Name = "Underground Spectate",
    CurrentValue = false,
    Flag = "SpectateToggle",
    Callback = function(Value)
        SpectateEnabled = Value
        if Value then
            if not SelectedTargetPlayer then
                SpectateEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Kein Target ausgewählt",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            local playerStillInGame = game.Players:FindFirstChild(SelectedTargetPlayer.Name)
            if not playerStillInGame then
                SelectedTargetPlayer = nil
                SpectateEnabled = false
                RemoveHighlight()
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Spieler ist nicht mehr im Spiel",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            if not SelectedTargetPlayer.Character then
                Rayfield:Notify({
                    Title = "Warte...",
                    Content = "Warte auf Character von " .. SelectedTargetPlayer.Name,
                    Duration = 2,
                    Image = 4483362458
                })
                SelectedTargetPlayer.CharacterAdded:Wait()
                wait(0.5)
            end
            
            if SelectedTargetPlayer.Character then
                StartUndergroundSpectate()
                Rayfield:Notify({
                    Title = "Spectate aktiviert",
                    Content = "Folge " .. SelectedTargetPlayer.Name .. " unterirdisch",
                    Duration = 3,
                    Image = 4483362458
                })
            else
                SpectateEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Character konnte nicht geladen werden",
                    Duration = 3,
                    Image = 4483362458
                })
            end
        else
            StopUndergroundSpectate()
            Rayfield:Notify({
                Title = "Spectate deaktiviert",
                Content = "Normale Position wiederhergestellt",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Headsit Section
local HeadsitSection = TargetTab:CreateSection("Headsit Controls")

local HeadsitHeightSlider = TargetTab:CreateSlider({
    Name = "Höhe über Kopf",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = 2,
    Flag = "HeadsitHeightSlider",
    Callback = function(Value)
        HeadsitHeight = Value
    end
})

local AutoHeadsitToggle = TargetTab:CreateToggle({
    Name = "Auto Headsit (nächste Person)",
    CurrentValue = false,
    Flag = "AutoHeadsitToggle",
    Callback = function(Value)
        _G.AutoHeadsitEnabled = Value
        if Value then
            Rayfield:Notify({
                Title = "Auto Headsit aktiviert",
                Content = "Drücke 'F' um zur nächsten Person zu springen",
                Duration = 3,
                Image = 4483362458
            })
        else
            Rayfield:Notify({
                Title = "Auto Headsit deaktiviert",
                Content = "Manuelle Auswahl wieder aktiv",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

local HeadsitToggle = TargetTab:CreateToggle({
    Name = "Headsit aktivieren",
    CurrentValue = false,
    Flag = "HeadsitToggle",
    Callback = function(Value)
        HeadsitEnabled = Value
        if Value then
            if not SelectedTargetPlayer then
                HeadsitEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Kein Target ausgewählt",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            local playerStillInGame = game.Players:FindFirstChild(SelectedTargetPlayer.Name)
            if not playerStillInGame then
                SelectedTargetPlayer = nil
                HeadsitEnabled = false
                RemoveHighlight()
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Spieler ist nicht mehr im Spiel",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            StartHeadsit()
            Rayfield:Notify({
                Title = "Headsit aktiviert",
                Content = "Sitzt auf Kopf von " .. SelectedTargetPlayer.Name,
                Duration = 3,
                Image = 4483362458
            })
        else
            if Headsitting then
                StopHeadsit()
            end
            Rayfield:Notify({
                Title = "Headsit deaktiviert",
                Content = "Headsit-Modus ausgeschaltet",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Fling Section
local FlingSection = TargetTab:CreateSection("Fling Controls")

local FlingPowerSlider = TargetTab:CreateSlider({
    Name = "Fling Power",
    Range = {100, 2000},
    Increment = 50,
    CurrentValue = 500,
    Flag = "FlingPowerSlider",
    Callback = function(Value)
        FlingPower = Value
    end
})

local FlingToggle = TargetTab:CreateToggle({
    Name = "Fling aktivieren",
    CurrentValue = false,
    Flag = "FlingToggle",
    Callback = function(Value)
        FlingEnabled = Value
        if Value then
            if not SelectedTargetPlayer then
                FlingEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Kein Target ausgewählt",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            local playerStillInGame = game.Players:FindFirstChild(SelectedTargetPlayer.Name)
            if not playerStillInGame then
                SelectedTargetPlayer = nil
                FlingEnabled = false
                RemoveHighlight()
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Spieler ist nicht mehr im Spiel",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            StartFlinging()
            Rayfield:Notify({
                Title = "Fling aktiviert",
                Content = "Fling auf " .. SelectedTargetPlayer.Name,
                Duration = 3,
                Image = 4483362458
            })
        else
            if Flinging then
                StopFlinging()
            end
            Rayfield:Notify({
                Title = "Fling deaktiviert",
                Content = "Fling-Modus ausgeschaltet",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- ============================================
-- FPS SHOOTER TAB
-- ============================================

local AimbotSection = FPSTab:CreateSection("Aimbot Settings")

-- Aimbot Toggle
local AimbotToggle = FPSTab:CreateToggle({
    Name = "Aimbot aktivieren",
    CurrentValue = true,
    Flag = "AimbotToggle",
    Callback = function(Value)
        _G.AimbotEnabled = Value
        Rayfield:Notify({
            Title = Value and "Aimbot aktiviert" or "Aimbot deaktiviert",
            Content = Value and "Aimbot ist jetzt aktiv" or "Aimbot ist jetzt inaktiv",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Team Check Toggle
local TeamCheckToggle = FPSTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "TeamCheckToggle",
    Callback = function(Value)
        _G.TeamCheck = Value
    end
})

-- Aim Part Dropdown
local AimPartDropdown = FPSTab:CreateDropdown({
    Name = "Ziel Körperteil",
    Options = {"Head", "HumanoidRootPart", "Torso"},
    CurrentOption = "Head",
    Flag = "AimPartDropdown",
    Callback = function(Option)
        _G.AimPart = Option
        Rayfield:Notify({
            Title = "Aim Part geändert",
            Content = "Zielt jetzt auf: " .. Option,
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Sensitivity Slider
local SensitivitySlider = FPSTab:CreateSlider({
    Name = "Sensitivity (1 = Snap)",
    Range = {0.1, 1},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "SensitivitySlider",
    Callback = function(Value)
        _G.Sensitivity = Value
    end
})

-- ESP Section
local ESPSection = FPSTab:CreateSection("ESP Settings")

local ESPToggle = FPSTab:CreateToggle({
    Name = "ESP aktivieren",
    CurrentValue = true,
    Flag = "ESPToggle",
    Callback = function(Value)
        _G.ESPEnabled = Value
    end
})

local ESPRainbowToggle = FPSTab:CreateToggle({
    Name = "ESP Rainbow",
    CurrentValue = true,
    Flag = "ESPRainbowToggle",
    Callback = function(Value)
        _G.ESPRainbow = Value
    end
})

local ESPColorDropdown = FPSTab:CreateDropdown({
    Name = "ESP Farbe",
    Options = {"white", "red", "green", "blue", "yellow", "purple"},
    CurrentOption = "green",
    Flag = "ESPColorDropdown",
    Callback = function(Option)
        _G.ESPColorName = Option
    end
})

local ESPFilledToggle = FPSTab:CreateToggle({
    Name = "ESP Gefüllt",
    CurrentValue = false,
    Flag = "ESPFilledToggle",
    Callback = function(Value)
        _G.ESPFilled = Value
    end
})

local ESPThicknessSlider = FPSTab:CreateSlider({
    Name = "ESP Dicke",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = 1,
    Flag = "ESPThicknessSlider",
    Callback = function(Value)
        _G.ESPThickness = Value
    end
})

local ESPTransparencySlider = FPSTab:CreateSlider({
    Name = "ESP Transparenz",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "ESPTransparencySlider",
    Callback = function(Value)
        _G.ESPTransparency = Value
    end
})

-- FOV Section
local FOVSection = FPSTab:CreateSection("FOV Settings")

local FOVToggle = FPSTab:CreateToggle({
    Name = "FOV Circle aktivieren",
    CurrentValue = true,
    Flag = "FOVToggle",
    Callback = function(Value)
        _G.FOVEnabled = Value
    end
})

local FOVRainbowToggle = FPSTab:CreateToggle({
    Name = "FOV Rainbow",
    CurrentValue = true,
    Flag = "FOVRainbowToggle",
    Callback = function(Value)
        _G.FOVRainbow = Value
    end
})

local FOVRadiusSlider = FPSTab:CreateSlider({
    Name = "FOV Radius",
    Range = {20, 300},
    Increment = 5,
    CurrentValue = 60,
    Flag = "FOVRadiusSlider",
    Callback = function(Value)
        _G.FOVRadius = Value
    end
})

local FOVColorDropdown = FPSTab:CreateDropdown({
    Name = "FOV Farbe",
    Options = {"white", "red", "green", "blue", "yellow", "purple"},
    CurrentOption = "white",
    Flag = "FOVColorDropdown",
    Callback = function(Option)
        _G.FOVColorName = Option
    end
})

local FOVFilledToggle = FPSTab:CreateToggle({
    Name = "FOV Gefüllt",
    CurrentValue = false,
    Flag = "FOVFilledToggle",
    Callback = function(Value)
        _G.FOVFilled = Value
    end
})

local FOVTransparencySlider = FPSTab:CreateSlider({
    Name = "FOV Transparenz",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0.7,
    Flag = "FOVTransparencySlider",
    Callback = function(Value)
        _G.FOVTransparency = Value
    end
})

local FOVThicknessSlider = FPSTab:CreateSlider({
    Name = "FOV Dicke",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = 1,
    Flag = "FOVThicknessSlider",
    Callback = function(Value)
        _G.FOVThickness = Value
    end
})

-- Toggle Key Section
local ToggleSection = FPSTab:CreateSection("Toggle Settings")

local ToggleKeyInput = FPSTab:CreateInput({
    Name = "Toggle Key (Enum.KeyCode)",
    PlaceholderText = "z.B. RightShift",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text ~= "" then
            _G.ToggleKey = Text
            Rayfield:Notify({
                Title = "Toggle Key geändert",
                Content = "Neue Taste: " .. Text,
                Duration = 2,
                Image = 4483362458
            })
        end
    end
})

-- Script Enabled Toggle
local ScriptEnabledToggle = FPSTab:CreateToggle({
    Name = "Script aktiviert",
    CurrentValue = true,
    Flag = "ScriptEnabledToggle",
    Callback = function(Value)
        _G.ScriptEnabled = Value
    end
})

-- Load Aimbot Button
local LoadAimbotButton = FPSTab:CreateButton({
    Name = "Aimbot Script laden",
    Callback = function()
        Rayfield:Notify({
            Title = "Lade Aimbot...",
            Content = "Script wird geladen",
            Duration = 2,
            Image = 4483362458
        })
        
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/randomuser832/Scripts25/refs/heads/main/UniversalAimbotLoadString"))()
        end)
        
        wait(0.5)
        Rayfield:Notify({
            Title = "Aimbot geladen",
            Content = "Script erfolgreich geladen!",
            Duration = 3,
            Image = 4483362458
        })
    end
})

-- ============================================
-- TARGET SYSTEM FUNKTIONEN
-- ============================================

function SetTargetPlayer(player)
    SelectedTargetPlayer = player
    UpdateHighlight()
    Rayfield:Notify({
        Title = "Target ausgewählt",
        Content = "Target: " .. player.Name,
        Duration = 3,
        Image = 4483362458
    })
end

function UpdateHighlight()
    RemoveHighlight()
    
    if SelectedTargetPlayer and SelectedTargetPlayer.Character then
        local rootPart = SelectedTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            HighlightInstance = Instance.new("Highlight")
            HighlightInstance.Adornee = SelectedTargetPlayer.Character
            HighlightInstance.FillColor = Color3.fromRGB(255, 0, 0)
            HighlightInstance.OutlineColor = Color3.fromRGB(255, 255, 255)
            HighlightInstance.FillTransparency = 0.5
            HighlightInstance.OutlineTransparency = 0
            HighlightInstance.Parent = SelectedTargetPlayer.Character
        end
    end
end

function RemoveHighlight()
    if HighlightInstance then
        HighlightInstance:Destroy()
        HighlightInstance = nil
    end
end

function EnableClickToSelect()
    local Mouse = Player:GetMouse()
    
    TargetConnection = Mouse.Button1Down:Connect(function()
        if not ClickToSelectEnabled then return end
        
        local target = Mouse.Target
        if target then
            local clickedPlayer = game.Players:GetPlayerFromCharacter(target.Parent)
            
            if clickedPlayer and clickedPlayer ~= Player then
                SetTargetPlayer(clickedPlayer)
            end
        end
    end)
end

function DisableClickToSelect()
    if TargetConnection then
        TargetConnection:Disconnect()
        TargetConnection = nil
    end
end

-- ============================================
-- MOVEMENT FUNKTIONEN
-- ============================================

-- Fly Funktionen
function StartFlying()
    Flying = true
    
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BodyVelocity.Parent = HumanoidRootPart
    
    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.P = 9e4
    BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    BodyGyro.CFrame = HumanoidRootPart.CFrame
    BodyGyro.Parent = HumanoidRootPart
    
    spawn(function()
        while Flying and FlyEnabled do
            local Camera = workspace.CurrentCamera
            local MoveDirection = Vector3.new(0, 0, 0)
            
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
                MoveDirection = MoveDirection + Camera.CFrame.LookVector
            end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
                MoveDirection = MoveDirection - Camera.CFrame.LookVector
            end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
                MoveDirection = MoveDirection - Camera.CFrame.RightVector
            end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
                MoveDirection = MoveDirection + Camera.CFrame.RightVector
            end
            
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
                MoveDirection = MoveDirection + Vector3.new(0, 1, 0)
            end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
                MoveDirection = MoveDirection - Vector3.new(0, 1, 0)
            end
            
            if BodyVelocity then
                BodyVelocity.Velocity = MoveDirection * FlySpeed
            end
            if BodyGyro then
                BodyGyro.CFrame = Camera.CFrame
            end
            
            wait()
        end
    end)
end

function StopFlying()
    Flying = false
    if BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        BodyGyro:Destroy()
        BodyGyro = nil
    end
end

-- ============================================
-- TARGET FUNKTIONEN
-- ============================================

-- Funktion um nächsten Spieler zu finden
function GetNearestPlayer()
    local nearestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= Player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = player.Character.HumanoidRootPart
            local distance = (HumanoidRootPart.Position - targetRoot.Position).Magnitude
            
            if distance < shortestDistance then
                shortestDistance = distance
                nearestPlayer = player
            end
        end
    end
    
    return nearestPlayer
end

-- Auto Headsit zur nächsten Person
function AutoHeadsitToNearest()
    local nearestPlayer = GetNearestPlayer()
    
    if nearestPlayer then
        -- Altes Headsit stoppen falls aktiv
        if Headsitting then
            StopHeadsit()
        end
        
        -- Neuen Target setzen
        SetTargetPlayer(nearestPlayer)
        
        -- Headsit aktivieren
        HeadsitEnabled = true
        StartHeadsit()
        
        Rayfield:Notify({
            Title = "Auto Headsit",
            Content = "Jetzt auf: " .. nearestPlayer.Name,
            Duration = 2,
            Image = 4483362458
        })
    else
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Keine Spieler in der Nähe gefunden",
            Duration = 3,
            Image = 4483362458
        })
    end
end

-- Underground Spectate Funktionen
function StartUndergroundSpectate()
    if not SelectedTargetPlayer then 
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Kein Target ausgewählt",
            Duration = 3,
            Image = 4483362458
        })
        return 
    end
    
    if not SelectedTargetPlayer.Character then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Target hat keinen Character",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    SpectateConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if SpectateEnabled and SelectedTargetPlayer and SelectedTargetPlayer.Character then
            local targetRoot = SelectedTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and HumanoidRootPart then
                local targetPos = targetRoot.Position
                HumanoidRootPart.CFrame = CFrame.new(
                    targetPos.X,
                    targetPos.Y - UndergroundDepth,
                    targetPos.Z
                )
                
                local Camera = workspace.CurrentCamera
                Camera.CameraSubject = SelectedTargetPlayer.Character.Humanoid
            else
                if not targetRoot then
                    StopUndergroundSpectate()
                    SpectateEnabled = false
                    Rayfield:Notify({
                        Title = "Spectate beendet",
                        Content = SelectedTargetPlayer.Name .. " hat keinen Character mehr",
                        Duration = 3,
                        Image = 4483362458
                    })
                end
            end
        end
    end)
end

function StopUndergroundSpectate()
    if SpectateConnection then
        SpectateConnection:Disconnect()
        SpectateConnection = nil
    end
    
    local Camera = workspace.CurrentCamera
    Camera.CameraSubject = Humanoid
end

-- Headsit Funktionen
function StartHeadsit()
    if not SelectedTargetPlayer then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Kein Target ausgewählt",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    if not SelectedTargetPlayer.Character then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Target hat keinen Character",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    Headsitting = true
    
    Humanoid.Sit = true
    
    HeadsitConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if HeadsitEnabled and SelectedTargetPlayer and SelectedTargetPlayer.Character then
            local targetHead = SelectedTargetPlayer.Character:FindFirstChild("Head")
            local targetRoot = SelectedTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetHead and targetRoot and HumanoidRootPart then
                local targetPos = targetHead.Position
                
                local targetRotation = targetRoot.CFrame - targetRoot.Position
                
                HumanoidRootPart.CFrame = CFrame.new(
                    targetPos.X,
                    targetPos.Y + HeadsitHeight,
                    targetPos.Z
                ) * targetRotation
                
                if not Humanoid.Sit then
                    Humanoid.Sit = true
                end
            else
                if not targetHead then
                    StopHeadsit()
                    HeadsitEnabled = false
                    Rayfield:Notify({
                        Title = "Headsit beendet",
                        Content = SelectedTargetPlayer.Name .. " hat keinen Character mehr",
                        Duration = 3,
                        Image = 4483362458
                    })
                end
            end
        end
    end)
end

function StopHeadsit()
    Headsitting = false
    
    if HeadsitConnection then
        HeadsitConnection:Disconnect()
        HeadsitConnection = nil
    end
    
    if Humanoid then
        Humanoid.Sit = false
    end
end

-- Fling Funktionen
function StartFlinging()
    if not SelectedTargetPlayer then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Kein Target ausgewählt",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    if not SelectedTargetPlayer.Character then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Target hat keinen Character",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    Flinging = true
    
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
            part.Massless = false
        end
    end
    
    HumanoidRootPart.CanCollide = true
    HumanoidRootPart.Massless = false
    
    FlingBodyVelocity = Instance.new("BodyVelocity")
    FlingBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlingBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlingBodyVelocity.Parent = HumanoidRootPart
    
    FlingBodyGyro = Instance.new("BodyGyro")
    FlingBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlingBodyGyro.P = 3000
    FlingBodyGyro.Parent = HumanoidRootPart
    
    spawn(function()
        while Flinging and FlingEnabled and SelectedTargetPlayer do
            if not SelectedTargetPlayer.Character then
                StopFlinging()
                FlingEnabled = false
                Rayfield:Notify({
                    Title = "Fling beendet",
                    Content = SelectedTargetPlayer.Name .. " hat keinen Character mehr",
                    Duration = 3,
                    Image = 4483362458
                })
                break
            end
            
            local targetRoot = SelectedTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if targetRoot then
                HumanoidRootPart.CFrame = targetRoot.CFrame
                
                HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(
                    math.rad(FlingPower / 5),
                    math.rad(FlingPower / 5), 
                    math.rad(FlingPower / 5)
                )
                
                FlingBodyVelocity.Velocity = Vector3.new(
                    math.random(-FlingPower * 2, FlingPower * 2),
                    math.random(-FlingPower * 2, FlingPower * 2),
                    math.random(-FlingPower * 2, FlingPower * 2)
                )
                
                FlingBodyGyro.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(
                    math.rad(math.random(-180, 180)),
                    math.rad(math.random(-180, 180)),
                    math.rad(math.random(-180, 180))
                )
            else
                StopFlinging()
                FlingEnabled = false
                Rayfield:Notify({
                    Title = "Fling beendet",
                    Content = "Target verloren",
                    Duration = 3,
                    Image = 4483362458
                })
                break
            end
            
            wait()
        end
    end)
end

function StopFlinging()
    Flinging = false
    
    if FlingBodyVelocity then
        FlingBodyVelocity:Destroy()
        FlingBodyVelocity = nil
    end
    
    if FlingBodyGyro then
        FlingBodyGyro:Destroy()
        FlingBodyGyro = nil
    end
    
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
    
    HumanoidRootPart.CanCollide = false
    
    if HumanoidRootPart:FindFirstChild("BodyVelocity") then
        HumanoidRootPart:FindFirstChild("BodyVelocity"):Destroy()
    end
end

-- ============================================
-- EVENT HANDLER
-- ============================================

-- Keybind Handler
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- C für Walkspeed
    if input.KeyCode == Enum.KeyCode.C and WalkSpeedEnabled then
        if Humanoid.WalkSpeed == 16 then
            Humanoid.WalkSpeed = WalkSpeedValue
            Rayfield:Notify({
                Title = "Walkspeed aktiviert",
                Content = "Speed: " .. WalkSpeedValue,
                Duration = 2,
                Image = 4483362458
            })
        else
            Humanoid.WalkSpeed = 16
            Rayfield:Notify({
                Title = "Walkspeed deaktiviert",
                Content = "Normale Speed",
                Duration = 2,
                Image = 4483362458
            })
        end
    end
    
    -- X für Fly
    if input.KeyCode == Enum.KeyCode.X and FlyEnabled then
        if not Flying then
            StartFlying()
            Rayfield:Notify({
                Title = "Fliegen aktiviert",
                Content = "WASD zum Steuern, Space/Shift für Hoch/Runter",
                Duration = 3,
                Image = 4483362458
            })
        else
            StopFlying()
            Rayfield:Notify({
                Title = "Fliegen deaktiviert",
                Content = "Zurück zum normalen Modus",
                Duration = 2,
                Image = 4483362458
            })
        end
    end
    
    -- F für Auto Headsit
    if input.KeyCode == Enum.KeyCode.F and _G.AutoHeadsitEnabled then
        AutoHeadsitToNearest()
    end
end)

-- Character Respawn Handler
Player.CharacterAdded:Connect(function(NewCharacter)
    Character = NewCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    Flying = false
    Flinging = false
    Headsitting = false
    BodyVelocity = nil
    BodyGyro = nil
    FlingBodyVelocity = nil
    FlingBodyGyro = nil
    
    if SpectateEnabled then
        StopUndergroundSpectate()
        SpectateEnabled = false
    end
    
    if HeadsitEnabled then
        StopHeadsit()
        HeadsitEnabled = false
    end
end)

-- Target Character Update Handler
game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        if player == SelectedTargetPlayer then
            UpdateHighlight()
        end
    end)
end)

-- Bestehende Spieler überwachen
for _, player in pairs(game.Players:GetPlayers()) do
    player.CharacterAdded:Connect(function(character)
        if player == SelectedTargetPlayer then
            wait(0.1)
            UpdateHighlight()
        end
    end)
end

-- Info Notification beim Start
Rayfield:Notify({
    Title = "GUI geladen!",
    Content = "Alle Features bereit. Viel Spaß!",
    Duration = 5,
    Image = 4483362458
})

-- ============================================
-- EMOTES TAB
-- ============================================

local EmotesTab = Window:CreateTab("Emotes", 4483362458)

-- Beliebte Emotes Section
local PopularEmotesSection = EmotesTab:CreateSection("Beliebte Emotes")

-- Emote Variablen
local CurrentEmoteTrack = nil

-- Funktion zum Abspielen von Emotes
local function PlayEmote(emoteId)
    if not Character or not Humanoid then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Character nicht gefunden",
            Duration = 2,
            Image = 4483362458
        })
        return
    end
    
    -- Stoppe aktuelles Emote falls vorhanden
    if CurrentEmoteTrack then
        CurrentEmoteTrack:Stop()
        CurrentEmoteTrack:Destroy()
        CurrentEmoteTrack = nil
    end
    
    -- Erstelle neue Animation
    local Animation = Instance.new("Animation")
    Animation.AnimationId = "rbxassetid://" .. emoteId
    
    local success, result = pcall(function()
        CurrentEmoteTrack = Humanoid:LoadAnimation(Animation)
        CurrentEmoteTrack:Play()
    end)
    
    if not success then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Emote konnte nicht geladen werden",
            Duration = 2,
            Image = 4483362458
        })
    end
end

-- Stopp Button
local StopEmoteButton = EmotesTab:CreateButton({
    Name = "Emote stoppen",
    Callback = function()
        if CurrentEmoteTrack then
            CurrentEmoteTrack:Stop()
            CurrentEmoteTrack:Destroy()
            CurrentEmoteTrack = nil
            Rayfield:Notify({
                Title = "Emote gestoppt",
                Content = "Animation wurde beendet",
                Duration = 2,
                Image = 4483362458
            })
        end
    end
})

-- Beliebte Emote Buttons
local DanceButton = EmotesTab:CreateButton({
    Name = "🕺 Dance",
    Callback = function()
        PlayEmote("507770239")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Dance wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local Dance2Button = EmotesTab:CreateButton({
    Name = "💃 Dance 2",
    Callback = function()
        PlayEmote("507771019")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Dance 2 wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local Dance3Button = EmotesTab:CreateButton({
    Name = "🎵 Dance 3",
    Callback = function()
        PlayEmote("507771955")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Dance 3 wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local WaveButton = EmotesTab:CreateButton({
    Name = "👋 Wave",
    Callback = function()
        PlayEmote("507770239")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Wave wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local PointButton = EmotesTab:CreateButton({
    Name = "👉 Point",
    Callback = function()
        PlayEmote("507770453")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Point wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local CheerButton = EmotesTab:CreateButton({
    Name = "🎉 Cheer",
    Callback = function()
        PlayEmote("507770677")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Cheer wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local LaughButton = EmotesTab:CreateButton({
    Name = "😂 Laugh",
    Callback = function()
        PlayEmote("507770818")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Laugh wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Custom Emote Section
local CustomEmoteSection = EmotesTab:CreateSection("Eigenes Emote")

local CustomEmoteInput = EmotesTab:CreateInput({
    Name = "Emote ID eingeben",
    PlaceholderText = "z.B. 507770239",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        -- Wird beim Button verwendet
    end
})

local PlayCustomButton = EmotesTab:CreateButton({
    Name = "Custom Emote abspielen",
    Callback = function()
        local emoteId = CustomEmoteInput.CurrentValue or ""
        
        if emoteId == "" then
            Rayfield:Notify({
                Title = "Fehler",
                Content = "Bitte gib eine Emote ID ein",
                Duration = 2,
                Image = 4483362458
            })
            return
        end
        
        -- Entferne "rbxassetid://" falls vorhanden
        emoteId = emoteId:gsub("rbxassetid://", "")
        
        PlayEmote(emoteId)
        Rayfield:Notify({
            Title = "Custom Emote",
            Content = "ID: " .. emoteId,
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Loop Emote Section
local LoopSection = EmotesTab:CreateSection("Loop Einstellungen")

local LoopEmoteToggle = EmotesTab:CreateToggle({
    Name = "Emote in Schleife",
    CurrentValue = false,
    Flag = "LoopEmoteToggle",
    Callback = function(Value)
        if CurrentEmoteTrack then
            CurrentEmoteTrack.Looped = Value
            Rayfield:Notify({
                Title = Value and "Loop aktiviert" or "Loop deaktiviert",
                Content = Value and "Emote wird wiederholt" or "Emote läuft einmal",
                Duration = 2,
                Image = 4483362458
            })
        end
    end
})

-- Speed Control
local EmoteSpeedSlider = EmotesTab:CreateSlider({
    Name = "Emote Geschwindigkeit",
    Range = {0.1, 3},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "EmoteSpeedSlider",
    Callback = function(Value)
        if CurrentEmoteTrack then
            CurrentEmoteTrack:AdjustSpeed(Value)
        end
    end
})

-- Weitere beliebte Emotes Section
local MoreEmotesSection = EmotesTab:CreateSection("Weitere Emotes")

local SaluteButton = EmotesTab:CreateButton({
    Name = "🫡 Salute",
    Callback = function()
        PlayEmote("3360686498")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Salute wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local TiltButton = EmotesTab:CreateButton({
    Name = "🤔 Tilt",
    Callback = function()
        PlayEmote("3360692915")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Tilt wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local ShrugsButton = EmotesTab:CreateButton({
    Name = "🤷 Shrug",
    Callback = function()
        PlayEmote("3334538554")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Shrug wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

local StadiumButton = EmotesTab:CreateButton({
    Name = "🏟️ Stadium",
    Callback = function()
        PlayEmote("3360686629")
        Rayfield:Notify({
            Title = "Emote",
            Content = "Stadium wird abgespielt",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- ============================================
-- ANIMATIONS TAB
-- ============================================

local AnimationsTab = Window:CreateTab("Animations", 4483362458)

-- Animation Variablen
local OriginalAnimations = {}

-- Funktion zum Speichern der Original-Animationen
local function SaveOriginalAnimations()
    if not Character then return end
    
    local Animate = Character:FindFirstChild("Animate")
    if not Animate then return end
    
    -- Speichere Run Animation
    local run = Animate:FindFirstChild("run")
    if run then
        local runAnim = run:FindFirstChildOfClass("Animation")
        if runAnim then
            OriginalAnimations.Run = runAnim.AnimationId
        end
    end
    
    -- Speichere Walk Animation
    local walk = Animate:FindFirstChild("walk")
    if walk then
        local walkAnim = walk:FindFirstChildOfClass("Animation")
        if walkAnim then
            OriginalAnimations.Walk = walkAnim.AnimationId
        end
    end
    
    -- Speichere Jump Animation
    local jump = Animate:FindFirstChild("jump")
    if jump then
        local jumpAnim = jump:FindFirstChildOfClass("Animation")
        if jumpAnim then
            OriginalAnimations.Jump = jumpAnim.AnimationId
        end
    end
    
    -- Speichere Fall Animation
    local fall = Animate:FindFirstChild("fall")
    if fall then
        local fallAnim = fall:FindFirstChildOfClass("Animation")
        if fallAnim then
            OriginalAnimations.Fall = fallAnim.AnimationId
        end
    end
    
    -- Speichere Idle Animation
    local idle = Animate:FindFirstChild("idle")
    if idle then
        local idleAnim = idle:FindFirstChild("Animation1")
        if idleAnim then
            OriginalAnimations.Idle = idleAnim.AnimationId
        end
    end
    
    -- Speichere Climb Animation
    local climb = Animate:FindFirstChild("climb")
    if climb then
        local climbAnim = climb:FindFirstChildOfClass("Animation")
        if climbAnim then
            OriginalAnimations.Climb = climbAnim.AnimationId
        end
    end
end

-- Funktion zum Ändern einer Animation
local function ChangeAnimation(animType, animId)
    if not Character then return false end
    
    local Animate = Character:FindFirstChild("Animate")
    if not Animate then return false end
    
    local animFolder = Animate:FindFirstChild(animType:lower())
    if not animFolder then return false end
    
    -- Für Idle gibt es mehrere Animationen
    if animType == "Idle" then
        local idleAnim = animFolder:FindFirstChild("Animation1")
        if idleAnim then
            idleAnim.AnimationId = "rbxassetid://" .. animId
            return true
        end
    else
        local anim = animFolder:FindFirstChildOfClass("Animation")
        if anim then
            anim.AnimationId = "rbxassetid://" .. animId
            return true
        end
    end
    
    return false
end

-- Funktion zum Zurücksetzen aller Animationen
local function ResetAllAnimations()
    if not Character then return end
    
    local Animate = Character:FindFirstChild("Animate")
    if not Animate then return end
    
    for animType, originalId in pairs(OriginalAnimations) do
        if originalId then
            ChangeAnimation(animType, originalId:gsub("rbxassetid://", ""))
        end
    end
    
    -- Character neu laden für sofortige Wirkung
    Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
end

-- Speichere Original-Animationen beim Start
SaveOriginalAnimations()

-- ============================================
-- ANIMATIONS SECTION
-- ============================================

local AnimSection = AnimationsTab:CreateSection("Animationspakete")

local PresetDropdown = AnimationsTab:CreateDropdown({
    Name = "Animations-Paket wählen",
    Options = {
        "Standard",
        "Adidas",
        "Adidas Classic",
        "Zombie",
        "Zombie Classic",
        "Robot",
        "Ninja",
        "Knight",
        "Superhero",
        "Elder",
        "Pirate",
        "Astronaut",
        "Vampire",
        "Werewolf",
        "Cartoony",
        "Levitation",
        "Mage",
        "Rthro",
        "Stylish",
        "Confident",
        "Popstar",
        "Cowboy",
        "Ghost"
    },
    CurrentOption = "Standard",
    Flag = "AnimPresetDropdown",
    Callback = function(Option)
        local presets = {
            Adidas = {
                Run = "1100960689",
                Walk = "1100960689",
                Jump = "1100961031",
                Fall = "1100959726",
                Idle = "1100960036",
                Climb = "1100960489"
            },
            ["Adidas Classic"] = {
                Run = "1100960689",
                Walk = "1100961031",
                Jump = "1100961031",
                Fall = "1100959726",
                Idle = "1100960036",
                Climb = "1100960489"
            },
            Zombie = {
                Run = "616163682",
                Walk = "616168032",
                Jump = "616161997",
                Fall = "616157476",
                Idle = "616158929",
                Climb = "616156119"
            },
            ["Zombie Classic"] = {
                Run = "616163682",
                Walk = "616163682",
                Jump = "616161997",
                Fall = "616157476",
                Idle = "616158929",
                Climb = "616156119"
            },
            Robot = {
                Run = "616091570",
                Walk = "616095330",
                Jump = "616090535",
                Fall = "616087089",
                Idle = "616088211",
                Climb = "616086039"
            },
            Ninja = {
                Run = "656118852",
                Walk = "656121766",
                Jump = "656117878",
                Fall = "656115606",
                Idle = "656117400",
                Climb = "656114359"
            },
            Knight = {
                Run = "657564596",
                Walk = "657552124",
                Jump = "658409194",
                Fall = "657600338",
                Idle = "657595757",
                Climb = "658360781"
            },
            Superhero = {
                Run = "616117076",
                Walk = "616122287",
                Jump = "616115533",
                Fall = "616108001",
                Idle = "616111295",
                Climb = "616104706"
            },
            Elder = {
                Run = "845386501",
                Walk = "845403856",
                Jump = "845398858",
                Fall = "845400429",
                Idle = "845397899",
                Climb = "845392038"
            },
            Pirate = {
                Run = "750783738",
                Walk = "750785693",
                Jump = "750782230",
                Fall = "750780242",
                Idle = "750781874",
                Climb = "750779899"
            },
            Astronaut = {
                Run = "891621366",
                Walk = "891636393",
                Jump = "891627522",
                Fall = "891617961",
                Idle = "891621366",
                Climb = "891609353"
            },
            Vampire = {
                Run = "1083216690",
                Walk = "1083178339",
                Jump = "1083218792",
                Fall = "1083189019",
                Idle = "1083195517",
                Climb = "1083182000"
            },
            Werewolf = {
                Run = "1083216690",
                Walk = "1083178339",
                Jump = "1083218792",
                Fall = "1083189019",
                Idle = "1083195517",
                Climb = "1083182000"
            },
            Cartoony = {
                Run = "742638842",
                Walk = "742640026",
                Jump = "742637942",
                Fall = "742637151",
                Idle = "742637544",
                Climb = "742636889"
            },
            Levitation = {
                Run = "616013216",
                Walk = "616013216",
                Jump = "616008936",
                Fall = "616005863",
                Idle = "616006778",
                Climb = "616003713"
            },
            Mage = {
                Run = "707861613",
                Walk = "707897309",
                Jump = "707853694",
                Fall = "707829716",
                Idle = "707742142",
                Climb = "707826056"
            },
            Rthro = {
                Run = "2510198475",
                Walk = "2510202577",
                Jump = "2510197830",
                Fall = "2510195892",
                Idle = "2510196951",
                Climb = "2510192778"
            },
            Stylish = {
                Run = "616136790",
                Walk = "616146177",
                Jump = "616139451",
                Fall = "616134815",
                Idle = "616136790",
                Climb = "616133594"
            },
            Confident = {
                Run = "1069977950",
                Walk = "1070017263",
                Jump = "1069984524",
                Fall = "1069973677",
                Idle = "1069977950",
                Climb = "1069946257"
            },
            Popstar = {
                Run = "910025107",
                Walk = "910034870",
                Jump = "910016857",
                Fall = "910009987",
                Idle = "910004836",
                Climb = "910028158"
            },
            Cowboy = {
                Run = "1014390418",
                Walk = "1014398616",
                Jump = "1014394726",
                Fall = "1014384571",
                Idle = "1014390418",
                Climb = "1014380606"
            },
            Ghost = {
                Run = "616005863",
                Walk = "616013216",
                Jump = "616008936",
                Fall = "616005863",
                Idle = "616006778",
                Climb = "616003713"
            }
        }
        
        if Option == "Standard" then
            ResetAllAnimations()
            Rayfield:Notify({
                Title = "Animationen zurückgesetzt",
                Content = "Standard-Animationen wiederhergestellt",
                Duration = 3,
                Image = 4483362458
            })
        else
            local preset = presets[Option]
            if preset then
                for animType, animId in pairs(preset) do
                    ChangeAnimation(animType, animId)
                end
                
                -- Character neu laden
                Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                
                Rayfield:Notify({
                    Title = "Animationspaket geladen",
                    Content = Option .. " Animationen aktiviert",
                    Duration = 3,
                    Image = 4483362458
                })
            end
        end
    end
})

-- ============================================
-- QUICK APPLY BUTTONS
-- ============================================

local QuickSection = AnimationsTab:CreateSection("Schnellauswahl")

local AdidasButton = AnimationsTab:CreateButton({
    Name = "👟 Adidas",
    Callback = function()
        PresetDropdown:Set("Adidas")
    end
})

local AdidasClassicButton = AnimationsTab:CreateButton({
    Name = "👟 Adidas Classic",
    Callback = function()
        PresetDropdown:Set("Adidas Classic")
    end
})

local ZombieButton = AnimationsTab:CreateButton({
    Name = "🧟 Zombie",
    Callback = function()
        PresetDropdown:Set("Zombie")
    end
})

local ZombieClassicButton = AnimationsTab:CreateButton({
    Name = "🧟 Zombie Classic",
    Callback = function()
        PresetDropdown:Set("Zombie Classic")
    end
})

local MageButton = AnimationsTab:CreateButton({
    Name = "🧙 Mage",
    Callback = function()
        PresetDropdown:Set("Mage")
    end
})

local NinjaButton = AnimationsTab:CreateButton({
    Name = "🥷 Ninja",
    Callback = function()
        PresetDropdown:Set("Ninja")
    end
})

local SuperheroButton = AnimationsTab:CreateButton({
    Name = "🦸 Superhero",
    Callback = function()
        PresetDropdown:Set("Superhero")
    end
})

local RobotButton = AnimationsTab:CreateButton({
    Name = "🤖 Robot",
    Callback = function()
        PresetDropdown:Set("Robot")
    end
})

-- ============================================
-- RESET SECTION
-- ============================================

local ResetSection = AnimationsTab:CreateSection("Zurücksetzen")

local ResetAnimationsButton = AnimationsTab:CreateButton({
    Name = "🔄 Standard wiederherstellen",
    Callback = function()
        ResetAllAnimations()
        PresetDropdown:Set("Standard")
        Rayfield:Notify({
            Title = "Animationen zurückgesetzt",
            Content = "Alle Original-Animationen wiederhergestellt",
            Duration = 3,
            Image = 4483362458
        })
    end
})






























-- ============================================
-- TROLL TAB
-- ============================================

local TrollTab = Window:CreateTab("Troll", 4483362458)

-- Bang Variablen
local BangEnabled = false
local Banging = false
local BangSpeed = 1
local BangDistance = 2
local BangMode = "Body" -- "Body", "Head", "Face"

-- ============================================
-- BANG SECTION
-- ============================================

local BangSection = TrollTab:CreateSection("Bang Controls")

local BangModeDropdown = TrollTab:CreateDropdown({
    Name = "Bang Position",
    Options = {"Body (Körper)", "Head (Kopf)", "Face (Gesicht)"},
    CurrentOption = "Body (Körper)",
    Flag = "BangModeDropdown",
    Callback = function(Option)
        if Option == "Body (Körper)" then
            BangMode = "Body"
        elseif Option == "Head (Kopf)" then
            BangMode = "Head"
        elseif Option == "Face (Gesicht)" then
            BangMode = "Face"
        end
        
        Rayfield:Notify({
            Title = "Bang Modus geändert",
            Content = Option,
            Duration = 2,
            Image = 4483362458
        })
    end
})

local BangSpeedSlider = TrollTab:CreateSlider({
    Name = "Bang Geschwindigkeit",
    Range = {0.3, 3},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "BangSpeedSlider",
    Callback = function(Value)
        BangSpeed = Value
    end
})

local BangDistanceSlider = TrollTab:CreateSlider({
    Name = "Bang Distanz",
    Range = {0.5, 5},
    Increment = 0.1,
    CurrentValue = 2,
    Flag = "BangDistanceSlider",
    Callback = function(Value)
        BangDistance = Value
    end
})

local BangToggle = TrollTab:CreateToggle({
    Name = "Bang aktivieren",
    CurrentValue = false,
    Flag = "BangToggle",
    Callback = function(Value)
        BangEnabled = Value
        if Value then
            if not SelectedTargetPlayer then
                BangEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Kein Target ausgewählt",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            local playerStillInGame = game.Players:FindFirstChild(SelectedTargetPlayer.Name)
            if not playerStillInGame then
                SelectedTargetPlayer = nil
                BangEnabled = false
                RemoveHighlight()
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Spieler ist nicht mehr im Spiel",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            if not SelectedTargetPlayer.Character then
                Rayfield:Notify({
                    Title = "Warte...",
                    Content = "Warte auf Character von " .. SelectedTargetPlayer.Name,
                    Duration = 2,
                    Image = 4483362458
                })
                SelectedTargetPlayer.CharacterAdded:Wait()
                wait(0.5)
            end
            
            StartBanging()
            local modeText = BangMode == "Body" and "Körper" or (BangMode == "Head" and "Kopf" or "Gesicht")
            Rayfield:Notify({
                Title = "Bang aktiviert",
                Content = "Bang auf " .. SelectedTargetPlayer.Name .. " (" .. modeText .. ")",
                Duration = 3,
                Image = 4483362458
            })
        else
            if Banging then
                StopBanging()
            end
            Rayfield:Notify({
                Title = "Bang deaktiviert",
                Content = "Bang-Modus ausgeschaltet",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Info Section
local BangInfoSection = TrollTab:CreateSection("ℹ️ Information")
local BangInfoLabel = TrollTab:CreateLabel("💡 Wähle zuerst ein Target im Target-Tab aus")
local BangInfo2Label = TrollTab:CreateLabel("Body = Hinter Körper | Head = Hinter Kopf | Face = Vor Gesicht (auf Kopfhöhe)")

-- ============================================
-- BANG FUNKTIONEN
-- ============================================

function StartBanging()
    if not SelectedTargetPlayer then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Kein Target ausgewählt",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    if not SelectedTargetPlayer.Character then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Target hat keinen Character",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    Banging = true
    
    spawn(function()
        local time = 0
        
        while Banging and BangEnabled and SelectedTargetPlayer do
            if not SelectedTargetPlayer.Character then
                StopBanging()
                BangEnabled = false
                Rayfield:Notify({
                    Title = "Bang beendet",
                    Content = SelectedTargetPlayer.Name .. " hat keinen Character mehr",
                    Duration = 3,
                    Image = 4483362458
                })
                break
            end
            
            local targetRoot = SelectedTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHead = SelectedTargetPlayer.Character:FindFirstChild("Head")
            
            if targetRoot and targetHead and HumanoidRootPart then
                -- Zeit für Sinus-Animation erhöhen
                time = time + (1 / 60) / BangSpeed
                
                -- Sinus-Welle für flüssige Bewegung (-1 bis 1)
                local wave = math.sin(time * math.pi * 2)
                
                local targetPosition
                local targetRotation
                
                if BangMode == "Body" then
                    -- Körper-Modus: Hinter dem Körper
                    local rootCFrame = targetRoot.CFrame
                    local backDistance = BangDistance * 0.5 + (wave * BangDistance * 0.5)
                    
                    targetPosition = (rootCFrame * CFrame.new(0, 0, backDistance + 1)).Position
                    targetRotation = CFrame.new(Vector3.new(), targetRoot.Position - targetPosition)
                    
                elseif BangMode == "Head" then
                    -- Kopf-Modus: Hinter dem Kopf
                    local headCFrame = targetHead.CFrame
                    local backDistance = BangDistance * 0.5 + (wave * BangDistance * 0.5)
                    
                    targetPosition = (headCFrame * CFrame.new(0, 0, backDistance + 0.5)).Position
                    targetRotation = CFrame.new(Vector3.new(), targetHead.Position - targetPosition)
                    
                elseif BangMode == "Face" then
                    -- Gesicht-Modus: VOR dem Gesicht auf Kopfhöhe
                    local headPos = targetHead.Position
                    local rootCFrame = targetRoot.CFrame
                    local lookVector = rootCFrame.LookVector
                    
                    -- Berechne Distanz basierend auf Sinus-Welle
                    local frontDistance = BangDistance * 0.5 + (wave * BangDistance * 0.5)
                    
                    -- Position VOR dem Kopf (in Blickrichtung)
                    targetPosition = headPos + (lookVector * (frontDistance + 1))
                    
                    -- Rotation: Schaue ZUM Kopf (umgekehrt)
                    targetRotation = CFrame.new(Vector3.new(), headPos - targetPosition)
                end
                
                -- Kombiniere Position und Rotation
                local targetCFrame = CFrame.new(targetPosition) * targetRotation
                
                -- EXTREM flüssige Interpolation
                HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(targetCFrame, 0.25)
                
            else
                StopBanging()
                BangEnabled = false
                Rayfield:Notify({
                    Title = "Bang beendet",
                    Content = "Target verloren",
                    Duration = 3,
                    Image = 4483362458
                })
                break
            end
            
            game:GetService("RunService").Heartbeat:Wait()
        end
    end)
end

function StopBanging()
    Banging = false
end

-- ============================================
-- SPIN SECTION
-- ============================================

local SpinSection = TrollTab:CreateSection("Spin Controls")

local SpinSpeedSlider = TrollTab:CreateSlider({
    Name = "Spin Geschwindigkeit",
    Range = {1, 50},
    Increment = 0.01,
    CurrentValue = 0.05,
    Flag = "SpinSpeedSlider",
    Callback = function(Value)
        SpinSpeed = Value
    end
})

local SpinToggle = TrollTab:CreateToggle({
    Name = "Spin aktivieren",
    CurrentValue = false,
    Flag = "SpinToggle",
    Callback = function(Value)
        SpinEnabled = Value
        if Value then
            local player = game.Players.LocalPlayer
            if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
                SpinEnabled = false
                Rayfield:Notify({
                    Title = "Fehler",
                    Content = "Character nicht gefunden",
                    Duration = 3,
                    Image = 4483362458
                })
                return
            end
            
            -- Spin-Loop starten
            local angle = 0
            SpinConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if not SpinEnabled then return end
                
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    angle = angle + SpinSpeed
                    local hrp = char.HumanoidRootPart
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, SpinSpeed, 0)
                else
                    SpinEnabled = false
                    if SpinConnection then
                        SpinConnection:Disconnect()
                    end
                end
            end)
            
            Rayfield:Notify({
                Title = "Spin aktiviert",
                Content = "Dein Character dreht sich jetzt!",
                Duration = 3,
                Image = 4483362458
            })
        else
            -- Spin stoppen
            if SpinConnection then
                SpinConnection:Disconnect()
                SpinConnection = nil
            end
            
            Rayfield:Notify({
                Title = "Spin deaktiviert",
                Content = "Spin-Modus ausgeschaltet",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Info Section für Spin
local SpinInfoSection = TrollTab:CreateSection("ℹ️ Spin Information")
local SpinInfoLabel = TrollTab:CreateLabel("💡 Dein Character dreht sich um die eigene Achse")
local SpinInfo2Label = TrollTab:CreateLabel("⚙️ Passe die Geschwindigkeit mit dem Slider an")
















-- ============================================
-- HVH TAB
-- ============================================

local HvHTab = Window:CreateTab("HvH", 4483362458)

-- Anti-Headsit Variablen
local AntiHeadsitEnabled = false
local AntiHeadsitConnection = nil
local HeadTeleportDistance = 5
local TeleportInterval = 0.3
local ShakeIntensity = 30
local AntiHeadsitMethod = "Teleport" -- "Teleport", "Shake", "Both"

-- ============================================
-- ANTI-HEADSIT SECTION
-- ============================================

local AntiHeadsitSection = HvHTab:CreateSection("Anti-Headsit Protection")

local AntiHeadsitMethodDropdown = HvHTab:CreateDropdown({
    Name = "Schutzmethode",
    Options = {"Teleport (Kopf wegbewegen)", "Shake (Kopf schütteln)", "Both (Beides)"},
    CurrentOption = "Teleport (Kopf wegbewegen)",
    Flag = "AntiHeadsitMethodDropdown",
    Callback = function(Option)
        if Option == "Teleport (Kopf wegbewegen)" then
            AntiHeadsitMethod = "Teleport"
        elseif Option == "Shake (Kopf schütteln)" then
            AntiHeadsitMethod = "Shake"
        elseif Option == "Both (Beides)" then
            AntiHeadsitMethod = "Both"
        end
        
        Rayfield:Notify({
            Title = "Methode geändert",
            Content = Option,
            Duration = 2,
            Image = 4483362458
        })
    end
})

local HeadTeleportSlider = HvHTab:CreateSlider({
    Name = "Teleport Distanz",
    Range = {3, 15},
    Increment = 0.5,
    CurrentValue = 5,
    Flag = "HeadTeleportSlider",
    Callback = function(Value)
        HeadTeleportDistance = Value
    end
})

local TeleportIntervalSlider = HvHTab:CreateSlider({
    Name = "Teleport Intervall (Sekunden)",
    Range = {0.1, 2},
    Increment = 0.1,
    CurrentValue = 0.3,
    Flag = "TeleportIntervalSlider",
    Callback = function(Value)
        TeleportInterval = Value
    end
})

local ShakeIntensitySlider = HvHTab:CreateSlider({
    Name = "Shake Intensität",
    Range = {10, 50},
    Increment = 5,
    CurrentValue = 30,
    Flag = "ShakeIntensitySlider",
    Callback = function(Value)
        ShakeIntensity = Value
    end
})

local AntiHeadsitToggle = HvHTab:CreateToggle({
    Name = "Anti-Headsit aktivieren",
    CurrentValue = false,
    Flag = "AntiHeadsitToggle",
    Callback = function(Value)
        AntiHeadsitEnabled = Value
        if Value then
            StartAntiHeadsit()
            Rayfield:Notify({
                Title = "Anti-Headsit aktiviert",
                Content = "Schutz vor Headsit aktiv",
                Duration = 3,
                Image = 4483362458
            })
        else
            StopAntiHeadsit()
            Rayfield:Notify({
                Title = "Anti-Headsit deaktiviert",
                Content = "Schutz deaktiviert",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

-- Info Section
local AntiHeadsitInfoSection = HvHTab:CreateSection("ℹ️ Information")
local AntiHeadsitInfoLabel = HvHTab:CreateLabel("💡 Teleport: Bewegt dich alle 0.1-2 Sekunden weg")
local AntiHeadsitInfo2Label = HvHTab:CreateLabel("💡 Shake: Schüttelt deinen Kopf kontinuierlich")
local AntiHeadsitInfo3Label = HvHTab:CreateLabel("💡 Both: Kombiniert beide für maximalen Schutz")
local AntiHeadsitInfo4Label = HvHTab:CreateLabel("⚡ Tipp: 0.1-0.3 Sek = Sehr schnell | 0.5+ Sek = Langsamer")

-- ============================================
-- ANTI-HEADSIT FUNKTIONEN
-- ============================================

function StartAntiHeadsit()
    if not Character or not HumanoidRootPart then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Character nicht gefunden",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    local Head = Character:FindFirstChild("Head")
    if not Head then
        Rayfield:Notify({
            Title = "Fehler",
            Content = "Kopf nicht gefunden",
            Duration = 3,
            Image = 4483362458
        })
        return
    end
    
    local lastTeleportTime = 0
    
    AntiHeadsitConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not AntiHeadsitEnabled then return end
        
        local Head = Character:FindFirstChild("Head")
        if not Head then return end
        
        local time = tick()
        
        -- TELEPORT METHODE: Nach einstellbarem Intervall teleportieren
        if AntiHeadsitMethod == "Teleport" or AntiHeadsitMethod == "Both" then
            if time - lastTeleportTime >= TeleportInterval then
                local randomOffset = Vector3.new(
                    math.random(-HeadTeleportDistance, HeadTeleportDistance),
                    0,
                    math.random(-HeadTeleportDistance, HeadTeleportDistance)
                )
                HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + randomOffset
                lastTeleportTime = time
            end
        end
        
        -- SHAKE METHODE: Durchgehend Kopf schütteln mit einstellbarer Intensität
        if AntiHeadsitMethod == "Shake" or AntiHeadsitMethod == "Both" then
            local shakeX = math.sin(time * ShakeIntensity) * 2
            local shakeZ = math.cos(time * ShakeIntensity) * 2
            
            HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(
                math.rad(shakeX),
                0,
                math.rad(shakeZ)
            )
        end
    end)
end

function StopAntiHeadsit()
    if AntiHeadsitConnection then
        AntiHeadsitConnection:Disconnect()
        AntiHeadsitConnection = nil
    end
end











