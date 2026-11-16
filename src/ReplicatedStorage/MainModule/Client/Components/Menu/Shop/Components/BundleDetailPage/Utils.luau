--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local ChatConfig = require(MainModule.Shared.Config.Chat.ChatConfig)

local rng = Random.new()

local FALLBACK_WHITE_SEQUENCE = ColorSequence.new(Color3.new(1, 1, 1))

local Utils = {}

function Utils.convertGradientColors(colors: { Color3 }): ColorSequence
	local colorCount = #colors
	if colorCount < 2 then
		return FALLBACK_WHITE_SEQUENCE
	end

	local keypoints: { ColorSequenceKeypoint } = {}
	if colorCount == 7 then
		keypoints = {
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.18, colors[2]),
			ColorSequenceKeypoint.new(0.35, colors[3]),
			ColorSequenceKeypoint.new(0.50, colors[4]),
			ColorSequenceKeypoint.new(0.65, colors[5]),
			ColorSequenceKeypoint.new(0.82, colors[6]),
			ColorSequenceKeypoint.new(1, colors[7]),
		}
	else
		for i, color in ipairs(colors) do
			local position = (i - 1) / (colorCount - 1)
			table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
		end
	end

	return ColorSequence.new(keypoints)
end

function Utils.getPlayerTags(): { string }
	local tags: { string } = {}
	local player = LocalPlayer

	for _, tag in ChatConfig.Tags do
		if tag.requirement then
			local req = tag.requirement
			if req.type == "group" then
				local success, rank = pcall(function()
					return player:GetRankInGroup(req.groupId)
				end)
				if success and rank and rank > 0 then
					table.insert(tags, tag.id)
				end
			elseif req.type == "ranks" then
				local success, rank = pcall(function()
					return player:GetRankInGroup(req.groupId)
				end)
				if success and rank then
					for _, r in req.ranks do
						if r == rank then
							table.insert(tags, tag.id)
							break
						end
					end
				end
			end
		end
	end

	return tags
end

function Utils.getPlayerRole(): (string?, Color3?)
	local player = LocalPlayer

	for _, role in ChatConfig.Roles do
		local success, rank = pcall(function()
			return player:GetRankInGroup(role.groupId)
		end)
		if success and rank and rank == role.rank then
			return role.prefix, role.color
		end
	end

	return nil, nil
end

function Utils.getPlayerNameColor(): Color3?
	local player = LocalPlayer

	for _, nameColorConfig in ChatConfig.NameColors do
		local req = nameColorConfig.requirement
		if req.type == "rank" then
			local success, rank = pcall(function()
				return player:GetRankInGroup(req.groupId)
			end)
		if success and rank and rank >= req.minRank then
				return nameColorConfig.color
			end
		end
	end

	return nil
end

function Utils.getPlayerAvatar(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

function Utils.generateRandomStats(): { Kills: number, Damage: number, Heals: number, Captures: number }
	return {
		Kills = rng:NextInteger(1, 150),
		Damage = rng:NextInteger(5000, 17500),
		Heals = rng:NextInteger(2000, 6000),
		Captures = rng:NextInteger(0, 20),
	}
end

return Utils
