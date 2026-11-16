--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Shadow = require(MainModule.Client.Components.Shadow)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn

export type ToastType = "join" | "leave"

export type ToastData = {
	id: string,
	username: string,
	userId: number,
	toastType: ToastType,
	timestamp: number,
}

export type PlayerToastProps = {
	Toasts: Types.FusionValue<{ ToastData }>,
	Visible: Types.FusionValue<boolean>?,
}

local PADDING_RIGHT = 24
local PADDING_BOTTOM = 115
local TOAST_GAP = 6
local TOAST_WIDTH = 180
local TOAST_HEIGHT = 36
local AVATAR_SIZE = 36
local SHADOW_SPREAD = 4
local SHADOW_OFFSET_Y = 2
local SHADOW_TRANSPARENCY = 0.7
local SLIDE_IN_OFFSET = 260
local TOAST_SLOT_HEIGHT = TOAST_HEIGHT + SHADOW_SPREAD * 2 + TOAST_GAP

local SPRING_SPEED = 18
local SPRING_DAMPING = 1

local ENTRY_DELAY = 0.015
local EXIT_DURATION = 0.2

local function getAvatarUrl(userId: number): string
	return string.format(
		"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png",
		userId
	)
end

local function ToastItem(
	scope: FusionScope,
	toast: ToastData,
	index: number,
	onRemoveComplete: (id: string) -> ()
): Frame
	local isJoin = toast.toastType == "join"
	local statusColor = if isJoin then Theme.Colors.Success else Theme.Colors.Destructive
	local statusText = if isJoin then "JOINED" else "LEFT"

	local currentIndex = scope:Value(index)
	local isEntering = scope:Value(true)
	local isExiting = scope:Value(false)
	local isDestroyed = false

	task.delay(ENTRY_DELAY, function()		if not isDestroyed then
			isEntering:set(false)
		end
	end)

	local function startExit()
		if isDestroyed or Fusion.peek(isExiting) then
			return
		end
		isExiting:set(true)
		task.delay(EXIT_DURATION, function()			if not isDestroyed then
				onRemoveComplete(toast.id)
			end
		end)
	end

	local targetX = scope:Computed(function(use: FusionUseFn)
		if use(isEntering) then
			return SLIDE_IN_OFFSET
		end
		if use(isExiting) then
			return SLIDE_IN_OFFSET
		end
		return 0
	end)

	local targetY = scope:Computed(function(use: FusionUseFn)
		return -((use(currentIndex) - 1) * TOAST_SLOT_HEIGHT)
	end)

	local targetOpacity = scope:Computed(function(use: FusionUseFn)
		if use(isExiting) then
			return 1
		end
		return 0
	end)

	local animatedX = scope:Spring(targetX, SPRING_SPEED, SPRING_DAMPING)
	local animatedY = scope:Spring(targetY, SPRING_SPEED, SPRING_DAMPING)
	local animatedOpacity = scope:Spring(targetOpacity, SPRING_SPEED, SPRING_DAMPING)

	local wrapper = scope:New("Frame")({
		Name = "ToastWrapper_" .. toast.id,
		Size = UDim2.fromOffset(TOAST_WIDTH + SHADOW_SPREAD * 2, TOAST_HEIGHT + SHADOW_SPREAD * 2),
		Position = scope:Computed(function(use: FusionUseFn)
			return UDim2.new(
				1, -PADDING_RIGHT + SHADOW_SPREAD + use(animatedX),
				1, -PADDING_BOTTOM + SHADOW_SPREAD + use(animatedY)
			)
		end),
		AnchorPoint = Vector2.one,
		BackgroundTransparency = 1,
		ZIndex = 100,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "ToastContent",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					Shadow(scope, {
						Size = UDim2.fromScale(1, 1),
						Position = UDim2.new(0.5, 0, 0.5, SHADOW_OFFSET_Y),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Spread = 0,
						Transparency = scope:Computed(function(use: FusionUseFn)
							return SHADOW_TRANSPARENCY + use(animatedOpacity) * 0.3
						end),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "Toast",
						Size = UDim2.fromOffset(TOAST_WIDTH, TOAST_HEIGHT),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Theme.Chat.Window.Background,
						BackgroundTransparency = scope:Computed(function(use: FusionUseFn)
							return Theme.Chat.Window.BackgroundTransparency + use(animatedOpacity) * 0.1
						end),
						ZIndex = 1,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.Medium,
							}),

							scope:New("UIStroke")({
								Color = Theme.Chat.Window.Border,
								Thickness = 1,
								Transparency = animatedOpacity,
							}),

							scope:New("ImageLabel")({
								Name = "Avatar",
								Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
								Position = UDim2.fromOffset(0, 0),
								BackgroundColor3 = Theme.Colors.Black[700],
								BackgroundTransparency = 0,
								Image = getAvatarUrl(toast.userId),
								ImageTransparency = animatedOpacity,
								ZIndex = 2,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.Medium,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "TextContainer",
								Size = UDim2.new(1, -(AVATAR_SIZE + 16), 1, 0),
								Position = UDim2.fromOffset(AVATAR_SIZE + 8, 0),
								BackgroundTransparency = 1,
								ZIndex = 2,

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Username",
										Size = UDim2.new(1, 0, 0, 16),
										Position = UDim2.new(0, 0, 0.5, -7),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										Text = toast.username,
										TextColor3 = Theme.Colors.White,
										TextTransparency = animatedOpacity,
										TextSize = 14,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),

									scope:New("TextLabel")({
										Name = "Status",
										Size = UDim2.new(1, 0, 0, 12),
										Position = UDim2.new(0, 0, 0.5, 8),
										AnchorPoint = Vector2.new(0, 0.5),
										BackgroundTransparency = 1,
										Text = "HAS " .. statusText,
										TextColor3 = statusColor,
										TextTransparency = animatedOpacity,
										TextSize = 10,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})

	return wrapper, {
		setIndex = function(newIndex: number)
			currentIndex:set(newIndex)
		end,
		startExit = startExit,
		destroy = function()
			isDestroyed = true
		end,
	}
end

type ToastController = {
	setIndex: (newIndex: number) -> (),
	startExit: () -> (),
	destroy: () -> (),
}

local function PlayerToast(scope: FusionScope, props: PlayerToastProps): ScreenGui
	local toastItems: { [string]: { frame: Frame, controller: ToastController, scope: any } } = {}
	local pendingRemovals: { [string]: boolean } = {}

	local container = scope:New("Frame")({
		Name = "ToastContainer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})

	local function removeToastFully(id: string)
		local item = toastItems[id]
		if item then
			item.controller.destroy()
			item.scope:doCleanup()
			toastItems[id] = nil
		end
		pendingRemovals[id] = nil
	end

	local function updateIndices(toasts: { ToastData })
		local visibleIndex = 0
		for _, toast in toasts do
			if not pendingRemovals[toast.id] then
				visibleIndex += 1
				local item = toastItems[toast.id]
				if item then
					item.controller.setIndex(visibleIndex)
				end
			end
		end
	end

	local function syncToasts(toasts: { ToastData })
		local currentIds: { [string]: boolean } = {}
		for _, toast in toasts do
			currentIds[toast.id] = true
		end

		for id, item in toastItems do
			if not currentIds[id] and not pendingRemovals[id] then
				pendingRemovals[id] = true
				item.controller.startExit()
			end
		end

		local visibleIndex = 0
		for _, toast in toasts do
			if not pendingRemovals[toast.id] then
				visibleIndex += 1
			end

			if not toastItems[toast.id] and not pendingRemovals[toast.id] then
				local itemScope = Fusion.scoped(Fusion)
				local frame, controller = ToastItem(
					itemScope,
					toast,
					visibleIndex,
					removeToastFully
				)
				frame.Parent = container
				toastItems[toast.id] = {
					frame = frame,
					controller = controller,
					scope = itemScope,
				}
			end
		end

		updateIndices(toasts)
	end

	scope:Observer(props.Toasts):onBind(function()
		local toasts = Fusion.peek(props.Toasts)
		syncToasts(toasts)
	end)

	table.insert(scope, function()
		for _, item in toastItems do
			item.controller.destroy()
			item.scope:doCleanup()
		end
		table.clear(toastItems)
	end)

	return scope:New("ScreenGui")({
		Name = "PlayerToast",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = props.Visible,

		[Fusion.Children] = {
			container,
		},
	})
end

return PlayerToast
