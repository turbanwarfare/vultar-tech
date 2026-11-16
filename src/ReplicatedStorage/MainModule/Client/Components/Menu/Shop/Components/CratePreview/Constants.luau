--!strict
--!native
--!optimize 2

local Constants = {}

Constants.PANEL_BG = Color3.fromRGB(20, 20, 20)
Constants.PANEL_BG_TRANSPARENCY = 0.25
Constants.PANEL_BORDER = Color3.fromRGB(140, 140, 160)

Constants.TITLE_TEXT = Color3.fromRGB(226, 226, 226)
Constants.MUTED_TEXT = Color3.fromRGB(125, 125, 125)
Constants.SUBTLE_TEXT = Color3.fromRGB(168, 168, 168)
Constants.TYPE_TEXT = Color3.fromRGB(127, 127, 127)
Constants.PRICE_COLOR = Color3.fromRGB(255, 185, 20)

Constants.HEADER_HEIGHT = 36
Constants.HEADER_TEXT_INSET = 14

Constants.LEFT_COLUMN_WIDTH = 340
Constants.COLUMN_GAP = 18

Constants.PRICE_ROW_HEIGHT = 44
Constants.OPEN_BUTTON_HEIGHT = 46
Constants.AMOUNT_BOX_WIDTH = 64

Constants.CHANCE_ROW_HEIGHT = 34
Constants.CHANCE_ROW_GAP = 6

Constants.DROP_CARD_WIDTH = 135
Constants.DROP_CARD_HEIGHT = 145
Constants.DROP_CARD_GAP = 8
Constants.DROP_FOOTER_HEIGHT = 46

Constants.OPEN_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 255, 66)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 255, 116)),
})

Constants.PANEL_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 178, 178)),
})

Constants.ART_FADE_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.875),
	NumberSequenceKeypoint.new(0.385, 0.9375),
	NumberSequenceKeypoint.new(0.623, 1),
	NumberSequenceKeypoint.new(1, 1),
})

Constants.OPEN_BUTTON_STROKE = Color3.fromRGB(101, 133, 171)

return Constants
