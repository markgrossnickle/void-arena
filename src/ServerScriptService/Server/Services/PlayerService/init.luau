--!strict
--[=[
	@class PlayerService
	@server
	Manages player HP, death, respawn, kills, assists, and spawn protection.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local ClassService
local GameModeService
local ProgressionService

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	PlayerKilled = Signal.new(), -- (victim, killer, wasHeadshot)
	PlayerDied = Signal.new(), -- (player)

	Client = {
		PlayerKilled = Knit.CreateSignal(), -- broadcast to all clients
		DamageTaken = Knit.CreateSignal(), -- sent to damaged player
		SpawnProtectionChanged = Knit.CreateSignal(),
	},

	_killStreaks = {} :: { [Player]: number },
	_assists = {} :: { [Player]: { [Player]: number } }, -- victim -> { attacker -> damage }
	_spawnProtected = {} :: { [Player]: boolean },
	_lastDamageSource = {} :: { [Player]: Player? },
})

function PlayerService:DealDamage(attacker: Player, victim: Player, damage: number, isHeadshot: boolean)
	local character = victim.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Spawn protection check
	if self._spawnProtected[victim] then
		return
	end

	-- Break invisibility on attack
	if ClassService:IsInvisible(attacker) then
		ClassService:BreakInvisibility(attacker)
	end

	-- Apply headshot multiplier
	if isHeadshot then
		damage = damage * VoidArenaConfig.Weapon.HeadshotMultiplier
	end

	-- Apply damage reduction (Titan Fortress)
	local reduction = ClassService:GetDamageReduction(victim)
	if reduction > 0 then
		damage = damage * (1 - reduction)
	end

	-- Apply damage falloff
	local attackerChar = attacker.Character
	if attackerChar then
		local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local victimRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if attackerRoot and victimRoot then
			local dist = (attackerRoot.Position - victimRoot.Position).Magnitude
			if dist > VoidArenaConfig.Weapon.DamageFalloffRange then
				damage = damage * VoidArenaConfig.Weapon.DamageFalloffMultiplier
			end
		end
	end

	-- Track assist damage
	if not self._assists[victim] then
		self._assists[victim] = {}
	end
	self._assists[victim][attacker] = (self._assists[victim][attacker] or 0) + damage

	self._lastDamageSource[victim] = attacker

	humanoid:TakeDamage(damage)

	-- Notify victim
	self.Client.DamageTaken:Fire(victim, damage, attacker.Name, isHeadshot)
end

function PlayerService:_onPlayerDied(victim: Player)
	local killer = self._lastDamageSource[victim]

	-- Process kill
	if killer and killer ~= victim and killer.Parent then
		self._killStreaks[killer] = (self._killStreaks[killer] or 0) + 1

		-- Notify all clients of kill
		for _, p in Players:GetPlayers() do
			self.Client.PlayerKilled:Fire(p, killer.Name, victim.Name, self._killStreaks[killer])
		end

		self.PlayerKilled:Fire(victim, killer, false)

		-- Process assists (anyone who dealt damage to victim, except the killer)
		local assistData = self._assists[victim]
		if assistData then
			for assister, _ in assistData do
				if assister ~= killer and assister.Parent then
					if ProgressionService then
						ProgressionService:RecordAssist(assister)
					end
				end
			end
		end

		-- Record kill for progression
		if ProgressionService then
			ProgressionService:RecordKill(killer, victim)
		end

		-- Report to game mode
		if GameModeService then
			GameModeService:OnPlayerKill(killer, victim)
		end
	end

	-- Reset assists for victim
	self._assists[victim] = nil
	self._lastDamageSource[victim] = nil
	self._killStreaks[victim] = 0

	self.PlayerDied:Fire(victim)

	-- Schedule respawn
	self:_scheduleRespawn(victim)
end

function PlayerService:_scheduleRespawn(player: Player)
	local gameMode = if GameModeService then GameModeService:GetCurrentMode() else "TDM"
	local respawnTime = VoidArenaConfig.Match.RespawnTime[gameMode] or 3

	task.delay(respawnTime + VoidArenaConfig.Match.KillcamDuration, function()
		if not player.Parent then
			return
		end

		-- Respawn
		player:LoadCharacter()
	end)
end

function PlayerService:_applySpawnProtection(player: Player)
	self._spawnProtected[player] = true
	self.Client.SpawnProtectionChanged:Fire(player, true)

	task.delay(VoidArenaConfig.Match.SpawnProtectionDuration, function()
		self._spawnProtected[player] = false
		if player.Parent then
			self.Client.SpawnProtectionChanged:Fire(player, false)
		end
	end)
end

function PlayerService:GetKillStreak(player: Player): number
	return self._killStreaks[player] or 0
end

function PlayerService:IsSpawnProtected(player: Player): boolean
	return self._spawnProtected[player] == true
end

function PlayerService.Client:GetKillStreak(player: Player): number
	return self.Server:GetKillStreak(player)
end

function PlayerService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		self._killStreaks[player] = nil
		self._assists[player] = nil
		self._spawnProtected[player] = nil
		self._lastDamageSource[player] = nil
	end)
end

function PlayerService:KnitStart()
	ClassService = Knit.GetService("ClassService")
	GameModeService = Knit.GetService("GameModeService")
	ProgressionService = Knit.GetService("ProgressionService")

	Players.PlayerAdded:Connect(function(player)
		self._killStreaks[player] = 0

		player.CharacterAdded:Connect(function(character)
			-- Apply spawn protection
			self:_applySpawnProtection(player)

			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				self:_onPlayerDied(player)
			end)
		end)
	end)
end

return PlayerService
