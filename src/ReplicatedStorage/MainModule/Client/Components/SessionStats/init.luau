--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)
local FormatUtils = require(MainModule.Shared.Utils.Text.FormatUtils)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local Constants = require(MainModule.Shared.Config.Constants)
local LogModal = require(MainModule.Client.Components.Modals.LogModal)

local peek: <T>(state: any) -> T = Fusion.peek

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

local AGE_UPDATE_INTERVAL = 1
local REGION_ATTRIBUTE = "ServerRegion"
local RENDER_BIND_KEY = "SessionStats_ShiftLockEnforce"

local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local STATS_TEXT_COLOR = Color3.fromRGB(170, 172, 178)
local STATS_STROKE_COLOR = Color3.fromRGB(15, 15, 20)
local PADDING = 8
local TEXT_SIZE = 12
local STATS_TEXT_SIZE = 14
local BUTTON_WIDTH = 125
local BUTTON_HEIGHT = 28
local ICON_BUTTON_SIZE = 28
local ICON_SIZE = 14
local ICON_EXPAND = "rbxassetid://81045999480314"
local ICON_COLLAPSE = "rbxassetid://123792095850614"
local SLIDE_TWEEN_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local SLIDE_TWEEN_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local formatTime = FormatUtils.formatTimeHHMMSS

local function getServerRegion(): string
	local region = ReplicatedStorage:GetAttribute(REGION_ATTRIBUTE)
	if region and region ~= "" then
		return region
	end
	return "..."
end

local function SessionStats(scope: FusionScope): ScreenGui
	local localPlayer = Players.LocalPlayer
	local playerCount = scope:Value(#Players:GetPlayers())
	local region = scope:Value(getServerRegion())
	local age = scope:Value(0)
	local shiftLockFree = scope:Value(false)
	local panelExpanded = scope:Value(true)
	local canAccessLogging = scope:Value(false)
	local logModalVisible = scope:Value(false)

	task.spawn(function()		if localPlayer then
			local vultarSuccess, vultarRank = pcall(function()
				return localPlayer:GetRankInGroup(Constants.GROUPS.VULTAR)
			end)
			if vultarSuccess and vultarRank >= Constants.MIN_RANK.NCO then
				canAccessLogging:set(true)
				return
			end

			local viacomSuccess, viacomRank = pcall(function()
				return localPlayer:GetRankInGroup(Constants.GROUPS.VIACOM)
			end)
			if viacomSuccess and viacomRank >= Constants.MIN_RANK.VIACOM_INSTRUCTOR then
				canAccessLogging:set(true)
			end
		end
	end)

	local sessionStart = os.clock()
	local ageUpdateThread: thread? = nil

	local rmbDown = false
	local shiftLockConnections: { RBXScriptConnection } = {}
	local savedMouseBehavior: Enum.MouseBehavior? = nil
	local savedCameraMode: Enum.CameraMode? = nil

	local function disconnectShiftLock()
		for _, conn in shiftLockConnections do
			conn:Disconnect()
		end
		table.clear(shiftLockConnections)
	end

	local function enableFreeMode()
		if not localPlayer then return end

		savedMouseBehavior = UserInputService.MouseBehavior
		savedCameraMode = localPlayer.CameraMode

		pcall(function()
			localPlayer.CameraMode = Enum.CameraMode.Classic
		end)

		table.insert(shiftLockConnections, UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				rmbDown = true
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			end
		end))

		table.insert(shiftLockConnections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				rmbDown = false
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end))

		RunService:BindToRenderStep(RENDER_BIND_KEY, Enum.RenderPriority.Camera.Value + 2, function()
			if rmbDown then
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				end
			else
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			end
		end)
	end

	local function disableFreeMode()
		rmbDown = false

		pcall(function()
			RunService:UnbindFromRenderStep(RENDER_BIND_KEY)
		end)

		disconnectShiftLock()

		if savedMouseBehavior then
			UserInputService.MouseBehavior = savedMouseBehavior
			savedMouseBehavior = nil
		end

		if savedCameraMode and localPlayer then
			pcall(function()
				localPlayer.CameraMode = savedCameraMode
			end)
			savedCameraMode = nil
		end
	end

	local function applyShiftLockMode(isFree: boolean)
		if isFree then
			enableFreeMode()
		else
			disableFreeMode()
		end
		shiftLockFree:set(isFree)
	end

	local function toggleShiftLock()
		local isFree = peek(shiftLockFree)
		local newMode = not isFree
		applyShiftLockMode(newMode)

		local enumValue = if newMode then SettingsEnums.ShiftLockMode.Free else SettingsEnums.ShiftLockMode.Locked
		Network.Settings.changeSetting("ShiftLockMode", enumValue)
	end

	task.spawn(function()		local settingsService = ServiceLocator.Settings()
		if settingsService then
			local settingChangedSignal = settingsService.SettingChanged
			if settingChangedSignal then
				table.insert(scope, settingChangedSignal:Connect(function(key: string, value: any)
					if key == "ShiftLockMode" then
						local isFree = value == SettingsEnums.ShiftLockMode.Free
						if isFree ~= peek(shiftLockFree) then
							applyShiftLockMode(isFree)
						end
					end
				end))
			end

			local currentMode = settingsService:GetSetting("ShiftLockMode")
			if currentMode == SettingsEnums.ShiftLockMode.Free then
				applyShiftLockMode(true)
			end

			task.delay(1, function()
				local delayedMode = settingsService:GetSetting("ShiftLockMode")
				if delayedMode == SettingsEnums.ShiftLockMode.Free and not peek(shiftLockFree) then
					applyShiftLockMode(true)
				end
			end)
		end
	end)

	local ageRunning = true
	ageUpdateThread = task.spawn(function()
		while ageRunning do
			task.wait(AGE_UPDATE_INTERVAL)
			if ageRunning then
				age:set(math.floor(os.clock() - sessionStart))
			end
		end
	end)

	local playerAddedConnection = Players.PlayerAdded:Connect(function()
		playerCount:set(#Players:GetPlayers())
	end)

	local playerRemovedConnection = Players.PlayerRemoving:Connect(function()
		task.defer(function()
			playerCount:set(#Players:GetPlayers())
		end)
	end)

	local regionChangedConnection = ReplicatedStorage:GetAttributeChangedSignal(REGION_ATTRIBUTE):Connect(function()
		region:set(getServerRegion())
	end)

	table.insert(scope, function()
		ageRunning = false
		if ageUpdateThread then
			task.cancel(ageUpdateThread)
			ageUpdateThread = nil
		end
		playerAddedConnection:Disconnect()
		playerRemovedConnection:Disconnect()
		regionChangedConnection:Disconnect()
		disableFreeMode()
	end)

	local modeText = scope:Computed(function(use: FusionUseFn)
		return if use(shiftLockFree) then "Free" else "Locked"
	end)

	local ROW_WIDTH = BUTTON_WIDTH + 4 + ICON_BUTTON_SIZE
	local SLIDE_DISTANCE = BUTTON_WIDTH + 4

	local slidingButtons = scope:New("Frame")({
		Name = "SlidingButtons",
		Size = UDim2.fromOffset(ROW_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("TextButton")({
				Name = "LoggingButton",
				Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
				BackgroundColor3 = Theme.Chat.Input.Background,
				BackgroundTransparency = Theme.Chat.Input.BackgroundTransparency,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				LayoutOrder = 0,
				Visible = canAccessLogging,

				[Fusion.OnEvent("Activated")] = function()
					logModalVisible:set(true)
				end,

				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
					scope:New("UIStroke")({ Color = Theme.Chat.Input.Border, Thickness = 1, Transparency = 0.3 }),
					scope:New("TextLabel")({
						Name = "Label",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "Logging",
						TextColor3 = TEXT_COLOR,
						TextSize = TEXT_SIZE,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "ShiftLockRow",
				Size = UDim2.fromOffset(ROW_WIDTH, BUTTON_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					scope:New("TextButton")({
						Name = "ShiftLockToggle",
						Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
						BackgroundColor3 = Theme.Chat.Input.Background,
						BackgroundTransparency = Theme.Chat.Input.BackgroundTransparency,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						LayoutOrder = 1,

						[Fusion.OnEvent("Activated")] = toggleShiftLock,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIStroke")({ Color = Theme.Chat.Input.Border, Thickness = 1, Transparency = 0.3 }),
							scope:New("TextLabel")({
								Name = "Label",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use: FusionUseFn)
									return "Shift Lock: " .. use(modeText)
								end),
								TextColor3 = TEXT_COLOR,
								TextSize = TEXT_SIZE,
								Font = Enum.Font.GothamBold,
								TextXAlignment = Enum.TextXAlignment.Center,
								TextYAlignment = Enum.TextYAlignment.Center,
							}),
						},
					}),

					scope:New("TextButton")({
						Name = "PanelToggle",
						Size = UDim2.fromOffset(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE),
						BackgroundColor3 = Theme.Chat.Input.Background,
						BackgroundTransparency = Theme.Chat.Input.BackgroundTransparency,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						LayoutOrder = 2,
						Text = "",

						[Fusion.OnEvent("Activated")] = function()
							panelExpanded:set(not peek(panelExpanded))
						end,

						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
							scope:New("UIStroke")({ Color = Theme.Chat.Input.Border, Thickness = 1, Transparency = 0.3 }),
							scope:New("ImageLabel")({
								Name = "Icon",
								Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = scope:Computed(function(use: FusionUseFn)
									return if use(panelExpanded) then ICON_COLLAPSE else ICON_EXPAND
								end),
								ImageColor3 = TEXT_COLOR,
							}),
						},
					}),
				},
			}),
		},
	})

	local container = scope:New("Frame")({
		Name = "Container",
		Size = UDim2.fromOffset(400, 100),
		Position = UDim2.new(0, PADDING, 1, -PADDING),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			scope:New("Frame")({
				Name = "ButtonArea",
				Size = UDim2.fromOffset(ROW_WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				LayoutOrder = 0,

				[Fusion.Children] = {
					slidingButtons,
				},
			}),

			scope:New("TextLabel")({
				Name = "StatsText",
				Size = UDim2.fromOffset(400, STATS_TEXT_SIZE + 2),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Text = scope:Computed(function(use: FusionUseFn)
					local count = use(playerCount)
					local regionVal = use(region)
					local ageVal = use(age)
					return string.format("Players: %d   Region: %s   Age: %s", count, regionVal, formatTime(ageVal))
				end),
				TextColor3 = STATS_TEXT_COLOR,
				TextTransparency = 0,
				TextStrokeColor3 = STATS_STROKE_COLOR,
				TextStrokeTransparency = 0.6,
				TextSize = STATS_TEXT_SIZE,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

	local slideTween: Tween? = nil
	scope:Observer(panelExpanded):onChange(function()
		local expanded = peek(panelExpanded)
		if slideTween then
			slideTween:Cancel()
		end
		local targetX = if expanded then 0 else -SLIDE_DISTANCE
		local info = if expanded then SLIDE_TWEEN_IN else SLIDE_TWEEN_OUT
		slideTween = TweenService:Create(slidingButtons, info, { Position = UDim2.fromOffset(targetX, 0) })
		slideTween:Play()
	end)

	return scope:New("ScreenGui")({
		Name = "SessionStats",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			LogModal(scope, {
				Visible = logModalVisible,
				OnClose = function()
					logModalVisible:set(false)
				end,
			}),
			container,
		},
	})
end

return SessionStats
