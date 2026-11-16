--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Signal = require(MainModule.Shared.Utils.State.Signal)

local ArenaUIService = {}

local MAX_CHANGE_FEED_ENTRIES = 50

local changeFeedEntries: { { player: string, action: string, value: string } } = {}
local changeFeedUpdated = Signal.new()

local function addChangeFeedEntry(player: Player, action: string, value: string)
	local entry = {
		player = player.Name,
		action = action,
		value = value,
	}

	local count = #changeFeedEntries
	if count >= MAX_CHANGE_FEED_ENTRIES then
		table.move(changeFeedEntries, 2, count, 1)
		changeFeedEntries[count] = entry
	else
		table.insert(changeFeedEntries, entry)
	end

	changeFeedUpdated:Fire()
end

function ArenaUIService.broadcastChange(_arenaNumber: number, player: Player, optionType: string, value: any)
	addChangeFeedEntry(player, optionType, tostring(value))
end

function ArenaUIService.getChangeFeed(): { { player: string, action: string, value: string } }
	return changeFeedEntries
end

function ArenaUIService.OnChangeFeedUpdated(callback: () -> ()): Signal.Connection
	return changeFeedUpdated:Connect(callback)
end

function ArenaUIService.cleanup()
	table.clear(changeFeedEntries)
	changeFeedUpdated:Destroy()
end

return ArenaUIService
