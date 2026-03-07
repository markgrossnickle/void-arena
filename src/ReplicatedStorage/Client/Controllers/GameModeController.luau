--!strict
--[=[
	@class GameModeController
	@client
	Manages game mode-specific client UI: domination capture indicators,
	round start/end screens, and post-game scoreboard.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local Player = Players.LocalPlayer

local GameModeController = Knit.CreateController({
	Name = "GameModeController",
	_trove = Trove.new(),
	_postGameGui = nil :: ScreenGui?,
	_captureGui = nil :: ScreenGui?,
	_currentMode = "",
	_gameState = "Lobby",
})

function GameModeController:_showPostGame(winnerName: string, scores: { [string]: number })
	if self._postGameGui then
		self._postGameGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PostGameGui"
	gui.ResetOnSpawn = false
	gui.Parent = Player.PlayerGui
	self._postGameGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "PostGameFrame"
	frame.Size = UDim2.fromScale(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.25, 0.25)
	frame.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 80, 255)
	stroke.Thickness = 3
	stroke.Parent = frame

	-- Winner title
	local title = Instance.new("TextLabel")
	title.Name = "WinnerTitle"
	title.Size = UDim2.fromScale(0.8, 0.15)
	title.Position = UDim2.fromScale(0.1, 0.05)
	title.BackgroundTransparency = 1
	title.Text = "WINNER"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextScaled = true
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	title.Parent = frame

	local winnerLabel = Instance.new("TextLabel")
	winnerLabel.Name = "WinnerName"
	winnerLabel.Size = UDim2.fromScale(0.8, 0.12)
	winnerLabel.Position = UDim2.fromScale(0.1, 0.2)
	winnerLabel.BackgroundTransparency = 1
	winnerLabel.Text = winnerName
	winnerLabel.TextColor3 = Color3.fromRGB(200, 150, 255)
	winnerLabel.TextScaled = true
	winnerLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	winnerLabel.Parent = frame

	-- Scores
	local yPos = 0.38
	for name, score in scores do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(0.8, 0.08)
		row.Position = UDim2.fromScale(0.1, yPos)
		row.BackgroundTransparency = 1
		row.Text = string.format("%s: %d", name, score)
		row.TextColor3 = if name == winnerName then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(200, 200, 220)
		row.TextScaled = true
		row.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
		row.Parent = frame
		yPos += 0.1
	end

	-- XP/Coins summary will be filled by ProgressionService signals
	local summaryLabel = Instance.new("TextLabel")
	summaryLabel.Name = "Summary"
	summaryLabel.Size = UDim2.fromScale(0.8, 0.1)
	summaryLabel.Position = UDim2.fromScale(0.1, 0.85)
	summaryLabel.BackgroundTransparency = 1
	summaryLabel.Text = "Calculating rewards..."
	summaryLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	summaryLabel.TextScaled = true
	summaryLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	summaryLabel.Parent = frame

	-- Auto-hide after 10s
	task.delay(10, function()
		if gui.Parent then
			gui:Destroy()
		end
		self._postGameGui = nil
	end)
end

function GameModeController:_createCapturePointDisplay()
	if self._captureGui then
		self._captureGui:Destroy()
	end

	if self._currentMode ~= "Domination" then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CaptureGui"
	gui.ResetOnSpawn = false
	gui.Parent = Player.PlayerGui
	self._captureGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "CaptureFrame"
	frame.Size = UDim2.fromScale(0.3, 0.04)
	frame.Position = UDim2.fromScale(0.35, 0.1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = frame

	local pointNames = { "Alpha", "Bravo", "Charlie" }
	for _, name in pointNames do
		local point = Instance.new("Frame")
		point.Name = "Point_" .. name
		point.Size = UDim2.fromScale(0.3, 1)
		point.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		point.BorderSizePixel = 0
		point.Parent = frame

		local pointCorner = Instance.new("UICorner")
		pointCorner.CornerRadius = UDim.new(0, 4)
		pointCorner.Parent = point

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = name:sub(1, 1) -- A, B, C
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		label.Parent = point
	end
end

function GameModeController:KnitInit() end

function GameModeController:KnitStart()
	local GameModeService = Knit.GetService("GameModeService")

	GameModeService.GameStateChanged:Connect(function(state, mode)
		self._gameState = state
		self._currentMode = mode

		if state == "InProgress" then
			self:_createCapturePointDisplay()
		end
	end)

	GameModeService.RoundEnded:Connect(function(winnerName, scores)
		self:_showPostGame(winnerName, scores)
	end)
end

return GameModeController
