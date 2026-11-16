--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local EconomyConfig = require(MainModule.Shared.Config.Economy.EconomyConfig)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local MenuNavigation = require(MainModule.Client.Components.Menu.MenuNavigation)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type CreditsModalProps = {
	Visible: any,
}

type ModalButtonProps = {
	Name: string,
	Text: string,
	Order: number,
	Accent: Color3,
	Fill: Color3,
	FillTransparency: number,
	Visible: boolean,
	OnActivated: () -> (),
}

local MODAL_Z = 50
local PANEL_WIDTH = 380
local BUTTON_HEIGHT = 48
local MODAL_LINE_COLOR = Color3.fromRGB(88, 88, 88)
local MUTED_COLOR = Color3.fromRGB(120, 120, 120)
local BUY_ACCENT = Color3.fromRGB(255, 200, 60)
local BUY_FILL = Color3.fromRGB(50, 38, 10)
local CRATES_ACCENT = Color3.fromRGB(240, 240, 240)

local function ModalButton(scope: FusionScope, props: ModalButtonProps): TextButton
	return scope:New("TextButton")({
		Name = props.Name,
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = props.Fill,
		BackgroundTransparency = props.FillTransparency,
		Text = props.Text,
		TextColor3 = props.Accent,
		TextSize = 14,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		LayoutOrder = props.Order,
		Visible = props.Visible,
		ZIndex = MODAL_Z + 2,

		[Fusion.OnEvent("Activated")] = props.OnActivated,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({
				Color = props.Accent,
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = 0.3,
			}),
		},
	})
end

local function CreditsModal(scope: FusionScope, props: CreditsModalProps): Frame
	local function close(): ()
		props.Visible:set(false)
	end

	local function openMenu(target: MenuNavigation.Target): ()
		close()
		MenuNavigation.request(target)
		local settings = ServiceLocator.Settings()
		if settings then
			settings:Show()
		end
	end

	return scope:New("Frame")({
		Name = "CreditsModal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		Visible = props.Visible,
		ZIndex = MODAL_Z,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.fromOffset(PANEL_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(14, 14, 14),
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = MODAL_Z + 1,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("UIStroke")({
						Color = MODAL_LINE_COLOR,
						Thickness = 1,
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 20),
						PaddingBottom = UDim.new(0, 16),
						PaddingLeft = UDim.new(0, 20),
						PaddingRight = UDim.new(0, 20),
					}),
					scope:New("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 12),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = "CREDITS",
						TextColor3 = Theme.Colors.White,
						TextSize = 18,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
						ZIndex = MODAL_Z + 2,
					}),

					scope:New("TextLabel")({
						Name = "Subtitle",
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = "Get more credits, or spend them on crates.",
						TextColor3 = Color3.fromRGB(170, 170, 178),
						TextSize = 12,
						Font = Theme.Text.Semibold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
						ZIndex = MODAL_Z + 2,
					}),

					ModalButton(scope, {
						Name = "BuyCreditsButton",
						Text = "BUY CREDITS",
						Order = 3,
						Accent = BUY_ACCENT,
						Fill = BUY_FILL,
						FillTransparency = 0.3,
						Visible = #EconomyConfig.CREDIT_PRODUCTS > 0,
						OnActivated = function()
							openMenu("BuyCredits")
						end,
					}),

					ModalButton(scope, {
						Name = "OpenCratesButton",
						Text = "OPEN CRATES",
						Order = 4,
						Accent = CRATES_ACCENT,
						Fill = Color3.fromRGB(8, 8, 8),
						FillTransparency = 0.35,
						Visible = true,
						OnActivated = function()
							openMenu("Crates")
						end,
					}),

					scope:New("TextButton")({
						Name = "CloseButton",
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = "CLOSE",
						TextColor3 = MUTED_COLOR,
						TextSize = 12,
						Font = Theme.Text.Bold,
						AutoButtonColor = false,
						LayoutOrder = 5,
						ZIndex = MODAL_Z + 2,

						[Fusion.OnEvent("Activated")] = close,
					}),
				},
			}),
		},
	})
end

return CreditsModal
