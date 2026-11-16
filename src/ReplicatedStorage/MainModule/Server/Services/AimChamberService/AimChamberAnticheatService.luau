--!strict
--!native
--!optimize 2

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local AimChamberRecordService = require(script.Parent.AimChamberRecordService)
local AimChamberMatchManager = require(script.Parent.AimChamberMatchManager)
local AimChamberConfigManager = require(script.Parent.AimChamberConfigManager)

local AimChamberAnticheatService = {}

local activeConnections: { RBXScriptConnection } = {}
local honeypotConnections: { [Instance]: RBXScriptConnection } = {}
local honeypotDebounce: { [Player]: number } = {}

local function onHoneypotTouched(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end

	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return
	end

	local inAimMatch = player:GetAttribute("InAimChamberMatch")
	if not inAimMatch then
		return
	end

	local now = os.clock()
	if honeypotDebounce[player] and now - honeypotDebounce[player] < 1 then
		return
	end
	honeypotDebounce[player] = now

	if not AimChamberMatchManager.hasActiveMatch(player) then
		return
	end

	local settings = AimChamberConfigManager.getConfigState(player).Settings
	if settings and settings.AssessmentValidation then
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		local posInfo = "Unknown Position"
		if rootPart and rootPart:IsA("BasePart") then
			local pos = rootPart.Position
			posInfo = string.format("X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z)
		end

		AimChamberRecordService.sendAnomalyWebhook(
			player,
			"Honeypot Triggered",
			string.format("Player touched out of bounds honeypot brick during Assessment Mode \nLocation: %s", posInfo)
		)

		AimChamberMatchManager.endMatchForPlayer(player, "LeftMidMatch")
	end
end

local function bindHoneypot(part: Instance)
	if part:IsA("BasePart") then
		honeypotConnections[part] = part.Touched:Connect(onHoneypotTouched)
	end
end

local function unbindHoneypot(part: Instance)
	if honeypotConnections[part] then
		honeypotConnections[part]:Disconnect()
		honeypotConnections[part] = nil
	end
end

function AimChamberAnticheatService.start(): ()
	local tag = AimChamberConfig.HONEYPOT_TAG or "AimChamberHoneypot"
	for _, part in CollectionService:GetTagged(tag) do
		bindHoneypot(part)
	end

	table.insert(activeConnections, CollectionService:GetInstanceAddedSignal(tag):Connect(bindHoneypot))
	table.insert(activeConnections, CollectionService:GetInstanceRemovedSignal(tag):Connect(unbindHoneypot))
end

function AimChamberAnticheatService.cleanup(): ()
	for _, conn in activeConnections do
		conn:Disconnect()
	end
	table.clear(activeConnections)
	for _, conn in honeypotConnections do
		conn:Disconnect()
	end
	table.clear(honeypotConnections)
	table.clear(honeypotDebounce)
end

return AimChamberAnticheatService
