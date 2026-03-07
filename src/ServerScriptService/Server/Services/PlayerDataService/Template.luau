--!strict
--[=[
	@class PlayerData
	@server
]=]

export type PlayerData = {
	-- Currencies
	Coins: number,
	Gems: number,

	-- Progression
	Level: number,
	XP: number,
	TotalKills: number,
	TotalDeaths: number,
	TotalWins: number,
	TotalAssists: number,
	HighestKillstreak: number,

	-- Class mastery (XP per class)
	ClassMastery: { [string]: number },

	-- Cosmetics
	OwnedSkins: { [string]: boolean },
	EquippedSkins: { [string]: string }, -- slot -> skinId
	OwnedAccessories: { [string]: boolean },
	EquippedAccessory: string,
	OwnedKillEffects: { [string]: boolean },
	EquippedKillEffect: string,

	-- Preferences
	SelectedClass: string,
	SelectedGameMode: string,

	-- Shop / Inventory
	Inventory: { [string]: number },

	-- Daily Login Rewards
	LoginStreak: number,
	LastLoginDate: string,
	LastLoginRewardClaimed: boolean,

	-- Analytics / Session tracking
	FirstJoinDate: string,
	TotalPlayTime: number,
	SessionCount: number,
	LastSessionStart: number,

	-- Monetization
	ProcessedReceipts: { [string]: boolean },
}

local playerDataTemplate: PlayerData = {
	Coins = 0,
	Gems = 0,

	Level = 1,
	XP = 0,
	TotalKills = 0,
	TotalDeaths = 0,
	TotalWins = 0,
	TotalAssists = 0,
	HighestKillstreak = 0,

	ClassMastery = {},

	OwnedSkins = {},
	EquippedSkins = {},
	OwnedAccessories = {},
	EquippedAccessory = "",
	OwnedKillEffects = {},
	EquippedKillEffect = "",

	SelectedClass = "Vanguard",
	SelectedGameMode = "TDM",

	Inventory = {},

	LoginStreak = 0,
	LastLoginDate = "",
	LastLoginRewardClaimed = false,

	FirstJoinDate = "",
	TotalPlayTime = 0,
	SessionCount = 0,
	LastSessionStart = 0,

	ProcessedReceipts = {},
}

return playerDataTemplate
