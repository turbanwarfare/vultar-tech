--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local MainModule = script.Parent.Parent.Parent.Parent
local SparConfig = require(MainModule.Shared.Config.SparConfig)

local ArenaTitleClient = {}
local LEGEND_TWEEN_INFO = TweenInfo.new(3.0, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false)
local PLATINUM_TWEEN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local playerGuis: { [Player]: BillboardGui } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local activeTweens: { [Player]: { Tween } } = {}

local winRankTemplate: BillboardGui? = nil

local function getTemplates()
	if winRankTemplate then
		return
	end
	local templates = ReplicatedStorage:WaitForChild("DuelTemplates", 5) :: Folder
	winRankTemplate = templates:WaitForChild("WinRank", 5) :: BillboardGui?
end

local function shouldShowFor(player: Player): boolean
	local spectatorsTeam = Teams:FindFirstChild("Spectators")
	return player.Character ~= nil and player.Team == spectatorsTeam
end

local function getRankForWins(wins: number): (string, Color3)
	local rankName = "UNPROVEN"
	local rankColor = Color3.fromRGB(160, 160, 160)
	for _, rank in SparConfig.TITLE_THRESHOLDS do
		if wins >= rank.Wins then
			rankName = rank.Name
			rankColor = rank.Color
		else
			break
		end
	end
	return rankName, rankColor
end

local function getMilestoneColors(wins: number): (Color3, boolean)
	if wins >= 1000 then
		return Color3.fromRGB(255, 216, 58), true
	elseif wins >= 500 then
		return Color3.fromRGB(221, 0, 255), false
	elseif wins >= 250 then
		return Color3.fromRGB(0, 255, 221), false
	elseif wins >= 100 then
		return Color3.fromRGB(6, 182, 212), false
	elseif wins >= 50 then
		return Color3.fromRGB(255, 184, 62), false
	elseif wins >= 25 then
		return Color3.fromRGB(156, 163, 175), false
	elseif wins >= 10 then
		return Color3.fromRGB(204, 131, 59), false
	else
		return Color3.fromRGB(82, 82, 92), false
	end
end

local function cleanupPlayerConnections(player: Player)
	local conns = playerConnections[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end
end

local function clearTweens(player: Player)
	local tweens = activeTweens[player]
	if tweens then
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		activeTweens[player] = nil
	end
end

local function hideGui(player: Player)
	local gui = playerGuis[player]
	if gui then
		gui:Destroy()
		playerGuis[player] = nil
	end
	clearTweens(player)
end

local function triggerMilestoneAnimations(player: Player, gui: BillboardGui)
	clearTweens(player)

	local wins = player:GetAttribute("SparWins") or 0
	local mainFrame = gui:FindFirstChild("MainFrame")
	local skullFrame = mainFrame and mainFrame:FindFirstChild("SkullFrame")
	local skull = skullFrame and skullFrame:FindFirstChild("Skull") :: ImageLabel?
	if not skull then
		return
	end

	local playerTweens = {}
	activeTweens[player] = playerTweens

	if wins >= 1000 then
		local gradient = skull:FindFirstChild("LegendGradient") :: UIGradient?
		if gradient then
			gradient.Rotation = 0

			local rotationTween = TweenService:Create(gradient, LEGEND_TWEEN_INFO, { Rotation = 360 })
			rotationTween:Play()
			table.insert(playerTweens, rotationTween)
		end
	elseif wins >= 100 and wins <= 249 then
		local skullScale = skull:FindFirstChild("SkullScale") :: UIScale?
		if not skullScale then
			skullScale = Instance.new("UIScale")
			skullScale.Name = "SkullScale"
			skullScale.Parent = skull
		end

		skullScale.Scale = 0.94

		local pulseTween = TweenService:Create(skullScale, PLATINUM_TWEEN_INFO, { Scale = 1.06 })
		pulseTween:Play()
		table.insert(playerTweens, pulseTween)
	end
end

local function updateGui(player: Player)
	local gui = playerGuis[player]
	if not gui then
		return
	end

	local wins = player:GetAttribute("SparWins") or 0
	local streak = player:GetAttribute("SparStreak") or 0

	local rankName, rankColor = getRankForWins(wins)
	local mainFrame = gui:FindFirstChild("MainFrame") :: Frame?
	if not mainFrame then
		return
	end

	local nameLabel = mainFrame:FindFirstChild("NameLabel") :: TextLabel?
	if nameLabel then
		nameLabel.Text = rankName
		nameLabel.TextColor3 = rankColor
	end

	local skullFrame = mainFrame:FindFirstChild("SkullFrame") :: Frame?
	if skullFrame then
		if streak > 0 then
			skullFrame.Visible = true
			if nameLabel then
				nameLabel.Position = UDim2.fromOffset(0, 0)
			end
			local skull = skullFrame:FindFirstChild("Skull") :: ImageLabel?
			local streakText = skull and skull:FindFirstChild("StreakText") :: TextLabel?
			if skull and streakText then
				local badgeColor, isLegend = getMilestoneColors(wins)

				if isLegend then
					skull.ImageColor3 = Color3.new(1, 1, 1)
					local gradient = skull:FindFirstChild("LegendGradient") :: UIGradient?
					if not gradient then
						gradient = Instance.new("UIGradient")
						gradient.Name = "LegendGradient"
						gradient.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 204, 21)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(249, 115, 22)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 68, 68)),
						})
						gradient.Parent = skull
					end
				else
					local gradient = skull:FindFirstChild("LegendGradient")
					if gradient then
						gradient:Destroy()
					end
					skull.ImageColor3 = badgeColor
				end

				if not (wins >= 100 and wins <= 249) then
					local skullScale = skull:FindFirstChild("SkullScale")
					if skullScale then
						skullScale:Destroy()
					end
				end

				streakText.Text = tostring(streak)

				triggerMilestoneAnimations(player, gui)
			end
		else
			skullFrame.Visible = false
			if nameLabel then
				nameLabel.Position = UDim2.fromOffset(-15, 0)
			end
			clearTweens(player)
		end
	end
end

local function showGui(player: Player)
	hideGui(player)

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not rootPart then
		return
	end

	getTemplates()
	if not winRankTemplate then
		return
	end

	local gui = winRankTemplate:Clone()
	gui.Enabled = true
	gui.Adornee = rootPart
	gui.MaxDistance = SparConfig.WIN_RANK_MAX_DISTANCE
	gui.Parent = rootPart

	playerGuis[player] = gui :: BillboardGui
	updateGui(player)
end

function ArenaTitleClient.start()
	local function trackPlayer(player: Player)
		cleanupPlayerConnections(player)

		local conns = {}
		playerConnections[player] = conns

		task.spawn(function()
			local function check()
				if shouldShowFor(player) then
					showGui(player)
				else
					hideGui(player)
				end
			end

			table.insert(conns, player:GetPropertyChangedSignal("Team"):Connect(check))
			table.insert(
				conns,
				player.CharacterAdded:Connect(function()
					task.spawn(function()
						task.wait(0.2)
						check()
					end)
				end)
			)
			table.insert(
				conns,
				player.CharacterRemoving:Connect(function()
					hideGui(player)
				end)
			)

			table.insert(
				conns,
				player:GetAttributeChangedSignal("SparWins"):Connect(function()
					updateGui(player)
				end)
			)
			table.insert(
				conns,
				player:GetAttributeChangedSignal("SparStreak"):Connect(function()
					updateGui(player)
				end)
			)

			check()
		end)
	end

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end

	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		hideGui(player)
		cleanupPlayerConnections(player)
	end)
end

function ArenaTitleClient.cleanup()
	for player in pairs(playerGuis) do
		hideGui(player)
	end
	for player in pairs(playerConnections) do
		cleanupPlayerConnections(player)
	end
	winRankTemplate = nil
end

return ArenaTitleClient
