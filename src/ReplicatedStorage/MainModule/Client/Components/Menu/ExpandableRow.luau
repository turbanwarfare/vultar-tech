--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local SearchEngine = require(script.Parent.SearchEngine)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

local Toggle = require(script.Parent.Toggle)
local Picker = require(script.Parent.Picker)
local Input = require(script.Parent.Input)
local Slider = require(script.Parent.Slider)
local HitmarkerPicker = require(script.Parent.HitmarkerPicker)
local FontPicker = require(script.Parent.FontPicker)

local function formatChildLabel(childDef: any): string
	return childDef.label or childDef.key
end

export type ChildSettingDef = {
	key: string,
	order: number,
	type: string,
	description: string,
	options: { string }?,
	min: number?,
	max: number?,
	step: number?,
	visibleWhen: { [string]: number }?,
}

export type ExpandableRowProps = {
	Label: string,
	Description: string?,
	Value: FusionCanBeState<boolean>,
	Children: { ChildSettingDef },
	ChildValues: { [string]: FusionCanBeState<any> },
	OnChange: ((boolean) -> ())?,
	OnChildChange: ((string, any) -> ())?,
	LayoutOrder: number?,
	Toggleable: boolean?,
	SearchFilter: FusionCanBeState<string>?,
	SettingKey: string?,
}

local function createChildControl(scope: FusionScope, def: ChildSettingDef, value: FusionCanBeState<any>, onChange: ((any) -> ())?): Instance?
	if def.type == "Boolean" then
		return Toggle(scope, {
			Value = value :: FusionCanBeState<boolean>,
			OnChange = onChange :: ((boolean) -> ())?,
		})
	elseif def.type == "Pick" and def.options then
		return Picker(scope, {
			Value = value :: FusionCanBeState<number>,
			Options = def.options,
			OnChange = onChange :: ((number) -> ())?,
		})
	elseif def.type == "Slider" then
		return Slider(scope, {
			Value = value :: FusionCanBeState<number>,
			Min = def.min,
			Max = def.max,
			Step = def.step,
			OnChange = onChange :: ((number) -> ())?,
		})
	elseif def.type == "HitmarkerPick" then
		return HitmarkerPicker(scope, {
			Value = value :: FusionCanBeState<number>,
			OnChange = onChange :: ((number) -> ())?,
		})
	elseif def.type == "FontPick" then
		return FontPicker(scope, {
			Value = value :: FusionCanBeState<string>,
			OnChange = onChange :: ((string) -> ())?,
		})
	elseif def.type == "TypeIn" then
		return Input(scope, {
			Value = value :: FusionCanBeState<number>,
			NumberOnly = true,
			OnSubmit = function(text: string)
				if onChange then
					local num = tonumber(text)
					onChange(num or 0)
				end
			end,
		})
	end
	return nil
end

local function ExpandableRow(scope: FusionScope, props: ExpandableRowProps): Frame
	local isHovered = scope:Value(false)
	local isExpanded = scope:Value(false)
	local hasInputFocus = scope:Value(false)

	local searchScore = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return 1000 end
		local query = use(props.SearchFilter)
		if query == "" then return 1000 end

		local parentScore = SearchEngine.score(query, props.Label, props.Description or "", props.SettingKey)
		local bestChildScore = 0

		for _, childDef in props.Children do
			local childLabel = formatChildLabel(childDef)
			local childScore = SearchEngine.score(query, childLabel, childDef.description or "", childDef.key)
			if childScore > bestChildScore then
				bestChildScore = childScore
			end
		end

		return math.max(parentScore, bestChildScore)
	end)

	local isVisible = scope:Computed(function(use: FusionUseFn)
		return use(searchScore) > 0
	end)

	local dynamicLayoutOrder = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return props.LayoutOrder or 0 end
		local query = use(props.SearchFilter)
		if query == "" then return props.LayoutOrder or 0 end
		local score = use(searchScore)
		return (10000 - score) * 100 + (props.LayoutOrder or 0)
	end)

	local collapsedHeight = 30
	local childRowHeight = 28

	local childVisibilityStates: { [number]: Types.FusionValue<boolean> } = {}
	for i, childDef in props.Children do
		local childIsVisible = scope:Computed(function(use: FusionUseFn)
			if not childDef.visibleWhen then
				return true
			end
			for depKey, requiredValue in childDef.visibleWhen do
				local depState = props.ChildValues[depKey]
				if depState then
					local currentValue = use(depState)
					if currentValue ~= requiredValue then
						return false
					end
				end
			end
			return true
		end)
		childVisibilityStates[i] = childIsVisible
	end

	local visibleChildCount = scope:Computed(function(use: FusionUseFn)
		local count = 0
		for _, visState in childVisibilityStates do
			if use(visState) then
				count += 1
			end
		end
		return count
	end)

	local expandedHeight = scope:Computed(function(use: FusionUseFn)
		return collapsedHeight + (use(visibleChildCount) * (childRowHeight + 4)) + 8
	end)

	local isSearching = scope:Computed(function(use: FusionUseFn)
		if not props.SearchFilter then return false end
		local query = use(props.SearchFilter)
		return query ~= ""
	end)

	local shouldBeExpanded = scope:Computed(function(use: FusionUseFn)
		return use(isHovered) or use(hasInputFocus) or use(isSearching)
	end)

	local borderColor = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then Theme.Border.Active else Theme.Row.Border
	end)

	local borderTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(isHovered) then 0 else Theme.Row.BorderTransparency
	end)

	local currentHeight = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(shouldBeExpanded) then use(expandedHeight) else collapsedHeight
		end),
		Theme.Spring.Snappy.Speed
	)

	local childrenTransparency = scope:Computed(function(use: FusionUseFn)
		return if use(shouldBeExpanded) then 0 else 1
	end)

	local expandIndicatorRotation = scope:Computed(function(use: FusionUseFn)
		return if use(shouldBeExpanded) then 90 else 0
	end)

	local function onMouseEnter()
		isHovered:set(true)
		isExpanded:set(true)
	end

	local function onMouseLeave()
		isHovered:set(false)
		isExpanded:set(false)
	end

	local childRows: { Instance } = {}
	local rowFrame: Frame

	table.sort(props.Children, function(a, b)
		return a.order < b.order
	end)

	for i, childDef in props.Children do
		local childValue = props.ChildValues[childDef.key]
		if not childValue then continue end

		local control = createChildControl(scope, childDef, childValue, function(newValue)
			if props.OnChildChange then
				props.OnChildChange(childDef.key, newValue)
			end
		end)

		if not control then continue end

		local childIsHovered = scope:Value(false)
		local childIsBoolean = childDef.type == "Boolean"
		local childIsVisible = childVisibilityStates[i]
		local childLabelUpper = string.upper(formatChildLabel(childDef))

		local childPosition = scope:Computed(function(use: FusionUseFn)
			local visibleBefore = 0
			for j = 1, i - 1 do
				local visState = childVisibilityStates[j]
				if visState and use(visState) then
					visibleBefore += 1
				end
			end
			return UDim2.fromOffset(8, collapsedHeight + 4 + visibleBefore * (childRowHeight + 4))
		end)

		local childBorderColor = scope:Computed(function(use: FusionUseFn)
			return if use(childIsHovered) then Theme.Border.Active else Theme.Background.Overlay
		end)

		local childBorderTransparency = scope:Computed(function(use: FusionUseFn)
			local baseTransparency = use(childrenTransparency)
			if baseTransparency > 0.5 then return 1 end
			return if use(childIsHovered) then 0 else 1
		end)

		local childRow = scope:New("Frame")({
			Name = childDef.key,
			Size = UDim2.new(1, -16, 0, childRowHeight),
			Position = childPosition,
			BackgroundColor3 = Theme.Background.Overlay,
			BackgroundTransparency = childrenTransparency,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Visible = childIsVisible,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Small,
				}),

				scope:New("UIStroke")({
					Color = childBorderColor,
					Thickness = 1,
					Transparency = childBorderTransparency,
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, Theme.Spacing.Small),
					PaddingRight = UDim.new(0, 8),
				}),

				scope:New("TextLabel")({
					Name = "Label",
					Size = UDim2.fromScale(0.4, 1),
					BackgroundTransparency = 1,
					Text = childLabelUpper,
					TextColor3 = Theme.Foreground.Secondary,
					TextSize = Theme.Text.Small,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTransparency = childrenTransparency,
				}),

				scope:New("Frame")({
					Name = "ControlContainer",
					Size = UDim2.fromScale(0.6, 1),
					Position = UDim2.fromScale(0.4, 0),
					BackgroundTransparency = 1,

					[Fusion.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),

						control,
					},
				}),

				scope:New("TextButton")({
					Name = "ChildHitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 0,

					[Fusion.OnEvent("MouseEnter")] = function()
						childIsHovered:set(true)
					end,

					[Fusion.OnEvent("MouseLeave")] = function()
						childIsHovered:set(false)
					end,

					[Fusion.OnEvent("Activated")] = function()
						if childIsBoolean and props.OnChildChange then
							local currentValue = peek(childValue)
							props.OnChildChange(childDef.key, not currentValue)
						end
					end,
				}),
			},
		})

		table.insert(childRows, childRow)
	end

	rowFrame = scope:New("Frame")({
		Name = props.Label,
		Size = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(1, -24, 0, use(currentHeight) + 4)
		end),
		Position = UDim2.fromOffset(12, 0),
		BackgroundColor3 = Theme.Row.Background,
		BackgroundTransparency = Theme.Row.BackgroundTransparency,
		BorderSizePixel = 0,
		LayoutOrder = dynamicLayoutOrder,
		ClipsDescendants = true,
		Visible = isVisible,

		[Fusion.OnEvent("MouseEnter")] = onMouseEnter,
		[Fusion.OnEvent("MouseLeave")] = onMouseLeave,

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),

			scope:New("UIStroke")({
				Color = borderColor,
				Thickness = 1,
				Transparency = borderTransparency,
			}),

			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Spacing.Medium),
				PaddingRight = UDim.new(0, 10),
			}),

			scope:New("TextLabel")({
				Name = "ExpandIndicator",
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromOffset(-8, 9),
				BackgroundTransparency = 1,
				Text = ">",
				TextColor3 = Theme.Foreground.Subtle,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				Rotation = expandIndicatorRotation,
			}),

			scope:New("TextLabel")({
				Name = "Label",
				Size = UDim2.new(0.45, 0, 0, collapsedHeight),
				Position = UDim2.fromOffset(8, 0),
				BackgroundTransparency = 1,
				Text = string.upper(props.Label),
				TextColor3 = Theme.Foreground.Secondary,
				TextSize = Theme.Text.Medium,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("Frame")({
				Name = "ControlContainer",
				Size = UDim2.new(0.55, 0, 0, collapsedHeight),
				Position = UDim2.fromScale(0.45, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					if props.Toggleable ~= false then Toggle(scope, {
						Value = props.Value,
						OnChange = props.OnChange,
					}) else nil,
				},
			}),

			if props.Toggleable ~= false then scope:New("TextButton")({
				Name = "HeaderHitbox",
				Size = UDim2.new(0.4, 0, 0, collapsedHeight),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 2,

				[Fusion.OnEvent("Activated")] = function()
					if props.OnChange then
						local currentValue = peek(props.Value)
						props.OnChange(not currentValue)
					end
				end,
			}) else nil,

			unpack(childRows),
		},
	})

	local function checkFocusInRow()
		local focused = UserInputService:GetFocusedTextBox()
		if focused and focused:IsDescendantOf(rowFrame) then
			hasInputFocus:set(true)
		else
			hasInputFocus:set(false)
		end
	end

	local textBoxConnections: { RBXScriptConnection } = {}

	local function connectTextBox(textBox: TextBox)
		table.insert(textBoxConnections, textBox.Focused:Connect(checkFocusInRow))
		table.insert(textBoxConnections, textBox.FocusLost:Connect(checkFocusInRow))
	end

	for _, descendant in rowFrame:GetDescendants() do
		if descendant:IsA("TextBox") then
			connectTextBox(descendant)
		end
	end

	local descendantAddedConnection = rowFrame.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("TextBox") then
			connectTextBox(descendant)
		end
	end)
	table.insert(textBoxConnections, descendantAddedConnection)

	table.insert(scope, function()
		for _, conn in textBoxConnections do
			conn:Disconnect()
		end
	end)

	return rowFrame
end

return ExpandableRow
