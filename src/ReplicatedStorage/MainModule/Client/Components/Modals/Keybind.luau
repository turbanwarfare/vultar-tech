--!native
--!optimize 2

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
local Buttons = require(script.Parent.Parent.Buttons)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local EMPTY = ""
local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

local BLACKLISTED_KEYS: { [string]: boolean } = {}
for keyCode in SettingsConfig.KEYBINDS_BLACKLIST_SET do
	BLACKLISTED_KEYS[keyCode.Name] = true
end

export type KeybindProps = {
	Visible: FusionCanBeState<boolean>,
	KeybindName: FusionCanBeState<string>,
	CurrentKey: FusionCanBeState<string>,
	CurrentKeybinds: FusionCanBeState<{ [string]: string }>?,
	OnSave: ((string) -> ())?,
	OnCancel: (() -> ())?,
}

local ACTION_NAME = "VultarKeybindCapture"

local function Keybind(scope: FusionScope, props: KeybindProps): Frame
	local pendingKey = scope:Value("")
	local errorMessage = scope:Value("")
	local inputConnection: RBXScriptConnection? = nil

	local function stopListening()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		ContextActionService:UnbindAction(ACTION_NAME)
	end

	table.insert(scope, stopListening)

	local function startListening()
		stopListening()
		pendingKey:set("")
		errorMessage:set("")

		inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local keyName = input.KeyCode.Name
				if keyName ~= "Unknown" then
					if BLACKLISTED_KEYS[keyName] then
						errorMessage:set("KEY NOT ALLOWED")
					else
						errorMessage:set("")
						pendingKey:set(keyName)
					end
				end
			end
		end)

		ContextActionService:BindAction(
			ACTION_NAME,
			function(_actionName: string, _inputState: Enum.UserInputState, _inputObject: InputObject)
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl
		)
	end

	local wasVisible = false
	scope:Observer(props.Visible):onChange(function()
		local visible = peek(props.Visible) or false
		if visible and not wasVisible then
			task.defer(startListening)
		elseif not visible and wasVisible then
			stopListening()
		end
		wasVisible = visible
	end)

	local modalVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and Theme.Modal.OverlayTransparency or 1
		end),
		Theme.Spring.Default.Speed
	)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and 1 or 0.97
		end),
		Theme.Spring.Gentle.Speed
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and 0 or 1
		end),
		Theme.Spring.Gentle.Speed
	)

	local displayKey = scope:Computed(function(use: FusionUseFn)
		local pending = use(pendingKey)
		if pending ~= "" then
			return pending
		end
		return use(props.CurrentKey) or "..."
	end)

	return scope:New("Frame")({
		Name = "KeybindModalContainer",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZIndex.Modal,
		Visible = modalVisible,

		[Fusion.Children] = {
			scope:New("TextButton")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Modal.Overlay,
				BackgroundTransparency = backgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = Theme.ZIndex.Modal,
				Text = "",
				AutoButtonColor = false,
				Active = true,
			}),

			scope:New("CanvasGroup")({
				Name = "ModalContainer",
				Size = UDim2.fromOffset(320, 220),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Modal.Background,
				BorderSizePixel = 0,
				ZIndex = Theme.ZIndex.Modal + 1,
				GroupTransparency = modalTransparency,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Large,
					}),

					scope:New("UIStroke")({
						Color = Theme.Modal.Border,
						Thickness = 1,
					}),

					scope:New("UIScale")({
						Scale = modalScale,
					}),

					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 45),
						BackgroundColor3 = Theme.Modal.Header,
						BorderSizePixel = 0,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Large,
							}),

							scope:New("Frame")({
								Name = "HeaderMask",
								Size = UDim2.fromScale(1, 0.5),
								Position = UDim2.fromScale(0, 1),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Theme.Modal.Header,
								BorderSizePixel = 0,
								ZIndex = Theme.ZIndex.Modal + 2,
							}),

							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									local name = use(props.KeybindName) or "Keybind"
									return string.upper("CHANGE " .. name:gsub("(%u)", " %1"):gsub("^%s", EMPTY))
								end),
								TextColor3 = Theme.Foreground.Primary,
								TextSize = Theme.Text.Large,
								Font = Theme.Text.Bold,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.new(1, -40, 1, -115),
						Position = UDim2.fromOffset(20, 55),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "Instruction",
								Size = UDim2.new(1, 0, 0, 18),
								BackgroundTransparency = 1,
								Text = "PRESS ANY KEY",
								TextColor3 = Theme.Foreground.Subtle,
								TextSize = Theme.Text.Small,
								Font = Theme.Text.Semibold,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),

							scope:New("Frame")({
								Name = "KeyDisplay",
								Size = UDim2.new(1, 0, 0, 48),
								Position = UDim2.fromOffset(0, 24),
								BackgroundColor3 = Theme.Background.Secondary,
								BorderSizePixel = 0,
								ZIndex = Theme.ZIndex.Modal + 3,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Medium,
									}),

									scope:New("UIStroke")({
										Color = scope:Computed(function(use: FusionUseFn)
											local pending = use(pendingKey)
											if pending ~= "" then
												return Theme.Border.Active
											end
											return Theme.Border.Default
										end),
										Thickness = 2,
									}),

									scope:New("TextLabel")({
										Name = "KeyText",
										Size = UDim2.fromScale(1, 1),
										BackgroundTransparency = 1,
										Text = displayKey,
										TextColor3 = scope:Computed(function(use: FusionUseFn)
											local pending = use(pendingKey)
											if pending ~= "" then
												return Theme.Colors.SuccessHover
											end
											return Theme.Foreground.Tertiary
										end),
										TextSize = Theme.Text.XXLarge,
										Font = Theme.Text.Bold,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "ErrorMessage",
								Size = UDim2.new(1, 0, 0, 16),
								Position = UDim2.fromOffset(0, 78),
								BackgroundTransparency = 1,
								Text = errorMessage,
								TextColor3 = Theme.Colors.Destructive,
								TextSize = Theme.Text.Small,
								Font = Theme.Text.Semibold,
								ZIndex = Theme.ZIndex.Modal + 3,
								Visible = scope:Computed(function(use: FusionUseFn)
									return use(errorMessage) ~= ""
								end),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Buttons",
						Size = UDim2.new(1, -40, 0, 36),
						Position = UDim2.new(0, 20, 1, -50),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, Theme.Spacing.Medium),
							}),

							Buttons.Button(scope, {
								Text = "CANCEL",
								Variant = "secondary",
								Size = UDim2.fromOffset(115, 34),
								LayoutOrder = 1,
								ZIndex = Theme.ZIndex.Modal + 3,
								OnClick = function()
									stopListening()
									if props.OnCancel then
										props.OnCancel()
									end
								end,
							}),

							Buttons.Button(scope, {
								Text = "SAVE",
								Variant = "primary",
								Size = UDim2.fromOffset(115, 34),
								LayoutOrder = 2,
								ZIndex = Theme.ZIndex.Modal + 3,
								OnClick = function()
									local keyToSave = peek(pendingKey)
									if keyToSave == "" then
										keyToSave = peek(props.CurrentKey) or ""
									end

									local currentKeybinds = props.CurrentKeybinds and peek(props.CurrentKeybinds)
									local currentName = peek(props.KeybindName)
									if currentKeybinds and keyToSave ~= "" then
										for bindName, bindKey in currentKeybinds do
											if bindKey == keyToSave and bindName ~= currentName then
												errorMessage:set("ALREADY ASSIGNED TO " .. string.upper(bindName:gsub("(%u)", " %1"):gsub("^%s", EMPTY)))
												return
											end
										end
									end

									stopListening()
									if keyToSave ~= "" and props.OnSave then
										props.OnSave(keyToSave)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

return Keybind
