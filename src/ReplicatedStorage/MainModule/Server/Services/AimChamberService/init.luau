--!strict
--!native
--!optimize 2

local Workspace = workspace
local HttpService = game:GetService("HttpService")

local MainModule = script.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local GroupUtils = require(MainModule.Shared.Utils.Game.GroupUtils)

local AimChamberConfigManager: any = nil
local AimChamberMatchManager: any = nil
local AimChamberRecordService: any = nil
local AimChamberLeaderboardService: any = nil
local AimChamberAnticheatService: any = nil

local AimChamberService = {}
AimChamberService.Name = "AimChamberService"

local configPrompt: ProximityPrompt? = nil
local startPrompt: ProximityPrompt? = nil

local MAX_EXPORT_CHUNKS = 50
local MAX_EXPORT_CHUNK_LENGTH = 16384
local MAX_EXPORT_TOTAL_LENGTH = 1048576

local function hasAimChamberAccess(player: Player): boolean
	local groups = AimChamberConfig.GROUPS
	return GroupUtils.isInGroup(player, groups.VULTAR) or GroupUtils.isInGroup(player, groups.VIA)
end

function AimChamberService:init()
	if not Maps.isAimMode() then
		return
	end

	AimChamberConfigManager = require(script.AimChamberConfigManager)
	AimChamberMatchManager = require(script.AimChamberMatchManager)
	AimChamberRecordService = require(script.AimChamberRecordService)
	AimChamberLeaderboardService = require(script.AimChamberLeaderboardService)
	AimChamberAnticheatService = require(script.AimChamberAnticheatService)
end

local function setupProximityPrompts(): ()
	local interactableFolder = Workspace:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.INTERACTABLE_FOLDER)
	if not interactableFolder then
		warn("[AimChamberService] InteractableParts folder not found in workspace")
		return
	end

	local configPart = interactableFolder:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.CONFIG_PART)
	if configPart then
		local existingPrompt = configPart:FindFirstChildOfClass("ProximityPrompt")
		if not existingPrompt then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = AimChamberConfig.PROMPTS.CONFIG_TEXT
			prompt.ActionText = AimChamberConfig.PROMPTS.CONFIG_ACTION
			prompt.HoldDuration = AimChamberConfig.PROMPTS.CONFIG_HOLD
			prompt.MaxActivationDistance = AimChamberConfig.PROMPTS.CONFIG_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = configPart
			configPrompt = prompt
		else
			configPrompt = existingPrompt
		end
	else
		warn("[AimChamberService] ConfigPart not found in InteractableParts")
	end

	local startPart = interactableFolder:FindFirstChild(AimChamberConfig.WORKSPACE_PARTS.START_PART)
	if startPart then
		local existingPrompt = startPart:FindFirstChildOfClass("ProximityPrompt")
		if not existingPrompt then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = AimChamberConfig.PROMPTS.START_TEXT
			prompt.ActionText = AimChamberConfig.PROMPTS.START_ACTION
			prompt.HoldDuration = AimChamberConfig.PROMPTS.START_HOLD
			prompt.MaxActivationDistance = AimChamberConfig.PROMPTS.START_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = startPart
			startPrompt = prompt
		else
			startPrompt = existingPrompt
		end
	else
		warn("[AimChamberService] StartPart not found in InteractableParts")
	end
end

local function wireProximityPrompts(): ()
	if configPrompt then
		configPrompt.Triggered:Connect(function(player: Player)
			if not hasAimChamberAccess(player) then
				return
			end
			if not AimChamberConfigManager.checkRateLimit(player, "REQUEST_OPEN_CONFIG") then
				return
			end

			local state = AimChamberConfigManager.getConfigState(player)
			Network.AimChamber.fireConfigStateSync(player, state)
		end)
	end

	if startPrompt then
		startPrompt.Triggered:Connect(function(player: Player)
			if not hasAimChamberAccess(player) then
				return
			end
			if not AimChamberConfigManager.checkRateLimit(player, "REQUEST_START_MATCH") then
				return
			end

			if AimChamberMatchManager.hasActiveMatch(player) then
				return
			end

			local success, err = AimChamberMatchManager.startMatch(player)
			if not success then
				warn("[AimChamberService] Failed to start match for", player.Name, ":", err)
			end
		end)
	end
end

local function wireNetworkEvents(): ()
	Network.AimChamber.onRequestOpenConfig(function(player: Player)
		if not hasAimChamberAccess(player) then
			return
		end
		if not AimChamberConfigManager.checkRateLimit(player, "REQUEST_OPEN_CONFIG") then
			return
		end

		local state = AimChamberConfigManager.getConfigState(player)
		Network.AimChamber.fireConfigStateSync(player, state)
	end)

	Network.AimChamber.onApplyConfig(function(player: Player, settings: any)
		if not AimChamberConfigManager.checkRateLimit(player, "APPLY_CONFIG") then
			Network.AimChamber.fireApplyConfigResult(player, {
				Success = false,
				Error = "Rate limited, please wait",
			})
			return
		end

		if AimChamberMatchManager.hasActiveMatch(player) then
			Network.AimChamber.fireApplyConfigResult(player, {
				Success = false,
				Error = "Cannot change settings during an active match",
			})
			return
		end

		pcall(function()
			print("[AimChamber Server] onApplyConfig from", player.Name, "settings:", HttpService:JSONEncode(settings))
		end)

		local success, err
		if settings and typeof(settings.PresetId) == "string" then
			if settings.PresetId == "AI" and typeof(settings.AiDifficulty) == "string" then
				success, err = AimChamberConfigManager.applyAiDifficulty(player, settings.AiDifficulty, settings)
			else
				success, err = AimChamberConfigManager.applyPreset(player, settings.PresetId)
			end
		else
			success, err = AimChamberConfigManager.validateAndApplySettings(player, settings)
		end

		if not success then
			local isAnomaly = AimChamberConfigManager.recordRejection(player)
			if isAnomaly then
				AimChamberRecordService.sendAnomalyWebhook(
					player,
					"Repeated Config Rejections",
					"Multiple rejected ApplyConfig requests in a short window",
					settings
				)
			end
		end

		print("[AimChamber Server] fireApplyConfigResult success:", success, "error:", err)
		Network.AimChamber.fireApplyConfigResult(player, {
			Success = success,
			Error = err,
		})

		if success then
			local state = AimChamberConfigManager.getConfigState(player)
			pcall(function()
				print("[AimChamber Server] fireConfigStateSync state settings:", HttpService:JSONEncode(state.Settings), "preset:", state.ActivePreset)
			end)
			Network.AimChamber.fireConfigStateSync(player, state)
		end
	end)

	Network.AimChamber.onRequestStartMatch(function(player: Player)
		if not hasAimChamberAccess(player) then
			return
		end
		if not AimChamberConfigManager.checkRateLimit(player, "REQUEST_START_MATCH") then
			return
		end

		if AimChamberMatchManager.hasActiveMatch(player) then
			return
		end

		local success, err = AimChamberMatchManager.startMatch(player)
		if not success then
			warn("[AimChamberService] Failed to start match for", player.Name, ":", err)
		end
	end)

	Network.AimChamber.onRequestEndMatch(function(player: Player)
		if AimChamberMatchManager.hasActiveMatch(player) then
			AimChamberMatchManager.endMatchForPlayer(player, "LeftMidMatch")
		end
	end)

	Network.AimChamber.onAimReport(function(player: Player, origin: Vector3, direction: Vector3)
		if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
			player:SetAttribute("AimChamberCursorOrigin", origin)
			player:SetAttribute("AimChamberCursorDir", direction)
		end
	end)

	Network.AimChamber.registerGetMatchHistory(function(player: Player)
		return AimChamberRecordService.getPlayerHistory(player)
	end)

	Network.AimChamber.onExportMovement(function(player: Player, chunks: { string })
		if not hasAimChamberAccess(player) then
			return
		end
		if not AimChamberConfigManager.checkRateLimit(player, "EXPORT_MOVEMENT") then
			return
		end
		if type(chunks) ~= "table" then
			return
		end
		if #chunks == 0 or #chunks > MAX_EXPORT_CHUNKS then
			warn("[AimChamber] Player", player.Name, "sent too many movement chunks.")
			return
		end

		local fullString = ""
		for _, chunk in chunks do
			if type(chunk) ~= "string" then
				continue
			end
			if #chunk > MAX_EXPORT_CHUNK_LENGTH then
				warn("[AimChamber] Player", player.Name, "sent an oversized movement chunk.")
				return
			end
			if #fullString + #chunk > MAX_EXPORT_TOTAL_LENGTH then
				warn("[AimChamber] Player", player.Name, "sent an oversized movement profile.")
				return
			end
			fullString ..= chunk
		end

		if #fullString == 0 then
			return
		end

		task.spawn(function()
			local boundary = "----WebhookBoundary" .. tostring(Random.new():NextInteger(1000000, 9999999))
			local body = "--" .. boundary .. "\r\n"
			body ..= 'Content-Disposition: form-data; name="content"\r\n\r\n'
			body ..= "Movement profile exported by **" .. player.Name .. "**\r\n"
			body ..= "--" .. boundary .. "\r\n"
			body ..= 'Content-Disposition: form-data; name="file"; filename="MovementProfile_' .. player.Name .. "_" .. os.time() .. '.luau"\r\n'
			body ..= "Content-Type: text/plain\r\n\r\n"
			body ..= fullString .. "\r\n"
			body ..= "--" .. boundary .. "--\r\n"

			local success, err = pcall(function()
				local webhookUrl =
					"REPLACE_WITH_YOUR_WEBHOOK_URL"
				if not webhookUrl or webhookUrl == "" then
					warn("[AimChamber] MovementExportWebhookUrl is not configured.")
					return
				end

				local response = HttpService:RequestAsync({
					Url = webhookUrl,
					Method = "POST",
					Headers = {
						["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
					},
					Body = body,
				})

				if not response.Success then
					warn("[AimChamber] Discord webhook failed with status", response.StatusCode, "-", response.StatusMessage)
					warn("[AimChamber] Webhook response body:", response.Body)
				else
					print("[AimChamber] Successfully exported movement profile to webhook!")
				end
			end)

			if not success then
				warn("[AimChamber] Discord webhook file upload failed:", err)
			end
		end)
	end)
end

function AimChamberService:start()
	if not Maps.isAimMode() then
		return
	end

	Network.AimChamber.init()

	AimChamberConfigManager.start()
	AimChamberMatchManager.start()
	AimChamberLeaderboardService.start()
	AimChamberAnticheatService.start()

	setupProximityPrompts()
	wireProximityPrompts()
	wireNetworkEvents()
end

function AimChamberService:Cleanup()
	if not AimChamberConfigManager then
		return
	end

	AimChamberConfigManager.cleanup()
	AimChamberMatchManager.cleanup()
	AimChamberRecordService.cleanup()
	AimChamberLeaderboardService.cleanup()
	AimChamberAnticheatService.cleanup()

	if configPrompt then
		configPrompt:Destroy()
		configPrompt = nil
	end
	if startPrompt then
		startPrompt:Destroy()
		startPrompt = nil
	end
end

return AimChamberService
