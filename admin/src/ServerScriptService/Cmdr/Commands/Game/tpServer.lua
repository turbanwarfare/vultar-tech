local Teleport = require(script:FindFirstAncestor("Commands").Parent.Teleport)

return function(context, target: Player): string
	local character = context.Executor.Character
	local targetCharacter = target.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return "You don't have a character."
	end
	if not (targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")) then
		return `{target.Name} doesn't have a character.`
	end

	Teleport(character, targetCharacter:GetPivot())
	return `Teleported to {target.Name}.`
end
