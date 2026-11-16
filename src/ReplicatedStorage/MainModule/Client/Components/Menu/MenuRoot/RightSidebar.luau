--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local Constants = require(script.Parent.Constants)
local ActionButton = require(script.Parent.ActionButton)
local NPCViewport = require(script.Parent.Parent.NPCViewport)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

export type Props = {
	Visible: FusionCanBeState<boolean>,
	PreviewOnRight: FusionValue<boolean>,
	PreviewForcedToBottom: FusionCanBeState<boolean>?,
	Width: FusionValue<number>,
	OnResetSettings: (() -> ())?,
	OnShareClick: () -> (),
}

local function RightSidebar(scope: FusionScope, props: Props): Frame
	return scope:New("Frame")({
		Name = "RightSidebar",
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(0, use(props.Width), 1, -12)
		end),
		Position = UDim2.fromOffset(Constants.SIDEBAR_WIDTH + Constants.SIDEBAR_GAP + Theme.Settings.ContentWidth + Constants.SIDEBAR_GAP, 0),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "BottomModeContent",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					return not use(props.PreviewOnRight)
				end),

				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 2),
					}),

					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					ActionButton(scope, {
						Text = "RESET SETTINGS",
						LayoutOrder = 1,
						ColorConfig = Constants.BUTTON_COLORS.Reset,
						OnClick = function()
							if props.OnResetSettings then
								props.OnResetSettings()
							end
						end,
					}),

					ActionButton(scope, {
						Text = "SHARE / IMPORT",
						LayoutOrder = 2,
						ColorConfig = Constants.BUTTON_COLORS.Share,
						OnClick = props.OnShareClick,
					}),

					scope:New("Frame")({
						Name = "Spacer",
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
					}),

					scope:New("TextLabel")({
						Name = "HelpTitle",
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = "HELP",
						TextColor3 = Color3.fromRGB(90, 90, 95),
						TextSize = 9,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 4,
					}),

					scope:New("TextLabel")({
						Name = "HelpText",
						Size = UDim2.new(1, 0, 0, 80),
						BackgroundTransparency = 1,
						Text = "Use the sidebar to jump between sections, or scroll down manually. Click PREVIEW at the bottom to test your hit feedback settings on a target dummy.",
						TextColor3 = Color3.fromRGB(111, 111, 116),
						TextSize = 10,
						Font = Theme.Text.Regular,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = true,
						LayoutOrder = 5,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "RightModeContent",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = props.PreviewOnRight,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "ViewportContainer",
						Size = UDim2.new(1, 0, 1, -100),
						Position = UDim2.fromOffset(0, 10),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							NPCViewport(scope, {
								Size = UDim2.fromScale(1, 1),
								Visible = scope:Computed(function(use: FusionUseFn): boolean
									return use(props.Visible) == true and use(props.PreviewOnRight)
								end),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "ButtonsContainer",
						Size = UDim2.new(1, 0, 0, 82),
						Position = UDim2.new(0, 0, 1, -82),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 8),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),

							ActionButton(scope, {
								Text = "RESET SETTINGS",
								LayoutOrder = 1,
								ColorConfig = Constants.BUTTON_COLORS.Reset,
								OnClick = function()
									if props.OnResetSettings then
										props.OnResetSettings()
									end
								end,
							}),

							ActionButton(scope, {
								Text = "SHARE / IMPORT",
								LayoutOrder = 2,
								ColorConfig = Constants.BUTTON_COLORS.Share,
								OnClick = props.OnShareClick,
							}),
						},
					}),
				},
			}),
		},
	})
end

return RightSidebar
