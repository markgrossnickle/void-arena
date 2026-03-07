--!strict
--[=[
	@class ProgressionService
	@server
	Handles XP, levels, coins, leaderboards, and cosmetics.
]=]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local PlayerDataService

local ProgressionService = Knit.CreateService({
	Name = "ProgressionService",
	LevelUp = Signal.new(), -- (player, newLevel)

	Client = {
		XPGained = Knit.CreateSignal(),
		CoinsGained = Knit.CreateSignal(),
		LevelUp = Knit.CreateSignal(),
		StatsUpdated = Knit.CreateSignal(),
	},

	_matchKills = {} :: { [Player]: number },
	_matchAssists = {} :: { [Player]: number },
	_matchObjectives = {} :: { [Player]: number },
})

function ProgressionService:_xpForLevel(level: number): number
	-- XP required to go from level to level+1
	return 100 + (level - 1) * 50
end

function ProgressionService:RecordKill(killer: Player, _victim: Player)
	self._matchKills[killer] = (self._matchKills[killer] or 0) + 1

	-- Immediate rewards
	self:_grantXP(killer, VoidArenaConfig.Progression.XPPerKill)
	self:_grantCoins(killer, VoidArenaConfig.Progression.CoinsPerKill)

	-- Update persistent stats
	task.spawn(function()
		local totalKills = PlayerDataService:Read(killer, { "TotalKills" }) or 0
		PlayerDataService:Write(killer, { "TotalKills" }, totalKills + 1)

		-- Update killstreak
		local currentStreak = self._matchKills[killer] or 0
		local highestStreak = PlayerDataService:Read(killer, { "HighestKillstreak" }) or 0
		if currentStreak > highestStreak then
			PlayerDataService:Write(killer, { "HighestKillstreak" }, currentStreak)
		end
	end)

	-- Class mastery XP
	local ClassService = Knit.GetService("ClassService")
	local className = ClassService:GetPlayerClass(killer)
	task.spawn(function()
		local mastery = PlayerDataService:Read(killer, { "ClassMastery", className }) or 0
		PlayerDataService:Write(killer, { "ClassMastery", className }, mastery + VoidArenaConfig.Progression.XPPerKill)
	end)
end

function ProgressionService:RecordAssist(player: Player)
	self._matchAssists[player] = (self._matchAssists[player] or 0) + 1
	self:_grantXP(player, VoidArenaConfig.Progression.XPPerAssist)
	self:_grantCoins(player, VoidArenaConfig.Progression.CoinsPerAssist)

	task.spawn(function()
		local totalAssists = PlayerDataService:Read(player, { "TotalAssists" }) or 0
		PlayerDataService:Write(player, { "TotalAssists" }, totalAssists + 1)
	end)
end

function ProgressionService:RecordObjective(player: Player)
	self._matchObjectives[player] = (self._matchObjectives[player] or 0) + 1
	self:_grantXP(player, VoidArenaConfig.Progression.XPPerObjective)
end

function ProgressionService:RecordWin(player: Player)
	self:_grantXP(player, VoidArenaConfig.Progression.WinBonus)
	self:_grantCoins(player, VoidArenaConfig.Progression.CoinsPerWin)

	task.spawn(function()
		local totalWins = PlayerDataService:Read(player, { "TotalWins" }) or 0
		PlayerDataService:Write(player, { "TotalWins" }, totalWins + 1)
	end)
end

function ProgressionService:RecordDeath(player: Player)
	task.spawn(function()
		local totalDeaths = PlayerDataService:Read(player, { "TotalDeaths" }) or 0
		PlayerDataService:Write(player, { "TotalDeaths" }, totalDeaths + 1)
	end)
end

function ProgressionService:EndMatch(player: Player)
	-- Reset match-specific counters
	self._matchKills[player] = 0
	self._matchAssists[player] = 0
	self._matchObjectives[player] = 0

	-- Send final stats update
	self:_sendStatsUpdate(player)
end

function ProgressionService:_grantXP(player: Player, amount: number)
	task.spawn(function()
		local currentXP = PlayerDataService:Read(player, { "XP" }) or 0
		local currentLevel = PlayerDataService:Read(player, { "Level" }) or 1

		currentXP += amount

		-- Check for level up
		while currentLevel < VoidArenaConfig.Progression.MaxLevel do
			local xpNeeded = self:_xpForLevel(currentLevel)
			if currentXP >= xpNeeded then
				currentXP -= xpNeeded
				currentLevel += 1
				self.LevelUp:Fire(player, currentLevel)
				self.Client.LevelUp:Fire(player, currentLevel)
			else
				break
			end
		end

		PlayerDataService:Write(player, { "XP" }, currentXP)
		PlayerDataService:Write(player, { "Level" }, currentLevel)

		self.Client.XPGained:Fire(player, amount)
	end)
end

function ProgressionService:_grantCoins(player: Player, amount: number)
	task.spawn(function()
		local currentCoins = PlayerDataService:Read(player, { "Coins" }) or 0
		local newCoins = math.min(currentCoins + amount, 999999)
		PlayerDataService:Write(player, { "Coins" }, newCoins)
		self.Client.CoinsGained:Fire(player, amount)
	end)
end

function ProgressionService:_sendStatsUpdate(player: Player)
	task.spawn(function()
		local stats = {
			Level = PlayerDataService:Read(player, { "Level" }) or 1,
			XP = PlayerDataService:Read(player, { "XP" }) or 0,
			Coins = PlayerDataService:Read(player, { "Coins" }) or 0,
			TotalKills = PlayerDataService:Read(player, { "TotalKills" }) or 0,
			TotalDeaths = PlayerDataService:Read(player, { "TotalDeaths" }) or 0,
			TotalWins = PlayerDataService:Read(player, { "TotalWins" }) or 0,
		}
		self.Client.StatsUpdated:Fire(player, stats)
	end)
end

function ProgressionService:GetPlayerStats(player: Player)
	return {
		Level = PlayerDataService:Read(player, { "Level" }) or 1,
		XP = PlayerDataService:Read(player, { "XP" }) or 0,
		Coins = PlayerDataService:Read(player, { "Coins" }) or 0,
		TotalKills = PlayerDataService:Read(player, { "TotalKills" }) or 0,
		TotalDeaths = PlayerDataService:Read(player, { "TotalDeaths" }) or 0,
		TotalWins = PlayerDataService:Read(player, { "TotalWins" }) or 0,
		TotalAssists = PlayerDataService:Read(player, { "TotalAssists" }) or 0,
		HighestKillstreak = PlayerDataService:Read(player, { "HighestKillstreak" }) or 0,
	}
end

function ProgressionService:PurchaseCosmetic(player: Player, itemId: string, cost: number, category: string): boolean
	local coins = PlayerDataService:Read(player, { "Coins" }) or 0
	if coins < cost then
		return false
	end

	-- Check if already owned
	local owned = PlayerDataService:Read(player, { category, itemId })
	if owned then
		return false
	end

	PlayerDataService:Write(player, { "Coins" }, coins - cost)
	PlayerDataService:Write(player, { category, itemId }, true)
	return true
end

function ProgressionService:EquipCosmetic(player: Player, slot: string, itemId: string)
	PlayerDataService:Write(player, { slot }, itemId)
end

function ProgressionService.Client:GetPlayerStats(player: Player)
	return self.Server:GetPlayerStats(player)
end

function ProgressionService.Client:PurchaseCosmetic(player: Player, itemId: string, cost: number, category: string): boolean
	return self.Server:PurchaseCosmetic(player, itemId, cost, category)
end

function ProgressionService.Client:EquipCosmetic(player: Player, slot: string, itemId: string)
	self.Server:EquipCosmetic(player, slot, itemId)
end

function ProgressionService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		self._matchKills[player] = nil
		self._matchAssists[player] = nil
		self._matchObjectives[player] = nil
	end)
end

function ProgressionService:KnitStart()
	PlayerDataService = Knit.GetService("PlayerDataService")

	-- Send initial stats when profile is ready
	PlayerDataService.ProfileReady:Connect(function(player)
		self:_sendStatsUpdate(player)
	end)
end

return ProgressionService
