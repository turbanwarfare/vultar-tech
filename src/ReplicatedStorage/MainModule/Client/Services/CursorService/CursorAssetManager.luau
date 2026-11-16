--!strict
--!native
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent.Parent
local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)

local CursorAssetManager = {}

local ASSET_PREFIX = "rbxassetid://"
local cursorURLCache: { [number]: string } = {}
local spectatorCursorURL: string = ""

local function buildAssetURL(id: number): string
	return ASSET_PREFIX .. tostring(id)
end

function CursorAssetManager.buildCache(): ()
	for _, cursorData in SettingsConfig.Cursors do
		for _, variantId in cursorData.variants do
			if not cursorURLCache[variantId] then
				cursorURLCache[variantId] = buildAssetURL(variantId)
			end
		end
		if not cursorURLCache[cursorData.id] then
			cursorURLCache[cursorData.id] = buildAssetURL(cursorData.id)
		end
	end

	local spectatorId = SettingsConfig.SpectatorCursor
	if spectatorId then
		spectatorCursorURL = buildAssetURL(spectatorId)
		cursorURLCache[spectatorId] = spectatorCursorURL
	end
end

function CursorAssetManager.preloadAll(): ()
	local preloadFrame = Instance.new("Frame")
	preloadFrame.Name = "CursorPreload"
	preloadFrame.Size = UDim2.fromOffset(1, 1)
	preloadFrame.Position = UDim2.fromOffset(-100, -100)
	preloadFrame.BackgroundTransparency = 1
	preloadFrame.Visible = false

	local imageLabels: { ImageLabel } = {}
	for _, url in cursorURLCache do
		local label = Instance.new("ImageLabel")
		label.Size = UDim2.fromOffset(1, 1)
		label.BackgroundTransparency = 1
		label.Image = url
		label.Parent = preloadFrame
		table.insert(imageLabels, label)
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		preloadFrame.Parent = playerGui
	end

	pcall(function()
		ContentProvider:PreloadAsync(imageLabels)
	end)

	preloadFrame:Destroy()
end

function CursorAssetManager.getVariantURL(styleIndex: number, variantIndex: number): string
	local cursorData = SettingsConfig.Cursors[styleIndex]
	if not cursorData then
		cursorData = SettingsConfig.Cursors[1]
	end

	if not cursorData then
		return ""
	end

	local variantId = cursorData.variants[variantIndex]
	if variantId then
		return cursorURLCache[variantId] or cursorURLCache[cursorData.id] or ""
	end

	return cursorURLCache[cursorData.id] or ""
end

function CursorAssetManager.getSpectatorURL(): string
	return spectatorCursorURL
end

function CursorAssetManager.getCachedURL(assetId: number): string?
	return cursorURLCache[assetId]
end

function CursorAssetManager.addToCache(assetId: number): string
	local url = buildAssetURL(assetId)
	cursorURLCache[assetId] = url
	return url
end

function CursorAssetManager.clearCache(): ()
	table.clear(cursorURLCache)
	spectatorCursorURL = ""
end

function CursorAssetManager.getPresetCount(): number
	return #SettingsConfig.Cursors
end

return CursorAssetManager
