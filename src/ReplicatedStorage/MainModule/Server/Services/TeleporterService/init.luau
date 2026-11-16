--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local TeleporterService = {}
TeleporterService.Name = "TeleporterService"

local connections: { RBXScriptConnection } = {}

local COOLDOWN_ATTRIBUTE = "TP_Cooldown"
local COOLDOWN_DURATION = 3
local FORCEFIELD_DURATION = 0.5
local TELEPORT_Y_OFFSET = 2.5
local VELOCITY_CLEANUP_DELAY = 0.05

local function getCharacterFromHit(hit: BasePart): (Model?, Humanoid?, Player?)
	local parent = hit.Parent
	if not parent then
		return nil, nil, nil
	end

	local humanoid = parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local grandparent = parent.Parent
		if grandparent then
			humanoid = grandparent:FindFirstChildOfClass("Humanoid")
			if humanoid then
				parent = grandparent
			end
		end
	end

	if not humanoid then
		return nil, nil, nil
	end

	local character = parent :: Model
	local targetPlayer = Players:GetPlayerFromCharacter(character)

	return character, humanoid, targetPlayer
end

local function teleportCharacter(character: Model, destination: BasePart): ()
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	local attachment = destination:FindFirstChild("Attachment") :: Attachment?
	if attachment then
		character:PivotTo(attachment.WorldCFrame)
	else
		character:PivotTo(destination.CFrame + Vector3.new(0, TELEPORT_Y_OFFSET, 0))
	end

	local forceField = Instance.new("ForceField")
	forceField.Visible = false
	forceField.Parent = character
	task.delay(FORCEFIELD_DURATION, function()
		forceField:Destroy()
	end)

	task.delay(VELOCITY_CLEANUP_DELAY, function()
		if rootPart and rootPart.Parent then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Landed)
			end
		end
	end)
end

local function setupTeleportConnection(source: BasePart, destination: BasePart): ()
	local connection = source.Touched:Connect(function(hit: BasePart)
		local character, humanoid, targetPlayer = getCharacterFromHit(hit)

		if not character or not humanoid or not targetPlayer then
			return
		end

		if character:GetAttribute(COOLDOWN_ATTRIBUTE) then
			return
		end

		if humanoid.Health <= 0 then
			return
		end

		character:SetAttribute(COOLDOWN_ATTRIBUTE, true)
		task.delay(COOLDOWN_DURATION, function()
			if character then
				character:SetAttribute(COOLDOWN_ATTRIBUTE, nil)
			end
		end)

		teleportCharacter(character, destination)
	end)

	table.insert(connections, connection)
end

local function setupOneWayTeleport(model: Model): ()
	local sourceA = model:FindFirstChild("TP Destination A") :: BasePart?
	local destB = model:FindFirstChild("TP Destination B") :: BasePart?

	if not sourceA or not destB then
		return
	end

	setupTeleportConnection(sourceA, destB)
end

local function setupTwoWayTeleport(teleportA: Model, teleportB: Model): ()
	local destA = teleportA:FindFirstChild("TP Destination A") :: BasePart?
	local destB = teleportB:FindFirstChild("TP Destination B") :: BasePart?

	if not destA or not destB then
		return
	end

	setupTeleportConnection(destA, destB)
	setupTeleportConnection(destB, destA)
end

local function initializeTeleporters(): ()
	local teleportsFolder = workspace:FindFirstChild("Teleports") :: Folder?
	if not teleportsFolder then
		return
	end

	for _, child in teleportsFolder:GetChildren() do
		if child:IsA("Model") then
			local name = child.Name:lower()

			if name:find("1 way") or name:find("1way") or name:find("oneway") then
				setupOneWayTeleport(child)
			end
		end
	end

	local twoWayModels: { [number]: Model } = {}

	for _, child in teleportsFolder:GetChildren() do
		if child:IsA("Model") then
			local name = child.Name:lower()
			if name:find("2 way") or name:find("2way") or name:find("twoway") then
				local numMatch = child.Name:match("%d+")
				if numMatch then
					local num = tonumber(numMatch)
					if num then
						twoWayModels[num] = child
					end
				end
			end
		end
	end

	local processedPairs: { [number]: boolean } = {}
	for num, model in twoWayModels do
		if not processedPairs[num] then
			local pairNum = if num % 2 == 1 then num + 1 else num - 1
			local pairModel = twoWayModels[pairNum]

			if pairModel then
				setupTwoWayTeleport(model, pairModel)
				processedPairs[num] = true
				processedPairs[pairNum] = true
			end
		end
	end
end

function TeleporterService:init(): ()
end

function TeleporterService:start(): ()
	initializeTeleporters()
end

function TeleporterService:SetupOneWay(model: Model): ()
	setupOneWayTeleport(model)
end

function TeleporterService:SetupTwoWay(teleportA: Model, teleportB: Model): ()
	setupTwoWayTeleport(teleportA, teleportB)
end

function TeleporterService:TeleportPlayer(player: Player, destination: BasePart): ()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if character:GetAttribute(COOLDOWN_ATTRIBUTE) then
		return
	end

	character:SetAttribute(COOLDOWN_ATTRIBUTE, true)
	task.delay(COOLDOWN_DURATION, function()
		if character then
			character:SetAttribute(COOLDOWN_ATTRIBUTE, nil)
		end
	end)

	teleportCharacter(character, destination)
end

function TeleporterService:Cleanup(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return TeleporterService
