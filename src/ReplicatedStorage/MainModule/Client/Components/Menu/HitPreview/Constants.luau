--!strict
--!native
--!optimize 2

local Constants = {}

Constants.HEAD_PARTS = { "Head" }

Constants.BODY_DAMAGE = 14
Constants.HEAD_DAMAGE = 16
Constants.FIRE_RATE = 0.1

Constants.HITMARKER_SIZE = 32
Constants.HITMARKER_HOLD_TIME = 0.08
Constants.HITMARKER_FADE_TIME = 0.12
Constants.HITMARKER_ROTATION_SPEED = 180
Constants.HITMARKER_SPEED_MULTIPLIERS = { 0.5, 1.0, 2.0 }

Constants.GOLDEN_ANGLE = 137.507764
Constants.PHI = 1.6180339887

Constants.CURSOR_EXPAND_DURATION = 0.85
Constants.CURSOR_EXPAND_SPEED = 160
Constants.CURSOR_EXPAND_FADE_START = 0.6
Constants.CURSOR_EXPAND_OFFSET = 45
Constants.CURSOR_EXPAND_GRAVITY = 30

Constants.EXPAND_POP_DURATION = 0.11
Constants.EXPAND_SETTLE_DURATION = 0.055
Constants.EXPAND_OVERSHOOT_SCALE = 1.15

Constants.HIGHLIGHT_DEBOUNCE = 0.08

Constants.STACK_TIMEOUT = 1.2
Constants.STACK_POP_DURATION = 0.11
Constants.STACK_SETTLE_DURATION = 0.055
Constants.STACK_SHRINK_DURATION = 0.13
Constants.STACK_PULSE_UP_DURATION = 0.08
Constants.STACK_PULSE_DOWN_DURATION = 0.12
Constants.STACK_OVERSHOOT_SCALE = 1.15
Constants.STACK_OFFSET_X = 35
Constants.STACK_OFFSET_Y = -25

Constants.PLAYER_EXPAND_SPREAD = 100
Constants.PLAYER_STACK_ABOVE_HEAD = 1.2
Constants.PLAYER_STACK_RIGHT_OFFSET = 70

Constants.KILL_INDICATOR_TOTAL_LIFETIME = 1.5

Constants.TWEEN_STACK_POP = TweenInfo.new(Constants.STACK_POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Constants.TWEEN_STACK_SETTLE = TweenInfo.new(Constants.STACK_SETTLE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Constants.TWEEN_STACK_SHRINK = TweenInfo.new(Constants.STACK_SHRINK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Constants.TWEEN_STACK_PULSE_UP = TweenInfo.new(Constants.STACK_PULSE_UP_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
Constants.TWEEN_STACK_PULSE_DOWN = TweenInfo.new(Constants.STACK_PULSE_DOWN_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

return Constants
