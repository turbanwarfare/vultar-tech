--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local AnimatedCardService = require(MainModule.Client.Services.AnimatedCardService)

local BundleTypes = require(script.Parent.Types)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type CardBackgroundProps = BundleTypes.CardBackgroundProps

local DEFAULT_GRADIENT_NUM_SEQ =
	NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 0.7) })

local DEFAULT_GRADIENT = DEFAULT_GRADIENT_NUM_SEQ

local function CardBackground(scope: FusionScope, props: CardBackgroundProps): Frame
	local imageId = props.ImageId
	local isAnimated = props.IsAnimated
	local size = props.Size
	local transparency = props.Transparency
	local gradient = props.GradientConfig or DEFAULT_GRADIENT
	local radius = props.CornerRadius or 4

	local registeredContainer: Frame? = nil

	local function cleanup()
		if registeredContainer then
			AnimatedCardService:UnregisterContainer(registeredContainer)
			registeredContainer = nil
		end
	end

	local container = scope:New("Frame")({
		Name = "CardBackgroundContainer",
		Size = size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,

		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),

			scope:New("ImageLabel")({
				Name = "StaticCardBackground",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = imageId,
				ImageTransparency = transparency,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					local img = if typeof(imageId) == "string" then imageId else use(imageId :: any)
					local animated = if typeof(isAnimated) == "boolean" then isAnimated else use(isAnimated :: any)
					return img ~= "" and not animated
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "AnimatedCardContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = 0,
				ZIndex = 1,
				Visible = scope:Computed(function(use: FusionUseFn)
					local img = if typeof(imageId) == "string" then imageId else use(imageId :: any)
					local animated = if typeof(isAnimated) == "boolean" then isAnimated else use(isAnimated :: any)
					return img ~= "" and animated
				end),

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) }),
					scope:New("UIGradient")({
						Transparency = gradient,
						Rotation = 0,
					}),

					scope:New("Frame")({
						Name = "ScrollingFrame",
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(2, 1),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("ImageLabel")({
								Name = "CardImage1",
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(0.5, 1),
								BackgroundTransparency = 1,
								Image = imageId,
								ImageTransparency = transparency,
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 1,
							}),
							scope:New("ImageLabel")({
								Name = "CardImage2",
								Position = UDim2.fromScale(0.5, 0),
								Size = UDim2.fromScale(0.5, 1),
								BackgroundTransparency = 1,
								Image = imageId,
								ImageTransparency = transparency,
								ScaleType = Enum.ScaleType.Crop,
								ZIndex = 1,
							}),
						},
					}),
				},
			}),
		},
	})

	local function updateAnimation()
		local animated = if typeof(isAnimated) == "boolean" then isAnimated else Fusion.peek(isAnimated :: any)
		local img = if typeof(imageId) == "string" then imageId else Fusion.peek(imageId :: any)

		if animated and img ~= "" then
			task.defer(function()
				local animContainer = container:FindFirstChild("AnimatedCardContainer")
				if animContainer and animContainer.Parent then
					if registeredContainer and registeredContainer ~= animContainer then
						AnimatedCardService:UnregisterContainer(registeredContainer)
					end
					AnimatedCardService:RegisterContainer(animContainer :: Frame)
					registeredContainer = animContainer :: Frame
				end
			end)
		elseif registeredContainer then
			AnimatedCardService:UnregisterContainer(registeredContainer)
			registeredContainer = nil
		end
	end

	if typeof(isAnimated) == "table" then
		scope:Observer(isAnimated :: any):onBind(updateAnimation)
	else
		updateAnimation()
	end

	table.insert(scope, cleanup)

	return container :: Frame
end

return CardBackground
