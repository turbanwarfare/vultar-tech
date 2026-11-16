--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local AbilityConfig = require(MainModule.Shared.Config.AbilityConfig)

local Stats = AbilityConfig.Abilities.Roll.Stats

local TRAIL_PARTS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local TRAIL_COLOR = ColorSequence.new(Color3.new(1, 1, 1))
local TRAIL_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
local TRAIL_WIDTH = NumberSequence.new(Stats.TRAIL_WIDTH, 0)

local Roll = {}

local function addTrail(part: BasePart): ()
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = part

	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = TRAIL_COLOR
	trail.Transparency = TRAIL_TRANSPARENCY
	trail.WidthScale = TRAIL_WIDTH
	trail.Lifetime = Stats.TRAIL_LIFETIME
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = part

	task.delay(Stats.DURATION, function()
		trail.Enabled = false
	end)
	local cleanupTime = Stats.DURATION + Stats.TRAIL_LIFETIME
	task.delay(cleanupTime, trail.Destroy, trail)
	task.delay(cleanupTime, top.Destroy, top)
	task.delay(cleanupTime, bottom.Destroy, bottom)
end

function Roll.use(_player: Player, character: Model): ()
	for _, name in TRAIL_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			addTrail(part)
		end
	end
end

return Roll
