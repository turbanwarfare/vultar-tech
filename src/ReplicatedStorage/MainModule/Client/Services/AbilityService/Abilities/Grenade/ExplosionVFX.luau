--!strict
--!native
--!optimize 2

local ExplosionVFX = {}

local SOUND = "rbxassetid://4550582204"
local SOUND_DISTANCE = 80
local BLAST_RADIUS = 6
local LIFETIME = 10

function ExplosionVFX.play(position: Vector3): ()
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastPressure = 0
	explosion.BlastRadius = BLAST_RADIUS
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace

	local holder = Instance.new("Attachment")
	holder.Name = "GrenadeExplosion"
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = SOUND
	sound.Volume = 2
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = SOUND_DISTANCE
	sound.Parent = holder
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()

	task.delay(LIFETIME, explosion.Destroy, explosion)
	task.delay(LIFETIME, holder.Destroy, holder)
end

return ExplosionVFX
