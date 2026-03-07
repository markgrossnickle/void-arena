--!strict
--[=[
	@class ClassController
	@client
	Class selection UI and ability cooldown display.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local Player = Players.LocalPlayer

local ClassController = Knit.CreateController({
	Name = "ClassController",
	_trove = Trove.new(),
	_selectedClass = "Vanguard",
	_abilityCooldownEnd = 0,
	_classSelectGui = nil :: ScreenGui?,
	_abilityGui = nil :: ScreenGui?,
})

function ClassController:GetSelectedClass(): string
	return self._selectedClass
end

function ClassController:SelectClass(className: string)
	local ClassService = Knit.GetService("ClassService")
	ClassService:SelectClass(className)
		:andThen(function(success)
			if success then
				self._selectedClass = className
				self:_hideClassSelect()
			end
		end)
		:catch(function(err)
			warn("Failed to select class:", err)
		end)
end

function ClassController:UseAbility()
	if tick() < self._abilityCooldownEnd then
		return
	end

	local ClassService = Knit.GetService("ClassService")
	ClassService:UseAbility()
		:andThen(function(success, errMsg)
			if success then
				local config = VoidArenaConfig.Classes[self._selectedClass]
				if config and config.Ability then
					self._abilityCooldownEnd = tick() + config.Ability.Cooldown
					self:_updateAbilityDisplay()
				end
			end
		end)
		:catch(function(err)
			warn("Ability failed:", err)
		end)
end

function ClassController:ShowClassSelect()
	if self._classSelectGui then
		self._classSelectGui.Enabled = true
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClassSelectGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Player.PlayerGui
	self._classSelectGui = gui

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.4, 0.08)
	title.Position = UDim2.fromScale(0.3, 0.05)
	title.BackgroundTransparency = 1
	title.Text = "SELECT YOUR CLASS"
	title.TextColor3 = Color3.fromRGB(200, 150, 255)
	title.TextScaled = true
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	title.Parent = overlay

	-- Cards container
	local container = Instance.new("Frame")
	container.Name = "CardsContainer"
	container.Size = UDim2.fromScale(0.9, 0.75)
	container.Position = UDim2.fromScale(0.05, 0.15)
	container.BackgroundTransparency = 1
	container.Parent = overlay

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.3, 0.45)
	grid.CellPadding = UDim2.fromScale(0.02, 0.04)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.Name
	grid.Parent = container

	-- Create class cards
	local classOrder = { "Vanguard", "Phantom", "Sentinel", "Titan", "Technomancer", "Wraith" }
	for _, className in classOrder do
		local config = VoidArenaConfig.Classes[className]
		if not config then
			continue
		end
		self:_createClassCard(container, className, config)
	end
end

function ClassController:_createClassCard(parent: Frame, className: string, config: any)
	local card = Instance.new("TextButton")
	card.Name = className
	card.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = true
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 50, 200)
	stroke.Thickness = 2
	stroke.Parent = card

	-- Class name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Size = UDim2.fromScale(0.9, 0.15)
	nameLabel.Position = UDim2.fromScale(0.05, 0.03)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.Name
	nameLabel.TextColor3 = Color3.fromRGB(200, 150, 255)
	nameLabel.TextScaled = true
	nameLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.fromScale(0.9, 0.1)
	desc.Position = UDim2.fromScale(0.05, 0.18)
	desc.BackgroundTransparency = 1
	desc.Text = config.Description
	desc.TextColor3 = Color3.fromRGB(180, 180, 200)
	desc.TextScaled = true
	desc.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = card

	-- Stats
	local statsText = string.format("HP: %d  |  Speed: %d", config.HP, config.Speed)
	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.Size = UDim2.fromScale(0.9, 0.1)
	stats.Position = UDim2.fromScale(0.05, 0.32)
	stats.BackgroundTransparency = 1
	stats.Text = statsText
	stats.TextColor3 = Color3.fromRGB(150, 255, 150)
	stats.TextScaled = true
	stats.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.Parent = card

	-- Weapons
	local weaponText = string.format("%s  |  %s", config.Primary.Name, config.Secondary.Name)
	local weapons = Instance.new("TextLabel")
	weapons.Name = "Weapons"
	weapons.Size = UDim2.fromScale(0.9, 0.1)
	weapons.Position = UDim2.fromScale(0.05, 0.45)
	weapons.BackgroundTransparency = 1
	weapons.Text = weaponText
	weapons.TextColor3 = Color3.fromRGB(255, 200, 100)
	weapons.TextScaled = true
	weapons.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	weapons.TextXAlignment = Enum.TextXAlignment.Left
	weapons.Parent = card

	-- Ability
	local abilityText =
		string.format("[%s] %s (CD: %ds)", config.Ability.Name, config.Ability.Description, config.Ability.Cooldown)
	local ability = Instance.new("TextLabel")
	ability.Name = "Ability"
	ability.Size = UDim2.fromScale(0.9, 0.15)
	ability.Position = UDim2.fromScale(0.05, 0.58)
	ability.BackgroundTransparency = 1
	ability.Text = abilityText
	ability.TextColor3 = Color3.fromRGB(100, 200, 255)
	ability.TextScaled = true
	ability.TextWrapped = true
	ability.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	ability.TextXAlignment = Enum.TextXAlignment.Left
	ability.Parent = card

	-- Select button
	local selectBtn = Instance.new("TextButton")
	selectBtn.Name = "SelectBtn"
	selectBtn.Size = UDim2.fromScale(0.8, 0.12)
	selectBtn.Position = UDim2.fromScale(0.1, 0.82)
	selectBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
	selectBtn.Text = "SELECT"
	selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectBtn.TextScaled = true
	selectBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	selectBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = selectBtn

	selectBtn.Activated:Connect(function()
		self:SelectClass(className)
	end)
end

function ClassController:_hideClassSelect()
	if self._classSelectGui then
		self._classSelectGui.Enabled = false
	end
end

function ClassController:_createAbilityDisplay()
	if self._abilityGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityGui"
	gui.ResetOnSpawn = false
	gui.Parent = Player.PlayerGui
	self._abilityGui = gui

	local frame = Instance.new("Frame")
	frame.Name = "AbilityFrame"
	frame.Size = UDim2.fromScale(0.06, 0.1)
	frame.Position = UDim2.fromScale(0.88, 0.72)
	frame.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 50, 200)
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "AbilityName"
	label.Size = UDim2.fromScale(0.9, 0.4)
	label.Position = UDim2.fromScale(0.05, 0.05)
	label.BackgroundTransparency = 1
	label.Text = "ABILITY"
	label.TextColor3 = Color3.fromRGB(100, 200, 255)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.Parent = frame

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.Size = UDim2.fromScale(0.9, 0.4)
	cooldownLabel.Position = UDim2.fromScale(0.05, 0.5)
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Text = "READY"
	cooldownLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	cooldownLabel.TextScaled = true
	cooldownLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
	cooldownLabel.Parent = frame

	-- Mobile ability button
	if PlatformUtil.IsMobile() then
		local abilityBtn = Instance.new("TextButton")
		abilityBtn.Name = "AbilityButton"
		abilityBtn.Size = UDim2.fromOffset(64, 64)
		abilityBtn.Position = UDim2.fromScale(0.82, 0.6)
		abilityBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
		abilityBtn.Text = "Q"
		abilityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		abilityBtn.TextScaled = true
		abilityBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
		abilityBtn.Parent = gui

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0.5, 0)
		btnCorner.Parent = abilityBtn

		abilityBtn.Activated:Connect(function()
			self:UseAbility()
		end)
	end
end

function ClassController:_updateAbilityDisplay()
	if not self._abilityGui then
		return
	end

	local frame = self._abilityGui:FindFirstChild("AbilityFrame")
	if not frame then
		return
	end

	local config = VoidArenaConfig.Classes[self._selectedClass]
	if config and config.Ability then
		local nameLabel = frame:FindFirstChild("AbilityName") :: TextLabel?
		if nameLabel then
			nameLabel.Text = config.Ability.Name
		end
	end

	-- Update cooldown in a loop
	task.spawn(function()
		local cooldownLabel = frame:FindFirstChild("CooldownLabel") :: TextLabel?
		if not cooldownLabel then
			return
		end
		while tick() < self._abilityCooldownEnd do
			local remaining = math.ceil(self._abilityCooldownEnd - tick())
			cooldownLabel.Text = tostring(remaining) .. "s"
			cooldownLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			task.wait(0.1)
		end
		cooldownLabel.Text = "READY"
		cooldownLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	end)
end

function ClassController:KnitInit() end

function ClassController:KnitStart()
	local ClassService = Knit.GetService("ClassService")

	-- Listen for class changes
	ClassService.ClassChanged:Connect(function(className)
		self._selectedClass = className
		self._abilityCooldownEnd = 0
		self:_updateAbilityDisplay()
	end)

	ClassService.AbilityReady:Connect(function()
		self._abilityCooldownEnd = 0
		self:_updateAbilityDisplay()
	end)

	-- Show class select on first spawn
	Player.CharacterAdded:Connect(function()
		task.defer(function()
			self:ShowClassSelect()
		end)
	end)

	-- Create ability display
	self:_createAbilityDisplay()

	-- Bind ability key (Q)
	local InputController = Knit.GetController("InputController")
	InputController:RegisterInput("Ability", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			self:UseAbility()
		end
	end, false, { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 })
end

return ClassController
