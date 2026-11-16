local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StaffRanks = require(script.StaffRanks)

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local required = StaffRanks.GetRequiredLevel(context.Group)
		if not context.Executor or StaffRanks.GetLevel(context.Executor) < required then
			return `You need to be {StaffRanks.GetName(required)} or higher to use this command.`
		end
	end)

	if RunService:IsServer() then
		registry:RegisterHook("AfterRun", function(context)
			print(`[Cmdr] {context.Executor.Name}: {context.RawText}`)
		end)
		return
	end

	local player = Players.LocalPlayer

	registry:RegisterHook("BeforeCommandRegister", function(context)
		if StaffRanks.GetLevel(player) < StaffRanks.GetRequiredLevel(context.Group) then
			return false
		end
	end)

	local function update()
		registry.Cmdr:SetEnabled(StaffRanks.GetLevel(player) > 0)
		registry.Cmdr.Dispatcher:RunBeforeCommandRegisterHooks()
	end

	player:GetAttributeChangedSignal(StaffRanks.Attribute):Connect(update)
	update()
end
