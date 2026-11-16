--!strict
--!native
--!optimize 2
--#selene: allow(deprecated)

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationController = require(script.AnimationController)
local ZoomController = require(script.ZoomController)

local MainModule = script.Parent.Parent.Parent
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)
local GunStats = require(MainModule.Shared.Config.GunStats)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Core = require(MainModule.Shared.Network.Core)

type WeaponState = WeaponConfig.WeaponState

local WeaponService = {}
WeaponService.Name = "WeaponService"

local player = Players.LocalPlayer
local character: Model? = nil
local humanoid: Humanoid? = nil
local animator: Animator? = nil

local equippedTool: Tool? = nil
local currentState: WeaponState = "Idle"

local isFiring = false
local isZooming = false
local isEquipping = false
local isRunning = false
local lastSprintBreakForFire = 0

local inputConnections: { RBXScriptConnection } = {}
local characterConnection: RBXScriptConnection? = nil
local toolConnections: { RBXScriptConnection } = {}
local remoteConnections: { RBXScriptConnection } = {}

local isInitialized = false
local zoomChangedCallback: ((zooming: boolean) -> ())? = nil
local rightGripDelayThread: thread? = nil
local defaultKeybinds = WeaponConfig.DefaultKeybinds
local animationPreloadList: { Animation } = {}

local holsterClones: { [string]: Model } = {}
local holsterDataCache: { [string]: { holsterPart: string, holsterOffset: CFrame, skinId: string? } } = {}
local holsterThreads: { [string]: thread } = {}

local localHolsterFolder: Folder? = nil

local torsoVisibilityStates: { [string]: boolean } = {}
local torsoVisibilityConnections: { [Player]: RBXScriptConnection } = {}

local REMOTE_NAMES = {
	REQUEST_ALL_HOLSTERS = "RequestAllHolsters",
}

local function getLocalHolsterFolder(): Folder
	if localHolsterFolder and localHolsterFolder.Parent then
		return localHolsterFolder
	end

	local ignore = workspace:FindFirstChild("Ignore")
	if not ignore then
		ignore = Instance.new("Folder")
		ignore.Name = "Ignore"
		ignore.Parent = workspace
	end

	local userFolder = ignore:FindFirstChild(tostring(player.UserId))
	if not userFolder then
		local f = Instance.new("Folder")
		f.Name = tostring(player.UserId)
		f.Parent = ignore
		userFolder = f
	end

	localHolsterFolder = userFolder :: Folder
	return localHolsterFolder
end

local function destroyLocalHolsterFolder(): ()
	if localHolsterFolder and localHolsterFolder.Parent then
		localHolsterFolder:ClearAllChildren()
	end
	localHolsterFolder = nil
end

local function shouldShowHolsterForPlayer(targetPlayer: Player?): boolean
	local settings = ServiceLocator.Settings()
	if not settings then
		return true
	end
	local holsterSetting = settings:GetSetting("Holsters") or SettingsEnums.Holsters.All

	if holsterSetting == SettingsEnums.Holsters.None then
		return false
	elseif holsterSetting == SettingsEnums.Holsters.Self then
		return targetPlayer == player
	elseif holsterSetting == SettingsEnums.Holsters.All then
		return true
	end
	return true
end

local function isPlayerTorsoVisible(targetPlayer: Player): boolean
	local targetChar = targetPlayer.Character
	if not targetChar or not targetChar.Parent then
		return false
	end

	local torso = targetChar:FindFirstChild("Torso") :: BasePart?
	if not torso then
		torso = targetChar:FindFirstChild("UpperTorso") :: BasePart?
	end

	if not torso then
		return false
	end

	return torso.Transparency < 0.99
end

local function removeHolsterRuntimeDescendants(instance: Instance): ()
	for _, desc in instance:GetDescendants() do
		if desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") or desc:IsA("BaseScript") or desc:IsA("Sound") then
			desc:Destroy()
		end
	end
end

local function buildHolsterClone(weaponName: string, holsterPartInstance: BasePart, holsterOffset: CFrame, skinId: string?): Model?
	local toolTemplates = ReplicatedStorage:FindFirstChild("ToolTemplates")
	if not toolTemplates then
		return nil
	end

	local toolTemplate = toolTemplates:FindFirstChild(weaponName)
	if not toolTemplate or not toolTemplate:IsA("Tool") then
		return nil
	end

	local defaultGunModel = toolTemplate:FindFirstChild("GunModel") :: Model? or toolTemplate:FindFirstChildOfClass("Model")

	local toolHandle = toolTemplate:FindFirstChild("Handle") :: BasePart?
	if not toolHandle then
		return nil
	end

	local skinModelClone: Model? = nil

	local referenceGunName = GunStats.get(weaponName) and GunStats.get(weaponName).SkinReferenceGun
	local referenceTemplate = referenceGunName and toolTemplates:FindFirstChild(referenceGunName)
	local referenceGunModel = (referenceTemplate and (referenceTemplate:FindFirstChild("GunModel") or referenceTemplate:FindFirstChildOfClass("Model"))) or defaultGunModel
	local referenceHandle = (referenceTemplate and referenceTemplate:FindFirstChild("Handle") :: BasePart?) or toolHandle

	if skinId then
		local skinTemplates = ReplicatedStorage:FindFirstChild("SkinTemplates")
		if skinTemplates then
			local collectionFolder = skinTemplates:FindFirstChild(skinId)
			if collectionFolder then
				local skinModel = collectionFolder:FindFirstChild(weaponName)
				if not skinModel and referenceGunName then
					skinModel = collectionFolder:FindFirstChild(referenceGunName)
				end
				if not skinModel and skinId == "Maxwell" then
					skinModel = collectionFolder:FindFirstChild("H-82")
				end
				if skinModel and skinModel:IsA("Model") then
					local relParts: { [string]: CFrame } = {}
					if referenceGunModel then
						for _, desc in referenceGunModel:GetDescendants() do
							if desc:IsA("BasePart") then
								relParts[desc.Name] = referenceHandle.CFrame:Inverse() * desc.CFrame
							end
						end
					end

					skinModelClone = skinModel:Clone()

					for _, desc in skinModelClone:GetDescendants() do
						if desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") then
							desc:Destroy()
						end
					end

					local transform: CFrame? = nil
					for _, desc in skinModelClone:GetDescendants() do
						if desc:IsA("BasePart") and relParts[desc.Name] then
							transform = (toolHandle.CFrame * relParts[desc.Name]) * desc.CFrame:Inverse()
							break
						end
					end
					if not transform then
						transform = toolHandle.CFrame * skinModelClone:GetPivot():Inverse()
					end

					for _, desc in skinModelClone:GetDescendants() do
						if desc:IsA("BasePart") then
							desc.CFrame = transform * desc.CFrame
							desc.Anchored = false
							desc.CanCollide = false
							desc.CanQuery = false
							desc.CanTouch = false
							desc.Massless = true
							desc.CastShadow = false
						end
					end
				end
			end
		end
	end

	local cloneHandle = toolHandle:Clone()
	removeHolsterRuntimeDescendants(cloneHandle)
	cloneHandle.CanCollide = false
	cloneHandle.CanQuery = false
	cloneHandle.Anchored = false
	cloneHandle.Massless = true

	local clone = Instance.new("Model")
	clone.Name = "LocalHolster_" .. weaponName
	cloneHandle.Parent = clone

	local sourceParts: { BasePart } = {}
	if skinModelClone then
		for _, desc in skinModelClone:GetDescendants() do
			if desc:IsA("BasePart") then
				table.insert(sourceParts, desc)
			end
		end
	elseif defaultGunModel then
		for _, desc in defaultGunModel:GetDescendants() do
			if desc:IsA("BasePart") then
				table.insert(sourceParts, desc)
			end
		end
	else
		for _, desc in toolTemplate:GetChildren() do
			if desc:IsA("BasePart") and desc ~= toolHandle and desc.Name ~= "BodyAttach" then
				table.insert(sourceParts, desc)
			end
		end
	end

	for _, desc in sourceParts do
		local partClone = desc:Clone()
		partClone.CanCollide = false
		partClone.CanQuery = false
		partClone.CanTouch = false
		partClone.CastShadow = false
		partClone.Anchored = false
		partClone.Massless = true
		removeHolsterRuntimeDescendants(partClone)

		local weld = Instance.new("Weld")
		weld.Name = "PartWeld"
		weld.Part0 = cloneHandle
		weld.Part1 = partClone
		weld.C0 = toolHandle.CFrame:Inverse() * desc.CFrame
		weld.C1 = CFrame.identity
		weld.Parent = partClone

		partClone.Parent = clone
	end

	clone.PrimaryPart = cloneHandle
	clone:PivotTo(holsterPartInstance.CFrame * holsterOffset:Inverse())

	local weld = Instance.new("Weld")
	weld.Name = "HolsterWeld"
	weld.Part0 = cloneHandle
	weld.Part1 = holsterPartInstance
	weld.C0 = holsterOffset
	weld.C1 = CFrame.identity
	weld.Parent = cloneHandle

	clone.Parent = getLocalHolsterFolder()

	if skinModelClone then
		skinModelClone:Destroy()
	end

	return clone
end

local function getHolsterKey(targetPlayer: Player, weaponName: string): string
	return targetPlayer.Name .. "_" .. weaponName
end

local function hasSameHolsterData(
	data: { holsterPart: string, holsterOffset: CFrame, skinId: string? }?,
	holsterPartName: string,
	holsterOffset: CFrame,
	skinId: string?
): boolean
	return data ~= nil and data.holsterPart == holsterPartName and data.holsterOffset == holsterOffset and data.skinId == skinId
end

local function destroyHolsterClone(holsterKey: string): ()
	local thread = holsterThreads[holsterKey]
	if thread then
		task.cancel(thread)
		holsterThreads[holsterKey] = nil
	end

	local clone = holsterClones[holsterKey]
	if clone and clone.Parent then
		clone:Destroy()
	end
	holsterClones[holsterKey] = nil
end

local function destroyAllHolstersForPlayer(targetPlayer: Player): ()
	for key, clone in pairs(holsterClones) do
		if key:find(targetPlayer.Name, 1, true) then
			local thread = holsterThreads[key]
			if thread then
				task.cancel(thread)
				holsterThreads[key] = nil
			end
			if clone and clone.Parent then
				clone:Destroy()
			end
			holsterClones[key] = nil
		end
	end

	for key in pairs(holsterDataCache) do
		if key:find(targetPlayer.Name, 1, true) then
			holsterDataCache[key] = nil
		end
	end
end

local function destroyAllHolsterClones(): ()
	for key in pairs(holsterClones) do
		destroyHolsterClone(key)
	end
	table.clear(holsterClones)
end

local HOLSTER_DEBOUNCE = 0.05

local function onHolsterTool(targetPlayer: Player, weaponName: string, holsterPartName: string, holsterOffset: CFrame, skinId: string?): ()
	if not targetPlayer or not targetPlayer.Parent then
		return
	end
	local holsterKey = getHolsterKey(targetPlayer, weaponName)
	local dataKey = targetPlayer.Name .. "_" .. weaponName

	if targetPlayer == player then
		if (equippedTool and equippedTool.Name == weaponName) or (character and character:FindFirstChild(weaponName) and character[weaponName]:IsA("Tool")) then
			destroyHolsterClone(holsterKey)
			holsterDataCache[dataKey] = nil
			return
		end
	end

	local targetChar = targetPlayer.Character
	if targetChar then
		local equippedInChar = targetChar:FindFirstChild(weaponName)
		if equippedInChar and equippedInChar:IsA("Tool") then
			destroyHolsterClone(holsterKey)
			holsterDataCache[dataKey] = nil
			return
		end
	end

	local cachedData = holsterDataCache[dataKey]
	local isDuplicateData = hasSameHolsterData(cachedData, holsterPartName, holsterOffset, skinId)

	holsterDataCache[dataKey] = { holsterPart = holsterPartName, holsterOffset = holsterOffset, skinId = skinId }

	if not shouldShowHolsterForPlayer(targetPlayer) then
		return
	end

	if not isPlayerTorsoVisible(targetPlayer) then
		return
	end

	local existingThread = holsterThreads[holsterKey]
	local existingClone = holsterClones[holsterKey]

	local currentHolsterPart = if targetChar
		then (targetChar:FindFirstChild(holsterPartName) :: BasePart? or targetChar:FindFirstChild("Torso") :: BasePart? or targetChar:FindFirstChild(
			"UpperTorso"
		) :: BasePart?)
		else nil
	local existingWeld = if existingClone then existingClone:FindFirstChild("HolsterWeld", true) :: Weld? else nil
	local hasValidWeld = existingWeld ~= nil and existingWeld.Part1 ~= nil and existingWeld.Part1 == currentHolsterPart and existingWeld.Part1.Parent ~= nil

	if isDuplicateData and ((existingClone and existingClone.Parent and hasValidWeld) or existingThread) then
		return
	end

	if existingThread then
		task.cancel(existingThread)
		holsterThreads[holsterKey] = nil
	end

	if existingClone and existingClone.Parent then
		existingClone:Destroy()
		holsterClones[holsterKey] = nil
	end

	holsterThreads[holsterKey] = task.delay(HOLSTER_DEBOUNCE, function()
		holsterThreads[holsterKey] = nil

		local currentCharacter = targetPlayer.Character
		if not currentCharacter or not currentCharacter.Parent then
			return
		end

		if not isPlayerTorsoVisible(targetPlayer) then
			return
		end

		if targetPlayer == player and equippedTool and equippedTool.Name == weaponName then
			return
		end

		local equippedInChar = currentCharacter:FindFirstChild(weaponName)
		if equippedInChar and equippedInChar:IsA("Tool") then
			return
		end

		local holsterPart = currentCharacter:FindFirstChild(holsterPartName) :: BasePart?
		if not holsterPart then
			holsterPart = currentCharacter:FindFirstChild("Torso") :: BasePart? or currentCharacter:FindFirstChild("UpperTorso") :: BasePart?
		end
		if not holsterPart then
			return
		end

		local clone = buildHolsterClone(weaponName, holsterPart, holsterOffset, skinId)
		if not clone then
			return
		end

		holsterClones[holsterKey] = clone
	end)
end

local function onUnholsterTool(targetPlayer: Player, weaponName: string): ()
	local dataKey = targetPlayer.Name .. "_" .. weaponName
	holsterDataCache[dataKey] = nil

	local holsterKey = getHolsterKey(targetPlayer, weaponName)
	destroyHolsterClone(holsterKey)
end

local function onClearAllHolstersForPlayer(targetPlayer: Player): ()
	destroyAllHolstersForPlayer(targetPlayer)
end

local function onSpectatorClear(): ()
	onClearAllHolstersForPlayer(player)
end

local function rebuildHolstersForPlayer(targetPlayer: Player)
	local prefix = targetPlayer.Name .. "_"

	for dataKey, data in pairs(holsterDataCache) do
		if dataKey:sub(1, #prefix) == prefix then
			local weaponName = dataKey:sub(#targetPlayer.Name + 2)
			local existingThread = holsterThreads[dataKey]
			local existingClone = holsterClones[dataKey]

			if existingThread then
				task.cancel(existingThread)
				holsterThreads[dataKey] = nil
			end

			if existingClone and existingClone.Parent then
				existingClone:Destroy()
				holsterClones[dataKey] = nil
			end

			local targetChar = targetPlayer.Character
			if targetChar and targetChar.Parent and isPlayerTorsoVisible(targetPlayer) then
				if targetPlayer == player and equippedTool and equippedTool.Name == weaponName then
					continue
				end
				local equippedInChar = targetChar:FindFirstChild(weaponName)
				if equippedInChar and equippedInChar:IsA("Tool") then
					continue
				end
				local holsterPart = targetChar:FindFirstChild(data.holsterPart) :: BasePart?
				if not holsterPart then
					holsterPart = targetChar:FindFirstChild("Torso") :: BasePart? or targetChar:FindFirstChild("UpperTorso") :: BasePart?
				end
				if holsterPart then
					local clone = buildHolsterClone(weaponName, holsterPart, data.holsterOffset, data.skinId)
					if clone then
						holsterClones[dataKey] = clone
					end
				end
			end
		end
	end
end

local function rebuildAllHolsters(): ()
	local settings = ServiceLocator.Settings()
	if not settings then
		return
	end

	local holsterSetting = settings:GetSetting("Holsters") or SettingsEnums.Holsters.All

	destroyAllHolsterClones()

	if holsterSetting == SettingsEnums.Holsters.None then
		return
	elseif holsterSetting == SettingsEnums.Holsters.Self then
		for dataKey, data in holsterDataCache do
			if dataKey:sub(1, #player.Name) == player.Name then
				local weaponName = dataKey:sub(#player.Name + 2)
				if isPlayerTorsoVisible(player) then
					onHolsterTool(player, weaponName, data.holsterPart, data.holsterOffset, data.skinId)
				end
			end
		end
	elseif holsterSetting == SettingsEnums.Holsters.All then
		for dataKey, data in holsterDataCache do
			local matchedPlayer: Player? = nil
			for _, p in Players:GetPlayers() do
				local prefix = p.Name .. "_"
				if dataKey:sub(1, #prefix) == prefix then
					matchedPlayer = p
					break
				end
			end
			if matchedPlayer then
				local weaponName = dataKey:sub(#matchedPlayer.Name + 2)
				if isPlayerTorsoVisible(matchedPlayer) then
					onHolsterTool(matchedPlayer, weaponName, data.holsterPart, data.holsterOffset, data.skinId)
				end
			end
		end

		local requestRemote = Core.getOrCreateRemoteEvent(REMOTE_NAMES.REQUEST_ALL_HOLSTERS)
		requestRemote:FireServer()
	end
end

local function setupTorsoVisibilityTracking(targetPlayer: Player)
	local targetChar = targetPlayer.Character
	if not targetChar then
		return
	end

	local torso = targetChar:FindFirstChild("Torso") :: BasePart?
	if not torso then
		torso = targetChar:FindFirstChild("UpperTorso") :: BasePart?
	end

	if not torso then
		return
	end

	torsoVisibilityStates[targetPlayer.Name] = isPlayerTorsoVisible(targetPlayer)

	local connection
	connection = torso:GetPropertyChangedSignal("Transparency"):Connect(function()
		if not torso.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local wasVisible = torsoVisibilityStates[targetPlayer.Name] or false
		local isNowVisible = isPlayerTorsoVisible(targetPlayer)

		if wasVisible == isNowVisible then
			torsoVisibilityStates[targetPlayer.Name] = isNowVisible
			return
		end

		torsoVisibilityStates[targetPlayer.Name] = isNowVisible

		if isNowVisible then
			rebuildHolstersForPlayer(targetPlayer)
		else
			local prefix = targetPlayer.Name .. "_"
			for dataKey, clone in pairs(holsterClones) do
				if dataKey:sub(1, #prefix) == prefix and clone and clone.Parent then
					clone:Destroy()
					holsterClones[dataKey] = nil
				end
			end

			for dataKey, thread in pairs(holsterThreads) do
				if dataKey:sub(1, #prefix) == prefix then
					task.cancel(thread)
					holsterThreads[dataKey] = nil
				end
			end
		end
	end)

	if torsoVisibilityConnections[targetPlayer] then
		torsoVisibilityConnections[targetPlayer]:Disconnect()
	end
	torsoVisibilityConnections[targetPlayer] = connection
end

local playerLifecycleConnections: { [Player]: { RBXScriptConnection } } = {}

local function onPlayerAdded(targetPlayer: Player): ()
	local conns: { RBXScriptConnection } = {}
	playerLifecycleConnections[targetPlayer] = conns

	local function onCharAdded(newChar: Model)
		setupTorsoVisibilityTracking(targetPlayer)
		task.defer(function()
			if targetPlayer.Character == newChar and newChar.Parent then
				rebuildHolstersForPlayer(targetPlayer)
			end
		end)
	end

	local function onCharRemoving(_oldChar: Model)
		destroyAllHolstersForPlayer(targetPlayer)
	end

	if targetPlayer.Character then
		onCharAdded(targetPlayer.Character)
	end

	table.insert(conns, targetPlayer.CharacterAdded:Connect(onCharAdded))
	table.insert(conns, targetPlayer.CharacterRemoving:Connect(onCharRemoving))
end

local function onPlayerRemoving(targetPlayer: Player): ()
	local conns = playerLifecycleConnections[targetPlayer]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerLifecycleConnections[targetPlayer] = nil
	end

	destroyAllHolstersForPlayer(targetPlayer)
	torsoVisibilityStates[targetPlayer.Name] = nil
	if torsoVisibilityConnections[targetPlayer] then
		torsoVisibilityConnections[targetPlayer]:Disconnect()
		torsoVisibilityConnections[targetPlayer] = nil
	end
end

local function wireRemotes(): ()
	local holsterRemote = Core.getOrCreateRemoteEvent("WeaponHolster")
	local unholsterRemote = Core.getOrCreateRemoteEvent("WeaponUnholster")
	local spectatorRemote = Core.getOrCreateRemoteEvent("WeaponSpectatorHolsters")
	local broadcastRemote = Core.getOrCreateRemoteEvent("WeaponHolsterBroadcast")
	local visibilityRemote = Core.getOrCreateRemoteEvent("PlayerVisibilityChanged")

	table.insert(
		remoteConnections,
		holsterRemote.OnClientEvent:Connect(function(weaponName: string, holsterPart: string, holsterOffset: CFrame, skinId: string?)
			onHolsterTool(player, weaponName, holsterPart, holsterOffset, if skinId ~= "" then skinId else nil)
		end)
	)

	table.insert(
		remoteConnections,
		unholsterRemote.OnClientEvent:Connect(function(weaponName: string)
			onUnholsterTool(player, weaponName)
		end)
	)

	table.insert(
		remoteConnections,
		spectatorRemote.OnClientEvent:Connect(function(holsterType: string, _weaponList: any)
			if holsterType == "Clear" then
				onSpectatorClear()
			end
		end)
	)

	table.insert(
		remoteConnections,
		broadcastRemote.OnClientEvent:Connect(function(targetPlayer: Player, weaponName: string, holsterPart: string, holsterOffset: CFrame, skinId: string?)
			if not targetPlayer or not targetPlayer.Parent then
				return
			end
			if weaponName == "__CLEAR_ALL__" then
				onClearAllHolstersForPlayer(targetPlayer)
			elseif holsterPart and holsterOffset then
				onHolsterTool(targetPlayer, weaponName, holsterPart, holsterOffset, if skinId ~= "" then skinId else nil)
			else
				onUnholsterTool(targetPlayer, weaponName)
			end
		end)
	)

	table.insert(
		remoteConnections,
		visibilityRemote.OnClientEvent:Connect(function(targetPlayer: Player, isVisible: boolean)
			if not targetPlayer or not targetPlayer.Parent then
				return
			end
			torsoVisibilityStates[targetPlayer.Name] = isVisible
			if isVisible then
				rebuildHolstersForPlayer(targetPlayer)
			else
				local prefix = targetPlayer.Name .. "_"
				for dataKey, clone in pairs(holsterClones) do
					if dataKey:sub(1, #prefix) == prefix and clone and clone.Parent then
						clone:Destroy()
						holsterClones[dataKey] = nil
					end
				end
			end
		end)
	)
end

local function buildPreloadList(): ()
	local seen: { [string]: boolean } = {}
	local function addAssetId(assetId: string): ()
		if seen[assetId] then
			return
		end
		seen[assetId] = true
		local anim = Instance.new("Animation")
		anim.AnimationId = assetId
		table.insert(animationPreloadList, anim)
	end
	for _, classConfig in WeaponConfig.Classes do
		for _, id in classConfig.Animations do
			addAssetId(id)
		end
	end
	for _, stats in GunStats.Guns do
		if not stats.Animations then
			continue
		end
		for _, numId in stats.Animations do
			addAssetId("rbxassetid://" .. tostring(numId))
		end
	end
end

local function getRightHand(char: Model): BasePart?
	return (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")) :: BasePart?
end

local function destroyRightGrip(): ()
	if not character then
		return
	end
	local rh = getRightHand(character)
	if rh then
		local rg = rh:FindFirstChild("RightGrip")
		if rg then
			rg:Destroy()
		end
	end
end

local function getTorso(char: Model): BasePart?
	return (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) :: BasePart?
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

local function attachToolToGrip(tool: Tool, torso: BasePart): ()
	prepareToolForBodyAttach(tool)

	local toolGrip = torso:FindFirstChild("ToolGrip") :: Motor6D?
	if not toolGrip then
		toolGrip = Instance.new("Motor6D")
		toolGrip.Name = "ToolGrip"
		toolGrip.Part0 = torso
		toolGrip.Part1 = nil
		toolGrip.Parent = torso
	end

	local bodyAttach = tool:FindFirstChild("BodyAttach")
	if bodyAttach and bodyAttach:IsA("BasePart") then
		toolGrip.Part1 = bodyAttach
		toolGrip.C1 = tool.Name == "GPR" and CFrame.Angles(0, -math.pi / 2, 0) or CFrame.identity
		return
	end
	local handle = getToolHandle(tool)
	if handle then
		toolGrip.Part1 = handle
		toolGrip.C1 = tool.Name == "GPR" and CFrame.Angles(0, -math.pi / 2, 0) or CFrame.identity
	end
end

local function detachToolFromGrip(tool: Tool, torso: BasePart?): ()
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

local function getKeybind(action: string): Enum.KeyCode
	local settings = ServiceLocator.Settings()
	if settings then
		local keyName = settings:GetKeybind(action)
		if keyName then
			local ok, keyCode = pcall(function()
				return (Enum.KeyCode :: any)[keyName]
			end)
			if ok and keyCode then
				return keyCode
			end
		end
	end
	return defaultKeybinds[action] or Enum.KeyCode.None
end

local function getSpeeds(): WeaponConfig.SpeedConfig
	if equippedTool then
		return WeaponConfig.getSpeeds(equippedTool.Name)
	end
	return WeaponConfig.DefaultSpeeds
end

local function setWalkSpeed(speed: number): ()
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function adjustCrouchSpeed(): ()
	AnimationController.adjustCrouchSpeed(isRunning)
end

local function isSprinting(): boolean
	return character and character:GetAttribute("Sprinting") == true
end

local function isCrouching(): boolean
	return character and character:GetAttribute("Crouching") == true
end

local function isSaluting(): boolean
	return character and character:GetAttribute("Saluting") == true
end

local function playCurrentAnimation(fadeTime: number?): ()
	if not equippedTool then
		return
	end

	local speeds = getSpeeds()
	local sprinting = isSprinting()
	local crouching = isCrouching()
	local saluting = isSaluting()

	if isFiring and not WeaponConfig.canSprintWhileFiring(equippedTool.Name) and sprinting then
		sprinting = false
	end

	if saluting then
		AnimationController.stop("Sprint", fadeTime)
		AnimationController.play("Idle", fadeTime)
		if crouching then
			AnimationController.play("Crouch", fadeTime)
			adjustCrouchSpeed()
			setWalkSpeed(if isZooming then speeds.Zoom else speeds.Crouch)
		else
			AnimationController.stop("Crouch", fadeTime)
			setWalkSpeed(if isZooming then speeds.Zoom else speeds.Walk)
		end
		currentState = "Saluting"
		return
	end

	if crouching then
		AnimationController.stop("Sprint", fadeTime)
		AnimationController.play("Crouch", fadeTime)
		AnimationController.play("Idle", fadeTime)
		setWalkSpeed(if isZooming then speeds.Zoom else speeds.Crouch)
		adjustCrouchSpeed()
		currentState = "Crouching"
		return
	end

	if sprinting then
		AnimationController.stop("Idle", fadeTime)
		AnimationController.stop("Crouch", fadeTime)
		AnimationController.play("Sprint", fadeTime)
		setWalkSpeed(speeds.Sprint)
		currentState = "Sprinting"
		return
	end

	AnimationController.stop("Sprint", fadeTime)
	AnimationController.stop("Crouch", fadeTime)
	AnimationController.play("Idle", fadeTime)
	setWalkSpeed(if isZooming then speeds.Zoom else speeds.Walk)
	currentState = "Idle"
end

local function updateState(): ()
	if not equippedTool then
		return
	end
	playCurrentAnimation()
end

local function onToolEquipped(tool: Tool): ()
	if isEquipping then
		return
	end

	local config = WeaponConfig.getToolConfig(tool.Name)
	if not config then
		return
	end
	if not character or not character.Parent then
		return
	end

	isEquipping = true
	equippedTool = tool
	prepareToolForBodyAttach(tool)

	local dataKey = player.Name .. "_" .. tool.Name
	holsterDataCache[dataKey] = nil

	local holsterKey = getHolsterKey(player, tool.Name)
	destroyHolsterClone(holsterKey)

	if tool.Name == "GPR" then
		local movementService = ServiceLocator.get("MovementService")
		if movementService then
			if movementService:IsCrouching() then
				movementService:SetCrouching(false)
			end

			if movementService:IsSprinting() then
				movementService:SetSprinting(false)
			end
		end
		local cursorService = ServiceLocator.get("CursorService")
		if cursorService then
			cursorService:SetIFFEnabled(false)
		end
	end

	destroyRightGrip()
	AnimationController.loadAnimations(tool)

	local charTorso = getTorso(character)
	if charTorso then
		attachToolToGrip(tool, charTorso)
	end

	playCurrentAnimation()

	if rightGripDelayThread then
		task.cancel(rightGripDelayThread)
	end
	rightGripDelayThread = task.delay(0.1, function()
		rightGripDelayThread = nil
		if equippedTool ~= tool then
			return
		end
		destroyRightGrip()
	end)

	isEquipping = false
end

local function onToolUnequipped(_tool: Tool): ()
	if not equippedTool then
		return
	end
	isEquipping = false
	local wasSprinting = isSprinting()
	local tool = equippedTool

	if character and character.Parent then
		local charTorso = getTorso(character)
		detachToolFromGrip(tool, charTorso)
	end

	local cursorService = ServiceLocator.get("CursorService")
	if cursorService then
		cursorService:SetOverrideCursor(nil)
		if tool and tool.Name == "GPR" then
			cursorService:SetIFFEnabled(true)
		end
	end

	equippedTool = nil
	AnimationController.unloadAnimations()
	isFiring = false
	currentState = "Idle"
	isRunning = false
	lastSprintBreakForFire = 0

	setWalkSpeed(if wasSprinting then WeaponConfig.DefaultSpeeds.Sprint else WeaponConfig.DefaultSpeeds.Walk)
end

local function isMeleeTool(tool: Tool?): boolean
	if not tool then
		return false
	end
	if tool.Name == "Sword" then
		return true
	end
	local stats = GunStats.get(tool.Name)
	return stats ~= nil and stats.Mode == "Melee"
end

local function setupCharacter(char: Model): ()
	destroyAllHolsterClones()
	table.clear(holsterDataCache)

	character = char
	humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
	end

	for _, conn in toolConnections do
		conn:Disconnect()
	end
	table.clear(toolConnections)

	equippedTool = nil
	isFiring = false
	isZooming = false
	isEquipping = false
	currentState = "Idle"
	isRunning = false
	lastSprintBreakForFire = 0

	AnimationController.setAnimator(animator)
	ZoomController.reset()

	if humanoid and animator then
		task.spawn(AnimationController.warmTrackCache)
	end

	if humanoid and not animator then
		table.insert(
			toolConnections,
			humanoid.ChildAdded:Connect(function(child)
				if not child:IsA("Animator") then
					return
				end
				animator = child :: Animator
				AnimationController.setAnimator(animator)
				task.spawn(AnimationController.warmTrackCache)
				if equippedTool then
					local tool = equippedTool
					task.defer(function()
						if equippedTool == tool and animator then
							AnimationController.loadAnimations(tool)
							playCurrentAnimation()
						end
					end)
				end
			end)
		)
	end

	local rightHand = getRightHand(char)
	if rightHand then
		local existing = rightHand:FindFirstChild("RightGrip") :: Motor6D?
		if existing then
			local tool = char:FindFirstChildOfClass("Tool") or (existing.Part1 and existing.Part1.Parent)
			if not isMeleeTool(tool) then
				existing:Destroy()
			end
		end
		table.insert(
			toolConnections,
			rightHand.ChildAdded:Connect(function(child)
				if child.Name == "RightGrip" and child:IsA("Motor6D") then
					task.defer(function()
						if not child.Parent then
							return
						end
						local tool = char:FindFirstChildOfClass("Tool") or (child.Part1 and child.Part1.Parent)
						if isMeleeTool(tool) then
							return
						end
						child.Part0 = nil
						child.Part1 = nil
						child:Destroy()
					end)
				end
			end)
		)
	end

	local charTorso = getTorso(char)
	local function bindToolGrip(toolGrip: Motor6D)
		table.insert(
			toolConnections,
			toolGrip:GetPropertyChangedSignal("Part1"):Connect(function()
				local activeTool = equippedTool or (character and character:FindFirstChildWhichIsA("Tool"))
				if activeTool and activeTool.Parent == character and not isMeleeTool(activeTool) then
					local expectedPart = activeTool:FindFirstChild("BodyAttach") or getToolHandle(activeTool)
					if expectedPart and toolGrip.Part1 ~= expectedPart then
						local currentTorso = toolGrip.Part0 or getTorso(character) or charTorso
						if currentTorso and currentTorso:IsA("BasePart") then
							attachToolToGrip(activeTool, currentTorso :: BasePart)
						end
					end
				end
			end)
		)
	end

	if charTorso then
		local existingToolGrip = charTorso:FindFirstChild("ToolGrip") :: Motor6D?
		if existingToolGrip and existingToolGrip:IsA("Motor6D") then
			bindToolGrip(existingToolGrip)
		end
		table.insert(
			toolConnections,
			charTorso.ChildAdded:Connect(function(child)
				if child.Name == "ToolGrip" and child:IsA("Motor6D") then
					bindToolGrip(child)
					local activeTool = equippedTool or (character and character:FindFirstChildWhichIsA("Tool"))
					if activeTool and activeTool.Parent == character and not isMeleeTool(activeTool) then
						attachToolToGrip(activeTool, charTorso)
					end
				end
			end)
		)
	end

	table.insert(
		toolConnections,
		char.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") and (child.Name == "Torso" or child.Name == "UpperTorso") then
				local existing = child:FindFirstChild("ToolGrip") :: Motor6D?
				if existing and existing:IsA("Motor6D") then
					bindToolGrip(existing)
				end
				table.insert(
					toolConnections,
					child.ChildAdded:Connect(function(grandchild)
						if grandchild.Name == "ToolGrip" and grandchild:IsA("Motor6D") then
							bindToolGrip(grandchild)
							local activeTool = equippedTool or (character and character:FindFirstChildWhichIsA("Tool"))
							if activeTool and activeTool.Parent == character and not isMeleeTool(activeTool) then
								attachToolToGrip(activeTool, child)
							end
						end
					end)
				)
			elseif child:IsA("Tool") then
				if isMeleeTool(child) then
					return
				end
				local currentTorso = getTorso(char)
				if currentTorso then
					attachToolToGrip(child, currentTorso)
				end
				onToolEquipped(child)
			end
		end)
	)

	table.insert(
		toolConnections,
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				if isMeleeTool(child) then
					return
				end
				detachToolFromGrip(child, getTorso(char))
				if child == equippedTool then
					onToolUnequipped(child)
				end
			end
		end)
	)

	if humanoid then
		table.insert(
			toolConnections,
			humanoid.Running:Connect(function(speed)
				isRunning = speed > 4
				adjustCrouchSpeed()
			end)
		)

		table.insert(
			toolConnections,
			humanoid.Died:Connect(function()
				local wasZooming = isZooming
				if wasZooming then
					ZoomController.applyZoom(false)
				end
				AnimationController.unloadAnimations()
				AnimationController.clearTrackCache()
				destroyAllHolsterClones()
				table.clear(holsterDataCache)
				equippedTool = nil
				isFiring = false
				isZooming = false
				currentState = "Idle"
				isRunning = false
				lastSprintBreakForFire = 0
				if wasZooming and zoomChangedCallback then
					zoomChangedCallback(false)
				end
			end)
		)
	end

	table.insert(toolConnections, char:GetAttributeChangedSignal("Crouching"):Connect(updateState))
	table.insert(toolConnections, char:GetAttributeChangedSignal("Sprinting"):Connect(updateState))
	table.insert(toolConnections, char:GetAttributeChangedSignal("Saluting"):Connect(updateState))

	local existingTool = char:FindFirstChildWhichIsA("Tool")
	if existingTool then
		if not isMeleeTool(existingTool) then
			if charTorso then
				attachToolToGrip(existingTool, charTorso)
			end
			onToolEquipped(existingTool)
		end
	end

	rebuildAllHolsters()
end

local function cleanupCharacter(): ()
	for _, conn in toolConnections do
		conn:Disconnect()
	end
	table.clear(toolConnections)

	for _, conn in pairs(torsoVisibilityConnections) do
		if conn then
			conn:Disconnect()
		end
	end
	table.clear(torsoVisibilityConnections)

	if isZooming then
		ZoomController.applyZoom(false)
	end

	AnimationController.unloadAnimations()
	AnimationController.clearTrackCache()
	destroyAllHolsterClones()
	table.clear(holsterDataCache)

	character = nil
	humanoid = nil
	animator = nil
	equippedTool = nil
	isFiring = false
	isZooming = false
	isEquipping = false
	currentState = "Idle"
	isRunning = false
	lastSprintBreakForFire = 0
end

local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed or not equippedTool then
		return
	end

	local keyCode = input.KeyCode
	local userInputType = input.UserInputType

	if userInputType == Enum.UserInputType.MouseButton1 then
		local gunService = ServiceLocator.get("GunService")
		if gunService and gunService:IsReloading() then
			return
		end
		local movementService = ServiceLocator.get("MovementService")
		if movementService then
			movementService:OnFiringStarted()
		end
		isFiring = true
		local canSprintWhileFiring = WeaponConfig.canSprintWhileFiring(equippedTool.Name)
		if not canSprintWhileFiring and isSprinting() then
			lastSprintBreakForFire = os.clock()
			local ms = ServiceLocator.get("MovementService")
			if ms then
				ms:SetSprinting(false)
			end
			playCurrentAnimation(AnimationController.SprintToFireFadeTime)
		else
			updateState()
		end
	elseif keyCode == getKeybind("Zoom") then
		isZooming = not isZooming
		ZoomController.applyZoom(isZooming)
		if zoomChangedCallback then
			zoomChangedCallback(isZooming)
		end
		updateState()
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean): ()
	if not equippedTool then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = false
		updateState()
	end
end

function WeaponService:init(): ()
	buildPreloadList()
	task.spawn(function()
		ContentProvider:PreloadAsync(animationPreloadList)
	end)
	ZoomController.init()
	wireRemotes()
	isInitialized = true
end

function WeaponService:start(): ()
	if not isInitialized then
		self:init()
	end

	local settings = ServiceLocator.Settings()
	if settings then
		table.insert(
			inputConnections,
			settings.SettingChanged:Connect(function(key: string, _value: any)
				if key == "Holsters" then
					rebuildAllHolsters()
				end
			end)
		)
	end

	table.insert(inputConnections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(inputConnections, UserInputService.InputEnded:Connect(onInputEnded))

	characterConnection = player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	for _, p in Players:GetPlayers() do
		if p ~= player then
			onPlayerAdded(p)
		end
	end

	table.insert(
		remoteConnections,
		Players.PlayerAdded:Connect(function(newPlayer)
			if newPlayer ~= player then
				onPlayerAdded(newPlayer)
			end
		end)
	)

	table.insert(
		remoteConnections,
		Players.PlayerRemoving:Connect(function(oldPlayer)
			if oldPlayer ~= player then
				onPlayerRemoving(oldPlayer)
			end
		end)
	)
end

function WeaponService:PlayFireAnimation(): ()
	local fadeTime = if os.clock() - lastSprintBreakForFire < AnimationController.SprintToFireFadeTime
		then AnimationController.SprintFireFadeTime
		else AnimationController.FireFadeTime
	AnimationController.play("Fire", fadeTime)
end

function WeaponService:StartFiring(): ()
	if not equippedTool then
		return
	end
	isFiring = true
	local canSprintWhileFiring = WeaponConfig.canSprintWhileFiring(equippedTool.Name)
	if not canSprintWhileFiring and isSprinting() then
		lastSprintBreakForFire = os.clock()
		local ms = ServiceLocator.get("MovementService")
		if ms then
			ms:SetSprinting(false)
		end
		playCurrentAnimation(AnimationController.SprintToFireFadeTime)
	else
		updateState()
	end
end

function WeaponService:StopFiring(): ()
	isFiring = false
	updateState()
end

function WeaponService:GetCurrentState(): WeaponState
	return currentState
end

function WeaponService:IsFiring(): boolean
	return isFiring
end

function WeaponService:IsSprinting(): boolean
	return isSprinting()
end

function WeaponService:IsCrouching(): boolean
	return isCrouching()
end

function WeaponService:IsZooming(): boolean
	return isZooming
end

function WeaponService:OnZoomChanged(callback: (zooming: boolean) -> ()): ()
	zoomChangedCallback = callback
end

function WeaponService:SetZooming(zooming: boolean): ()
	if isZooming == zooming then
		return
	end
	isZooming = zooming
	ZoomController.applyZoom(zooming)
	if zoomChangedCallback then
		zoomChangedCallback(zooming)
	end
	updateState()
end

function WeaponService:IsSaluting(): boolean
	return isSaluting()
end

function WeaponService:CanSprintWhileFiring(): boolean
	if not equippedTool then
		return false
	end
	return WeaponConfig.canSprintWhileFiring(equippedTool.Name)
end

function WeaponService:HasWeaponEquipped(): boolean
	return equippedTool ~= nil
end

function WeaponService:GetEquippedWeaponName(): string?
	return equippedTool and equippedTool.Name or nil
end

function WeaponService:PredictEquip(_weaponName: string): () end
function WeaponService:PredictUnequip(): () end

function WeaponService:GetEquippedClass(): WeaponConfig.WeaponClass?
	if equippedTool then
		return WeaponConfig.getToolClass(equippedTool.Name)
	end
	return nil
end

function WeaponService:IsToolProperlyAttached(): boolean
	if not equippedTool or not character or not character.Parent then
		return false
	end
	local charTorso = getTorso(character)
	if not charTorso then
		return false
	end
	local toolGrip = charTorso:FindFirstChild("ToolGrip") :: Motor6D?
	return toolGrip ~= nil and toolGrip.Part0 ~= nil and toolGrip.Part1 ~= nil
end

function WeaponService:EnsureToolAttached(): boolean
	if not equippedTool or not character or not character.Parent then
		return false
	end
	destroyRightGrip()
	prepareToolForBodyAttach(equippedTool)

	local charTorso = getTorso(character)

	if not charTorso then
		return false
	end
	local toolGrip = charTorso:FindFirstChild("ToolGrip") :: Motor6D?
	if not toolGrip or not toolGrip.Part0 then
		return false
	end
	if not toolGrip.Part1 then
		attachToolToGrip(equippedTool, charTorso)
	end
	return toolGrip.Part1 ~= nil
end

function WeaponService:Cleanup(): ()
	for _, conn in inputConnections do
		conn:Disconnect()
	end
	table.clear(inputConnections)

	for _, conn in remoteConnections do
		conn:Disconnect()
	end
	table.clear(remoteConnections)

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if rightGripDelayThread then
		task.cancel(rightGripDelayThread)
		rightGripDelayThread = nil
	end

	cleanupCharacter()
	destroyLocalHolsterFolder()

	for p, conns in playerLifecycleConnections do
		for _, conn in conns do
			conn:Disconnect()
		end
		destroyAllHolstersForPlayer(p)
	end
	table.clear(playerLifecycleConnections)

	ZoomController.cleanup()
	zoomChangedCallback = nil

	for _, anim in animationPreloadList do
		anim:Destroy()
	end
	table.clear(animationPreloadList)
	isInitialized = false
end

return WeaponService
