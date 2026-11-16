--!strict
--!native
--!optimize 2

type PromptHandler = (gamepassId: number) -> ()

local PurchaseRedirectController = {}

local activePromptHandler: PromptHandler? = nil

function PurchaseRedirectController.setPromptHandler(handler: PromptHandler): ()
	activePromptHandler = handler
end

function PurchaseRedirectController.clearPromptHandler(handler: PromptHandler): ()
	if activePromptHandler == handler then
		activePromptHandler = nil
	end
end

function PurchaseRedirectController.promptPurchase(gamepassId: number): ()
	if gamepassId <= 0 then
		return
	end

	if activePromptHandler then
		activePromptHandler(gamepassId)
	else
		warn(`No shop purchase redirect prompt is registered for gamepass {gamepassId}`)
	end
end

return PurchaseRedirectController
