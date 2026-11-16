--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))

local Constants = require(script.Parent.Parent.Constants)
local FactionHeader = require(script.Parent.FactionHeader)
local PlayerList = require(script.Parent.PlayerList)
local PlayerStatsStore = require(script.Parent.Parent.PlayerStatsStore)
local Shadow = require(MainModule.Client.Components.Shadow)

local Types = require(script.Parent.Parent.Types)
type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FactionData = Types.FactionData

type PlayerStats = Types.PlayerStats

export type FactionPanelProps = {
	Data: FusionCanBeState<FactionData>,
	Totals: FusionCanBeState<PlayerStats>?,
	LocalUserId: number,
	IsDefenders: boolean,
	StatsStore: PlayerStatsStore.PlayerStatsStore?,
	OnRowClick: ((userId: number, cardImageId: string?, isAnimatedCard: boolean) -> ())?,
	IsSpar: boolean?,
}

local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65

local function FactionPanel(scope: FusionScope, props: FactionPanelProps): Frame
	return scope:New("Frame")({
		Name = if props.IsSpar then "PlayersPanel" elseif props.IsDefenders then "DefendersPanel" else "RaidersPanel",
		Size = if props.IsSpar then UDim2.fromScale(1, 1) else UDim2.new(0.5, -Constants.PANEL_GAP / 2, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "HeaderWrapper",
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 0, Constants.HEADER_HEIGHT + SHADOW_SPREAD * 2),
				Position = UDim2.fromOffset(-SHADOW_SPREAD, -SHADOW_SPREAD),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = SHADOW_TRANSPARENCY,
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "HeaderContainer",
						Size = UDim2.new(1, -SHADOW_SPREAD * 2, 1, -SHADOW_SPREAD * 2),
						Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
						BackgroundTransparency = 1,
						ZIndex = 1,

						[Fusion.Children] = {
							FactionHeader(scope, {
								Data = props.Data,
								Totals = props.Totals,
								IsDefenders = props.IsDefenders,
								IsSpar = props.IsSpar,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ListWrapper",
				Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, -Constants.HEADER_HEIGHT - Constants.HEADER_GAP + SHADOW_SPREAD * 2),
				Position = UDim2.fromOffset(-SHADOW_SPREAD, Constants.HEADER_HEIGHT + Constants.HEADER_GAP - SHADOW_SPREAD),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = SHADOW_TRANSPARENCY,
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "ListContainer",
						Size = UDim2.new(1, -SHADOW_SPREAD * 2, 1, -SHADOW_SPREAD * 2),
						Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
						BackgroundTransparency = 1,
						ZIndex = 1,

						[Fusion.Children] = {
							PlayerList(scope, {
								Data = props.Data,
								LocalUserId = props.LocalUserId,
								StatsStore = props.StatsStore,
								OnRowClick = props.OnRowClick,
							}),
						},
					}),
				},
			}),
		},
	})
end

return FactionPanel
