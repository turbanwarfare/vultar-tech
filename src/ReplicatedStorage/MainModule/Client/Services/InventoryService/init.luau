--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)
local Core = require(MainModule.Shared.Network.Core)
local InventoryConfig = require(MainModule.Shared.Config.Inventory.InventoryConfig)
local InventoryComponents = require(MainModule.Client.Components.Inventory)

type FusionScope = Types.FusionScope
type InventoryItem = InventoryConfig.InventoryItem
type InventoryState = InventoryConfig.InventoryState

local InventoryService = {}
InventoryService.Name = "InventoryService"

local player = Players.LocalPlayer

local playerGui: PlayerGui? = nil
local scope: FusionScope? = nil
local hotbarGui: ScreenGui? = nil
local inventoryState: any = nil
local equippedSlot: any = nil
local isEditing: any = nil
local lockedOutSlot: any = nil
local isLockoutFlashing: any = nil
local lockoutTask: thread? = nil
local FLASH_INTERVAL = 0.12
local localInventoryItems: { InventoryItem } = {}
local slotPreferences: { [string]: number } = {}

local isInitialized = false
local inputConnection: RBXScriptConnection? = nil
local inventoryUpdateConnection: { Disconnect: () -> () }? = nil

local deployConnection: { Disconnect: () -> () }? = nil
local characterRemovingConnection: RBXScriptConnection? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local hasDeployed = false
local swapStartTime = 0
local isEquipping = false

local SWAP_TIMEOUT = 2
local EDITOR_KEY = Enum.KeyCode.Backquote
local DEV_GUN_KEY = Enum.KeyCode.L
local DEV_GUN_REMOTE = "RequestDevGun"
local devGunEvent: RemoteEvent? = nil
local lastUnequipTime = 0
local UNEQUIP_GUARD_WINDOW = 0.5
local lastEquipTime = 0
local EQUIP_COOLDOWN = 0.05

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function findItemBySlot(items: { InventoryItem }, slot: number): InventoryItem?
	for _, item in items do
		if item.Slot == slot then
			return item
		end
	end
	return nil
end

local function copyItemWithSlot(item: InventoryItem, newSlot: number, preserveServerSlot: boolean?): InventoryItem
	local copy: any = table.clone(item :: any)
	if preserveServerSlot then
		copy.ServerSlot = copy.ServerSlot or copy.Slot
	else
		copy.ServerSlot = nil
	end
	copy.Slot = newSlot
	return copy :: InventoryItem
end

local function applySlotPreferences(items: { InventoryItem }): { InventoryItem }
	local result: { InventoryItem } = {}
	local usedSlots: { [number]: boolean } = {}
	local pending: { InventoryItem } = {}

	for _, item in items do
		local preferredSlot = slotPreferences[item.Name]
		if preferredSlot and not usedSlots[preferredSlot] then
			usedSlots[preferredSlot] = true
			table.insert(result, copyItemWithSlot(item, preferredSlot, true))
		else
			table.insert(pending, item)
		end
	end

	for _, item in pending do
		local slot = item.Slot
		if usedSlots[slot] then
			for s = 1, 9 do
				if not usedSlots[s] then
					slot = s
					break
				end
			end
		end
		usedSlots[slot] = true
		table.insert(result, copyItemWithSlot(item, slot, true))
	end

	return result
end

local function saveSlotPreferences(items: { InventoryItem }): ()
	for _, item in items do
		slotPreferences[item.Name] = item.Slot
	end
end

local function findToolInBackpack(toolName: string): Tool?
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return nil
	end

	local found = backpack:FindFirstChild(toolName)
	if found and found:IsA("Tool") then
		return found
	end

	return nil
end

local function findToolInCharacter(toolName: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end

	local found = character:FindFirstChild(toolName)
	if found and found:IsA("Tool") then
		return found
	end

	return nil
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function directEquip(slot: number): ()
	if isEquipping then
		return
	end

	local now = os.clock()
	if now - lastEquipTime < EQUIP_COOLDOWN then
		return
	end
	lastEquipTime = now

	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local currentSlot = if equippedSlot then Fusion.peek(equippedSlot) else 0

	if currentSlot == slot then
		equippedSlot:set(0)
		lastUnequipTime = os.clock()
		humanoid:UnequipTools()
		return
	end

	local item = findItemBySlot(localInventoryItems, slot)
	if not item then
		return
	end

	if lockedOutSlot and Fusion.peek(lockedOutSlot) == slot then
		return
	end

	isEquipping = true

	local currentlyEquipped = findToolInCharacter(item.Name)
	if currentlyEquipped then
		equippedSlot:set(slot)
		isEquipping = false
		return
	end

	local tool = findToolInBackpack(item.Name)
	if not tool then
		isEquipping = false
		return
	end

	local equipSuccess = pcall(function()
		equippedSlot:set(slot)
		humanoid:EquipTool(tool)
	end)

	if not equipSuccess then
		equippedSlot:set(0)
	end

	isEquipping = false
end

local function directUnequip(): ()
	equippedSlot:set(0)
	lastUnequipTime = os.clock()
	if lockoutTask then
		task.cancel(lockoutTask)
		lockoutTask = nil
	end
	if lockedOutSlot then
		lockedOutSlot:set(0)
	end
	if isLockoutFlashing then
		isLockoutFlashing:set(false)
	end

	local humanoid = getHumanoid()
	if humanoid then
		humanoid:UnequipTools()
	end
end

local function swapLocalSlots(slotA: number, slotB: number): ()
	local newItems: { InventoryItem } = {}

	for _, item in localInventoryItems do
		local newSlot = item.Slot
		if item.Slot == slotA then
			newSlot = slotB
		elseif item.Slot == slotB then
			newSlot = slotA
		end
		table.insert(newItems, copyItemWithSlot(item, newSlot))
	end

	localInventoryItems = newItems
	saveSlotPreferences(newItems)
	inventoryState:set(newItems)

	swapStartTime = os.clock()
	task.spawn(function()
		Network.Inventory.swapSlots(slotA, slotB)
		swapStartTime = 0
	end)
end

local function createHotbar(uiScope: FusionScope): ScreenGui
	local hotbar = InventoryComponents.Hotbar(uiScope, {
		Items = inventoryState,
		EquippedSlot = equippedSlot,
		IsEditing = isEditing,
		LockedOutSlot = lockedOutSlot,
		IsLockoutFlashing = isLockoutFlashing,
		OnSlotActivated = function(slot: number)
			directEquip(slot)
		end,
		OnSwapSlots = swapLocalSlots,
	})

	return uiScope:New("ScreenGui")({
		Name = "VultarInventory",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = { hotbar },
	})
end

local function handleInput(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == EDITOR_KEY then
		if isEditing then
			isEditing:set(not Fusion.peek(isEditing))
		end
		return
	end

	if input.KeyCode == DEV_GUN_KEY and (UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)) then
		if not devGunEvent then
			devGunEvent = Core.getOrCreateRemoteEvent(DEV_GUN_REMOTE)
		end
		if devGunEvent then
			devGunEvent:FireServer()
		end
		return
	end

	local slot = SLOT_KEYS[input.KeyCode]
	if slot then
		directEquip(slot)
	end
end

local function updateInventoryState(data: any): ()
	if data.state then
		if data.action == "full" then
			swapStartTime = 0
		else
			local isRecentSwap = swapStartTime > 0 and (os.clock() - swapStartTime) < SWAP_TIMEOUT
			if isRecentSwap then
				return
			end
			swapStartTime = 0
		end
		local serverItems = data.state.Items or {}
		localInventoryItems = applySlotPreferences(serverItems)
		inventoryState:set(localInventoryItems)
		if data.action ~= "equip" and data.action ~= "unequip" then
			local isRecentUnequip = (os.clock() - lastUnequipTime) < UNEQUIP_GUARD_WINDOW
			if not isRecentUnequip then
				equippedSlot:set(data.state.EquippedSlot or 0)
			end
		end
	elseif data.action == "add" and data.item then
		local newItem = data.item
		local preferredSlot = slotPreferences[newItem.Name]
		if preferredSlot then
			local slotTaken = false
			for _, existing in localInventoryItems do
				if existing.Slot == preferredSlot then
					slotTaken = true
					break
				end
			end
			if not slotTaken then
				newItem = copyItemWithSlot(newItem, preferredSlot)
			end
		end
		table.insert(localInventoryItems, newItem)
		inventoryState:set(localInventoryItems)
	elseif data.action == "remove" and data.item then
		for i, item in localInventoryItems do
			if item.Id == data.item.Id then
				table.remove(localInventoryItems, i)
				break
			end
		end
		inventoryState:set(localInventoryItems)
	end
end

function InventoryService:init(): ()
	playerGui = player:WaitForChild("PlayerGui", 15) :: PlayerGui?

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	isInitialized = true
end

function InventoryService:start(): ()
	if not isInitialized then
		self:init()
	end

	if not playerGui then
		return
	end

	scope = Fusion.scoped(Fusion)
	inventoryState = scope:Value({} :: { InventoryItem })
	equippedSlot = scope:Value(0)
	isEditing = scope:Value(false)
	lockedOutSlot = scope:Value(0)
	isLockoutFlashing = scope:Value(false)

	hotbarGui = createHotbar(scope)
	hotbarGui.Enabled = false
	hotbarGui.Parent = playerGui

	deployConnection = Network.Deploy.onDeployComplete(function()
		hasDeployed = true
		if hotbarGui then
			hotbarGui.Enabled = true
		end
	end)

	characterRemovingConnection = player.CharacterRemoving:Connect(function()
		if hotbarGui then
			hotbarGui.Enabled = false
		end
		if lockoutTask then
			task.cancel(lockoutTask)
			lockoutTask = nil
		end
		if lockedOutSlot then
			lockedOutSlot:set(0)
		end
		if isLockoutFlashing then
			isLockoutFlashing:set(false)
		end
	end)

	local function setupHumanoidDeath(char: Model)
		local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				if lockoutTask then
					task.cancel(lockoutTask)
					lockoutTask = nil
				end
				if lockedOutSlot then
					lockedOutSlot:set(0)
				end
				if isLockoutFlashing then
					isLockoutFlashing:set(false)
				end
			end)
		end
	end

	characterAddedConnection = player.CharacterAdded:Connect(function(char)
		if hasDeployed and hotbarGui then
			hotbarGui.Enabled = true
		end
		if lockoutTask then
			task.cancel(lockoutTask)
			lockoutTask = nil
		end
		if lockedOutSlot then
			lockedOutSlot:set(0)
		end
		if isLockoutFlashing then
			isLockoutFlashing:set(false)
		end
		setupHumanoidDeath(char)
	end)

	if player.Character then
		setupHumanoidDeath(player.Character)
	end

	inventoryUpdateConnection = Network.Inventory.onInventoryUpdated(updateInventoryState)

	inputConnection = UserInputService.InputBegan:Connect(handleInput)

	task.spawn(function()
		local serverInventory = Network.Inventory.getInventory()
		if serverInventory then
			local serverItems = serverInventory.Items or {}
			localInventoryItems = applySlotPreferences(serverItems)
			inventoryState:set(localInventoryItems)
			equippedSlot:set(serverInventory.EquippedSlot or 0)
		end
	end)
end

function InventoryService:GetInventory(): InventoryState?
	if inventoryState then
		return {
			Items = Fusion.peek(inventoryState),
			EquippedSlot = Fusion.peek(equippedSlot),
		}
	end
	return nil
end

function InventoryService:GetEquippedSlot(): number
	if equippedSlot then
		return Fusion.peek(equippedSlot)
	end
	return 0
end

function InventoryService:EquipSlot(slot: number): ()
	directEquip(slot)
end

function InventoryService:Unequip(): ()
	directUnequip()
end

function InventoryService:SwapSlots(slotA: number, slotB: number): ()
	swapLocalSlots(slotA, slotB)
end

function InventoryService:DropItem(slot: number): ()
	Network.Inventory.dropItem(slot)
end

function InventoryService:SetHasDeployed(deployed: boolean): ()
	hasDeployed = deployed
	if hotbarGui then
		hotbarGui.Enabled = deployed
	end
end

function InventoryService:SetVisible(visible: boolean): ()
	if hotbarGui then
		hotbarGui.Enabled = visible
	end
end

function InventoryService:IsVisible(): boolean
	if hotbarGui then
		return hotbarGui.Enabled
	end
	return false
end

function InventoryService:SetSlotLockout(slot: number, duration: number): ()
	if lockoutTask then
		task.cancel(lockoutTask)
		lockoutTask = nil
	end
	if lockedOutSlot then
		lockedOutSlot:set(slot)
	end
	if isLockoutFlashing then
		isLockoutFlashing:set(true)
	end

	local startTime = os.clock()
	lockoutTask = task.spawn(function()
		local flash = true
		while os.clock() - startTime < duration do
			task.wait(FLASH_INTERVAL)
			flash = not flash
			if isLockoutFlashing then
				isLockoutFlashing:set(flash)
			end
		end
		if lockedOutSlot and Fusion.peek(lockedOutSlot) == slot then
			lockedOutSlot:set(0)
		end
		if isLockoutFlashing then
			isLockoutFlashing:set(false)
		end
		lockoutTask = nil
	end)
end

function InventoryService:ClearSlotLockout(): ()
	if lockoutTask then
		task.cancel(lockoutTask)
		lockoutTask = nil
	end
	if lockedOutSlot then
		lockedOutSlot:set(0)
	end
	if isLockoutFlashing then
		isLockoutFlashing:set(false)
	end
end

function InventoryService:GetSlotForTool(toolName: string): number?
	for _, item in localInventoryItems do
		if item.Name == toolName then
			return item.Slot
		end
	end
	return nil
end

function InventoryService:Cleanup(): ()
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end

	if inventoryUpdateConnection then
		inventoryUpdateConnection:Disconnect()
		inventoryUpdateConnection = nil
	end

	if deployConnection then
		deployConnection:Disconnect()
		deployConnection = nil
	end

	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end

	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end

	if lockoutTask then
		task.cancel(lockoutTask)
		lockoutTask = nil
	end

	hasDeployed = false
	inventoryState = nil :: any
	equippedSlot = nil :: any
	isEditing = nil :: any
	lockedOutSlot = nil :: any
	isLockoutFlashing = nil :: any

	if scope then
		Fusion.doCleanup(scope)
		scope = nil
	end

	hotbarGui = nil
	localInventoryItems = {}
	swapStartTime = 0
	lastUnequipTime = 0
	isEquipping = false
	isInitialized = false
end

return InventoryService
