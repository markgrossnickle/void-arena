--!strict
--[=[
	@class MapController
	@client
	Handles map visual effects, atmosphere, and ambient particles.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local Player = Players.LocalPlayer

local MapController = Knit.CreateController({
	Name = "MapController",
	_trove = Trove.new(),
	_currentMap = "",
	_ambientParts = {} :: { BasePart },
})

function MapController:_setupAmbientParticles(mapName: string)
	-- Clean up previous
	for _, part in self._ambientParts do
		if part.Parent then
			part:Destroy()
		end
	end
	self._ambientParts = {}

	-- Reduce particles on mobile
	local count = if PlatformUtil.IsMobile() then 3 else 6

	for i = 1, count do
		local emitter = Instance.new("Part")
		emitter.Name = "AmbientEmitter_" .. i
		emitter.Size = Vector3.new(1, 1, 1)
		emitter.Transparency = 1
		emitter.Anchored = true
		emitter.CanCollide = false

		local angle = math.rad((i - 1) * (360 / count))
		local radius = 30
		emitter.Position = Vector3.new(math.cos(angle) * radius, 15, math.sin(angle) * radius)

		local particles = Instance.new("ParticleEmitter")
		particles.Rate = if PlatformUtil.IsMobile() then 2 else 5
		particles.Lifetime = NumberRange.new(3, 6)
		particles.Speed = NumberRange.new(1, 3)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})

		if mapName == "VoidPlatform" or mapName == "AbyssalFortress" then
			particles.Color = ColorSequence.new(Color3.fromRGB(150, 50, 255))
		elseif mapName == "CrystalRuins" then
			particles.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
		elseif mapName == "FungalCavern" then
			particles.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
		end

		particles.LightEmission = 0.8
		particles.Parent = emitter
		emitter.Parent = workspace

		table.insert(self._ambientParts, emitter)
	end
end

function MapController:KnitInit() end

function MapController:KnitStart()
	local MapService = Knit.GetService("MapService")

	MapService.MapChanged:Connect(function(mapName)
		self._currentMap = mapName
		self:_setupAmbientParticles(mapName)
	end)
end

return MapController
