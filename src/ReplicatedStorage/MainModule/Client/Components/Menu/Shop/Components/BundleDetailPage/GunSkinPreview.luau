--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local SkinModelCache = require(script.Parent.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local BundleTypes = require(script.Parent.Types)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type GunSkinPreviewProps = BundleTypes.GunSkinPreviewProps

local ROTATE_RIGHT_GUNS = {
	["H-41"] = true,
	["H-94"] = true,
	["BR-40"] = true,
	["BR-56"] = true,
	["BR-50"] = true,
	["BR-22"] = true,
	["BR-8"] = true,
	["H-22"] = true,
}

local DISTANCE_OVERRIDES = {
	["H-41"] = 1.05,
	["H-94"] = 1.15,
	["H-22"] = 1.5,
}

local function createGunViewport(skinId: string, gunName: string): ViewportFrame?
	local model = SkinModelCache.getModel(skinId, gunName)
	if not model then
		model = SkinModelCache.getModel("Default", gunName)
	end
	if not model then
		return nil
	end

	local rotY = if ROTATE_RIGHT_GUNS[gunName] then math.pi / 2 else -math.pi / 2
	local rotation = CFrame.Angles(0, rotY, 0)
	local dist = DISTANCE_OVERRIDES[gunName] or 0.75

	local viewport = GunViewportFactory.create(model, {
		fov = 50,
		distanceMultiplier = dist,
		rotation = rotation,
		ambient = Color3.fromRGB(150, 150, 155),
		lightDirection = Vector3.new(-0.4, -0.7, -0.5),
	})
	viewport.Name = "GunViewport_" .. skinId
	return viewport
end

local function GunSkinPreview(scope: FusionScope, props: GunSkinPreviewProps): Frame
	local selectedItem = props.SelectedItem

	return scope:New("Frame")({
		Name = "GunSkinPreview",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = scope:Computed(function(use: FusionUseFn)
			local item = use(selectedItem)
			return item ~= nil and item.type == "GunSkin"
		end),

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextLabel")({
				Name = "SectionLabel",
				Size = UDim2.new(1, 0, 0, 14),
				BackgroundTransparency = 1,
				Text = "GUN PREVIEW",
				TextColor3 = Color3.fromRGB(155, 155, 165),
				TextSize = 10,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			scope:New("Frame")({
				Name = "GunViewportContainer",
				Size = UDim2.new(1, 0, 0, 340),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:Computed(function(use: FusionUseFn)
						local item = use(selectedItem)
						if item and item.type == "GunSkin" and item.skinId and item.gunName then
							return createGunViewport(item.skinId, item.gunName)
						end
						return nil
					end),
				},
			}),
		},
	})
end

return GunSkinPreview
