--!strict

local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local Types = require(MainModule.Shared.Types)
local Constants = require(script.Parent.Constants)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionUseFn = Types.FusionUseFn

local peek = Fusion.peek

local SIDEBAR_ITEM_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.6, 0.6, 0.6)),
})

local SCROLL_TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

export type Props = {
	Index: number,
	Name: string,
	IsPreview: boolean?,
	ActiveSectionIndex: FusionValue<number>,
	SectionPositions: FusionValue<{ [number]: number }>,
	GetScrollFrame: () -> ScrollingFrame?,
	CategoryCount: number,
}

local function SidebarItem(scope: FusionScope, props: Props): Frame
	local isActive = scope:Computed(function(use: FusionUseFn)
		if props.IsPreview then
			return use(props.ActiveSectionIndex) == props.CategoryCount + 1
		end
		return use(props.ActiveSectionIndex) == props.Index
	end)

	local isHovered = scope:Value(false)

	local accentColor = if props.IsPreview
		then Theme.Settings.Sidebar.PreviewAccent
		else Theme.Settings.Sidebar.Accent

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isActive) then return 0.8
			elseif use(isHovered) then return 0.88
			end
			return 1
		end),
		Constants.SPRING_SPEED,
		Constants.SMOOTH_DAMPING
	)

	local textColor = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isActive) then
				return Theme.Settings.Sidebar.ItemTextSelected
			elseif use(isHovered) then
				return Theme.Settings.Sidebar.ItemTextHover
			end
			return Theme.Settings.Sidebar.ItemText
		end),
		Constants.SPRING_SPEED,
		Constants.SMOOTH_DAMPING
	)

	local xOffset = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isActive) or use(isHovered) then 4 else 0
		end),
		Constants.SPRING_SPEED,
		Constants.SMOOTH_DAMPING
	)

	return scope:New("Frame")({
		Name = props.Name,
		Size = UDim2.new(1, 0, 0, Theme.Settings.Sidebar.ItemHeight),
		BackgroundTransparency = 1,
		LayoutOrder = props.Index,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Background",
				Size = UDim2.fromScale(1, 1),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(use(xOffset), 0)
				end),
				BackgroundColor3 = accentColor,
				BackgroundTransparency = bgTransparency,
				BorderSizePixel = 0,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 4),
					}),

					scope:New("UIGradient")({
						Color = SIDEBAR_ITEM_GRADIENT,
						Rotation = 90,
					}),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isActive) then return accentColor
								elseif use(isHovered) then return Color3.fromRGB(70, 70, 75)
								end
								return Color3.fromRGB(50, 50, 55)
							end),
							Constants.SPRING_SPEED,
							Constants.SMOOTH_DAMPING
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isActive) then return 0.1
								elseif use(isHovered) then return 0.5
								end
								return 1
							end),
							Constants.SPRING_SPEED,
							Constants.SMOOTH_DAMPING
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 2,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.new(1, -16, 1, 0),
				Position = scope:Computed(function(use: FusionUseFn)
					return UDim2.fromOffset(10 + use(xOffset), 0)
				end),
				BackgroundTransparency = 1,
				Text = string.upper(props.Name),
				TextColor3 = textColor,
				TextSize = 12,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 3,
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,

				[Fusion.OnEvent("Activated")] = function()
					local scrollFrame = props.GetScrollFrame()
					if not scrollFrame then return end

					local positions = peek(props.SectionPositions)
					local targetPos = positions[props.Index]

					if props.IsPreview then
						targetPos = positions[props.CategoryCount + 1]
					end

					if targetPos then
						local viewportHeight = scrollFrame.AbsoluteSize.Y
						local canvasHeight = scrollFrame.AbsoluteCanvasSize.Y
						local maxScroll = math.max(0, canvasHeight - viewportHeight)

						local lastSectionPos = 0
						for i = props.CategoryCount, 1, -1 do
							if positions[i] then
								lastSectionPos = positions[i]
								break
							end
						end

						local targetY = math.max(0, targetPos - 10)
						local hasUnreachableSections = lastSectionPos > maxScroll and maxScroll > 0
						if hasUnreachableSections and lastSectionPos > 0 then
							targetY = ((targetPos + 40) / lastSectionPos) * maxScroll
							targetY = math.clamp(targetY, 0, maxScroll)
						end

						local scrollValue = Instance.new("NumberValue")
						scrollValue.Value = scrollFrame.CanvasPosition.Y

						local tween = TweenService:Create(scrollValue, SCROLL_TWEEN_INFO, {
							Value = targetY
						})

						scrollValue:GetPropertyChangedSignal("Value"):Connect(function()
							if scrollFrame then
								scrollFrame.CanvasPosition = Vector2.new(0, scrollValue.Value)
							end
						end)

						tween.Completed:Once(function()
							scrollValue:Destroy()
						end)

						tween:Play()
					end
				end,
			}),
		},
	})
end

return SidebarItem
