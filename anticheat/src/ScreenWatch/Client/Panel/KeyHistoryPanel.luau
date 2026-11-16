--!strict
--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

local MAX_VISIBLE_ROWS = 25

local COLOR_SETTINGS_BG = Color3.fromRGB(58, 30, 10)
local COLOR_FOCUS_BG = Color3.fromRGB(48, 40, 14)
local COLOR_FLAGGED_BG = Color3.fromRGB(65, 18, 18)

local COLOR_SETTINGS_TEXT = Color3.fromRGB(255, 150, 45)
local COLOR_FOCUS_TEXT = Color3.fromRGB(245, 195, 65)
local COLOR_FLAGGED_TEXT = Color3.fromRGB(255, 95, 95)
local COLOR_DOWN_STATUS = Color3.fromRGB(60, 200, 120)

export type KeyHistoryEntry = {
	keyName: string,
	isFlagged: boolean,
	isDown: boolean,
	timestamp: number,
	formattedTime: string,
	isFocusEvent: boolean?,
	isSettingsEvent: boolean?,
}

export type KeyHistoryPanelProps = {
	KeyHistory: FusionValue<{ KeyHistoryEntry }>,
	TargetName: FusionValue<string>?,
	TargetUserId: FusionValue<number>?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Visible: FusionValue<boolean>?,
	OnClose: (() -> ())?,
	OnExport: (() -> ())?,
}

local function ExportBtn(
	scope: FusionScope,
	props: {
		OnExport: (() -> ())?,
	}
): TextButton
	local status = scope:Value("idle")

	local btnText = scope:Computed(function(use: FusionUseFn)
		local s = use(status)
		if s == "sent" or s == "success" then
			return "SENT"
		elseif s == "exporting" then
			return "..."
		elseif s == "error" then
			return "ERROR"
		end
		return "EXPORT"
	end)

	local btnTextColor = scope:Computed(function(use: FusionUseFn)
		local s = use(status)
		if s == "sent" or s == "success" then
			return Color3.fromRGB(80, 220, 130)
		elseif s == "exporting" then
			return Theme.Colors.Black[300]
		elseif s == "error" then
			return Theme.Colors.Destructive
		end
		return Theme.Colors.White
	end)

	return scope:New("TextButton")({
		Name = "ExportButton",
		Size = UDim2.fromOffset(56, 22),
		BackgroundColor3 = Theme.Colors.Black[800],
		BorderSizePixel = 0,
		Text = btnText,
		TextColor3 = btnTextColor,
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Bold,
		AutoButtonColor = false,
		LayoutOrder = 1,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
		},
		[Fusion.OnEvent("Activated")] = function()
			if props.OnExport then
				status:set("exporting")
				props.OnExport()
				status:set("sent")
				task.delay(2.5, function()
					status:set("idle")
				end)
			end
		end,
	})
end

type RowSlot = {
	Frame: Frame,
	TimeLabel: TextLabel,
	KeyNameLabel: TextLabel,
	StatusLabel: TextLabel,
}

local function createRow(scope: FusionScope, index: number): RowSlot
	local timeLabel = scope:New("TextLabel")({
		Name = "Time",
		Size = UDim2.new(0, 48, 1, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.Black[400],
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Mono,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local keyNameLabel = scope:New("TextLabel")({
		Name = "KeyName",
		Size = UDim2.new(1, -105, 1, 0),
		Position = UDim2.fromOffset(50, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.White,
		TextSize = Theme.Text.Small,
		Font = Theme.Text.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local statusLabel = scope:New("TextLabel")({
		Name = "Status",
		Size = UDim2.new(0, 48, 1, 0),
		Position = UDim2.new(1, -48, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.Colors.Black[400],
		TextSize = Theme.Text.XSmall,
		Font = Theme.Text.Bold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local frame = scope:New("Frame")({
		Name = "Slot_" .. index,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = index,
		BackgroundColor3 = Theme.Colors.Black[850],
		BorderSizePixel = 0,
		Visible = false,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			timeLabel,
			keyNameLabel,
			statusLabel,
		},
	})

	return {
		Frame = frame,
		TimeLabel = timeLabel,
		KeyNameLabel = keyNameLabel,
		StatusLabel = statusLabel,
	}
end

local function updateRows(rowSlots: { RowSlot }, list: { KeyHistoryEntry })
	for i = 1, MAX_VISIBLE_ROWS do
		local row = rowSlots[i]
		local entry = list[i]
		if entry then
			local isFlagged = entry.isFlagged
			local isFocus = entry.isFocusEvent == true
			local isSettings = entry.isSettingsEvent == true
			local isDown = entry.isDown

			local bgColor = if isSettings
				then COLOR_SETTINGS_BG
				elseif isFocus then COLOR_FOCUS_BG
				elseif isFlagged then COLOR_FLAGGED_BG
				else Theme.Colors.Black[850]

			local textColor = if isSettings
				then COLOR_SETTINGS_TEXT
				elseif isFocus then COLOR_FOCUS_TEXT
				elseif isFlagged then COLOR_FLAGGED_TEXT
				elseif isDown then Theme.Colors.White
				else Theme.Colors.Black[300]

			local statusText = if isSettings
				then (if isDown then "OPEN" else "CLOSE")
				elseif isFocus then (if isDown then "LOST" else "GAINED")
				elseif isFlagged then "FLAG"
				else "PRESS"

			local statusColor = if isSettings
				then COLOR_SETTINGS_TEXT
				elseif isFocus then COLOR_FOCUS_TEXT
				elseif isFlagged then COLOR_FLAGGED_TEXT
				else COLOR_DOWN_STATUS

			row.Frame.BackgroundColor3 = bgColor
			row.TimeLabel.Text = entry.formattedTime
			row.KeyNameLabel.Text = entry.keyName
			row.KeyNameLabel.TextColor3 = textColor
			row.KeyNameLabel.Font = if isFlagged or isFocus then Theme.Text.Bold else Theme.Text.Regular
			row.StatusLabel.Text = statusText
			row.StatusLabel.TextColor3 = statusColor
			row.Frame.Visible = true
		else
			row.Frame.Visible = false
		end
	end
end

local function KeyHistoryPanel(scope: FusionScope, props: KeyHistoryPanelProps): Frame
	local panelPos = scope:Value(props.Position or UDim2.new(1, -280, 0.5, -235))
	local isDragging = false
	local dragStartPos = Vector2.zero
	local frameStartPos = UDim2.new(1, -280, 0.5, -235)
	local dragConn: RBXScriptConnection? = nil
	local endConn: RBXScriptConnection? = nil

	local function cleanupDrag()
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
		if endConn then
			endConn:Disconnect()
			endConn = nil
		end
		isDragging = false
	end

	local function onHeaderInputBegan(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
			frameStartPos = Fusion.peek(panelPos)

			cleanupDrag()
			isDragging = true

			dragConn = UserInputService.InputChanged:Connect(function(moveInput)
				if isDragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
					local delta = Vector2.new(moveInput.Position.X, moveInput.Position.Y) - dragStartPos
					panelPos:set(UDim2.new(frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X, frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y))
				end
			end)

			endConn = UserInputService.InputEnded:Connect(function(endInput)
				if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
					cleanupDrag()
				end
			end)
		end
	end

	local rows: { RowSlot } = table.create(MAX_VISIBLE_ROWS)
	local logChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
	}

	for i = 1, MAX_VISIBLE_ROWS do
		local row = createRow(scope, i)
		table.insert(rows, row)
		table.insert(logChildren, row.Frame)
	end

	local function update()
		local list = Fusion.peek(props.KeyHistory) or {}
		updateRows(rows, list)
	end

	table.insert(scope, scope:Observer(props.KeyHistory):onChange(update))
	update()

	return scope:New("Frame")({
		Name = "KeyHistoryPanel",
		Size = UDim2.fromOffset(260, 240),
		Position = panelPos,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = if props.Visible ~= nil then props.Visible else true,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),

			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				[Fusion.OnEvent("InputBegan")] = onHeaderInputBegan,
				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, -90, 1, 0),
						BackgroundTransparency = 1,
						Text = "INPUT LOG",
						TextColor3 = Theme.Colors.White,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("Frame")({
						Name = "Controls",
						Size = UDim2.fromOffset(84, 24),
						Position = UDim2.new(1, -84, 0, 0),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							ExportBtn(scope, {
								OnExport = props.OnExport,
							}),
							scope:New("TextButton")({
								Name = "CloseButton",
								Size = UDim2.fromOffset(22, 22),
								BackgroundColor3 = Theme.Colors.Black[800],
								BorderSizePixel = 0,
								Text = "X",
								TextColor3 = Theme.Colors.Black[300],
								TextSize = Theme.Text.Small,
								Font = Theme.Text.Bold,
								AutoButtonColor = false,
								LayoutOrder = 2,
								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Small,
									}),
									scope:New("UIStroke")({
										Color = Theme.Colors.Black[650],
										Thickness = 1,
									}),
								},
								[Fusion.OnEvent("Activated")] = props.OnClose or function() end,
							}),
						},
					}),
				},
			}),

			scope:New("ScrollingFrame")({
				Name = "LogList",
				Size = UDim2.new(1, 0, 1, -34),
				Position = UDim2.fromOffset(0, 32),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.Black[600],
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				[Fusion.Children] = logChildren,
			}),
		},
	})
end

return KeyHistoryPanel
