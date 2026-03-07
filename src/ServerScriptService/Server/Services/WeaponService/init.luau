--!strict
--[=[
	@class WeaponService
	@server
	Handles shooting, damage calculation, projectiles, and ammo.
	Clients send fire requests; server validates and applies damage.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local ClassService
local PlayerService

local WeaponService = Knit.CreateService({
	Name = "WeaponService",

	Client = {
		WeaponFired = Knit.CreateSignal(), -- replicate shots to other clients
		HitConfirmed = Knit.CreateSignal(), -- confirm hit to shooter
		ReloadComplete = Knit.CreateSignal(),
	},

	_ammo = {} :: { [Player]: { Primary: number, Secondary: number } },
	_reloading = {} :: { [Player]: { Primary: boolean, Secondary: boolean } },
	_lastFireTime = {} :: { [Player]: { Primary: number, Secondary: number } },
})

function WeaponService:_getWeaponConfig(player: Player, slot: string)
	local className = ClassService:GetPlayerClass(player)
	local classConfig = VoidArenaConfig.Classes[className]
	if not classConfig then
		return nil
	end
	return if slot == "Primary" then classConfig.Primary else classConfig.Secondary
end

function WeaponService:_initPlayerAmmo(player: Player)
	local className = ClassService:GetPlayerClass(player)
	local classConfig = VoidArenaConfig.Classes[className]
	if not classConfig then
		return
	end
	self._ammo[player] = {
		Primary = classConfig.Primary.MaxAmmo,
		Secondary = classConfig.Secondary.MaxAmmo,
	}
	self._reloading[player] = { Primary = false, Secondary = false }
	self._lastFireTime[player] = { Primary = 0, Secondary = 0 }
end

function WeaponService:Fire(player: Player, slot: string, origin: Vector3, direction: Vector3): boolean
	local weaponConfig = self:_getWeaponConfig(player, slot)
	if not weaponConfig then
		return false
	end

	-- Check fire rate
	local now = tick()
	local lastFire = self._lastFireTime[player]
	if not lastFire then
		return false
	end
	local slotTime = if slot == "Primary" then lastFire.Primary else lastFire.Secondary
	if now - slotTime < weaponConfig.FireRate then
		return false
	end

	-- Check ammo
	local ammo = self._ammo[player]
	if not ammo then
		return false
	end
	local currentAmmo = if slot == "Primary" then ammo.Primary else ammo.Secondary
	if currentAmmo <= 0 then
		return false
	end

	-- Check reloading
	local reloading = self._reloading[player]
	if reloading then
		local isReloading = if slot == "Primary" then reloading.Primary else reloading.Secondary
		if isReloading then
			return false
		end
	end

	-- Consume ammo
	if slot == "Primary" then
		self._ammo[player].Primary -= 1
		self._lastFireTime[player].Primary = now
	else
		self._ammo[player].Secondary -= 1
		self._lastFireTime[player].Secondary = now
	end

	-- Process hit via raycast
	self:_processShot(player, weaponConfig, origin, direction)

	-- Replicate to other clients
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			self.Client.WeaponFired:Fire(otherPlayer, player.Name, slot, origin, direction)
		end
	end

	return true
end

function WeaponService:_processShot(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	-- Validate origin is near player
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Allow some tolerance for network latency
	if (origin - rootPart.Position).Magnitude > 15 then
		return
	end

	local normalizedDir = direction.Unit

	if weaponConfig.IsMelee then
		self:_processMelee(player, weaponConfig, origin, normalizedDir)
	elseif weaponConfig.IsGrenade then
		self:_processGrenade(player, weaponConfig, origin, normalizedDir)
	elseif weaponConfig.IsBeam then
		self:_processBeam(player, weaponConfig, origin, normalizedDir)
	elseif weaponConfig.PelletCount then
		self:_processShotgun(player, weaponConfig, origin, normalizedDir)
	else
		self:_processRaycast(player, weaponConfig, origin, normalizedDir)
	end
end

function WeaponService:_processRaycast(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	local result = workspace:Raycast(origin, direction * weaponConfig.Range, rayParams)
	if not result then
		return
	end

	-- Check if hit a player
	local hitPart = result.Instance
	local hitCharacter = hitPart:FindFirstAncestorOfClass("Model")
	if not hitCharacter then
		return
	end

	local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
	if not hitPlayer or hitPlayer == player then
		return
	end

	local isHeadshot = hitPart.Name == "Head"
	PlayerService:DealDamage(player, hitPlayer, weaponConfig.Damage, isHeadshot)
	self.Client.HitConfirmed:Fire(player, hitPlayer.Name, isHeadshot)
end

function WeaponService:_processMelee(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	if weaponConfig.IsAoE then
		-- AoE melee (Titan fist slam)
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
			if (otherRoot.Position - origin).Magnitude <= (weaponConfig.AoERadius or weaponConfig.Range) then
				PlayerService:DealDamage(player, otherPlayer, weaponConfig.Damage, false)
				self.Client.HitConfirmed:Fire(player, otherPlayer.Name, false)
			end
		end
	else
		-- Single target melee
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { player.Character }

		local result = workspace:Raycast(origin, direction * weaponConfig.Range, rayParams)
		if not result then
			return
		end

		local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
		if not hitCharacter then
			return
		end
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
		if not hitPlayer or hitPlayer == player then
			return
		end

		PlayerService:DealDamage(player, hitPlayer, weaponConfig.Damage, false)
		self.Client.HitConfirmed:Fire(player, hitPlayer.Name, false)
	end
end

function WeaponService:_processShotgun(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	local pelletDamage = weaponConfig.Damage / weaponConfig.PelletCount
	local spreadRad = math.rad(weaponConfig.SpreadAngle)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	for _ = 1, weaponConfig.PelletCount do
		local spreadX = (math.random() - 0.5) * 2 * spreadRad
		local spreadY = (math.random() - 0.5) * 2 * spreadRad
		local spreadDir = CFrame.new(Vector3.zero, direction) * CFrame.Angles(spreadY, spreadX, 0)
		local pelletDir = spreadDir.LookVector

		local result = workspace:Raycast(origin, pelletDir * weaponConfig.Range, rayParams)
		if result then
			local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
			if hitCharacter then
				local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
				if hitPlayer and hitPlayer ~= player then
					local isHeadshot = result.Instance.Name == "Head"
					PlayerService:DealDamage(player, hitPlayer, pelletDamage, isHeadshot)
					self.Client.HitConfirmed:Fire(player, hitPlayer.Name, isHeadshot)
				end
			end
		end
	end
end

function WeaponService:_processBeam(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	-- Beam weapon - basically a raycast but continuous
	self:_processRaycast(player, weaponConfig, origin, direction)
end

function WeaponService:_processGrenade(player: Player, weaponConfig: any, origin: Vector3, direction: Vector3)
	-- Spawn grenade part on server
	local grenade = Instance.new("Part")
	grenade.Name = "Grenade_" .. player.Name
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(1.5, 1.5, 1.5)
	grenade.Position = origin + direction * 2
	grenade.Material = Enum.Material.Neon
	grenade.Color = Color3.fromRGB(0, 200, 255)
	grenade.CanCollide = true
	grenade.Anchored = false
	grenade.Parent = workspace

	-- Apply velocity
	grenade:SetNetworkOwner(nil) -- server-owned
	local velocity = direction * weaponConfig.ProjectileSpeed + Vector3.new(0, 30, 0)
	grenade.AssemblyLinearVelocity = velocity

	-- Detonate after 2 seconds
	task.delay(2, function()
		if not grenade.Parent then
			return
		end
		local pos = grenade.Position

		-- Deal AoE damage
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
			if (otherRoot.Position - pos).Magnitude <= weaponConfig.ExplosionRadius then
				PlayerService:DealDamage(player, otherPlayer, weaponConfig.Damage, false)

				-- Stun effect
				if weaponConfig.StunDuration and weaponConfig.StunDuration > 0 then
					local humanoid = otherChar:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local prevSpeed = humanoid.WalkSpeed
						humanoid.WalkSpeed = 0
						task.delay(weaponConfig.StunDuration, function()
							if humanoid.Parent then
								humanoid.WalkSpeed = prevSpeed
							end
						end)
					end
				end
			end
		end

		-- Explosion visual
		local explosion = Instance.new("Part")
		explosion.Shape = Enum.PartType.Ball
		explosion.Size = Vector3.new(weaponConfig.ExplosionRadius * 2, weaponConfig.ExplosionRadius * 2, weaponConfig.ExplosionRadius * 2)
		explosion.Position = pos
		explosion.Anchored = true
		explosion.Material = Enum.Material.Neon
		explosion.Color = Color3.fromRGB(0, 200, 255)
		explosion.Transparency = 0.5
		explosion.CanCollide = false
		explosion.Parent = workspace

		grenade:Destroy()

		task.delay(0.3, function()
			if explosion.Parent then
				explosion:Destroy()
			end
		end)
	end)
end

function WeaponService:Reload(player: Player, slot: string)
	local weaponConfig = self:_getWeaponConfig(player, slot)
	if not weaponConfig then
		return
	end
	if weaponConfig.ReloadTime == 0 then
		return
	end

	local reloading = self._reloading[player]
	if not reloading then
		return
	end

	local isReloading = if slot == "Primary" then reloading.Primary else reloading.Secondary
	if isReloading then
		return
	end

	if slot == "Primary" then
		self._reloading[player].Primary = true
	else
		self._reloading[player].Secondary = true
	end

	task.delay(weaponConfig.ReloadTime, function()
		if not self._ammo[player] then
			return
		end
		if slot == "Primary" then
			self._ammo[player].Primary = weaponConfig.MaxAmmo
			self._reloading[player].Primary = false
		else
			self._ammo[player].Secondary = weaponConfig.MaxAmmo
			self._reloading[player].Secondary = false
		end

		if player.Parent then
			self.Client.ReloadComplete:Fire(player, slot)
		end
	end)
end

function WeaponService:GetAmmo(player: Player): { Primary: number, Secondary: number }?
	return self._ammo[player]
end

function WeaponService.Client:Fire(player: Player, slot: string, origin: Vector3, direction: Vector3): boolean
	return self.Server:Fire(player, slot, origin, direction)
end

function WeaponService.Client:Reload(player: Player, slot: string)
	self.Server:Reload(player, slot)
end

function WeaponService.Client:GetAmmo(player: Player): { Primary: number, Secondary: number }?
	return self.Server:GetAmmo(player)
end

function WeaponService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		self._ammo[player] = nil
		self._reloading[player] = nil
		self._lastFireTime[player] = nil
	end)
end

function WeaponService:KnitStart()
	ClassService = Knit.GetService("ClassService")
	PlayerService = Knit.GetService("PlayerService")

	-- Re-init ammo on class change
	ClassService.ClassChanged:Connect(function(player: Player, _className: string)
		self:_initPlayerAmmo(player)
	end)

	-- Init ammo on spawn
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				self:_initPlayerAmmo(player)
			end)
		end)
	end)
end

return WeaponService
