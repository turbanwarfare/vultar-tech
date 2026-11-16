--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local BundleTypes = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)
local PurchaseRedirectController = require(script.Parent.Parent.Parent.PurchaseRedirectController)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type PurchaseButtonProps = BundleTypes.PurchaseButtonProps

local COLOR_CLR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 210, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 190, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70)),
})

local function PurchaseButton(scope: FusionScope, props: PurchaseButtonProps): Frame
	local gamepassId = props.GamepassId
	local buttonLabel = props.ButtonLabel or "PURCHASE BUNDLE"
	local isButtonHovered = scope:Value(false)

	local buttonScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isButtonHovered) then 1.02 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local function promptPurchase()
		PurchaseRedirectController.promptPurchase(gamepassId)
	end

	return scope:New("Frame")({
		Name = "PurchaseSection",
		Size = UDim2.fromOffset(Constants.LIST_WIDTH, Constants.PURCHASE_BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 2,

		[Fusion.Children] = {
			scope:New("TextButton")({
				Name = "PurchaseButton",
				Size = scope:Computed(function(use: FusionUseFn)
					local scale = use(buttonScale)
					return UDim2.new(scale, 0, 0, Constants.PURCHASE_BUTTON_HEIGHT - 4)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(45, 180, 80),
				Text = "",

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("UIStroke")({
						Color = Color3.fromRGB(80, 220, 120),
						Thickness = 1.5,
						Transparency = 0.2,
					}),

					scope:New("UIGradient")({
						Color = COLOR_CLR_SEQ,
						Rotation = 90,
					}),

					scope:New("TextLabel")({
						Name = "ButtonText",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = buttonLabel,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 16,
						Font = Enum.Font.GothamBlack,
					}),
				},

				[Fusion.OnEvent("MouseEnter")] = function()
					isButtonHovered:set(true)
				end,
				[Fusion.OnEvent("MouseLeave")] = function()
					isButtonHovered:set(false)
				end,
				[Fusion.OnEvent("Activated")] = promptPurchase,
			}),
		},
	})
end

return PurchaseButton
