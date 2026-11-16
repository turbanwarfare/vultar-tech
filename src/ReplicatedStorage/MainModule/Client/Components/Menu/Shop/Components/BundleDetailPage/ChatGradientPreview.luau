--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local Shadow = require(MainModule.Client.Components.Shadow)
local MessageList = require(MainModule.Client.Components.Chat.Messages)
local GradientDriver = require(MainModule.Client.Components.Chat.Messages.GradientDriver)

local BundleTypes = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)
local Utils = require(script.Parent.Utils)

type FusionScope = BundleTypes.FusionScope
type FusionUseFn = BundleTypes.FusionUseFn
type FusionValue<T> = BundleTypes.FusionValue<T>
type ChatMessage = BundleTypes.ChatMessage
type ChatGradientPreviewProps = BundleTypes.ChatGradientPreviewProps
type BundleItem = BundleTypes.BundleItem

local UI = ChatConstants.UI

local FALLBACK_WHITE_SEQUENCE = ColorSequence.new(Color3.new(1, 1, 1))

local function ChatGradientPreview(scope: FusionScope, props: ChatGradientPreviewProps): Frame
	local selectedItem = props.SelectedItem

	local localPlayer = Players.LocalPlayer
	local playerDisplayName = localPlayer.DisplayName
	local localUserId = localPlayer.UserId

	local playerTags = Utils.getPlayerTags()
	local rolePrefix, roleColor = Utils.getPlayerRole()
	local nameColor = Utils.getPlayerNameColor()

	local inputText = scope:Value("")
	local isInputFocused = scope:Value(false)

	local focusGlow = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isInputFocused) then 1 else 0
		end),
		40,
		1
	)

	local function createMockMessage(
		sender: string,
		senderId: number,
		content: string,
		isLocal: boolean,
		gradient: { colors: { Color3 } }?
	): ChatMessage
		return {
			id = HttpService:GenerateGUID(false),
			channelId = "GLOBAL",
			senderId = senderId,
			senderName = sender,
			senderDisplayName = sender,
			content = content,
			timestamp = os.time(),
			tags = if isLocal then playerTags else {},
			nameColor = if isLocal then nameColor else nil,
			rolePrefix = if isLocal then rolePrefix else nil,
			roleColor = if isLocal then roleColor else nil,
			isSystem = false,
			isTeamOnly = false,
			senderTeam = "Vultarians",
			gradient = gradient,
		}
	end

	local chatMessages: FusionValue<{ ChatMessage }> = scope:Value({
		createMockMessage("Player1", 1, "Hey, how's everyone doing?", false, nil),
		createMockMessage("Player2", 2, "Pretty good, thanks for asking!", false, nil),
		createMockMessage(playerDisplayName, localUserId, "Same here, just checking things out", true, nil),
		createMockMessage("Player1", 1, "Nice, have fun!", false, nil),
	})

	local previewColorSequence = scope:Computed(function(use: FusionUseFn)
		local item = use(selectedItem)
		if item and item.gradientColors and #item.gradientColors >= 2 then
			return Utils.convertGradientColors(item.gradientColors)
		end
		return nil
	end)

	local messagesWithGradient = scope:Computed(function(use: FusionUseFn)
		local messages = use(chatMessages)
		local item = use(selectedItem)

		local gradientConfig: { colors: { Color3 } }? = nil
		if item and item.gradientColors and #item.gradientColors >= 2 then
			gradientConfig = { colors = item.gradientColors }
		end

		local result: { ChatMessage } = {}
		for _, msg in messages do
			if msg.senderId == localUserId then
				local newMsg = table.clone(msg) :: any
				newMsg.gradient = gradientConfig
				newMsg.tags = playerTags
				newMsg.rolePrefix = rolePrefix
				newMsg.roleColor = roleColor
				newMsg.nameColor = nameColor
				table.insert(result, newMsg)
			else
				table.insert(result, msg)
			end
		end

		return result
	end)

	return scope:New("Frame")({
		Name = "ChatGradientPreview",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = scope:Computed(function(use: FusionUseFn)
			local item = use(selectedItem)
			return item ~= nil and item.type == "ChatGradient"
		end),

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "ChatPreviewSection",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "SectionLabel",
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = "CHAT PREVIEW",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 11,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "ChatContainer",
						Size = UDim2.fromOffset(UI.chatWidth, UI.chatHeight + UI.elementGap + UI.inputHeight),
						BackgroundTransparency = 1,
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "ChatWindowWrapper",
								Size = UDim2.fromOffset(UI.chatWidth + Constants.SHADOW_SPREAD * 2, UI.chatHeight + Constants.SHADOW_SPREAD * 2),
								Position = UDim2.fromOffset(-Constants.SHADOW_SPREAD, -Constants.SHADOW_SPREAD),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									Shadow(scope, {
										Size = UDim2.fromScale(1, 1),
										Position = UDim2.new(0.5, 0, 0.5, Constants.SHADOW_OFFSET_Y),
										AnchorPoint = Vector2.new(0.5, 0.5),
										Spread = 0,
										Transparency = Constants.SHADOW_TRANSPARENCY,
										ZIndex = 0,
									}),

									scope:New("Frame")({
										Name = "ChatWindow",
										Size = UDim2.fromOffset(UI.chatWidth, UI.chatHeight),
										Position = UDim2.fromOffset(Constants.SHADOW_SPREAD, Constants.SHADOW_SPREAD),
										BackgroundColor3 = Theme.Chat.Window.Background,
										BackgroundTransparency = Theme.Chat.Window.BackgroundTransparency,
										BorderSizePixel = 0,
										ClipsDescendants = true,
										ZIndex = 1,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = Theme.Radius.Medium,
											}),

											scope:New("UIStroke")({
												Color = Theme.Chat.Window.Border,
												Thickness = 1,
												Transparency = Theme.Chat.Window.BorderTransparency,
											}),

											MessageList(scope, {
												Messages = messagesWithGradient,
												LayoutOrder = 0,
												ViewportScale = scope:Value(1),
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "InputBarWrapper",
								Size = UDim2.fromOffset(UI.chatWidth + Constants.SHADOW_SPREAD * 2, UI.inputHeight + Constants.SHADOW_SPREAD * 2),
								Position = UDim2.fromOffset(-Constants.SHADOW_SPREAD, UI.chatHeight + UI.elementGap - Constants.SHADOW_SPREAD),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									Shadow(scope, {
										Size = UDim2.fromScale(1, 1),
										Position = UDim2.new(0.5, 0, 0.5, Constants.SHADOW_OFFSET_Y),
										AnchorPoint = Vector2.new(0.5, 0.5),
										Spread = 0,
										Transparency = Constants.SHADOW_TRANSPARENCY,
										ZIndex = 0,
									}),

									scope:New("Frame")({
										Name = "InputBar",
										Size = UDim2.fromOffset(UI.chatWidth, UI.inputHeight),
										Position = UDim2.fromOffset(Constants.SHADOW_SPREAD, Constants.SHADOW_SPREAD),
										BackgroundColor3 = scope:Spring(
											scope:Computed(function(use: FusionUseFn)
												if use(isInputFocused) then
													return Theme.Chat.Input.BackgroundFocused
												end
												return Theme.Chat.Input.Background
											end),
											Theme.Spring.Default.Speed
										),
										BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
											local glow = use(focusGlow)
											local base = Theme.Chat.Input.BackgroundTransparency
											local focused = Theme.Chat.Input.BackgroundFocusedTransparency
											return base - (base - focused) * glow
										end),
										BorderSizePixel = 0,
										ZIndex = 1,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = Theme.Radius.Medium,
											}),

											scope:New("UIStroke")({
												Color = scope:Spring(
													scope:Computed(function(use: FusionUseFn)
														if use(isInputFocused) then
															return Theme.Chat.Input.BorderFocused
														end
														return Theme.Chat.Input.Border
													end),
													Theme.Spring.Default.Speed
												),
												Thickness = scope:Computed(function(use: FusionUseFn)
													local glow = use(focusGlow)
													return 1 + 0.5 * glow
												end),
												Transparency = scope:Computed(function(use: FusionUseFn)
													local glow = use(focusGlow)
													local base = Theme.Chat.Input.BorderTransparency
													local focused = Theme.Chat.Input.BorderFocusedTransparency
													return base - (base - focused) * glow
												end),
											}),

											scope:New("TextBox")({
												Name = "Input",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = inputText,
												PlaceholderText = "Preview only",
												TextEditable = false,
												PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
												TextColor3 = ChatConstants.Colors.messageText,
												TextSize = ChatConstants.Text.inputTextSize,
												Font = Enum.Font.GothamMedium,
												TextXAlignment = Enum.TextXAlignment.Left,
												ClearTextOnFocus = false,
												ClipsDescendants = true,

												[Fusion.Children] = {
													scope:New("UIPadding")({
														PaddingLeft = UDim.new(0, 10),
														PaddingRight = UDim.new(0, 10),
													}),
												},

												[Fusion.OnChange("Text")] = function(newText: string)
													newText = string.gsub(newText, "[\r\n]", "")
													if #newText > 200 then
														newText = string.sub(newText, 1, 200)
													end
													inputText:set(newText)
												end,

												[Fusion.OnEvent("Focused")] = function()
													isInputFocused:set(true)
												end,

												[Fusion.OnEvent("FocusLost")] = function()
													isInputFocused:set(false)
												end,
											}),
										},
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "GradientBarSection",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextLabel")({
						Name = "SectionLabel",
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = "GRADIENT COLORS",
						TextColor3 = Color3.fromRGB(155, 155, 165),
						TextSize = 11,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "GradientBar",
						Size = UDim2.fromOffset(UI.chatWidth, 28),
						BackgroundColor3 = Color3.new(1, 1, 1),
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
							scope:New("UIStroke")({ Color = Color3.fromRGB(60, 60, 65), Thickness = 1 }),
							(function()
								local g = scope:New("UIGradient")({
									Color = scope:Computed(function(use: FusionUseFn)
										return use(previewColorSequence) or FALLBACK_WHITE_SEQUENCE
									end),
									Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
								})
								GradientDriver.register(g :: any)
								return g
							end)(),
						},
					}),
				},
			}),
		},
	})
end

return ChatGradientPreview
