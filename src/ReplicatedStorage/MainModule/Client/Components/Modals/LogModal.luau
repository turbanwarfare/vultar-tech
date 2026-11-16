--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type LogModalProps = {
	Visible: FusionCanBeState<boolean>,
	OnClose: (() -> ())?,
}

local MODAL_WIDTH = 360
local PLAYER_ROW_HEIGHT = 34

local function getGameName(): string
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if success and info then
		return info.Name or "Unknown"
	end
	return "Unknown"
end

local function formatTime(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

local function PlayerRow(
	scope: FusionScope,
	player: Network.LogPlayer,
	onRemove: () -> ()
): Frame
	local isHovered = scope:Value(false)
	local removeHovered = scope:Value(false)

	return scope:New("Frame")({
		Name = player.name,
		Size = UDim2.new(1, 0, 0, PLAYER_ROW_HEIGHT),
		BackgroundColor3 = Theme.Colors.Black[800],
		BackgroundTransparency = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				return if use(isHovered) then 0.3 else 0.5
			end),
			50, 1
		),

		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 6),
			}),

			scope:New("TextLabel")({
				Name = "Username",
				Size = UDim2.new(0.5, -12, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				BackgroundTransparency = 1,
				Text = player.name,
				TextColor3 = Theme.Colors.White,
				TextSize = 13,
				Font = Theme.Text.Semibold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),

			scope:New("TextLabel")({
				Name = "Time",
				Size = UDim2.new(0.5, -40, 1, 0),
				Position = UDim2.fromScale(0.5, 0),
				BackgroundTransparency = 1,
				Text = formatTime(player.timeInServer),
				TextColor3 = Color3.fromRGB(140, 140, 145),
				TextSize = 12,
				Font = Theme.Text.Regular,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			scope:New("TextButton")({
				Name = "RemoveButton",
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.new(1, -28, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 80, 80),
				BackgroundTransparency = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return if use(removeHovered) then 0 else 0.85
					end),
					50, 1
				),
				BorderSizePixel = 0,
				Text = "×",
				TextColor3 = scope:Spring(
					scope:Computed(function(use: FusionUseFn)
						return if use(removeHovered) then Theme.Colors.White else Color3.fromRGB(255, 120, 120)
					end),
					50, 1
				),
				TextSize = 16,
				Font = Theme.Text.Bold,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 6),
					}),
				},

				[Fusion.OnEvent("MouseEnter")] = function()
					removeHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					removeHovered:set(false)
				end,

				[Fusion.OnEvent("Activated")] = onRemove,
			}),

			scope:New("TextButton")({
				Name = "Hitbox",
				Size = UDim2.new(1, -34, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 0,

				[Fusion.OnEvent("MouseEnter")] = function()
					isHovered:set(true)
				end,

				[Fusion.OnEvent("MouseLeave")] = function()
					isHovered:set(false)
				end,
			}),
		},
	})
end

local function LogModal(scope: FusionScope, props: LogModalProps): Frame
	local localPlayer = Players.LocalPlayer
	local gameName = getGameName()

	local players = scope:Value({} :: { Network.LogPlayer })
	local isLoading = scope:Value(true)
	local isSubmitting = scope:Value(false)
	local hasError = scope:Value(false)
	local hasSuccess = scope:Value(false)

	local modalVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	scope:Observer(props.Visible):onChange(function()
		local visible = peek(props.Visible)
		if visible then
			isLoading:set(true)
			isSubmitting:set(false)
			hasError:set(false)

			task.spawn(function()
				local logPlayers = Network.Logging.getLogPlayers()
				players:set(logPlayers)
				isLoading:set(false)
			end)
		end
	end)

	local function removePlayer(userId: number)
		local currentPlayers = peek(players)
		local newPlayers = {}
		for _, p in currentPlayers do
			if p.userId ~= userId then
				table.insert(newPlayers, p)
			end
		end
		players:set(newPlayers)
	end

	local function handleSubmit()
		if peek(isSubmitting) then return end
		if peek(hasSuccess) then return end

		local currentPlayers = peek(players)
		if #currentPlayers == 0 then
			hasError:set(true)
			return
		end

		isSubmitting:set(true)
		hasError:set(false)

		local usernames = {}
		for _, p in currentPlayers do
			table.insert(usernames, p.name)
		end

		task.spawn(function()			local result = Network.Logging.submitLog(usernames)
			if result.success then
				hasError:set(false)
				hasSuccess:set(true)
			else
				hasError:set(true)
			end
			isSubmitting:set(false)
		end)
	end

	local submitHovered = scope:Value(false)
	local closeHovered = scope:Value(false)

	local playerCount = scope:Computed(function(use: FusionUseFn)
		return #use(players)
	end)

	return scope:New("Frame")({
		Name = "LogModalContainer",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZIndex.Modal,
		Visible = modalVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ModalWrapper",
				Size = UDim2.fromOffset(MODAL_WIDTH, 440),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = Theme.ZIndex.Modal + 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.new(1, 6, 1, 6),
						Position = UDim2.new(0.5, 0, 0.5, 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = 0.6,
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "Modal",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Black[900],
						BackgroundTransparency = Theme.Transparency.ChatWindow,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 10),
							}),

							scope:New("UIStroke")({
								Color = Theme.Border.Default,
								Thickness = 1,
								Transparency = 0,
							}),

							scope:New("Frame")({
								Name = "Header",
								Size = UDim2.new(1, 0, 0, 100),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 18),
										PaddingLeft = UDim.new(0, 20),
										PaddingRight = UDim.new(0, 20),
									}),

									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, 0, 0, 24),
										BackgroundTransparency = 1,
										Text = "Session Logger",
										TextColor3 = Theme.Colors.White,
										TextSize = 18,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("Frame")({
										Name = "InfoRow",
										Size = UDim2.new(1, 0, 0, 18),
										Position = UDim2.fromOffset(0, 32),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("TextLabel")({
												Name = "MapLabel",
												Size = UDim2.new(0, 36, 1, 0),
												BackgroundTransparency = 1,
												Text = "Map:",
												TextColor3 = Color3.fromRGB(120, 200, 255),
												TextSize = 12,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("TextLabel")({
												Name = "MapValue",
												Size = UDim2.new(1, -36, 1, 0),
												Position = UDim2.fromOffset(36, 0),
												BackgroundTransparency = 1,
												Text = gameName,
												TextColor3 = Theme.Colors.White,
												TextSize = 12,
												Font = Theme.Text.Regular,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextTruncate = Enum.TextTruncate.AtEnd,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "HostRow",
										Size = UDim2.new(1, 0, 0, 18),
										Position = UDim2.fromOffset(0, 54),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("TextLabel")({
												Name = "HostLabel",
												Size = UDim2.new(0, 40, 1, 0),
												BackgroundTransparency = 1,
												Text = "Host:",
												TextColor3 = Color3.fromRGB(120, 200, 255),
												TextSize = 12,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("TextLabel")({
												Name = "HostValue",
												Size = UDim2.new(1, -40, 1, 0),
												Position = UDim2.fromOffset(40, 0),
												BackgroundTransparency = 1,
												Text = localPlayer and (localPlayer.Name .. "  (" .. tostring(localPlayer.UserId) .. ")") or "Unknown",
												TextColor3 = Theme.Colors.White,
												TextSize = 12,
												Font = Theme.Text.Regular,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "PlayersSection",
								Size = UDim2.new(1, 0, 1, -100 - 80),
								Position = UDim2.fromOffset(0, 100),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 12),
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 16),
									}),

									scope:New("Frame")({
										Name = "PlayersHeader",
										Size = UDim2.new(1, 0, 0, 18),
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("TextLabel")({
												Name = "Label",
												Size = UDim2.fromScale(0.5, 1),
												BackgroundTransparency = 1,
												Text = "ATTENDEES",
												TextColor3 = Color3.fromRGB(100, 100, 105),
												TextSize = 10,
												Font = Theme.Text.Bold,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("TextLabel")({
												Name = "Count",
												Size = UDim2.fromScale(0.5, 1),
												Position = UDim2.fromScale(0.5, 0),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use: FusionUseFn)
													return tostring(use(playerCount)) .. " players"
												end),
												TextColor3 = Color3.fromRGB(100, 100, 105),
												TextSize = 10,
												Font = Theme.Text.Regular,
												TextXAlignment = Enum.TextXAlignment.Right,
											}),
										},
									}),

									scope:New("ScrollingFrame")({
										Name = "PlayersList",
										Size = UDim2.new(1, 0, 1, -26),
										Position = UDim2.fromOffset(0, 26),
										BackgroundTransparency = 1,
										ScrollBarThickness = 3,
										ScrollBarImageColor3 = Color3.fromRGB(80, 80, 85),
										CanvasSize = UDim2.fromOffset(0, 0),
										AutomaticCanvasSize = Enum.AutomaticSize.Y,
										ScrollingDirection = Enum.ScrollingDirection.Y,
										BorderSizePixel = 0,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Vertical,
												Padding = UDim.new(0, 6),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),

											scope:New("TextLabel")({
												Name = "Loading",
												Size = UDim2.new(1, 0, 0, 40),
												BackgroundTransparency = 1,
												Visible = isLoading,
												Text = "Loading players...",
												TextColor3 = Color3.fromRGB(140, 140, 145),
												TextSize = 12,
												Font = Theme.Text.Regular,
											}),

											scope:New("TextLabel")({
												Name = "Empty",
												Size = UDim2.new(1, 0, 0, 40),
												BackgroundTransparency = 1,
												Visible = scope:Computed(function(use: FusionUseFn)
													return not use(isLoading) and use(playerCount) == 0
												end),
												Text = "No players found",
												TextColor3 = Color3.fromRGB(140, 140, 145),
												TextSize = 12,
												Font = Theme.Text.Regular,
											}),

											scope:ForValues(players, function(_, innerScope, player)
												return PlayerRow(innerScope, player, function()
													removePlayer(player.userId)
												end)
											end),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Footer",
								Size = UDim2.new(1, 0, 0, 80),
								Position = UDim2.new(0, 0, 1, -80),
								BackgroundTransparency = 1,

								[Fusion.Children] = {
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 16),
										PaddingBottom = UDim.new(0, 16),
									}),

									scope:New("Frame")({
										Name = "SuccessAlert",
										Size = UDim2.new(1, 0, 0, 28),
										Position = UDim2.new(0, 0, 1, -36 - 28 - 6),
										BackgroundColor3 = Color3.fromRGB(40, 120, 70),
										BackgroundTransparency = 0.2,
										Visible = hasSuccess,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 6),
											}),

											scope:New("TextLabel")({
												Name = "Message",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = "Session logged successfully",
												TextColor3 = Color3.fromRGB(200, 255, 210),
												TextSize = 11,
												Font = Theme.Text.Semibold,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "ErrorAlert",
										Size = UDim2.new(1, 0, 0, 28),
										Position = UDim2.new(0, 0, 1, -36 - 28 - 6),
										BackgroundColor3 = Color3.fromRGB(120, 40, 40),
										BackgroundTransparency = 0.2,
										Visible = hasError,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 6),
											}),

											scope:New("TextLabel")({
												Name = "Message",
												Size = UDim2.fromScale(1, 1),
												BackgroundTransparency = 1,
												Text = "Failed to submit log, webhook has been sent",
												TextColor3 = Color3.fromRGB(255, 200, 200),
												TextSize = 11,
												Font = Theme.Text.Semibold,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "ButtonRow",
										Size = UDim2.new(1, 0, 0, 36),
										Position = UDim2.new(0, 0, 1, -36),
										AnchorPoint = Vector2.zero,
										BackgroundTransparency = 1,

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												Padding = UDim.new(0, 10),
											}),

											scope:New("TextButton")({
												Name = "CloseButton",
												Size = UDim2.fromScale(0.48, 1),
												BackgroundColor3 = Theme.Colors.Black[800],
												BackgroundTransparency = scope:Spring(
													scope:Computed(function(use: FusionUseFn)
														return if use(closeHovered) then 0.2 else 0.4
													end),
													50, 1
												),
												BorderSizePixel = 0,
												Text = "",
												LayoutOrder = 1,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = UDim.new(0, 8),
													}),

													scope:New("UIStroke")({
														Color = Theme.Border.Default,
														Thickness = 1,
														Transparency = 0.3,
													}),

													scope:New("TextLabel")({
														Name = "Label",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = "Close",
														TextColor3 = Theme.Colors.White,
														TextSize = 13,
														Font = Theme.Text.Semibold,
													}),
												},

												[Fusion.OnEvent("MouseEnter")] = function()
													closeHovered:set(true)
												end,

												[Fusion.OnEvent("MouseLeave")] = function()
													closeHovered:set(false)
												end,

												[Fusion.OnEvent("Activated")] = function()
													if props.OnClose then
														props.OnClose()
													end
												end,
											}),

											scope:New("TextButton")({
												Name = "SubmitButton",
												Size = UDim2.fromScale(0.48, 1),
												BackgroundColor3 = scope:Spring(
													scope:Computed(function(use: FusionUseFn)
														if use(hasSuccess) then
															return Color3.fromRGB(60, 60, 65)
														end
														if use(submitHovered) then
															return Color3.fromRGB(50, 160, 100)
														end
														return Color3.fromRGB(40, 140, 85)
													end),
													50, 1
												),
												BackgroundTransparency = 0.1,
												BorderSizePixel = 0,
												Text = "",
												LayoutOrder = 2,

												[Fusion.Children] = {
													scope:New("UICorner")({
														CornerRadius = UDim.new(0, 8),
													}),

													scope:New("TextLabel")({
														Name = "Label",
														Size = UDim2.fromScale(1, 1),
														BackgroundTransparency = 1,
														Text = scope:Computed(function(use: FusionUseFn)
															if use(hasSuccess) then return "Logged" end
															if use(isSubmitting) then return "Submitting..." end
															return "Submit Log"
														end),
														TextColor3 = scope:Computed(function(use: FusionUseFn)
															if use(hasSuccess) then
																return Color3.fromRGB(140, 140, 145)
															end
															return Theme.Colors.White
														end),
														TextSize = 13,
														Font = Theme.Text.Semibold,
													}),
												},

												[Fusion.OnEvent("MouseEnter")] = function()
													submitHovered:set(true)
												end,

												[Fusion.OnEvent("MouseLeave")] = function()
													submitHovered:set(false)
												end,

												[Fusion.OnEvent("Activated")] = handleSubmit,
											}),
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

return LogModal
