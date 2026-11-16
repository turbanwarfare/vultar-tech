--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Profile = require(MainModule.Shared.Utils.Debug.Profile)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type KillData = {
	id: number,
	killerName: string,
	killerUserId: number,
	killerTeam: string,
	killerHealth: number,
	weaponName: string,
	victimName: string,
	victimUserId: number,
	victimTeam: string,
	mutual: boolean?,
	isAcak: boolean?,
}

export type KillFeedProps = {
	Kills: Types.FusionValue<{ KillData }>,
	Visible: Types.FusionValue<boolean>?,
	TextSize: Types.FusionValue<number>?,
	Position: Types.FusionValue<string>?,
}

local BASE_TEXT_SIZE = 14
local BASE_KILL_HEIGHT = 22
local KILL_GAP = 2
local BOTTOM_OFFSET = 100
local SIDE_OFFSET = 20

local TEXT_H_PAD = 5
local COL_GAP = 6
local FADE_IN_TIME = 0.25
local MOVE_TIME = 0.2
local FADE_OUT_TIME = 0.25

local LocalPlayer = Players.LocalPlayer
local LocalUserId = LocalPlayer.UserId

local COLOR_LOCAL = Color3.fromRGB(219, 182, 87)
local COLOR_VULTARIAN = Color3.fromRGB(180, 60, 60)
local COLOR_INITIATE = Color3.fromRGB(140, 140, 140)
local COLOR_HOSTILE = Color3.fromRGB(80, 140, 220)
local COLOR_SPECTATOR = Color3.fromRGB(100, 100, 100)
local COLOR_WEAPON = Color3.fromRGB(255, 255, 255)
local COLOR_BURST_CORE = Color3.fromRGB(255, 255, 255)
local COLOR_BURST_EDGE = Color3.fromRGB(180, 180, 195)

local BURST_COLOR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLOR_BURST_EDGE),
	ColorSequenceKeypoint.new(0.35, COLOR_BURST_CORE),
	ColorSequenceKeypoint.new(0.5, COLOR_BURST_CORE),
	ColorSequenceKeypoint.new(0.65, COLOR_BURST_CORE),
	ColorSequenceKeypoint.new(1, COLOR_BURST_EDGE),
})

local BURST_TRANS_SEQ = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.8),
	NumberSequenceKeypoint.new(0.25, 0.2),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.75, 0.2),
	NumberSequenceKeypoint.new(1, 0.8),
})

local TEAM_COLORS: { [string]: Color3 } = {
	Vultarians = COLOR_VULTARIAN,
	Vultarian = COLOR_VULTARIAN,
	Initiates = COLOR_INITIATE,
	Initiate = COLOR_INITIATE,
	Hostiles = COLOR_HOSTILE,
	Hostile = COLOR_HOSTILE,
	Spectators = COLOR_SPECTATOR,
	Spectator = COLOR_SPECTATOR,
}

local function getTeamColor(teamName: string, userId: number): Color3
	if userId == LocalUserId then
		return COLOR_LOCAL
	end
	return TEAM_COLORS[teamName] or COLOR_INITIATE
end

type ItemState = {
	id: number,
	posY: number,
	opacity: number,
	burstWidth: number,
	burstOpacity: number,
	frame: Frame,
	burstFrame: Frame,
	textLabels: { TextLabel },
	textDims: { number },
	scope: any,
	fadeInStart: number,
	fadeInComplete: boolean,
	isExiting: boolean,
	currentIndex: number,
	targetIndex: number,
	moveStartTime: number?,
	moveStartIdx: number?,
	moveTargetIdx: number?,
	exitStartTime: number?,
	isLocalKill: boolean,
}

local function KillFeed(scope: FusionScope, props: KillFeedProps): ScreenGui
	local textSizeValue = props.TextSize or scope:Value(BASE_TEXT_SIZE)
	local positionValue = props.Position or scope:Value("Middle")

	local killHeight = scope:Computed(function(use: FusionUseFn)
		return BASE_KILL_HEIGHT * use(textSizeValue) / BASE_TEXT_SIZE
	end)

	local slotHeight = scope:Computed(function(use: FusionUseFn)
		return use(killHeight) + KILL_GAP
	end)

	local items: { [number]: ItemState } = {}
	local pendingRemovals: { [number]: true } = {}
	local renderConnection: RBXScriptConnection? = nil

	local container = scope:New("Frame")({
		Name = "KillFeedContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local function createItemUI(itemScope: FusionScope, kill: KillData, state: ItemState): Frame
		local isEnvironmental = kill.victimName == ""
		local isLocalDeath = kill.killerUserId == LocalUserId

		local collectedLabels: { TextLabel } = {}
		local collectedDims: { number } = {}

		local burstFrame = itemScope:New("Frame")({
			Size = UDim2.fromOffset(2, BASE_KILL_HEIGHT + 6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = COLOR_BURST_CORE,
			BackgroundTransparency = 1,
			ZIndex = 99,
			[Fusion.Children] = {
				itemScope:New("UIGradient")({
					Color = BURST_COLOR_SEQ,
					Transparency = BURST_TRANS_SEQ,
				}),
				itemScope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
			},
		})

		local innerContent: Instance

		if isEnvironmental then
			local nameColor
			if kill.killerColor then
				nameColor = kill.killerColor
			elseif isLocalDeath then
				nameColor = COLOR_LOCAL
			else
				nameColor = COLOR_WEAPON
			end

			local fullText = kill.killerName .. " " .. kill.weaponName

			local label = itemScope:New("TextLabel")({
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = fullText,
				TextColor3 = nameColor,
				TextTransparency = 1,
				TextSize = textSizeValue,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextStrokeTransparency = 0.6,
				TextStrokeColor3 = Color3.new(0, 0, 0),
			})
			table.insert(collectedLabels, label)
			table.insert(collectedDims, 0)

			local wrapper = itemScope:New("Frame")({
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 100,
				[Fusion.Children] = {
					itemScope:New("UIPadding")({
						PaddingLeft = UDim.new(0, TEXT_H_PAD),
						PaddingRight = UDim.new(0, TEXT_H_PAD),
					}),
					label,
				},
			})

			innerContent = wrapper
		else
			local killerColor = getTeamColor(kill.killerTeam, kill.killerUserId)
			local victimColor = getTeamColor(kill.victimTeam, kill.victimUserId)

			local function makeText(text: string, color: Color3, align: Enum.TextXAlignment, order: number, dim: number): Frame
				local label = itemScope:New("TextLabel")({
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = text,
					TextColor3 = color,
					TextTransparency = 1,
					TextSize = textSizeValue,
					Font = Theme.Text.Bold,
					TextXAlignment = align,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextStrokeTransparency = 0.6,
					TextStrokeColor3 = Color3.new(0, 0, 0),
				})
				table.insert(collectedLabels, label)
				table.insert(collectedDims, dim)

				return itemScope:New("Frame")({
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					LayoutOrder = order,
					ClipsDescendants = false,
					[Fusion.Children] = {
						itemScope:New("UIPadding")({
							PaddingLeft = UDim.new(0, TEXT_H_PAD),
							PaddingRight = UDim.new(0, TEXT_H_PAD),
						}),
						label,
					},
				})
			end

			innerContent = itemScope:New("Frame")({
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 100,
				[Fusion.Children] = {
					itemScope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, COL_GAP),
					}),
					makeText(kill.killerName .. " [" .. kill.killerHealth .. "%]", killerColor, Enum.TextXAlignment.Left, 1, 0),
					makeText(if kill.mutual then kill.weaponName .. "  [⇄]" else kill.weaponName, COLOR_WEAPON, Enum.TextXAlignment.Left, 2, 0.15),
					makeText(kill.victimName, victimColor, Enum.TextXAlignment.Left, 3, 0),
				},
			})
		end

		local frame = itemScope:New("Frame")({
			Size = UDim2.fromOffset(0, BASE_KILL_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			ZIndex = 100,
			[Fusion.Children] = { innerContent },
		})

		state.textLabels = collectedLabels
		state.textDims = collectedDims
		state.burstFrame = burstFrame

		return frame
	end

	local function removeItem(id: number)
		local state = items[id]
		if state then
			state.scope:doCleanup()
			items[id] = nil
		end
		pendingRemovals[id] = nil
	end

	local cachedSlotHeight = BASE_KILL_HEIGHT + KILL_GAP
	local cachedPosition = "Middle"

	scope:Observer(slotHeight):onBind(function()
		cachedSlotHeight = Fusion.peek(slotHeight)
	end)
	scope:Observer(positionValue):onBind(function()
		cachedPosition = Fusion.peek(positionValue)
	end)

	local function applyPosition(state: ItemState)
		local y = state.posY
		local slot = cachedSlotHeight
		local pos = cachedPosition
		if pos == "Left" then
			state.frame.AnchorPoint = Vector2.new(0, 1)
			state.frame.Position = UDim2.new(0, SIDE_OFFSET, 0.65, -y * slot)
		elseif pos == "Right" then
			state.frame.AnchorPoint = Vector2.one
			state.frame.Position = UDim2.new(1, -SIDE_OFFSET, 0.65, -y * slot)
		else
			state.frame.AnchorPoint = Vector2.new(0.5, 1)
			state.frame.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET - y * slot)
		end

		state.burstFrame.Position = state.frame.Position
		state.burstFrame.AnchorPoint = state.frame.AnchorPoint
	end

	local function applyOpacity(state: ItemState)
		local opacity = state.opacity
		for i, label in state.textLabels do
			label.TextTransparency = math.clamp(1 - opacity + state.textDims[i], 0, 1)
		end
	end

	local function applyBurst(state: ItemState)
		state.burstFrame.Position = state.frame.Position
		state.burstFrame.AnchorPoint = state.frame.AnchorPoint
		state.burstFrame.Size = UDim2.fromOffset(state.burstWidth, BASE_KILL_HEIGHT + 6)
		state.burstFrame.BackgroundTransparency = 1 - state.burstOpacity
	end

	local function updateAnimations()
		local now = os.clock()
		local hasActiveAnimations = false

		for id, state in items do
			if not state.fadeInComplete then
				hasActiveAnimations = true
				local progress = math.clamp((now - state.fadeInStart) / FADE_IN_TIME, 0, 1)
				state.opacity = progress
				if state.isLocalKill then
					local frameW = state.frame.AbsoluteSize.X
					if frameW == 0 then
						frameW = 200
					end
					state.burstWidth = 2 + (frameW + 40) * progress
					state.burstOpacity = 0.4 * (1 - progress * progress)
				end
				if progress >= 1 then
					state.fadeInComplete = true
					state.opacity = 1
					if state.isLocalKill then
						state.burstWidth = state.frame.AbsoluteSize.X + 42
						state.burstOpacity = 0
					end
				end
				applyOpacity(state)
				if state.isLocalKill then
					applyBurst(state)
				end
			end

			if state.isExiting and state.exitStartTime then
				hasActiveAnimations = true
				local progress = math.clamp((now - state.exitStartTime) / FADE_OUT_TIME, 0, 1)
				state.opacity = 1 - progress
				applyOpacity(state)
				if progress >= 1 then
					removeItem(id)
				end
			elseif state.moveStartTime and state.moveStartIdx and state.moveTargetIdx then
				hasActiveAnimations = true
				local progress = math.clamp((now - state.moveStartTime) / MOVE_TIME, 0, 1)
				state.posY = state.moveStartIdx + (state.moveTargetIdx - state.moveStartIdx) * progress
				if progress >= 1 then
					state.posY = state.moveTargetIdx
					state.moveStartTime = nil
					state.moveStartIdx = nil
					state.moveTargetIdx = nil
				end
				applyPosition(state)
			end
		end

		if not hasActiveAnimations and renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
	end

	local function ensureRenderConnection()
		if not renderConnection then
			renderConnection = RunService.RenderStepped:Connect(updateAnimations)
		end
	end

	local function setItemIndex(state: ItemState, newIndex: number)
		if state.isExiting or newIndex == state.currentIndex then
			return
		end
		state.currentIndex = newIndex
		if newIndex == state.targetIndex then
			return
		end
		state.moveStartTime = os.clock()
		state.moveStartIdx = state.posY
		state.moveTargetIdx = newIndex - 1
		state.targetIndex = newIndex
		ensureRenderConnection()
	end

	local function startItemExit(state: ItemState)
		if state.isExiting then
			return
		end
		state.isExiting = true
		state.exitStartTime = os.clock()
		ensureRenderConnection()
	end

	local function syncKills(kills: { KillData })
		local activeIds: { [number]: true } = {}
		for _, kill in kills do
			activeIds[kill.id] = true
		end

		for id in items do
			if not activeIds[id] and not pendingRemovals[id] then
				pendingRemovals[id] = true
				startItemExit(items[id])
			end
		end

		local visibleIndex = 0
		for _, kill in kills do
			if not pendingRemovals[kill.id] then
				visibleIndex += 1
			end

			local existing = items[kill.id]
			if existing then
				if not pendingRemovals[kill.id] then
					setItemIndex(existing, visibleIndex)
				end
			elseif not pendingRemovals[kill.id] then
				local itemScope = Fusion.scoped(Fusion)
				local isLocal = kill.killerUserId == LocalUserId and kill.victimName ~= ""
				local state: ItemState = {
					id = kill.id,
					posY = visibleIndex - 1,
					opacity = 0,
					burstWidth = 2,
					burstOpacity = if isLocal then 0.4 else 0,
					frame = nil :: any,
					burstFrame = nil :: any,
					textLabels = {},
					textDims = {},
					scope = itemScope,
					fadeInStart = os.clock(),
					fadeInComplete = false,
					isExiting = false,
					currentIndex = visibleIndex,
					targetIndex = visibleIndex,
					moveStartTime = nil,
					moveStartIdx = nil,
					moveTargetIdx = nil,
					exitStartTime = nil,
					isLocalKill = isLocal,
				}
				state.frame = Profile.run("Vultar::KillFeed::createRow", createItemUI, itemScope, kill, state)
				state.frame.Parent = container
				state.burstFrame.Parent = container
				applyPosition(state)
				if isLocal then
					applyBurst(state)
				end
				items[kill.id] = state
				ensureRenderConnection()
			end
		end
	end

	scope:Observer(props.Kills):onBind(function()
		syncKills(Fusion.peek(props.Kills))
	end)

	table.insert(scope, function()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		for _, state in items do
			state.scope:doCleanup()
		end
		table.clear(items)
		table.clear(pendingRemovals)
	end)

	return scope:New("ScreenGui")({
		Name = "KillFeed",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = props.Visible,
		[Fusion.Children] = { container },
	})
end

return KillFeed
