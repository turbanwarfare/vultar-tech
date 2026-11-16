--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local AbilityHUD = require(MainModule.Client.Components.AbilityHUD)
local GunHUD = require(MainModule.Client.Components.GunHUD)

export type ClientAbility = {
	init: (() -> ())?,
	start: (() -> ())?,
	getPayload: ((character: Model) -> any)?,
	onUsed: ((character: Model, humanoid: Humanoid) -> ())?,
	onCharacterAdded: (() -> ())?,
	cleanup: (() -> ())?,
}

local AbilityService = {}
AbilityService.Name = "AbilityService"

local getSettingsService = LazyService.create(MainModule, "SettingsService")

local player = Players.LocalPlayer
local handlers: { [string]: ClientAbility } = {}
local charges: { [string]: number } = {}
local lastUses: { [string]: number } = {}
local cooldownShown: { [string]: boolean } = {}
local useRemote: RemoteEvent? = nil
local connections: { RBXScriptConnection } = {}
local characterConnections: { RBXScriptConnection } = {}

local function getAliveCharacter(): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return character, humanoid
end

local function cooldownLeft(name: string): number
	local definition = AbilityConfig.get(name)
	local lastUse = lastUses[name]
	if not definition or not lastUse then
		return 0
	end
	return math.max(0, definition.Cooldown - (os.clock() - lastUse))
end

local function getCharges(name: string): number
	local definition = AbilityConfig.get(name)
	if definition and definition.Charges == nil then
		return math.huge
	end
	return charges[name] or 0
end

local function refreshHud(): ()
	local character = getAliveCharacter()
	local shown: { string } = {}
	if character then
		for _, name in AbilityConfig.forClass(character:GetAttribute("PlayerClass")) do
			if handlers[name] then
				table.insert(shown, name)
			end
		end
	end
	AbilityHUD.show(shown)
	for name in handlers do
		AbilityHUD.setState(name, getCharges(name), cooldownLeft(name))
	end
end

local function getKeyName(name: string): string
	local settingsService = getSettingsService()
	local key = settingsService and settingsService:GetKeybind(name)
	if typeof(key) == "string" and key ~= "" then
		return key
	end
	local definition = AbilityConfig.get(name)
	return if definition then definition.Key else ""
end

local function getKeyCode(name: string): Enum.KeyCode?
	local ok, keyCode = pcall(function()
		return (Enum.KeyCode :: any)[getKeyName(name)]
	end)
	return if ok then keyCode else nil
end

local function tryUse(name: string): ()
	local handler = handlers[name]
	local character, humanoid = getAliveCharacter()
	if not handler or not character or not humanoid or not useRemote then
		return
	end
	if not AbilityConfig.classHas(character:GetAttribute("PlayerClass"), name) then
		return
	end
	if getCharges(name) <= 0 or cooldownLeft(name) > 0 then
		return
	end

	local payload = if handler.getPayload then handler.getPayload(character) else true
	if payload == nil then
		return
	end

	lastUses[name] = os.clock()
	local left = charges[name]
	if left then
		charges[name] = left - 1
	end
	refreshHud()
	useRemote:FireServer(name, payload)
	if handler.onUsed then
		handler.onUsed(character, humanoid)
	end
end

local function clearCharacterConnections(): ()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function onCharacterAdded(character: Model): ()
	clearCharacterConnections()
	table.clear(lastUses)
	table.clear(charges)
	for name, handler in handlers do
		local definition = AbilityConfig.get(name)
		local maxCharges = definition and definition.Charges
		if maxCharges then
			charges[name] = maxCharges
		end
		if handler.onCharacterAdded then
			handler.onCharacterAdded()
		end
	end

	table.insert(characterConnections, character:GetAttributeChangedSignal("PlayerClass"):Connect(refreshHud))
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		table.insert(characterConnections, humanoid.Died:Connect(refreshHud))
	end
	refreshHud()
end

function AbilityService:init(): ()
	local folder = script:FindFirstChild("Abilities")
	for name, definition in AbilityConfig.getAll() do
		local module = folder and folder:FindFirstChild(name)
		if module and module:IsA("ModuleScript") and AbilityConfig.isActive(name) then
			local handler = (require :: any)(module) :: ClientAbility
			if handler.init then
				handler.init()
			end
			handlers[name] = handler
			AbilityHUD.add(name, definition.Icon, definition.Charges or 0, definition.IconSize)
		end
	end
end

function AbilityService:start(): ()
	if next(handlers) == nil then
		return
	end

	useRemote = Core.getOrCreateRemoteEvent("Ability_Use")
	table.insert(
		connections,
		Core.getOrCreateRemoteEvent("Ability_Charges").OnClientEvent:Connect(function(name: any, count: any)
			if typeof(name) == "string" and handlers[name] and typeof(count) == "number" then
				charges[name] = count
				refreshHud()
			end
		end)
	)
	for _, handler in handlers do
		if handler.start then
			handler.start()
		end
	end

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			for name in handlers do
				if input.KeyCode == getKeyCode(name) then
					tryUse(name)
				end
			end
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			for name in handlers do
				local left = cooldownLeft(name)
				if left > 0 or cooldownShown[name] then
					AbilityHUD.setState(name, getCharges(name), left)
					cooldownShown[name] = left > 0
				end
			end
		end)
	)

	for name in handlers do
		AbilityHUD.setKeybind(name, getKeyName(name))
	end
	task.spawn(function()
		local container = GunHUD.getContainer()
		while container == nil do
			task.wait(0.5)
			container = GunHUD.getContainer()
		end
		if container then
			AbilityHUD.attach(container)
		end
	end)
	table.insert(connections, player.CharacterAdded:Connect(onCharacterAdded))
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function AbilityService:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	clearCharacterConnections()
	for _, handler in handlers do
		if handler.cleanup then
			handler.cleanup()
		end
	end
	table.clear(handlers)
	table.clear(charges)
	table.clear(lastUses)
	table.clear(cooldownShown)
	AbilityHUD.destroy()
	useRemote = nil
end

return AbilityService
