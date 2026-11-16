--!strict
--!native
--!optimize 2
--#selene: allow(deprecated)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MainModule = script.Parent.Parent.Parent
local Constants = require(MainModule.Shared.Config.Constants)
local WeaponConfig = require(MainModule.Shared.Config.Weapons.WeaponConfig)
local ServiceLocator = require(MainModule.Shared.Utils.Services.ServiceLocator)

local MovementService = {}
MovementService.Name = "MovementService"

local player = Players.LocalPlayer
local character: Model? = nil
local humanoid: Humanoid? = nil
local animator: Animator? = nil

local crouchTrack: AnimationTrack? = nil
local saluteTrack: AnimationTrack? = nil
local atEaseTrack: AnimationTrack? = nil

local isCrouching = false
local isSprinting = false
local isSaluting = false
local isAtEase = false
local isRunning = false

local defaultHipHeight: number = 2
local CROUCH_HIP_HEIGHT_OFFSET = 1

local inputConnections: { RBXScriptConnection } = {}
local characterConnection: RBXScriptConnection? = nil
local characterConnections: { RBXScriptConnection } = {}

local isInitialized = false
local defaultKeybinds = WeaponConfig.DefaultKeybinds
local defaultSpeeds = WeaponConfig.DefaultSpeeds
local FADE_TIME = WeaponConfig.AnimationFadeTime

local CREATOR_GROUP_ID = Constants.GROUPS.VULTAR
local AT_EASE_RANK = Constants.RANKS.COLONEL
local cachedHasAtEase: boolean? = nil

local ANIMATION_IDS = {
	Crouch = "rbxassetid://101785625813335",
	Salute = "rbxassetid://92409640158033",
	AtEase = "rbxassetid://105939857950798",
}

local function getKeybind(action: string): Enum.KeyCode
	local settings = ServiceLocator.Settings()
	if settings then
		local keyName = settings:GetKeybind(action)
		if keyName then
			local success, keyCode = pcall(function()
				return (Enum.KeyCode :: any)[keyName]
			end)
			if success and keyCode then
				return keyCode
			end
		end
	end
	return defaultKeybinds[action] or Enum.KeyCode.None
end

local function setWalkSpeed(speed: number): ()
	if humanoid then
		if character and speed == defaultSpeeds.Sprint then
			local tool = character:FindFirstChildOfClass("Tool")
			if tool and tool.Name == "Sword" then
				speed = defaultSpeeds.Walk
			end
		end
		humanoid.WalkSpeed = speed
	end
end

local function setHipHeight(height: number): ()
	if humanoid then
		humanoid.HipHeight = height
	end
end

local function loadAnimation(id: string): AnimationTrack?
	if not animator then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	return track
end

local function loadAnimations(): ()
	if not animator then
		return
	end

	crouchTrack = loadAnimation(ANIMATION_IDS.Crouch)
	if crouchTrack then
		crouchTrack.Looped = true
	end

	saluteTrack = loadAnimation(ANIMATION_IDS.Salute)
	if saluteTrack then
		saluteTrack.Looped = true
	end

	atEaseTrack = loadAnimation(ANIMATION_IDS.AtEase)
	if atEaseTrack then
		atEaseTrack.Looped = true
	end
end

local function unloadAnimations(): ()
	if crouchTrack then
		crouchTrack:Stop(0)
		crouchTrack:Destroy()
		crouchTrack = nil
	end
	if saluteTrack then
		saluteTrack:Stop(0)
		saluteTrack:Destroy()
		saluteTrack = nil
	end
	if atEaseTrack then
		atEaseTrack:Stop(0)
		atEaseTrack:Destroy()
		atEaseTrack = nil
	end
end

local function setCharacterAttribute(name: string, value: any): ()
	if character then
		character:SetAttribute(name, value)
	end
end

local function initCharacterAttributes(): ()
	if character then
		character:SetAttribute("Crouching", false)
		character:SetAttribute("Sprinting", false)
		character:SetAttribute("Saluting", false)
		character:SetAttribute("AtEase", false)
		character:SetAttribute("Firing", false)
		character:SetAttribute("Zooming", false)
	end
end

local function applySprint(sprinting: boolean): ()
	isSprinting = sprinting
	setCharacterAttribute("Sprinting", sprinting)

	if sprinting then
		isCrouching = false
		isAtEase = false
		setCharacterAttribute("Crouching", false)
		setCharacterAttribute("AtEase", false)

		if crouchTrack and crouchTrack.IsPlaying then
			crouchTrack:Stop(FADE_TIME)
		end
		if atEaseTrack and atEaseTrack.IsPlaying then
			atEaseTrack:Stop(FADE_TIME)
		end

		if humanoid then
			humanoid.HipHeight = defaultHipHeight
		end

		setWalkSpeed(defaultSpeeds.Sprint)
	else
		if isCrouching then
			setWalkSpeed(defaultSpeeds.Crouch)
		else
			setWalkSpeed(defaultSpeeds.Walk)
		end
	end
end

local function applyCrouch(crouching: boolean): ()
	isCrouching = crouching
	setCharacterAttribute("Crouching", crouching)

	if crouching then
		isSprinting = false
		setCharacterAttribute("Sprinting", false)

		if crouchTrack then
			crouchTrack:Play(FADE_TIME)
			crouchTrack:AdjustSpeed(isRunning and 1 or 0)
		end

		setWalkSpeed(defaultSpeeds.Crouch)
		setHipHeight(defaultHipHeight - CROUCH_HIP_HEIGHT_OFFSET)
	else
		if crouchTrack and crouchTrack.IsPlaying then
			crouchTrack:Stop(FADE_TIME)
		end

		setHipHeight(defaultHipHeight)

		if isSprinting then
			setWalkSpeed(defaultSpeeds.Sprint)
		else
			setWalkSpeed(defaultSpeeds.Walk)
		end
	end
end

local function applySalute(saluting: boolean): ()
	isSaluting = saluting
	setCharacterAttribute("Saluting", saluting)

	if saluting then
		if saluteTrack then
			saluteTrack:Play(FADE_TIME)
		end
	else
		if saluteTrack and saluteTrack.IsPlaying then
			saluteTrack:Stop(FADE_TIME)
		end
	end
end

local function applyAtEase(atEase: boolean): ()
	isAtEase = atEase
	setCharacterAttribute("AtEase", atEase)

	if atEase then
		isSprinting = false
		setCharacterAttribute("Sprinting", false)

		if atEaseTrack then
			atEaseTrack:Play(FADE_TIME)
		end
	else
		if atEaseTrack and atEaseTrack.IsPlaying then
			atEaseTrack:Stop(FADE_TIME)
		end
	end
end

local function hasAtEasePermission(): boolean
	if cachedHasAtEase ~= nil then
		return cachedHasAtEase
	end
	local success, rank = pcall(function()
		return player:GetRankInGroup(CREATOR_GROUP_ID)
	end)
	cachedHasAtEase = success and rank >= AT_EASE_RANK
	return cachedHasAtEase
end

local function resetState(): ()
	isCrouching = false
	isSprinting = false
	isSaluting = false
	isAtEase = false
	isRunning = false
	initCharacterAttributes()
end

local function setupCharacter(char: Model): ()
	character = char
	local currentHumanoid = char:FindFirstChildOfClass("Humanoid")
	if not currentHumanoid then
		currentHumanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	humanoid = currentHumanoid

	task.spawn(function()
		local cam = workspace.CurrentCamera
		if cam then
			local hum = currentHumanoid or char:WaitForChild("Humanoid", 10)
			if hum and hum:IsA("Humanoid") then
				cam.CameraSubject = hum
			end
		end
	end)

	for _, conn in characterConnections do
		conn:Disconnect()
	end
	table.clear(characterConnections)

	unloadAnimations()
	resetState()

	if currentHumanoid then
		defaultHipHeight = currentHumanoid.HipHeight
		animator = currentHumanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = currentHumanoid:WaitForChild("Animator", 5) :: Animator?
		end

		loadAnimations()

		table.insert(
			characterConnections,
			char.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and child.Name == "Sword" then
					if isSprinting then
						setWalkSpeed(defaultSpeeds.Sprint)
					end
				end
			end)
		)

		table.insert(
			characterConnections,
			char.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") and child.Name == "Sword" then
					if isSprinting then
						setWalkSpeed(defaultSpeeds.Sprint)
					end
				end
			end)
		)

		table.insert(
			characterConnections,
			currentHumanoid.StateChanged:Connect(function(_oldState, newState)
				if newState == Enum.HumanoidStateType.Jumping then
					if isCrouching then
						applyCrouch(false)
					end
				end
			end)
		)

		table.insert(
			characterConnections,
			currentHumanoid.Running:Connect(function(speed)
				isRunning = speed > 4
				if crouchTrack and crouchTrack.IsPlaying then
					crouchTrack:AdjustSpeed(isRunning and 1 or 0)
				end
			end)
		)

		table.insert(
			characterConnections,
			currentHumanoid.Died:Connect(function()
				applyCrouch(false)
				applySprint(false)
				applySalute(false)
				applyAtEase(false)
				isRunning = false
			end)
		)
	end
end

local function cleanupCharacter(): ()
	for _, conn in characterConnections do
		conn:Disconnect()
	end
	table.clear(characterConnections)

	unloadAnimations()
	resetState()

	character = nil
	humanoid = nil
	animator = nil
end

local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	local keyCode = input.KeyCode

	if keyCode == getKeybind("Sprint") then
		local Maps = require(MainModule.Shared.Config.Maps)
		if Maps.getConfig().GameType == "Aim" then
			return
		end
		local weaponService = ServiceLocator.Weapon()
		if weaponService and weaponService:GetEquippedWeaponName() == "GPR" then
			return
		end
		local hasFiring = weaponService and weaponService:IsFiring()
		local canSprintWhileFiring = weaponService and weaponService:CanSprintWhileFiring()
		if hasFiring and not canSprintWhileFiring then
			local gunService = ServiceLocator.get("GunService")
			if gunService then
				gunService:StopFiring()
			end
		end
		applySprint(not isSprinting)
		return
	end

	if keyCode == getKeybind("Crouch") then
		local weaponService = ServiceLocator.Weapon()
		if weaponService and weaponService:GetEquippedWeaponName() == "GPR" then
			return
		end
		applyCrouch(not isCrouching)
		return
	end

	if keyCode == getKeybind("Salute") then
		local flagBearer = ServiceLocator.get("FlagBearerService")
		if flagBearer and flagBearer:IsFlagBearer() then
			return
		end
		applySalute(true)
		return
	end

	if keyCode == Enum.KeyCode.Y then
		if isAtEase then
			applyAtEase(false)
		else
			if hasAtEasePermission() then
				applyAtEase(true)
			end
		end
		return
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean): ()
	local keyCode = input.KeyCode

	if keyCode == getKeybind("Salute") then
		local flagBearer = ServiceLocator.get("FlagBearerService")
		if flagBearer and flagBearer:IsFlagBearer() then
			return
		end
		applySalute(false)
		return
	end
end

function MovementService:init(): ()
	isInitialized = true
end

function MovementService:start(): ()
	if not isInitialized then
		self:init()
	end

	table.insert(inputConnections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(inputConnections, UserInputService.InputEnded:Connect(onInputEnded))

	characterConnection = player.CharacterAdded:Connect(setupCharacter)

	if player.Character then
		setupCharacter(player.Character)
	end
end

function MovementService:IsCrouching(): boolean
	return isCrouching
end

function MovementService:IsSprinting(): boolean
	return isSprinting
end

function MovementService:IsSaluting(): boolean
	return isSaluting
end

function MovementService:IsAtEase(): boolean
	return isAtEase
end

function MovementService:SetSprinting(value: boolean): ()
	applySprint(value)
end

function MovementService:SetCrouching(value: boolean): ()
	applyCrouch(value)
end

function MovementService:OnFiringStarted(): ()
	local weaponService = ServiceLocator.Weapon()
	local canSprintWhileFiring = weaponService and weaponService:CanSprintWhileFiring()
	if isSprinting and not canSprintWhileFiring then
		applySprint(false)
	end
end

function MovementService:Cleanup(): ()
	for _, conn in inputConnections do
		conn:Disconnect()
	end
	table.clear(inputConnections)

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	cleanupCharacter()
	cachedHasAtEase = nil
	isInitialized = false
end

return MovementService
