--!strict
--[=[
	@class WeaponController
	@client
	Handles crosshair, firing, reload, ammo display, recoil, and weapon effects.
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
local Camera = workspace.CurrentCamera

local WeaponController = Knit.CreateController({
	Name = "WeaponController",
	_trove = Trove.new(),
	_currentSlot = "Primary" :: string,
	_ammo = { Primary = 0, Secondary = 0 },
	_firing = false,
	_bloom = 0,
	_recoilOffset = 0,
	_crosshairGui = nil :: ScreenGui?,
	_ammoGui = nil :: ScreenGui?,
	_lastFireTime = 0,
})

function WeaponController:_getWeaponConfig()
	local ClassController = Knit.GetController("ClassController")
	local className = ClassController:GetSelectedClass()
	local classConfig = VoidArenaConfig.Classes[className]
	if not classConfig then
		return nil
	end
	return if self._currentSlot == "Primary" then classConfig.Primary else classConfig.Secondary
end

function WeaponController:Fire()
	local config = self:_getWeaponConfig()
	if not config then
		return
	end

	local now = tick()
	if now - self._lastFireTime < config.FireRate then
		return
	end

	local ammo = self._ammo[self._currentSlot]
	if ammo <= 0 then
		self:Reload()
		return
	end

	self._lastFireTime = now

	-- Get aim direction from camera
	local character = Player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local origin = rootPart.Position + Vector3.new(0, 1.5, 0)
	local direction = Camera.CFrame.LookVector

	-- Apply bloom to direction
	if self._bloom > 0 then
		local bloomRad = math.rad(self._bloom)
		local spreadX = (math.random() - 0.5) * 2 * bloomRad
		local spreadY = (math.random() - 0.5) * 2 * bloomRad
		direction = (CFrame.new(Vector3.zero, direction) * CFrame.Angles(spreadY, spreadX, 0)).LookVector
	end

	-- Send to server
	local WeaponService = Knit.GetService("WeaponService")
	WeaponService:Fire(self._currentSlot, origin, direction)

	-- Client-side effects
	self:_muzzleFlash(origin + direction * 2)
	self:_createLocalTracer(origin, direction, config)
	self:_applyRecoil(config)
	self:_addBloom(2)

	-- Update ammo locally (optimistic)
	self._ammo[self._currentSlot] = math.max(0, ammo - 1)
	self:_updateAmmoDisplay()
end

function WeaponController:Reload()
	local config = self:_getWeaponConfig()
	if not config or config.ReloadTime == 0 then
		return
	end

	local WeaponService = Knit.GetService("WeaponService")
	WeaponService:Reload(self._currentSlot)
end

function WeaponController:SwitchWeapon()
	self._currentSlot = if self._currentSlot == "Primary" then "Secondary" else "Primary"
	self._bloom = 0
	self:_updateAmmoDisplay()
end

function WeaponController:_applyRecoil(config: any)
	self._recoilOffset += 0.5
	-- Camera kick up
	local cameraCF = Camera.CFrame
	Camera.CFrame = cameraCF * CFrame.Angles(math.rad(-self._recoilOffset * 0.3), 0, 0)
end

function WeaponController:_addBloom(amount: number)
	self._bloom = math.min(self._bloom + amount, VoidArenaConfig.Weapon.CrosshairBloomMax)
end

function WeaponController:_muzzleFlash(position: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Size = Vector3.new(0.5, 0.5, 0.5)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 200, 50)
	flash.Transparency = 0.3
	flash.Parent = workspace

	task.delay(0.05, function()
		if flash.Parent then
			flash:Destroy()
		end
	end)
end

function WeaponController:_createLocalTracer(origin: Vector3, direction: Vector3, config: any)
	local range = config.Range or 120
	local character = Player.Character

	-- Skip tracer for melee weapons
	if config.IsMelee then
		return
	end

	-- Client-side raycast to find hit distance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if character then
		params.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(origin, direction * range, params)
	local hitDistance = if result then result.Distance else range

	-- Create tracer beam
	local tracer = Instance.new("Part")
	tracer.Name = "LocalTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(200, 100, 255)
	tracer.Size = Vector3.new(0.08, 0.08, math.min(hitDistance, range))
	tracer.CFrame = CFrame.lookAt(origin + direction * (hitDistance / 2), origin + direction * hitDistance)
	tracer.Transparency = 0.3
	tracer.Parent = workspace

	-- Fade out
	task.delay(0.06, function()
		if tracer.Parent then
			tracer:Destroy()
		end
	end)

	-- Hit spark at impact point
	if result then
		local spark = Instance.new("Part")
		spark.Name = "HitSpark"
		spark.Size = Vector3.new(0.4, 0.4, 0.4)
		spark.Position = result.Position
		spark.Anchored = true
		spark.CanCollide = false
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(255, 200, 100)
		spark.Shape = Enum.PartType.Ball
		spark.Parent = workspace

		task.delay(0.08, function()
			if spark.Parent then
				spark:Destroy()
			end
		end)
	end
end

function WeaponController:_createTracerEffect(origin: Vector3, direction: Vector3, distance: number)
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(200, 100, 255)
	tracer.Size = Vector3.new(0.1, 0.1, math.min(distance, 20))

	local mid = origin + direction * (distance / 2)
	tracer.CFrame = CFrame.lookAt(mid, origin + direction * distance)
	tracer.Parent = workspace

	task.delay(0.08, function()
		if tracer.Parent then
			tracer:Destroy()
		end
	end)
end

function WeaponController:_createCrosshair()
	if self._crosshairGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CrosshairGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Player.PlayerGui
	self._crosshairGui = gui

	-- Center dot
	local dot = Instance.new("Frame")
	dot.Name = "CenterDot"
	dot.Size = UDim2.fromOffset(4, 4)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = gui

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot

	-- Crosshair lines (4 directions)
	local directions = {
		{
			name = "Top",
			pos = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 1),
			size = UDim2.fromOffset(2, 8),
			offsetY = -6,
		},
		{
			name = "Bottom",
			pos = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(2, 8),
			offsetY = 6,
		},
		{
			name = "Left",
			pos = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(1, 0.5),
			size = UDim2.fromOffset(8, 2),
			offsetX = -6,
		},
		{
			name = "Right",
			pos = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0, 0.5),
			size = UDim2.fromOffset(8, 2),
			offsetX = 6,
		},
	}

	for _, dir in directions do
		local line = Instance.new("Frame")
		line.Name = "Crosshair_" .. dir.name
		line.Size = dir.size
		line.AnchorPoint = dir.anchor
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.Parent = gui

		-- Position will be updated dynamically based on bloom
		line:SetAttribute("BaseOffsetX", dir.offsetX or 0)
		line:SetAttribute("BaseOffsetY", dir.offsetY or 0)
	end
end

function WeaponController:_updateCrosshair()
	if not self._crosshairGui then
		return
	end

	local bloomOffset = VoidArenaConfig.Weapon.CrosshairBaseSize + self._bloom

	for _, child in self._crosshairGui:GetChildren() do
		if child:IsA("Frame") and child.Name:sub(1, 9) == "Crosshair" then
			local baseX = child:GetAttribute("BaseOffsetX") or 0
			local baseY = child:GetAttribute("BaseOffsetY") or 0

			local scale = bloomOffset / VoidArenaConfig.Weapon.CrosshairBaseSize
			local offsetX = baseX * scale
			local offsetY = baseY * scale

			child.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
		end
	end
end

function WeaponController:_createAmmoDisplay()
	if self._ammoGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AmmoGui"
	gui.ResetOnSpawn = false
	gui.Parent = Player.PlayerGui
	self._ammoGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "AmmoFrame"
	frame.Size = UDim2.fromScale(0.1, 0.06)
	frame.Position = UDim2.fromScale(0.85, 0.85)
	frame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 50, 200)
	stroke.Thickness = 1
	stroke.Parent = frame

	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoCount"
	ammoLabel.Size = UDim2.fromScale(0.6, 0.8)
	ammoLabel.Position = UDim2.fromScale(0.05, 0.1)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = "0/0"
	ammoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoLabel.TextScaled = true
	ammoLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ammoLabel.Parent = frame

	local slotLabel = Instance.new("TextLabel")
	slotLabel.Name = "SlotLabel"
	slotLabel.Size = UDim2.fromScale(0.35, 0.5)
	slotLabel.Position = UDim2.fromScale(0.62, 0.05)
	slotLabel.BackgroundTransparency = 1
	slotLabel.Text = "PRIMARY"
	slotLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
	slotLabel.TextScaled = true
	slotLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	slotLabel.Parent = frame

	-- Weapon name
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponName"
	weaponLabel.Size = UDim2.fromScale(0.35, 0.4)
	weaponLabel.Position = UDim2.fromScale(0.62, 0.55)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = ""
	weaponLabel.TextColor3 = Color3.fromRGB(200, 150, 255)
	weaponLabel.TextScaled = true
	weaponLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	weaponLabel.Parent = frame
end

function WeaponController:_updateAmmoDisplay()
	if not self._ammoGui then
		return
	end

	local frame = self._ammoGui:FindFirstChild("AmmoFrame")
	if not frame then
		return
	end

	local config = self:_getWeaponConfig()
	local ammo = self._ammo[self._currentSlot]
	local maxAmmo = if config then config.MaxAmmo else 0

	local ammoLabel = frame:FindFirstChild("AmmoCount") :: TextLabel?
	if ammoLabel then
		if maxAmmo == math.huge then
			ammoLabel.Text = "INF"
		else
			ammoLabel.Text = string.format("%d/%d", ammo, maxAmmo)
		end
	end

	local slotLabel = frame:FindFirstChild("SlotLabel") :: TextLabel?
	if slotLabel then
		slotLabel.Text = string.upper(self._currentSlot)
	end

	local weaponLabel = frame:FindFirstChild("WeaponName") :: TextLabel?
	if weaponLabel and config then
		weaponLabel.Text = config.Name
	end
end

function WeaponController:KnitInit() end

function WeaponController:KnitStart()
	local WeaponService = Knit.GetService("WeaponService")
	local InputController = Knit.GetController("InputController")

	-- Create UI
	self:_createCrosshair()
	self:_createAmmoDisplay()

	-- Fire input
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._firing = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._firing = false
		end
	end)

	-- Gamepad fire (RT)
	InputController:RegisterInput("Fire", function(inputState)
		self._firing = inputState == Enum.UserInputState.Begin
	end, false, { Enum.KeyCode.ButtonR2 })

	-- Reload (R key or gamepad B)
	InputController:RegisterInput("Reload", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:Reload()
		end
	end, false, { Enum.KeyCode.R, Enum.KeyCode.ButtonB })

	-- Weapon switch (number keys or gamepad Y)
	InputController:RegisterInput("SwitchWeapon", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:SwitchWeapon()
		end
	end, false, { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.ButtonY })

	-- Listen for reload completion
	WeaponService.ReloadComplete:Connect(function(slot)
		local config = self:_getWeaponConfig()
		if config then
			self._ammo[slot] = config.MaxAmmo
			self:_updateAmmoDisplay()
		end
	end)

	-- Listen for other players' shots (visual effects)
	WeaponService.WeaponFired:Connect(function(shooterName, slot, origin, direction)
		self:_createTracerEffect(origin, direction, 50)
	end)

	-- Hit confirmation
	WeaponService.HitConfirmed:Connect(function(victimName, isHeadshot)
		-- Flash crosshair red
		if self._crosshairGui then
			local dot = self._crosshairGui:FindFirstChild("CenterDot") :: Frame?
			if dot then
				dot.BackgroundColor3 = if isHeadshot then Color3.fromRGB(255, 255, 0) else Color3.fromRGB(255, 0, 0)
				task.delay(0.15, function()
					if dot.Parent then
						dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					end
				end)
			end
		end
	end)

	-- Mobile fire button
	if PlatformUtil.IsMobile() then
		local fireBtn = Instance.new("TextButton")
		fireBtn.Name = "FireButton"
		fireBtn.Size = UDim2.fromOffset(72, 72)
		fireBtn.Position = UDim2.fromScale(0.88, 0.45)
		fireBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		fireBtn.BackgroundTransparency = 0.3
		fireBtn.Text = "FIRE"
		fireBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		fireBtn.TextScaled = true
		fireBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		fireBtn.Parent = self._ammoGui

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0.5, 0)
		btnCorner.Parent = fireBtn

		fireBtn.MouseButton1Down:Connect(function()
			self._firing = true
		end)
		fireBtn.MouseButton1Up:Connect(function()
			self._firing = false
		end)

		-- Reload button
		local reloadBtn = Instance.new("TextButton")
		reloadBtn.Name = "ReloadButton"
		reloadBtn.Size = UDim2.fromOffset(56, 56)
		reloadBtn.Position = UDim2.fromScale(0.75, 0.55)
		reloadBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
		reloadBtn.BackgroundTransparency = 0.3
		reloadBtn.Text = "R"
		reloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		reloadBtn.TextScaled = true
		reloadBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		reloadBtn.Parent = self._ammoGui

		local reloadCorner = Instance.new("UICorner")
		reloadCorner.CornerRadius = UDim.new(0.5, 0)
		reloadCorner.Parent = reloadBtn

		reloadBtn.Activated:Connect(function()
			self:Reload()
		end)
	end

	-- Main update loop
	self._trove:Connect(RunService.RenderStepped, function(dt)
		-- Auto-fire for automatic weapons
		if self._firing then
			local config = self:_getWeaponConfig()
			if config and config.Automatic then
				self:Fire()
			elseif config and not config.Automatic and self._firing then
				-- Semi-auto: fire once on press (handled in InputBegan)
			end
		end

		-- Bloom decay
		self._bloom = self._bloom * VoidArenaConfig.Weapon.CrosshairBloomDecay

		-- Recoil recovery
		if self._recoilOffset > 0 then
			self._recoilOffset = math.max(0, self._recoilOffset - dt / VoidArenaConfig.Weapon.RecoilRecoveryTime)
		end

		-- Update crosshair bloom
		self:_updateCrosshair()
	end)

	-- Fire on mouse click for semi-auto
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:Fire()
		end
	end)

	-- Sync ammo from server periodically
	task.spawn(function()
		while true do
			task.wait(2)
			WeaponService:GetAmmo()
				:andThen(function(ammo)
					if ammo then
						self._ammo = ammo
						self:_updateAmmoDisplay()
					end
				end)
				:catch(function() end)
		end
	end)
end

return WeaponController
