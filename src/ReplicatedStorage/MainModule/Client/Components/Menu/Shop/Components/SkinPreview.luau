--!native
--!optimize 2

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

local PriceCache = require(script.Parent.Parent.Cache.PriceCache)
local SkinModelCache = require(script.Parent.Parent.Cache.SkinModelCache)
local GunViewportFactory = require(MainModule.Client.Utils.GunViewportFactory)
local PurchaseRedirectController = require(script.Parent.Parent.PurchaseRedirectController)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>

local ROTATION_SENSITIVITY = 0.3
local FLOAT_PRIMARY_SPEED = 0.4
local FLOAT_SECONDARY_SPEED = 0.7
local FLOAT_TERTIARY_SPEED = 1.1
local FLOAT_AMPLITUDE = 0.004

local COLOR_CLR_SEQ_2 = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 140, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 120, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 100, 180)),
})
local COLOR_CLR_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 210, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 190, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 70)),
})

type InteractiveViewportResult = {
	viewport: ViewportFrame,
	model: Model?,
	cameraDistance: number,
}

local function createInteractiveGunViewport(
	scope: FusionScope,
	skinId: string,
	rotationCFrame: FusionValue<CFrame>,
	floatOffset: FusionValue<number>
): InteractiveViewportResult
	local model = SkinModelCache.getModel(skinId, "H-82")
	if not model then
		local emptyViewport = Instance.new("ViewportFrame")
		emptyViewport.Name = "InteractiveGunViewport"
		emptyViewport.Size = UDim2.fromScale(1, 1)
		emptyViewport.BackgroundTransparency = 1
		return { viewport = emptyViewport, model = nil, cameraDistance = 1 }
	end

	local viewport, clonedModel, cameraDistance = GunViewportFactory.create(model, {
		fov = 45,
		distanceMultiplier = 0.85,
		ambient = Color3.fromRGB(140, 140, 150),
		lightDirection = Vector3.new(-0.4, -0.7, -0.5),
	})
	viewport.Name = "InteractiveGunViewport"

	local modelRef = clonedModel
	local function updateModelRotation()
		if not modelRef or not modelRef.Parent then
			return
		end
		local userRotation = Fusion.peek(rotationCFrame)
		local floatY = Fusion.peek(floatOffset)
		local baseCFrame = CFrame.Angles(0, -math.pi / 2, 0)
		local floatTranslation = CFrame.new(0, floatY, 0)
		modelRef:PivotTo(floatTranslation * userRotation * baseCFrame)
	end

	local rotationObserver = scope:Observer(rotationCFrame)
	local floatObserver = scope:Observer(floatOffset)
	rotationObserver:onChange(updateModelRotation)
	floatObserver:onChange(updateModelRotation)

	return {
		viewport = viewport,
		model = clonedModel,
		cameraDistance = cameraDistance,
	}
end

export type SkinPreviewProps = {
	SkinId: string,
	SkinName: string,
	GamepassId: number,
	OnBack: () -> (),
}

local function SkinPreview(scope: FusionScope, props: SkinPreviewProps): Frame
	local isButtonHovered = scope:Value(false)
	local price = scope:Value(0)

	local isDragging = scope:Value(false)
	local isAnimatingBack = scope:Value(false)
	local rotationCFrame = scope:Value(CFrame.identity)
	local lastMousePosition = scope:Value(Vector2.zero)
	local floatOffset = scope:Value(0)

	PriceCache.getPriceAsync(props.GamepassId, price)

	local buttonScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isButtonHovered) then 1.02 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	local uiTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isDragging) or use(isAnimatingBack) then 1 else 0
	end)

	local priceText = scope:Computed(function(use: FusionUseFn)
		local p = use(price)
		if p == -1 then
			return "OWNED"
		elseif p > 0 then
			return tostring(p) .. " R$"
		else
			return "..."
		end
	end)

	local function promptPurchase()
		PurchaseRedirectController.promptPurchase(props.GamepassId)
	end

	local inputConnection: RBXScriptConnection? = nil
	local inputEndConnection: RBXScriptConnection? = nil
	local snapBackConnection: RBXScriptConnection? = nil

	local function cleanupDragConnections()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		if inputEndConnection then
			inputEndConnection:Disconnect()
			inputEndConnection = nil
		end
		if snapBackConnection then
			snapBackConnection:Disconnect()
			snapBackConnection = nil
		end
	end

	local function startDrag(initialPosition: Vector2)
		isDragging:set(true)
		lastMousePosition:set(initialPosition)
		cleanupDragConnections()

		inputConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local currentPos = Vector2.new(input.Position.X, input.Position.Y)
				local lastPos = Fusion.peek(lastMousePosition)
				local delta = currentPos - lastPos

				local yawAngle = math.rad(delta.X * ROTATION_SENSITIVITY)
				local pitchAngle = math.rad(delta.Y * ROTATION_SENSITIVITY)

				local yawIncrement = CFrame.Angles(0, yawAngle, 0)
				local pitchIncrement = CFrame.Angles(pitchAngle, 0, 0)

				local currentRotation = Fusion.peek(rotationCFrame)
				local newRotation = yawIncrement * pitchIncrement * currentRotation

				rotationCFrame:set(newRotation)
				lastMousePosition:set(currentPos)
			end
		end)

		inputEndConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isDragging:set(false)
				cleanupDragConnections()

				local startRotation = Fusion.peek(rotationCFrame)
				if startRotation == CFrame.identity then
					return
				end

				isAnimatingBack:set(true)
				local animationStart = os.clock()
				local animationDuration = 0.3

				if snapBackConnection then
					snapBackConnection:Disconnect()
				end
				snapBackConnection = RunService.RenderStepped:Connect(function()
					local elapsed = os.clock() - animationStart
					local alpha = math.min(elapsed / animationDuration, 1)
					local easedAlpha = 1 - math.pow(1 - alpha, 3)

					local currentRotation = startRotation:Lerp(CFrame.identity, easedAlpha)
					rotationCFrame:set(currentRotation)

					if alpha >= 1 then
						rotationCFrame:set(CFrame.identity)
						isAnimatingBack:set(false)
						if snapBackConnection then
							snapBackConnection:Disconnect()
							snapBackConnection = nil
						end
					end
				end)
			end
		end)
	end

	table.insert(scope, cleanupDragConnections)

	local floatConnection = RunService.RenderStepped:Connect(function()
		if not Fusion.peek(isDragging) then
			local time = os.clock()
			local primary = math.sin(time * FLOAT_PRIMARY_SPEED * math.pi * 2) * FLOAT_AMPLITUDE
			local secondary = math.sin(time * FLOAT_SECONDARY_SPEED * math.pi * 2) * FLOAT_AMPLITUDE * 0.5
			local tertiary = math.sin(time * FLOAT_TERTIARY_SPEED * math.pi * 2) * FLOAT_AMPLITUDE * 0.3
			local offset = primary + secondary + tertiary
			floatOffset:set(offset)
		end
	end)

	table.insert(scope, function()
		floatConnection:Disconnect()
	end)

	local viewportResult = createInteractiveGunViewport(scope, props.SkinId, rotationCFrame, floatOffset)

	return scope:New("Frame")({
		Name = "SkinPreview",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 100),
				Position = UDim2.new(0.5, 0, 0, 20),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				GroupTransparency = uiTransparency,
				ZIndex = 100,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "SkinName",
						Size = UDim2.new(1, 0, 0, 50),
						Position = UDim2.fromScale(0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = string.upper(props.SkinName),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 42,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),

					scope:New("TextLabel")({
						Name = "Price",
						Size = UDim2.new(1, 0, 0, 32),
						Position = UDim2.new(0.5, 0, 0, 52),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = priceText,
						TextColor3 = Color3.fromRGB(0, 200, 100),
						TextSize = 26,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ViewportContainer",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					viewportResult.viewport,

					scope:New("TextButton")({
						Name = "InteractionHitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,

						[Fusion.OnEvent("MouseButton1Down")] = function()
							local mouse = UserInputService:GetMouseLocation()
							startDrag(Vector2.new(mouse.X, mouse.Y))
						end,
					}),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "Footer",
				Size = UDim2.fromOffset(480, 70),
				Position = UDim2.new(0.5, 0, 1, -70),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				GroupTransparency = uiTransparency,
				ZIndex = 100,

				[Fusion.Children] = {
					scope:New("TextButton")({
						Name = "BackButton",
						Size = UDim2.fromOffset(140, 50),
						Position = UDim2.fromScale(0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = Color3.fromRGB(50, 120, 200),
						Text = "",

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({
								Color = Color3.fromRGB(80, 150, 230),
								Thickness = 2,
								Transparency = 0.2,
							}),

							scope:New("UIGradient")({
								Color = COLOR_CLR_SEQ_2,
								Rotation = 90,
							}),

							scope:New("TextLabel")({
								Name = "Label",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "< BACK",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 18,
								Font = Enum.Font.GothamBold,
							}),
						},

						[Fusion.OnEvent("Activated")] = props.OnBack,
					}),

					scope:New("Frame")({
						Name = "ButtonContainer",
						Size = UDim2.fromOffset(320, 50),
						Position = UDim2.fromScale(1, 0.5),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,

						[Fusion.Children] = {
							scope:New("UIScale")({ Scale = buttonScale }),

							scope:New("TextButton")({
								Name = "PurchaseButton",
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = Color3.fromRGB(45, 180, 80),
								Text = "",

								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(80, 220, 120),
										Thickness = 2,
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
										Text = "PURCHASE SKIN",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 18,
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
					}),
				},
			}),
		},
	})
end

return SkinPreview
