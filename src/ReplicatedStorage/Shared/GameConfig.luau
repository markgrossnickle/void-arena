--!strict
--[=[
	@class GameConfig
	Shared baseline configuration for runtime-tunable values.
	LiveConfigService reads this as the baseline. Use Cmdr to override at runtime.
]=]

local GameConfig = {
	Player = {
		MaxHP = 150,
		WalkSpeed = 16,
		JumpPower = 50,
		RespawnTime = 3,
	},
	Economy = {
		StartingCoins = 0,
		StartingGems = 0,
		MaxCoins = 999999,
		MaxGems = 99999,
	},
	Gameplay = {
		MaxPlayersPerTeam = 5,
		RoundDuration = 300,
		IntermissionDuration = 10,
	},
}

return GameConfig
