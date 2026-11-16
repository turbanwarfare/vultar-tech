--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local GunStats = require(MainModule.Shared.Config.GunStats)
local TeamService = require(MainModule.Server.Services.TeamService)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local Core = require(MainModule.Shared.Network.Core)
local WeaponService = {}
WeaponService.Name = "WeaponService"

local GunSkinService: any = nil

local serviceConnections: { RBXScriptConnection } = {}
local playerCharacterConns: { [Player]: RBXScriptConnection } = {}
local playerScriptConns: { [Player]: { [string]: RBXScriptConnection? } } = {}

local SPECTATOR_WEAPONS = {
	["H-82"] = true,
}

local REMOTE_NAMES = {
	HOLSTER = "WeaponHolster",
	UNHOLSTER = "WeaponUnholster",
	SPECTATOR_HOLSTERS = "WeaponSpectatorHolsters",
	BROADCAST_HOLSTER = "WeaponHolsterBroadcast",
	REQUEST_ALL_HOLSTERS = "RequestAllHolsters",
	PLAYER_VISIBILITY_CHANGED = "PlayerVisibilityChanged",
}

local HolsterEvent: RemoteEvent? = nil
local UnholsterEvent: RemoteEvent? = nil
local SpectatorHolsterEvent: RemoteEvent? = nil
local BroadcastHolsterEvent: RemoteEvent? = nil
local RequestAllHolstersEvent: RemoteEvent? = nil
local PlayerVisibilityChangedEvent: RemoteEvent? = nil

local playerHolsters: { [Player]: { [string]: { holsterPart: string, holsterOffset: CFrame, skinId: string? } } } = {}
local pendingHolsterRequests: { [Player]: thread } = {}

local function getOrCreateRemotes(): ()
	if not HolsterEvent then
		HolsterEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.HOLSTER)
	end
	if not UnholsterEvent then
		UnholsterEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.UNHOLSTER)
	end
	if not SpectatorHolsterEvent then
		SpectatorHolsterEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.SPECTATOR_HOLSTERS)
	end
	if not BroadcastHolsterEvent then
		BroadcastHolsterEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.BROADCAST_HOLSTER)
	end
	if not RequestAllHolstersEvent then
		RequestAllHolstersEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_ALL_HOLSTERS)
	end
	if not PlayerVisibilityChangedEvent then
		PlayerVisibilityChangedEvent = Core.getOrCreateRemoteEvent(REMOTE_NAMES.PLAYER_VISIBILITY_CHANGED)
	end
end

local function fireHolster(player: Player, toolName: string, holsterPart: string, holsterOffset: CFrame, skinId: string?): ()
	getOrCreateRemotes()
	local skinIdToSend = skinId or ""
	HolsterEvent:FireClient(player, toolName, holsterPart, holsterOffset, skinIdToSend)
end

local function fireUnholster(player: Player, toolName: string): ()
	getOrCreateRemotes()
	UnholsterEvent:FireClient(player, toolName)
end

local function fireSpectatorHolsters(player: Player, holsterType: string, weaponList: any): ()
	getOrCreateRemotes()
	SpectatorHolsterEvent:FireClient(player, holsterType, weaponList)
end

local function broadcastHolsterToAll(player: Player, toolName: string, holsterPart: string, holsterOffset: CFrame, skinId: string?)
	getOrCreateRemotes()
	local skinIdToSend = skinId or ""
	local count = 0
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			BroadcastHolsterEvent:FireClient(otherPlayer, player, toolName, holsterPart, holsterOffset, skinIdToSend)
			count += 1
		end
	end
end

local function broadcastUnholsterToAll(player: Player, toolName: string)
	getOrCreateRemotes()
	local count = 0
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			BroadcastHolsterEvent:FireClient(otherPlayer, player, toolName)
			count += 1
		end
	end
end

local function broadcastClearAllHolstersForPlayer(player: Player)
	getOrCreateRemotes()
	local count = 0
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			BroadcastHolsterEvent:FireClient(otherPlayer, player, "__CLEAR_ALL__")
			count += 1
		end
	end
end

local function broadcastPlayerVisibilityChanged(player: Player, isVisible: boolean)
	getOrCreateRemotes()
	PlayerVisibilityChangedEvent:FireAllClients(player, isVisible)
end

local function getTorso(char: Model): BasePart?
	local torso = char:FindFirstChild("Torso") :: BasePart?
	if torso then
		return torso
	end
	return char:FindFirstChild("UpperTorso") :: BasePart?
end

local function getRightArm(char: Model): BasePart?
	local rightArm = char:FindFirstChild("Right Arm") :: BasePart?
	if rightArm then
		return rightArm
	end
	return char:FindFirstChild("RightHand") :: BasePart?
end

local function disconnectAll(connections: { [string]: RBXScriptConnection? }): ()
	for key, conn in connections do
		if conn then
			conn:Disconnect()
		end
		connections[key] = nil
	end
end

local function ensureToolGrip(torso: BasePart): Motor6D
	local existing = torso:FindFirstChild("ToolGrip")
	if existing and existing:IsA("Motor6D") then
		existing.Part0 = torso
		return existing
	end

	local toolGrip = Instance.new("Motor6D")
	toolGrip.Name = "ToolGrip"
	toolGrip.Part0 = torso
	toolGrip.Parent = torso
	return toolGrip
end

local function getToolHandle(tool: Tool): BasePart?
	return tool:FindFirstChild("Handle") :: BasePart?
end

local function prepareToolForBodyAttach(tool: Tool): ()
	tool.RequiresHandle = false

	local handle = getToolHandle(tool)
	if not handle then
		return
	end

	local grip = handle:FindFirstChildOfClass("Motor6D")
	if grip then
		grip.Part0 = nil
		grip.Part1 = handle
	end
end

local function destroyRightGrip(rightArm: BasePart): ()
	local rg = rightArm:FindFirstChild("RightGrip")
	if rg then
		rg:Destroy()
	end
end

local function resolvePlayerSkinId(player: Player, weaponName: string): string?
	if not GunSkinService then
		return nil
	end
	local skinId = GunSkinService:GetPlayerSkinForGun(player, weaponName)
	if skinId and skinId ~= "Default" then
		return skinId
	end
	return nil
end

type ToolState = {
	Connections: { [string]: RBXScriptConnection? },
	HolsterThread: thread?,
}

local HOLSTER_DEBOUNCE = 0.1

local function cancelPendingHolster(state: ToolState): ()
	if state.HolsterThread then
		task.cancel(state.HolsterThread)
		state.HolsterThread = nil
	end
end

local function holsterTool(player: Player, tool: Tool, toolState: ToolState, character: Model, holsterPart: string, holsterOffset: CFrame): ()
	cancelPendingHolster(toolState)
	toolState.HolsterThread = task.delay(HOLSTER_DEBOUNCE, function()
		toolState.HolsterThread = nil
		if tool.Parent == character then
			return
		end

		local skinId = resolvePlayerSkinId(player, tool.Name)
		local skinIdToStore = if skinId and skinId ~= "" then skinId else nil

		if not playerHolsters[player] then
			playerHolsters[player] = {}
		end
		playerHolsters[player][tool.Name] = {
			holsterPart = holsterPart,
			holsterOffset = holsterOffset,
			skinId = skinIdToStore,
		}

		fireHolster(player, tool.Name, holsterPart, holsterOffset, skinIdToStore)
		broadcastHolsterToAll(player, tool.Name, holsterPart, holsterOffset, skinIdToStore)
	end)
end

local function unholsterTool(player: Player, tool: Tool, toolState: ToolState): ()
	cancelPendingHolster(toolState)

	if playerHolsters[player] then
		playerHolsters[player][tool.Name] = nil
		if next(playerHolsters[player]) == nil then
			playerHolsters[player] = nil
		end
	end

	fireUnholster(player, tool.Name)
	broadcastUnholsterToAll(player, tool.Name)
end

local function attachCharacterToolToGrip(tool: Tool, torso: BasePart): ()
	prepareToolForBodyAttach(tool)

	local function isMeleeTool(t: Tool?): boolean
		if not t then
			return false
		end
		if t.Name == "Sword" then
			return true
		end
		local stats = GunStats.get(t.Name)
		return stats ~= nil and stats.Mode == "Melee"
	end

	if isMeleeTool(tool) then
		return
	end

	local toolGrip = ensureToolGrip(torso)
	local bodyAttach = tool:FindFirstChild("BodyAttach") :: BasePart?
	if bodyAttach then
		toolGrip.Part1 = bodyAttach
		toolGrip.C1 = tool.Name == "GPR" and CFrame.Angles(0, -math.pi / 2, 0) or CFrame.identity
		return
	end

	toolGrip.Part1 = getToolHandle(tool)
	toolGrip.C1 = tool.Name == "GPR" and CFrame.Angles(0, -math.pi / 2, 0) or CFrame.identity
end

local function detachCharacterToolFromGrip(tool: Tool, torso: BasePart?): ()
	if not torso then
		return
	end

	local toolGrip = torso:FindFirstChild("ToolGrip") :: Motor6D?
	if not toolGrip then
		return
	end

	local bodyAttach = tool:FindFirstChild("BodyAttach")
	if toolGrip.Part1 == bodyAttach or toolGrip.Part1 == getToolHandle(tool) then
		toolGrip.Part1 = nil
	end
end

local function setupTorsoVisibilityTracking(player: Player, character: Model)
	local torso = getTorso(character)
	if not torso then
		return
	end

	local function checkVisibility()
		local isVisible = torso.Transparency < 0.99
		broadcastPlayerVisibilityChanged(player, isVisible)
	end

	checkVisibility()

	local connection = torso:GetPropertyChangedSignal("Transparency"):Connect(checkVisibility)

	if not playerScriptConns[player] then
		playerScriptConns[player] = {}
	end
	playerScriptConns[player]["TorsoVisibility"] = connection
end

local function initializeTool(
	player: Player,
	tool: Tool,
	torso: BasePart,
	rightArm: BasePart,
	character: Model,
	allTools: { [Tool]: ToolState },
	isCleanedUp: { value: boolean }
): ()
	if not tool:IsA("Tool") or allTools[tool] or isCleanedUp.value then
		return
	end

	local function isMeleeTool(t: Tool?): boolean
		if not t then
			return false
		end
		if t.Name == "Sword" then
			return true
		end
		local stats = GunStats.get(t.Name)
		return stats ~= nil and stats.Mode == "Melee"
	end

	if isMeleeTool(tool) then
		return
	end

	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end

	local stats = GunStats.get(tool.Name)
	if not stats then
		return
	end

	local holsterPart: string = stats.HolsterPart or "Torso"
	local holsterOffset: CFrame = stats.HolsterOffset or CFrame.identity
	prepareToolForBodyAttach(tool)

	local toolState: ToolState = {
		Connections = {},
		HolsterThread = nil,
	}
	allTools[tool] = toolState

	local function doHolster()
		if tool.Name == "GPR" then
			return
		end
		holsterTool(player, tool, toolState, character, holsterPart, holsterOffset)
	end
	local function doUnholster()
		unholsterTool(player, tool, toolState)
	end

	destroyRightGrip(rightArm)

	toolState.Connections.RightArmChildAdded = rightArm.ChildAdded:Connect(function(child)
		if child.Name ~= "RightGrip" or not child:IsA("Motor6D") then
			return
		end
		child.Part0 = nil
		child.Part1 = nil
		task.defer(function()
			if child.Parent then
				child:Destroy()
			end
		end)
	end)

	toolState.Connections.ChildAdded = tool.ChildAdded:Connect(function(child)
		if not child:IsA("Model") or child.Name ~= "GunModel" then
			return
		end

		if tool.Parent ~= character then
			task.defer(doHolster)
		else
			task.defer(function()
				if tool.Parent == character then
					attachCharacterToolToGrip(tool, torso)
					destroyRightGrip(rightArm)
				end
			end)
		end
	end)

	toolState.Connections.Equipped = tool.Equipped:Connect(function()
		attachCharacterToolToGrip(tool, torso)
		doUnholster()
		destroyRightGrip(rightArm)
		task.delay(0.1, function()
			if tool.Parent == character then
				destroyRightGrip(rightArm)
			end
		end)
	end)

	toolState.Connections.Unequipped = tool.Unequipped:Connect(function()
		doHolster()
	end)

	local function cleanup()
		cancelPendingHolster(toolState)
		disconnectAll(toolState.Connections)
		allTools[tool] = nil
	end

	toolState.Connections.HumanoidDied = character:FindFirstChildOfClass("Humanoid")
			and character:FindFirstChildOfClass("Humanoid").Died:Connect(function()
				if tool.Parent == character then
					tool.Parent = nil
				end
				cleanup()
			end)
		or nil

	toolState.Connections.Destroying = tool.Destroying:Connect(cleanup)

	if tool.Parent ~= character then
		task.defer(doHolster)
	else
		attachCharacterToolToGrip(tool, torso)
		doUnholster()
		destroyRightGrip(rightArm)
		task.delay(0.1, function()
			if tool.Parent == character then
				destroyRightGrip(rightArm)
			end
		end)
	end
end

local function initializeBackpackTool(
	player: Player,
	torso: BasePart,
	rightArm: BasePart,
	character: Model,
	tools: { [Tool]: ToolState },
	isCleanedUp: { value: boolean }
)
	return function(tool: Tool)
		initializeTool(player, tool, torso, rightArm, character, tools, isCleanedUp)
	end
end

local function initializeCharacterTool(
	player: Player,
	character: Model,
	torso: BasePart,
	rightArm: BasePart,
	tools: { [Tool]: ToolState },
	isCleanedUp: { value: boolean }
)
	return function(tool: Tool)
		initializeTool(player, tool, torso, rightArm, character, tools, isCleanedUp)
	end
end

local function sendAllHolstersToPlayer(targetPlayer: Player)
	getOrCreateRemotes()

	local holsterCount = 0
	for player, holsters in pairs(playerHolsters) do
		for toolName, data in pairs(holsters) do
			if player == targetPlayer then
				HolsterEvent:FireClient(targetPlayer, toolName, data.holsterPart, data.holsterOffset, data.skinId or "")
			else
				BroadcastHolsterEvent:FireClient(targetPlayer, player, toolName, data.holsterPart, data.holsterOffset, data.skinId or "")
			end
			holsterCount += 1
		end
	end
end

local function clearAllHolstersForPlayer(player: Player)
	local pending = pendingHolsterRequests[player]
	if pending then
		task.cancel(pending)
		pendingHolsterRequests[player] = nil
	end

	if playerHolsters[player] then
		playerHolsters[player] = nil
	end

	fireSpectatorHolsters(player, "Clear", {})
	broadcastClearAllHolstersForPlayer(player)
end

local function setupSpectatorHolsters(player: Player): ()
	if not GunStats or not GunStats.Guns then
		warn("GunStats not loaded yet when setupSpectatorHolsters called for", player.Name)
		return
	end

	local char = player.Character
	local torso = char and getTorso(char)
	local holsterPartName = torso and torso.Name or "Torso"

	if not playerHolsters[player] then
		playerHolsters[player] = {}
	end

	for weaponName in SPECTATOR_WEAPONS do
		local stats = GunStats.get(weaponName)
		local skinId = resolvePlayerSkinId(player, weaponName)
		local holsterOffset = stats and stats.HolsterOffset or CFrame.identity

		if not playerHolsters[player] then
			playerHolsters[player] = {}
		end
		playerHolsters[player][weaponName] = {
			holsterPart = holsterPartName,
			holsterOffset = holsterOffset,
			skinId = skinId,
		}

		fireHolster(player, weaponName, holsterPartName, holsterOffset, skinId)
		broadcastHolsterToAll(player, weaponName, holsterPartName, holsterOffset, skinId)
	end
end

local function setupSpecTeamHolsters(player: Player, weaponFilter: { [string]: boolean }?): ()
	local char = player.Character
	local torso = char and getTorso(char)
	local holsterPartName = torso and torso.Name or "Torso"

	if not playerHolsters[player] then
		playerHolsters[player] = {}
	end

	local allWeapons = GunStats.Guns or {}
	for weaponName in pairs(allWeapons) do
		if not weaponFilter or weaponFilter[weaponName] then
			local stats = GunStats.get(weaponName)
			if stats then
				local skinId = resolvePlayerSkinId(player, weaponName)
				local holsterOffset = stats.HolsterOffset or CFrame.identity

				if not playerHolsters[player] then
					playerHolsters[player] = {}
				end
				playerHolsters[player][weaponName] = {
					holsterPart = holsterPartName,
					holsterOffset = holsterOffset,
					skinId = skinId,
				}

				fireHolster(player, weaponName, holsterPartName, holsterOffset, skinId)
				broadcastHolsterToAll(player, weaponName, holsterPartName, holsterOffset, skinId)
			end
		end
	end
end

local function isSpecTeam(player: Player): boolean
	return TeamService:GetPlayerTeam(player) == "SpecTeam"
end

local function cleanupAllPlayerTools(
	tools: { [Tool]: ToolState },
	scriptConnections: { [string]: RBXScriptConnection? },
	isCleanedUp: { value: boolean },
	player: Player?
): ()
	if isCleanedUp.value then
		return
	end
	isCleanedUp.value = true

	for _, state in tools do
		cancelPendingHolster(state)
		disconnectAll(state.Connections)
	end
	table.clear(tools)
	disconnectAll(scriptConnections)

	if player then
		playerScriptConns[player] = nil
	end
end

local function setupToolsForPlayer(player: Player, character: Model): ()
	local prevConns = playerScriptConns[player]
	if prevConns then
		disconnectAll(prevConns)
		playerScriptConns[player] = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local backpack = player:WaitForChild("Backpack", 10) :: Backpack?

	if not humanoid or not backpack then
		return
	end

	local rightArm = getRightArm(character)
	local torso = getTorso(character)
	if not rightArm or not torso then
		return
	end

	local playerFaction = TeamService:GetPlayerFaction(player)

	clearAllHolstersForPlayer(player)
	setupTorsoVisibilityTracking(player, character)

	if playerFaction == "Neutral" then
		setupSpectatorHolsters(player)
		return
	end

	if isSpecTeam(player) then
		setupSpecTeamHolsters(player, SPECTATOR_WEAPONS)
		return
	end

	ensureToolGrip(torso)

	local tools: { [Tool]: ToolState } = {}
	local scriptConnections: { [string]: RBXScriptConnection? } = {}
	local isCleanedUp = { value = false }

	playerScriptConns[player] = scriptConnections

	local initBackpackTool = initializeBackpackTool(player, torso, rightArm, character, tools, isCleanedUp)
	local initCharacterTool = initializeCharacterTool(player, character, torso, rightArm, tools, isCleanedUp)

	scriptConnections.CharChildAdded = character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then
			return
		end
		attachCharacterToolToGrip(child :: Tool, torso)
		local toolState = tools[child :: Tool]
		if toolState then
			unholsterTool(player, child :: Tool, toolState)
		end
		task.spawn(initCharacterTool, child :: Tool)
	end)

	scriptConnections.CharChildRemoved = character.ChildRemoved:Connect(function(child)
		if not child:IsA("Tool") then
			return
		end
		detachCharacterToolFromGrip(child :: Tool, torso)
		local toolState = tools[child :: Tool]
		if toolState then
			local stats = GunStats.get(child.Name)
			if stats and child.Name ~= "GPR" then
				local holsterPartName = stats.HolsterPart or "Torso"
				local holsterOffset = stats.HolsterOffset or CFrame.identity
				holsterTool(player, child :: Tool, toolState, character, holsterPartName, holsterOffset)
			end
		end
	end)

	scriptConnections.BackpackChildAdded = backpack.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then
			return
		end
		task.spawn(initBackpackTool, child :: Tool)
	end)

	scriptConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			cleanupAllPlayerTools(tools, scriptConnections, isCleanedUp, player)
		end
	end)

	scriptConnections.CharacterRemoving = player.CharacterRemoving:Connect(function(removingChar)
		if removingChar == character then
			cleanupAllPlayerTools(tools, scriptConnections, isCleanedUp, player)
		end
	end)

	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") then
			task.spawn(initBackpackTool, tool :: Tool)
		end
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			attachCharacterToolToGrip(child :: Tool, torso)
			task.spawn(initCharacterTool, child :: Tool)
		end
	end

	setupTorsoVisibilityTracking(player, character)
end

local function onPlayerAdded(player: Player): ()
	playerCharacterConns[player] = player.CharacterAdded:Connect(function(character)
		task.defer(setupToolsForPlayer, player, character)
	end)

	if player.Character then
		task.defer(setupToolsForPlayer, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player): ()
	local conn = playerCharacterConns[player]
	if conn then
		conn:Disconnect()
		playerCharacterConns[player] = nil
	end

	local scriptConns = playerScriptConns[player]
	if scriptConns then
		disconnectAll(scriptConns)
		playerScriptConns[player] = nil
	end

	local pending = pendingHolsterRequests[player]
	if pending then
		task.cancel(pending)
		pendingHolsterRequests[player] = nil
	end

	clearAllHolstersForPlayer(player)
end

local REQUEST_DEBOUNCE = 0.5

local function handleRequestAllHolsters(player: Player)
	local existing = pendingHolsterRequests[player]
	if existing then
		task.cancel(existing)
	end
	pendingHolsterRequests[player] = task.delay(REQUEST_DEBOUNCE, function()
		pendingHolsterRequests[player] = nil
		sendAllHolstersToPlayer(player)
	end)
end

function WeaponService:start(): ()
	GunSkinService = LazyService.create(MainModule, "GunSkinService")()

	getOrCreateRemotes()

	RequestAllHolstersEvent.OnServerEvent:Connect(handleRequestAllHolsters)

	if GunSkinService and GunSkinService.OnSkinApplied then
		table.insert(
			serviceConnections,
			GunSkinService:OnSkinApplied(function(targetPlayer: Player, _itemId: string)
				local holsters = playerHolsters[targetPlayer]
				if not holsters then
					return
				end
				for weaponName, data in holsters do
					local newSkinId = resolvePlayerSkinId(targetPlayer, weaponName)
					local newSkinIdToStore = if newSkinId and newSkinId ~= "" then newSkinId else nil
					data.skinId = newSkinIdToStore
					fireHolster(targetPlayer, weaponName, data.holsterPart, data.holsterOffset, newSkinIdToStore)
					broadcastHolsterToAll(targetPlayer, weaponName, data.holsterPart, data.holsterOffset, newSkinIdToStore)
				end
			end)
		)
	end

	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function WeaponService:Cleanup(): ()
	for player in pairs(playerHolsters) do
		clearAllHolstersForPlayer(player)
	end
	playerHolsters = {}

	for player, pending in pairs(pendingHolsterRequests) do
		task.cancel(pending)
		pendingHolsterRequests[player] = nil
	end

	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for player, conn in playerCharacterConns do
		if conn then
			conn:Disconnect()
		end
		playerCharacterConns[player] = nil
	end

	for player, conns in playerScriptConns do
		if conns then
			disconnectAll(conns)
		end
		playerScriptConns[player] = nil
	end

	GunSkinService = nil
end

return WeaponService
