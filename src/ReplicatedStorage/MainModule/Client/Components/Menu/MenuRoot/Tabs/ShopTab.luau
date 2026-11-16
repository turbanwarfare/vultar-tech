--!strict

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)
local ShopGrid = require(script.Parent.Parent.Parent.Shop)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

export type Props = {
	Visible: FusionValue<boolean>,
	OwnedItems: FusionValue<{ [string]: boolean }>,
	EquippedItems: FusionValue<{ [string]: any }>,
	ResetTrigger: FusionValue<number>,
	CurrentPage: FusionValue<number>?,
	CurrentTab: FusionValue<string>?,
	SelectedBundleKey: FusionValue<string?>?,
	SelectedPackId: FusionValue<string?>?,
	SelectedSkinId: FusionValue<string?>?,
	SelectedCardId: FusionValue<string?>?,
	OnPurchaseSuccess: ((cosmeticType: string, newState: Network.CosmeticState?) -> ())?,
}

local function ShopTab(scope: FusionScope, props: Props): Frame
	return scope:New("Frame")({
		Name = "ShopContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		[Fusion.Children] = {
			ShopGrid(scope, {
				OnCardClick = function(cardId: string)
					print("[Shop] Card clicked:", cardId)
				end,
				OwnedItems = props.OwnedItems,
				EquippedItems = props.EquippedItems,
				ResetTrigger = props.ResetTrigger,
				CurrentPage = props.CurrentPage,
				CurrentTab = props.CurrentTab,
				SelectedBundleKey = props.SelectedBundleKey,
				SelectedPackId = props.SelectedPackId,
				SelectedSkinId = props.SelectedSkinId,
				SelectedCardId = props.SelectedCardId,
				OnPurchaseSuccess = props.OnPurchaseSuccess,
			}),
		},
	})
end

return ShopTab
