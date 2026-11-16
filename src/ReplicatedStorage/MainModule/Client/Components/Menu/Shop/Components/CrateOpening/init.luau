--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)
local Network = require(MainModule.Shared.Network)

local PlaceholderStage = require(script.PlaceholderStage)
local BatchRevealStage = require(script.BatchRevealStage)
local SummaryStage = require(script.SummaryStage)
local RevealEffects = require(script.RevealEffects)
local UISound = require(MainModule.Client.Components.Menu.UISound)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type CrateConfig = CratesConfig.CrateConfig
type RollResult = CratesConfig.RollResult

local REQUEST_TIMEOUT = 20

export type CrateOpeningOverlayProps = {
	Crate: CrateConfig,
	Results: { RollResult } | Types.FusionValue<{ RollResult }?>,
	TotalRefund: (number | Types.FusionValue<number?>)?,
	ErrorMessage: (string | Types.FusionValue<string?>)?,
	OnClose: () -> (),
}

local function CrateOpeningOverlay(scope: FusionScope, props: CrateOpeningOverlayProps): Instance
	local crate = props.Crate

	local currentPhase = scope:Value("Placeholder")
	local currentBatchIndex = scope:Value(1)
	local isSkipped = scope:Value(false)
	local isSkipHovered = scope:Value(false)

	local maxSlots = CratesConfig.MAX_DISPLAY_SLOTS

	local slot1Vis = scope:Value(false)
	local slot2Vis = scope:Value(false)
	local slot3Vis = scope:Value(false)
	local slotVisibilities = { slot1Vis, slot2Vis, slot3Vis }

	local isClosing = false
	local sequenceThread: thread? = nil
	local screenGuiRef: ScreenGui? = nil
	local DEBUG_LOGGING = false

	local function getResults(): { RollResult }?
		if typeof(props.Results) == "table" and (props.Results :: any).type == "State" then
			return Fusion.peek(props.Results :: any)
		end
		return props.Results :: { RollResult }?
	end

	local function getTotalRefund(): number
		if props.TotalRefund ~= nil then
			if typeof(props.TotalRefund) == "table" and (props.TotalRefund :: any).type == "State" then
				return Fusion.peek(props.TotalRefund :: any) or 0
			end
			return (props.TotalRefund :: any) or 0
		end
		return 0
	end

	local function getErrorMessage(): string?
		if props.ErrorMessage ~= nil then
			if typeof(props.ErrorMessage) == "table" and (props.ErrorMessage :: any).type == "State" then
				return Fusion.peek(props.ErrorMessage :: any)
			end
			return props.ErrorMessage :: string?
		end
		return nil
	end

	local function resetBatchSlotVisibilities()
		slot1Vis:set(false)
		slot2Vis:set(false)
		slot3Vis:set(false)
	end

	local function handleSkip()
		if Fusion.peek(isSkipped) or isClosing then
			return
		end
		isSkipped:set(true)
		UISound.setCrateOpeningActive(false)
		RevealEffects.cleanup()
		if sequenceThread then
			task.cancel(sequenceThread)
			sequenceThread = nil
		end
		currentPhase:set("Complete")
	end

	local function handleClose()
		if isClosing then
			return
		end
		isClosing = true
		UISound.setCrateOpeningActive(false)
		RevealEffects.cleanup()
		if sequenceThread then
			task.cancel(sequenceThread)
			sequenceThread = nil
		end
		props.OnClose()
		if screenGuiRef and screenGuiRef.Parent then
			screenGuiRef:Destroy()
			screenGuiRef = nil
		end
	end

	local keybindConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == CratesConfig.SKIP_KEYBIND then
			handleSkip()
		end
	end)

	table.insert(scope, function()
		keybindConn:Disconnect()
		UISound.setCrateOpeningActive(false)
		RevealEffects.cleanup()
		if sequenceThread then
			task.cancel(sequenceThread)
			sequenceThread = nil
		end
	end)

	local overlayRef: Frame? = nil

	local hasLegendary = scope:Value(false)
	local highestRarity = scope:Value(nil :: CrateRarity?)

	sequenceThread = task.spawn(function()
		UISound.setCrateOpeningActive(true)
		local results = getResults()
		local waitStart = os.clock()
		while not results and not isClosing do
			local err = getErrorMessage()
			if err and err ~= "" then
				UISound.setCrateOpeningActive(false)
				currentPhase:set("Error")
				return
			end
			if (os.clock() - waitStart) > REQUEST_TIMEOUT then
				warn(`[CrateOpening] Server request timed out after {REQUEST_TIMEOUT}s`)
				task.spawn(Network.Economy.requestBalance)
				UISound.setCrateOpeningActive(false)
				currentPhase:set("Error")
				return
			end
			task.wait(0.04)
			results = getResults()
		end

		if not results or #results == 0 or isClosing then
			return
		end

		if Fusion.peek(isSkipped) then
			currentPhase:set("Complete")
			return
		end

		local highestTier: CrateRarity = "Common"
		for _, item in results do
			if item.rarity == "Mythic" then
				highestTier = "Mythic"
				break
			elseif item.rarity == "Legendary" and highestTier ~= "Mythic" then
				highestTier = "Legendary"
			elseif item.rarity == "Rare" and highestTier ~= "Mythic" and highestTier ~= "Legendary" then
				highestTier = "Rare"
			elseif item.rarity == "Uncommon" and highestTier == "Common" then
				highestTier = "Uncommon"
			end
		end

		highestRarity:set(highestTier)
		if DEBUG_LOGGING then
			print(string.format("[CrateOpening] Batch highest rarity determined: %s (#items=%d)", highestTier, #results))
		end

		local crateAnimCfg = CratesConfig.BOX_ANIMATIONS[crate.rarity] or CratesConfig.BOX_ANIMATIONS.Common
		local animDuration = crateAnimCfg.TotalDuration or CratesConfig.BOX_ANIM_DURATION
		if highestTier == "Mythic" or highestTier == "Legendary" then
			local legOverlayCfg = CratesConfig.BOX_ANIMATIONS.LegendaryOverlay
			animDuration += (legOverlayCfg.PreJerkDuration or 0.08) + (legOverlayCfg.HeldJerkPause or 0.12) + 0.10
		elseif highestTier == "Rare" then
			local rareOverlayCfg = CratesConfig.BOX_ANIMATIONS.RareOverlay
			animDuration += (rareOverlayCfg.StutterFlicker and rareOverlayCfg.StutterFlicker.Duration or 0.12) + 0.05
		end

		local startTime = os.clock()
		while (os.clock() - startTime) < animDuration do
			task.wait(0.03)
			if Fusion.peek(isSkipped) or isClosing then
				break
			end
		end

		if Fusion.peek(isSkipped) or isClosing then
			if not isClosing then
				currentPhase:set("Complete")
			end
			return
		end

		currentPhase:set("Reveal")
		local totalBatches = math.max(1, math.ceil(#results / maxSlots))

		local RARITY_RANK: { [CrateRarity]: number } = {
			Common = 1,
			Uncommon = 2,
			Rare = 3,
			Legendary = 4,
			Mythic = 5,
		}

		local function sortByRarity(queue: { { slotIdx: number, item: RollResult } }): ()
			table.sort(queue, function(a, b)
				local rankA = RARITY_RANK[a.item.rarity] or 1
				local rankB = RARITY_RANK[b.item.rarity] or 1
				return rankA < rankB
			end)
		end

		for batchIdx = 1, totalBatches do
			currentBatchIndex:set(batchIdx)
			resetBatchSlotVisibilities()

			local startIdx = (batchIdx - 1) * maxSlots + 1
			local endIdx = math.min(batchIdx * maxSlots, #results)
			local batchCount = endIdx - startIdx + 1

			local batchQueue: { { slotIdx: number, item: RollResult } } = {}
			for i = 1, batchCount do
				table.insert(batchQueue, { slotIdx = i, item = results[startIdx + i - 1] })
			end

			sortByRarity(batchQueue)

			local slotLookup: { [string]: GuiObject? } = {}
			if overlayRef then
				for _, descendant in overlayRef:GetDescendants() do
					if descendant:IsA("GuiObject") and slotLookup[descendant.Name] == nil then
						slotLookup[descendant.Name] = descendant
					end
				end
			end

			for _, entry in batchQueue do
				local slotIdx = entry.slotIdx
				local item = entry.item

				local delay = CratesConfig.STAGGER_REVEAL_DELAY
				local effCfg = (CratesConfig.EFFECTS :: any)[item.rarity]
				if (item.rarity == "Mythic" or item.rarity == "Legendary") and effCfg and effCfg.SlowRevealDelay then
					delay = effCfg.SlowRevealDelay
				end

				task.wait(delay)
				if Fusion.peek(isSkipped) or isClosing then
					return
				end

				slotVisibilities[slotIdx]:set(true)
				local slotFrame: GuiObject? = nil
				if overlayRef then
					slotFrame = slotLookup["BatchSlot_" .. tostring(slotIdx)] or slotLookup["RevealSlot_" .. item.id]
				end
				local hasLegendaryEscalation = (highestTier == "Legendary")
				RevealEffects.trigger(item.rarity, slotFrame, overlayRef, {
					isDuplicate = (item.isDuplicate == true) or (item.refundAmount ~= nil and item.refundAmount > 0),
					hasLegendaryEscalation = hasLegendaryEscalation,
				})
			end

			task.wait(CratesConfig.HOLD_REVEAL_SECONDS)
			if Fusion.peek(isSkipped) or isClosing then
				return
			end
		end

		UISound.setCrateOpeningActive(false)
		currentPhase:set("Complete")
	end)

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	local overlayFrame = scope:New("Frame")({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Theme.Modal.Overlay,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 1,

		[Fusion.Children] = {
			scope:Computed(function(use: FusionUseFn)
				local phase = use(currentPhase)
				if phase == "Complete" or phase == "Error" then
					return nil
				end

				return scope:New("Frame")({
					Name = "SkipContainer",
					Size = UDim2.fromOffset(110, 36),
					Position = UDim2.new(1, -28, 0, 28),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					ZIndex = 20,

					[Fusion.Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
						scope:New("UIStroke")({
							Color = scope:Computed(function(innerUse: FusionUseFn)
								return if innerUse(isSkipHovered) then Color3.fromRGB(255, 255, 255) else Theme.Colors.SilverMuted
							end),
							Thickness = 1,
							Transparency = 0.3,
						}),
						scope:New("TextButton")({
							Name = "SkipButton",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = string.format("[%s] SKIP", CratesConfig.SKIP_KEYBIND.Name),
							TextColor3 = scope:Computed(function(innerUse: FusionUseFn)
								return if innerUse(isSkipHovered) then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(200, 205, 215)
							end),
							TextSize = 12,
							Font = Theme.Text.Bold,
							AutoButtonColor = false,

							[Fusion.OnEvent("MouseEnter")] = function()
								isSkipHovered:set(true)
							end,
							[Fusion.OnEvent("MouseLeave")] = function()
								isSkipHovered:set(false)
							end,
							[Fusion.OnEvent("Activated")] = handleSkip,
						}),
					},
				})
			end),

			scope:Computed(function(use: FusionUseFn)
				local phase = use(currentPhase)

				if phase == "Placeholder" then
					return PlaceholderStage(scope, {
						Crate = crate,
						HighestRarity = highestRarity,
						HasLegendary = hasLegendary,
					})
				elseif phase == "Reveal" then
					local results = getResults() or {}
					local totalBatches = math.max(1, math.ceil(#results / maxSlots))
					local batchIdx = use(currentBatchIndex)
					local startIdx = (batchIdx - 1) * maxSlots + 1
					local endIdx = math.min(batchIdx * maxSlots, #results)

					local batchItems: { RollResult } = {}
					for i = startIdx, endIdx do
						table.insert(batchItems, results[i])
					end

					return BatchRevealStage(scope, {
						Items = batchItems,
						SlotVisibility = slotVisibilities,
						BatchIndex = batchIdx,
						TotalBatches = totalBatches,
					})
				elseif phase == "Error" then
					local errMsg = getErrorMessage() or "No response from the server. Your crate may have opened. Check your inventory."
					return scope:New("Frame")({
						Name = "ErrorStage",
						Size = UDim2.fromOffset(400, 220),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						BackgroundTransparency = 0.15,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(255, 75, 75),
								Thickness = 1.2,
							}),
							scope:New("TextLabel")({
								Name = "ErrorTitle",
								Size = UDim2.new(1, 0, 0, 30),
								Position = UDim2.fromOffset(0, 20),
								BackgroundTransparency = 1,
								Text = "OPENING FAILED",
								TextColor3 = Color3.fromRGB(255, 80, 80),
								TextSize = 18,
								Font = Theme.Text.Black,
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							scope:New("TextLabel")({
								Name = "ErrorMessage",
								Size = UDim2.new(1, -40, 0, 50),
								Position = UDim2.fromOffset(20, 55),
								BackgroundTransparency = 1,
								Text = errMsg,
								TextColor3 = Color3.fromRGB(220, 220, 225),
								TextSize = 13,
								Font = Theme.Text.Medium,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							scope:New("Frame")({
								Name = "CloseBtnHolder",
								Size = UDim2.fromOffset(140, 38),
								Position = UDim2.fromScale(0.5, 0.78),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(40, 40, 45),

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Radius.Small }),
									scope:New("UIStroke")({ Color = Theme.Colors.SilverMuted, Thickness = 1 }),
									scope:New("TextButton")({
										Name = "CloseBtn",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = "CLOSE",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 12,
										Font = Theme.Text.Bold,
										[Fusion.OnEvent("Activated")] = handleClose,
									}),
								},
							}),
						},
					})
				else
					local results = getResults() or {}
					local totalRefund = getTotalRefund()
					return SummaryStage(scope, {
						Results = results,
						TotalRefund = totalRefund,
						OnClose = handleClose,
					})
				end
			end),
		},
	})

	overlayRef = overlayFrame

	local screenGui = scope:New("ScreenGui")({
		Name = "CrateOpeningGui",
		AutoLocalize = false,
		DisplayOrder = 100010,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,

		[Fusion.Children] = {
			overlayFrame,
		},
	})
	screenGuiRef = screenGui

	local destroyConn = screenGui.Destroying:Connect(function()
		pcall(RevealEffects.cleanup)
	end)
	local ancestryConn = screenGui.AncestryChanged:Connect(function(_, parent)
		if not parent then
			pcall(RevealEffects.cleanup)
		end
	end)

	table.insert(scope, function()
		destroyConn:Disconnect()
		ancestryConn:Disconnect()
		pcall(RevealEffects.cleanup)
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)

	return screenGui
end

return CrateOpeningOverlay
