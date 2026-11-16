--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)
local SettingsEnums = require(MainModule.Shared.Config.Settings.SettingsEnums)

local HolsterService = {}
HolsterService.Name = "HolsterService"

local player = Players.LocalPlayer
local currentHolsterSetting: number = SettingsEnums.Holsters.All
local connections: { RBXScriptConnection } = {}
local playerFolderConns: { [Instance]: { RBXScriptConnection } } = {}
local isInitialized = false

local holsterPartsCache: { [Model]: { BasePart } } = {}

local function getHolsterParts(holsterModel: Model): { BasePart }
	local cached = holsterPartsCache[holsterModel]
	if cached then
		return cached
	end

	local parts: { BasePart } = {}
	for _, desc in holsterModel:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end

	holsterPartsCache[holsterModel] = parts
	return parts
end

local function applyVisibilityToModel(holsterModel: Instance, ownerUserId: number): ()
	if not holsterModel:IsA("Model") then
		return
	end

	local shouldShow = true
	if currentHolsterSetting == SettingsEnums.Holsters.None then
		shouldShow = false
	elseif currentHolsterSetting == SettingsEnums.Holsters.Self then
		shouldShow = ownerUserId == player.UserId
	end

	local modifier = if shouldShow then 0 else 1
	local parts = getHolsterParts(holsterModel :: Model)
	for _, part in parts do
		if part.Parent then
			part.LocalTransparencyModifier = modifier
		end
	end
end

local function updateAllInPlayerFolder(playerFolder: Instance, ownerUserId: number): ()
	for _, child in playerFolder:GetChildren() do
		applyVisibilityToModel(child, ownerUserId)
	end
end

local function updateAllHolsterVisibility(): ()
	local ignore = workspace:FindFirstChild("Ignore")
	if not ignore then
		return
	end

	for _, playerFolder in ignore:GetChildren() do
		local ownerUserId = tonumber(playerFolder.Name)
		if not ownerUserId or not playerFolder:IsA("Folder") then
			continue
		end
		updateAllInPlayerFolder(playerFolder, ownerUserId)
	end
end

local function disconnectPlayerFolder(playerFolder: Instance): ()
	local conns = playerFolderConns[playerFolder]
	if not conns then
		return
	end
	for _, conn in conns do
		conn:Disconnect()
	end
	playerFolderConns[playerFolder] = nil
end

local function connectPlayerFolder(playerFolder: Instance, ownerUserId: number): ()
	if playerFolderConns[playerFolder] then
		return
	end

	local conns: { RBXScriptConnection } = {}
	playerFolderConns[playerFolder] = conns

	table.insert(
		conns,
		playerFolder.ChildAdded:Connect(function(child)
			applyVisibilityToModel(child, ownerUserId)
		end)
	)

	table.insert(
		conns,
		playerFolder.ChildRemoved:Connect(function(child)
			if child:IsA("Model") then
				holsterPartsCache[child] = nil
			end
		end)
	)

	updateAllInPlayerFolder(playerFolder, ownerUserId)
end

local function connectIgnoreFolder(ignore: Instance): ()
	for _, playerFolder in ignore:GetChildren() do
		local ownerUserId = tonumber(playerFolder.Name)
		if ownerUserId and playerFolder:IsA("Folder") then
			connectPlayerFolder(playerFolder, ownerUserId)
		end
	end

	table.insert(
		connections,
		ignore.ChildAdded:Connect(function(child)
			local ownerUserId = tonumber(child.Name)
			if ownerUserId and child:IsA("Folder") then
				connectPlayerFolder(child, ownerUserId)
			end
		end)
	)

	table.insert(
		connections,
		ignore.ChildRemoved:Connect(function(child)
			disconnectPlayerFolder(child)
		end)
	)
end

function HolsterService:init(): ()
	isInitialized = true
end

function HolsterService:start(): ()
	if not isInitialized then
		self:init()
	end

	local settings = ServiceLocator.Settings()
	if settings then
		currentHolsterSetting = settings:GetSetting("Holsters") or SettingsEnums.Holsters.All

		table.insert(
			connections,
			settings.SettingChanged:Connect(function(key: string, newValue: any)
				if key == "Holsters" then
					currentHolsterSetting = newValue
					updateAllHolsterVisibility()
				end
			end)
		)
	end

	local ignore = workspace:FindFirstChild("Ignore")
	if ignore then
		connectIgnoreFolder(ignore)
	else
		table.insert(
			connections,
			workspace.ChildAdded:Connect(function(child)
				if child.Name == "Ignore" then
					connectIgnoreFolder(child)
				end
			end)
		)
	end
end

function HolsterService:Cleanup(): ()
	local ignore = workspace:FindFirstChild("Ignore")
	if ignore then
		for _, playerFolder in ignore:GetChildren() do
			if not playerFolder:IsA("Folder") then
				continue
			end
			for _, child in playerFolder:GetChildren() do
				if not child:IsA("Model") then
					continue
				end
				local parts = holsterPartsCache[child]
				if not parts then
					continue
				end
				for _, part in parts do
					if part.Parent then
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end

	for _, conns in playerFolderConns do
		for _, conn in conns do
			conn:Disconnect()
		end
	end
	table.clear(playerFolderConns)

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(holsterPartsCache)
	isInitialized = false
end

return HolsterService
