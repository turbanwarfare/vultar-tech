local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local Notify = require(script.Parent.Notify)
local StaffRanks = require(script.Parent.Shared.Permissions.StaffRanks)

local IS_PRIVATE_SERVER = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
local OWNER_LEVEL = StaffRanks.Levels[Config.PrivateServer.OwnerRank]

local rankStore = DataStoreService:GetDataStore(Config.DataStoreName)

local groupLevels: { [number]: number } = {}
local savedLevels: { [number]: number } = {}
local tempLevels: { [number]: number } = {}

local Ranks = {}

Ranks.GetName = StaffRanks.GetName

function Ranks.Get(player: Player): number
	return StaffRanks.GetLevel(player)
end

local function isStudioBlocked(err: any): boolean
	return tostring(err):find("Studio access to APIs is not allowed", 1, true) ~= nil
end

local function callAsync(callback: () -> any): (boolean, any)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(callback)
		if ok or attempt == 3 or isStudioBlocked(result) then
			break
		end
		task.wait(attempt)
	end
	return ok, result
end

local function levelForGroupRank(rank: number): number
	for _, range in Config.GroupRanks do
		if rank >= range.Min and rank <= range.Max then
			return StaffRanks.Levels[range.Rank]
		end
	end
	return 0
end

local function countsInThisServer(groupLevel: number): boolean
	return not IS_PRIVATE_SERVER or table.find(Config.PrivateServer.GroupRanks, StaffRanks.GetName(groupLevel)) ~= nil
end

local function fetchGroupLevelAsync(userId: number): number?
	local ok, result = callAsync(function()
		return GroupService:GetRolesInGroupAsync(userId, Config.GroupId)
	end)
	if not ok then
		warn(`[Cmdr] Couldn't load group roles for {userId}: {result}`)
		return nil
	end

	local best = 0
	for _, role in result.Roles or {} do
		local level = levelForGroupRank(role.Rank)
		if level > best and countsInThisServer(level) then
			best = level
		end
	end
	return best
end

local function fetchSavedLevelAsync(userId: number): number?
	local ok, data = callAsync(function()
		return rankStore:GetAsync(tostring(userId))
	end)
	if not ok then
		if isStudioBlocked(data) then
			return 0
		end
		warn(`[Cmdr] Couldn't load the saved rank for {userId}: {data}`)
		return nil
	end
	return if type(data) == "table" then StaffRanks.Levels[data.Rank] or 0 else 0
end

local function saveAsync(userId: number, level: number?, byUserId: number): (boolean, string?)
	local ok, err = callAsync(function()
		if level then
			rankStore:SetAsync(tostring(userId), {
				Rank = StaffRanks.GetName(level),
				By = byUserId,
				At = os.time(),
			}, { userId })
		else
			rankStore:RemoveAsync(tostring(userId))
		end
	end)
	if not ok then
		return false, tostring(err)
	end

	if Players:GetPlayerByUserId(userId) then
		savedLevels[userId] = level or 0
	end
	task.spawn(pcall, MessagingService.PublishAsync, MessagingService, Config.MessagingTopic, userId)
	return true, nil
end

local function computeLevel(userId: number): number
	local level = math.max(groupLevels[userId] or 0, tempLevels[userId] or 0)
	if not IS_PRIVATE_SERVER then
		level = math.max(level, savedLevels[userId] or 0)
	elseif userId == game.PrivateServerOwnerId then
		level = math.max(level, OWNER_LEVEL)
	end
	return level
end

local function refresh(player: Player)
	local oldLevel = Ranks.Get(player)
	local newLevel = computeLevel(player.UserId)
	if newLevel == oldLevel and player:GetAttribute(StaffRanks.Attribute) ~= nil then
		return
	end
	player:SetAttribute(StaffRanks.Attribute, newLevel)

	if newLevel > 0 then
		local name = StaffRanks.GetName(newLevel)
		local article = if name:match("^[AEIOU]") then "an" else "a"
		Notify.Banner(player, {
			Title = name,
			Text = `You're {if oldLevel > 0 then "now " else ""}{article} {name}. Press ; to open the command console.`,
			Icon = "alert",
			Duration = 10,
		})
	elseif oldLevel > 0 then
		Notify.Alert(player, "You're no longer staff.")
	end
end

local function refreshUser(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		refresh(player)
	end
end

local function loadPlayerAsync(player: Player)
	local userId = player.UserId
	local groupLevel = fetchGroupLevelAsync(userId)
	local savedLevel = if IS_PRIVATE_SERVER then 0 else fetchSavedLevelAsync(userId)
	if player.Parent ~= Players then
		return
	end

	groupLevels[userId] = groupLevel or 0
	savedLevels[userId] = savedLevel or 0
	refresh(player)
end

function Ranks.GetUserLevelAsync(userId: number): number?
	local player = Players:GetPlayerByUserId(userId)
	if player and groupLevels[userId] ~= nil then
		return Ranks.Get(player)
	end

	local groupLevel = fetchGroupLevelAsync(userId)
	local savedLevel = if IS_PRIVATE_SERVER then 0 else fetchSavedLevelAsync(userId)
	if groupLevel == nil or savedLevel == nil then
		return nil
	end

	local level = math.max(groupLevel, savedLevel, tempLevels[userId] or 0)
	if IS_PRIVATE_SERVER and userId == game.PrivateServerOwnerId then
		level = math.max(level, OWNER_LEVEL)
	end
	return level
end

function Ranks.CanTargetAsync(executor: Player, userId: number): (boolean, string?)
	if userId == executor.UserId then
		return true, nil
	end

	local level = Ranks.GetUserLevelAsync(userId)
	if level == nil then
		return false, "couldn't check their rank"
	end
	if level >= Ranks.Get(executor) then
		return false, `they're {StaffRanks.GetName(level)}`
	end
	return true, nil
end

function Ranks.GetUserNameAsync(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end

	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	return if ok then name else `#{userId}`
end

function Ranks.GrantCommand(context, userId: number, rankName: string, temp: boolean): string
	local executor = context.Executor
	local level = StaffRanks.Levels[rankName]
	local name = Ranks.GetUserNameAsync(userId)

	if userId == executor.UserId then
		return "You can't change your own rank."
	end

	local currentLevel = Ranks.GetUserLevelAsync(userId)
	if currentLevel == nil then
		return `Couldn't check {name}'s rank. Try again.`
	end
	if currentLevel >= Ranks.Get(executor) then
		return `You can't change {name}'s rank, they're {StaffRanks.GetName(currentLevel)}.`
	end

	if temp then
		if currentLevel >= level then
			return `{name} is already {StaffRanks.GetName(currentLevel)}.`
		end
		tempLevels[userId] = level
		refreshUser(userId)
		return `{name} is {rankName} until this server closes.`
	end

	local groupLevel = groupLevels[userId] or fetchGroupLevelAsync(userId)
	if groupLevel and groupLevel >= level then
		return `{name} already gets {StaffRanks.GetName(groupLevel)} from their group rank.`
	end

	local ok, err = saveAsync(userId, level, executor.UserId)
	if not ok then
		return `Couldn't save the rank ({err}). Add "temp" to give it for this server only.`
	end
	refreshUser(userId)

	if IS_PRIVATE_SERVER then
		return `Saved {rankName} for {name}. Saved ranks don't apply in private servers, so add "temp" to give it here.`
	end
	local player = Players:GetPlayerByUserId(userId)
	if player and Ranks.Get(player) > level then
		return `Saved {rankName} for {name}, but they're {StaffRanks.GetName(Ranks.Get(player))} until this server closes.`
	end
	return `{name} is now {rankName}.`
end

function Ranks.RevokeCommand(context, userId: number, rankName: string): string
	local level = StaffRanks.Levels[rankName]
	local name = Ranks.GetUserNameAsync(userId)

	if userId == context.Executor.UserId then
		return "You can't change your own rank."
	end

	local removed = false
	if tempLevels[userId] == level then
		tempLevels[userId] = nil
		removed = true
	end

	local savedLevel = fetchSavedLevelAsync(userId)
	if savedLevel == level then
		local ok, err = saveAsync(userId, nil, context.Executor.UserId)
		if not ok then
			refreshUser(userId)
			return `Couldn't remove {name}'s saved rank ({err}). Try again.`
		end
		removed = true
	end
	refreshUser(userId)

	if not removed then
		if savedLevel == nil then
			return `Couldn't check {name}'s saved rank. Try again.`
		end
		return `{name} wasn't given {rankName} with a rank command. Ranks from the group have to be changed in the group.`
	end

	local player = Players:GetPlayerByUserId(userId)
	if player and Ranks.Get(player) > 0 then
		return `{name} is no longer {rankName}, but is still {StaffRanks.GetName(Ranks.Get(player))}.`
	end
	return `{name} is no longer {rankName}.`
end

function Ranks.Start()
	Players.PlayerAdded:Connect(loadPlayerAsync)
	Players.PlayerRemoving:Connect(function(player)
		groupLevels[player.UserId] = nil
		savedLevels[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayerAsync, player)
	end

	if IS_PRIVATE_SERVER then
		return
	end

	task.spawn(function()
		local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, Config.MessagingTopic, function(message)
			local userId = tonumber(message.Data)
			local player = userId and Players:GetPlayerByUserId(userId)
			if not player then
				return
			end

			local savedLevel = fetchSavedLevelAsync(userId)
			if savedLevel ~= nil and player.Parent == Players then
				savedLevels[userId] = savedLevel
				refresh(player)
			end
		end)
		if not ok then
			warn(`[Cmdr] Couldn't listen for rank changes from other servers: {err}`)
		end
	end)
end

return Ranks
