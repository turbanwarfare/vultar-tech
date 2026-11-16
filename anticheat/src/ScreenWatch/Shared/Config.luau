--!strict

local ScreenWatchConfig = {}

ScreenWatchConfig.CameraSampleHz = 60
ScreenWatchConfig.CursorSampleHz = 60

ScreenWatchConfig.RecordingBufferSeconds = 30
ScreenWatchConfig.KeyHistoryMaxEntries = 100
ScreenWatchConfig.HitHistoryMaxEntries = 100

ScreenWatchConfig.FlaggedKeycodes = {
	Enum.KeyCode.Insert,
	Enum.KeyCode.Delete,
	Enum.KeyCode.Home,
	Enum.KeyCode.End,
	Enum.KeyCode.PageUp,
	Enum.KeyCode.PageDown,
	Enum.KeyCode.F1,
	Enum.KeyCode.F2,
	Enum.KeyCode.F3,
	Enum.KeyCode.F4,
	Enum.KeyCode.F5,
	Enum.KeyCode.F6,
	Enum.KeyCode.F7,
	Enum.KeyCode.F8,
	Enum.KeyCode.F9,
	Enum.KeyCode.F10,
	Enum.KeyCode.F11,
	Enum.KeyCode.F12,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.RightAlt,
	Enum.KeyCode.KeypadZero,
	Enum.KeyCode.KeypadOne,
	Enum.KeyCode.KeypadTwo,
	Enum.KeyCode.KeypadThree,
	Enum.KeyCode.KeypadFour,
	Enum.KeyCode.KeypadFive,
	Enum.KeyCode.KeypadSix,
	Enum.KeyCode.KeypadSeven,
	Enum.KeyCode.KeypadEight,
	Enum.KeyCode.KeypadNine,
	Enum.KeyCode.KeypadPeriod,
	Enum.KeyCode.KeypadDivide,
	Enum.KeyCode.KeypadMultiply,
	Enum.KeyCode.KeypadMinus,
	Enum.KeyCode.KeypadPlus,
	Enum.KeyCode.KeypadEnter,
} :: { Enum.KeyCode }

ScreenWatchConfig.TrackedMovementKeycodes = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.F,
	Enum.KeyCode.C,
	Enum.KeyCode.Q,
	Enum.KeyCode.R,
	Enum.KeyCode.Space,
} :: { Enum.KeyCode }

return ScreenWatchConfig
