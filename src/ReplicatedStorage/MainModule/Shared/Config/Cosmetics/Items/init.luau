--!strict
--!native
--!optimize 2

local PlayerCards = require(script.PlayerCards)
local GunSkins = require(script.GunSkins)
local ChatGradients = require(script.ChatGradients)
local Special = require(script.Special)

local Items = {}

local function addItems(sourceItems: { any }, category: string)
	for _, item in sourceItems do
		item.category = item.category or category
		table.insert(Items, item)
	end
end

addItems(PlayerCards, "PlayerCard")
addItems(GunSkins, "GunSkin")
addItems(ChatGradients, "ChatGradient")

for _, item in Special do
	table.insert(Items, item)
end

return Items
