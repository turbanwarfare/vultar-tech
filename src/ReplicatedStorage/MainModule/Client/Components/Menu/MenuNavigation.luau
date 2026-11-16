--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Signal = require(MainModule.Shared.Utils.State.Signal)

export type Target = "Crates" | "BuyCredits"

local MenuNavigation = {}

MenuNavigation.Requested = Signal.new() :: Signal.Signal<Target>

local pendingTarget: Target? = nil
local pendingBuyCredits = false

function MenuNavigation.request(target: Target): ()
	pendingTarget = target
	if target == "BuyCredits" then
		pendingBuyCredits = true
	end
	MenuNavigation.Requested:Fire(target)
end

function MenuNavigation.takeTarget(): Target?
	local target = pendingTarget
	pendingTarget = nil
	return target
end

function MenuNavigation.consumeBuyCredits(): boolean
	local pending = pendingBuyCredits
	pendingBuyCredits = false
	return pending
end

return MenuNavigation
