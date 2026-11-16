--!native
--!optimize 2

local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionValue<T> = Types.FusionValue<T>

local COLS = 3
local ROWS = 2
local CROSSFADE_TIME = 0.25
local THEME_COLOR = Color3.fromRGB(180, 12, 152)

local LAYER_TILES: { [string]: { string } } = {
	featured_1 = {
		"rbxassetid://80061037961904",
		"rbxassetid://97388304963160",
		"rbxassetid://98043569406314",
		"rbxassetid://130175291064911",
		"rbxassetid://94138184247018",
		"rbxassetid://113569606128692",
	},
	featured_2 = {
		"rbxassetid://107562879922340",
		"rbxassetid://107168954663379",
		"rbxassetid://96489821174496",
		"rbxassetid://104800335969285",
		"rbxassetid://121159967448273",
		"rbxassetid://101829381002607",
	},
	skins = {
		"rbxassetid://124407812365636",
		"rbxassetid://73136789285142",
		"rbxassetid://136299650644615",
		"rbxassetid://115778555109856",
		"rbxassetid://72058764229015",
		"rbxassetid://125680739156584",
	},
	cards = {
		"rbxassetid://76705950485177",
		"rbxassetid://112113923538528",
		"rbxassetid://78555770845686",
		"rbxassetid://90090188868134",
		"rbxassetid://103875289450515",
		"rbxassetid://71740383322185",
	},
	gradients = {
		"rbxassetid://124407812365636",
		"rbxassetid://73136789285142",
		"rbxassetid://136299650644615",
		"rbxassetid://115778555109856",
		"rbxassetid://72058764229015",
		"rbxassetid://125680739156584",
	},
}

local LAYER_ORDER = { "featured_1", "featured_2", "skins", "cards", "gradients" }

local sharedLayers: { [string]: CanvasGroup } = {}
local layersInitialized = false
local preloadStarted = false
local currentActiveLayer: string? = nil
local activeTweens: { Tween } = {}
local currentContainer: Frame? = nil

local crossfadeTweenInfo = TweenInfo.new(CROSSFADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function preloadAllImages()
	if preloadStarted then
		return
	end
	preloadStarted = true

	task.spawn(function()		local allAssets: { Instance } = {}

		for _, tiles in LAYER_TILES do
			for _, tileId in tiles do
				local img = Instance.new("ImageLabel")
				img.Image = tileId
				table.insert(allAssets, img)
			end
		end

		pcall(function()
			ContentProvider:PreloadAsync(allAssets)
		end)

		for _, img in allAssets do
			img:Destroy()
		end
	end)
end

local function ensureLayersCreated()
	if layersInitialized then
		return
	end
	layersInitialized = true

	for zIndex, layerId in LAYER_ORDER do
		local tiles = LAYER_TILES[layerId]

		local layer = Instance.new("CanvasGroup")
		layer.Name = `Layer_{layerId}`
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.GroupTransparency = 1
		layer.ZIndex = zIndex

		for i = 1, COLS * ROWS do
			local col = (i - 1) % COLS
			local row = (i - 1) // COLS

			local tile = Instance.new("ImageLabel")
			tile.Name = `Tile_{i}`
			tile.Size = UDim2.fromScale(1 / COLS, 1 / ROWS)
			tile.Position = UDim2.fromScale(col / COLS, row / ROWS)
			tile.BackgroundTransparency = 1
			tile.BorderSizePixel = 0
			tile.Image = tiles[i] or ""
			tile.ScaleType = Enum.ScaleType.Stretch
			if layerId == "featured_1" or layerId == "gradients" then
				tile.ImageColor3 = THEME_COLOR
			end
			tile.Parent = layer
		end

		sharedLayers[layerId] = layer
	end
end

local function reparentLayersTo(container: Frame)
	if currentContainer == container then
		return
	end

	currentContainer = container

	for _, layerId in LAYER_ORDER do
		local layer = sharedLayers[layerId]
		if layer then
			layer.Parent = container
		end
	end
end

local function getLayerId(tab: string, page: number): string
	if tab == "featured" then
		page = math.clamp(page, 1, 2)
		return "featured_" .. tostring(page)
	end
	if LAYER_TILES[tab] then
		return tab
	end
	return "featured_1"
end

local function cancelActiveTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function transitionToLayer(newLayerId: string)
	if currentActiveLayer == newLayerId then
		return
	end

	cancelActiveTweens()

	local newLayer = sharedLayers[newLayerId]
	if not newLayer then
		return
	end

	for layerId, layer in sharedLayers do
		if layerId ~= newLayerId and layer.GroupTransparency < 1 then
			local fadeOutTween = TweenService:Create(layer, crossfadeTweenInfo, { GroupTransparency = 1 })
			fadeOutTween:Play()
			table.insert(activeTweens, fadeOutTween)
		end
	end

	local fadeInTween = TweenService:Create(newLayer, crossfadeTweenInfo, { GroupTransparency = 0 })
	fadeInTween:Play()
	table.insert(activeTweens, fadeInTween)

	currentActiveLayer = newLayerId
end

export type GradientBackgroundProps = {
	Visible: FusionCanBeState<boolean>,
	CurrentTab: FusionValue<string>,
	CurrentPage: FusionValue<number>,
}

local function create(scope: FusionScope, props: GradientBackgroundProps): Frame
	preloadAllImages()
	ensureLayersCreated()

	local currentTab = props.CurrentTab
	local currentPage = props.CurrentPage

	local container = Instance.new("Frame")
	container.Name = "GradientBackground"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.ZIndex = 0

	reparentLayersTo(container)

	local function syncLayer()
		local tab = Fusion.peek(currentTab) or "featured"
		local page = Fusion.peek(currentPage) or 1
		transitionToLayer(getLayerId(tab, page))
	end

	scope:Observer(currentTab):onBind(syncLayer)
	scope:Observer(currentPage):onBind(syncLayer)

	local visibleBinding = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	scope:Observer(visibleBinding):onBind(function()
		local visible = Fusion.peek(visibleBinding)
		container.Visible = visible
	end)

	table.insert(scope, function()
		cancelActiveTweens()
		for _, layer in sharedLayers do
			layer.Parent = nil
		end
		currentContainer = nil
	end)

	return container
end

local function setThemeColor(color: Color3)
	THEME_COLOR = color
	for _, layerId in { "featured_1", "gradients" } do
		local layer = sharedLayers[layerId]
		if layer then
			for _, tile in layer:GetChildren() do
				if tile:IsA("ImageLabel") then
					tile.ImageColor3 = THEME_COLOR
				end
			end
		end
	end
end

local module = setmetatable({
	setThemeColor = setThemeColor,
}, {
	__call = function(_, scope, props)
		return create(scope, props)
	end,
})

return module
