--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope

export type ChatGradientsPageProps = {
	OwnedItems: Types.FusionValue<{ [string]: boolean }>?,
	EquippedItems: Types.FusionValue<{ [string]: any }>?,
}

local ChatGradientsPage = {}

function ChatGradientsPage.create(scope: FusionScope, _props: ChatGradientsPageProps): Frame
	return scope:New("Frame")({
		Name = "ChatGradientsContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 40),
				PaddingRight = UDim.new(0, 40),
				PaddingTop = UDim.new(0, 20),
				PaddingBottom = UDim.new(0, 20),
			}),

			scope:New("TextLabel")({
				Name = "Placeholder",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "Chat Gradients content coming soon",
				TextColor3 = Theme.Foreground.Muted,
				TextSize = 16,
				Font = Theme.Text.Bold,
			}),
		},
	})
end

return ChatGradientsPage
