--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Section = require(script.Parent.Section)
local Row = require(script.Parent.Row)
local ExpandableRow = require(script.Parent.ExpandableRow)
local CursorHistoryRow = require(script.Parent.CursorHistoryRow)
local CursorHistoryGridRow = require(script.Parent.CursorHistoryGridRow)
local SearchEngine = require(script.Parent.SearchEngine)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Signal = require(MainModule.Shared.Utils.State.Signal)

local MenuContent = {}

local KEYBIND_GRADIENT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.95, 0.95, 0.95)),
})

local function formatLabel(settingDef: any): string
	return settingDef.label or settingDef.key
end

export type CursorHistoryCallbacks = {
	OnEquip: ((cursorId: number) -> ())?,
	OnToggleRadial: ((cursorId: number) -> ())?,
}

function MenuContent.createSettingsContent(
	scope: FusionScope,
	settings: SettingsConfig.SettingsTemplate,
	onSettingChange: ((string, any) -> ())?,
	searchFilter: FusionCanBeState<string>?,
	cursorHistoryCallbacks: CursorHistoryCallbacks?,
	restrictedSettings: { [string]: FusionCanBeState<boolean> }?,
	settingChanged: Signal.Signal<string, any>?
): { Frame }
	local allSections: { Frame } = {}
	local settingStates: { [string]: FusionValue<any> } = {}

	for categoryIndex, category in SettingsConfig.Categories do
		local rows: { Frame } = {}

		local sectionBestScore = scope:Computed(function(use: FusionUseFn)
			if not searchFilter then return 1000 end
			local query = use(searchFilter)
			if query == "" then return 1000 end

			local bestScore = 0
			for _, settingDef in category.settings do
				local label = formatLabel(settingDef)
				local score = SearchEngine.score(query, label, settingDef.description or "", settingDef.key)
				if score > bestScore then
					bestScore = score
				end

				if settingDef.children then
					for _, childDef in settingDef.children do
						local childLabel = formatLabel(childDef)
						local childScore = SearchEngine.score(query, childLabel, childDef.description or "", childDef.key)
						if childScore > bestScore then
							bestScore = childScore
						end
					end
				end
			end
			return bestScore
		end)

		for _, settingDef in category.settings do
			local settingKey = settingDef.key
			local settingValue = scope:Value(settings.Settings[settingKey])
			settingStates[settingKey] = settingValue

			local row: Frame

			if settingDef.type == "CursorHistoryInput" then
				row = CursorHistoryRow(scope, {
					Label = formatLabel(settingDef),
					Description = settingDef.description,
					Value = settingValue :: FusionCanBeState<number>,
					LayoutOrder = settingDef.order,
					SearchFilter = searchFilter,
					SettingKey = settingKey,
					OnChange = function(newValue: number)
						settingValue:set(newValue)
						if onSettingChange then
							onSettingChange(settingKey, newValue)
						end
					end,
				})
			elseif settingDef.type == "CursorHistoryGrid" then
				local cursorService = ServiceLocator.Cursor()
				local historyValue = if cursorService and cursorService.GetHistoryValue
					then cursorService:GetHistoryValue()
					else scope:Value(settings.Settings.CustomCursorHistory or {})
				local radialValue = if cursorService and cursorService.GetRadialCursorsValue
					then cursorService:GetRadialCursorsValue()
					else scope:Value(settings.Settings.RadialCursors or {})

				row = CursorHistoryGridRow(scope, {
					Label = formatLabel(settingDef),
					Description = settingDef.description,
					History = historyValue,
					RadialCursors = radialValue,
					LayoutOrder = settingDef.order,
					SearchFilter = searchFilter,
					SettingKey = settingKey,
					OnEquip = if cursorHistoryCallbacks then cursorHistoryCallbacks.OnEquip else nil,
					OnToggleRadial = if cursorHistoryCallbacks then cursorHistoryCallbacks.OnToggleRadial else nil,
				})
			elseif settingDef.type == "Expandable" and settingDef.children then
				local childValues: { [string]: FusionCanBeState<any> } = {}
				for _, childDef in settingDef.children do
					local childState = scope:Value(settings.Settings[childDef.key])
					childValues[childDef.key] = childState
					settingStates[childDef.key] = childState
				end

				row = ExpandableRow(scope, {
					Label = formatLabel(settingDef),
					Description = settingDef.description,
					Value = settingValue :: FusionCanBeState<boolean>,
					Children = settingDef.children,
					ChildValues = childValues,
					LayoutOrder = settingDef.order,
					Toggleable = settingDef.toggleable,
					SearchFilter = searchFilter,
					SettingKey = settingKey,
					OnChange = function(newValue: boolean)
						settingValue:set(newValue)
						if onSettingChange then
							onSettingChange(settingKey, newValue)
						end
					end,
					OnChildChange = function(childKey: string, newValue: any)
						local childState = childValues[childKey]
						if childState then
							(childState :: any):set(newValue)
						end
						if onSettingChange then
							onSettingChange(childKey, newValue)
						end
					end,
				})
			else
				row = Row(scope, {
					Label = formatLabel(settingDef),
					Description = settingDef.description,
					ControlType = settingDef.type :: any,
					Value = settingValue,
					Options = settingDef.options,
					Min = settingDef.min,
					Max = settingDef.max,
					Step = settingDef.step,
					LayoutOrder = settingDef.order,
					SearchFilter = searchFilter,
					SettingKey = settingKey,
					Restricted = if restrictedSettings then restrictedSettings[settingKey] else nil,
					OnChange = function(newValue: any)
						settingValue:set(newValue)
						if onSettingChange then
							onSettingChange(settingKey, newValue)
						end
					end,
				})
			end

			table.insert(rows, row)
		end

		local section = Section(scope, {
			Title = category.name,
			Children = rows,
			LayoutOrder = categoryIndex,
			SearchFilter = searchFilter,
			BestScore = sectionBestScore,
		})

		table.insert(allSections, section)
	end

	if settingChanged then
		local settingConnection = settingChanged:Connect(function(key: string, value: any)
			local state = settingStates[key]
			if state then
				state:set(value)
			end
		end)
		table.insert(scope, function()
			settingConnection:Disconnect()
		end)
	end

	return allSections
end

function MenuContent.createKeybindsContent(
	scope: FusionScope,
	settings: SettingsConfig.SettingsTemplate,
	keybindStates: { [string]: FusionValue<string> },
	onKeybindClick: (string, FusionValue<string>) -> ()
): { Frame }
	local rows: { Frame } = {}
	local order = 1

	for keybindName, keybindValue in settings.Keybinds do
		local keybindState = keybindStates[keybindName]
		if not keybindState then
			keybindState = scope:Value(keybindValue)
			keybindStates[keybindName] = keybindState
		end

		local description = SettingsConfig.KeybindDescriptions[keybindName] or ""
		local keybindLabel = string.upper(keybindName:gsub("(%l)(%u)", "%1 %2"))
		local descriptionUpper = string.upper(description)
		local isHovered = scope:Value(false)

		local rowColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(isHovered) then
					return Theme.Background.Overlay
				end
				return Theme.Background.Elevated
			end),
			Theme.Spring.Default.Speed
		)

		local row = scope:New("Frame")({
			Name = keybindName,
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = rowColor,
			BorderSizePixel = 0,
			LayoutOrder = order,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Medium,
				}),

				scope:New("UIGradient")({
					Color = KEYBIND_GRADIENT_SEQUENCE,
					Rotation = 90,
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
				}),

				scope:New("TextLabel")({
					Name = "Label",
					Size = UDim2.fromScale(0.5, 0.5),
					Position = UDim2.fromScale(0, 0.1),
					BackgroundTransparency = 1,
					Text = keybindLabel,
					TextColor3 = Theme.Foreground.Secondary,
					TextSize = Theme.Text.Large,
					Font = Theme.Text.Bold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				scope:New("TextLabel")({
					Name = "Description",
					Size = UDim2.fromScale(0.65, 0.4),
					Position = UDim2.fromScale(0, 0.52),
					BackgroundTransparency = 1,
					Text = descriptionUpper,
					TextColor3 = Theme.Foreground.Disabled,
					TextSize = Theme.Text.Small,
					Font = Theme.Text.Regular,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),

				scope:New("Frame")({
					Name = "KeyDisplay",
					Size = UDim2.fromOffset(100, 36),
					Position = UDim2.fromScale(1, 0.5),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Theme.Background.Secondary,
					BorderSizePixel = 0,

					[Fusion.Children] = {
						scope:New("UICorner")({
							CornerRadius = Theme.Radius.Medium,
						}),

						scope:New("UIStroke")({
							Color = Theme.Border.Default,
							Thickness = 1,
							Transparency = Theme.Stroke.Default,
						}),

						scope:New("TextLabel")({
							Name = "KeyText",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = keybindState,
							TextColor3 = Theme.Foreground.Tertiary,
							TextSize = Theme.Text.Large,
							Font = Theme.Text.Bold,
						}),
					},
				}),

				scope:New("TextButton")({
					Name = "Hitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",

					[Fusion.OnEvent("MouseEnter")] = function()
						isHovered:set(true)
					end,

					[Fusion.OnEvent("MouseLeave")] = function()
						isHovered:set(false)
					end,

					[Fusion.OnEvent("Activated")] = function()
						onKeybindClick(keybindName, keybindState)
					end,
				}),
			},
		})

		table.insert(rows, row)
		order = order + 1
	end

	return rows
end

function MenuContent.createRulesContent(scope: FusionScope): { Frame }
	local rows: { Frame } = {}

	for i, rule in SettingsConfig.Rules do
		local ruleName = `Rule{i}`
		local ruleNumber = `{i}`
		local row = scope:New("Frame")({
			Name = ruleName,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = Theme.Background.Elevated,
			BorderSizePixel = 0,
			LayoutOrder = i,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = Theme.Radius.Medium,
				}),

				scope:New("UIGradient")({
					Color = KEYBIND_GRADIENT_SEQUENCE,
					Rotation = 90,
				}),

				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
				}),

				scope:New("Frame")({
					Name = "NumberBadge",
					Size = UDim2.fromOffset(36, 36),
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme.Colors.Destructive,
					BorderSizePixel = 0,

					[Fusion.Children] = {
						scope:New("UICorner")({
							CornerRadius = Theme.Radius.Medium,
						}),

						scope:New("TextLabel")({
							Name = "Number",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = ruleNumber,
							TextColor3 = Theme.Foreground.Primary,
							TextSize = Theme.Text.Large,
							Font = Theme.Text.Bold,
						}),
					},
				}),

				scope:New("TextLabel")({
					Name = "RuleText",
					Size = UDim2.new(1, -56, 1, 0),
					Position = UDim2.fromOffset(50, 0),
					BackgroundTransparency = 1,
					Text = rule,
					TextColor3 = Theme.Foreground.Tertiary,
					TextSize = Theme.Text.Large,
					Font = Theme.Text.Semibold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
			},
		})

		table.insert(rows, row)
	end

	return rows
end

return MenuContent
