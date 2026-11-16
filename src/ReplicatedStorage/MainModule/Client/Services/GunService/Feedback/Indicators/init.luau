--!strict
--!native
--!optimize 2

local WorldIndicators = require(script.WorldIndicators)
local CursorExpandIndicators = require(script.CursorExpandIndicators)
local StackIndicators = require(script.StackIndicators)

local FeedbackIndicators = {}

function FeedbackIndicators.showExpand(damage: number, isHead: boolean, hitPart: BasePart?, character: Model?): ()
	WorldIndicators.showExpand(damage, isHead, hitPart, character)
end

function FeedbackIndicators.showHealExpand(healAmount: number, hitPos: Vector3, character: Model?): ()
	WorldIndicators.showHealExpand(healAmount, hitPos, character)
end

function FeedbackIndicators.showHealStackAtPlayer(healAmount: number, hitPart: BasePart?, character: Model, rootPartHint: BasePart?): ()
	StackIndicators.showHealStackAtPlayer(healAmount, hitPart, character, rootPartHint)
end

function FeedbackIndicators.showExpandAtCursor(damage: number, isHead: boolean): ()
	CursorExpandIndicators.showExpandAtCursor(damage, isHead)
end

function FeedbackIndicators.showStackAtPlayer(damage: number, isHead: boolean, hitPart: BasePart?, character: Model, rootPartHint: BasePart?): ()
	StackIndicators.showStackAtPlayer(damage, isHead, hitPart, character, rootPartHint)
end

function FeedbackIndicators.showStackAtCursor(damage: number): ()
	StackIndicators.showStackAtCursor(damage)
end

function FeedbackIndicators.setDamageLabelGetter(getter: () -> TextLabel?): ()
	StackIndicators.setDamageLabelGetter(getter)
end

function FeedbackIndicators.flashKillAtCursor(): ()
	StackIndicators.flashKillAtCursor()
end

function FeedbackIndicators.clearActive(): ()
	WorldIndicators.clearActive()
	CursorExpandIndicators.clearActive()
end

function FeedbackIndicators.cleanup(): ()
	WorldIndicators.cleanup()
	CursorExpandIndicators.cleanup()
	StackIndicators.cleanup()
end

return FeedbackIndicators
