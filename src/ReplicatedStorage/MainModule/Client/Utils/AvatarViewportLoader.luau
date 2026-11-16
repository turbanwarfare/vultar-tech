--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local AvatarViewportLoader = {}

function AvatarViewportLoader.loadFromUserId(userId: number): Model?
	if userId <= 0 then
		return nil
	end

	local success, model = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)

	if not success or not model then
		return nil
	end

	AvatarViewportLoader.sanitizeModel(model)
	return model
end

local cachedModels: { [number]: Model } = {}

function AvatarViewportLoader.loadCachedFromUserId(userId: number): Model?
	local template = cachedModels[userId]
	if not template then
		local loaded = AvatarViewportLoader.loadFromUserId(userId)
		if not loaded then
			return nil
		end
		cachedModels[userId] = loaded
		template = loaded
	end
	return template:Clone()
end

function AvatarViewportLoader.clearCache(): ()
	for _, model in cachedModels do
		model:Destroy()
	end
	table.clear(cachedModels)
end

function AvatarViewportLoader.sanitizeModel(model: Model): ()
	model.Name = "AvatarPreview"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local scriptToRemove = model:FindFirstChildWhichIsA("BaseScript", true)
	while scriptToRemove do
		scriptToRemove:Destroy()
		scriptToRemove = model:FindFirstChildWhichIsA("BaseScript", true)
	end
end

return AvatarViewportLoader
