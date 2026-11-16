--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

local Constants = require(script.Constants)
local FactionPanel = require(script.Components.FactionPanel)
local StatCard = require(script.Components.PlayerStatsModal)
local Scale = require(MainModule.Client.Utils.Scaling.Scale)
local PlayerStatsStore = require(script.PlayerStatsStore)
local Maps = require(MainModule.Shared.Config.Maps)

local Types = require(script.Types)
type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>

export type FactionData = Types.FactionData
export type PlayerStatsStore = PlayerStatsStore.PlayerStatsStore

export type LeaderboardProps = {
	Visible: FusionCanBeState<boolean>,
	DefendersData: FusionCanBeState<FactionData>,
	RaidersData: FusionCanBeState<FactionData>,
	DefendersTotals: FusionCanBeState<Types.PlayerStats>?,
	RaidersTotals: FusionCanBeState<Types.PlayerStats>?,
	LocalUserId: number,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
}

local function Leaderboard(scope: FusionScope, props: LeaderboardProps): ScreenGui
	local isSpar = Maps.isSparMode() or Maps.isAimMode()

	local combinedDataState = if isSpar
		then scope:Computed(function(use: FusionUseFn)
			local defenders = use(props.DefendersData)
			local raiders = use(props.RaidersData)

			local entries = {}
			for _, entry in defenders.entries do
				table.insert(entries, entry)
			end
			for _, entry in raiders.entries do
				table.insert(entries, entry)
			end

			table.sort(entries, function(a, b)
				return a.Stats.Kills > b.Stats.Kills
			end)

			local totals = {
				Kills = defenders.totals.Kills + raiders.totals.Kills,
				Damage = defenders.totals.Damage + raiders.totals.Damage,
				Heals = defenders.totals.Heals + raiders.totals.Heals,
				Captures = defenders.totals.Captures + raiders.totals.Captures,
			}

			local factionData: FactionData = {
				name = "PLAYERS",
				displayName = "PLAYERS",
				icon = "",
				entries = entries,
				totals = totals,
				playerCount = #entries,
				teamLabels = {},
			}
			return factionData
		end)
		else nil

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local selectedUserId = scope:Value(nil :: number?)
	local selectedCardImageId = scope:Value(nil :: string?)
	local selectedIsAnimatedCard = scope:Value(false)

	local FADE_SPEED = 8
	local FADE_DAMPING = 1

	local statCardInstance = scope:Value(nil :: CanvasGroup?)
	local statCardScope: any = nil

	local function destroyStatCard()
		if statCardScope then
			Fusion.doCleanup(statCardScope)
			statCardScope = nil
		end
		statCardInstance:set(nil)
	end

	local function createStatCard()
		destroyStatCard()
		statCardScope = Fusion.scoped(Fusion)
		local fadeTarget = statCardScope:Value(1)
		local fadeTransparency = statCardScope:Spring(fadeTarget, FADE_SPEED, FADE_DAMPING)
		local card = StatCard(statCardScope, {
			UserId = selectedUserId,
			CardImageId = selectedCardImageId,
			IsAnimatedCard = selectedIsAnimatedCard,
			GroupTransparency = fadeTransparency,
		})
		statCardInstance:set(card)
		task.defer(function()
			fadeTarget:set(0)
		end)
	end

	table.insert(scope, function()
		destroyStatCard()
	end)

	scope:Observer(selectedUserId):onChange(function()
		local id = Fusion.peek(selectedUserId)
		if id and not statCardScope then
			createStatCard()
		elseif not id and statCardScope then
			destroyStatCard()
		end
	end)

	local function clearSelection()
		selectedUserId:set(nil)
		selectedCardImageId:set(nil)
		selectedIsAnimatedCard:set(false)
	end

	local statCardOpen = scope:Computed(function(use: FusionUseFn)
		return use(selectedUserId) ~= nil
	end)

	scope:Observer(isVisible):onChange(function()
		if not Fusion.peek(isVisible) then
			clearSelection()
		end
	end)

	local function onRowClick(clickedUserId: number, cardImageId: string?, isAnimatedCard: boolean)
		local current = Fusion.peek(selectedUserId)
		if current == clickedUserId then
			clearSelection()
		else
			selectedCardImageId:set(cardImageId)
			selectedIsAnimatedCard:set(isAnimatedCard)
			selectedUserId:set(clickedUserId)
		end
	end

	local viewportScale = Scale.scoped(scope)

	local screenGui = scope:New("ScreenGui")({
		Name = "VultarLeaderboard",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 150,
		Enabled = isVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ClickCatcher",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 0,
				Visible = statCardOpen,
				[Fusion.OnEvent("InputBegan")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						clearSelection()
					end
				end,
			}),

			scope:New("Frame")({
				Name = "Container",
				Position = UDim2.new(0.5, 0, 0.5, -25),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = if isSpar then UDim2.fromOffset(540, 640) else UDim2.fromOffset(Constants.CONTAINER_WIDTH, Constants.CONTAINER_HEIGHT),
				BackgroundTransparency = 1,
				Visible = isVisible,

				[Fusion.Children] = {
					scope:New("UIScale")({
						Scale = viewportScale,
					}),

					scope:New("Frame")({
						Name = "PanelsRow",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, Constants.PANEL_GAP),
							}),

							if isSpar
								then FactionPanel(scope, {
									Data = combinedDataState :: any,
									Totals = nil,
									LocalUserId = props.LocalUserId,
									IsDefenders = true,
									StatsStore = props.StatsStore,
									OnRowClick = onRowClick,
									IsSpar = true,
								})
								else FactionPanel(scope, {
									Data = props.DefendersData,
									Totals = props.DefendersTotals,
									LocalUserId = props.LocalUserId,
									IsDefenders = true,
									StatsStore = props.StatsStore,
									OnRowClick = onRowClick,
								}),

							if not isSpar
								then FactionPanel(scope, {
									Data = props.RaidersData,
									Totals = props.RaidersTotals,
									LocalUserId = props.LocalUserId,
									IsDefenders = false,
									StatsStore = props.StatsStore,
									OnRowClick = onRowClick,
								})
								else nil,
						},
					}),

					statCardInstance,
				},
			}),
		},
	})

	return screenGui
end

return Leaderboard
