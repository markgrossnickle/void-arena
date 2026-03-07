--!strict
--[=[
	@class MapService
	@server
	Builds and manages arena maps from code-constructed Parts.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local VoidArenaConfig = require(ReplicatedStorage.Shared.VoidArenaConfig)

local MapService = Knit.CreateService({
	Name = "MapService",
	MapLoaded = Signal.new(),

	Client = {
		MapChanged = Knit.CreateSignal(),
	},

	_currentMap = "" :: string,
	_mapFolder = nil :: Folder?,
	_spawnPoints = {} :: { [string]: { CFrame } }, -- team/general -> positions
})

function MapService:GetCurrentMap(): string
	return self._currentMap
end

function MapService:LoadRandomMapForMode(mode: string)
	local compatibleMaps = {}
	for _, mapName in VoidArenaConfig.Maps do
		local modes = VoidArenaConfig.MapModes[mapName]
		if modes and table.find(modes, mode) then
			table.insert(compatibleMaps, mapName)
		end
	end

	if #compatibleMaps == 0 then
		-- Fallback: use any map
		compatibleMaps = VoidArenaConfig.Maps
	end

	local mapName = compatibleMaps[math.random(#compatibleMaps)]
	self:LoadMap(mapName)
end

function MapService:LoadMap(mapName: string)
	-- Clean up previous map
	if self._mapFolder then
		self._mapFolder:Destroy()
	end
	self._spawnPoints = {}

	self._currentMap = mapName
	self._mapFolder = Instance.new("Folder")
	self._mapFolder.Name = "ArenaMap_" .. mapName
	self._mapFolder.Parent = workspace

	-- Set void atmosphere
	self:_setupAtmosphere()

	if mapName == "VoidPlatform" then
		self:_buildVoidPlatform()
	elseif mapName == "CrystalRuins" then
		self:_buildCrystalRuins()
	elseif mapName == "FungalCavern" then
		self:_buildFungalCavern()
	elseif mapName == "AbyssalFortress" then
		self:_buildAbyssalFortress()
	end

	-- Notify clients
	self.MapLoaded:Fire(mapName)
	for _, player in game:GetService("Players"):GetPlayers() do
		self.Client.MapChanged:Fire(player, mapName)
	end
end

function MapService:GetSpawnPoint(player: any, team: string?): CFrame
	local key = team or "General"
	local points = self._spawnPoints[key] or self._spawnPoints["General"]
	if not points or #points == 0 then
		return CFrame.new(0, 10, 0)
	end
	return points[math.random(#points)]
end

function MapService:_setupAtmosphere()
	-- Clear existing atmosphere
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("BloomEffect") then
			child:Destroy()
		end
	end

	Lighting.Ambient = Color3.fromRGB(30, 10, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 5, 30)
	Lighting.Brightness = 0.5
	Lighting.ClockTime = 0
	Lighting.FogEnd = 500
	Lighting.FogColor = Color3.fromRGB(10, 5, 20)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(50, 20, 80)
	atmosphere.Decay = Color3.fromRGB(30, 10, 50)
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.8
	bloom.Parent = Lighting
end

-- Helper to create a Part in the map folder
function MapService:_createPart(props: {
	Size: Vector3,
	Position: Vector3?,
	CFrame: CFrame?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Name: string?,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "MapPart"
	part.Size = props.Size
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.Position = props.Position
	end
	part.Color = props.Color or Color3.fromRGB(30, 20, 40)
	part.Material = props.Material or Enum.Material.Slate
	part.Transparency = props.Transparency or 0
	part.Anchored = if props.Anchored ~= nil then props.Anchored else true
	part.CanCollide = if props.CanCollide ~= nil then props.CanCollide else true
	part.Parent = self._mapFolder
	return part
end

function MapService:_addNeonEdge(parent: Part, offset: Vector3, size: Vector3, color: Color3?)
	local edge = Instance.new("Part")
	edge.Name = "NeonEdge"
	edge.Size = size
	edge.CFrame = parent.CFrame * CFrame.new(offset)
	edge.Color = color or Color3.fromRGB(150, 50, 255)
	edge.Material = Enum.Material.Neon
	edge.Anchored = true
	edge.CanCollide = false
	edge.Parent = self._mapFolder
end

function MapService:_addLight(position: Vector3, color: Color3?, brightness: number?, range: number?)
	local lightPart = Instance.new("Part")
	lightPart.Name = "LightSource"
	lightPart.Size = Vector3.new(0.5, 0.5, 0.5)
	lightPart.Position = position
	lightPart.Transparency = 1
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Parent = self._mapFolder

	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(150, 50, 255)
	light.Brightness = brightness or 2
	light.Range = range or 30
	light.Parent = lightPart
end

function MapService:_addSpawnPoint(key: string, position: Vector3, rotation: number?)
	if not self._spawnPoints[key] then
		self._spawnPoints[key] = {}
	end
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	table.insert(self._spawnPoints[key], cf)
end

-- ==========================================
-- MAP 1: Void Platform (Small, FFA)
-- ==========================================
function MapService:_buildVoidPlatform()
	-- Main platform
	self:_createPart({
		Name = "MainFloor",
		Size = Vector3.new(60, 3, 60),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(25, 15, 35),
		Material = Enum.Material.Basalt,
	})

	-- Neon border
	for _, offset in {
		{ Vector3.new(30, 1.5, 0), Vector3.new(0.5, 3, 60) },
		{ Vector3.new(-30, 1.5, 0), Vector3.new(0.5, 3, 60) },
		{ Vector3.new(0, 1.5, 30), Vector3.new(60, 3, 0.5) },
		{ Vector3.new(0, 1.5, -30), Vector3.new(60, 3, 0.5) },
	} do
		self:_createPart({
			Name = "Border",
			Size = offset[2],
			Position = offset[1],
			Color = Color3.fromRGB(150, 50, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end

	-- Central elevated platform
	self:_createPart({
		Name = "CenterPlatform",
		Size = Vector3.new(16, 5, 16),
		Position = Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(35, 20, 50),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Ramps to center
	for _, angle in { 0, 90, 180, 270 } do
		local ramp = self:_createPart({
			Name = "Ramp",
			Size = Vector3.new(6, 1, 10),
			CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, -1, -12) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = Color3.fromRGB(30, 20, 45),
			Material = Enum.Material.SmoothPlastic,
		})
		self:_addNeonEdge(ramp, Vector3.new(0, 0.5, 0), Vector3.new(6, 0.2, 10))
	end

	-- 4 corner pillars
	for _, pos in {
		Vector3.new(22, 6, 22),
		Vector3.new(-22, 6, 22),
		Vector3.new(22, 6, -22),
		Vector3.new(-22, 6, -22),
	} do
		self:_createPart({
			Name = "Pillar",
			Size = Vector3.new(4, 12, 4),
			Position = pos,
			Color = Color3.fromRGB(40, 25, 55),
			Material = Enum.Material.Slate,
		})
		self:_addLight(pos + Vector3.new(0, 6, 0), Color3.fromRGB(200, 100, 255))
	end

	-- Cover walls on center platform
	for _, offset in {
		Vector3.new(5, 5.5, 0),
		Vector3.new(-5, 5.5, 0),
		Vector3.new(0, 5.5, 5),
		Vector3.new(0, 5.5, -5),
	} do
		local wall = self:_createPart({
			Name = "CoverWall",
			Size = Vector3.new(6, 5, 1.5),
			Position = offset,
			Color = Color3.fromRGB(35, 25, 50),
			Material = Enum.Material.SmoothPlastic,
		})
		self:_addNeonEdge(wall, Vector3.new(0, 2.5, 0), Vector3.new(6, 0.2, 1.5))
	end

	-- Kill volume below platform
	local killZone = self:_createPart({
		Name = "KillZone",
		Size = Vector3.new(200, 5, 200),
		Position = Vector3.new(0, -20, 0),
		Transparency = 1,
		CanCollide = false,
	})
	killZone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end
	end)

	-- Spawn points (scattered)
	for i = 1, 8 do
		local angle = (i - 1) * (360 / 8)
		local rad = math.rad(angle)
		local x = math.cos(rad) * 20
		local z = math.sin(rad) * 20
		self:_addSpawnPoint("General", Vector3.new(x, 5, z), angle + 180)
	end

	-- Lighting
	self:_addLight(Vector3.new(0, 15, 0), Color3.fromRGB(150, 50, 255), 3, 50)
end

-- ==========================================
-- MAP 2: Crystal Ruins (Medium, TDM)
-- ==========================================
function MapService:_buildCrystalRuins()
	-- Main floor
	self:_createPart({
		Name = "MainFloor",
		Size = Vector3.new(100, 3, 80),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(20, 15, 30),
		Material = Enum.Material.Basalt,
	})

	-- Team 1 side (left)
	self:_createPart({
		Name = "Team1Base",
		Size = Vector3.new(20, 1, 30),
		Position = Vector3.new(-35, 1.5, 0),
		Color = Color3.fromRGB(60, 30, 100),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Team 2 side (right)
	self:_createPart({
		Name = "Team2Base",
		Size = Vector3.new(20, 1, 30),
		Position = Vector3.new(35, 1.5, 0),
		Color = Color3.fromRGB(0, 80, 80),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Mid contested area - elevated
	self:_createPart({
		Name = "MidPlatform",
		Size = Vector3.new(20, 6, 20),
		Position = Vector3.new(0, 3, 0),
		Color = Color3.fromRGB(30, 20, 45),
		Material = Enum.Material.Slate,
	})

	-- Ramps to mid from each side
	for _, xDir in { -1, 1 } do
		self:_createPart({
			Name = "MidRamp",
			Size = Vector3.new(8, 1, 15),
			CFrame = CFrame.new(xDir * 15, 3, 0) * CFrame.Angles(0, 0, math.rad(xDir * -15)),
			Color = Color3.fromRGB(25, 18, 38),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Crystal pillars (cover)
	local crystalPositions = {
		Vector3.new(-15, 6, 15), Vector3.new(-15, 6, -15),
		Vector3.new(15, 6, 15), Vector3.new(15, 6, -15),
		Vector3.new(0, 8, 20), Vector3.new(0, 8, -20),
		Vector3.new(-25, 6, 0), Vector3.new(25, 6, 0),
	}

	for _, pos in crystalPositions do
		local crystal = self:_createPart({
			Name = "CrystalPillar",
			Size = Vector3.new(3, 12, 3),
			Position = pos,
			Color = Color3.fromRGB(100, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
		self:_addLight(pos + Vector3.new(0, 6, 0), Color3.fromRGB(100, 200, 255), 1.5, 20)
	end

	-- Walls for cover
	local wallPositions = {
		{ pos = Vector3.new(-8, 4, 10), size = Vector3.new(8, 5, 1.5) },
		{ pos = Vector3.new(8, 4, -10), size = Vector3.new(8, 5, 1.5) },
		{ pos = Vector3.new(-20, 4, -5), size = Vector3.new(1.5, 5, 10) },
		{ pos = Vector3.new(20, 4, 5), size = Vector3.new(1.5, 5, 10) },
	}

	for _, wallDef in wallPositions do
		local wall = self:_createPart({
			Name = "CoverWall",
			Size = wallDef.size,
			Position = wallDef.pos,
			Color = Color3.fromRGB(35, 25, 50),
			Material = Enum.Material.SmoothPlastic,
		})
		self:_addNeonEdge(wall, Vector3.new(0, wallDef.size.Y / 2, 0), Vector3.new(wallDef.size.X, 0.2, wallDef.size.Z))
	end

	-- Sniper perches (elevated on each side)
	for _, xDir in { -1, 1 } do
		self:_createPart({
			Name = "SniperPerch",
			Size = Vector3.new(8, 10, 6),
			Position = Vector3.new(xDir * 40, 5, 0),
			Color = Color3.fromRGB(30, 20, 45),
			Material = Enum.Material.Slate,
		})
		self:_createPart({
			Name = "SniperLedge",
			Size = Vector3.new(10, 1, 8),
			Position = Vector3.new(xDir * 40, 10.5, 0),
			Color = Color3.fromRGB(35, 25, 55),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Second level platforms along sides
	for _, zDir in { -1, 1 } do
		self:_createPart({
			Name = "SidePlatform",
			Size = Vector3.new(30, 1, 8),
			Position = Vector3.new(0, 6, zDir * 32),
			Color = Color3.fromRGB(28, 18, 40),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Kill zone
	local killZone = self:_createPart({
		Name = "KillZone",
		Size = Vector3.new(200, 5, 200),
		Position = Vector3.new(0, -20, 0),
		Transparency = 1,
		CanCollide = false,
	})
	killZone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end
	end)

	-- Team 1 spawns (Void)
	for i = 1, 5 do
		self:_addSpawnPoint(VoidArenaConfig.Teams.Team1.Name, Vector3.new(-35, 4, -12 + (i - 1) * 6), 0)
	end

	-- Team 2 spawns (Abyss)
	for i = 1, 5 do
		self:_addSpawnPoint(VoidArenaConfig.Teams.Team2.Name, Vector3.new(35, 4, -12 + (i - 1) * 6), 180)
	end

	-- Central light
	self:_addLight(Vector3.new(0, 20, 0), Color3.fromRGB(100, 200, 255), 3, 60)
end

-- ==========================================
-- MAP 3: Fungal Cavern (Medium, Domination)
-- ==========================================
function MapService:_buildFungalCavern()
	-- Cave floor
	self:_createPart({
		Name = "CaveFloor",
		Size = Vector3.new(100, 3, 80),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(20, 25, 15),
		Material = Enum.Material.Slate,
	})

	-- Cave ceiling
	self:_createPart({
		Name = "CaveCeiling",
		Size = Vector3.new(100, 3, 80),
		Position = Vector3.new(0, 25, 0),
		Color = Color3.fromRGB(15, 18, 12),
		Material = Enum.Material.Slate,
	})

	-- Three rooms connected by corridors
	-- Room A (left - capture point Alpha)
	self:_createPart({
		Name = "RoomAFloor",
		Size = Vector3.new(25, 1, 25),
		Position = Vector3.new(-30, 1.5, 0),
		Color = Color3.fromRGB(25, 30, 20),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Room B (center - capture point Bravo)
	self:_createPart({
		Name = "RoomBFloor",
		Size = Vector3.new(25, 1, 25),
		Position = Vector3.new(0, 1.5, 0),
		Color = Color3.fromRGB(25, 30, 20),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Room C (right - capture point Charlie)
	self:_createPart({
		Name = "RoomCFloor",
		Size = Vector3.new(25, 1, 25),
		Position = Vector3.new(30, 1.5, 0),
		Color = Color3.fromRGB(25, 30, 20),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Capture point markers (glowing circles)
	for _, cpConfig in VoidArenaConfig.CapturePoints.FungalCavern do
		local marker = self:_createPart({
			Name = "CapturePoint_" .. cpConfig.Name,
			Size = Vector3.new(10, 0.5, 10),
			Position = cpConfig.Position,
			Color = Color3.fromRGB(200, 200, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
		})
		marker.Shape = Enum.PartType.Cylinder
		marker.CFrame = CFrame.new(cpConfig.Position) * CFrame.Angles(0, 0, math.rad(90))
		marker.Size = Vector3.new(0.5, 10, 10)

		self:_addLight(cpConfig.Position + Vector3.new(0, 3, 0), Color3.fromRGB(200, 200, 100), 2, 25)
	end

	-- Corridor walls
	for _, corridor in {
		{ from = -17, to = -13, z = 6 },
		{ from = -17, to = -13, z = -6 },
		{ from = 13, to = 17, z = 6 },
		{ from = 13, to = 17, z = -6 },
	} do
		self:_createPart({
			Name = "CorridorWall",
			Size = Vector3.new(corridor.to - corridor.from, 12, 1.5),
			Position = Vector3.new((corridor.from + corridor.to) / 2, 7.5, corridor.z),
			Color = Color3.fromRGB(25, 30, 20),
			Material = Enum.Material.Slate,
		})
	end

	-- Mushroom cover objects (destructible)
	local mushroomPositions = {
		Vector3.new(-25, 5, 8), Vector3.new(-25, 5, -8),
		Vector3.new(-5, 5, 10), Vector3.new(5, 5, -10),
		Vector3.new(25, 5, 8), Vector3.new(25, 5, -8),
	}

	for _, pos in mushroomPositions do
		local mushroom = self:_createPart({
			Name = "Mushroom",
			Size = Vector3.new(4, 6, 4),
			Position = pos,
			Color = Color3.fromRGB(100, 200, 100),
			Material = Enum.Material.SmoothPlastic,
		})

		-- Mushroom cap
		local cap = self:_createPart({
			Name = "MushroomCap",
			Size = Vector3.new(8, 2, 8),
			Position = pos + Vector3.new(0, 4, 0),
			Color = Color3.fromRGB(150, 50, 200),
			Material = Enum.Material.SmoothPlastic,
		})

		mushroom:SetAttribute("Health", 100)
		mushroom:SetAttribute("Destructible", true)

		self:_addLight(pos + Vector3.new(0, 6, 0), Color3.fromRGB(100, 255, 100), 1, 15)
	end

	-- Upper catwalks
	self:_createPart({
		Name = "Catwalk1",
		Size = Vector3.new(80, 1, 4),
		Position = Vector3.new(0, 12, 20),
		Color = Color3.fromRGB(30, 25, 20),
		Material = Enum.Material.Metal,
	})
	self:_createPart({
		Name = "Catwalk2",
		Size = Vector3.new(80, 1, 4),
		Position = Vector3.new(0, 12, -20),
		Color = Color3.fromRGB(30, 25, 20),
		Material = Enum.Material.Metal,
	})

	-- Ramps to catwalks
	for _, side in { -1, 1 } do
		self:_createPart({
			Name = "CatwalkRamp",
			Size = Vector3.new(4, 1, 12),
			CFrame = CFrame.new(-35, 7, side * 20) * CFrame.Angles(math.rad(-30), 0, 0),
			Color = Color3.fromRGB(30, 25, 20),
			Material = Enum.Material.Metal,
		})
		self:_createPart({
			Name = "CatwalkRamp",
			Size = Vector3.new(4, 1, 12),
			CFrame = CFrame.new(35, 7, side * 20) * CFrame.Angles(math.rad(-30), 0, 0),
			Color = Color3.fromRGB(30, 25, 20),
			Material = Enum.Material.Metal,
		})
	end

	-- Spawn points
	for _, teamConfig in {
		{ name = VoidArenaConfig.Teams.Team1.Name, x = -40, rot = 0 },
		{ name = VoidArenaConfig.Teams.Team2.Name, x = 40, rot = 180 },
	} do
		for i = 1, 5 do
			self:_addSpawnPoint(teamConfig.name, Vector3.new(teamConfig.x, 4, -10 + (i - 1) * 5), teamConfig.rot)
		end
	end

	self:_addLight(Vector3.new(0, 20, 0), Color3.fromRGB(100, 255, 100), 2, 50)
end

-- ==========================================
-- MAP 4: Abyssal Fortress (Large, TDM/Domination)
-- ==========================================
function MapService:_buildAbyssalFortress()
	-- Main courtyard floor
	self:_createPart({
		Name = "CourtyardFloor",
		Size = Vector3.new(80, 3, 60),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(25, 15, 30),
		Material = Enum.Material.Basalt,
	})

	-- Outer walls
	local wallSegments = {
		{ pos = Vector3.new(0, 10, 30), size = Vector3.new(80, 20, 3) },
		{ pos = Vector3.new(0, 10, -30), size = Vector3.new(80, 20, 3) },
		{ pos = Vector3.new(40, 10, 0), size = Vector3.new(3, 20, 60) },
		{ pos = Vector3.new(-40, 10, 0), size = Vector3.new(3, 20, 60) },
	}

	for _, seg in wallSegments do
		self:_createPart({
			Name = "FortressWall",
			Size = seg.size,
			Position = seg.pos,
			Color = Color3.fromRGB(30, 18, 40),
			Material = Enum.Material.Slate,
		})
	end

	-- Battlements (top of walls)
	for x = -36, 36, 6 do
		for _, z in { 30, -30 } do
			self:_createPart({
				Name = "Battlement",
				Size = Vector3.new(3, 4, 4),
				Position = Vector3.new(x, 22, z),
				Color = Color3.fromRGB(35, 20, 45),
				Material = Enum.Material.Slate,
			})
		end
	end

	-- Walkways along walls
	for _, z in { 27, -27 } do
		self:_createPart({
			Name = "WallWalkway",
			Size = Vector3.new(74, 1, 4),
			Position = Vector3.new(0, 16, z),
			Color = Color3.fromRGB(28, 16, 38),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Central tower
	self:_createPart({
		Name = "CentralTower",
		Size = Vector3.new(12, 20, 12),
		Position = Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(35, 20, 50),
		Material = Enum.Material.Slate,
	})
	self:_createPart({
		Name = "TowerTop",
		Size = Vector3.new(16, 1, 16),
		Position = Vector3.new(0, 20.5, 0),
		Color = Color3.fromRGB(40, 25, 55),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Ramps to tower
	for _, angle in { 0, 90, 180, 270 } do
		self:_createPart({
			Name = "TowerRamp",
			Size = Vector3.new(4, 1, 12),
			CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -12) * CFrame.Angles(math.rad(-25), 0, 0),
			Color = Color3.fromRGB(30, 18, 42),
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Underground tunnels (below courtyard)
	self:_createPart({
		Name = "TunnelFloor",
		Size = Vector3.new(60, 1, 10),
		Position = Vector3.new(0, -5, 0),
		Color = Color3.fromRGB(20, 12, 28),
		Material = Enum.Material.Slate,
	})
	self:_createPart({
		Name = "TunnelCeiling",
		Size = Vector3.new(60, 1, 10),
		Position = Vector3.new(0, 0, 0), -- shares with courtyard floor
		Color = Color3.fromRGB(20, 12, 28),
		Material = Enum.Material.Slate,
	})

	-- Tunnel entrances (holes in the floor at edges)
	for _, xDir in { -1, 1 } do
		self:_createPart({
			Name = "TunnelEntrance",
			Size = Vector3.new(6, 6, 6),
			Position = Vector3.new(xDir * 25, -2, 0),
			Color = Color3.fromRGB(20, 12, 28),
			Material = Enum.Material.SmoothPlastic,
		})
		-- Stairs down
		for step = 0, 3 do
			self:_createPart({
				Name = "TunnelStair",
				Size = Vector3.new(6, 1, 2),
				Position = Vector3.new(xDir * (25 + xDir * step * 2), -step * 1.5, 0),
				Color = Color3.fromRGB(25, 15, 35),
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-- Cover objects in courtyard
	local coverPositions = {
		{ pos = Vector3.new(-15, 4, 10), size = Vector3.new(6, 5, 1.5) },
		{ pos = Vector3.new(15, 4, -10), size = Vector3.new(6, 5, 1.5) },
		{ pos = Vector3.new(-10, 4, -15), size = Vector3.new(1.5, 5, 8) },
		{ pos = Vector3.new(10, 4, 15), size = Vector3.new(1.5, 5, 8) },
		{ pos = Vector3.new(-25, 4, 0), size = Vector3.new(4, 5, 4) },
		{ pos = Vector3.new(25, 4, 0), size = Vector3.new(4, 5, 4) },
	}

	for _, cover in coverPositions do
		local wall = self:_createPart({
			Name = "Cover",
			Size = cover.size,
			Position = cover.pos,
			Color = Color3.fromRGB(30, 20, 42),
			Material = Enum.Material.SmoothPlastic,
		})
		self:_addNeonEdge(wall, Vector3.new(0, cover.size.Y / 2, 0), Vector3.new(cover.size.X, 0.2, cover.size.Z))
	end

	-- Capture points for Domination
	if VoidArenaConfig.CapturePoints.AbyssalFortress then
		for _, cpConfig in VoidArenaConfig.CapturePoints.AbyssalFortress do
			local marker = self:_createPart({
				Name = "CapturePoint_" .. cpConfig.Name,
				Size = Vector3.new(0.5, 10, 10),
				CFrame = CFrame.new(cpConfig.Position) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(200, 200, 200),
				Material = Enum.Material.Neon,
				Transparency = 0.5,
			})
			marker.Shape = Enum.PartType.Cylinder
			self:_addLight(cpConfig.Position + Vector3.new(0, 5, 0), Color3.fromRGB(200, 200, 100), 2, 25)
		end
	end

	-- Neon void tendrils (decorative)
	for i = 1, 6 do
		local angle = math.rad((i - 1) * 60)
		local x = math.cos(angle) * 35
		local z = math.sin(angle) * 25
		self:_createPart({
			Name = "VoidTendril",
			Size = Vector3.new(1, 15 + math.random(5), 1),
			Position = Vector3.new(x, 8, z),
			Color = Color3.fromRGB(120, 40, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
		})
	end

	-- Kill zone
	local killZone = self:_createPart({
		Name = "KillZone",
		Size = Vector3.new(200, 5, 200),
		Position = Vector3.new(0, -30, 0),
		Transparency = 1,
		CanCollide = false,
	})
	killZone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end
	end)

	-- Spawn points
	for _, teamConfig in {
		{ name = VoidArenaConfig.Teams.Team1.Name, x = -30, rot = 0 },
		{ name = VoidArenaConfig.Teams.Team2.Name, x = 30, rot = 180 },
	} do
		for i = 1, 5 do
			self:_addSpawnPoint(teamConfig.name, Vector3.new(teamConfig.x, 4, -10 + (i - 1) * 5), teamConfig.rot)
		end
	end

	-- Lighting
	self:_addLight(Vector3.new(0, 25, 0), Color3.fromRGB(150, 50, 255), 3, 60)
	for _, pos in { Vector3.new(-30, 10, 0), Vector3.new(30, 10, 0) } do
		self:_addLight(pos, Color3.fromRGB(100, 50, 200), 2, 30)
	end
end

function MapService.Client:GetCurrentMap(player: Player): string
	return self.Server:GetCurrentMap()
end

function MapService:KnitInit() end

function MapService:KnitStart() end

return MapService
