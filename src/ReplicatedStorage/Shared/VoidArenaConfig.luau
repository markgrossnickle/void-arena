--!strict
--[=[
	@class VoidArenaConfig
	Central configuration for Void Arena - all game constants.
]=]

local VoidArenaConfig = {
	-- Match settings
	Match = {
		Duration = 300, -- 5 minutes
		RespawnTime = {
			TDM = 3,
			FFA = 2,
			Domination = 4,
		},
		SpawnProtectionDuration = 2,
		KillcamDuration = 2,
	},

	-- Game mode settings
	GameModes = {
		TDM = {
			Name = "Team Deathmatch",
			KillsToWin = 30,
			MaxPlayers = 10,
			TeamsRequired = true,
		},
		FFA = {
			Name = "Free-for-All",
			KillsToWin = 20,
			MaxPlayers = 8,
			TeamsRequired = false,
		},
		Domination = {
			Name = "Domination",
			PointsToWin = 200,
			MaxPlayers = 10,
			TeamsRequired = true,
			CaptureTime = 5,
			PointsPerSecond = 1,
		},
	},

	-- Class definitions
	Classes = {
		Vanguard = {
			Name = "Vanguard",
			Description = "Balanced frontliner with deployable cover",
			HP = 150,
			Speed = 15,
			Primary = {
				Name = "Void Rifle",
				Damage = 15,
				FireRate = 0.2, -- seconds between shots
				MaxAmmo = 24,
				ReloadTime = 2.0,
				ProjectileSpeed = 300,
				Automatic = false,
				Range = 120,
			},
			Secondary = {
				Name = "Sidearm",
				Damage = 10,
				FireRate = 0.15,
				MaxAmmo = 12,
				ReloadTime = 1.5,
				ProjectileSpeed = 280,
				Automatic = false,
				Range = 80,
			},
			Ability = {
				Name = "Shield Wall",
				Description = "Deploy cover (200HP, 8s)",
				Cooldown = 15,
				Duration = 8,
				ShieldHP = 200,
			},
		},
		Phantom = {
			Name = "Phantom",
			Description = "Stealthy flanker with invisibility",
			HP = 100,
			Speed = 19,
			Primary = {
				Name = "Shadow SMG",
				Damage = 8,
				FireRate = 0.08,
				MaxAmmo = 30,
				ReloadTime = 1.8,
				ProjectileSpeed = 260,
				Automatic = true,
				Range = 60,
			},
			Secondary = {
				Name = "Void Blade",
				Damage = 35,
				FireRate = 0.6,
				MaxAmmo = math.huge,
				ReloadTime = 0,
				ProjectileSpeed = 0, -- melee
				Automatic = false,
				Range = 8,
				IsMelee = true,
			},
			Ability = {
				Name = "Phase Shift",
				Description = "Invisible for 3s (breaks on attack)",
				Cooldown = 18,
				Duration = 3,
			},
		},
		Sentinel = {
			Name = "Sentinel",
			Description = "Long-range marksman with traps",
			HP = 125,
			Speed = 16,
			Primary = {
				Name = "Pulse Sniper",
				Damage = 50,
				FireRate = 1.2,
				MaxAmmo = 5,
				ReloadTime = 2.5,
				ProjectileSpeed = 500,
				Automatic = false,
				Range = 200,
			},
			Secondary = {
				Name = "Sidearm",
				Damage = 10,
				FireRate = 0.15,
				MaxAmmo = 12,
				ReloadTime = 1.5,
				ProjectileSpeed = 280,
				Automatic = false,
				Range = 80,
			},
			Ability = {
				Name = "Void Trap",
				Description = "Proximity mine (60 AoE damage)",
				Cooldown = 12,
				Damage = 60,
				TriggerRadius = 8,
				ExplosionRadius = 12,
			},
		},
		Titan = {
			Name = "Titan",
			Description = "Heavy tank with damage reduction",
			HP = 200,
			Speed = 12,
			Primary = {
				Name = "Void Shotgun",
				Damage = 40, -- total spread damage
				FireRate = 0.8,
				MaxAmmo = 6,
				ReloadTime = 2.5,
				ProjectileSpeed = 200,
				Automatic = false,
				Range = 30,
				PelletCount = 8,
				SpreadAngle = 12,
			},
			Secondary = {
				Name = "Fist Slam",
				Damage = 25,
				FireRate = 1.0,
				MaxAmmo = math.huge,
				ReloadTime = 0,
				ProjectileSpeed = 0,
				Automatic = false,
				Range = 10,
				IsMelee = true,
				IsAoE = true,
				AoERadius = 8,
			},
			Ability = {
				Name = "Fortress",
				Description = "+50% damage reduction for 4s",
				Cooldown = 20,
				Duration = 4,
				DamageReduction = 0.5,
			},
		},
		Technomancer = {
			Name = "Technomancer",
			Description = "Tech specialist with deployable turret",
			HP = 110,
			Speed = 17,
			Primary = {
				Name = "Arc Caster",
				Damage = 12, -- per tick
				FireRate = 0.1, -- tick rate
				MaxAmmo = 60,
				ReloadTime = 2.0,
				ProjectileSpeed = 0, -- beam weapon
				Automatic = true,
				Range = 40,
				IsBeam = true,
			},
			Secondary = {
				Name = "Shock Grenade",
				Damage = 30,
				FireRate = 1.5,
				MaxAmmo = 2,
				ReloadTime = 3.0,
				ProjectileSpeed = 80,
				Automatic = false,
				Range = 60,
				IsGrenade = true,
				StunDuration = 1,
				ExplosionRadius = 10,
			},
			Ability = {
				Name = "Turret",
				Description = "Auto-firing turret (30HP, 8dmg, 10s)",
				Cooldown = 22,
				Duration = 10,
				TurretHP = 30,
				TurretDamage = 8,
				TurretFireRate = 0.5,
				TurretRange = 40,
			},
		},
		Wraith = {
			Name = "Wraith",
			Description = "Ultra-fast assassin with teleport",
			HP = 90,
			Speed = 20,
			Primary = {
				Name = "Dual Void Pistols",
				Damage = 15,
				FireRate = 0.12,
				MaxAmmo = 20,
				ReloadTime = 1.5,
				ProjectileSpeed = 300,
				Automatic = false,
				Range = 70,
			},
			Secondary = {
				Name = "Void Dagger",
				Damage = 40,
				FireRate = 0.5,
				MaxAmmo = math.huge,
				ReloadTime = 0,
				ProjectileSpeed = 0,
				Automatic = false,
				Range = 8,
				IsMelee = true,
			},
			Ability = {
				Name = "Blink",
				Description = "Teleport 20 studs in aim direction",
				Cooldown = 8,
				Distance = 20,
			},
		},
	},

	-- Weapon constants
	Weapon = {
		HeadshotMultiplier = 1.5,
		DamageFalloffRange = 80,
		DamageFalloffMultiplier = 0.7,
		AmmoRefillInterval = 30,
		RecoilRecoveryTime = 0.3,
		CrosshairBaseSize = 4,
		CrosshairBloomMax = 16,
		CrosshairBloomDecay = 0.85,
	},

	-- Progression
	Progression = {
		XPPerKill = 10,
		XPPerAssist = 5,
		XPPerObjective = 15,
		WinBonus = 50,
		MaxLevel = 50,
		CoinsPerKill = 2,
		CoinsPerWin = 10,
		CoinsPerAssist = 1,
	},

	-- Map names
	Maps = {
		"VoidPlatform",
		"CrystalRuins",
		"FungalCavern",
		"AbyssalFortress",
	},

	-- Map-GameMode compatibility
	MapModes = {
		VoidPlatform = { "FFA" },
		CrystalRuins = { "TDM" },
		FungalCavern = { "Domination" },
		AbyssalFortress = { "TDM", "Domination" },
	},

	-- Domination capture point positions (per map)
	CapturePoints = {
		FungalCavern = {
			{ Name = "Alpha", Position = Vector3.new(-30, 5, 0) },
			{ Name = "Bravo", Position = Vector3.new(0, 5, 0) },
			{ Name = "Charlie", Position = Vector3.new(30, 5, 0) },
		},
		AbyssalFortress = {
			{ Name = "Alpha", Position = Vector3.new(-40, 10, 0) },
			{ Name = "Bravo", Position = Vector3.new(0, 15, 0) },
			{ Name = "Charlie", Position = Vector3.new(40, 10, 0) },
		},
	},

	-- Team colors
	Teams = {
		Team1 = {
			Name = "Void",
			Color = Color3.fromRGB(100, 50, 200),
			BrickColor = BrickColor.new("Royal purple"),
		},
		Team2 = {
			Name = "Abyss",
			Color = Color3.fromRGB(0, 200, 200),
			BrickColor = BrickColor.new("Teal"),
		},
	},

	-- Mobile / platform settings
	Mobile = {
		AimAssistAngle = 5, -- degrees
		AutoFireEnabled = true,
		ReducedParticles = true,
		ParticleReduction = 0.5,
	},
}

return VoidArenaConfig
