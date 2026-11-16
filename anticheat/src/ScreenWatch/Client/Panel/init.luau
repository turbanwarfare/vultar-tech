--!strict
--!native
--!optimize 2

local Root = script:FindFirstAncestor("Client").Parent
local MainModule = require(Root.Shared.Game).get()
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)

local KeyboardOverlay = require(script.KeyboardOverlay)
local MouseOverlay = require(script.MouseOverlay)
local KeyHistoryPanel = require(script.KeyHistoryPanel)
local HitLogPanel = require(script.HitLogPanel)
local PlaybackBar = require(script.PlaybackBar)
local CursorOverlay = require(script.CursorOverlay)

type FusionScope = any
type FusionValue<T> = any
type FusionUseFn = any

export type ScreenWatchPanelProps = {
	IsWatching: FusionValue<boolean>,
	TargetUserId: FusionValue<number>,
	TargetName: FusionValue<string>,
	CursorPosition: FusionValue<Vector2>,
	CursorIcon: FusionValue<string>,
	CursorSize: FusionValue<Vector2?>?,
	PlaybackStatus: FusionValue<string>,
	PlaybackPaused: FusionValue<boolean>,
	PlaybackSpeed: FusionValue<number>,
	MarkersEnabled: FusionValue<boolean>,
	TimelineSpan: FusionValue<number>,
	TimelineRewind: FusionValue<number>,
	TimelineTicks: { FusionValue<number> },
	LagStatus: FusionValue<string>,
	AcReport: FusionValue<string>,
	FlickBars: { FusionValue<number> },
	FlickPeak: FusionValue<number>,
	OnTogglePause: () -> (),
	OnCycleSpeed: () -> (),
	OnStepBack: () -> (),
	OnStepForward: () -> (),
	OnSeekBack: () -> (),
	OnSeekForward: () -> (),
	OnGoLive: () -> (),
	OnNextSuspect: () -> (),
	OnWatchVictim: () -> (),
	OnSeekFraction: (fraction: number) -> (),
	OnToggleMarkers: () -> (),
	IsCursorFree: FusionValue<boolean>,
	IsSprinting: FusionValue<boolean>,
	IsCrouching: FusionValue<boolean>,
	TrailEnabled: FusionValue<boolean>,
	GhostsEnabled: FusionValue<boolean>,
	ESPMode: FusionValue<string>,
	InputsVisible: FusionValue<boolean>,
	HitsVisible: FusionValue<boolean>,
	TargetPing: FusionValue<number>,
	TargetAvgPing: FusionValue<number>,
	TargetPingSpikes: FusionValue<number>,
	TargetMatchAccuracy: FusionValue<number>,
	TargetFOV: FusionValue<number>?,
	TargetResolution: FusionValue<Vector2>?,
	TrailNodes: { any },
	KeyStates: { [string]: FusionValue<boolean> },
	MouseStates: { [string]: FusionValue<boolean> },
	KeyHistory: FusionValue<{ any }>,
	HitHistory: FusionValue<{ any }>,
	OnStopWatching: () -> (),
	OnToggleTrail: () -> (),
	OnToggleGhosts: () -> (),
	OnCycleESP: () -> (),
	OnToggleInputs: () -> (),
	OnToggleHits: () -> (),
	OnExportLogs: (() -> ())?,
}

local function MovementBadge(
	scope: FusionScope,
	props: {
		IsSprinting: FusionValue<boolean>,
		IsCrouching: FusionValue<boolean>,
	}
): Frame
	local badgeText = scope:Computed(function(use: FusionUseFn)
		local sprint = use(props.IsSprinting)
		local crouch = use(props.IsCrouching)
		if sprint then
			return "SPRINT"
		elseif crouch then
			return "CROUCH"
		end
		return "STAND"
	end)

	local badgeColor = scope:Computed(function(use: FusionUseFn)
		local sprint = use(props.IsSprinting)
		local crouch = use(props.IsCrouching)
		if sprint then
			return Color3.fromRGB(0, 255, 180)
		elseif crouch then
			return Color3.fromRGB(255, 200, 60)
		end
		return Theme.Colors.Black[400]
	end)

	return scope:New("Frame")({
		Name = "MovementBadge",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.Colors.Black[800],
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("TextLabel")({
				Name = "MovementText",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				Text = badgeText,
				TextColor3 = badgeColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})
end

local function PingBadge(
	scope: FusionScope,
	props: {
		TargetPing: FusionValue<number>,
		TargetAvgPing: FusionValue<number>,
		TargetPingSpikes: FusionValue<number>,
	}
): Frame
	local pingText = scope:Computed(function(use: FusionUseFn)
		local ping = math.round(use(props.TargetPing) or 0)
		local avg = math.round(use(props.TargetAvgPing) or 0)
		local spikes = use(props.TargetPingSpikes) or 0
		return `{ping}ms (AVG: {avg}ms, SPIKES: {spikes})`
	end)

	local pingColor = scope:Computed(function(use: FusionUseFn)
		local ping = use(props.TargetPing) or 0
		if ping > 150 then
			return Theme.Colors.Destructive
		elseif ping > 80 then
			return Theme.Colors.Warning
		end
		return Theme.Colors.Success
	end)

	return scope:New("Frame")({
		Name = "PingBadge",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.Colors.Black[800],
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Small,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("TextLabel")({
				Name = "PingText",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				Text = pingText,
				TextColor3 = pingColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})
end

local function HeaderBanner(
	scope: FusionScope,
	props: {
		TargetName: FusionValue<string>,
		TargetUserId: FusionValue<number>,
		IsSprinting: FusionValue<boolean>,
		IsCrouching: FusionValue<boolean>,
		TrailEnabled: FusionValue<boolean>,
		GhostsEnabled: FusionValue<boolean>,
		ESPMode: FusionValue<string>,
		InputsVisible: FusionValue<boolean>,
		HitsVisible: FusionValue<boolean>,
		TargetPing: FusionValue<number>,
		TargetAvgPing: FusionValue<number>,
		TargetPingSpikes: FusionValue<number>,
		OnToggleTrail: () -> (),
		OnToggleGhosts: () -> (),
		OnCycleESP: () -> (),
		OnToggleInputs: () -> (),
		OnToggleHits: () -> (),
		OnExportLogs: (() -> ())?,
		OnClose: () -> (),
	}
): Frame
	local trailBtnText = scope:Computed(function(use: FusionUseFn)
		return if use(props.TrailEnabled) then "TRAIL: ON" else "TRAIL: OFF"
	end)
	local trailBtnColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.TrailEnabled)
			then Theme.Colors.White
			else Theme.Colors.Black[400]
	end)

	local ghostsBtnText = scope:Computed(function(use: FusionUseFn)
		return if use(props.GhostsEnabled) then "GHOSTS: ON" else "GHOSTS: OFF"
	end)
	local ghostsBtnColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.GhostsEnabled)
			then Theme.Colors.White
			else Theme.Colors.Black[400]
	end)

	local espBtnText = scope:Computed(function(use: FusionUseFn)
		local mode = use(props.ESPMode) or "TEAM"
		return `ESP: {mode}`
	end)
	local espBtnColor = scope:Computed(function(use: FusionUseFn)
		local mode = use(props.ESPMode) or "TEAM"
		return if mode == "OFF" then Theme.Colors.Black[400] else Theme.Colors.White
	end)

	local inputsBtnText = scope:Computed(function(use: FusionUseFn)
		return if use(props.InputsVisible) then "INPUTS: ON" else "INPUTS: OFF"
	end)
	local inputsBtnColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.InputsVisible)
			then Theme.Colors.White
			else Theme.Colors.Black[400]
	end)

	local hitsBtnText = scope:Computed(function(use: FusionUseFn)
		return if use(props.HitsVisible) then "HITS: ON" else "HITS: OFF"
	end)
	local hitsBtnColor = scope:Computed(function(use: FusionUseFn)
		return if use(props.HitsVisible)
			then Theme.Colors.White
			else Theme.Colors.Black[400]
	end)

	local exportStatus = scope:Value("idle")
	local exportBtnText = scope:Computed(function(use: FusionUseFn)
		local s = use(exportStatus)
		if s == "sent" or s == "success" then
			return "SENT"
		elseif s == "exporting" then
			return "..."
		end
		return "EXPORT"
	end)
	local exportBtnTextColor = scope:Computed(function(use: FusionUseFn)
		local s = use(exportStatus)
		if s == "sent" or s == "success" then
			return Color3.fromRGB(80, 220, 130)
		elseif s == "exporting" then
			return Theme.Colors.Black[300]
		end
		return Theme.Colors.White
	end)

	return scope:New("Frame")({
		Name = "HeaderBanner",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
		Position = UDim2.new(0.5, 0, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Black[900],
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		[Fusion.Children] = {
			scope:New("UICorner")({
				CornerRadius = Theme.Radius.Medium,
			}),
			scope:New("UIStroke")({
				Color = Theme.Colors.Black[650],
				Thickness = 1,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),

			scope:New("TextLabel")({
				Name = "Title",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 24),
				BackgroundTransparency = 1,
				Text = "VDI SCREENWATCH",
				TextColor3 = Theme.Colors.White,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),

			scope:New("TextLabel")({
				Name = "TargetInfo",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use: FusionUseFn)
					local name = use(props.TargetName)
					return `TARGET: {name}`
				end),
				TextColor3 = Theme.Colors.Black[200],
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),

			scope:New("Frame")({
				Name = "MovementContainer",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				[Fusion.Children] = {
					MovementBadge(scope, {
						IsSprinting = props.IsSprinting,
						IsCrouching = props.IsCrouching,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "PingContainer",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				[Fusion.Children] = {
					PingBadge(scope, {
						TargetPing = props.TargetPing,
						TargetAvgPing = props.TargetAvgPing,
						TargetPingSpikes = props.TargetPingSpikes,
					}),
				},
			}),

			scope:New("TextButton")({
				Name = "TrailButton",
				Size = UDim2.fromOffset(78, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = trailBtnText,
				TextColor3 = trailBtnColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 5,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnToggleTrail,
			}),

			scope:New("TextButton")({
				Name = "GhostsButton",
				Size = UDim2.fromOffset(88, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = ghostsBtnText,
				TextColor3 = ghostsBtnColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 6,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnToggleGhosts,
			}),

			scope:New("TextButton")({
				Name = "ESPButton",
				Size = UDim2.fromOffset(92, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = espBtnText,
				TextColor3 = espBtnColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 7,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnCycleESP,
			}),

			scope:New("TextButton")({
				Name = "InputsButton",
				Size = UDim2.fromOffset(82, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = inputsBtnText,
				TextColor3 = inputsBtnColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 8,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnToggleInputs,
			}),

			scope:New("TextButton")({
				Name = "HitsButton",
				Size = UDim2.fromOffset(74, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = hitsBtnText,
				TextColor3 = hitsBtnColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 9,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Black[650],
						Thickness = 1,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnToggleHits,
			}),

			scope:New("TextButton")({
				Name = "ExportButton",
				Size = UDim2.fromOffset(68, 26),
				BackgroundColor3 = Theme.Colors.Black[800],
				BorderSizePixel = 0,
				Text = exportBtnText,
				TextColor3 = exportBtnTextColor,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 10,
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
					if props.OnExportLogs then
						exportStatus:set("exporting")
						props.OnExportLogs()
						exportStatus:set("sent")
						task.delay(2.5, function()
							exportStatus:set("idle")
						end)
					end
				end,
			}),

			scope:New("TextButton")({
				Name = "StopButton",
				Size = UDim2.fromOffset(56, 26),
				BackgroundColor3 = Theme.Colors.Destructive,
				BorderSizePixel = 0,
				Text = "STOP",
				TextColor3 = Theme.Colors.White,
				TextSize = Theme.Text.Small,
				Font = Theme.Text.Bold,
				AutoButtonColor = false,
				LayoutOrder = 11,
				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.Small,
					}),
				},
				[Fusion.OnEvent("Activated")] = props.OnClose,
			}),
		},
	})
end

local function ScreenWatchPanel(scope: FusionScope, props: ScreenWatchPanelProps): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ScreenWatchHUD",
		AutoLocalize = false,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		Enabled = props.IsWatching,
		[Fusion.Children] = {
			HeaderBanner(scope, {
				TargetName = props.TargetName,
				TargetUserId = props.TargetUserId,
				IsSprinting = props.IsSprinting,
				IsCrouching = props.IsCrouching,
				TrailEnabled = props.TrailEnabled,
				GhostsEnabled = props.GhostsEnabled,
				ESPMode = props.ESPMode,
				InputsVisible = props.InputsVisible,
				HitsVisible = props.HitsVisible,
				TargetPing = props.TargetPing,
				TargetAvgPing = props.TargetAvgPing,
				TargetPingSpikes = props.TargetPingSpikes,
				OnToggleTrail = props.OnToggleTrail,
				OnToggleGhosts = props.OnToggleGhosts,
				OnCycleESP = props.OnCycleESP,
				OnToggleInputs = props.OnToggleInputs,
				OnToggleHits = props.OnToggleHits,
				OnExportLogs = props.OnExportLogs,
				OnClose = props.OnStopWatching,
			}),
			CursorOverlay(scope, {
				CursorPosition = props.CursorPosition,
				CursorIcon = props.CursorIcon,
				CursorSize = props.CursorSize,
				IsWatching = props.IsWatching,
				TrailNodes = props.TrailNodes,
			}),
			KeyboardOverlay(scope, {
				KeyStates = props.KeyStates,
				TargetFOV = props.TargetFOV,
				TargetResolution = props.TargetResolution,
			}),
			MouseOverlay(scope, {
				MouseStates = props.MouseStates,
			}),
			KeyHistoryPanel(scope, {
				KeyHistory = props.KeyHistory,
				TargetName = props.TargetName,
				TargetUserId = props.TargetUserId,
				Visible = props.InputsVisible,
				OnClose = props.OnToggleInputs,
				OnExport = props.OnExportLogs,
			}),
			PlaybackBar(scope, {
				PlaybackStatus = props.PlaybackStatus,
				PlaybackPaused = props.PlaybackPaused,
				PlaybackSpeed = props.PlaybackSpeed,
				MarkersEnabled = props.MarkersEnabled,
				TimelineSpan = props.TimelineSpan,
				TimelineRewind = props.TimelineRewind,
				TimelineTicks = props.TimelineTicks,
				LagStatus = props.LagStatus,
				AcReport = props.AcReport,
				FlickBars = props.FlickBars,
				FlickPeak = props.FlickPeak,
				OnTogglePause = props.OnTogglePause,
				OnCycleSpeed = props.OnCycleSpeed,
				OnStepBack = props.OnStepBack,
				OnStepForward = props.OnStepForward,
				OnSeekBack = props.OnSeekBack,
				OnSeekForward = props.OnSeekForward,
				OnGoLive = props.OnGoLive,
				OnNextSuspect = props.OnNextSuspect,
				OnWatchVictim = props.OnWatchVictim,
				OnSeekFraction = props.OnSeekFraction,
				OnToggleMarkers = props.OnToggleMarkers,
			}),
			HitLogPanel(scope, {
				HitHistory = props.HitHistory,
				TargetName = props.TargetName,
				TargetUserId = props.TargetUserId,
				TargetMatchAccuracy = props.TargetMatchAccuracy,
				Visible = props.HitsVisible,
				OnClose = props.OnToggleHits,
				OnExport = props.OnExportLogs,
			}),
		},
	})
end

return ScreenWatchPanel
