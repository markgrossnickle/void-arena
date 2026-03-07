--!strict
--[=[
	@class GameModeService
	@server
	Manages game modes (TDM, FFA, Domination), scoring, rounds, and teams.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local MapService
local ProgressionService

export type GameState = "Lobby" | "ClassSelect" | "InProgress" | "PostGame"

local GameModeService = Knit.CreateService({
	Name = "GameModeService",
	RoundStarted = Signal.new(),
	RoundEnded = Signal.new(), -- (winnerInfo)
	ScoreChanged = Signal.new(),

	Client = {
		GameStateChanged = Knit.CreateSignal(),
		ScoreUpdated = Knit.CreateSignal(),
		TimerSync = Knit.CreateSignal(),
		RoundEnded = Knit.CreateSignal(),
		KillFeedEntry = Knit.CreateSignal(),
	},

	_currentMode = "TDM" :: string,
	_gameState = "Lobby" :: GameState,
	_scores = {} :: { [string]: number }, -- team name or player name -> score
	_playerTeams = {} :: { [Player]: string }, -- player -> team name
	_capturePoints = {} :: { [string]: { Owner: string?, Progress: number, Capturers: { Player } } },
	_matchTimer = 0,
	_matchStartTime = 0,
	_team1 = nil :: Team?,
	_team2 = nil :: Team?,
})

function GameModeService:GetCurrentMode(): string
	return self._currentMode
end

function GameModeService:GetGameState(): GameState
	return self._gameState
end

function GameModeService:GetScores(): { [string]: number }
	return self._scores
end

function GameModeService:GetPlayerTeam(player: Player): string?
	return self._playerTeams[player]
end

function GameModeService:AreAllies(player1: Player, player2: Player): boolean
	if self._currentMode == "FFA" then
		return false
	end
	local team1 = self._playerTeams[player1]
	local team2 = self._playerTeams[player2]
	return team1 ~= nil and team1 == team2
end

function GameModeService:StartMatch(mode: string)
	if not VoidArenaConfig.GameModes[mode] then
		warn("Invalid game mode:", mode)
		return
	end

	self._currentMode = mode
	self._scores = {}
	self._capturePoints = {}

	-- Set up teams
	if VoidArenaConfig.GameModes[mode].TeamsRequired then
		self:_setupTeams()
	else
		-- FFA: each player is their own "team"
		for _, player in Players:GetPlayers() do
			self._playerTeams[player] = player.Name
			self._scores[player.Name] = 0
		end
	end

	-- Load a compatible map
	if MapService then
		MapService:LoadRandomMapForMode(mode)
	end

	-- Set up capture points for Domination
	if mode == "Domination" then
		self:_setupCapturePoints()
	end

	-- Start match
	self._gameState = "InProgress"
	self._matchStartTime = tick()
	self._matchTimer = VoidArenaConfig.Match.Duration

	for _, player in Players:GetPlayers() do
		self.Client.GameStateChanged:Fire(player, "InProgress", mode)
		self.Client.ScoreUpdated:Fire(player, self._scores)
	end

	self.RoundStarted:Fire(mode)

	-- Spawn all players
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end

	-- Start game loop
	self:_runMatchLoop()
end

function GameModeService:_setupTeams()
	-- Create teams if they don't exist
	self._team1 = Teams:FindFirstChild(VoidArenaConfig.Teams.Team1.Name) :: Team?
	if not self._team1 then
		self._team1 = Instance.new("Team")
		self._team1.Name = VoidArenaConfig.Teams.Team1.Name
		self._team1.TeamColor = VoidArenaConfig.Teams.Team1.BrickColor
		self._team1.AutoAssignable = false
		self._team1.Parent = Teams
	end

	self._team2 = Teams:FindFirstChild(VoidArenaConfig.Teams.Team2.Name) :: Team?
	if not self._team2 then
		self._team2 = Instance.new("Team")
		self._team2.Name = VoidArenaConfig.Teams.Team2.Name
		self._team2.TeamColor = VoidArenaConfig.Teams.Team2.BrickColor
		self._team2.AutoAssignable = false
		self._team2.Parent = Teams
	end

	self._scores[VoidArenaConfig.Teams.Team1.Name] = 0
	self._scores[VoidArenaConfig.Teams.Team2.Name] = 0

	-- Assign players to teams (balanced)
	local players = Players:GetPlayers()
	for i, player in players do
		local teamName: string
		if i % 2 == 1 then
			teamName = VoidArenaConfig.Teams.Team1.Name
			player.Team = self._team1
		else
			teamName = VoidArenaConfig.Teams.Team2.Name
			player.Team = self._team2
		end
		self._playerTeams[player] = teamName
	end
end

function GameModeService:_setupCapturePoints()
	if not MapService then
		return
	end
	local currentMap = MapService:GetCurrentMap()
	local pointConfigs = VoidArenaConfig.CapturePoints[currentMap]
	if not pointConfigs then
		return
	end

	for _, pointConfig in pointConfigs do
		self._capturePoints[pointConfig.Name] = {
			Owner = nil,
			Progress = 0,
			Capturers = {},
		}
	end
end

function GameModeService:_runMatchLoop()
	task.spawn(function()
		while self._gameState == "InProgress" do
			local elapsed = tick() - self._matchStartTime
			local timeRemaining = math.max(0, VoidArenaConfig.Match.Duration - elapsed)

			-- Sync timer to clients every second
			for _, player in Players:GetPlayers() do
				self.Client.TimerSync:Fire(player, timeRemaining)
			end

			-- Domination: award points for held capture points
			if self._currentMode == "Domination" then
				self:_tickDomination()
			end

			-- Check win conditions
			if self:_checkWinCondition() or timeRemaining <= 0 then
				self:_endMatch()
				return
			end

			task.wait(1)
		end
	end)
end

function GameModeService:_tickDomination()
	-- Award points for owned capture points
	for _, pointData in self._capturePoints do
		if pointData.Owner then
			self._scores[pointData.Owner] = (self._scores[pointData.Owner] or 0)
				+ VoidArenaConfig.GameModes.Domination.PointsPerSecond
		end
	end

	-- Update capture progress
	if not MapService then
		return
	end
	local currentMap = MapService:GetCurrentMap()
	local pointConfigs = VoidArenaConfig.CapturePoints[currentMap]
	if not pointConfigs then
		return
	end

	for _, pointConfig in pointConfigs do
		local pointData = self._capturePoints[pointConfig.Name]
		if not pointData then
			continue
		end

		-- Count players on point by team
		local teamCounts: { [string]: number } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then
				continue
			end
			local dist = (rootPart.Position - pointConfig.Position).Magnitude
			if dist <= 15 then -- capture radius
				local team = self._playerTeams[player]
				if team then
					teamCounts[team] = (teamCounts[team] or 0) + 1
				end
			end
		end

		-- Determine dominant team
		local dominantTeam: string? = nil
		local maxCount = 0
		for team, count in teamCounts do
			if count > maxCount then
				maxCount = count
				dominantTeam = team
			elseif count == maxCount then
				dominantTeam = nil -- contested
			end
		end

		if dominantTeam and dominantTeam ~= pointData.Owner then
			pointData.Progress += 1
			if pointData.Progress >= VoidArenaConfig.GameModes.Domination.CaptureTime then
				pointData.Owner = dominantTeam
				pointData.Progress = 0
			end
		elseif not dominantTeam then
			pointData.Progress = math.max(0, pointData.Progress - 1)
		end
	end

	-- Sync scores
	for _, player in Players:GetPlayers() do
		self.Client.ScoreUpdated:Fire(player, self._scores)
	end
end

function GameModeService:OnPlayerKill(killer: Player, victim: Player)
	if self._gameState ~= "InProgress" then
		return
	end

	local mode = self._currentMode

	if mode == "TDM" then
		local killerTeam = self._playerTeams[killer]
		if killerTeam then
			self._scores[killerTeam] = (self._scores[killerTeam] or 0) + 1
		end
	elseif mode == "FFA" then
		self._scores[killer.Name] = (self._scores[killer.Name] or 0) + 1
	elseif mode == "Domination" then
		-- Kills don't directly score in domination, but we track them
		local killerTeam = self._playerTeams[killer]
		if killerTeam then
			-- Small bonus for kills
		end
	end

	-- Broadcast kill feed
	for _, player in Players:GetPlayers() do
		self.Client.KillFeedEntry:Fire(player, killer.Name, victim.Name)
		self.Client.ScoreUpdated:Fire(player, self._scores)
	end

	self.ScoreChanged:Fire(self._scores)
end

function GameModeService:_checkWinCondition(): boolean
	local mode = self._currentMode
	local modeConfig = VoidArenaConfig.GameModes[mode]

	if mode == "TDM" then
		for _, score in self._scores do
			if score >= modeConfig.KillsToWin then
				return true
			end
		end
	elseif mode == "FFA" then
		for _, score in self._scores do
			if score >= modeConfig.KillsToWin then
				return true
			end
		end
	elseif mode == "Domination" then
		for _, score in self._scores do
			if score >= modeConfig.PointsToWin then
				return true
			end
		end
	end

	return false
end

function GameModeService:_endMatch()
	self._gameState = "PostGame"

	-- Determine winner
	local winnerName = ""
	local highScore = 0
	for name, score in self._scores do
		if score > highScore then
			highScore = score
			winnerName = name
		end
	end

	-- Award win bonuses
	if ProgressionService then
		for _, player in Players:GetPlayers() do
			local playerTeam = self._playerTeams[player]
			local isWinner = false

			if self._currentMode == "FFA" then
				isWinner = player.Name == winnerName
			else
				isWinner = playerTeam == winnerName
			end

			if isWinner then
				ProgressionService:RecordWin(player)
			end

			ProgressionService:EndMatch(player)
		end
	end

	-- Notify clients
	for _, player in Players:GetPlayers() do
		self.Client.RoundEnded:Fire(player, winnerName, self._scores)
		self.Client.GameStateChanged:Fire(player, "PostGame", self._currentMode)
	end

	self.RoundEnded:Fire(winnerName)

	-- After post-game, go back to lobby and start new match
	task.delay(10, function()
		self._gameState = "Lobby"
		for _, player in Players:GetPlayers() do
			self.Client.GameStateChanged:Fire(player, "Lobby", "")
		end

		-- Auto-start next match after brief intermission
		task.delay(VoidArenaConfig.GameModes[self._currentMode] and 5 or 5, function()
			if #Players:GetPlayers() >= 1 then
				-- Cycle game modes
				local modes = { "TDM", "FFA", "Domination" }
				local currentIdx = table.find(modes, self._currentMode) or 0
				local nextMode = modes[(currentIdx % #modes) + 1]
				self:StartMatch(nextMode)
			end
		end)
	end)
end

function GameModeService:GetSpawnPosition(player: Player): CFrame
	if MapService then
		local team = self._playerTeams[player]
		return MapService:GetSpawnPoint(player, team)
	end
	return CFrame.new(0, 10, 0)
end

function GameModeService.Client:GetCurrentMode(player: Player): string
	return self.Server:GetCurrentMode()
end

function GameModeService.Client:GetGameState(player: Player): string
	return self.Server:GetGameState()
end

function GameModeService.Client:GetScores(player: Player): { [string]: number }
	return self.Server:GetScores()
end

function GameModeService.Client:GetPlayerTeam(player: Player): string?
	return self.Server:GetPlayerTeam(player)
end

function GameModeService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		self._playerTeams[player] = nil
	end)

	-- Handle new players joining mid-match
	Players.PlayerAdded:Connect(function(player)
		if self._gameState == "InProgress" then
			-- Assign to team with fewer players
			if VoidArenaConfig.GameModes[self._currentMode].TeamsRequired then
				local team1Count = 0
				local team2Count = 0
				for _, team in self._playerTeams do
					if team == VoidArenaConfig.Teams.Team1.Name then
						team1Count += 1
					else
						team2Count += 1
					end
				end
				if team1Count <= team2Count then
					self._playerTeams[player] = VoidArenaConfig.Teams.Team1.Name
					player.Team = self._team1
				else
					self._playerTeams[player] = VoidArenaConfig.Teams.Team2.Name
					player.Team = self._team2
				end
			else
				self._playerTeams[player] = player.Name
				self._scores[player.Name] = 0
			end

			self.Client.GameStateChanged:Fire(player, "InProgress", self._currentMode)
			self.Client.ScoreUpdated:Fire(player, self._scores)
		end
	end)
end

function GameModeService:KnitStart()
	MapService = Knit.GetService("MapService")
	ProgressionService = Knit.GetService("ProgressionService")

	-- Start first match when enough players join
	task.spawn(function()
		while #Players:GetPlayers() < 1 do
			task.wait(1)
		end
		task.wait(3) -- Brief wait for players to load
		self:StartMatch("TDM")
	end)
end

return GameModeService
