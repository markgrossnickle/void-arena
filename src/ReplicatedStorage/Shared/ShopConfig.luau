--!strict
--[=[
	@class ShopConfig
	Shared configuration for the in-game cosmetic shop.
]=]

export type ShopItem = {
	Id: string,
	Name: string,
	Category: string,
	Price: number,
	Currency: string,
	Icon: string,
	Description: string,
	OneTimePurchase: boolean,
}

export type CurrencyDefinition = {
	Name: string,
	Icon: string,
	DisplayOrder: number,
}

local Currencies: { [string]: CurrencyDefinition } = {
	Coins = { Name = "Coins", Icon = "rbxassetid://0", DisplayOrder = 1 },
	Gems = { Name = "Gems", Icon = "rbxassetid://0", DisplayOrder = 2 },
}

local CategoryOrder: { string } = {
	"Weapon Skins",
	"Accessories",
	"Kill Effects",
	"Boosts",
}

local Items: { ShopItem } = {
	-- Weapon Skins
	{
		Id = "skin_void_purple",
		Name = "Void Purple",
		Category = "Weapon Skins",
		Price = 200,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Deep purple glow on all weapons",
		OneTimePurchase = true,
	},
	{
		Id = "skin_crystal_cyan",
		Name = "Crystal Cyan",
		Category = "Weapon Skins",
		Price = 300,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Icy cyan crystal coating",
		OneTimePurchase = true,
	},
	{
		Id = "skin_flame_red",
		Name = "Flame Red",
		Category = "Weapon Skins",
		Price = 300,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Fiery red embers on weapons",
		OneTimePurchase = true,
	},
	{
		Id = "skin_shadow_black",
		Name = "Shadow Black",
		Category = "Weapon Skins",
		Price = 500,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Matte black with dark aura",
		OneTimePurchase = true,
	},
	{
		Id = "skin_gold_elite",
		Name = "Gold Elite",
		Category = "Weapon Skins",
		Price = 1000,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Prestigious golden finish",
		OneTimePurchase = true,
	},

	-- Accessories
	{
		Id = "acc_void_crown",
		Name = "Void Crown",
		Category = "Accessories",
		Price = 400,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "A crown made of void energy",
		OneTimePurchase = true,
	},
	{
		Id = "acc_neon_aura",
		Name = "Neon Aura",
		Category = "Accessories",
		Price = 350,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Glowing neon particle aura",
		OneTimePurchase = true,
	},
	{
		Id = "acc_trail_purple",
		Name = "Void Trail",
		Category = "Accessories",
		Price = 250,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Purple particle trail when moving",
		OneTimePurchase = true,
	},

	-- Kill Effects
	{
		Id = "kill_void_explosion",
		Name = "Void Explosion",
		Category = "Kill Effects",
		Price = 500,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Enemies explode in void particles",
		OneTimePurchase = true,
	},
	{
		Id = "kill_crystal_shatter",
		Name = "Crystal Shatter",
		Category = "Kill Effects",
		Price = 500,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Enemies shatter like crystal",
		OneTimePurchase = true,
	},
	{
		Id = "kill_lightning_strike",
		Name = "Lightning Strike",
		Category = "Kill Effects",
		Price = 750,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "Lightning strikes on elimination",
		OneTimePurchase = true,
	},

	-- Boosts
	{
		Id = "boost_double_xp",
		Name = "Double XP (1 Match)",
		Category = "Boosts",
		Price = 100,
		Currency = "Coins",
		Icon = "rbxassetid://0",
		Description = "2x XP for your next match",
		OneTimePurchase = false,
	},
	{
		Id = "boost_double_coins",
		Name = "Double Coins (1 Match)",
		Category = "Boosts",
		Price = 5,
		Currency = "Gems",
		Icon = "rbxassetid://0",
		Description = "2x Coins for your next match",
		OneTimePurchase = false,
	},
}

-- Build lookup table by Id
local ItemsById: { [string]: ShopItem } = {}
for _, item in Items do
	ItemsById[item.Id] = item
end

-- Build items grouped by category
local ItemsByCategory: { [string]: { ShopItem } } = {}
for _, item in Items do
	if not ItemsByCategory[item.Category] then
		ItemsByCategory[item.Category] = {}
	end
	table.insert(ItemsByCategory[item.Category], item)
end

return {
	Currencies = Currencies,
	CategoryOrder = CategoryOrder,
	Items = Items,
	ItemsById = ItemsById,
	ItemsByCategory = ItemsByCategory,
}
