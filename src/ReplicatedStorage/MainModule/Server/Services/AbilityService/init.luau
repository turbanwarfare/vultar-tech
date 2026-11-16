--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Core = require(MainModule.Shared.Network.Core)
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)

export type ServerAbility = {
	init: (() -> ())?,
	validate: ((payload: any) -> boolean)?,
	use: (player: Player, character: Model, payload: any) -> (),
}

local AbilityService = {}
AbilityService.Name = "AbilityService"

local handlers: { [string]: ServerAbility } = {}
local charges: { [number]: { [string]: number } } = {}
local lastUses: { [number]: { [string]: number } } = {}
local connections: { RBXScriptConnection } = {}
local chargesRemote: RemoteEvent? = nil

local function isAlive(character: Model?): boolean
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function sendCharges(player: Player, name: string): ()
	local userCharges = charges[player.UserId]
	if chargesRemote and userCharges then
		chargesRemote:FireClient(player, name, userCharges[name] or 0)
	end
end

local function activate(handler: ServerAbility, player: Player, character: Model, payload: any): ()
	if player.Character == character and isAlive(character) then
		handler.use(player, character, payload)
	end
end

local function onUseRequested(player: Player, name: any, payload: any): ()
	if typeof(name) ~= "string" then
		return
	end
	local handler = handlers[name]
	local definition = AbilityConfig.get(name)
	if not handler or not definition then
		return
	end
	if handler.validate and not handler.validate(payload) then
		return
	end

	local userId = player.UserId
	local userCharges = charges[userId]
	local userLastUses = lastUses[userId]
	if not userCharges or not userLastUses then
		return
	end
	local now = os.clock()
	local lastUse = userLastUses[name]
	if lastUse and now - lastUse < definition.Cooldown then
		return
	end
	if definition.Charges and (userCharges[name] or 0) <= 0 then
		return
	end

	local character = player.Character
	if not character or not isAlive(character) or FactionUtils.isSpectator(player) then
		return
	end
	if not AbilityConfig.classHas(character:GetAttribute("PlayerClass"), name) then
		return
	end

	userLastUses[name] = now
	if definition.Charges then
		userCharges[name] -= 1
		sendCharges(player, name)
	end

	task.delay(definition.Windup, activate, handler, player, character, payload)
end

local function resupply(player: Player): ()
	local userCharges: { [string]: number } = {}
	for name in handlers do
		local definition = AbilityConfig.get(name)
		local maxCharges = definition and definition.Charges
		if maxCharges then
			userCharges[name] = maxCharges
		end
	end
	charges[player.UserId] = userCharges
	lastUses[player.UserId] = {}
	for name in userCharges do
		sendCharges(player, name)
	end
end

local function onPlayerAdded(player: Player): ()
	table.insert(
		connections,
		player.CharacterAdded:Connect(function()
			resupply(player)
		end)
	)
	if player.Character then
		resupply(player)
	end
end

function AbilityService:init(): ()
	local folder = script:FindFirstChild("Abilities")
	local anyActive = false
	for name in AbilityConfig.getAll() do
		if AbilityConfig.isActive(name) then
			anyActive = true
			local module = folder and folder:FindFirstChild(name)
			if module and module:IsA("ModuleScript") then
				local handler = (require :: any)(module) :: ServerAbility
				if handler.init then
					handler.init()
				end
				handlers[name] = handler
			end
		end
	end
	if not anyActive then
		return
	end

	chargesRemote = Core.getOrCreateRemoteEvent("Ability_Charges")
	table.insert(connections, Core.getOrCreateRemoteEvent("Ability_Use").OnServerEvent:Connect(onUseRequested))
end

function AbilityService:start(): ()
	if next(handlers) == nil then
		return
	end

	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			charges[player.UserId] = nil
			lastUses[player.UserId] = nil
		end)
	)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function AbilityService:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(handlers)
	table.clear(charges)
	table.clear(lastUses)
end

return AbilityService
