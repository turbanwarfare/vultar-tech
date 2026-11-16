--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Network = require(MainModule.Shared.Network)
local Maps = require(MainModule.Shared.Config.Maps)
local ServerUtils = require(MainModule.Shared.Utils.Game.ServerUtils)

type FusionScope = Types.FusionScope
type FusionUseFn = Types.FusionUseFn
type TeamChoice = string

local TeamChangerService = {}
TeamChangerService.Name = "TeamChangerService"

local player = Players.LocalPlayer
local playerGui: PlayerGui? = nil

local scope: FusionScope? = nil
local isOpen: any = nil
local isInitialized = false
local currentTeam: any = nil

local BUTTON_WIDTH = 115
local BUTTON_HEIGHT = 26
local ELEMENT_GAP = 4
local HEADER_HEIGHT = 26
local TOGGLE_GAP = 6
local MARGIN = 8

local SPRING_SPEED = 40
local SPRING_DAMPING = 1

type TeamButtonConfig = {
	choice: TeamChoice,
	label: string,
	color: Color3,
}

local TEAM_BUTTONS: { TeamButtonConfig } = {}

local function buildTeamButtons(): { TeamButtonConfig }
	local buttons: { TeamButtonConfig } = {}

	for _, teamConfig in Maps.getTeams() do
		if teamConfig.Selectable ~= false then
			table.insert(buttons, {
				choice = teamConfig.Name,
				label = string.upper(teamConfig.DisplayName or teamConfig.Name),
				color = teamConfig.Color.Color,
			})
		end
	end

	return buttons
end

local function getTotalHeight(): number
	return HEADER_HEIGHT + ELEMENT_GAP + (BUTTON_HEIGHT + ELEMENT_GAP) * #TEAM_BUTTONS - ELEMENT_GAP
end

local function getToggleYOffset(): number
	local totalHeight = getTotalHeight()
	return -totalHeight / 2 + HEADER_HEIGHT / 2
end

local function createTeamButton(s: FusionScope, config: TeamButtonConfig, index: number): TextButton
	local isHovered = s:Value(false)

	local bgTransparency = s:Spring(
		s:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.15 else 0.3
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local strokeTransparency = s:Spring(
		s:Computed(function(use: FusionUseFn)
			return if use(isHovered) then 0.2 else 0.4
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	return s:New("TextButton")({
		Name = config.choice,
		Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + ELEMENT_GAP + (index - 1) * (BUTTON_HEIGHT + ELEMENT_GAP)),
		BackgroundColor3 = Color3.fromRGB(40, 40, 45),
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		Text = config.label,
		TextColor3 = config.color,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,

		[Fusion.Children] = {
			s:New("UICorner")({
				CornerRadius = UDim.new(0, 4),
			}),

			s:New("UIStroke")({
				Color = Color3.fromRGB(60, 60, 65),
				Thickness = 1.5,
				Transparency = strokeTransparency,
			}),
		},

		[Fusion.OnEvent("MouseEnter")] = function()
			isHovered:set(true)
		end,

		[Fusion.OnEvent("MouseLeave")] = function()
			isHovered:set(false)
		end,

		[Fusion.OnEvent("Activated")] = function()
			if not currentTeam then
				return
			end
			if config.choice == Fusion.peek(currentTeam) then
				return
			end

			local result = Network.Teams.changeTeam(config.choice)
			if result.success and result.team then
				currentTeam:set(result.team)
				isOpen:set(false)
			end
		end,
	})
end

local function createHeader(s: FusionScope): Frame
	return s:New("Frame")({
		Name = "Header",
		Size = UDim2.fromOffset(BUTTON_WIDTH, HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 28),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			s:New("UICorner")({
				CornerRadius = UDim.new(0, 4),
			}),

			s:New("UIStroke")({
				Color = Color3.fromRGB(55, 55, 60),
				Thickness = 1.5,
				Transparency = 0.4,
			}),

			s:New("TextLabel")({
				Name = "Title",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "TEAM CHANGER",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

local function createContent(s: FusionScope): Frame
	local totalHeight = getTotalHeight()

	local contentXOffset = s:Spring(
		s:Computed(function(use: FusionUseFn)
			local open = use(isOpen)
			return if open then MARGIN else -BUTTON_WIDTH - 20
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local contentPosition = s:Computed(function(use: FusionUseFn)
		return UDim2.new(0, math.round(use(contentXOffset)), 0.5, 0)
	end)

	local buttons: { TextButton } = {}
	for i, config in TEAM_BUTTONS do
		table.insert(buttons, createTeamButton(s, config, i))
	end

	return s:New("Frame")({
		Name = "TeamChangerContent",
		Size = UDim2.fromOffset(BUTTON_WIDTH, totalHeight),
		Position = contentPosition,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		[Fusion.Children] = {
			createHeader(s),
			buttons,
		},
	})
end

local function createToggleButton(s: FusionScope): TextButton
	local yOffset = getToggleYOffset()

	local toggleXOffset = s:Spring(
		s:Computed(function(use: FusionUseFn)
			local open = use(isOpen)
			return if open then MARGIN + BUTTON_WIDTH + TOGGLE_GAP else MARGIN
		end),
		SPRING_SPEED,
		SPRING_DAMPING
	)

	local togglePosition = s:Computed(function(use: FusionUseFn)
		return UDim2.new(0, math.round(use(toggleXOffset)), 0.5, yOffset)
	end)

	local toggleText = s:Computed(function(use: FusionUseFn)
		return if use(isOpen) then "<" else ">"
	end)

	return s:New("TextButton")({
		Name = "TeamChangerToggle",
		Size = UDim2.fromOffset(16, 16),
		Position = togglePosition,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = toggleText,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,

		[Fusion.Children] = {
			s:New("UIStroke")({
				Color = Color3.fromRGB(60, 60, 65),
				Thickness = 1,
				Transparency = 0.7,
			}),
		},

		[Fusion.OnEvent("Activated")] = function()
			if isOpen then
				isOpen:set(not Fusion.peek(isOpen))
			end
		end,
	})
end

function TeamChangerService:init(): ()
	playerGui = player:WaitForChild("PlayerGui", 15) :: PlayerGui?
	isInitialized = true
end

function TeamChangerService:start(): ()
	if not isInitialized then
		self:init()
	end

	if not playerGui then
		return
	end

	local mapConfig = Maps.getConfig()
	local isPrivateServer = ServerUtils.isPrivateServer()
	if not isPrivateServer and (mapConfig.GameType == "Raid" or mapConfig.GameType == "Spar" or mapConfig.GameType == "Aim") then
		return
	end

	TEAM_BUTTONS = buildTeamButtons()
	if #TEAM_BUTTONS == 0 then
		return
	end

	scope = Fusion.scoped(Fusion)
	isOpen = scope:Value(false)
	currentTeam = scope:Value(if player.Team then player.Team.Name else nil)

	scope:New("ScreenGui")({
		Name = "TeamChanger",
		AutoLocalize = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 45,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,

		[Fusion.Children] = {
			createToggleButton(scope),
			createContent(scope),
		},
	})

	table.insert(
		scope,
		player:GetPropertyChangedSignal("Team"):Connect(function()
			local newTeam = player.Team
			if newTeam and currentTeam then
				currentTeam:set(newTeam.Name)
			end
		end)
	)
end

function TeamChangerService:Open(): ()
	if isOpen and not Fusion.peek(isOpen) then
		isOpen:set(true)
	end
end

function TeamChangerService:Close(): ()
	if isOpen and Fusion.peek(isOpen) then
		isOpen:set(false)
	end
end

function TeamChangerService:Toggle(): ()
	if isOpen then
		isOpen:set(not Fusion.peek(isOpen))
	end
end

function TeamChangerService:IsOpen(): boolean
	return isOpen and Fusion.peek(isOpen) or false
end

function TeamChangerService:Cleanup(): ()
	if scope then
		scope:doCleanup()
		scope = nil
	end

	isOpen = nil
	currentTeam = nil
	isInitialized = false
end

return TeamChangerService
