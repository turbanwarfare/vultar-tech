--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local RankCache = require(MainModule.Server.Cache.RankCache)
local Uniforms = require(MainModule.Shared.Config.Uniforms)

local AvatarService = {}
AvatarService.Name = "AvatarService"

type AvatarState = {
	showHats: boolean,
	equippedUniform: string?,
	equippedVariantKey: string?,
	noobicSkinColor: boolean,
	torsoColor: number,
}

type AvatarClientState = {
	showHats: boolean,
	equippedUniform: string?,
	equippedVariantKey: string?,
	availableUniforms: { string },
	noobicSkinColor: boolean,
	torsoColor: number,
}

local DATASTORE_NAME = "AvatarState_v2"
local SAVE_DEBOUNCE = 3
local MAX_STATE_WAIT = 50

local NOOBIC_HEAD_ARM_COLOR = Color3.fromRGB(224, 206, 34)
local NOOBIC_LEG_COLOR = Color3.fromRGB(164, 185, 58)
local TORSO_COLORS: { Color3 } = {
	Color3.fromRGB(18, 102, 172),
	Color3.fromRGB(190, 32, 23),
	Color3.fromRGB(87, 157, 69),
}

local playerStates: { [Player]: AvatarState } = {}
local playerStateLoaded: { [Player]: boolean } = {}
local playerDescriptions: { [Player]: HumanoidDescription } = {}
local playerCharacterConns: { [Player]: RBXScriptConnection } = {}
local spawnedWithLook: { [Player]: boolean } = {}
local pendingSaveThreads: { [Player]: thread } = {}
local connections: { RBXScriptConnection } = {}

local avatarDataStore: DataStore? = nil

local function getDataStore(): DataStore?
	if avatarDataStore then
		return avatarDataStore
	end
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, DATASTORE_NAME)
	if ok then
		avatarDataStore = store :: DataStore
		return avatarDataStore
	end
	return nil
end

local function loadStateFromStore(player: Player): AvatarState
	local store = getDataStore()
	if not store then
		return {
			showHats = true,
			equippedUniform = nil,
			equippedVariantKey = nil,
			noobicSkinColor = false,
			torsoColor = 1,
		}
	end
	local ok, data = pcall(store.GetAsync, store, "user_" .. player.UserId)
	if ok and type(data) == "table" then
		return {
			showHats = if type(data.showHats) == "boolean" then data.showHats else true,
			equippedUniform = nil,
			equippedVariantKey = nil,
			noobicSkinColor = if type(data.noobicSkinColor) == "boolean" then data.noobicSkinColor else false,
			torsoColor = if type(data.torsoColor) == "number" then math.clamp(data.torsoColor, 1, 3) else 1,
		}
	end
	return { showHats = true, equippedUniform = nil, equippedVariantKey = nil, noobicSkinColor = false, torsoColor = 1 }
end

local function buildSavePayload(state: AvatarState): { [string]: any }
	return {
		showHats = state.showHats,
		noobicSkinColor = state.noobicSkinColor,
		torsoColor = state.torsoColor,
	}
end

local function flushSaveNow(player: Player, state: AvatarState): ()
	local saveThread = pendingSaveThreads[player]
	if saveThread then
		task.cancel(saveThread)
		pendingSaveThreads[player] = nil
	end
	local store = getDataStore()
	if not store then
		return
	end
	local ok, err = pcall(store.SetAsync, store, "user_" .. player.UserId, buildSavePayload(state))
	if not ok then
		warn("[AvatarService] Failed to flush save for", player.Name, "-", err)
	end
end

local function scheduleSave(player: Player, state: AvatarState): ()
	local existing = pendingSaveThreads[player]
	if existing then
		task.cancel(existing)
	end
	pendingSaveThreads[player] = task.delay(SAVE_DEBOUNCE, function()
		pendingSaveThreads[player] = nil
		local store = getDataStore()
		if not store then
			return
		end
		local ok, err = pcall(store.SetAsync, store, "user_" .. player.UserId, buildSavePayload(state))
		if not ok then
			warn("[AvatarService] Failed to save for", player.Name, "-", err)
		end
	end)
end

local function getAvailableUniforms(player: Player): { string }
	local available: { string } = {}
	local checkedGroups: { [number]: boolean } = {}
	for _, uniform in Uniforms.All do
		if checkedGroups[uniform.groupId] == nil then
			checkedGroups[uniform.groupId] = RankCache.isInGroup(player, uniform.groupId)
		end
		if checkedGroups[uniform.groupId] then
			table.insert(available, uniform.key)
		end
	end
	return available
end

local function buildClientState(player: Player): AvatarClientState
	local state = playerStates[player]
		or { showHats = true, equippedUniform = nil, equippedVariantKey = nil, noobicSkinColor = false, torsoColor = 1 }
	return {
		showHats = state.showHats,
		equippedUniform = state.equippedUniform,
		equippedVariantKey = state.equippedVariantKey,
		availableUniforms = getAvailableUniforms(player),
		noobicSkinColor = state.noobicSkinColor,
		torsoColor = state.torsoColor,
	}
end

local function removeAccessories(character: Model): ()
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end
end

local function applyBodyColors(character: Model, state: AvatarState): ()
	local torsoColor = TORSO_COLORS[math.clamp(state.torsoColor, 1, 3)]
	local bc = character:FindFirstChildOfClass("BodyColors")
	if not bc then
		local newBc = Instance.new("BodyColors")
		newBc.Parent = character
		bc = newBc
	end
	bc.HeadColor3 = NOOBIC_HEAD_ARM_COLOR
	bc.LeftArmColor3 = NOOBIC_HEAD_ARM_COLOR
	bc.RightArmColor3 = NOOBIC_HEAD_ARM_COLOR
	bc.TorsoColor3 = torsoColor
	bc.LeftLegColor3 = NOOBIC_LEG_COLOR
	bc.RightLegColor3 = NOOBIC_LEG_COLOR
end

local function buildModifiedDesc(baseDesc: HumanoidDescription, state: AvatarState): HumanoidDescription
	local modified = baseDesc:Clone()

	if state.equippedUniform then
		local shirtId, pantId = Uniforms.getClothingIds(state.equippedUniform, state.equippedVariantKey)
		modified.Shirt = shirtId or 0
		modified.Pants = pantId or 0
	end

	if not state.showHats then
		modified.HatAccessory = ""
		modified.HairAccessory = ""
		modified.FaceAccessory = ""
		modified.NeckAccessory = ""
		modified.ShouldersAccessory = ""
		modified.FrontAccessory = ""
		modified.BackAccessory = ""
		modified.WaistAccessory = ""
	end

	return modified
end

local function needsDescriptionOverride(state: AvatarState): boolean
	return state.equippedUniform ~= nil or not state.showHats
end

local function applyStateToCharacter(player: Player, character: Model, state: AvatarState, forceApply: boolean?): ()
	local hum = character:FindFirstChildWhichIsA("Humanoid")
	if not hum then
		return
	end

	if forceApply or needsDescriptionOverride(state) then
		local baseDesc = playerDescriptions[player]
		if not baseDesc then
			local ok, freshDesc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
			if ok and freshDesc and player.Parent then
				baseDesc = freshDesc :: HumanoidDescription
				playerDescriptions[player] = baseDesc
			end
		end
		if baseDesc then
			local modified = buildModifiedDesc(baseDesc :: HumanoidDescription, state)
			pcall(hum.ApplyDescriptionAsync, hum, modified)
		elseif not state.showHats then
			removeAccessories(character)
		end
	end

	if state.noobicSkinColor then
		applyBodyColors(character, state)
	end
end

local function onCharacterAdded(player: Player, character: Model): ()
	local state = playerStates[player]
	if not state then
		return
	end
	if spawnedWithLook[player] then
		spawnedWithLook[player] = nil
		if state.noobicSkinColor then
			applyBodyColors(character, state)
		end
		return
	end
	task.defer(function()
		if not character.Parent then
			return
		end
		applyStateToCharacter(player, character, state)
	end)
end

local function onPlayerAdded(player: Player): ()
	task.spawn(function()
		task.spawn(function()
			local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
			if ok and desc and player.Parent then
				playerDescriptions[player] = desc :: HumanoidDescription
			end
		end)

		local state = loadStateFromStore(player)
		playerStates[player] = state
		playerStateLoaded[player] = true

		playerCharacterConns[player] = player.CharacterAdded:Connect(function(character: Model)
			onCharacterAdded(player, character)
		end)

		local character = player.Character
		if character then
			onCharacterAdded(player, character)
		end
	end)
end

local function onPlayerRemoving(player: Player): ()
	local conn = playerCharacterConns[player]
	if conn then
		conn:Disconnect()
		playerCharacterConns[player] = nil
	end
	local state = playerStates[player]
	if state then
		flushSaveNow(player, state)
	end
	playerStates[player] = nil
	playerStateLoaded[player] = nil
	playerDescriptions[player] = nil
	spawnedWithLook[player] = nil
end

function AvatarService:init(): () end

function AvatarService:LoadCharacter(player: Player): ()
	local state = playerStates[player]
	local baseDesc = playerDescriptions[player]
	if not (state and baseDesc and needsDescriptionOverride(state)) then
		player:LoadCharacterAsync()
		return
	end
	spawnedWithLook[player] = true
	local ok, err = pcall(player.LoadCharacterWithHumanoidDescriptionAsync, player, buildModifiedDesc(baseDesc, state))
	if not ok then
		spawnedWithLook[player] = nil
		error(err, 0)
	end
end

function AvatarService:start(): ()
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	table.insert(
		connections,
		Network.Avatar.onGetState(function(player: Player)
			local waited = 0
			while not playerStateLoaded[player] and waited < MAX_STATE_WAIT do
				task.wait(0.1)
				waited += 1
			end
			return buildClientState(player)
		end)
	)

	table.insert(
		connections,
		Network.Avatar.onToggleHats(function(player: Player, showHats: boolean)
			local state = playerStates[player]
			if not state then
				return
			end
			state.showHats = showHats
			local character = player.Character
			if character then
				applyStateToCharacter(player, character, state, true)
			end
			scheduleSave(player, state)
			Network.Avatar.sendStateUpdate(player, buildClientState(player))
		end)
	)

	table.insert(
		connections,
		Network.Avatar.onEquipUniform(function(player: Player, uniformKey: string, variantKey: string?)
			local state = playerStates[player]
			if not state then
				return
			end
			local uniform = Uniforms.byKey[uniformKey]
			if not uniform then
				Network.Avatar.sendStateUpdate(player, buildClientState(player))
				return
			end
			if not RankCache.isInGroup(player, uniform.groupId) then
				Network.Avatar.sendStateUpdate(player, buildClientState(player))
				return
			end
			if variantKey and uniform.variants then
				for _, v in uniform.variants do
					if v.key == variantKey then
						if v.minRank and not RankCache.isInGroup(player, uniform.groupId, v.minRank) then
							Network.Avatar.sendStateUpdate(player, buildClientState(player))
							return
						end
						break
					end
				end
			end
			state.equippedUniform = uniformKey
			state.equippedVariantKey = variantKey
			local character = player.Character
			if character then
				applyStateToCharacter(player, character, state)
			end
			scheduleSave(player, state)
			Network.Avatar.sendStateUpdate(player, buildClientState(player))
		end)
	)

	table.insert(
		connections,
		Network.Avatar.onUnequipUniform(function(player: Player)
			local state = playerStates[player]
			if not state then
				return
			end
			state.equippedUniform = nil
			state.equippedVariantKey = nil
			local character = player.Character
			if character then
				local hum = character:FindFirstChildWhichIsA("Humanoid")
				if hum then
					local baseDesc = playerDescriptions[player]
					if baseDesc then
						local modified = buildModifiedDesc(baseDesc, state)
						pcall(hum.ApplyDescriptionAsync, hum, modified)
					end
				end
				if state.noobicSkinColor then
					applyBodyColors(character, state)
				end
			end
			scheduleSave(player, state)
			Network.Avatar.sendStateUpdate(player, buildClientState(player))
		end)
	)

	table.insert(
		connections,
		Network.Avatar.onSetNoobicSkinColor(function(player: Player, enabled: boolean)
			local state = playerStates[player]
			if not state then
				return
			end
			state.noobicSkinColor = enabled
			local character = player.Character
			if character then
				applyStateToCharacter(player, character, state)
			end
			scheduleSave(player, state)
			Network.Avatar.sendStateUpdate(player, buildClientState(player))
		end)
	)

	table.insert(
		connections,
		Network.Avatar.onSetTorsoColor(function(player: Player, colorIndex: number)
			local state = playerStates[player]
			if not state then
				return
			end
			state.torsoColor = math.clamp(colorIndex, 1, 3)
			local character = player.Character
			if character and state.noobicSkinColor then
				applyBodyColors(character, state)
			end
			scheduleSave(player, state)
			Network.Avatar.sendStateUpdate(player, buildClientState(player))
		end)
	)
end

function AvatarService:Cleanup(): ()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	for _, conn in playerCharacterConns do
		conn:Disconnect()
	end
	table.clear(playerCharacterConns)
	for _, thread in pendingSaveThreads do
		task.cancel(thread)
	end
	table.clear(pendingSaveThreads)
	table.clear(playerStates)
	table.clear(playerStateLoaded)
	table.clear(playerDescriptions)
	table.clear(spawnedWithLook)
end

return AvatarService
