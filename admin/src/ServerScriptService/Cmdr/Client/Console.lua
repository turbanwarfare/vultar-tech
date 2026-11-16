local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BACKGROUND = Color3.fromRGB(8, 8, 8)
local BACKGROUND_TRANSPARENCY = 0.35
local ROW_SELECTED = Color3.fromRGB(32, 32, 32)
local ROW_SELECTED_TRANSPARENCY = 0.2
local DIVIDER = Color3.fromRGB(75, 73, 75)
local DIVIDER_TRANSPARENCY = 0.5
local SCROLLBAR = Color3.fromRGB(40, 40, 40)
local BORDER = Color3.fromRGB(75, 73, 75)
local ACCENT = Color3.fromRGB(220, 220, 235)
local BADGE_TEXT = Color3.fromRGB(14, 14, 14)
local TEXT = Color3.fromRGB(255, 255, 255)
local TEXT_SECONDARY = Color3.fromRGB(210, 210, 210)
local TEXT_MUTED = Color3.fromRGB(170, 170, 170)
local PLACEHOLDER = Color3.fromRGB(120, 120, 120)
local KEY_TEXT = "FFFFFF"
local WARNING = Color3.fromRGB(255, 165, 0)
local DESTRUCTIVE = Color3.fromRGB(255, 100, 103)
local ERROR_COLORS = { "FF9999", "FF4949", DESTRUCTIVE:ToHex():upper() }

local SANS = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium)
local SANS_BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local SANS_HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local PALETTE_WIDTH = 620
local PALETTE_TOP = 96
local HEADER_HEIGHT = 52
local ROW_HEIGHT = 40
local LIST_MAX_HEIGHT = 300
local FOOTER_HEIGHT = 32
local TOAST_WIDTH = 340
local TOAST_BODY_MAX_HEIGHT = 220
local MAX_TOASTS = 5
local LATE_REPLY_WINDOW = 0.5
local EMPTY_RESULT_GRACE = 0.3

local SPIN = TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
local RICH_TEXT_ESCAPES = { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }

local player = Players.LocalPlayer

type Toast = {
	Frame: Frame,
	Icon: Frame,
	Body: TextLabel,
	Lines: { string },
	Error: boolean,
	Finished: boolean,
	Hovered: boolean,
	Pinned: boolean,
	Spin: Tween?,
}

local function create(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = properties.Parent
	for property, value in properties do
		if property ~= "Parent" then
			instance[property] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function padding(parent: Instance, vertical: number, horizontal: number)
	create("UIPadding", {
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		Parent = parent,
	})
end

local function list(parent: Instance, direction: Enum.FillDirection, gap: number): UIListLayout
	return create("UIListLayout", {
		FillDirection = direction,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = if direction == Enum.FillDirection.Horizontal
			then Enum.VerticalAlignment.Center
			else Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, gap),
		Parent = parent,
	})
end

local function label(properties: { [string]: any }): TextLabel
	properties.BackgroundTransparency = 1
	properties.BorderSizePixel = 0
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", properties)
end

local function escape(text: string): string
	return (text:gsub("[<>&]", RICH_TEXT_ESCAPES))
end

local function isErrorColor(color: any): boolean
	return typeof(color) == "Color3" and table.find(ERROR_COLORS, color:ToHex():upper()) ~= nil
end

local Console = {}

function Console.Init(Cmdr: any)
	local StaffRanks = require(
		Cmdr._replicatedRoot:WaitForChild("Types"):WaitForChild("Permissions"):WaitForChild("StaffRanks")
	)
	local Window = Cmdr._interface.Window
	local AutoComplete = Cmdr._interface.AutoComplete
	local gui = Cmdr.Gui :: ScreenGui

	function Window:UpdateWindowHeight() end

	local palette = gui:WaitForChild("Frame") :: ScrollingFrame
	local paletteLayout = palette:WaitForChild("UIListLayout") :: UIListLayout
	local entry = palette:WaitForChild("Entry") :: Frame
	local textBox = entry:WaitForChild("TextBox") :: TextBox
	local prompt = entry:WaitForChild("TextLabel") :: TextLabel

	palette.AnchorPoint = Vector2.new(0.5, 0)
	palette.Position = UDim2.new(0.5, 0, 0, PALETTE_TOP)
	palette.BackgroundColor3 = BACKGROUND
	palette.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	palette.ScrollBarThickness = 0
	palette.ScrollingEnabled = false
	palette.AutomaticCanvasSize = Enum.AutomaticSize.None
	palette.CanvasSize = UDim2.new()
	palette.ClipsDescendants = true
	local oldPadding = palette:FindFirstChildOfClass("UIPadding")
	if oldPadding then
		oldPadding:Destroy()
	end
	corner(palette, 6)
	create("UIStroke", { Color = BORDER, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = palette })
	create("UISizeConstraint", { MaxSize = Vector2.new(PALETTE_WIDTH, math.huge), Parent = palette })

	local header = create("Frame", {
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = palette,
	})
	padding(header, 0, 16)
	list(header, Enum.FillDirection.Horizontal, 12)
	label({
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = SANS_BOLD,
		TextSize = 15,
		TextColor3 = ACCENT,
		Text = ">_",
		Parent = header,
	})
	label({
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = SANS_HEAVY,
		TextSize = 11,
		TextColor3 = ACCENT,
		Text = "CMDR",
		Parent = header,
	})

	entry.Parent = header
	entry.LayoutOrder = 3
	entry.Size = UDim2.new(0, 0, 0, 32)
	create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = entry })
	prompt.Visible = false
	textBox.Size = UDim2.fromScale(1, 1)
	textBox.FontFace = SANS
	textBox.TextSize = 15
	textBox.TextColor3 = TEXT
	textBox.PlaceholderText = "Type a command"
	textBox.PlaceholderColor3 = PLACEHOLDER

	local badge = label({
		Name = "Rank",
		LayoutOrder = 4,
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = SANS_HEAVY,
		TextSize = 10,
		TextColor3 = BADGE_TEXT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = header,
	})
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = ACCENT
	padding(badge, 0, 7)
	corner(badge, 3)

	local divider = create("Frame", {
		Name = "Divider",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = DIVIDER,
		BackgroundTransparency = DIVIDER_TRANSPARENCY,
		BorderSizePixel = 0,
		Visible = false,
		Parent = palette,
	})

	local suggestions = create("ScrollingFrame", {
		Name = "Suggestions",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = SCROLLBAR,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = palette,
	})
	padding(suggestions, 6, 6)
	local suggestionsLayout = list(suggestions, Enum.FillDirection.Vertical, 2)

	local argument = create("Frame", {
		Name = "Argument",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = suggestions,
	})
	padding(argument, 6, 12)
	list(argument, Enum.FillDirection.Vertical, 3)
	local argumentTitle = label({
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = SANS_BOLD,
		TextSize = 13,
		TextColor3 = TEXT,
		Parent = argument,
	})
	local argumentDescription = label({
		Name = "Description",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = SANS,
		TextSize = 12,
		TextColor3 = TEXT_SECONDARY,
		TextWrapped = true,
		Parent = argument,
	})

	local footer = create("Frame", {
		Name = "Footer",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = palette,
	})
	create("Frame", {
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = DIVIDER,
		BackgroundTransparency = DIVIDER_TRANSPARENCY,
		BorderSizePixel = 0,
		Parent = footer,
	})
	local hints = create("Frame", {
		Name = "Hints",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = footer,
	})
	padding(hints, 0, 16)
	list(hints, Enum.FillDirection.Horizontal, 18)

	local closeKey = Cmdr._activationKeys[1]
	local closeText = if closeKey then UserInputService:GetStringForKeyCode(closeKey) else ""
	if closeText == "" and closeKey then
		closeText = closeKey.Name
	end
	for index, hint in { { "↑ ↓", "SELECT" }, { "TAB", "COMPLETE" }, { "ENTER", "RUN" }, false, { closeText, "CLOSE" } } do
		if not hint then
			local spacer = create("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = hints,
			})
			create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = spacer })
			continue
		end
		label({
			LayoutOrder = index,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = SANS_BOLD,
			TextSize = 10,
			TextColor3 = TEXT_MUTED,
			RichText = true,
			Text = `<font color="#{KEY_TEXT}">{escape(hint[1])}</font>  {hint[2]}`,
			Parent = hints,
		})
	end

	local function updateBadge()
		local level = StaffRanks.GetLevel(player)
		badge.Text = string.upper(StaffRanks.GetName(level))
		badge.Visible = level > 0
	end
	player:GetAttributeChangedSignal(StaffRanks.Attribute):Connect(updateBadge)
	updateBadge()

	local function resizePalette()
		palette.Size = UDim2.new(1, -32, 0, paletteLayout.AbsoluteContentSize.Y)
	end
	paletteLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePalette)
	resizePalette()

	suggestionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		suggestions.Size = UDim2.new(1, 0, 0, math.min(suggestionsLayout.AbsoluteContentSize.Y + 12, LIST_MAX_HEIGHT))
	end)

	local rows: { TextButton } = {}
	local suggestionsShown = false

	local function argumentHint(name: string): string
		local command = Cmdr.Registry:GetCommand(name)
		if not command or type(command.Args) ~= "table" then
			return ""
		end
		local parts = {}
		for _, arg in command.Args do
			if type(arg) == "table" then
				table.insert(parts, if arg.Optional then `[{arg.Name}]` else `<{arg.Name}>`)
			end
		end
		return table.concat(parts, " ")
	end

	local function scrollToSelected()
		local row = rows[AutoComplete.SelectedItem]
		if not row then
			return
		end
		local top = row.AbsolutePosition.Y - suggestions.AbsolutePosition.Y + suggestions.CanvasPosition.Y
		local bottom = top + row.AbsoluteSize.Y
		local view = suggestions.AbsoluteWindowSize.Y
		if top < suggestions.CanvasPosition.Y then
			suggestions.CanvasPosition = Vector2.new(0, math.max(0, top - 6))
		elseif bottom > suggestions.CanvasPosition.Y + view then
			suggestions.CanvasPosition = Vector2.new(0, bottom - view + 6)
		end
	end

	local function updateSelection()
		for index, row in rows do
			row.BackgroundTransparency = if index == AutoComplete.SelectedItem then ROW_SELECTED_TRANSPARENCY else 1
		end
	end

	local function complete(index: number)
		AutoComplete.SelectedItem = index
		Window:_handleTabCompletion()
		textBox:CaptureFocus()
		textBox.CursorPosition = #textBox.Text + 1
	end

	local function createRow(index: number, item: any, isCommand: boolean): TextButton
		local row = create("TextButton", {
			Name = "Row",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = ROW_SELECTED,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = suggestions,
		})
		corner(row, 4)
		padding(row, 0, 12)
		list(row, Enum.FillDirection.Horizontal, 14)

		local name = item[2]
		label({
			Name = "Name",
			LayoutOrder = 1,
			Size = if isCommand then UDim2.new(0, 110, 1, 0) else UDim2.fromScale(1, 1),
			FontFace = SANS_BOLD,
			TextSize = 13,
			TextColor3 = TEXT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = name,
			Parent = row,
		})

		if isCommand then
			local options = item.options or {}
			local isAlias = options.name and name:lower() ~= options.name:lower()
			local description = label({
				Name = "Description",
				LayoutOrder = 2,
				Size = UDim2.new(0, 0, 1, 0),
				FontFace = SANS,
				TextSize = 12,
				TextColor3 = TEXT_SECONDARY,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = if isAlias then `Alias of {options.name}` else options.description or "",
				Parent = row,
			})
			create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = description })
			label({
				Name = "Arguments",
				LayoutOrder = 3,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				FontFace = SANS,
				TextSize = 11,
				TextColor3 = TEXT_MUTED,
				Text = argumentHint(name),
				Parent = row,
			})
		end

		row.MouseEnter:Connect(function()
			AutoComplete.SelectedItem = index
			updateSelection()
		end)
		row.Activated:Connect(function()
			complete(index)
		end)
		return row
	end

	local function setSuggestionsVisible(visible: boolean)
		suggestionsShown = visible
		suggestions.Visible = visible
		divider.Visible = visible
	end

	function AutoComplete:Show(items: any, options: any)
		options = options or {}

		self.SelectedItem = 1
		self.Items = items
		self.Prefix = options.prefix or ""
		self.LastItem = options.isLast or false
		self.Command = options.command
		self.Arg = options.arg
		self.NumArgs = options.numArgs
		self.IsPartial = options.isPartial

		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)

		local isCommand = options.command == nil
		for index, item in items do
			rows[index] = createRow(index, item, isCommand)
		end

		argument.Visible = options.name ~= nil
		if options.name then
			local typeName = options.type and `{options.type:sub(1, 1):upper()}{options.type:sub(2)}`
			argumentTitle.Text = if typeName then `{options.name}: {typeName}` else options.name
			argumentDescription.Text = options.description or ""
			argumentDescription.Visible = argumentDescription.Text ~= ""
			argumentDescription.TextColor3 = if options.invalid then DESTRUCTIVE else TEXT_SECONDARY
		end

		updateSelection()
		suggestions.CanvasPosition = Vector2.zero
		setSuggestionsVisible(#items > 0 or options.name ~= nil)
	end

	function AutoComplete:GetSelectedItem()
		if not suggestionsShown then
			return nil
		end
		return self.Items[self.SelectedItem]
	end

	function AutoComplete:Hide()
		setSuggestionsVisible(false)
	end

	function AutoComplete:IsVisible(): boolean
		return suggestionsShown
	end

	function AutoComplete:Select(delta: number)
		if not suggestionsShown or #self.Items == 0 then
			return
		end
		self.SelectedItem += delta
		if self.SelectedItem > #self.Items then
			self.SelectedItem = 1
		elseif self.SelectedItem < 1 then
			self.SelectedItem = #self.Items
		end
		updateSelection()
		scrollToSelected()
	end

	function AutoComplete:_updateContainerPosition() end

	local toastHolder = create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, TOAST_WIDTH, 1, -32),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local toastLayout = list(toastHolder, Enum.FillDirection.Vertical, 8)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local toasts: { Toast } = {}
	local toastOrder = 0
	local running: Toast? = nil
	local lingering: Toast? = nil
	local lingerUntil = 0

	local function removeToast(toast: Toast)
		local index = table.find(toasts, toast)
		if index then
			table.remove(toasts, index)
		end
		if toast.Spin then
			toast.Spin:Cancel()
		end
		toast.Frame:Destroy()
	end

	local function scheduleRemoval(toast: Toast, delay: number)
		task.delay(delay, function()
			if toast.Frame.Parent and not toast.Hovered and not toast.Pinned then
				removeToast(toast)
			end
		end)
	end

	local function createToast(command: string?): Toast
		toastOrder += 1
		local frame = create("Frame", {
			Name = "Toast",
			LayoutOrder = toastOrder,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = BACKGROUND,
			BackgroundTransparency = BACKGROUND_TRANSPARENCY,
			BorderSizePixel = 0,
			Parent = toastHolder,
		})
		corner(frame, 4)
		create("UIStroke", { Color = BORDER, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
		padding(frame, 10, 12)
		local layout = list(frame, Enum.FillDirection.Horizontal, 10)
		layout.VerticalAlignment = Enum.VerticalAlignment.Top

		local icon = create("Frame", {
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		local ring = create("Frame", {
			Name = "Spinner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1,
			Parent = icon,
		})
		corner(ring, 6)
		local stroke = create("UIStroke", { Color = WARNING, Thickness = 2, Parent = ring })
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.51, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = stroke,
		})
		local spin = TweenService:Create(ring, SPIN, { Rotation = 360 })
		spin:Play()

		local content = create("Frame", {
			Name = "Content",
			LayoutOrder = 2,
			Size = UDim2.new(1, -26, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = frame,
		})
		list(content, Enum.FillDirection.Vertical, 2)

		if command then
			label({
				Name = "Command",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				FontFace = SANS,
				TextSize = 11,
				TextColor3 = TEXT_MUTED,
				TextWrapped = true,
				Text = command,
				Parent = content,
			})
		end

		local scroller = create("ScrollingFrame", {
			Name = "Body",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = SCROLLBAR,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = content,
		})
		local body = label({
			Name = "Text",
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = SANS,
			TextSize = 13,
			TextColor3 = TEXT_SECONDARY,
			TextWrapped = true,
			RichText = true,
			Text = "",
			Parent = scroller,
		})
		local close = create("TextButton", {
			Name = "Close",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			FontFace = SANS_BOLD,
			TextSize = 16,
			TextColor3 = TEXT_MUTED,
			Text = "×",
			Visible = false,
			Parent = frame,
		})

		local toast: Toast = {
			Frame = frame,
			Icon = icon,
			Body = body,
			Lines = {},
			Error = false,
			Finished = false,
			Hovered = false,
			Pinned = false,
			Spin = spin,
		}

		body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			scroller.Size = UDim2.new(1, 0, 0, math.min(body.AbsoluteSize.Y, TOAST_BODY_MAX_HEIGHT))
			if body.AbsoluteSize.Y > TOAST_BODY_MAX_HEIGHT and not toast.Pinned then
				toast.Pinned = true
				close.Visible = true
				content.Size = UDim2.new(1, -52, 0, 0)
			end
		end)
		close.MouseEnter:Connect(function()
			close.TextColor3 = TEXT
		end)
		close.MouseLeave:Connect(function()
			close.TextColor3 = TEXT_MUTED
		end)
		close.Activated:Connect(function()
			removeToast(toast)
		end)

		frame.MouseEnter:Connect(function()
			toast.Hovered = true
		end)
		frame.MouseLeave:Connect(function()
			toast.Hovered = false
			if toast.Finished then
				scheduleRemoval(toast, 2)
			end
		end)

		table.insert(toasts, toast)
		for _, old in table.clone(toasts) do
			if #toasts <= MAX_TOASTS then
				break
			end
			if old.Finished then
				removeToast(old)
			end
		end
		return toast
	end

	local function appendLine(toast: Toast, text: string, options: { [string]: any })
		local line = Cmdr.Util.EmulateTabstops(text, 8)
		if not options.RichText then
			line = escape(line)
		end
		if typeof(options.Color) == "Color3" then
			line = `<font color="#{options.Color:ToHex()}">{line}</font>`
		end
		if isErrorColor(options.Color) then
			toast.Error = true
		end
		table.insert(toast.Lines, line)
		toast.Body.Text = table.concat(toast.Lines, "\n")
		toast.Body.Parent.Visible = true
	end

	local function finishToast(toast: Toast)
		toast.Finished = true
		if toast.Spin then
			toast.Spin:Cancel()
			toast.Spin = nil
		end
		toast.Icon:ClearAllChildren()
		label({
			Name = "Glyph",
			Size = UDim2.fromScale(1, 1),
			FontFace = SANS_BOLD,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if toast.Error then DESTRUCTIVE else ACCENT,
			Text = if toast.Error then "×" else "✓",
			Parent = toast.Icon,
		})
		local length = #toast.Body.ContentText
		scheduleRemoval(toast, math.clamp(4 + length / 40, 4, 15))
	end

	local submitted: string? = nil
	local loseFocus = Window._loseFocus

	function Window:_loseFocus(submit: boolean, cause: InputObject?)
		submitted = if submit then Cmdr.Util.TrimString(self:GetEntryText()) else nil
		loseFocus(self, submit, cause)
		submitted = nil
	end

	function Window:AddLine(text: any, options: any)
		local lineText = tostring(text)
		if lineText == "" then
			return
		end
		local lineOptions = if typeof(options) == "Color3" then { Color = options } else options or {}
		local toast = running
		if not toast and lingering and os.clock() < lingerUntil and lingering.Frame.Parent then
			toast = lingering
		end
		if toast then
			appendLine(toast, lineText, lineOptions)
			if toast.Finished then
				finishToast(toast)
			end
			return
		end

		toast = createToast(if submitted ~= "" then submitted else nil)
		appendLine(toast, lineText, lineOptions)
		finishToast(toast)
	end

	function Window:_processEntry(text: string)
		local trimmed = Cmdr.Util.TrimString(text)
		if #trimmed == 0 then
			return
		end

		local toast = createToast(trimmed)
		running = toast
		local ok, result =
			pcall(Cmdr.Dispatcher.EvaluateAndRun, Cmdr.Dispatcher, trimmed, player, { IsHuman = true })
		if running == toast then
			running = nil
		end
		lingering = toast
		lingerUntil = os.clock() + LATE_REPLY_WINDOW

		if not ok then
			appendLine(toast, tostring(result), { Color = DESTRUCTIVE })
		elseif result ~= nil and tostring(result) ~= "" then
			appendLine(toast, tostring(result), {})
		end

		if #toast.Lines > 0 then
			finishToast(toast)
		else
			task.delay(EMPTY_RESULT_GRACE, function()
				if not toast.Finished then
					finishToast(toast)
				end
			end)
		end
	end
end

return Console
