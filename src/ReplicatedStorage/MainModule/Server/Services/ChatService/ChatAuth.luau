--!strict
--!native
--!optimize 2

local ChatConfig = require(script.Parent.Parent.Parent.Parent.Shared.Config.Chat.ChatConfig)
local ChatTypes = require(script.Parent.Parent.Parent.Parent.Shared.Network.Chat.Types)
local RankCache = require(script.Parent.Parent.Parent.Cache.RankCache)

type ChannelId = ChatTypes.ChannelId
type PlayerChatData = ChatTypes.PlayerChatData

local ChatAuth = {}

local playerChatDataCache: { [Player]: PlayerChatData } = {}
local raidLeaders: { [Player]: boolean } = {}
local mutedPlayers: { [Player]: boolean } = {}

local sortedTags: typeof(ChatConfig.Tags) = {}
local sortedRoles: typeof(ChatConfig.Roles) = {}
local channelRequirementsCache: { [ChannelId]: { [string]: any } } = {}

local function initSortedData()
	sortedTags = table.clone(ChatConfig.Tags)
	table.sort(sortedTags, function(a, b)
		return a.priority > b.priority
	end)

	sortedRoles = table.clone(ChatConfig.Roles)
	table.sort(sortedRoles, function(a, b)
		return a.rank > b.rank
	end)

	for channelId, requirement in ChatConfig.ChannelRequirements do
		channelRequirementsCache[channelId :: ChannelId] = requirement
	end
end

initSortedData()

local function checkRequirement(player: Player, requirement: { [string]: any }): boolean
	local reqType = requirement.type

	if reqType == "all" then
		return true
	end

	if reqType == "rank" then
		local rank = RankCache.getPlayerRank(player, requirement.groupId)
		return rank >= requirement.minRank
	end

	if reqType == "ranks" then
		local rank = RankCache.getPlayerRank(player, requirement.groupId)
		local ranks = requirement.ranks
		for _, r in ranks do
			if r == rank then
				return true
			end
		end
		return false
	end

	if reqType == "group" then
		return RankCache.isInGroup(player, requirement.groupId)
	end

	if reqType == "any" then
		for _, option in requirement.requirements do
			if checkRequirement(player, option) then
				return true
			end
		end
		return false
	end

	if reqType == "raidleader" then
		return raidLeaders[player] == true
	end

	if reqType == "raid" then
		if raidLeaders[player] == true then
			return true
		end
		return RankCache.isInGroup(player, ChatConfig.MAIN_GROUP_ID, 50)
	end

	if reqType == "whitelist" then
		local userIds = requirement.userIds
		local targetId = player.UserId
		for _, id in userIds do
			if id == targetId then
				return true
			end
		end
		return false
	end

	if reqType == "user" then
		return player.UserId == requirement.userId
	end

	return false
end

function ChatAuth.canAccessChannel(player: Player, channelId: ChannelId): boolean
	local requirement = channelRequirementsCache[channelId]
	if not requirement then
		return false
	end
	return checkRequirement(player, requirement)
end

function ChatAuth.getVisibleChannels(player: Player): { ChannelId }
	local channels: { ChannelId } = {}

	for _, channel in ChatConfig.Channels do
		local channelId = channel.id :: ChannelId
		if ChatAuth.canAccessChannel(player, channelId) then
			table.insert(channels, channelId)
		end
	end

	return channels
end

function ChatAuth.getPlayerTags(player: Player): { string }
	local tags: { string } = {}

	for _, tag in sortedTags do
		if checkRequirement(player, tag.requirement) then
			table.insert(tags, tag.id)
		end
	end

	return tags
end

function ChatAuth.getPlayerNameColor(player: Player): Color3?
	for _, colorConfig in ChatConfig.NameColors do
		if checkRequirement(player, colorConfig.requirement) then
			return colorConfig.color
		end
	end
	return nil
end

function ChatAuth.getPlayerRole(player: Player): (string?, Color3?)
	for _, role in sortedRoles do
		local rank = RankCache.getPlayerRank(player, role.groupId)
		if rank == role.rank then
			return role.prefix, role.color
		end
	end

	for _, role in sortedRoles do
		local rank = RankCache.getPlayerRank(player, role.groupId)
		if rank > 0 and rank >= role.rank then
			return role.prefix, role.color
		end
	end

	return nil, nil
end

function ChatAuth.getPlayerChatData(player: Player): PlayerChatData
	local cached = playerChatDataCache[player]
	if cached and (raidLeaders[player] == true) == cached.isRaidLeader then
		local newChannels = ChatAuth.getVisibleChannels(player)
		if #newChannels == #cached.visibleChannels then
			local same = true
			for i, ch in newChannels do
				if cached.visibleChannels[i] ~= ch then
					same = false
					break
				end
			end
			if same then
				return cached
			end
		end
	end

	local rolePrefix, roleColor = ChatAuth.getPlayerRole(player)

	local data: PlayerChatData = {
		visibleChannels = ChatAuth.getVisibleChannels(player),
		tags = ChatAuth.getPlayerTags(player),
		nameColor = ChatAuth.getPlayerNameColor(player),
		rolePrefix = rolePrefix,
		roleColor = roleColor,
		isRaidLeader = raidLeaders[player] == true,
	}

	playerChatDataCache[player] = data
	return data
end

function ChatAuth.setRaidLeader(player: Player, isLeader: boolean): ()
	raidLeaders[player] = if isLeader then true else nil
	playerChatDataCache[player] = nil
end

function ChatAuth.isRaidLeader(player: Player): boolean
	return raidLeaders[player] == true
end

function ChatAuth.clearPlayerCache(player: Player): ()
	RankCache.clearPlayerCache(player)
	playerChatDataCache[player] = nil
	raidLeaders[player] = nil
	mutedPlayers[player] = nil
end

function ChatAuth.refreshPlayerCache(player: Player): ()
	RankCache.clearPlayerCache(player)
	playerChatDataCache[player] = nil
end

function ChatAuth.getAdminLevel(player: Player): number
	return RankCache.getPlayerRank(player, ChatConfig.MAIN_GROUP_ID)
end

function ChatAuth.canMutePlayer(admin: Player, target: Player): boolean
	local adminLevel = ChatAuth.getAdminLevel(admin)
	if adminLevel < 80 then
		return false
	end
	return adminLevel > ChatAuth.getAdminLevel(target)
end

function ChatAuth.mutePlayer(player: Player): ()
	mutedPlayers[player] = true
end

function ChatAuth.unmutePlayer(player: Player): ()
	mutedPlayers[player] = nil
end

function ChatAuth.isPlayerMuted(player: Player): boolean
	return mutedPlayers[player] == true
end

return ChatAuth
