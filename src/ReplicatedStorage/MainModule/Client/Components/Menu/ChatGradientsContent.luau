--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CosmeticConfig = require(MainModule.Shared.Config.Cosmetics)
local Network = require(MainModule.Shared.Network)
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)
local ChatConstants = require(MainModule.Shared.Chat.Constants)
local ChatTypes = require(MainModule.Shared.Network.Chat.Types)
local Shadow = require(MainModule.Client.Components.Shadow)
local EMPTY = ""

local MessageList = require(MainModule.Client.Components.Chat.Messages)
local GradientDriver = require(MainModule.Client.Components.Chat.Messages.GradientDriver)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionValue<T> = Types.FusionValue<T>
type ChatMessage = ChatTypes.ChatMessage

export type ChatGradientsContentProps = {
	OwnedItems: FusionValue<{ [string]: boolean }>?,
	EquippedItems: FusionValue<{ [string]: any }>?,
}

local LIST_WIDTH = 300
local ITEM_HEIGHT = 60
local ITEM_GAP = 4
local LIST_PADDING = 4
local ACCENT_COLOR = Color3.fromRGB(255, 140, 60)

local UI = ChatConstants.UI
local SHADOW_SPREAD = 6
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.65
local DEFAULT_GRADIENT_ID = "DEFAULT_NONE"
local DEFAULT_NAME_COLOR = Theme.Chat.Name.Default
local WHITE_COLOR_SEQUENCE = ColorSequence.new(Color3.new(1, 1, 1))

local function convertGradientColors(colors: { Color3 }): ColorSequence
	local colorCount = #colors
	if colorCount < 2 then
		return WHITE_COLOR_SEQUENCE
	end

	local keypoints: { ColorSequenceKeypoint } = {}

	if colorCount == 7 then
		keypoints = {
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.18, colors[2]),
			ColorSequenceKeypoint.new(0.35, colors[3]),
			ColorSequenceKeypoint.new(0.50, colors[4]),
			ColorSequenceKeypoint.new(0.65, colors[5]),
			ColorSequenceKeypoint.new(0.82, colors[6]),
			ColorSequenceKeypoint.new(1, colors[7]),
		}
	else
		for i, color in ipairs(colors) do
			local position = (i - 1) / (colorCount - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
		end
	end

	return ColorSequence.new(keypoints)
end

local function getGradientName(item: CosmeticConfig.ItemConfig): string
	if item.name then
		return item.name
	end
	local id = item.id
	local name = id:gsub("_ChatGradient", EMPTY):gsub("_", " ")
	return name
end

local function getPlayerTags(): { string }
	local tags: { string } = {}
	local player = LocalPlayer

	for _, tag in ChatConfig.Tags do
		if tag.requirement then
			local req = tag.requirement
			if req.type == "group" then
				local success, rank = pcall(function()
					return player:GetRankInGroup(req.groupId)
				end)
				if success and rank and rank > 0 then
					table.insert(tags, tag.id)
				end
			elseif req.type == "ranks" then
				local success, rank = pcall(function()
					return player:GetRankInGroup(req.groupId)
				end)
				if success and rank then
					for _, r in req.ranks do
						if r == rank then
							table.insert(tags, tag.id)
							break
						end
					end
				end
			end
		end
	end

	return tags
end

local function getPlayerRole(): (string?, Color3?)
	local player = LocalPlayer

	for _, role in ChatConfig.Roles do
		local success, rank = pcall(function()
			return player:GetRankInGroup(role.groupId)
		end)
		if success and rank and rank == role.rank then
			return role.prefix, role.color
		end
	end

	return nil, nil
end

local function getPlayerNameColor(): Color3?
	local player = LocalPlayer

	for _, nameColorConfig in ChatConfig.NameColors do
		local req = nameColorConfig.requirement
		if req.type == "rank" then
			local success, rank = pcall(function()
				return player:GetRankInGroup(req.groupId)
			end)
			if success and rank and rank >= req.minRank then
				return nameColorConfig.color
			end
		end
	end

	return nil
end

local function createGradientListItem(
	scope: FusionScope,
	item: CosmeticConfig.ItemConfig,
	isHovered: FusionValue<boolean>,
	isEquipped: FusionValue<boolean>,
	onHover: () -> (),
	onLeave: () -> (),
	onClick: () -> ()
): Frame
	local gradientName = getGradientName(item)
	local colors = item.gradientColors or {}
	local hasGradient = #colors >= 2
	local colorSequence = if hasGradient then convertGradientColors(colors) else WHITE_COLOR_SEQUENCE

	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return 0.88
			elseif use(isHovered) then
				return 0.92
			end
			return 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.01 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	return scope:New("Frame")({
		Name = item.id,
		Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "ItemContainer",
				Size = scope:Computed(function(use: FusionUseFn)
					local scale = use(cardScale)
					return UDim2.new(scale, -8, scale, 0)
				end),
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = ACCENT_COLOR,
				BackgroundTransparency = bgTransparency,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return ACCENT_COLOR
								elseif use(isHovered) then
									return Color3.fromRGB(50, 50, 55)
								end
								return Color3.fromRGB(35, 35, 40)
							end),
							Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return 0.7
								elseif use(isHovered) then
									return 0.85
								end
								return 1
							end),
							Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(10, 0),
						BackgroundTransparency = 1,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "GradientName",
								Size = UDim2.new(0.55, 0, 0, 18),
								Position = UDim2.fromOffset(0, 10),
								BackgroundTransparency = 1,
								Text = string.upper(gradientName),
								TextColor3 = Color3.new(1, 1, 1),
								TextSize = 14,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								[Fusion.Children] = {
									if hasGradient then (function()
										local g = scope:New("UIGradient")({
											Color = colorSequence,
											Rotation = 0,
											Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
										})
										GradientDriver.register(g :: any)
										return g
									end)() else nil,
								},
							}),

							scope:New("Frame")({
								Name = "GradientPreview",
								Size = UDim2.fromOffset(80, 10),
								Position = UDim2.new(1, -6, 0, 12),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundColor3 = Color3.new(1, 1, 1),
								ZIndex = 3,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
									if hasGradient then (function()
										local g = scope:New("UIGradient")({
											Color = colorSequence,
											Rotation = 0,
											Offset = Vector2.new(GradientDriver.getCurrentOffset() - 1, 0),
										})
										GradientDriver.register(g :: any)
										return g
									end)() else nil,
								},
							}),

							scope:New("Frame")({
								Name = "EquippedBadge",
								Size = UDim2.fromOffset(74, 18),
								Position = UDim2.new(0, 0, 1, -8),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = ACCENT_COLOR,
								BackgroundTransparency = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(isEquipped) then 0.15 else 1
									end),
									Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
								),
								Visible = isEquipped,
								ZIndex = 3,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										Padding = UDim.new(0, 4),
									}),
									scope:New("ImageLabel")({
										Name = "CheckIcon",
										Size = UDim2.fromOffset(11, 11),
										BackgroundTransparency = 1,
										Image = "rbxassetid://10709791437",
										ImageColor3 = Color3.fromRGB(255, 255, 255),
									}),
									scope:New("TextLabel")({
										Name = "EquippedText",
										Size = UDim2.new(0, 50, 1, 0),
										BackgroundTransparency = 1,
										Text = "EQUIPPED",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						[Fusion.OnEvent("MouseEnter")] = onHover,
						[Fusion.OnEvent("MouseLeave")] = onLeave,
						[Fusion.OnEvent("Activated")] = onClick,
					}),
				},
			}),
		},
	})
end

local function createDefaultListItem(
	scope: FusionScope,
	isHovered: FusionValue<boolean>,
	isEquipped: FusionValue<boolean>,
	nameColor: Color3,
	onHover: () -> (),
	onLeave: () -> (),
	onClick: () -> ()
): Frame
	local bgTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			if use(isEquipped) then
				return 0.88
			elseif use(isHovered) then
				return 0.92
			end
			return 1
		end),
		Theme.Spring.Snappy.Speed,
		Theme.Spring.Snappy.Damping
	)

	local cardScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 1.01 else 1
		end),
		Theme.Spring.Responsive.Speed,
		Theme.Spring.Responsive.Damping
	)

	return scope:New("Frame")({
		Name = DEFAULT_GRADIENT_ID,
		Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("CanvasGroup")({
				Name = "ItemContainer",
				Size = scope:Computed(function(use: FusionUseFn)
					local scale = use(cardScale)
					return UDim2.new(scale, -8, scale, 0)
				end),
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(90, 90, 95),
				BackgroundTransparency = bgTransparency,
				ClipsDescendants = true,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),

					scope:New("ImageLabel")({
						Name = "Stripes",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Image = Theme.Patterns.DiagonalStripes.Fat,
						ImageColor3 = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return Color3.fromRGB(90, 90, 95)
								elseif use(isHovered) then
									return Color3.fromRGB(50, 50, 55)
								end
								return Color3.fromRGB(35, 35, 40)
							end),
							Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
						),
						ImageTransparency = scope:Spring(
							scope:Computed(function(use: FusionUseFn)
								if use(isEquipped) then
									return 0.7
								elseif use(isHovered) then
									return 0.85
								end
								return 1
							end),
							Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
						),
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(48, 48),
						ZIndex = 1,
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(10, 0),
						BackgroundTransparency = 1,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "GradientName",
								Size = UDim2.new(0.55, 0, 0, 18),
								Position = UDim2.fromOffset(0, 10),
								BackgroundTransparency = 1,
								Text = "DEFAULT",
								TextColor3 = nameColor,
								TextSize = 14,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),

							scope:New("Frame")({
								Name = "ColorPreview",
								Size = UDim2.fromOffset(80, 10),
								Position = UDim2.new(1, -6, 0, 12),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundColor3 = nameColor,
								ZIndex = 3,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
								},
							}),

							scope:New("TextLabel")({
								Name = "Description",
								Size = UDim2.new(1, 0, 0, 14),
								Position = UDim2.new(0, 0, 1, -10),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundTransparency = 1,
								Text = "Your standard name color",
								TextColor3 = Color3.fromRGB(140, 140, 145),
								TextSize = 10,
								Font = Theme.Text.Semibold,
								TextXAlignment = Enum.TextXAlignment.Left,
								Visible = scope:Computed(function(use: FusionUseFn)
									return not use(isEquipped)
								end),
								ZIndex = 3,
							}),

							scope:New("Frame")({
								Name = "EquippedBadge",
								Size = UDim2.fromOffset(74, 18),
								Position = UDim2.new(0, 0, 1, -8),
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = Color3.fromRGB(90, 90, 95),
								BackgroundTransparency = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(isEquipped) then 0.15 else 1
									end),
									Theme.Spring.Snappy.Speed, Theme.Spring.Snappy.Damping
								),
								Visible = isEquipped,
								ZIndex = 3,
								[Fusion.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										Padding = UDim.new(0, 4),
									}),
									scope:New("ImageLabel")({
										Name = "CheckIcon",
										Size = UDim2.fromOffset(11, 11),
										BackgroundTransparency = 1,
										Image = "rbxassetid://10709791437",
										ImageColor3 = Color3.fromRGB(255, 255, 255),
									}),
									scope:New("TextLabel")({
										Name = "EquippedText",
										Size = UDim2.new(0, 50, 1, 0),
										BackgroundTransparency = 1,
										Text = "EQUIPPED",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "Hitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 10,
						[Fusion.OnEvent("MouseEnter")] = onHover,
						[Fusion.OnEvent("MouseLeave")] = onLeave,
						[Fusion.OnEvent("Activated")] = onClick,
					}),
				},
			}),
		},
	})
end

local function ChatGradientsContent(scope: FusionScope, props: ChatGradientsContentProps): Frame
	local hoveredGradientId = scope:Value(nil :: string?)

	local initialEquipped = ""
	if props.EquippedItems then
		local equipped = Fusion.peek(props.EquippedItems)
		if equipped and equipped.ChatGradient and equipped.ChatGradient ~= "" then
			initialEquipped = equipped.ChatGradient
		end
	end
	local equippedGradientId = scope:Value(initialEquipped)

	local pendingEquipId: string? = nil
	local pendingTimeoutThread: thread? = nil

	local function setPendingEquip(equipId: string)
		if pendingTimeoutThread then
			task.cancel(pendingTimeoutThread)
		end
		pendingEquipId = equipId

		pendingTimeoutThread = task.delay(3, function()
			if pendingEquipId == equipId then
				pendingEquipId = nil
			end
		end)
	end

	if props.EquippedItems then
		scope:Observer(props.EquippedItems):onBind(function()
			local equipped = Fusion.peek(props.EquippedItems)
			if equipped then
				local serverValue = equipped.ChatGradient or ""

				if pendingEquipId ~= nil then
					if pendingEquipId == "" and serverValue == "" then
						pendingEquipId = nil
						equippedGradientId:set("")
					elseif pendingEquipId == serverValue then
						pendingEquipId = nil
						equippedGradientId:set(serverValue)
					end
				else
					equippedGradientId:set(serverValue)
				end
			end
		end)
	end

	local gradientUnsubscribe = GradientDriver.subscribe()
	table.insert(scope, function()
		gradientUnsubscribe()
		if pendingTimeoutThread then
			task.cancel(pendingTimeoutThread)
		end
	end)

	local chatGradients = CosmeticConfig.getItemsByCategory("ChatGradient")

	local filteredGradients = scope:Computed(function(use: FusionUseFn)
		local ownedItems = props.OwnedItems and use(props.OwnedItems)
		local result: { CosmeticConfig.ItemConfig } = {}
		for _, item in chatGradients do
			local isOwned = ownedItems and ownedItems[item.id]
			if item.visible == false and not isOwned then
				continue
			end
			if isOwned then
				table.insert(result, item)
			end
		end
		return result
	end)

	local previewGradientId = scope:Computed(function(use: FusionUseFn)
		return use(hoveredGradientId) or use(equippedGradientId)
	end)

	local isPreviewingDefault = scope:Computed(function(use: FusionUseFn)
		local gradientId = use(previewGradientId)
		return gradientId == "" or gradientId == DEFAULT_GRADIENT_ID
	end)

	local previewGradient = scope:Computed(function(use: FusionUseFn)
		local gradientId = use(previewGradientId)
		if gradientId == "" or gradientId == DEFAULT_GRADIENT_ID then
			return nil
		end
		for _, item in chatGradients do
			if item.id == gradientId then
				return item
			end
		end
		return nil
	end)

	local previewGradientName = scope:Computed(function(use: FusionUseFn)
		if use(isPreviewingDefault) then
			return "Default"
		end
		local item = use(previewGradient)
		return if item then getGradientName(item) else "None"
	end)

	local previewColorSequence = scope:Computed(function(use: FusionUseFn)
		local item = use(previewGradient)
		if item and item.gradientColors and #item.gradientColors >= 2 then
			return convertGradientColors(item.gradientColors)
		end
		return nil
	end)

	local gradientCount = scope:Computed(function(use: FusionUseFn)
		return #use(filteredGradients)
	end)

	local isDefaultEquipped = scope:Computed(function(use: FusionUseFn)
		local equipped = use(equippedGradientId)
		return equipped == "" or equipped == DEFAULT_GRADIENT_ID
	end)

	local isDefaultHovered = scope:Computed(function(use: FusionUseFn)
		return use(hoveredGradientId) == DEFAULT_GRADIENT_ID
	end)

	local localPlayer = LocalPlayer
	local localPlayerName = localPlayer.DisplayName
	local localUserId = localPlayer.UserId
	local playerTags = getPlayerTags()
	local rolePrefix, roleColor = getPlayerRole()
	local nameColor = getPlayerNameColor()

	local inputText = scope:Value("")
	local isInputFocused = scope:Value(false)

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

	local chatMessages = scope:Value({
		createMockMessage("Player1", 1, "Hey, how's everyone doing?", false, nil),
		createMockMessage("Player2", 2, "Pretty good, thanks for asking!", false, nil),
		createMockMessage(localPlayerName, localUserId, "Same here, just checking things out", true, nil),
		createMockMessage("Player1", 1, "Nice, have fun!", false, nil),
	} :: { ChatMessage })

	local messagesWithGradient = scope:Computed(function(use: FusionUseFn)
		local messages = use(chatMessages)
		local gradientItem = use(previewGradient)

		local gradientConfig: { colors: { Color3 } }? = nil
		if gradientItem and gradientItem.gradientColors and #gradientItem.gradientColors >= 2 then
			gradientConfig = { colors = gradientItem.gradientColors }
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

	local focusGlow = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(isInputFocused) then 1 else 0
		end),
		40,
		1
	)

	return scope:New("Frame")({
		Name = "ChatGradientsContent",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ListSection",
				Size = UDim2.new(0, LIST_WIDTH, 1, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4) }),
							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return string.format("MY GRADIENTS [%d]", use(gradientCount))
								end),
								TextColor3 = Color3.fromRGB(120, 120, 125),
								TextSize = 11,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),
							scope:New("Frame")({
								Name = "Underline",
								Size = UDim2.new(0.6, 0, 0, 1),
								Position = UDim2.new(0, 0, 1, 4),
								BackgroundColor3 = Color3.fromRGB(50, 50, 55),
								BorderSizePixel = 0,
							}),
						},
					}),

					scope:New("ScrollingFrame")({
						Name = "GradientList",
						Size = UDim2.new(1, 0, 1, -48),
						Position = UDim2.fromOffset(0, 44),
						BackgroundTransparency = 1,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						BorderSizePixel = 0,
						ClipsDescendants = true,

						[Fusion.Children] = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, LIST_PADDING),
								PaddingLeft = UDim.new(0, LIST_PADDING),
								PaddingRight = UDim.new(0, LIST_PADDING + 8),
								PaddingBottom = UDim.new(0, LIST_PADDING),
							}),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, ITEM_GAP),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),

							(function()
								local defaultItem = createDefaultListItem(
									scope,
									isDefaultHovered,
									isDefaultEquipped,
									nameColor or DEFAULT_NAME_COLOR,
									function()
										hoveredGradientId:set(DEFAULT_GRADIENT_ID)
									end,
									function()
										hoveredGradientId:set(nil)
									end,
									function()
										setPendingEquip("")
										equippedGradientId:set("")
										task.spawn(Network.Cosmetic.unequip, "ChatGradient")
									end
								)
								defaultItem.LayoutOrder = 0
								return defaultItem
							end)(),

							scope:ForPairs(filteredGradients, function(_use, innerScope, index, item)
								local gradientId = item.id
								local isHovered = innerScope:Value(false)
								local isEquipped = innerScope:Computed(function(use: FusionUseFn)
									return use(equippedGradientId) == gradientId
								end)

								local listItem = createGradientListItem(
									innerScope, item, isHovered, isEquipped,
									function()
										isHovered:set(true)
										hoveredGradientId:set(gradientId)
									end,
									function()
										isHovered:set(false)
										hoveredGradientId:set(nil)
									end,
									function()
										setPendingEquip(gradientId)
										equippedGradientId:set(gradientId)
										Network.Cosmetic.equip("ChatGradient", gradientId)
									end
								)
								listItem.LayoutOrder = index + 1
								return index, listItem
							end),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "PreviewSection",
				Size = UDim2.new(1, -(LIST_WIDTH + 32), 1, 0),
				Position = UDim2.fromOffset(LIST_WIDTH + 32, 0),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "PreviewHeader",
						Size = UDim2.new(1, 0, 0, 48),
						BackgroundTransparency = 1,
						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "PreviewTitle",
								Size = UDim2.new(1, 0, 0, 12),
								Position = UDim2.fromOffset(0, 4),
								BackgroundTransparency = 1,
								Text = "PREVIEW",
								TextColor3 = Color3.fromRGB(90, 90, 95),
								TextSize = 10,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("TextLabel")({
								Name = "GradientNameLabel",
								Size = UDim2.new(1, 0, 0, 24),
								Position = UDim2.fromOffset(0, 18),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return string.upper(use(previewGradientName))
								end),
								TextColor3 = Color3.fromRGB(240, 240, 245),
								TextSize = 20,
								Font = Theme.Text.Bold,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),

					scope:New("ScrollingFrame")({
						Name = "PreviewContainer",
						Size = UDim2.new(1, 0, 1, -56),
						Position = UDim2.fromOffset(0, 52),
						BackgroundTransparency = 1,
						ScrollBarThickness = 3,
						ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						BorderSizePixel = 0,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 20),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),

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
										TextColor3 = Color3.fromRGB(100, 100, 105),
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
												Size = UDim2.fromOffset(UI.chatWidth + SHADOW_SPREAD * 2, UI.chatHeight + SHADOW_SPREAD * 2),
												Position = UDim2.fromOffset(-SHADOW_SPREAD, -SHADOW_SPREAD),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													Shadow(scope, {
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
														AnchorPoint = Vector2.new(0.5, 0.5),
														Spread = 0,
														Transparency = SHADOW_TRANSPARENCY,
														ZIndex = 0,
													}),

													scope:New("Frame")({
														Name = "ChatWindow",
														Size = UDim2.fromOffset(UI.chatWidth, UI.chatHeight),
														Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
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
												Size = UDim2.fromOffset(UI.chatWidth + SHADOW_SPREAD * 2, UI.inputHeight + SHADOW_SPREAD * 2),
												Position = UDim2.fromOffset(-SHADOW_SPREAD, UI.chatHeight + UI.elementGap - SHADOW_SPREAD),
												BackgroundTransparency = 1,

												[Fusion.Children] = {
													Shadow(scope, {
														Size = UDim2.fromScale(1, 1),
														Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
														AnchorPoint = Vector2.new(0.5, 0.5),
														Spread = 0,
														Transparency = SHADOW_TRANSPARENCY,
														ZIndex = 0,
													}),

													scope:New("Frame")({
														Name = "InputBar",
														Size = UDim2.fromOffset(UI.chatWidth, UI.inputHeight),
														Position = UDim2.fromOffset(SHADOW_SPREAD, SHADOW_SPREAD),
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
															return Theme.Chat.Input.BackgroundTransparency - (Theme.Chat.Input.BackgroundTransparency - Theme.Chat.Input.BackgroundFocusedTransparency) * glow
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
																	return Theme.Chat.Input.BorderTransparency - (Theme.Chat.Input.BorderTransparency - Theme.Chat.Input.BorderFocusedTransparency) * glow
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
																	scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
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
										Text = scope:Computed(function(use: FusionUseFn)
											return if use(isPreviewingDefault) then "NAME COLOR" else "GRADIENT COLORS"
										end),
										TextColor3 = Color3.fromRGB(100, 100, 105),
										TextSize = 11,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										LayoutOrder = 1,
									}),
									scope:New("Frame")({
										Name = "GradientBar",
										Size = UDim2.fromOffset(UI.chatWidth, 28),
										BackgroundColor3 = scope:Computed(function(use: FusionUseFn)
											if use(isPreviewingDefault) then
												return nameColor or DEFAULT_NAME_COLOR
											end
											return Color3.new(1, 1, 1)
										end),
										LayoutOrder = 2,
										[Fusion.Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
											scope:New("UIStroke")({ Color = Color3.fromRGB(60, 60, 65), Thickness = 1 }),
											(function()
												local g = scope:New("UIGradient")({
													Color = scope:Computed(function(use: FusionUseFn)
														if use(isPreviewingDefault) then
															return WHITE_COLOR_SEQUENCE
														end
														return use(previewColorSequence) or WHITE_COLOR_SEQUENCE
													end),
													Rotation = 0,
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
					}),
				},
			}),
		},
	})
end

return ChatGradientsContent
