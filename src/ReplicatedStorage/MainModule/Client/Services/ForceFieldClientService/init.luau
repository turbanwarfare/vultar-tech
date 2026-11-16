--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")

task.spawn(function()
	local p1 = Instance.new("ParticleEmitter")
	p1.Texture = "rbxassetid://117208227488794"
	local p2 = Instance.new("ParticleEmitter")
	p2.Texture = "rbxassetid://13911794170"
	local p3 = Instance.new("ParticleEmitter")
	p3.Texture = "rbxassetid://11817596219"
	local p4 = Instance.new("ParticleEmitter")
	p4.Texture = "rbxassetid://115295862851987"
	pcall(ContentProvider.PreloadAsync, ContentProvider, { p1, p2, p3, p4 })
	p1:Destroy()
	p2:Destroy()
	p3:Destroy()
	p4:Destroy()
end)

local ForceFieldClientService = {}
ForceFieldClientService.Name = "ForceFieldClientService"

local P_LIFETIME = NumberRange.new(99999)
local P_SPEED = NumberRange.new(0)

local FB_FRAMERATE_1 = NumberRange.new(1)
local FB_FRAMERATE_15 = NumberRange.new(15)

local P3_ROTSPEED = NumberRange.new(-180, 180)
local P3_ROTATION = NumberRange.new(-180, 180)

local P4_ROTSPEED = NumberRange.new(-180, 180)
local P4_ROTATION = NumberRange.new(-360, 360)

local P1_SIZE = NumberSequence.new(3.5)
local P2_SIZE = NumberSequence.new(3.5)
local P3_SIZE = NumberSequence.new(3.25)
local P4_SIZE = NumberSequence.new(3.25)

local P1_TRANS = NumberSequence.new(0)
local P2_TRANS = NumberSequence.new(0.5)
local P3_TRANS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.7875),
	NumberSequenceKeypoint.new(0.439891, 0.6),
	NumberSequenceKeypoint.new(0.998634, 0.74375),
	NumberSequenceKeypoint.new(1, 1),
})
local P4_TRANS = NumberSequence.new(0.2)

local processed: { [ForceField]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local charConnections: { [Model]: { RBXScriptConnection } } = {}

local function setupForceField(forceField: ForceField)
	if processed[forceField] then
		return
	end

	forceField.Visible = false

	local character = forceField.Parent
	if not character or not character:IsA("Model") then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)

	task.spawn(function()
		while not character:IsDescendantOf(workspace) do
			if forceField.Parent ~= character then
				return
			end

			local ok = pcall(function()
				character.AncestryChanged:Wait()
			end)
			if not ok then
				return
			end
		end

		if forceField.Parent ~= character then
			return
		end
		if player and player.Character ~= character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		end
		if not rootPart then
			return
		end

		if forceField.Parent ~= character then
			return
		end
		if not character.Parent or not rootPart.Parent then
			return
		end
		if player and player.Character ~= character then
			return
		end

		if processed[forceField] then
			return
		end
		processed[forceField] = true
		local hue = 0
		local sat = 1
		if player and player.TeamColor then
			hue, sat = player.TeamColor.Color:ToHSV()
		end

		local flipbookColor = ColorSequence.new(Color3.fromHSV(hue, math.min(sat, 0.75), 1))
		local staticColor = ColorSequence.new(Color3.fromHSV(hue, math.min(sat, 0.82), 0.494118))

		local existingAttachment = rootPart:FindFirstChild("CustomForceFieldAttachment")
		if existingAttachment then
			existingAttachment:Destroy()
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "CustomForceFieldAttachment"
		attachment.Position = Vector3.new(0, -0.5, 0)
		attachment:SetAttribute("IgnoreWorldParticles", true)
		attachment.Parent = rootPart

		local p1 = Instance.new("ParticleEmitter")
		p1.Name = "1"
		p1.Texture = "rbxassetid://117208227488794"
		p1.FlipbookFramerate = FB_FRAMERATE_1
		p1.Lifetime = P_LIFETIME
		p1.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		p1.LockedToPart = true
		p1.Transparency = P1_TRANS
		p1.LightEmission = 1
		p1.Color = staticColor
		p1.Drag = 0
		p1.ZOffset = 3
		p1.Brightness = 2
		p1.Size = P1_SIZE
		p1.Speed = P_SPEED
		p1.Rate = 0
		p1.EmissionDirection = Enum.NormalId.Top
		p1.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		p1.Orientation = Enum.ParticleOrientation.FacingCamera
		p1.Enabled = true
		p1.Parent = attachment

		local p2 = Instance.new("ParticleEmitter")
		p2.Name = "2"
		p2.Texture = "rbxassetid://13911794170"
		p2.FlipbookFramerate = FB_FRAMERATE_1
		p2.Lifetime = P_LIFETIME
		p2.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		p2.LockedToPart = true
		p2.Transparency = P2_TRANS
		p2.LightEmission = 1
		p2.Color = staticColor
		p2.Drag = 0
		p2.ZOffset = 3
		p2.Brightness = 1
		p2.Size = P2_SIZE
		p2.Speed = P_SPEED
		p2.Rate = 0
		p2.EmissionDirection = Enum.NormalId.Top
		p2.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		p2.Orientation = Enum.ParticleOrientation.FacingCamera
		p2.Enabled = true
		p2.Parent = attachment

		local p3 = Instance.new("ParticleEmitter")
		p3.Name = "3"
		p3.Texture = "rbxassetid://11817596219"
		p3.FlipbookFramerate = FB_FRAMERATE_15
		p3.Lifetime = P_LIFETIME
		p3.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		p3.LockedToPart = true
		p3.Transparency = P3_TRANS
		p3.LightEmission = 5
		p3.Color = flipbookColor
		p3.Drag = 0
		p3.ZOffset = 3
		p3.Brightness = 3
		p3.Size = P3_SIZE
		p3.Speed = P_SPEED
		p3.Rate = 0
		p3.EmissionDirection = Enum.NormalId.Top
		p3.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		p3.Orientation = Enum.ParticleOrientation.FacingCamera
		p3.RotSpeed = P3_ROTSPEED
		p3.Rotation = P3_ROTATION
		p3.Enabled = true
		p3.Parent = attachment

		local p4 = Instance.new("ParticleEmitter")
		p4.Name = "4"
		p4.Texture = "rbxassetid://115295862851987"
		p4.FlipbookFramerate = FB_FRAMERATE_15
		p4.Lifetime = P_LIFETIME
		p4.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		p4.LockedToPart = true
		p4.Transparency = P4_TRANS
		p4.LightEmission = 5
		p4.Color = flipbookColor
		p4.Drag = 0
		p4.ZOffset = 3
		p4.Brightness = 3
		p4.Size = P4_SIZE
		p4.Speed = P_SPEED
		p4.Rate = 0
		p4.EmissionDirection = Enum.NormalId.Top
		p4.FlipbookMode = Enum.ParticleFlipbookMode.PingPong
		p4.Orientation = Enum.ParticleOrientation.FacingCamera
		p4.RotSpeed = P4_ROTSPEED
		p4.Rotation = P4_ROTATION
		p4.Enabled = true
		p4.Parent = attachment

		p1:Emit(1)
		p2:Emit(1)
		p3:Emit(1)
		p4:Emit(1)

		local ancestryConn: RBXScriptConnection? = nil
		local diedConn: RBXScriptConnection? = nil

		local function cleanAttachment()
			if ancestryConn then
				ancestryConn:Disconnect()
				ancestryConn = nil
			end
			if diedConn then
				diedConn:Disconnect()
				diedConn = nil
			end
			processed[forceField] = nil
			if attachment.Parent then
				attachment:Destroy()
			end
		end

		ancestryConn = forceField.AncestryChanged:Connect(function(_, newParent)
			if newParent then
				return
			end
			cleanAttachment()
		end)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			diedConn = humanoid.Died:Connect(function()
				cleanAttachment()
			end)
		end
	end)
end

local function cleanupCharacter(character: Model)
	local conns = charConnections[character]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		charConnections[character] = nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local attachment = rootPart:FindFirstChild("CustomForceFieldAttachment")
		if attachment then
			attachment:Destroy()
		end
	end
end

local function onCharacterAdded(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			task.spawn(setupForceField, child)
		end
	end

	local conns: { RBXScriptConnection } = {}
	charConnections[character] = conns

	local childAddedConn = character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") then
			task.spawn(setupForceField, child)
		end
	end)
	table.insert(conns, childAddedConn)
end

local function onCharacterRemoving(character: Model)
	cleanupCharacter(character)
end

local function onPlayerAdded(player: Player)
	local conns: { RBXScriptConnection } = {}
	playerConnections[player] = conns

	if player.Character then
		onCharacterAdded(player.Character)
	end

	local charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
	local charRemovingConn = player.CharacterRemoving:Connect(onCharacterRemoving)

	table.insert(conns, charAddedConn)
	table.insert(conns, charRemovingConn)
end

local function onPlayerRemoving(player: Player)
	local conns = playerConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end

	if player.Character then
		cleanupCharacter(player.Character)
	end
end

function ForceFieldClientService:init() end

function ForceFieldClientService:start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	CollectionService:GetInstanceAddedSignal("NPCForceField"):Connect(function(forceField: Instance)
		if not forceField:IsA("ForceField") then
			return
		end
		local parent = forceField.Parent
		if not parent or not parent:IsA("Model") then
			return
		end
		if Players:GetPlayerFromCharacter(parent) then
			return
		end
		task.spawn(setupForceField, forceField)
	end)
end

return ForceFieldClientService
