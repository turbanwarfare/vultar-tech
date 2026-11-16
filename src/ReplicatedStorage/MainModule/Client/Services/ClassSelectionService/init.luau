--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Network = require(MainModule.Shared.Network)
local ClassConfig = require(MainModule.Shared.Config.Classes.ClassConfig)
local GunStats = require(MainModule.Shared.Config.GunStats)
local FactionUtils = require(MainModule.Shared.Utils.Game.FactionUtils)
local FeatureFlags = require(MainModule.Shared.Config.FeatureFlags)
local LoadoutScreen = require(MainModule.Client.Components.LoadoutScreen)
local LazyService = require(MainModule.Shared.Utils.Services.LazyService)
local FadeGroup = require(MainModule.Client.Utils.UI.FadeGroup)
local Profile = require(MainModule.Shared.Utils.Debug.Profile)
local LoadoutFill = require(script.LoadoutFill)
local GunSkinUtils = require(MainModule.Client.Components.Menu.GunSkinUtils)

local getCosmeticService = LazyService.create(MainModule, "CosmeticService")

type ClassName = ClassConfig.ClassName
type CardState = "Selected" | "Open" | "Full"

type CardRefs = {
	button: TextButton,
	stroke: UIStroke,
	gunImage: ImageLabel,
	current: TextLabel,
	slots: Frame,
	labels: LoadoutFill.CardLabels,
	pips: { Frame },
	state: CardState,
}

type StatFills = {
	damage: Frame,
	fireRate: Frame,
	range: Frame,
	accuracy: Frame,
	magazine: Frame,
}

type Ui = {
	gui: ScreenGui,
	faction: TextLabel,
	classList: Frame,
	panel: LoadoutFill.PanelLabels,
	primaryImage: ImageLabel,
	primaryPreview: ViewportFrame?,
	primaryPreviewGun: string?,
	fills: StatFills,
	secondaryFrame: Frame,
	secondaryImage: ImageLabel,
	healingFrame: Frame,
	healingImage: ImageLabel,
	deploy: TextButton,
	hint: TextLabel,
	hintText: string,
	viewport: ViewportFrame,
	camera: Camera,
	world: WorldModel,
	cards: { [ClassName]: CardRefs },
}

type StatRange = {
	maxDamage: number,
	maxRoundsPerSecond: number,
	maxRange: number,
	minSpread: number,
	maxSpread: number,
	maxMagazine: number,
}

local ClassSelectionService = {}
ClassSelectionService.Name = "ClassSelectionService"

local player = Players.LocalPlayer
local playerGui: PlayerGui? = nil

local DEFAULT_IDLE_ANIMATION_ID = "rbxassetid://96896749029991"
local FLAG_MODEL_NAME = "FlagBanner"
local FLAG_CLASS: ClassName = "FlagBearer"

local getModelsService = LazyService.create(MainModule, "ModelsService")
local CAMERA_FOV = 35
local CAMERA_DISTANCE = 9.5
local CAMERA_HEIGHT = 1.8
local CAMERA_ANGLE = 192
local LOOK_AT_HEIGHT = 1.2
local ROTATE_SPEED = 0.01
local CLOSE_DISTANCE = 10
local ERROR_SHOW_TIME = 3
local CURRENT_TAG_GAP = 0.025
local OPEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local CLOSED_SCALE = 0.97

local scope: any = nil
local ui: Ui? = nil
local isInitialized = false
local isOpen = false
local deploying = false
local errorToken = 0

local activeFaction = "Defenders"
local selectedClass: ClassName? = nil
local currentClass: ClassName? = nil
local slotsState: Network.ClassSlotsState = {}
local statRange: StatRange? = nil

local connections: { RBXScriptConnection } = {}
local originPart: BasePart? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local fade: FadeGroup.FadeGroup? = nil
local holderScale: UIScale? = nil

local baseAvatarModel: Model? = nil
local previewModel: Model? = nil
local previewTracks: { AnimationTrack } = {}
local previewClass: ClassName? = nil
local previewFaction: string? = nil
local previewBase = CFrame.identity
local previewYaw = 0
local dragging = false
local lastDragX = 0

local function getPlayerFaction(): string?
	local team = player.Team
	if not team then
		return nil
	end
	local faction = FactionUtils.getTeamFaction(team.Name)
	if faction == "" then
		return nil
	end
	return faction
end

local function loadBaseAvatar(): ()
	local success, model = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(player.UserId)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)

	if not success or not model then
		return
	end

	model.Name = "BaseAvatar"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") then
			desc:Destroy()
		end
	end

	baseAvatarModel = model
end

local function equippedSkinFor(gunName: string): string
	local cosmeticService = getCosmeticService()
	return if cosmeticService then cosmeticService:GetEquippedGunSkin(gunName) else "Default"
end

local function cloneToolTemplate(weaponName: string): Tool?
	local skinId = equippedSkinFor(weaponName)
	local clone = GunSkinUtils.cloneSkinnedTool(weaponName, skinId)
	if not clone then
		return nil
	end

	clone:ScaleTo(0.6)

	for _, desc in clone:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") then
			desc:Destroy()
		end
	end

	return clone
end

local function attachPreviewFlag(model: Model): boolean
	local modelsService = getModelsService()
	local template = if modelsService then modelsService:FindModel(FLAG_MODEL_NAME) else nil
	local leftArm = model:FindFirstChild("Left Arm") :: BasePart?
	if not template or not leftArm then
		return false
	end

	local flag = template:Clone()
	flag.Name = FLAG_MODEL_NAME
	for _, desc in flag:GetDescendants() do
		if desc:IsA("BaseScript") or desc:IsA("Sound") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.Massless = true
		end
	end

	local handle = flag.PrimaryPart
	if not handle then
		flag:Destroy()
		return false
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "FlagMotor6D"
	motor.Part0 = leftArm
	motor.Part1 = handle
	motor.Parent = leftArm

	flag.Parent = model
	return true
end

local function attachPreviewTool(model: Model, tool: Tool): boolean
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local attach = tool:FindFirstChild("BodyAttach") :: BasePart? or handle
	if not torso or not attach then
		tool:Destroy()
		return false
	end

	tool.RequiresHandle = false
	for _, desc in tool:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.Massless = true
		end
	end

	if handle then
		local handleGrip = handle:FindFirstChildOfClass("Motor6D")
		if handleGrip then
			handleGrip.Part0 = nil
			handleGrip.Part1 = handle
		end
	end

	local toolGrip = Instance.new("Motor6D")
	toolGrip.Name = "ToolGrip"
	toolGrip.Part0 = torso
	toolGrip.Part1 = attach
	toolGrip.C1 = if tool.Name == "GPR" then CFrame.Angles(0, -math.pi / 2, 0) else CFrame.identity
	toolGrip.Parent = torso

	tool.Parent = model
	return true
end

local function find(root: Instance, ...: string): any
	local node: Instance = root
	for _, name in { ... } do
		local nextNode = node:FindFirstChild(name)
		if not nextNode then
			error(`[ClassSelectionService] Missing {name} under {node:GetFullName()}`)
		end
		node = nextNode
	end
	return node
end

local function gunImageFor(gunName: string?): string
	local stats = if gunName then GunStats.get(gunName) else nil
	if not stats or not stats.GunImageId then
		return ""
	end
	return "rbxassetid://" .. tostring(stats.GunImageId)
end

local function getStatRange(): StatRange
	local cached = statRange
	if cached then
		return cached
	end

	local range: StatRange = {
		maxDamage = 0,
		maxRoundsPerSecond = 0,
		maxRange = 0,
		minSpread = math.huge,
		maxSpread = 0,
		maxMagazine = 0,
	}

	for _, className in ClassConfig.ClassOrder do
		local def = ClassConfig.get(className)
		if def then
			for _, weapons in { def.DefenderWeapons, def.RaiderWeapons } do
				local weaponNames: { string } = { weapons.Primary }
				if weapons.Secondary then
					table.insert(weaponNames, weapons.Secondary)
				end
				for _, weaponName in weaponNames do
					local stats = GunStats.get(weaponName)
					if stats then
						range.maxDamage = math.max(range.maxDamage, stats.BaseDamage or 0)
						if (stats.FireRate or 0) > 0 then
							range.maxRoundsPerSecond = math.max(range.maxRoundsPerSecond, 1 / stats.FireRate)
						end
						range.maxRange = math.max(range.maxRange, stats.Range or 0)
						range.minSpread = math.min(range.minSpread, stats.Spread or 0)
						range.maxSpread = math.max(range.maxSpread, stats.Spread or 0)
						range.maxMagazine = math.max(range.maxMagazine, stats.MaxAmmo or 0)
					end
				end
			end
		end
	end

	statRange = range
	return range
end

local function accuracyFraction(spread: number): number
	local range = getStatRange()
	if range.maxSpread <= range.minSpread then
		return 1
	end
	return math.clamp(1 - 0.85 * (spread - range.minSpread) / (range.maxSpread - range.minSpread), 0, 1)
end

local function weaponInfo(weaponName: string?): LoadoutFill.Weapon?
	if not weaponName then
		return nil
	end
	local stats = GunStats.get(weaponName)
	if not stats then
		return nil
	end

	local fireRate = stats.FireRate or 0
	local healAmount = (stats :: any).HealAmount or 0
	local spread = stats.Spread or 0

	return {
		name = weaponName,
		mode = stats.Mode or "",
		damage = stats.BaseDamage or 0,
		headDamage = stats.HeadDamage or 0,
		roundsPerSecond = if fireRate > 0 then 1 / fireRate else 0,
		range = stats.Range or 0,
		spread = spread,
		accuracy = accuracyFraction(spread),
		magazine = stats.MaxAmmo or 0,
		healPerSecond = if healAmount > 0 and fireRate > 0 then healAmount / fireRate else 0,
	}
end

local function slotsFor(className: ClassName): (number, number, { string })
	local def = ClassConfig.get(className)
	local data = slotsState[className]
	local max = if data then data.max elseif def then def.MaxSlots else -1
	local current = if data then data.current else 0
	return current, max, if data then data.players else {}
end

local function cardStateFor(className: ClassName): CardState
	if className == selectedClass then
		return "Selected"
	end
	local current, max = slotsFor(className)
	if max ~= -1 and current >= max and className ~= currentClass then
		return "Full"
	end
	return "Open"
end

local function applyCardStyle(card: CardRefs, state: CardState): ()
	local style = LoadoutScreen.Styles.Card[state]
	card.state = state
	card.button.BackgroundColor3 = style.BackgroundColor3
	card.button.BackgroundTransparency = style.BackgroundTransparency
	card.stroke.Color = style.StrokeColor
	card.stroke.Transparency = style.StrokeTransparency
	card.gunImage.ImageTransparency = style.GunImageTransparency
	for _, label in { card.labels.title, card.labels.loadout, card.labels.players, card.labels.slotCount } do
		label.TextTransparency = style.TextTransparency
	end
	card.labels.players.TextColor3 = style.PlayersColor
	card.labels.slotCount.TextColor3 = style.SlotCountColor
end

local function attach(child: Instance, parent: Instance): ()
	child.Parent = parent
end

local function syncPips(card: CardRefs, current: number, max: number): ()
	local wanted = math.max(max, 0)
	while #card.pips < wanted do
		local pip = LoadoutScreen.createSlotPip(scope)
		pip.LayoutOrder = #card.pips + 1
		attach(pip, card.slots)
		table.insert(card.pips, pip)
	end
	while #card.pips > wanted do
		local pip = table.remove(card.pips)
		if pip then
			pip:Destroy()
		end
	end

	for index, pip in card.pips do
		local style = if index <= current then LoadoutScreen.Styles.Pip.Filled else LoadoutScreen.Styles.Pip.Empty
		pip.BackgroundColor3 = style.BackgroundColor3
		pip.BackgroundTransparency = style.BackgroundTransparency
		local stroke = pip:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = style.StrokeTransparency
		end
	end
end

local function createModelPreview(parent: Instance, gunName: string?, skinId: string): ViewportFrame?
	if not gunName then
		return nil
	end

	local tool: Tool? = GunSkinUtils.cloneSkinnedTool(gunName, skinId)
	if not tool then
		warn(`[ClassSelection] No tool template for {gunName}`)
		return nil
	end

	for _, desc in tool:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		elseif desc:IsA("BaseScript") or desc:IsA("Sound") then
			desc:Destroy()
		end
	end

	local viewPortFrame = Instance.new("ViewportFrame")
	viewPortFrame.Size = UDim2.fromScale(1, 1)
	viewPortFrame.BackgroundTransparency = 1
	local WorldModel = Instance.new("WorldModel")

	tool.Parent = WorldModel
	WorldModel.Parent = viewPortFrame

	local center, size = tool:GetBoundingBox()
	local side = if size.X < size.Z then center.RightVector else center.LookVector
	local camera = Instance.new("Camera")
	camera.FieldOfView = 10
	camera.CFrame = CFrame.lookAt(center.Position + side * size.Magnitude * 2, center.Position)
	camera.Parent = viewPortFrame
	viewPortFrame.CurrentCamera = camera

	viewPortFrame.Parent = parent
	return viewPortFrame
end

local function renderCards(current: Ui): ()
	for className, card in current.cards do
		local def = ClassConfig.get(className)
		local weapons = ClassConfig.getWeaponsForFaction(className, activeFaction)
		if def and weapons then
			local count, max, players = slotsFor(className)
			applyCardStyle(card, cardStateFor(className))
			syncPips(card, count, max)
			card.current.Visible = className == currentClass
			card.gunImage.Image = gunImageFor(weapons.Primary)
			LoadoutFill.classCard(card.labels, {
				className = className,
				displayName = def.DisplayName,
				primary = weapons.Primary,
				secondary = weapons.Secondary,
				healing = weapons.Healing,
				players = players,
				current = count,
				max = max,
				isUnlimited = max == -1,
				isFull = max ~= -1 and count >= max,
				isYourClass = className == currentClass,
			})
		end
	end
end

local function setFill(fill: Frame, fraction: number): ()
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

local function renderPanel(current: Ui, className: ClassName): ()
	local def = ClassConfig.get(className)
	local weapons = ClassConfig.getWeaponsForFaction(className, activeFaction)
	local primary = if weapons then weaponInfo(weapons.Primary) else nil
	if not def or not weapons or not primary then
		return
	end

	local secondary = weaponInfo(weapons.Secondary)
	local healing = weaponInfo(weapons.Healing)
	local range = getStatRange()

	local skinId = equippedSkinFor(primary.name)
	local previewKey = `{primary.name}:{skinId}`
	if current.primaryPreviewGun ~= previewKey then
		if current.primaryPreview then
			current.primaryPreview:Destroy()
		end
		current.primaryPreview = createModelPreview(current.primaryImage, primary.name, skinId)
		current.primaryPreviewGun = previewKey
	end
	current.primaryImage.Image = if current.primaryPreview then "" else gunImageFor(primary.name)
	setFill(current.fills.damage, if range.maxDamage > 0 then primary.damage / range.maxDamage else 0)
	setFill(current.fills.fireRate, if range.maxRoundsPerSecond > 0 then primary.roundsPerSecond / range.maxRoundsPerSecond else 0)
	setFill(current.fills.range, if range.maxRange > 0 then primary.range / range.maxRange else 0)
	setFill(current.fills.accuracy, primary.accuracy)
	setFill(current.fills.magazine, if range.maxMagazine > 0 then primary.magazine / range.maxMagazine else 0)

	current.secondaryFrame.Visible = secondary ~= nil
	current.secondaryImage.Image = if secondary then gunImageFor(secondary.name) else ""
	current.healingFrame.Visible = healing ~= nil
	current.healingImage.Image = if healing then gunImageFor(healing.name) else ""

	LoadoutFill.classDetails(current.panel, {
		className = className,
		displayName = def.DisplayName,
		health = def.Health or 100,
		primary = primary,
		secondary = secondary,
		healing = healing,
	})
end

local function clearPreview(): ()
	for _, track in previewTracks do
		track:Stop()
		track:Destroy()
	end
	table.clear(previewTracks)
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	previewClass = nil
	previewFaction = nil
	dragging = false
end

local function idleAnimationFor(weaponName: string?): string
	local stats = if weaponName then GunStats.get(weaponName) else nil
	local idle = if stats and stats.Animations then stats.Animations.Idle else nil
	return if idle then "rbxassetid://" .. tostring(idle) else DEFAULT_IDLE_ANIMATION_ID
end

local function playPreviewAnimation(model: Model, weaponName: string?): ()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = idleAnimationFor(weaponName)
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	animation:Destroy()
	if ok and track then
		track.Looped = true
		track:Play()
		table.insert(previewTracks, track)
	end
end

local function renderPreview(current: Ui, className: ClassName): ()
	if not baseAvatarModel then
		return
	end
	if previewModel and previewClass == className and previewFaction == activeFaction then
		return
	end

	clearPreview()
	previewClass = className
	previewFaction = activeFaction

	local model = baseAvatarModel:Clone()
	model.Name = "ClassPreview_" .. className
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0))
	model.Parent = current.world
	model:ScaleTo(0.6)

	local weapons = ClassConfig.getWeaponsForFaction(className, activeFaction)
	local weaponName = if weapons then weapons.Primary else nil
	local tool = if weaponName then cloneToolTemplate(weaponName) else nil
	local hasTool = tool ~= nil and attachPreviewTool(model, tool)
	local hasFlag = className ~= FLAG_CLASS or attachPreviewFlag(model)

	previewBase = model:GetPivot()
	previewYaw = 0

	local root = model:FindFirstChild("Torso") :: BasePart? or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local center = if root then root.Position else previewBase.Position
	local angle = math.rad(CAMERA_ANGLE)
	local offset = Vector3.new(math.sin(angle) * CAMERA_DISTANCE, CAMERA_HEIGHT, math.cos(angle) * CAMERA_DISTANCE)
	current.camera.FieldOfView = CAMERA_FOV
	current.camera.CFrame = CFrame.new(center + offset, center + Vector3.new(0, LOOK_AT_HEIGHT, 0))

	playPreviewAnimation(model, weaponName)
	previewModel = model
	if (weaponName and not hasTool) or not hasFlag then
		previewClass = nil
	end
end

local function rotatePreview(deltaX: number): ()
	local model = previewModel
	if not model then
		return
	end
	previewYaw += deltaX * ROTATE_SPEED
	model:PivotTo(previewBase * CFrame.Angles(0, previewYaw, 0))
end

local function renderUi(): ()
	local current = ui
	if not current then
		return
	end

	if not selectedClass then
		selectedClass = currentClass or ClassConfig.ClassOrder[1]
	end

	LoadoutFill.faction(current.faction, activeFaction)
	renderCards(current)

	local shown = selectedClass
	if shown then
		renderPanel(current, shown)
		if isOpen then
			renderPreview(current, shown)
		end
	end
end

local render = Profile.wrap("Vultar::ClassSelection::render", renderUi)

local function refreshFromServer(): ()
	task.spawn(function()
		local state = Network.Class.getSlotsState()
		if state then
			slotsState = state
		end
		local playerClass = Network.Class.getPlayerClass()
		if playerClass then
			currentClass = playerClass :: ClassName
			if not selectedClass then
				selectedClass = currentClass
			end
		end
		render()
	end)
end

local function showError(message: string): ()
	local current = ui
	if not current then
		return
	end
	errorToken += 1
	local token = errorToken
	LoadoutFill.deployError(current.hint, message)
	task.delay(ERROR_SHOW_TIME, function()
		if token == errorToken and ui then
			ui.hint.Text = ui.hintText
		end
	end)
end

local function deploy(): ()
	local className = selectedClass
	if not className or deploying then
		return
	end
	if className == currentClass then
		ClassSelectionService:Close()
		return
	end

	deploying = true
	task.spawn(function()
		local ok, result = pcall(function(): Network.ClassSelectResult
			return Network.Class.selectClass(className)
		end)
		deploying = false

		if ok and result.success then
			currentClass = className
			render()
			ClassSelectionService:Close()
		else
			showError(if ok and result.error then result.error else "Could not switch class")
		end
	end)
end

local function selectCard(className: ClassName): ()
	local current = ui
	if not current then
		return
	end
	local card = current.cards[className]
	if not card or card.state == "Full" then
		return
	end
	selectedClass = className
	render()
end

local function placeCurrentTag(card: CardRefs): ()
	local cardWidth = card.button.AbsoluteSize.X
	if cardWidth <= 0 then
		return
	end
	local title = card.labels.title
	local x = title.Position.X.Scale + title.TextBounds.X / cardWidth + CURRENT_TAG_GAP
	card.current.Position = UDim2.fromScale(x, card.current.Position.Y.Scale)
end

local function buildCard(current: Ui, className: ClassName, order: number): ()
	local button = LoadoutScreen.createClassCard(scope)
	button.Name = className
	button.LayoutOrder = order

	local card: CardRefs = {
		button = button,
		stroke = find(button, "UIStroke"),
		gunImage = find(button, "GunImage"),
		current = find(button, "Current"),
		slots = find(button, "Slots"),
		labels = {
			title = find(button, "Title"),
			loadout = find(button, "Loadout"),
			players = find(button, "Players"),
			slotCount = find(button, "SlotCount"),
		},
		pips = {},
		state = "Open",
	}

	table.insert(
		connections,
		button.Activated:Connect(function()
			selectCard(className)
		end)
	)

	local function reposition()
		placeCurrentTag(card)
	end
	table.insert(connections, card.labels.title:GetPropertyChangedSignal("TextBounds"):Connect(reposition))
	table.insert(connections, button:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition))

	button.Parent = current.classList
	current.cards[className] = card
end

local function buildUi(): Ui?
	if ui then
		return ui
	end
	if not playerGui then
		return nil
	end

	scope = Fusion.scoped(Fusion)
	local gui = LoadoutScreen.create(scope)
	local holder = find(gui, "Frame", "Holder")
	local panel = find(holder, "Loadout")
	local stats = find(panel, "Stats")
	local extras = find(panel, "Extras")
	local viewport = find(holder, "ClassViewport")
	local hint = find(holder, "Hint")

	local built: Ui = {
		gui = gui,
		faction = find(holder, "Header", "Faction"),
		classList = find(holder, "ClassList"),
		panel = {
			title = find(panel, "Header", "Title"),
			health = find(panel, "Header", "Health"),
			gunName = find(panel, "GunName"),
			mode = find(panel, "Mode"),
			damage = find(stats, "Damage", "Value"),
			fireRate = find(stats, "FireRate", "Value"),
			range = find(stats, "Range", "Value"),
			accuracy = find(stats, "Accuracy", "Value"),
			magazine = find(stats, "Magazine", "Value"),
			secondaryName = find(extras, "Secondary", "Title"),
			secondaryDetail = find(extras, "Secondary", "Detail"),
			healingName = find(extras, "Medi", "Title"),
			healingDetail = find(extras, "Medi", "Detail"),
		},
		primaryImage = find(panel, "Primary", "GunImage"),
		fills = {
			damage = find(stats, "Damage", "Bar", "Fill"),
			fireRate = find(stats, "FireRate", "Bar", "Fill"),
			range = find(stats, "Range", "Bar", "Fill"),
			accuracy = find(stats, "Accuracy", "Bar", "Fill"),
			magazine = find(stats, "Magazine", "Bar", "Fill"),
		},
		secondaryFrame = find(extras, "Secondary"),
		secondaryImage = find(extras, "Secondary", "GunImage"),
		healingFrame = find(extras, "Medi"),
		healingImage = find(extras, "Medi", "GunImage"),
		deploy = find(panel, "Deploy"),
		hint = hint,
		hintText = hint.Text,
		viewport = viewport,
		camera = find(viewport, "Camera"),
		world = find(viewport, "WorldModel"),
		cards = {},
	}
	built.viewport.CurrentCamera = built.camera
	ui = built

	for order, className in ClassConfig.ClassOrder do
		buildCard(built, className, order)
	end

	table.insert(connections, built.deploy.Activated:Connect(deploy))
	local cosmeticService = getCosmeticService()
	if cosmeticService then
		table.insert(
			connections,
			cosmeticService:OnStateChanged(function()
				render()
			end) :: any
		)
	end
	table.insert(
		connections,
		built.viewport.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				lastDragX = input.Position.X
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				rotatePreview(input.Position.X - lastDragX)
				lastDragX = input.Position.X
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if isOpen and input.KeyCode == Enum.KeyCode.Escape then
				ClassSelectionService:Close()
			end
		end)
	)

	gui.Parent = playerGui
	return built
end

local function setupProximityPrompts(): ()
	local classChangersFolder = workspace:FindFirstChild("ClassChangers")
	if not classChangersFolder then
		return
	end

	local function setPromptsEnabled(factionFolder: Instance, enabled: boolean): ()
		for _, desc in factionFolder:GetDescendants() do
			if desc:IsA("ProximityPrompt") then
				desc.Enabled = enabled
			end
		end
	end

	local function updatePromptVisibility(): ()
		local playerFaction = getPlayerFaction()

		local defendersFolder = classChangersFolder:FindFirstChild("Defenders")
		if defendersFolder then
			setPromptsEnabled(defendersFolder, playerFaction == "Defenders")
		end

		local hostilesFolder = classChangersFolder:FindFirstChild("Hostiles")
		if hostilesFolder then
			setPromptsEnabled(hostilesFolder, playerFaction == "Raiders")
		end
	end

	local function getFactionFromPrompt(prompt: ProximityPrompt): string?
		if not prompt:IsDescendantOf(classChangersFolder) then
			return nil
		end

		local node: Instance? = prompt.Parent
		while node and node.Parent ~= classChangersFolder do
			node = node.Parent
		end

		if not node then
			return nil
		end

		if node.Name == "Defenders" then
			return "Defenders"
		elseif node.Name == "Hostiles" then
			return "Raiders"
		end

		return nil
	end

	updatePromptVisibility()

	table.insert(
		connections,
		player:GetPropertyChangedSignal("Team"):Connect(function()
			updatePromptVisibility()

			local playerFaction = getPlayerFaction()
			if playerFaction then
				activeFaction = if playerFaction == "Defenders" then "Defenders" else "Raiders"
				selectedClass = nil
				currentClass = nil
				slotsState = {}
				clearPreview()
				refreshFromServer()
			end
		end)
	)

	table.insert(
		connections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt)
			local promptFaction = getFactionFromPrompt(prompt)
			if not promptFaction then
				return
			end

			local playerFaction = getPlayerFaction()
			if not playerFaction or playerFaction ~= promptFaction then
				return
			end

			local part = prompt.Parent
			if part and part:IsA("BasePart") then
				ClassSelectionService:Open(part)
			else
				ClassSelectionService:Open()
			end
		end)
	)
end

function ClassSelectionService:init(): ()
	playerGui = player:WaitForChild("PlayerGui", 15) :: PlayerGui?
	isInitialized = true
end

function ClassSelectionService:start(): ()
	if not FeatureFlags.isEnabled("ClassSystem") then
		return
	end

	if not isInitialized then
		self:init()
	end

	activeFaction = getPlayerFaction() or "Defenders"
	if not Profile.run("Vultar::ClassSelection::buildUi", buildUi) then
		return
	end

	table.insert(
		connections,
		Network.Class.onSlotsUpdated(function(teamKey, state)
			if teamKey == activeFaction then
				slotsState = state
				render()
			end
		end)
	)

	task.spawn(function()
		loadBaseAvatar()
		render()
	end)

	refreshFromServer()
	setupProximityPrompts()
end

function ClassSelectionService:Open(openedFrom: BasePart?): ()
	local current = ui
	if not current or isOpen then
		return
	end

	isOpen = true
	originPart = openedFrom

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(function()
			if not originPart then
				return
			end
			local character = player.Character
			local rootPart = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local delta = if rootPart then rootPart.Position - originPart.Position else Vector3.zero
			if not rootPart or delta:Dot(delta) >= CLOSE_DISTANCE * CLOSE_DISTANCE then
				ClassSelectionService:Close()
			end
		end)
	end

	render()

	local group: FadeGroup.FadeGroup = fade or FadeGroup.new()
	if not fade then
		FadeGroup.capture(group, { find(current.gui, "Frame"), find(current.gui, "Background") })
		fade = group
	end
	local scale: UIScale = holderScale or Instance.new("UIScale")
	if not holderScale then
		scale.Parent = find(current.gui, "Frame", "Holder")
		holderScale = scale
	end

	if not current.gui.Enabled then
		FadeGroup.set(group, 0)
		scale.Scale = CLOSED_SCALE
		current.gui.Enabled = true
	end
	FadeGroup.tweenTo(group, 1, OPEN_INFO, function()
		if isOpen and ui then
			renderCards(ui)
		end
	end)
	TweenService:Create(scale, OPEN_INFO, { Scale = 1 }):Play()

	refreshFromServer()
end

function ClassSelectionService:Close(): ()
	if not isOpen then
		return
	end

	isOpen = false
	dragging = false
	local current = ui
	if current then
		if fade then
			FadeGroup.tweenTo(fade, 0, CLOSE_INFO, function()
				if not isOpen then
					current.gui.Enabled = false
				end
			end)
		else
			current.gui.Enabled = false
		end
		if holderScale then
			TweenService:Create(holderScale, CLOSE_INFO, { Scale = CLOSED_SCALE }):Play()
		end
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	originPart = nil
end

function ClassSelectionService:Toggle(): ()
	if isOpen then
		self:Close()
	else
		self:Open()
	end
end

function ClassSelectionService:IsOpen(): boolean
	return isOpen
end

function ClassSelectionService:GetSelectedClass(): ClassName?
	return currentClass
end

function ClassSelectionService:Cleanup(): ()
	clearPreview()

	if baseAvatarModel then
		baseAvatarModel:Destroy()
		baseAvatarModel = nil
	end

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if fade then
		FadeGroup.destroy(fade)
		fade = nil
	end
	holderScale = nil

	if scope then
		scope:doCleanup()
		scope = nil
	end

	ui = nil
	isOpen = false
	deploying = false
	selectedClass = nil
	currentClass = nil
	slotsState = {}
	statRange = nil
	originPart = nil
	isInitialized = false
end

return ClassSelectionService
