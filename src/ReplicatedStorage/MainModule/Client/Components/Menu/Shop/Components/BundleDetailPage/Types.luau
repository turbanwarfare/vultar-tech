--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Types = require(MainModule.Shared.Types)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)

export type FusionScope = Types.FusionScope
export type FusionUseFn = Types.FusionUseFn
export type FusionValue<T> = Types.FusionValue<T>
export type FusionCanBeState<T> = Types.FusionCanBeState<T>
export type ChatMessage = ChatTypes.ChatMessage

export type BundleItem = {
	type: "PlayerCard" | "GunSkin" | "ChatGradient",
	id: string,
	name: string,
	imageId: string?,
	skinId: string?,
	gunName: string?,
	gradientColors: { Color3 }?,
	animated: boolean?,
}

export type BundleDetailPageProps = {
	BundleName: string,
	GamepassId: number,
	Items: { BundleItem },
	OnBack: () -> (),
}

export type CardBackgroundProps = {
	ImageId: FusionCanBeState<string>,
	IsAnimated: FusionCanBeState<boolean>,
	Size: UDim2,
	Transparency: number,
	GradientConfig: NumberSequence?,
	CornerRadius: number?,
}

export type BundleItemListProps = {
	Items: { BundleItem },
	SelectedItem: FusionValue<BundleItem?>,
	HeaderText: string?,
}

export type PlayerCardPreviewProps = {
	SelectedItem: FusionValue<BundleItem?>,
	PreviewImageId: FusionValue<string>,
	PreviewIsAnimated: FusionValue<boolean>,
}

export type GunSkinPreviewProps = {
	SelectedItem: FusionValue<BundleItem?>,
}

export type ChatGradientPreviewProps = {
	SelectedItem: FusionValue<BundleItem?>,
}

export type PurchaseButtonProps = {
	GamepassId: number,
	ButtonLabel: string?,
}

return nil
