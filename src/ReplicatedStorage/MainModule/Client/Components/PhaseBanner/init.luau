--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type PhaseBannerProps = {
	Text: Types.FusionValue<string>,
	Visible: Types.FusionValue<boolean>,
}

local DISPLAY_DURATION = 4
local SPRING_SPEED = 30
local SPRING_DAMPING = 1
local DISABLE_DELAY = 0.4
local SHOW_DELAY = 2

local function PhaseBanner(scope: FusionScope, props: PhaseBannerProps): ScreenGui
	local alpha = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return if use(props.Visible) then 1 else 0
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local guiEnabled = scope:Value(false)
	local disableTask: thread? = nil
	local showTask: thread? = nil

	local dismissThread: thread? = nil

	local function scheduleDismiss()
		if dismissThread then
			task.cancel(dismissThread)
		end
		dismissThread = task.delay(DISPLAY_DURATION, function()
			dismissThread = nil
			if Fusion.peek(props.Visible) then
				props.Visible:set(false)
			end
		end)
	end

	scope:Observer(props.Visible):onBind(function()
		if showTask then
			task.cancel(showTask)
			showTask = nil
		end

		if Fusion.peek(props.Visible) then
			if disableTask then
				task.cancel(disableTask)
				disableTask = nil
			end
			showTask = task.delay(SHOW_DELAY, function()
				showTask = nil
				if Fusion.peek(props.Visible) then
					guiEnabled:set(true)
					scheduleDismiss()
				end
			end)
		else
			disableTask = task.delay(DISABLE_DELAY, function()
				disableTask = nil
				if not Fusion.peek(props.Visible) then
					guiEnabled:set(false)
				end
			end)
		end
	end)

	scope:Observer(props.Text):onChange(function()
		if Fusion.peek(props.Visible) then
			scheduleDismiss()
		end
	end)

	table.insert(scope, function()
		if showTask then
			task.cancel(showTask)
		end
		if disableTask then
			task.cancel(disableTask)
		end
		if dismissThread then
			task.cancel(dismissThread)
		end
	end)

	return scope:New("ScreenGui")({
		Name = "PhaseBanner",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 90,
		Enabled = guiEnabled,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "BannerText",
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0.5, 0, 0, 100),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Text = props.Text,
				TextColor3 = Theme.Colors.Warning,
				TextTransparency = scope:Computed(function(use: FusionUseFn)
					return 1 - use(alpha)
				end),
				TextSize = Theme.Text.XXLarge,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

return PhaseBanner
