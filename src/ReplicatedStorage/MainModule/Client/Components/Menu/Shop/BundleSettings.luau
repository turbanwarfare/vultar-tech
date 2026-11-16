--!native
--!optimize 2

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UserOwnedGamepasses = {}
local SkinRandom = Random.new()

local BUNDLE_NAMES = { "Vex", "HelloKitty", "Toxic", "Freeze", "PixelGun" }

local BundleSettings = {
	Vex = {
		Gradient = {
			Color3.fromRGB(255, 130, 130),
			Color3.fromRGB(225, 35, 35),
			Color3.fromRGB(70, 0, 8),
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(70, 0, 8),
			Color3.fromRGB(225, 35, 35),
			Color3.fromRGB(255, 130, 130),
		},
		Id = "Vex",
		DisplayName = "VEX WEAPON BUNDLE",
		CardImage = 94577033925642,
		TitleTextColor = Color3.fromRGB(225, 35, 35),
		BundleId = 1870445094,
		Chance = 7.5,
	},
	HelloKitty = {
		Gradient = {
			Color3.fromRGB(177, 80, 161),
			Color3.fromRGB(153, 72, 149),
			Color3.fromRGB(104, 14, 131),
			Color3.fromRGB(65, 10, 78),
			Color3.fromRGB(104, 14, 131),
			Color3.fromRGB(153, 72, 149),
			Color3.fromRGB(177, 80, 161),
		},
		Id = "HelloKitty",
		DisplayName = "HELLO KITTY BUNDLE",
		CardImage = 111626098174570,
		TitleTextColor = Color3.fromRGB(104, 14, 131),
		BundleId = 1902972726,
		Chance = 7.5,
	},
	Toxic = {
		Gradient = {
			Color3.fromRGB(32, 112, 16),
			Color3.fromRGB(32, 112, 16),
			Color3.fromRGB(17, 138, 33),
			Color3.fromRGB(8, 228, 26),
			Color3.fromRGB(17, 138, 33),
			Color3.fromRGB(32, 112, 16),
			Color3.fromRGB(32, 112, 16),
		},
		Id = "Toxic",
		DisplayName = "TOXIC BUNDLE",
		CardImage = 138636472807093,
		TitleTextColor = Color3.fromRGB(17, 138, 33),
		BundleId = 1763970361,
		Chance = 7.5,
	},
	Freeze = {
		Gradient = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(100, 180, 240),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(200, 230, 255),
			Color3.fromRGB(255, 255, 255),
		},
		Id = "Freeze",
		DisplayName = "FREEZE BUNDLE",
		CardImage = 93932951856854,
		TitleTextColor = Color3.fromRGB(18, 68, 126),
		BundleId = 1931220905,
		Chance = 7.5,
	},
	PixelGun = {
		Gradient = {
			Color3.fromRGB(255, 240, 150),
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(200, 140, 0),
			Color3.fromRGB(90, 60, 0),
			Color3.fromRGB(200, 140, 0),
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(255, 240, 150),
		},
		Id = "PixelGun",
		DisplayName = "PIXEL GUN BUNDLE",
		CardImage = 109968889836758,
		TitleTextColor = Color3.fromRGB(230, 170, 20),
		BundleId = 2061442665,
		NoChatGradient = true,
		Chance = 70,
	},
}

function BundleSettings.checkOwned()
	local owned = {}
	for _, bundleName in BUNDLE_NAMES do
		local bundle = BundleSettings[bundleName]
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, bundle.BundleId)
		end)
		owned[bundleName] = success and hasPass or false
	end
	UserOwnedGamepasses[LocalPlayer.UserId] = owned
end

function BundleSettings.selectSkin(): string?
	BundleSettings.checkOwned()
	local owned = UserOwnedGamepasses[LocalPlayer.UserId]
	if not owned then
		return nil
	end
	local unowned = {}
	for bundleName, isOwned in pairs(owned) do
		if not isOwned then
			table.insert(unowned, bundleName)
		end
	end
	if #unowned == 0 then
		return nil
	end
	local total = 0
	for _, bundleName in unowned do
		total += BundleSettings[bundleName].Chance
	end
	local roll = SkinRandom:NextNumber() * total
	for _, bundleName in unowned do
		roll -= BundleSettings[bundleName].Chance
		if roll < 0 then
			return bundleName
		end
	end
	return unowned[#unowned]
end

return BundleSettings
