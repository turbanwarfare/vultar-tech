--!strict
--!native
--!optimize 2

local FeedbackPools = require(script.FeedbackPools)
local FeedbackSounds = require(script.FeedbackSounds)
local FeedbackHitmarker = require(script.FeedbackHitmarker)
local FeedbackKillIndicator = require(script.FeedbackKillIndicator)
local FeedbackIndicators = require(script.Indicators)
local FeedbackHighlights = require(script.FeedbackHighlights)
local FeedbackBlood = require(script.FeedbackBlood)

local Cache = require(script.Parent.Cache)
local Profile = require(script.Parent.Parent.Parent.Parent.Shared.Utils.Debug.Profile)

local Feedback = {}

function Feedback.init(): ()
	FeedbackSounds.init()
	FeedbackHitmarker.createUI()
	FeedbackKillIndicator.createUI()
	FeedbackPools.init()
	FeedbackHighlights.init()
	FeedbackBlood.init()

	FeedbackIndicators.setDamageLabelGetter(FeedbackHitmarker.getDamageLabel)
end

function Feedback.showHit(hit: { target: Humanoid, damage: number, head: boolean, pos: Vector3, normal: Vector3, hitPart: BasePart, gunName: string? }): ()
	task.defer(FeedbackSounds.playHit, hit.head, hit.gunName)
	if hit.gunName ~= "GPR" then
		FeedbackHitmarker.animate(hit.head)
	end
	FeedbackHighlights.showDamage(hit.hitPart, hit.head)
	FeedbackBlood.show(hit.pos, hit.normal)

	if not Cache.getDamageIndicatorsEnabled() then
		return
	end

	local indicatorType = Cache.getDamageIndicatorType()
	local stickTo = Cache.getDamageIndicatorStickTo()
	local character = if hit.target then hit.target.Parent :: Model? else nil
	local rootPart: BasePart? = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

	if indicatorType == 2 then
		if stickTo == 2 then
			FeedbackIndicators.showStackAtCursor(hit.damage)
		else
			FeedbackIndicators.showStackAtPlayer(hit.damage, hit.head, hit.hitPart, character, rootPart)
		end
	else
		if stickTo == 2 then
			FeedbackIndicators.showExpandAtCursor(hit.damage, hit.head)
		else
			FeedbackIndicators.showExpand(hit.damage, hit.head, hit.hitPart, character)
		end
	end
end

function Feedback.showShieldHit(damage: number, hitPart: BasePart, gunName: string?): ()
	task.defer(FeedbackSounds.playHit, false, gunName)
	if gunName ~= "GPR" then
		FeedbackHitmarker.animate(false)
	end

	if not Cache.getDamageIndicatorsEnabled() then
		return
	end

	local indicatorType = Cache.getDamageIndicatorType()
	local stickTo = Cache.getDamageIndicatorStickTo()

	pcall(function()
		if indicatorType == 2 then
			if stickTo == 2 then
				FeedbackIndicators.showStackAtCursor(damage)
			else
				FeedbackIndicators.showStackAtPlayer(damage, false, hitPart, nil)
			end
		else
			if stickTo == 2 then
				FeedbackIndicators.showExpandAtCursor(damage, false)
			else
				FeedbackIndicators.showExpand(damage, false, hitPart, nil)
			end
		end
	end)
end

function Feedback.showHeal(healData: { healAmount: number, pos: Vector3, hitPart: BasePart, target: Humanoid }): ()
	if not Cache.getHealNumberIndicatorsEnabled() then
		return
	end

	local character = healData.target.Parent :: Model?
	local rootPart: BasePart? = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local indicatorType = Cache.getHealIndicatorType()

	if indicatorType == 2 and character then
		FeedbackIndicators.showHealStackAtPlayer(healData.healAmount, healData.hitPart, character, rootPart)
	else
		FeedbackIndicators.showHealExpand(healData.healAmount, healData.pos, character)
	end
end

function Feedback.playKillSound(): ()
	FeedbackSounds.playKill()
end

function Feedback.showKill(victimRootPart: BasePart?, gunName: string?): ()
	if gunName ~= "GPR" then
		FeedbackSounds.playKill()
		FeedbackKillIndicator.show(victimRootPart)
	end

	if Cache.getDamageIndicatorsEnabled() and Cache.getStackKillFlash() then
		local indicatorType = Cache.getDamageIndicatorType()
		local stickTo = Cache.getDamageIndicatorStickTo()
		if indicatorType == 2 and stickTo == 2 then
			FeedbackIndicators.flashKillAtCursor()
		end
	end
end

function Feedback.clearActive(): ()
	FeedbackIndicators.clearActive()
end

function Feedback.cleanup(): ()
	FeedbackIndicators.cleanup()
	FeedbackHitmarker.cleanup()
	FeedbackKillIndicator.cleanup()
	FeedbackSounds.cleanup()
	FeedbackHighlights.cleanup()
	FeedbackBlood.cleanup()
	FeedbackPools.cleanup()
end

Feedback.showHit = Profile.wrap("Vultar::Feedback::showHit", Feedback.showHit)
Feedback.showShieldHit = Profile.wrap("Vultar::Feedback::showShieldHit", Feedback.showShieldHit)
Feedback.showHeal = Profile.wrap("Vultar::Feedback::showHeal", Feedback.showHeal)
Feedback.showKill = Profile.wrap("Vultar::Feedback::showKill", Feedback.showKill)

return Feedback
