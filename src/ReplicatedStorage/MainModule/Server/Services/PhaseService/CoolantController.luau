--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent
local ServiceTrove = require(MainModule.Shared.Utils.Services.ServiceTrove)

local KILL_CHECK_INTERVAL = 0.1

type WaterZone = {
	Part: BasePart,
	Active: boolean,
	OriginalTransparency: number,
}

local CoolantController = {}

local trove: ServiceTrove.ServiceTrove = nil :: any
local waterZones: { WaterZone } = {}
local buttonPrompts: { ProximityPrompt } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local trackedCharacters: { Instance } = {}
local trackedCharCount: number = 0
local trackedCharSet: { [Model]: true } = {}
local filterDirty: boolean = false
local activeZoneCount: number = 0

local reusableKilled: { [Model]: boolean } = {}
local characterSwimConns: { [Model]: RBXScriptConnection } = {}

local function connectTerrainWaterKill(character: Model): ()
	task.defer(function()
		if not character.Parent then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		characterSwimConns[character] = humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.Swimming and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end)
end

local function disconnectTerrainWaterKill(character: Model): ()
	local conn = characterSwimConns[character]
	if conn then
		conn:Disconnect()
		characterSwimConns[character] = nil
	end
end

local function addCharacter(character: Model): ()
	if trackedCharSet[character] then
		return
	end
	trackedCharSet[character] = true
	trackedCharCount += 1
	trackedCharacters[trackedCharCount] = character
	filterDirty = true
end

local function removeCharacter(character: Model): ()
	if not trackedCharSet[character] then
		return
	end
	trackedCharSet[character] = nil
	for i = 1, trackedCharCount do
		if trackedCharacters[i] == character then
			trackedCharacters[i] = trackedCharacters[trackedCharCount]
			trackedCharacters[trackedCharCount] = nil :: any
			trackedCharCount -= 1
			filterDirty = true
			return
		end
	end
end

local function drainZone(zone: WaterZone): ()
	if not zone.Active then
		return
	end
	zone.Active = false
	zone.Part.Transparency = 1
	activeZoneCount -= 1
end

local function fillZone(zone: WaterZone): ()
	if zone.Active then
		return
	end
	zone.Active = true
	zone.Part.Transparency = zone.OriginalTransparency
	activeZoneCount += 1
end

local function fillZoneInit(zone: WaterZone): ()
	zone.Active = true
	zone.Part.Transparency = zone.OriginalTransparency
	activeZoneCount += 1
end

local function checkZoneOverlaps(): ()
	if activeZoneCount == 0 or trackedCharCount == 0 then
		return
	end

	if filterDirty then
		overlapParams.FilterDescendantsInstances = trackedCharacters
		filterDirty = false
	end

	for _, zone in waterZones do
		if not zone.Active then
			continue
		end

		local parts = workspace:GetPartsInPart(zone.Part, overlapParams)
		for _, part in parts do
			local character = part.Parent :: Model?
			if not character or reusableKilled[character] then
				continue
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
				reusableKilled[character] = true
			end
		end
	end

	table.clear(reusableKilled)
end

local function collectWaterZones(): { [number]: WaterZone }
	local zonesByNumber: { [number]: WaterZone } = {}
	local nextIndex = 1

	local coolantFolder = workspace:FindFirstChild("Coolant")
	if not coolantFolder then
		return zonesByNumber
	end

	for _, child in coolantFolder:GetDescendants() do
		if not child:IsA("BasePart") then
			continue
		end
		if not string.find(string.lower(child.Name), "water") then
			continue
		end

		local num = tonumber(string.match(child.Name, "%d+")) or nextIndex
		nextIndex = math.max(nextIndex, num + 1)

		local zone: WaterZone = {
			Part = child :: BasePart,
			Active = false,
			OriginalTransparency = (child :: BasePart).Transparency,
		}
		table.insert(waterZones, zone)
		zonesByNumber[num] = zone
		fillZoneInit(zone)
	end

	return zonesByNumber
end

local function trackPlayer(player: Player): ()
	local character = player.Character
	if character then
		addCharacter(character)
		connectTerrainWaterKill(character)
	end

	trove:Connect(player.CharacterAdded, function(char: Model)
		addCharacter(char)
		connectTerrainWaterKill(char)
	end)
	trove:Connect(player.CharacterRemoving, function(char: Model)
		removeCharacter(char)
		disconnectTerrainWaterKill(char)
	end)
end

function CoolantController.start(broadcastMessage: (message: string) -> ()): ()
	trove = ServiceTrove.new()
	local zonesByNumber = collectWaterZones()

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	trove:Connect(Players.PlayerAdded, trackPlayer)
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		local character = player.Character
		if character then
			removeCharacter(character)
			disconnectTerrainWaterKill(character)
		end
	end)

	if #waterZones == 0 then
		return
	end

	local lastCheck = 0
	trove:Connect(RunService.Heartbeat, function()
		local now = os.clock()
		if now - lastCheck < KILL_CHECK_INTERVAL then
			return
		end
		lastCheck = now
		debug.profilebegin("CoolantController::zoneCheck")
		checkZoneOverlaps()
		debug.profileend()
	end)

	local coolantFolder = workspace:FindFirstChild("Coolant")
	if not coolantFolder then
		return
	end

	for _, child in coolantFolder:GetDescendants() do
		if not child:IsA("ProximityPrompt") then
			continue
		end

		local parent = child.Parent
		if not parent then
			continue
		end

		local num = tonumber(string.match(parent.Name, "%d+"))
		if not num then
			continue
		end

		local zone = zonesByNumber[num]
		if not zone then
			continue
		end

		child.Enabled = true
		table.insert(buttonPrompts, child)

		trove:Connect(child.Triggered, function(_player: Player)
			if not zone.Active then
				return
			end
			drainZone(zone)
			broadcastMessage(`COOLANT ZONE {num} DRAINED!`)
		end)
	end
end

function CoolantController.refill(): ()
	for _, zone in waterZones do
		fillZone(zone)
	end
	for _, prompt in buttonPrompts do
		prompt.Enabled = true
	end
end

function CoolantController.stop(): ()
	if trove then
		trove:Destroy()
		trove = nil :: any
	end

	for _, conn in characterSwimConns do
		conn:Disconnect()
	end
	table.clear(characterSwimConns)

	for _, zone in waterZones do
		zone.Part.Transparency = zone.OriginalTransparency
	end
	table.clear(waterZones)

	for _, prompt in buttonPrompts do
		prompt.Enabled = false
	end
	table.clear(buttonPrompts)

	table.clear(trackedCharacters)
	table.clear(trackedCharSet)
	trackedCharCount = 0
	activeZoneCount = 0
	filterDirty = false
end

return CoolantController
