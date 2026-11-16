--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

local Constants = require(script.Parent.Parent.Constants)
local Utils = require(script.Parent.Parent.Utils)
local PlayerStatsStore = require(script.Parent.Parent.PlayerStatsStore)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type LeaderboardEntry = Types.LeaderboardEntry

local CARD_FADE_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local SEPARATOR_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.1, 0),
	NumberSequenceKeypoint.new(0.9, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local HOVER_TWEEN_IN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_TWEEN_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type PlayerRowProps = {
	Entry: LeaderboardEntry,
	IsLocalPlayer: boolean,
	LayoutOrder: Types.FusionCanBeState<number>?,
	ShowSeparator: boolean?,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
	IsFirstRow: boolean?,
	OnClick: (() -> ())?,
}

local function PlayerRow(scope: FusionScope, props: PlayerRowProps): Frame
	local entry = props.Entry
	local isLocal = props.IsLocalPlayer
	local isSpectator = Utils.isSpectator(entry.Team)
	local isFirstRow = props.IsFirstRow == true

	local textColor = Utils.getTextColor(isLocal, isSpectator)
	local textTransparency = Utils.getTextTransparency(isSpectator, isLocal)

	local statsStore = props.StatsStore
	local playerStats = statsStore and statsStore:getPlayerStats(entry.UserId) or nil

	local cardImageId = if playerStats
		then scope:Computed(function(use)
			return use(playerStats.CardImageId) or entry.CardImageId or ""
		end)
		else entry.CardImageId or ""

	local children: { any } = {}

	local initialCardImageId = if playerStats then Fusion.peek(playerStats.CardImageId) else entry.CardImageId
	local initialIsAnimatedCard = if playerStats then Fusion.peek(playerStats.IsAnimatedCard) else entry.IsAnimatedCard

	if initialCardImageId and initialCardImageId ~= "" then
		if initialIsAnimatedCard then
			local animatedContainerChildren: { Instance } = {}
			if isFirstRow then
				table.insert(animatedContainerChildren, scope:New("UICorner")({ CornerRadius = UDim.new(0, Constants.CORNER_RADIUS) }))
			end
			table.insert(
				animatedContainerChildren,
				scope:New("UIGradient")({
					Transparency = CARD_FADE_GRADIENT,
					Rotation = 0,
				})
			)
			table.insert(
				animatedContainerChildren,
				scope:New("Frame")({
					Name = "ScrollingFrame",
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromScale(2, 1),
					BackgroundTransparency = 1,

					[Fusion.Children] = {
						scope:New("ImageLabel")({
							Name = "CardImage1",
							Position = UDim2.fromOffset(0, 0),
							Size = UDim2.fromScale(0.5, 1),
							BackgroundTransparency = 1,
							Image = cardImageId,
							ImageTransparency = 0.5,
							ScaleType = Enum.ScaleType.Crop,
							ZIndex = 1,
						}),
						scope:New("ImageLabel")({
							Name = "CardImage2",
							Position = UDim2.fromScale(0.5, 0),
							Size = UDim2.fromScale(0.5, 1),
							BackgroundTransparency = 1,
							Image = cardImageId,
							ImageTransparency = 0.5,
							ScaleType = Enum.ScaleType.Crop,
							ZIndex = 1,
						}),
					},
				})
			)

			local animatedContainer = scope:New("CanvasGroup")({
				Name = "AnimatedCardContainer",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = 0,
				ZIndex = 1,

				[Fusion.Children] = animatedContainerChildren,
			})

			table.insert(children, animatedContainer)

			task.spawn(function()
				task.wait()
				local container = animatedContainer :: Frame
				if container and container.Parent then
					AnimatedCardService:RegisterContainer(container, entry.UserId)
				end
			end)
		else
			local cardChildren: { Instance } = {}
			if isFirstRow then
				table.insert(cardChildren, scope:New("UICorner")({ CornerRadius = UDim.new(0, Constants.CORNER_RADIUS) }))
			end

			table.insert(
				children,
				scope:New("ImageLabel")({
					Name = "CardBackground",
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = cardImageId,
					ImageTransparency = 0.5,
					ScaleType = Enum.ScaleType.Crop,
					ZIndex = 1,

					[Fusion.Children] = cardChildren,
				})
			)
		end
	end

	table.insert(
		children,
		scope:New("ImageLabel")({
			Name = "Thumbnail",
			Position = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.zero,
			Size = UDim2.fromOffset(Constants.ROW_HEIGHT, Constants.ROW_HEIGHT),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150",
			ImageTransparency = if isSpectator then Constants.SPECTATOR_TEXT_TRANSPARENCY else 0,
			ZIndex = 2,
		})
	)

	local usernameLabel = scope:New("TextLabel")({
		Name = "Username",
		Position = UDim2.new(0, Constants.ROW_HEIGHT + Constants.ROW_USERNAME_OFFSET, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(Constants.USERNAME_END, -(Constants.ROW_HEIGHT + Constants.ROW_USERNAME_OFFSET * 2), 0, Constants.ROW_USERNAME_HEIGHT),
		BackgroundTransparency = 1,
		Text = entry.Username or entry.DisplayName,
		TextColor3 = textColor,
		TextTransparency = textTransparency,
		TextScaled = true,
		Font = Constants.Font.Bold,
		TextStrokeColor3 = textColor,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 2,

		[Fusion.Children] = {
			scope:New("UITextSizeConstraint")({
				MaxTextSize = Constants.ROW_USERNAME_MAX_SIZE,
				MinTextSize = Constants.ROW_USERNAME_MIN_SIZE,
			}),
		},
	})
	table.insert(children, usernameLabel)

	for _, col in Constants.STAT_COLUMNS do
		local statText: any

		if playerStats then
			local statValue = (playerStats :: any)[col.key]
			if statValue then
				statText = scope:Computed(function(use)
					local val = use(statValue)
					if col.key == "Kills" or col.key == "Captures" then
						return tostring(val)
					else
						return Utils.formatNumber(val)
					end
				end)
			else
				statText = Utils.getStatValue(entry.Stats, col.key)
			end
		else
			statText = Utils.getStatValue(entry.Stats, col.key)
		end

		table.insert(
			children,
			scope:New("TextLabel")({
				Name = col.key,
				Position = UDim2.fromScale(col.pos, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(Constants.STAT_WIDTH, 0, 0, Constants.ROW_STAT_HEIGHT),
				BackgroundTransparency = 1,
				Text = statText,
				TextColor3 = textColor,
				TextTransparency = textTransparency,
				TextSize = Constants.ROW_STAT_SIZE,
				Font = Constants.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 2,
			})
		)
	end

	if props.ShowSeparator then
		table.insert(
			children,
			scope:New("Frame")({
				Name = "Separator",
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0, Constants.SEPARATOR_THICKNESS),
				BackgroundColor3 = Constants.Colors.Initiates,
				BorderSizePixel = 0,
				ZIndex = 3,

				[Fusion.Children] = {
					scope:New("UIGradient")({
						Transparency = SEPARATOR_GRADIENT,
						Rotation = 0,
					}),
				},
			})
		)
	end

	return scope:New("TextButton")({
		Name = "PlayerRow_" .. entry.UserId,
		Size = UDim2.new(1, 0, 0, Constants.ROW_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = 2,
		Text = "",
		AutoButtonColor = false,

		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,

		[Fusion.OnEvent("MouseEnter")] = function()
			TweenService:Create(usernameLabel, HOVER_TWEEN_IN, { TextStrokeTransparency = 0.75 }):Play()
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			TweenService:Create(usernameLabel, HOVER_TWEEN_OUT, { TextStrokeTransparency = 1 }):Play()
		end,

		[Fusion.Children] = children,
	})
end

return PlayerRow
