--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent
local ToolAssetCache = require(MainModule.Server.Cache.ToolAssetCache)
local Network = require(MainModule.Shared.Network)
local Constants = require(MainModule.Shared.Config.Constants)
local InventoryConfig = require(MainModule.Shared.Config.Inventory.InventoryConfig)
local TeamService = require(script.Parent.TeamService)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local Maps = require(MainModule.Shared.Config.Maps)
local GunStats = require(MainModule.Shared.Config.GunStats)
local FeatureFlags = require(MainModule.Shared.Config.FeatureFlags)
local ServiceTrove = require(MainModule.Shared.Utils.Services.ServiceTrove)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local GroupUtils = require(MainModule.Shared.Utils.Game.GroupUtils)
local Core = require(MainModule.Shared.Network.Core)

local getReconAntiMacroService = LazyService.create(MainModule, "ReconAntiMacroService")

type InventoryItem = InventoryConfig.InventoryItem
type InventoryState = InventoryConfig.InventoryState

local InventoryService = {}
InventoryService.Name = "InventoryService"

local playerInventories: { [number]: InventoryState } = {}
local playerBackpacks: { [number]: Backpack } = {}
local playerLastAction: { [number]: number } = {}
local playerTroves: { [number]: ServiceTrove.ServiceTrove } = {}
local playerCharacterTroves: { [number]: ServiceTrove.ServiceTrove } = {}
local playerToolSet: { [number]: { [string]: boolean } } = {}
local serviceTrove: ServiceTrove.ServiceTrove = nil :: any
local isInitialized = false

local isLoadingTools = false
local toolsModule: { [string]: Tool } = {}
local toolsLoaded = false
local loadToolsFromCache: () -> boolean

local BODY_ATTACH_SIZE = Vector3.new(0.1, 0.1, 0.1)

local DEV_GUN_NAME = "H-94-DEV"
local DEV_GUN_REMOTE = "RequestDevGun"
local DEV_GUN_GROUP = Constants.GROUPS.VULTAR
local DEV_GUN_MIN_RANK = 254
local DEV_GUN_COOLDOWN = 1
local devGunCooldowns: { [number]: number } = {}

local rng = Random.new()

local GunSkinService: any = nil
local ClassServiceRef: any = nil

local ACTION_COOLDOWN = 0.25

local FACTION_LOADOUTS: { [string]: { string } } = {
	Defenders = { "H-82", "Medi+" },
	Raiders = { "BR-16", "Medi+" },
	Spectators = {},
	Neutral = {},
}

local inventoryChanged = Signal.new()

local playerEquipLock: { [number]: boolean } = {}

local isRunning = false

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local userId = player.UserId
	local last = playerLastAction[userId]
	if last and (now - last) < ACTION_COOLDOWN then
		return true
	end
	playerLastAction[userId] = now
	return false
end

local function acquireEquipLock(player: Player): boolean
	local userId = player.UserId
	if playerEquipLock[userId] then
		return false
	end
	playerEquipLock[userId] = true
	return true
end

local function releaseEquipLock(player: Player): ()
	playerEquipLock[player.UserId] = nil
end

local idCounter = 0
local function generateItemId(): string
	idCounter += 1
	return tostring(os.clock()) .. "_" .. tostring(rng:NextInteger(100000, 999999)) .. "_" .. tostring(idCounter)
end

local function playerHasToolByName(player: Player, toolName: string): boolean
	local userId = player.UserId
	local toolSet = playerToolSet[userId]
	if not toolSet then
		return false
	end
	return toolSet[toolName] == true
end

local function addToolToSet(player: Player, toolName: string): ()
	local userId = player.UserId
	if not playerToolSet[userId] then
		playerToolSet[userId] = {}
	end
	playerToolSet[userId][toolName] = true
end

local function removeToolFromSet(player: Player, toolName: string): ()
	local userId = player.UserId
	local toolSet = playerToolSet[userId]
	if toolSet then
		toolSet[toolName] = nil
	end
end

local function clearToolSet(player: Player): ()
	playerToolSet[player.UserId] = nil
end

local function getPlayerInventory(player: Player): InventoryState
	local userId = player.UserId
	if not playerInventories[userId] then
		playerInventories[userId] = InventoryConfig.createDefaultState()
	end
	return playerInventories[userId]
end

local function notifyInventoryChange(player: Player, action: string, item: InventoryItem?, slot: number?): ()
	local state = getPlayerInventory(player)

	inventoryChanged:Fire(player, state)

	Network.Inventory.broadcastInventoryUpdate(player, {
		action = action :: any,
		item = item,
		slot = slot,
		state = state,
	})
end

local function syncToolToInventory(player: Player, tool: Tool): InventoryItem?
	if playerHasToolByName(player, tool.Name) then
		return nil
	end

	local state = getPlayerInventory(player)

	for _, item in state.Items do
		if item.Tool == tool then
			return nil
		end
	end

	local slot = InventoryConfig.getNextAvailableSlot(state.Items)
	if not slot then
		return nil
	end

	local item: InventoryItem = {
		Id = generateItemId(),
		Name = tool.Name,
		Tool = tool,
		Slot = slot,
		Icon = if tool:FindFirstChild("TextureId") then (tool :: any).TextureId else nil,
	}

	table.insert(state.Items, item)
	addToolToSet(player, tool.Name)
	return item
end

local function removeToolFromInventory(player: Player, tool: Tool): InventoryItem?
	local state = getPlayerInventory(player)

	for i, item in state.Items do
		if item.Tool == tool then
			table.remove(state.Items, i)
			removeToolFromSet(player, item.Name)
			if state.EquippedSlot == item.Slot then
				state.EquippedSlot = nil
			end
			return item
		end
	end

	return nil
end

local function getPlayerTrove(player: Player): ServiceTrove.ServiceTrove?
	if not isRunning then
		return nil
	end
	local userId = player.UserId
	local trove = playerTroves[userId]
	if not trove then
		trove = serviceTrove:Extend()
		playerTroves[userId] = trove
	end
	return trove
end

local function getCharacterTrove(player: Player): ServiceTrove.ServiceTrove?
	if not isRunning then
		return nil
	end
	local userId = player.UserId
	local existing = playerCharacterTroves[userId]
	if existing then
		existing:Destroy()
		playerCharacterTroves[userId] = nil
	end
	local playerTrove = getPlayerTrove(player)
	if not playerTrove then
		return nil
	end
	local trove = playerTrove:Extend()
	playerCharacterTroves[userId] = trove
	return trove
end

local function setupBackpackListeners(player: Player): ()
	local backpack = player:WaitForChild("Backpack", 10) :: Backpack?
	if not backpack then
		return
	end

	if not isRunning then
		return
	end

	playerBackpacks[player.UserId] = backpack

	local trove = getPlayerTrove(player)
	if not trove then
		return
	end

	trove:Connect(backpack.ChildAdded, function(child)
		if child:IsA("Tool") then
			local item = syncToolToInventory(player, child)
			if item then
				notifyInventoryChange(player, "add", item, item.Slot)
			end
		end
	end)

	trove:Connect(backpack.ChildRemoved, function(child)
		if child:IsA("Tool") then
			local character = player.Character
			if character and child.Parent == character then
				return
			end

			local item = removeToolFromInventory(player, child)
			if item then
				notifyInventoryChange(player, "remove", item, item.Slot)
			end
		end
	end)

	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") then
			syncToolToInventory(player, child)
		end
	end
end

local function getPlayerBackpack(player: Player): Backpack?
	return player:FindFirstChildOfClass("Backpack")
end

local function fixBarrelAttachment(tool: Tool): ()
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end

	local barrelAttachment = handle:FindFirstChild("Barrel")
	if not barrelAttachment or not barrelAttachment:IsA("Attachment") then
		return
	end

	local gunModel = tool:FindFirstChild("GunModel") :: Model?
	if not gunModel then
		return
	end

	local baWorldPos = barrelAttachment.WorldPosition
	for _, desc in gunModel:GetDescendants() do
		local descName = string.lower(desc.Name)
		if desc:IsA("BasePart") and string.find(descName, "barrel") then
			local sz = desc.Size
			local cf = desc.CFrame
			local halfX, halfY, halfZ = sz.X / 2, sz.Y / 2, sz.Z / 2
			local faces = {
				(cf * CFrame.new(halfX, 0, 0)).Position,
				(cf * CFrame.new(-halfX, 0, 0)).Position,
				(cf * CFrame.new(0, halfY, 0)).Position,
				(cf * CFrame.new(0, -halfY, 0)).Position,
				(cf * CFrame.new(0, 0, halfZ)).Position,
				(cf * CFrame.new(0, 0, -halfZ)).Position,
			}

			local tipWorldPos = faces[1]
			local tipDist = (tipWorldPos - baWorldPos).Magnitude
			for i = 2, 6 do
				local d = (faces[i] - baWorldPos).Magnitude
				if d < tipDist then
					tipDist = d
					tipWorldPos = faces[i]
				end
			end

			local localPos = handle.CFrame:PointToObjectSpace(tipWorldPos)
			barrelAttachment.CFrame = CFrame.new(localPos) * barrelAttachment.CFrame.Rotation
			return
		end
	end

	local baOffset = tool:GetAttribute("BarrelOffset") :: Vector3?
	if baOffset then
		barrelAttachment.CFrame = CFrame.new(-baOffset) * barrelAttachment.CFrame
		tool:SetAttribute("BarrelOffset", nil)
	end
end

local function ensureToolsLoaded(timeout: number?): boolean
	if toolsLoaded and next(toolsModule) ~= nil then
		return true
	end

	if not isLoadingTools then
		task.spawn(loadToolsFromCache)
	end

	local maxWait = timeout or 5
	local waitStart = os.clock()
	while not toolsLoaded and (os.clock() - waitStart) < maxWait do
		task.wait(0.1)
	end

	return toolsLoaded and next(toolsModule) ~= nil
end

local function giveToolToPlayer(player: Player, toolName: string): ()
	if playerHasToolByName(player, toolName) then
		return
	end

	if not toolsLoaded or not toolsModule[toolName] then
		ensureToolsLoaded(3)
	end

	if not isRunning then
		return
	end
	if not player.Parent then
		return
	end

	local toolTemplate = toolsModule[toolName]
	if not toolTemplate then
		warn("[InventoryService] Tool not found:", toolName)
		return
	end

	local backpack = getPlayerBackpack(player)
	if not backpack then
		warn("[InventoryService] No backpack for player:", player.Name)
		return
	end

	local tool = toolTemplate:Clone()
	tool.RequiresHandle = tool.Name == "Sword"

	local stats = GunStats.get(tool.Name)
	if stats and stats.Sounds and stats.Sounds.Fire then
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if handle then
			local fireSoundStr = tostring(stats.Sounds.Fire)
			local correctSoundId = if string.find(fireSoundStr, "://") then fireSoundStr else "rbxassetid://" .. fireSoundStr
			local fireSound = handle:FindFirstChild("Fire") :: Sound?
			if not fireSound then
				fireSound = Instance.new("Sound")
				fireSound.Name = "Fire"
				fireSound.Volume = 0.5
				fireSound.RollOffMode = Enum.RollOffMode.InverseTapered
				fireSound.RollOffMinDistance = 10
				fireSound.RollOffMaxDistance = 300
				fireSound.Parent = handle
			end
			fireSound.SoundId = correctSoundId
		end
	end

	local state = getPlayerInventory(player)
	local slot = InventoryConfig.getNextAvailableSlot(state.Items)
	if not slot then
		tool:Destroy()
		return
	end

	local item: InventoryItem = {
		Id = generateItemId(),
		Name = tool.Name,
		Tool = tool,
		Slot = slot,
		Icon = nil,
	}
	table.insert(state.Items, item)
	addToolToSet(player, toolName)

	tool.Parent = backpack

	local skinSvc = GunSkinService
	if skinSvc then
		skinSvc:ApplySkinToTool(player, tool)
	end

	fixBarrelAttachment(tool)

	local handle = tool:FindFirstChild("Handle")
	if handle then
		local grip = handle:FindFirstChild("Grip") :: Motor6D?
		if not grip then
			grip = handle:FindFirstChildOfClass("Motor6D")
		end
		if grip then
			grip.Part0 = nil
			grip.Part1 = handle
		end
	end
end

local function getLoadoutForPlayer(player: Player): { string }
	if player:GetAttribute("InAimChamberMatch") then
		local gun = player:GetAttribute("AimChamberSelectedGun")
		if gun then
			return { gun }
		end
		return {}
	end

	if player:GetAttribute("InDuel") then
		return {}
	end

	local faction = TeamService:GetPlayerFaction(player)
	if not faction or faction == "Spectators" or faction == "Neutral" then
		return {}
	end

	local forcedWeapon = Maps.getForceWeapon(nil, faction)
	if forcedWeapon then
		return { forcedWeapon, "Medi+" }
	end

	if FeatureFlags.isEnabled("ClassSystem") then
		local classSvc = ClassServiceRef
		if classSvc then
			local weapons = classSvc:GetWeaponsForPlayer(player)
			if #weapons > 0 then
				return weapons
			end
		end
	end

	return FACTION_LOADOUTS[faction] or {}
end

local function giveLoadoutToPlayer(player: Player): ()
	local loadout = getLoadoutForPlayer(player)
	if #loadout == 0 then
		return
	end

	if not toolsLoaded then
		ensureToolsLoaded(5)
	end

	for _, toolName in loadout do
		giveToolToPlayer(player, toolName)
	end
end

local function handleDevGunRequest(player: Player): ()
	if not isRunning then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local last = devGunCooldowns[userId]
	if last and (now - last) < DEV_GUN_COOLDOWN then
		return
	end
	devGunCooldowns[userId] = now

	if not GroupUtils.isInGroup(player, DEV_GUN_GROUP, DEV_GUN_MIN_RANK) then
		return
	end

	if playerHasToolByName(player, DEV_GUN_NAME) then
		return
	end

	giveToolToPlayer(player, DEV_GUN_NAME)
	notifyInventoryChange(player, "full", nil, nil)
end

local function clearPlayerTools(player: Player): ()
	local state = getPlayerInventory(player)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end

	for _, item in state.Items do
		if item.Tool then
			item.Tool:Destroy()
		end
	end

	state.Items = {}
	state.EquippedSlot = nil
	clearToolSet(player)
end

local function refreshLoadout(player: Player): ()
	if not isRunning then
		return
	end
	if not player.Parent then
		return
	end
	clearPlayerTools(player)
	giveLoadoutToPlayer(player)
	notifyInventoryChange(player, "full", nil, nil)
end

local function setupCharacterListeners(player: Player): ()
	local function onCharacterAdded(character: Model)
		if not isRunning then
			return
		end

		local charTrove = getCharacterTrove(player)
		if not charTrove then
			return
		end

		charTrove:Connect(character.ChildAdded, function(child)
			if child:IsA("Tool") then
				local antiMacroSvc = getReconAntiMacroService()
				if antiMacroSvc and antiMacroSvc.IsSwitchLocked(player, child.Name) then
					antiMacroSvc.RecordSwitchAttempt(player, child.Name)
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack then
						child.Parent = backpack
					end
					return
				end
				local state = getPlayerInventory(player)
				for _, item in state.Items do
					if item.Tool == child then
						state.EquippedSlot = item.Slot
						notifyInventoryChange(player, "equip", item, item.Slot)
						break
					end
				end
			end
		end)

		charTrove:Connect(character.ChildRemoved, function(child)
			if child:IsA("Tool") then
				local state = getPlayerInventory(player)
				if state.EquippedSlot then
					local item = InventoryConfig.findItemBySlot(state.Items, state.EquippedSlot)
					if item and item.Tool == child then
						state.EquippedSlot = nil
						notifyInventoryChange(player, "unequip", item, item.Slot)
					end
				end
			end
		end)

		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local state = getPlayerInventory(player)
				for _, item in state.Items do
					if item.Tool == child then
						state.EquippedSlot = item.Slot
						break
					end
				end
			end
		end

		task.defer(refreshLoadout, player)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end

	local trove = getPlayerTrove(player)
	if trove then
		trove:Connect(player.CharacterAdded, onCharacterAdded)
	end
end

local function onPlayerAdded(player: Player): ()
	if not isRunning then
		return
	end
	playerInventories[player.UserId] = InventoryConfig.createDefaultState()
	setupBackpackListeners(player)
	setupCharacterListeners(player)
end

local function onPlayerRemoving(player: Player): ()
	local userId = player.UserId

	local trove = playerTroves[userId]
	if trove then
		trove:Destroy()
	end

	playerTroves[userId] = nil
	playerCharacterTroves[userId] = nil
	playerInventories[userId] = nil
	playerBackpacks[userId] = nil
	playerLastAction[userId] = nil
	playerToolSet[userId] = nil
	playerEquipLock[userId] = nil
	devGunCooldowns[userId] = nil
end

local function createToolVariants(): ()
	local allGuns: { [string]: GunStats.GunProperties } = GunStats.Guns :: any
	for name, gunProps in allGuns do
		local sourceTool = gunProps.SourceTool
		if not sourceTool then
			continue
		end
		if toolsModule[name] then
			continue
		end
		local source = toolsModule[sourceTool]
		if not source then
			continue
		end
		local variant = source:Clone()
		variant.Name = name
		toolsModule[name] = variant
	end
end

local function createClientToolTemplates(): ()
	local existingFolder = ReplicatedStorage:FindFirstChild("ToolTemplates")
	if existingFolder then
		existingFolder:Destroy()
	end

	local templatesFolder = Instance.new("Folder")
	templatesFolder.Name = "ToolTemplates"

	for _, tool in toolsModule do
		local clone = tool:Clone()

		for _, desc in clone:GetDescendants() do
			if desc:IsA("BaseScript") or desc:IsA("ModuleScript") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.CanQuery = false
			end
		end

		clone.Parent = templatesFolder
	end

	templatesFolder.Parent = ReplicatedStorage
end

local function clearToolsModule(): ()
	for name, tool in toolsModule do
		tool:Destroy()
		toolsModule[name] = nil
	end
end

loadToolsFromCache = function(): boolean
	if isLoadingTools then
		while isLoadingTools do
			task.wait(0.1)
		end
		return toolsLoaded
	end

	isLoadingTools = true
	clearToolsModule()
	toolsLoaded = false

	local success, result, _err = ToolAssetCache.loadAsset()
	if not success or not result then
		isLoadingTools = false
		toolsLoaded = false
		return false
	end

	local toolsFolder = result:FindFirstChild("Tools", true)
	if toolsFolder then
		for _, child in toolsFolder:GetChildren() do
			if child:IsA("Tool") and not toolsModule[child.Name] and (GunStats.get(child.Name) or child.Name == "Sword") then
				local toolClone = child:Clone()
				toolClone.RequiresHandle = child.Name == "Sword"
				toolClone.CanBeDropped = false

				local handle = toolClone:FindFirstChild("Handle") :: BasePart?
				if not handle then
					toolClone:Destroy()
					continue
				end

				if toolClone.Name ~= "Sword" and toolClone.Name ~= "GPR" then
					handle.Transparency = 1
				else
					handle.Transparency = 0
				end
				handle.CanCollide = false
				handle.CanQuery = false
				handle.Anchored = false
				handle.Massless = true

				local barrelAttachment = handle:FindFirstChild("Barrel")
				if not barrelAttachment then
					barrelAttachment = Instance.new("Attachment")
					barrelAttachment.Name = "Barrel"
					barrelAttachment.Position = Vector3.new(0, 0, -2) -- generic offset
					barrelAttachment.Parent = handle
				end
				if barrelAttachment then
					local emitter = barrelAttachment:FindFirstChildWhichIsA("ParticleEmitter")
					while emitter do
						emitter:Destroy()
						emitter = barrelAttachment:FindFirstChildWhichIsA("ParticleEmitter")
					end
				end

				local smokeFX = handle:FindFirstChild("SmokeFX")
				if smokeFX then
					smokeFX:Destroy()
				end

				local bodyAttach = toolClone:FindFirstChild("BodyAttach") :: BasePart?
				if bodyAttach then
					local originalBA = bodyAttach.CFrame
					local handleCFrame = handle.CFrame
					local shiftCFrame = handleCFrame * originalBA:Inverse()

					bodyAttach.CFrame = handleCFrame

					local hasHandleMotor = false
					local baToHandleC0 = handleCFrame:Inverse() * originalBA
					for _, motor in bodyAttach:GetChildren() do
						if motor:IsA("Motor6D") then
							if motor.Part1 == handle then
								hasHandleMotor = true
							end
							motor.C0 = baToHandleC0 * motor.C0
						end
					end

					for _, desc in toolClone:GetDescendants() do
						if desc:IsA("BasePart") and desc ~= handle and desc ~= bodyAttach then
							desc.CFrame = shiftCFrame * desc.CFrame
						end
					end

					bodyAttach.Transparency = 1
					bodyAttach.CanCollide = false
					bodyAttach.CanQuery = false
					bodyAttach.Anchored = false
					bodyAttach.Massless = true

					if not hasHandleMotor then
						if toolClone.Name == "GPR" then
							local bodyWeld = Instance.new("Weld")
							bodyWeld.Name = "BodyWeld"
							bodyWeld.Part0 = bodyAttach
							bodyWeld.Part1 = handle
							bodyWeld.C0 = CFrame.Angles(0, math.pi / 2, 0)
							bodyWeld.Parent = bodyAttach
						else
							local bodyWeld = Instance.new("Weld")
							bodyWeld.Name = "BodyWeld"
							bodyWeld.Part0 = bodyAttach
							bodyWeld.Part1 = handle
							bodyWeld.C0 = bodyAttach.CFrame:Inverse() * handle.CFrame
							bodyWeld.C1 = CFrame.identity
							bodyWeld.Parent = bodyAttach
						end
					end

					if barrelAttachment and barrelAttachment:IsA("Attachment") then
						local baLocalOffset = handleCFrame:Inverse() * originalBA
						toolClone:SetAttribute("BarrelOffset", baLocalOffset.Position)
					end
				end

				if toolClone.Name ~= "Sword" and toolClone.Name ~= "GPR" then
					local grip = handle:FindFirstChild("Grip") :: Motor6D?
					if not grip then
						grip = handle:FindFirstChildOfClass("Motor6D")
					end
					if grip then
						grip.Name = "Grip"
						grip.Part0 = nil
						grip.Part1 = handle
					else
						local newGrip = Instance.new("Motor6D")
						newGrip.Name = "Grip"
						newGrip.Part0 = nil
						newGrip.Part1 = handle
						newGrip.Parent = handle
					end
				else
					local grip = handle:FindFirstChild("Grip") or handle:FindFirstChildOfClass("Motor6D")
					if grip then
						grip:Destroy()
					end
				end

				for _, desc in toolClone:GetDescendants() do
					if desc:IsA("BasePart") and desc ~= handle and desc ~= bodyAttach and desc.Name ~= "BodyAttach" then
						desc.Anchored = false
						desc.CanCollide = false
						desc.CanQuery = false
						desc.Massless = true
					end
				end

				toolsModule[child.Name] = toolClone
			end
		end
	end

	local skinsFolder = result:FindFirstChild("Skins", true)
	if skinsFolder then
		local defaultFolder = skinsFolder:FindFirstChild("Default")
		if defaultFolder then
			for _, model in defaultFolder:GetChildren() do
				if model:IsA("Model") and not toolsModule[model.Name] then
					local stats = GunStats.get(model.Name)
					if stats then
						local tool = Instance.new("Tool")
						tool.Name = model.Name
						tool.RequiresHandle = model.Name == "Sword"
						tool.CanBeDropped = false

						local gunModel = model:Clone()
						gunModel.Name = "GunModel"
						local handle: BasePart? = nil
						local parts: { BasePart } = {}

						for _, part in gunModel:GetDescendants() do
							if part:IsA("BasePart") then
								if part.Name == "Handle" and not handle then
									handle = part;
									(handle :: any).Parent = nil
								else
									table.insert(parts, part)
								end
							end
						end

						if not handle then
							if gunModel.PrimaryPart then
								handle = gunModel.PrimaryPart:Clone();
								(handle :: any).Name = "Handle"
							elseif #parts > 0 then
								handle = parts[1]:Clone();
								(handle :: any).Name = "Handle"
							end
						end

						if handle then
							local safeHandle = handle :: BasePart
							if tool.Name ~= "Sword" and tool.Name ~= "GPR" then
								safeHandle.Transparency = 1
							else
								safeHandle.Transparency = 0
							end
							safeHandle.CanCollide = false
							safeHandle.CanQuery = false
							safeHandle.Anchored = false
							safeHandle.Massless = true
							safeHandle.Parent = tool

							if tool.Name ~= "Sword" and tool.Name ~= "GPR" then
								local grip = Instance.new("Motor6D")
								grip.Name = "Grip"
								grip.Part0 = nil
								grip.Part1 = safeHandle
								grip.Parent = safeHandle
							end

							local barrelAttachment = safeHandle:FindFirstChild("Barrel")
							if not barrelAttachment then
								barrelAttachment = Instance.new("Attachment")
								barrelAttachment.Name = "Barrel"
								barrelAttachment.Position = Vector3.new(0, 0, -2)
								barrelAttachment.Parent = safeHandle
							end

							local bodyAttach = Instance.new("Part")
							bodyAttach.Name = "BodyAttach"
							bodyAttach.Size = BODY_ATTACH_SIZE
							bodyAttach.Transparency = 1
							bodyAttach.CanCollide = false
							bodyAttach.CanQuery = false
							bodyAttach.Anchored = false
							bodyAttach.Massless = true
							bodyAttach.CFrame = safeHandle.CFrame
							bodyAttach.Parent = tool

							if tool.Name == "GPR" then
								local bodyWeld = Instance.new("Weld")
								bodyWeld.Name = "BodyWeld"
								bodyWeld.Part0 = bodyAttach
								bodyWeld.Part1 = safeHandle
								bodyWeld.C0 = CFrame.Angles(0, math.pi / 2, 0)
								bodyWeld.Parent = bodyAttach
							else
								local bodyWeld = Instance.new("Weld")
								bodyWeld.Name = "BodyWeld"
								bodyWeld.Part0 = bodyAttach
								bodyWeld.Part1 = safeHandle
								bodyWeld.C0 = bodyAttach.CFrame:Inverse() * safeHandle.CFrame
								bodyWeld.C1 = CFrame.identity
								bodyWeld.Parent = bodyAttach
							end

							local handleCFrame = safeHandle.CFrame
							local modelPivot = gunModel:GetPivot()

							for _, part in parts do
								part.CFrame = handleCFrame * modelPivot:ToObjectSpace(part.CFrame)
								part.Anchored = false
								part.CanCollide = false
								part.CanQuery = false
								part.Massless = true

								local weld = Instance.new("Weld")
								weld.Name = "GunWeld"
								weld.Part0 = safeHandle
								weld.Part1 = part
								weld.C0 = safeHandle.CFrame:Inverse() * part.CFrame
								weld.C1 = CFrame.identity
								weld.Parent = part
							end

							gunModel.Parent = tool
							toolsModule[model.Name] = tool
						else
							gunModel:Destroy()
						end
					end
				end
			end
		end
	end

	createToolVariants()
	createClientToolTemplates()

	local toolCount = 0
	for _ in toolsModule do
		toolCount += 1
	end

	if toolCount > 0 then
		toolsLoaded = true
		isLoadingTools = false

		for _, player in Players:GetPlayers() do
			if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				task.spawn(refreshLoadout, player)
			end
		end
		return true
	else
		warn("[InventoryService] Loaded tools asset but no valid tools found")
		toolsLoaded = false
		isLoadingTools = false
		return false
	end
end

function InventoryService:init(): ()
	if isLoadingTools then
		return
	end

	task.spawn(loadToolsFromCache)
	isInitialized = true
end

function InventoryService:start(): ()
	if not isInitialized then
		self:init()
	end

	isRunning = true
	serviceTrove = ServiceTrove.new()

	GunSkinService = LazyService.create(MainModule, "GunSkinService")()
	ClassServiceRef = LazyService.create(MainModule, "ClassService")()

	serviceTrove:Connect(Players.PlayerAdded, onPlayerAdded)
	serviceTrove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	local devGunEvent = Core.getOrCreateRemoteEvent(DEV_GUN_REMOTE)
	serviceTrove:Connect(devGunEvent.OnServerEvent, handleDevGunRequest)

	if GunSkinService and GunSkinService.OnSkinApplied then
		serviceTrove:Add(GunSkinService:OnSkinApplied(function(player: Player, _skinId: string)
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				for _, child in backpack:GetChildren() do
					if child:IsA("Tool") then
						fixBarrelAttachment(child)
					end
				end
			end
			local character = player.Character
			if character then
				for _, child in character:GetChildren() do
					if child:IsA("Tool") then
						fixBarrelAttachment(child)
					end
				end
			end
		end))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Network.Inventory.onGetInventory(function(player: Player)
		return getPlayerInventory(player)
	end)

	Network.Inventory.onEquipSlot(function(player: Player, slot: number)
		if isRateLimited(player) then
			return false
		end
		if not acquireEquipLock(player) then
			return false
		end
		if type(slot) ~= "number" or slot < 1 or slot > InventoryConfig.MaxSlots then
			releaseEquipLock(player)
			return false
		end

		local state = getPlayerInventory(player)
		local item = InventoryConfig.findItemBySlot(state.Items, slot)

		if not item or not item.Tool then
			releaseEquipLock(player)
			return false
		end

		local antiMacroSvc = getReconAntiMacroService()
		if antiMacroSvc and antiMacroSvc.IsSwitchLocked(player, item.Name) then
			antiMacroSvc.RecordSwitchAttempt(player, item.Name)
			releaseEquipLock(player)
			return false
		end

		local character = player.Character
		if not character then
			releaseEquipLock(player)
			return false
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			releaseEquipLock(player)
			return false
		end

		if state.EquippedSlot == slot then
			humanoid:UnequipTools()
			releaseEquipLock(player)
			return true
		end

		humanoid:EquipTool(item.Tool)
		releaseEquipLock(player)
		return true
	end)

	Network.Inventory.onEquipSlotOptimistic(function(player: Player, slot: number)
		if isRateLimited(player) then
			return
		end
		if not acquireEquipLock(player) then
			return
		end
		if type(slot) ~= "number" or slot < 1 or slot > InventoryConfig.MaxSlots then
			releaseEquipLock(player)
			return
		end

		local state = getPlayerInventory(player)
		local item = InventoryConfig.findItemBySlot(state.Items, slot)

		if not item or not item.Tool then
			releaseEquipLock(player)
			return
		end

		local antiMacroSvc = getReconAntiMacroService()
		if antiMacroSvc and antiMacroSvc.IsSwitchLocked(player, item.Name) then
			antiMacroSvc.RecordSwitchAttempt(player, item.Name)
			releaseEquipLock(player)
			return
		end

		local character = player.Character
		if not character then
			releaseEquipLock(player)
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			releaseEquipLock(player)
			return
		end

		if state.EquippedSlot == slot then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(item.Tool)
		end
		releaseEquipLock(player)
	end)

	Network.Inventory.onUnequip(function(player: Player)
		if isRateLimited(player) then
			return false
		end
		if not acquireEquipLock(player) then
			return false
		end
		local character = player.Character
		if not character then
			releaseEquipLock(player)
			return false
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			releaseEquipLock(player)
			return false
		end

		humanoid:UnequipTools()
		releaseEquipLock(player)
		return true
	end)

	Network.Inventory.onUnequipOptimistic(function(player: Player)
		if isRateLimited(player) then
			return
		end
		if not acquireEquipLock(player) then
			return
		end
		local character = player.Character
		if not character then
			releaseEquipLock(player)
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			releaseEquipLock(player)
			return
		end

		humanoid:UnequipTools()
		releaseEquipLock(player)
	end)

	Network.Inventory.onSwapSlots(function(player: Player, slotA: number, slotB: number)
		if isRateLimited(player) then
			return false
		end
		if type(slotA) ~= "number" or type(slotB) ~= "number" then
			return false
		end
		if slotA < 1 or slotA > InventoryConfig.MaxSlots then
			return false
		end
		if slotB < 1 or slotB > InventoryConfig.MaxSlots then
			return false
		end
		if slotA == slotB then
			return false
		end

		local state = getPlayerInventory(player)
		local itemA = InventoryConfig.findItemBySlot(state.Items, slotA)
		local itemB = InventoryConfig.findItemBySlot(state.Items, slotB)

		if itemA then
			itemA.Slot = slotB
		end
		if itemB then
			itemB.Slot = slotA
		end

		if state.EquippedSlot == slotA then
			state.EquippedSlot = slotB
		elseif state.EquippedSlot == slotB then
			state.EquippedSlot = slotA
		end

		notifyInventoryChange(player, "swap", nil, nil)
		return true
	end)

	Network.Inventory.onDropItem(function(player: Player, slot: number)
		if isRateLimited(player) then
			return false
		end
		if type(slot) ~= "number" or slot < 1 or slot > InventoryConfig.MaxSlots then
			return false
		end

		local state = getPlayerInventory(player)
		local item = InventoryConfig.findItemBySlot(state.Items, slot)

		if not item or not item.Tool then
			return false
		end

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end

		item.Tool.Parent = workspace
		return true
	end)
end

function InventoryService:GetInventory(player: Player): InventoryState
	return getPlayerInventory(player)
end

function InventoryService:AddItem(player: Player, tool: Tool): InventoryItem?
	local backpack = playerBackpacks[player.UserId]
	if backpack then
		tool.Parent = backpack
	end
	return syncToolToInventory(player, tool)
end

function InventoryService:RemoveItem(player: Player, slot: number): boolean
	local state = getPlayerInventory(player)
	local item = InventoryConfig.findItemBySlot(state.Items, slot)

	if not item then
		return false
	end

	if item.Tool then
		item.Tool:Destroy()
	end

	for i, invItem in state.Items do
		if invItem.Slot == slot then
			table.remove(state.Items, i)
			removeToolFromSet(player, invItem.Name)
			break
		end
	end

	if state.EquippedSlot == slot then
		state.EquippedSlot = nil
	end

	notifyInventoryChange(player, "remove", item, slot)
	return true
end

function InventoryService:EquipSlot(player: Player, slot: number): boolean
	local state = getPlayerInventory(player)
	local item = InventoryConfig.findItemBySlot(state.Items, slot)

	if not item or not item.Tool then
		return false
	end

	local antiMacroSvc = getReconAntiMacroService()
	if antiMacroSvc and antiMacroSvc.IsSwitchLocked(player, item.Name) then
		antiMacroSvc.RecordSwitchAttempt(player, item.Name)
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	humanoid:EquipTool(item.Tool)
	return true
end

function InventoryService:Unequip(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	humanoid:UnequipTools()
	return true
end

function InventoryService:ClearInventory(player: Player): ()
	local state = getPlayerInventory(player)

	for _, item in state.Items do
		if item.Tool then
			item.Tool:Destroy()
		end
	end

	state.Items = {}
	state.EquippedSlot = nil
	clearToolSet(player)

	notifyInventoryChange(player, "full", nil, nil)
end

function InventoryService:OnInventoryChanged(callback: (player: Player, state: InventoryState) -> ()): Signal.Connection
	return inventoryChanged:Connect(callback)
end

function InventoryService:GiveTool(player: Player, toolName: string): ()
	giveToolToPlayer(player, toolName)
end

function InventoryService:Cleanup(): ()
	isRunning = false

	if serviceTrove then
		serviceTrove:Destroy()
		serviceTrove = nil :: any
	end

	table.clear(playerTroves)
	table.clear(playerCharacterTroves)
	table.clear(playerInventories)
	table.clear(playerBackpacks)
	table.clear(playerLastAction)
	table.clear(playerToolSet)
	table.clear(playerEquipLock)

	clearToolsModule()

	local existingFolder = ReplicatedStorage:FindFirstChild("ToolTemplates")
	if existingFolder then
		existingFolder:Destroy()
	end

	inventoryChanged:Destroy()
	inventoryChanged = Signal.new()

	idCounter = 0
	isLoadingTools = false
	toolsLoaded = false
	isInitialized = false
	GunSkinService = nil
	ClassServiceRef = nil
end

return InventoryService
