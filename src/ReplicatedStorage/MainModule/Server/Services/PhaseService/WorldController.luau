--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")

local TP_COOLDOWN = 3
local TP_FORCEFIELD_DURATION = 1

local WorldController = {}

local sewerState: {
	c4Planted: boolean,
	tunnel: BasePart?,
	tunnelOriginalCanCollide: boolean,
	tunnelOriginalCanQuery: boolean,
	tunnelOriginalTransparency: number,
	hatch2: BasePart?,
	hatch2Open: boolean,
	hatch2OriginalCanCollide: boolean,
	hatch2OriginalTransparency: number,
	tunnelPrompt: ProximityPrompt?,
	buttonPrompt: ProximityPrompt?,
} = {
	c4Planted = false,
	tunnel = nil,
	tunnelOriginalCanCollide = true,
	tunnelOriginalCanQuery = true,
	tunnelOriginalTransparency = 0,
	hatch2 = nil,
	hatch2Open = false,
	hatch2OriginalCanCollide = true,
	hatch2OriginalTransparency = 0,
	tunnelPrompt = nil,
	buttonPrompt = nil,
}

function WorldController.setupTeleports(connections: { RBXScriptConnection }): ()
	local teleportsFolder = workspace:FindFirstChild("Teleports_")
	if not teleportsFolder then return end

	local destinations: { [string]: { Part: BasePart, Pair: string } } = {}

	for _, folder in teleportsFolder:GetChildren() do
		local destA = folder:FindFirstChild("TP Destination A") :: BasePart?
		local destB = folder:FindFirstChild("TP Destination B") :: BasePart?

		local num = tonumber(folder.Name:match("%d+"))
		if destA and num then
			local keyA = `A_{num}`
			local pairA = `B_{num + 1}`
			destinations[keyA] = { Part = destA, Pair = pairA }
		end

		if destB and num then
			local keyB = `B_{num}`
			local pairB = `A_{num - 1}`
			destinations[keyB] = { Part = destB, Pair = pairB }
		end
	end

	local playerCooldowns: { [Player]: number } = {}

	local function teleportPlayer(player: Player, targetPart: BasePart): ()
		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then return end

		local now = os.clock()
		if playerCooldowns[player] and (now - playerCooldowns[player]) < TP_COOLDOWN then return end
		playerCooldowns[player] = now

		local attachment = targetPart:FindFirstChildWhichIsA("Attachment")
		local targetCFrame = if attachment
			then targetPart.CFrame * attachment.CFrame
			else targetPart.CFrame + Vector3.new(0, 2.5, 0)

		rootPart.CFrame = targetCFrame
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero

		local forceField = Instance.new("ForceField")
		forceField.Visible = false
		forceField.Parent = character

		task.delay(TP_FORCEFIELD_DURATION, function()
			if forceField.Parent then
				forceField:Destroy()
			end
		end)
	end

	for _, data in destinations do
		local targetKey = data.Pair
		local targetData = destinations[targetKey]
		if not targetData then continue end

		table.insert(connections, data.Part.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then return end
			teleportPlayer(player, targetData.Part)
		end))
	end

	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		playerCooldowns[player] = nil
	end))
end

function WorldController.setupSewerSystem(
	connections: { RBXScriptConnection },
	getPlayerFaction: (player: Player) -> string?,
	broadcastMessage: (message: string) -> ()
): ()
	local folder = workspace:FindFirstChild("TerminalActions")
	if not folder then return end

	local sewerTunnel = folder:FindFirstChild("SewerTunnel") :: BasePart?
	local sewerButton = folder:FindFirstChild("SewerButton")
	local sewerHatch = folder:FindFirstChild("SewerHatch") :: BasePart?
	local sewerHatch2 = folder:FindFirstChild("SewerHatch2") :: BasePart?

	if sewerTunnel then
		sewerState.tunnel = sewerTunnel
		sewerState.tunnelOriginalCanCollide = sewerTunnel.CanCollide
		sewerState.tunnelOriginalCanQuery = sewerTunnel.CanQuery
		sewerState.tunnelOriginalTransparency = sewerTunnel.Transparency

		local tunnelPrompt = sewerTunnel:FindFirstChildWhichIsA("ProximityPrompt")
		sewerState.tunnelPrompt = tunnelPrompt

		if tunnelPrompt then
			tunnelPrompt.Enabled = false

			table.insert(connections, tunnelPrompt.Triggered:Connect(function(player: Player)
				local faction = getPlayerFaction(player)
				if faction ~= "Raiders" then return end
				if sewerState.c4Planted then return end

				sewerState.c4Planted = true
				tunnelPrompt.Enabled = false

				task.spawn(function()
					local C4_COUNTDOWN = 10
					for timer = C4_COUNTDOWN, 1, -1 do
						broadcastMessage(`SEWER BOMB PLANTED, STAND BACK: {timer}s`)
						task.wait(1)
					end

					local explosion = Instance.new("Explosion")
					explosion.Position = sewerTunnel.Position
					explosion.BlastRadius = 10
					explosion.BlastPressure = 500000

					sewerTunnel.CanCollide = false
					sewerTunnel.CanQuery = false
					sewerTunnel.Transparency = 1

					explosion.Parent = workspace

					broadcastMessage("THE SEWER TUNNEL HAS BEEN OPENED BY THE HOSTILES")
				end)
			end))
		end
	end

	if sewerHatch and sewerHatch:IsA("BasePart") then
		sewerHatch.CanCollide = false
		sewerHatch.Transparency = 1
	end

	if sewerHatch2 and sewerHatch2:IsA("BasePart") then
		sewerState.hatch2 = sewerHatch2
		sewerState.hatch2OriginalCanCollide = sewerHatch2.CanCollide
		sewerState.hatch2OriginalTransparency = sewerHatch2.Transparency
	end

	if sewerButton then
		local buttonPrompt = sewerButton:FindFirstChildWhichIsA("ProximityPrompt")
		sewerState.buttonPrompt = buttonPrompt

		if buttonPrompt then
			buttonPrompt.Enabled = false
		end

		if buttonPrompt and sewerHatch2 then
			table.insert(connections, buttonPrompt.Triggered:Connect(function(_player: Player)
				if sewerState.hatch2Open then return end

				sewerState.hatch2Open = true
				if sewerHatch2:IsA("BasePart") then
					sewerHatch2.CanCollide = false
					sewerHatch2.Transparency = 1
				end
				broadcastMessage("SEWER HATCH OPENED!")
			end))
		end
	end
end

function WorldController.resetSewerSystem(): ()
	sewerState.c4Planted = false
	sewerState.hatch2Open = false

	if sewerState.tunnel then
		sewerState.tunnel.CanCollide = sewerState.tunnelOriginalCanCollide
		sewerState.tunnel.CanQuery = sewerState.tunnelOriginalCanQuery
		sewerState.tunnel.Transparency = sewerState.tunnelOriginalTransparency
	end

	if sewerState.tunnelPrompt then
		sewerState.tunnelPrompt.Enabled = false
	end

	if sewerState.hatch2 and sewerState.hatch2:IsA("BasePart") then
		sewerState.hatch2.CanCollide = sewerState.hatch2OriginalCanCollide
		sewerState.hatch2.Transparency = sewerState.hatch2OriginalTransparency
	end

	if sewerState.buttonPrompt then
		sewerState.buttonPrompt.Enabled = false
	end
end

function WorldController.setTerminalBillboards(phaseNum: number): ()
	local folder = workspace:FindFirstChild("TerminalBillboards")
	if not folder then return end

	for _, billboard in folder:GetChildren() do
		local bbGui = billboard:FindFirstChildWhichIsA("BillboardGui")
		if bbGui then
			local num = tonumber(billboard.Name:match("P(%d+)Billboard"))
			bbGui.Enabled = num == phaseNum
		end
	end
end

function WorldController.setTerminalActionsOnOfficial(): ()
	local folder = workspace:FindFirstChild("TerminalActions")
	if not folder then return end

	local closeOnOfficial = folder:FindFirstChild("CloseOnOfficial")
	if closeOnOfficial and closeOnOfficial:IsA("BasePart") then
		closeOnOfficial.CanCollide = true
		closeOnOfficial.Transparency = 0
	end
end

function WorldController.enableSewerPrompts(): ()
	if sewerState.tunnelPrompt and not sewerState.c4Planted then
		sewerState.tunnelPrompt.Enabled = true
	end
	if sewerState.buttonPrompt then
		sewerState.buttonPrompt.Enabled = true
	end
end

function WorldController.setTerminalActionsOnEnd(): ()
	local folder = workspace:FindFirstChild("TerminalActions")
	if not folder then return end

	local closeOnOfficial = folder:FindFirstChild("CloseOnOfficial")
	if closeOnOfficial and closeOnOfficial:IsA("BasePart") then
		closeOnOfficial.CanCollide = false
		closeOnOfficial.Transparency = 1
	end

	WorldController.resetSewerSystem()
end

return WorldController
