--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent
local ToolAssetCache = require(MainModule.Server.Cache.ToolAssetCache)
local GunStats = require(MainModule.Shared.Config.GunStats)
local Signal = require(MainModule.Shared.Utils.State.Signal)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)

local GunSkinService = {}
GunSkinService.Name = "GunSkinService"

local GUN_SKIN_SEPARATOR = ":"

local SKIN_GUN_OVERRIDES: { [string]: string } = {
	["Maxwell"] = "H-82",
}

local SKIN_FIRE_SOUNDS: { [string]: number } = {
	["Maxwell"] = 8772968188,
	["Test_Skin"] = 8772968188,
	["Fish"] = 9125409840,
	["Squirrel"] = 9125409840,
}

local skinTemplates: { [string]: { [string]: Model } } = {}
local skinsLoaded = false
local isInitialized = false

local playerSkins: { [number]: { [string]: string } } = {}
local skinApplied = Signal.new()
local serviceConnections: { RBXScriptConnection } = {}

local toolDestroyConnections: { [any]: RBXScriptConnection } = {}

local isLoadingSkins = false
local cosmeticService: any = nil
local ensureSkinsLoaded: (timeout: number?) -> boolean

local toolAnchorParts: { [any]: { [string]: CFrame } } = {}

local function evictTool(tool: any): ()
	toolAnchorParts[tool] = nil

	local conn = toolDestroyConnections[tool]
	if conn then
		conn:Disconnect()
		toolDestroyConnections[tool] = nil
	end
end

local function watchTool(tool: any): ()
	if toolDestroyConnections[tool] then
		return
	end
	toolDestroyConnections[tool] = tool.Destroying:Connect(function()
		evictTool(tool)
	end)
end

local function applyFireSoundForSkin(tool: Tool, skinId: string): ()
	local fireChild = tool:FindFirstChild("Fire", true)
	if not fireChild or not fireChild:IsA("Sound") then
		return
	end
	local fireSound = fireChild :: Sound

	local customId = SKIN_FIRE_SOUNDS[skinId]
	if customId then
		fireSound.SoundId = "rbxassetid://" .. tostring(customId)
		return
	end

	local stats = GunStats.get(tool.Name)
	if stats and stats.Sounds and stats.Sounds.Fire then
		fireSound.SoundId = "rbxassetid://" .. tostring(stats.Sounds.Fire)
	end
end

local function applySkinToTool(tool: Tool, skinId: string): boolean
	applyFireSoundForSkin(tool, skinId)

	local skinData = skinTemplates[skinId]
	if not skinData then
		return false
	end

	local overrideGun = SKIN_GUN_OVERRIDES[skinId]
	local skinModel = skinData[overrideGun or tool.Name]
	if not skinModel and overrideGun then
		skinModel = skinData[tool.Name]
	end
	if not skinModel then
		local refGun = GunStats.get(tool.Name) and GunStats.get(tool.Name).SkinReferenceGun
		if refGun then
			skinModel = skinData[refGun]
		end
	end
	if not skinModel then
		return false
	end

	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return false
	end

	watchTool(tool)

	local oldGunModel = tool:FindFirstChildOfClass("Model")
	local newModel = skinModel:Clone()
	newModel.Name = "GunModel"

	for _, desc in newModel:GetDescendants() do
		if desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") then
			desc:Destroy()
		end
	end

	if oldGunModel and not oldGunModel:GetAttribute("SkinOverride") then
		local relParts: { [string]: CFrame } = {}
		for _, desc in oldGunModel:GetDescendants() do
			if desc:IsA("BasePart") then
				relParts[desc.Name] = handle.CFrame:Inverse() * desc.CFrame
			end
		end
		toolAnchorParts[tool] = relParts
	end

	local needsOverride = overrideGun ~= nil and overrideGun ~= tool.Name
	if needsOverride then
		newModel:SetAttribute("SkinOverride", true)
		newModel:PivotTo(handle.CFrame)
		newModel.Parent = tool
		for _, desc in newModel:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
				desc.CanQuery = false
				desc.CanTouch = false
				desc.Massless = true
				desc.CastShadow = false
				local weld = Instance.new("Weld")
				weld.Name = "SkinWeld"
				weld.Part0 = handle
				weld.Part1 = desc
				weld.C0 = handle.CFrame:Inverse() * desc.CFrame
				weld.C1 = CFrame.identity
				weld.Parent = desc
			elseif desc:IsA("Light") then
				desc.Enabled = false
			end
		end
	else
		local transform = handle.CFrame * newModel:GetPivot():Inverse()
		local savedParts = toolAnchorParts[tool]
		if savedParts then
			for _, desc in newModel:GetDescendants() do
				if desc:IsA("BasePart") and savedParts[desc.Name] then
					transform = (handle.CFrame * savedParts[desc.Name]) * desc.CFrame:Inverse()
					break
				end
			end
		end
		newModel.Parent = tool
		for _, desc in newModel:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CFrame = transform * desc.CFrame
				desc.Anchored = false
				desc.CanCollide = false
				desc.CanQuery = false
				desc.CanTouch = false
				desc.Massless = true
				desc.CastShadow = false
				local weld = Instance.new("Weld")
				weld.Name = "SkinWeld"
				weld.Part0 = handle
				weld.Part1 = desc
				weld.C0 = handle.CFrame:Inverse() * desc.CFrame
				weld.C1 = CFrame.identity
				weld.Parent = desc
			elseif desc:IsA("Light") then
				desc.Enabled = false
			end
		end
	end

	if oldGunModel then
		oldGunModel:Destroy()
	end

	for _, w in handle:GetDescendants() do
		if (w:IsA("WeldConstraint") or w:IsA("Weld")) and (not w.Part1 or not w.Part1.Parent) then
			w:Destroy()
		end
	end

	return true
end

local function getPlayerSkinForGun(player: Player, gunName: string): string
	if not player or not player.UserId then
		return "Default"
	end

	local skins = playerSkins[player.UserId]
	if skins then
		local cached = skins[gunName]
		if cached and cached ~= "" then
			return cached
		end
	end

	if cosmeticService and cosmeticService.GetEquippedGunSkin then
		local ok, skinId = pcall(function()
			return cosmeticService:GetEquippedGunSkin(player, gunName)
		end)

		local resolved: string = (ok and skinId and skinId ~= "") and skinId or "Default"

		if not skins then
			skins = {}
			playerSkins[player.UserId] = skins
		end
		skins[gunName] = resolved
		return resolved
	end

	return "Default"
end

local function applyPlayerSkinToTool(player: Player, tool: Tool): boolean
	if not skinsLoaded then
		ensureSkinsLoaded(3)
	end

	local skinId = getPlayerSkinForGun(player, tool.Name)
	return applySkinToTool(tool, skinId)
end

local function updateToolsForGun(player: Player, gunName: string, skinId: string): ()
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child.Name == gunName then
				applySkinToTool(child, skinId)
			end
		end
	end

	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child.Name == gunName then
				applySkinToTool(child, skinId)
			end
		end
	end
end

local function updateAllPlayerTools(player: Player): ()
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				local skinId = getPlayerSkinForGun(player, child.Name)
				applySkinToTool(child, skinId)
			end
		end
	end

	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local skinId = getPlayerSkinForGun(player, child.Name)
				applySkinToTool(child, skinId)
			end
		end
	end
end

local function onCosmeticChanged(player: Player, category: string, itemId: string): ()
	if category ~= "GunSkin" then
		return
	end

	local sepPos = string.find(itemId, GUN_SKIN_SEPARATOR, 1, true)
	if sepPos then
		local skinId = string.sub(itemId, 1, sepPos - 1)
		local gunName = string.sub(itemId, sepPos + 1)

		if skinId == "" or gunName == "" then
			return
		end

		local skins = playerSkins[player.UserId]
		if not skins then
			skins = {}
			playerSkins[player.UserId] = skins
		end
		skins[gunName] = skinId

		task.spawn(function()
			updateToolsForGun(player, gunName, skinId)
			skinApplied:Fire(player, itemId)
		end)
	else
		playerSkins[player.UserId] = nil
		task.spawn(function()
			updateAllPlayerTools(player)
			skinApplied:Fire(player, itemId)
		end)
	end
end

local function onPlayerRemoving(player: Player): ()
	playerSkins[player.UserId] = nil
end

local CLIENT_STRIP_CLASSES: { [string]: true } = {
	Weld = true,
	ManualWeld = true,
	Script = true,
	Sound = true,
}

local function createClientSkinTemplates(): ()
	local existingFolder = ReplicatedStorage:FindFirstChild("SkinTemplates")
	if existingFolder then
		existingFolder:Destroy()
	end

	local templatesFolder = Instance.new("Folder")
	templatesFolder.Name = "SkinTemplates"

	for collectionName, gunModels in skinTemplates do
		local collectionFolder = Instance.new("Folder")
		collectionFolder.Name = collectionName

		for gunName, model in gunModels do
			local clone = model:Clone()
			clone.Name = gunName
			for _, desc in clone:GetDescendants() do
				if CLIENT_STRIP_CLASSES[desc.ClassName] or desc:IsA("BodyMover") then
					desc:Destroy()
				end
			end
			clone.Parent = collectionFolder
		end

		collectionFolder.Parent = templatesFolder
	end

	templatesFolder.Parent = ReplicatedStorage
end

local function clearSkinTemplates(): ()
	for _, skinData in skinTemplates do
		for _, model in skinData do
			model:Destroy()
		end
	end
	table.clear(skinTemplates)
end

local function loadSkinsFromAsset(): boolean
	if isLoadingSkins then
		while isLoadingSkins do
			task.wait(0.1)
		end
		return skinsLoaded
	end

	isLoadingSkins = true
	clearSkinTemplates()
	skinsLoaded = false

	local success, result, err = ToolAssetCache.loadAsset()
	if not success or not result then
		warn(`[GunSkinService] Failed to load tools asset for skins: {err or "unknown error"}. Skins will be unavailable until retry.`)
		isLoadingSkins = false
		skinsLoaded = false
		return false
	end

	local skinsFolder = result:FindFirstChild("Skins", true)
	if not skinsFolder then
		warn("[GunSkinService] No Skins folder found in tools asset")
		isLoadingSkins = false
		skinsLoaded = false
		return false
	end

	for _, skinFolder in skinsFolder:GetChildren() do
		if skinFolder:IsA("Folder") then
			local skinName = skinFolder.Name
			skinTemplates[skinName] = {}

			for _, gunModel in skinFolder:GetChildren() do
				if gunModel:IsA("Model") then
					skinTemplates[skinName][gunModel.Name] = gunModel:Clone()
				end
			end
		end
	end

	createClientSkinTemplates()

	skinsLoaded = true
	isLoadingSkins = false
	return true
end

ensureSkinsLoaded = function(timeout: number?): boolean
	if skinsLoaded and next(skinTemplates) ~= nil then
		return true
	end

	if not isLoadingSkins then
		task.spawn(loadSkinsFromAsset)
	end

	local maxWait = timeout or 5
	local waitStart = os.clock()
	while not skinsLoaded and (os.clock() - waitStart) < maxWait do
		task.wait(0.1)
	end

	return skinsLoaded and next(skinTemplates) ~= nil
end

function GunSkinService:init(): ()
	skinsLoaded = false
	table.clear(playerSkins)
	table.clear(toolAnchorParts)

	for tool, conn in toolDestroyConnections do
		conn:Disconnect()
		toolDestroyConnections[tool] = nil
	end

	task.spawn(loadSkinsFromAsset)
	isInitialized = true
end

function GunSkinService:start(): ()
	if not isInitialized then
		self:init()
	end

	cosmeticService = LazyService.create(MainModule, "CosmeticService")()

	table.insert(serviceConnections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	if cosmeticService then
		cosmeticService:OnCosmeticChanged(onCosmeticChanged)
	end
end

function GunSkinService:ApplySkinToTool(player: Player, tool: Tool): boolean
	return applyPlayerSkinToTool(player, tool)
end

function GunSkinService:GetPlayerSkinForGun(player: Player, gunName: string): string
	return getPlayerSkinForGun(player, gunName)
end

function GunSkinService:HasSkinForGun(collection: string, gunName: string): boolean
	local skinData = skinTemplates[collection]
	if not skinData then
		return false
	end
	if skinData[gunName] ~= nil then
		return true
	end
	local refGun = GunStats.get(gunName) and GunStats.get(gunName).SkinReferenceGun
	if refGun and skinData[refGun] ~= nil then
		return true
	end
	return false
end

function GunSkinService:GetAvailableSkins(): { string }
	local skins: { string } = {}
	for skinName in skinTemplates do
		table.insert(skins, skinName)
	end
	return skins
end

function GunSkinService:OnSkinApplied(callback: (player: Player, skinId: string) -> ()): Signal.Connection
	return skinApplied:Connect(callback)
end

function GunSkinService:IsLoaded(): boolean
	return skinsLoaded
end

function GunSkinService:Cleanup(): ()
	for _, conn in serviceConnections do
		conn:Disconnect()
	end
	table.clear(serviceConnections)

	for tool, conn in toolDestroyConnections do
		conn:Disconnect()
		toolDestroyConnections[tool] = nil
	end

	clearSkinTemplates()

	table.clear(playerSkins)
	table.clear(toolAnchorParts)

	skinApplied:Destroy()
	skinApplied = Signal.new()

	local existingFolder = ReplicatedStorage:FindFirstChild("SkinTemplates")
	if existingFolder then
		existingFolder:Destroy()
	end

	skinsLoaded = false
	isInitialized = false
	cosmeticService = nil
end

return GunSkinService
