--!strict
--[=[
	@class ClassService
	@server
	Manages class selection, stats, and abilities for all players.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local PlayerDataService

local ClassService = Knit.CreateService({
	Name = "ClassService",
	ClassChanged = Signal.new(), -- (player, className)
	AbilityUsed = Signal.new(), -- (player, abilityName)

	Client = {
		ClassChanged = Knit.CreateSignal(),
		AbilityReady = Knit.CreateSignal(),
	},

	_playerClasses = {} :: { [Player]: string },
	_abilityCooldowns = {} :: { [Player]: number },
	_activeAbilities = {} :: { [Player]: { Name: string, EndTime: number }? },
	_playerTroves = {} :: { [Player]: any },
})

function ClassService:GetPlayerClass(player: Player): string
	return self._playerClasses[player] or "Vanguard"
end

function ClassService:GetClassConfig(className: string)
	return VoidArenaConfig.Classes[className]
end

function ClassService:SelectClass(player: Player, className: string): boolean
	if not VoidArenaConfig.Classes[className] then
		return false
	end

	self._playerClasses[player] = className
	self._abilityCooldowns[player] = 0
	self._activeAbilities[player] = nil

	-- Apply class stats to character
	self:_applyClassStats(player)

	-- Save preference
	task.spawn(function()
		PlayerDataService:Write(player, { "SelectedClass" }, className)
	end)

	self.ClassChanged:Fire(player, className)
	self.Client.ClassChanged:Fire(player, className)
	return true
end

function ClassService:_applyClassStats(player: Player)
	local className = self._playerClasses[player]
	if not className then
		return
	end

	local config = VoidArenaConfig.Classes[className]
	if not config then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = config.HP
		humanoid.Health = config.HP
		humanoid.WalkSpeed = config.Speed
	end
end

function ClassService:UseAbility(player: Player): (boolean, string?)
	local className = self._playerClasses[player]
	if not className then
		return false, "No class selected"
	end

	local config = VoidArenaConfig.Classes[className]
	if not config or not config.Ability then
		return false, "No ability"
	end

	local now = tick()
	local cooldownEnd = self._abilityCooldowns[player] or 0
	if now < cooldownEnd then
		return false, "On cooldown"
	end

	-- Check if player is alive
	local character = player.Character
	if not character then
		return false, "No character"
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Dead"
	end

	-- Set cooldown
	self._abilityCooldowns[player] = now + config.Ability.Cooldown

	-- Execute ability
	self:_executeAbility(player, className, config.Ability)

	self.AbilityUsed:Fire(player, config.Ability.Name)
	return true, nil
end

function ClassService:_executeAbility(player: Player, className: string, ability: any)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	if className == "Vanguard" then
		self:_deployShieldWall(player, rootPart, ability)
	elseif className == "Phantom" then
		self:_activatePhaseShift(player, character, ability)
	elseif className == "Sentinel" then
		self:_placeVoidTrap(player, rootPart, ability)
	elseif className == "Titan" then
		self:_activateFortress(player, ability)
	elseif className == "Technomancer" then
		self:_deployTurret(player, rootPart, ability)
	elseif className == "Wraith" then
		self:_executeBlink(player, rootPart)
	end

	-- Notify client cooldown started
	task.delay(ability.Cooldown, function()
		if player.Parent then
			self.Client.AbilityReady:Fire(player, true)
		end
	end)
end

function ClassService:_deployShieldWall(player: Player, rootPart: BasePart, ability: any)
	local wall = Instance.new("Part")
	wall.Name = "ShieldWall_" .. player.Name
	wall.Size = Vector3.new(10, 8, 2)
	wall.CFrame = rootPart.CFrame * CFrame.new(0, 0, -6)
	wall.Anchored = true
	wall.Material = Enum.Material.ForceField
	wall.Color = Color3.fromRGB(100, 50, 200)
	wall.Transparency = 0.3
	wall.CanCollide = true
	wall.Parent = workspace

	-- Health tracking via attribute
	wall:SetAttribute("Health", ability.ShieldHP)
	wall:SetAttribute("Owner", player.Name)

	task.delay(ability.Duration, function()
		if wall.Parent then
			wall:Destroy()
		end
	end)
end

function ClassService:_activatePhaseShift(player: Player, character: Model, ability: any)
	-- Make character invisible
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("PrePhaseTransparency", part.Transparency)
			part.Transparency = 1
		end
	end

	self._activeAbilities[player] = {
		Name = "PhaseShift",
		EndTime = tick() + ability.Duration,
	}

	task.delay(ability.Duration, function()
		if not character.Parent then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				local prev = part:GetAttribute("PrePhaseTransparency")
				part.Transparency = if prev then prev else 0
			end
		end
		if self._activeAbilities[player] and self._activeAbilities[player].Name == "PhaseShift" then
			self._activeAbilities[player] = nil
		end
	end)
end

function ClassService:_placeVoidTrap(player: Player, rootPart: BasePart, ability: any)
	local trap = Instance.new("Part")
	trap.Name = "VoidTrap_" .. player.Name
	trap.Size = Vector3.new(2, 0.5, 2)
	trap.Position = rootPart.Position - Vector3.new(0, 2.5, 0)
	trap.Anchored = true
	trap.Material = Enum.Material.Neon
	trap.Color = Color3.fromRGB(200, 0, 200)
	trap.Transparency = 0.6
	trap.CanCollide = false
	trap.Parent = workspace

	trap:SetAttribute("Owner", player.Name)
	trap:SetAttribute("Damage", ability.Damage)
	trap:SetAttribute("TriggerRadius", ability.TriggerRadius)
	trap:SetAttribute("ExplosionRadius", ability.ExplosionRadius)
	trap:SetAttribute("Active", true)

	local PlayerService = Knit.GetService("PlayerService")

	-- Check for enemies in range
	task.spawn(function()
		while trap.Parent and trap:GetAttribute("Active") do
			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer == player then
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
				local dist = (otherRoot.Position - trap.Position).Magnitude
				if dist <= ability.TriggerRadius then
					-- Explode
					trap:SetAttribute("Active", false)

					-- Deal AoE damage
					for _, hitPlayer in Players:GetPlayers() do
						if hitPlayer == player then
							continue
						end
						local hitChar = hitPlayer.Character
						if not hitChar then
							continue
						end
						local hitRoot = hitChar:FindFirstChild("HumanoidRootPart") :: BasePart?
						if not hitRoot then
							continue
						end
						if (hitRoot.Position - trap.Position).Magnitude <= ability.ExplosionRadius then
							PlayerService:DealDamage(player, hitPlayer, ability.Damage, false)
						end
					end

					-- Visual explosion
					local explosion = Instance.new("Part")
					explosion.Name = "TrapExplosion"
					explosion.Shape = Enum.PartType.Ball
					explosion.Size = Vector3.new(
						ability.ExplosionRadius * 2,
						ability.ExplosionRadius * 2,
						ability.ExplosionRadius * 2
					)
					explosion.Position = trap.Position
					explosion.Anchored = true
					explosion.Material = Enum.Material.Neon
					explosion.Color = Color3.fromRGB(200, 0, 200)
					explosion.Transparency = 0.5
					explosion.CanCollide = false
					explosion.Parent = workspace

					trap:Destroy()

					task.delay(0.3, function()
						if explosion.Parent then
							explosion:Destroy()
						end
					end)
					return
				end
			end
			task.wait(0.1)
		end
	end)

	-- Auto-remove after 30s
	task.delay(30, function()
		if trap.Parent then
			trap:Destroy()
		end
	end)
end

function ClassService:_activateFortress(player: Player, ability: any)
	self._activeAbilities[player] = {
		Name = "Fortress",
		EndTime = tick() + ability.Duration,
	}

	task.delay(ability.Duration, function()
		if self._activeAbilities[player] and self._activeAbilities[player].Name == "Fortress" then
			self._activeAbilities[player] = nil
		end
	end)
end

function ClassService:_deployTurret(player: Player, rootPart: BasePart, ability: any)
	local turret = Instance.new("Part")
	turret.Name = "Turret_" .. player.Name
	turret.Size = Vector3.new(3, 3, 3)
	turret.Position = rootPart.Position + rootPart.CFrame.LookVector * 5 + Vector3.new(0, 1, 0)
	turret.Anchored = true
	turret.Material = Enum.Material.Metal
	turret.Color = Color3.fromRGB(0, 200, 200)
	turret.CanCollide = true
	turret.Parent = workspace

	turret:SetAttribute("Owner", player.Name)
	turret:SetAttribute("Health", ability.TurretHP)

	local PlayerService = Knit.GetService("PlayerService")
	local GameModeService = Knit.GetService("GameModeService")

	-- Auto-fire at enemies
	task.spawn(function()
		while turret.Parent and turret:GetAttribute("Health") > 0 do
			local closestEnemy: Player? = nil
			local closestDist = ability.TurretRange

			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer == player then
					continue
				end
				if GameModeService:AreAllies(player, otherPlayer) then
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
				local dist = (otherRoot.Position - turret.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestEnemy = otherPlayer
				end
			end

			if closestEnemy then
				PlayerService:DealDamage(player, closestEnemy, ability.TurretDamage, false)

				-- Visual tracer
				local enemyChar = closestEnemy.Character
				if enemyChar then
					local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart") :: BasePart?
					if enemyRoot then
						local tracer = Instance.new("Part")
						tracer.Name = "TurretTracer"
						tracer.Anchored = true
						tracer.CanCollide = false
						tracer.Material = Enum.Material.Neon
						tracer.Color = Color3.fromRGB(0, 255, 255)

						local mid = (turret.Position + enemyRoot.Position) / 2
						local dist = (turret.Position - enemyRoot.Position).Magnitude
						tracer.Size = Vector3.new(0.2, 0.2, dist)
						tracer.CFrame = CFrame.lookAt(mid, enemyRoot.Position)
						tracer.Parent = workspace

						task.delay(0.1, function()
							if tracer.Parent then
								tracer:Destroy()
							end
						end)
					end
				end
			end

			task.wait(ability.TurretFireRate)
		end
	end)

	-- Auto-remove after duration
	task.delay(ability.Duration, function()
		if turret.Parent then
			turret:Destroy()
		end
	end)
end

function ClassService:_executeBlink(player: Player, rootPart: BasePart)
	local config = VoidArenaConfig.Classes.Wraith.Ability
	local direction = rootPart.CFrame.LookVector
	local newPosition = rootPart.Position + direction * config.Distance

	-- Raycast to avoid blinking through walls
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = workspace:Raycast(rootPart.Position, direction * config.Distance, rayParams)
	if result then
		newPosition = result.Position - direction * 2
	end

	rootPart.CFrame = CFrame.new(newPosition) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0)
end

function ClassService:GetDamageReduction(player: Player): number
	local activeAbility = self._activeAbilities[player]
	if activeAbility and activeAbility.Name == "Fortress" and tick() < activeAbility.EndTime then
		return VoidArenaConfig.Classes.Titan.Ability.DamageReduction
	end
	return 0
end

function ClassService:IsInvisible(player: Player): boolean
	local activeAbility = self._activeAbilities[player]
	if activeAbility and activeAbility.Name == "PhaseShift" and tick() < activeAbility.EndTime then
		return true
	end
	return false
end

function ClassService:BreakInvisibility(player: Player)
	local activeAbility = self._activeAbilities[player]
	if activeAbility and activeAbility.Name == "PhaseShift" then
		self._activeAbilities[player] = nil
		local character = player.Character
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					local prev = part:GetAttribute("PrePhaseTransparency")
					part.Transparency = if prev then prev else 0
				end
			end
		end
	end
end

function ClassService.Client:SelectClass(player: Player, className: string): boolean
	return self.Server:SelectClass(player, className)
end

function ClassService.Client:UseAbility(player: Player): (boolean, string?)
	return self.Server:UseAbility(player)
end

function ClassService.Client:GetPlayerClass(player: Player): string
	return self.Server:GetPlayerClass(player)
end

function ClassService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		self._playerClasses[player] = nil
		self._abilityCooldowns[player] = nil
		self._activeAbilities[player] = nil
		if self._playerTroves[player] then
			self._playerTroves[player]:Destroy()
			self._playerTroves[player] = nil
		end
	end)
end

function ClassService:KnitStart()
	PlayerDataService = Knit.GetService("PlayerDataService")

	-- When player spawns, apply class stats
	Players.PlayerAdded:Connect(function(player)
		self._playerTroves[player] = Trove.new()

		-- Load saved class
		task.spawn(function()
			PlayerDataService:WaitForProfile(player)
				:andThen(function()
					local savedClass = PlayerDataService:Read(player, { "SelectedClass" })
					if savedClass and VoidArenaConfig.Classes[savedClass] then
						self._playerClasses[player] = savedClass
					else
						self._playerClasses[player] = "Vanguard"
					end
				end)
				:catch(function(err)
					warn("Failed to load class for", player.Name, err)
					self._playerClasses[player] = "Vanguard"
				end)
		end)

		player.CharacterAdded:Connect(function()
			task.defer(function()
				self:_applyClassStats(player)
			end)
		end)
	end)
end

return ClassService
