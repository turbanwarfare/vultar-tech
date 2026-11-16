--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Theme = require(MainModule.Shared.UI.Theme)
local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

type FusionCanBeState<T> = T | { get: () -> T }

local AimChamberTimerHUD = {}

local SPRING_SPEED = 18
local SPRING_DAMP = 1

local TIMER_FONT = Theme.Text.Bold
local SUB_FONT = Theme.Text.Semibold

local TIMER_COLOR = Theme.Colors.White
local SUB_COLOR = Theme.Foreground.Secondary
local ACCENT_COLOR = Color3.fromRGB(255, 180, 60)

function AimChamberTimerHUD.createHUD(props: {
	Visible: FusionCanBeState<boolean>,
	ElapsedTime: FusionCanBeState<number>,
	SpawnRate: FusionCanBeState<number>,
	PresetId: FusionCanBeState<string>,
	IsAiMode: FusionCanBeState<boolean>?,
	Settings: FusionCanBeState<any>?,
}): ScreenGui
	local scope = Fusion.scoped(Fusion)

	local playerTeam = scope:Value(localPlayer.Team)
	local teamConnection = localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		playerTeam:set(localPlayer.Team)
	end)
	table.insert(scope, teamConnection)

	local visible = props.Visible
	local elapsedTime = props.ElapsedTime
	local spawnRate = props.SpawnRate
	local presetId = props.PresetId

	local hudAlpha = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local hudY = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then 0 else -20
		end),
		SPRING_SPEED,
		SPRING_DAMP
	)

	local timerText = scope:Computed(function(use)
		return AimChamberConfig.formatElapsedTime(use(elapsedTime))
	end)

	local subText = scope:Computed(function(use)
		local isAi = props.IsAiMode and use(props.IsAiMode)
		if isAi and props.Settings then
			local set = use(props.Settings :: any)
			if set and set.AiNpcAccuracy then
				return string.format("SPREAD: %.1f", set.AiNpcAccuracy)
			end
			return "SPREAD: 1.0"
		end
		return AimChamberConfig.formatSpawnRate(use(spawnRate))
	end)

	local modeText = scope:Computed(function(use)
		local p = use(presetId)
		local isAi = props.IsAiMode and use(props.IsAiMode)
		if isAi then
			local difficulty = "EASY"
			if props.Settings then
				local set = use(props.Settings :: any)
				if set and set.AiDifficulty then
					difficulty = string.upper(set.AiDifficulty)
				end
			end
			if p == "CUSTOM" then
				return "MODE: " .. difficulty .. " (CUSTOM)"
			else
				return "MODE: " .. difficulty
			end
		end
		return "MODE: " .. string.upper(tostring(p or "NORMAL"))
	end)

	local container = scope:New("Frame")({
		Name = "TimerContainer",
		Size = UDim2.new(1, 0, 0, 120),
		Position = scope:Computed(function(use)
			return UDim2.new(0.5, 0, 0, 40 + use(hudY))
		end),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(hudAlpha) > 0.01
		end),
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("TextLabel")({
				Name = "TimerText",
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				Text = timerText,
				Font = TIMER_FONT,
				TextSize = 48,
				TextColor3 = TIMER_COLOR,
				TextStrokeTransparency = 0.5,
				TextTransparency = scope:Computed(function(use) return 1 - use(hudAlpha) end),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				LayoutOrder = 1,
			}),
			scope:New("TextLabel")({
				Name = "SubText",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = subText,
				Font = SUB_FONT,
				TextSize = 20,
				TextColor3 = SUB_COLOR,
				TextStrokeTransparency = 0.5,
				TextTransparency = scope:Computed(function(use) return 1 - use(hudAlpha) end),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				LayoutOrder = 2,
				Visible = scope:Computed(function(use)
					if props.IsAiMode and use(props.IsAiMode) then
						return true
					end
					return true
				end),
			}),
			scope:New("TextLabel")({
				Name = "ModeText",
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = modeText,
				Font = SUB_FONT,
				TextSize = 16,
				TextColor3 = ACCENT_COLOR,
				TextStrokeTransparency = 0.5,
				TextTransparency = scope:Computed(function(use) return 1 - use(hudAlpha) end),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				LayoutOrder = 3,
			}),
			scope:New("TextButton")({
				Name = "ExitButton",
				Size = UDim2.fromOffset(100, 26),
				BackgroundColor3 = Theme.Colors.Warning,
				Text = "EXIT MATCH",
				Font = Theme.Text.Bold,
				TextSize = 12,
				TextColor3 = Theme.Colors.White,
				LayoutOrder = 4,
				Visible = scope:Computed(function(use)
					local team = use(playerTeam)
					if team and team.Name == "Spectators" then
						return false
					end

					local isAi = props.IsAiMode
					if isAi ~= nil then
						return use(isAi) == true
					end
					return use(presetId) == "AI"
				end),
				AutoButtonColor = true,
				[Fusion.Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Radius.Medium }),
				},
				[Fusion.OnEvent("Activated")] = function()
					Network.AimChamber.sendEndMatch()
				end,
			}),
		},
	})

	local screenGui = scope:New("ScreenGui")({
		Name = "AimChamberTimerHUD",
		AutoLocalize = false,
		ResetOnSpawn = false,
		DisplayOrder = 150,
		Enabled = true,
		IgnoreGuiInset = true,
		[Fusion.Children] = { container },
	})

	table.insert(scope, screenGui.Destroying:Connect(function()
		scope:doCleanup()
	end))

	return screenGui :: ScreenGui
end

return AimChamberTimerHUD
