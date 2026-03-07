--!strict
--[=[
	@class HUDController
	@client
	Manages all HUD elements: HP bar, kill feed, score, timer, minimap, scoreboard.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local Player = Players.LocalPlayer

local HUDController = Knit.CreateController({
	Name = "HUDController",
	_trove = Trove.new(),
	_hudGui = nil :: ScreenGui?,
	_scoreboardGui = nil :: ScreenGui?,
	_scoreboardVisible = false,
	_killFeed = {} :: { { killer: string, victim: string, time: number } },
	_currentScores = {} :: { [string]: number },
	_timeRemaining = 0,
	_currentMode = "" :: string,
	_gameState = "Lobby" :: string,
})

function HUDController:_createHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUDGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Player.PlayerGui
	self._hudGui = gui

	self:_createHPBar(gui)
	self:_createKillFeed(gui)
	self:_createScoreDisplay(gui)
	self:_createTimerDisplay(gui)
	self:_createMinimap(gui)
	self:_createGameStateOverlay(gui)
	self:_createDamageFlash(gui)
end

function HUDController:_createHPBar(parent: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "HPFrame"
	frame.Size = UDim2.fromScale(0.15, 0.03)
	frame.Position = UDim2.fromScale(0.02, 0.92)
	frame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 50, 200)
	stroke.Thickness = 1
	stroke.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "HPFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	fill.BorderSizePixel = 0
	fill.Parent = frame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Text = "150/150"
	hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpText.TextScaled = true
	hpText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	hpText.ZIndex = 2
	hpText.Parent = frame
end

function HUDController:_createKillFeed(parent: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "KillFeed"
	frame.Size = UDim2.fromScale(0.22, 0.2)
	frame.Position = UDim2.fromScale(0.76, 0.02)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame
end

function HUDController:_addKillFeedEntry(killer: string, victim: string)
	table.insert(self._killFeed, { killer = killer, victim = victim, time = tick() })

	-- Keep only last 5
	while #self._killFeed > 5 do
		table.remove(self._killFeed, 1)
	end

	self:_refreshKillFeed()
end

function HUDController:_refreshKillFeed()
	if not self._hudGui then
		return
	end
	local feed = self._hudGui:FindFirstChild("KillFeed") :: Frame?
	if not feed then
		return
	end

	-- Clear existing entries
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for i, entry in self._killFeed do
		local label = Instance.new("TextLabel")
		label.Name = "Entry_" .. i
		label.Size = UDim2.fromScale(1, 0.18)
		label.LayoutOrder = i
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 0.6
		label.BorderSizePixel = 0
		label.Text = string.format(" %s  killed  %s", entry.killer, entry.victim)
		label.TextColor3 = Color3.fromRGB(255, 200, 200)
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Parent = feed

		-- Auto-remove after 5 seconds
		task.delay(5, function()
			if label.Parent then
				label:Destroy()
			end
		end)
	end
end

function HUDController:_createScoreDisplay(parent: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "ScoreFrame"
	frame.Size = UDim2.fromScale(0.2, 0.05)
	frame.Position = UDim2.fromScale(0.4, 0.01)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreText"
	scoreLabel.Size = UDim2.fromScale(1, 0.6)
	scoreLabel.Position = UDim2.fromScale(0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "0 - 0"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreLabel.TextScaled = true
	scoreLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	scoreLabel.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeText"
	modeLabel.Size = UDim2.fromScale(1, 0.35)
	modeLabel.Position = UDim2.fromScale(0, 0.6)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Text = ""
	modeLabel.TextColor3 = Color3.fromRGB(180, 150, 220)
	modeLabel.TextScaled = true
	modeLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	modeLabel.Parent = frame
end

function HUDController:_createTimerDisplay(parent: ScreenGui)
	local label = Instance.new("TextLabel")
	label.Name = "TimerLabel"
	label.Size = UDim2.fromScale(0.1, 0.03)
	label.Position = UDim2.fromScale(0.45, 0.06)
	label.BackgroundTransparency = 1
	label.Text = "5:00"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.Parent = parent
end

function HUDController:_createMinimap(parent: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Minimap"
	frame.Size = UDim2.fromScale(0.12, 0.16)
	frame.Position = UDim2.fromScale(0.01, 0.02)
	frame.BackgroundColor3 = Color3.fromRGB(10, 8, 15)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 40, 160)
	stroke.Thickness = 1
	stroke.Parent = frame

	-- Player dot (center)
	local playerDot = Instance.new("Frame")
	playerDot.Name = "PlayerDot"
	playerDot.Size = UDim2.fromOffset(6, 6)
	playerDot.Position = UDim2.fromScale(0.5, 0.5)
	playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerDot.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	playerDot.BorderSizePixel = 0
	playerDot.Parent = frame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = playerDot
end

function HUDController:_updateMinimap()
	if not self._hudGui then
		return
	end
	local minimap = self._hudGui:FindFirstChild("Minimap") :: Frame?
	if not minimap then
		return
	end

	local character = Player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local myPos = rootPart.Position
	local mapScale = 0.005 -- studs to minimap scale

	-- Remove old dots (except player dot)
	for _, child in minimap:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "PlayerDot" and child.Name ~= "UICorner" then
			child:Destroy()
		end
	end

	-- Add other player dots
	local GameModeService = Knit.GetService("GameModeService")
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == Player then
			continue
		end
		local otherChar = otherPlayer.Character
		if not otherChar then
			continue
		end
		local otherRoot = otherChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not otherRoot then
			continue
		end

		local offset = otherRoot.Position - myPos
		local dotX = 0.5 + offset.X * mapScale
		local dotY = 0.5 + offset.Z * mapScale

		-- Clamp to minimap bounds
		dotX = math.clamp(dotX, 0.05, 0.95)
		dotY = math.clamp(dotY, 0.05, 0.95)

		local dot = Instance.new("Frame")
		dot.Name = "OtherDot"
		dot.Size = UDim2.fromOffset(4, 4)
		dot.Position = UDim2.fromScale(dotX, dotY)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.Parent = minimap

		-- Color based on team
		GameModeService:GetPlayerTeam()
			:andThen(function(myTeam)
				-- Check if ally
				local isAlly = false
				if myTeam then
					-- We'd need to know their team too
					isAlly = otherPlayer.Team == Player.Team
				end
				dot.BackgroundColor3 = if isAlly then Color3.fromRGB(0, 150, 255) else Color3.fromRGB(255, 50, 50)
			end)
			:catch(function()
				dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			end)

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot
	end
end

function HUDController:_createGameStateOverlay(parent: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = "GameStateOverlay"
	overlay.Size = UDim2.fromScale(0.4, 0.15)
	overlay.Position = UDim2.fromScale(0.3, 0.35)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = overlay

	local label = Instance.new("TextLabel")
	label.Name = "StateText"
	label.Size = UDim2.fromScale(0.9, 0.5)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.Parent = overlay

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubText"
	subLabel.Size = UDim2.fromScale(0.9, 0.3)
	subLabel.Position = UDim2.fromScale(0.05, 0.6)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = ""
	subLabel.TextColor3 = Color3.fromRGB(200, 180, 230)
	subLabel.TextScaled = true
	subLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	subLabel.Parent = overlay
end

function HUDController:_showGameStateMessage(title: string, subtitle: string, duration: number?)
	if not self._hudGui then
		return
	end
	local overlay = self._hudGui:FindFirstChild("GameStateOverlay") :: Frame?
	if not overlay then
		return
	end

	local stateText = overlay:FindFirstChild("StateText") :: TextLabel?
	local subText = overlay:FindFirstChild("SubText") :: TextLabel?

	if stateText then
		stateText.Text = title
	end
	if subText then
		subText.Text = subtitle
	end

	overlay.Visible = true

	if duration then
		task.delay(duration, function()
			if overlay.Parent then
				overlay.Visible = false
			end
		end)
	end
end

function HUDController:_createDamageFlash(parent: ScreenGui)
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = parent
end

function HUDController:_flashDamage()
	if not self._hudGui then
		return
	end
	local flash = self._hudGui:FindFirstChild("DamageFlash") :: Frame?
	if not flash then
		return
	end

	flash.BackgroundTransparency = 0.6
	task.spawn(function()
		for i = 1, 6 do
			task.wait(0.03)
			flash.BackgroundTransparency = 0.6 + (i / 6) * 0.4
		end
		flash.BackgroundTransparency = 1
	end)
end

function HUDController:_updateHP()
	if not self._hudGui then
		return
	end

	local character = Player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local frame = self._hudGui:FindFirstChild("HPFrame") :: Frame?
	if not frame then
		return
	end

	local fill = frame:FindFirstChild("HPFill") :: Frame?
	local hpText = frame:FindFirstChild("HPText") :: TextLabel?

	local ratio = humanoid.Health / humanoid.MaxHealth

	if fill then
		fill.Size = UDim2.fromScale(ratio, 1)
		if ratio > 0.5 then
			fill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		elseif ratio > 0.25 then
			fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		else
			fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
	end

	if hpText then
		hpText.Text = string.format("%d/%d", math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
end

function HUDController:_updateScoreDisplay()
	if not self._hudGui then
		return
	end

	local frame = self._hudGui:FindFirstChild("ScoreFrame") :: Frame?
	if not frame then
		return
	end

	local scoreText = frame:FindFirstChild("ScoreText") :: TextLabel?
	local modeText = frame:FindFirstChild("ModeText") :: TextLabel?

	if scoreText then
		if self._currentMode == "FFA" then
			local myScore = self._currentScores[Player.Name] or 0
			scoreText.Text = string.format("Kills: %d", myScore)
		else
			local team1Score = self._currentScores[VoidArenaConfig.Teams.Team1.Name] or 0
			local team2Score = self._currentScores[VoidArenaConfig.Teams.Team2.Name] or 0
			scoreText.Text = string.format("%d - %d", team1Score, team2Score)
		end
	end

	if modeText then
		local modeConfig = VoidArenaConfig.GameModes[self._currentMode]
		modeText.Text = if modeConfig then modeConfig.Name else ""
	end
end

function HUDController:_updateTimer()
	if not self._hudGui then
		return
	end

	local label = self._hudGui:FindFirstChild("TimerLabel") :: TextLabel?
	if not label then
		return
	end

	local minutes = math.floor(self._timeRemaining / 60)
	local seconds = math.floor(self._timeRemaining % 60)
	label.Text = string.format("%d:%02d", minutes, seconds)

	if self._timeRemaining <= 30 then
		label.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function HUDController:_createScoreboard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScoreboardGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Player.PlayerGui
	self._scoreboardGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "ScoreboardFrame"
	frame.Size = UDim2.fromScale(0.5, 0.6)
	frame.Position = UDim2.fromScale(0.25, 0.2)
	frame.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 50, 200)
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.9, 0.08)
	title.Position = UDim2.fromScale(0.05, 0.02)
	title.BackgroundTransparency = 1
	title.Text = "SCOREBOARD"
	title.TextColor3 = Color3.fromRGB(200, 150, 255)
	title.TextScaled = true
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	title.Parent = frame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(0.9, 0.06)
	header.Position = UDim2.fromScale(0.05, 0.12)
	header.BackgroundTransparency = 1
	header.Parent = frame

	local columns = { "Player", "K", "D", "A", "Score" }
	local widths = { 0.4, 0.12, 0.12, 0.12, 0.15 }
	local xPos = 0
	for i, col in columns do
		local colLabel = Instance.new("TextLabel")
		colLabel.Size = UDim2.fromScale(widths[i], 1)
		colLabel.Position = UDim2.fromScale(xPos, 0)
		colLabel.BackgroundTransparency = 1
		colLabel.Text = col
		colLabel.TextColor3 = Color3.fromRGB(150, 130, 180)
		colLabel.TextScaled = true
		colLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		colLabel.Parent = header
		xPos += widths[i]
	end

	-- Player rows container
	local rowsFrame = Instance.new("ScrollingFrame")
	rowsFrame.Name = "Rows"
	rowsFrame.Size = UDim2.fromScale(0.9, 0.7)
	rowsFrame.Position = UDim2.fromScale(0.05, 0.2)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.BorderSizePixel = 0
	rowsFrame.ScrollBarThickness = 4
	rowsFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = rowsFrame
end

function HUDController:_updateScoreboard()
	if not self._scoreboardGui then
		return
	end

	local rowsFrame = self._scoreboardGui:FindFirstChild("ScoreboardFrame")
	if not rowsFrame then
		return
	end
	rowsFrame = rowsFrame:FindFirstChild("Rows") :: ScrollingFrame?
	if not rowsFrame then
		return
	end

	-- Clear existing rows
	for _, child in rowsFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Add player rows
	local orderedPlayers = Players:GetPlayers()
	for i, p in orderedPlayers do
		local row = Instance.new("Frame")
		row.Name = p.Name
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = i
		row.BackgroundColor3 = if p == Player then Color3.fromRGB(50, 30, 80) else Color3.fromRGB(25, 15, 40)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Parent = rowsFrame

		local score = self._currentScores[p.Name] or self._currentScores[p.Team and p.Team.Name or ""] or 0
		local values = { p.DisplayName, "0", "0", "0", tostring(score) }
		local widths = { 0.4, 0.12, 0.12, 0.12, 0.15 }
		local xPos = 0

		for j, val in values do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(widths[j], 1)
			label.Position = UDim2.fromScale(xPos, 0)
			label.BackgroundTransparency = 1
			label.Text = val
			label.TextColor3 = Color3.fromRGB(220, 220, 240)
			label.TextScaled = true
			label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
			label.Parent = row
			xPos += widths[j]
		end
	end
end

function HUDController:KnitInit() end

function HUDController:KnitStart()
	local GameModeService = Knit.GetService("GameModeService")
	local PlayerService = Knit.GetService("PlayerService")

	self:_createHUD()
	self:_createScoreboard()

	-- Game state changes
	GameModeService.GameStateChanged:Connect(function(state, mode)
		self._gameState = state
		self._currentMode = mode

		if state == "InProgress" then
			local modeName = VoidArenaConfig.GameModes[mode] and VoidArenaConfig.GameModes[mode].Name or mode
			self:_showGameStateMessage("MATCH STARTED", modeName, 3)
		elseif state == "PostGame" then
			self:_showGameStateMessage("MATCH OVER", "Results incoming...", nil)
		elseif state == "Lobby" then
			self:_showGameStateMessage("LOBBY", "Waiting for next match...", nil)
		end
	end)

	-- Score updates
	GameModeService.ScoreUpdated:Connect(function(scores)
		self._currentScores = scores
		self:_updateScoreDisplay()
	end)

	-- Timer sync
	GameModeService.TimerSync:Connect(function(timeRemaining)
		self._timeRemaining = timeRemaining
		self:_updateTimer()
	end)

	-- Kill feed
	GameModeService.KillFeedEntry:Connect(function(killer, victim)
		self:_addKillFeedEntry(killer, victim)
	end)

	-- Round ended
	GameModeService.RoundEnded:Connect(function(winnerName, scores)
		self._currentScores = scores
		self:_showGameStateMessage("WINNER: " .. winnerName, "", 8)
		self:_updateScoreboard()
	end)

	-- Damage taken
	PlayerService.DamageTaken:Connect(function(damage, attackerName, isHeadshot)
		self:_flashDamage()
	end)

	-- Kill feed from PlayerService
	PlayerService.PlayerKilled:Connect(function(killerName, victimName, streak)
		self:_addKillFeedEntry(killerName, victimName)
	end)

	-- HP update loop
	self._trove:Connect(RunService.Heartbeat, function()
		self:_updateHP()
	end)

	-- Minimap update (less frequent)
	task.spawn(function()
		while true do
			self:_updateMinimap()
			task.wait(0.5)
		end
	end)

	-- Scoreboard toggle (Tab key)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			if self._scoreboardGui then
				self._scoreboardGui.Enabled = true
				self:_updateScoreboard()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab then
			if self._scoreboardGui then
				self._scoreboardGui.Enabled = false
			end
		end
	end)
end

return HUDController
