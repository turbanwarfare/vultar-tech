--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local RaidLeaderService = {}
RaidLeaderService.Name = "RaidLeaderService"

local chatService: any = nil

function RaidLeaderService:SetRaidLeader(player: Player, isLeader: boolean): ()
	if chatService then
		chatService:SetRaidLeader(player, isLeader)
	end
end

function RaidLeaderService:IsRaidLeader(player: Player): boolean
	if chatService then
		return chatService:IsRaidLeader(player)
	end
	return false
end

function RaidLeaderService:init(): ()
end

function RaidLeaderService:start(): ()
	chatService = LazyService.create(MainModule, "ChatService")()
end

return RaidLeaderService
