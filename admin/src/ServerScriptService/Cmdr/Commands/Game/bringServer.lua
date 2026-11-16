local Package = script:FindFirstAncestor("Commands").Parent
local Reply = require(Package.Reply)
local Teleport = require(Package.Teleport)

return function(context, players: { Player }): string
	local executor = context.Executor
	local character = executor.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return "You don't have a character."
	end

	local brought, skipped = {}, {}
	for _, player in players do
		local targetCharacter = player.Character
		if player == executor then
			continue
		elseif targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") then
			Teleport(targetCharacter, character:GetPivot())
			table.insert(brought, player.Name)
		else
			table.insert(skipped, `{player.Name} (no character)`)
		end
	end
	return Reply.Summary("Brought", brought, skipped)
end
