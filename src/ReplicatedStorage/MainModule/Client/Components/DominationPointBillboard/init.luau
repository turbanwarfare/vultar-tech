--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type Owner = "Defenders" | "Hostiles" | nil

export type DominationPointUIState = {
	Label: string,
	Owner: Owner,
	Progress: number,
	ProgressOwner: Owner,
	Contested: boolean,
}

export type DominationPointBillboardProps = {
	State: Types.FusionValue<DominationPointUIState> | any,
	Adornee: BasePart,
	StudsOffset: Vector3?,
}

local DEFENDER_COLOR = Color3.fromRGB(180, 50, 50)
local HOSTILE_COLOR = Color3.fromRGB(50, 110, 200)
local NEUTRAL_COLOR = Color3.fromRGB(70, 72, 80)

local function getBadgeColor(owner: Owner): Color3
	if owner == "Defenders" then return DEFENDER_COLOR end
	if owner == "Hostiles" then return HOSTILE_COLOR end
	return NEUTRAL_COLOR
end

local function DominationPointBillboard(scope: FusionScope, props: DominationPointBillboardProps): BillboardGui
	local labelText = scope:Computed(function(use: FusionUseFn)
		local state = use(props.State) :: DominationPointUIState
		if not state then return "" end
		return state.Label
	end)

	local ownerColor = scope:Computed(function(use: FusionUseFn)
		local state = use(props.State) :: DominationPointUIState
		if not state then return NEUTRAL_COLOR end
		return getBadgeColor(state.Owner)
	end)
	
	local boxColor = scope:Spring(ownerColor, 20, 0.9)

	return scope:New("BillboardGui")({
		Name = "DominationPointBillboard",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(2.5, 2.5),
		StudsOffset = props.StudsOffset or Vector3.new(0, 35, 0),
		AlwaysOnTop = true,
		MaxDistance = 1000,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		LightInfluence = 0,
		[Fusion.Children] = {
			scope:New("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(65, 65),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://107116062425826",
				ImageColor3 = boxColor,
				ImageTransparency = 0.2,
				ScaleType = Enum.ScaleType.Fit,
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "PointLetter",
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, -2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Text = labelText,
						TextColor3 = Theme.Colors.White,
						TextSize = 24,
						Font = Theme.Text.Black,
					}),
				},
			})
		},
	}) :: BillboardGui
end

return DominationPointBillboard
