local Vultar = require(script:FindFirstAncestor("Commands").Parent.Vultar)

return function(context): string
	local phaseService = Vultar.GetService("PhaseService")
	if not phaseService or not phaseService:IsActive() then
		return "The phase system isn't active on this map."
	end
	if not phaseService:IsOfficial() then
		return "No phase game is running."
	end

	local phase = phaseService:GetCurrentPhase()
	if phase == "phase3" then
		return "You can't skip the final phase. Use :end in chat to end the event."
	end
	if phase == "idle" or phase == "ended" then
		return "No phase game is running."
	end

	phaseService:SkipPhase(context.Executor)
	return "Skipped to the next phase."
end
