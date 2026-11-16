local Package = script:FindFirstAncestor("Commands").Parent
local Notify = require(Package.Notify)
local Ranks = require(Package.Ranks)
local Reply = require(Package.Reply)
local Vultar = require(Package.Vultar)

return function(context, players: { Player }): string
	local classService = Vultar.GetService("ClassService")
	if not classService then
		return "The class system isn't available in this place."
	end

	local reset, skipped = {}, {}
	for _, player in players do
		local allowed, why = Ranks.CanTargetAsync(context.Executor, player.UserId)
		if not allowed then
			table.insert(skipped, `{player.Name} ({why})`)
		elseif classService:GetPlayerClass(player) == "Assault" then
			table.insert(skipped, `{player.Name} (already on Assault)`)
		elseif classService:SetPlayerClass(player, "Assault") then
			Notify.Alert(player, "Your class has been reset to Assault.")
			table.insert(reset, player.Name)
		else
			table.insert(skipped, `{player.Name} (couldn't reset their class)`)
		end
	end
	return Reply.Summary("Reset to Assault", reset, skipped)
end
