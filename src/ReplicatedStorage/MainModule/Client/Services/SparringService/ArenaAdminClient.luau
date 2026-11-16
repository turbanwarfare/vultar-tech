local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Icon = require(Packages:WaitForChild("TopbarPlus", 5))
local Iris = require(Packages:WaitForChild("iris", 5))
local Network = require(MainModule.Shared.Network)

local ArenaAdminClient = {}
ArenaAdminClient.Name = "ArenaAdminClient"

local topbarIcon: any = nil

local isWindowOpen = Iris.State(false)

local targetPlayerState = Iris.State("")

local allTimeWins = Iris.State(0)
local allTimeLosses = Iris.State(0)
local allTimeKills = Iris.State(0)
local allTimeDamage = Iris.State(0)

local weeklyWins = Iris.State(0)
local weeklyKills = Iris.State(0)

local monthlyWins = Iris.State(0)
local monthlyKills = Iris.State(0)

local injectMapName = Iris.State("Sparring Arena")
local injectOpponentName = Iris.State("Opponent")
local injectWinLoss = Iris.State("Win")
local injectVultarianScore = Iris.State(1)
local injectHostileScore = Iris.State(0)
local injectKills = Iris.State(0)
local injectDamage = Iris.State(0)
local injectDevMandated = Iris.State(false)

local ADMIN_ICON = "rbxassetid://130980269883607"

local function onIconSelected(): ()
	isWindowOpen:set(true)
end

local function onIconDeselected(): ()
	isWindowOpen:set(false)
end

function ArenaAdminClient.createTopbarIcon(): ()
	if topbarIcon then
		return
	end

	topbarIcon = Icon.new()
		:setImage(ADMIN_ICON)
		:setLabel("")
		:setOrder(7)
		:setEnabled(true)
		:setCaption("VDI VSA Panel")
		:bindEvent("selected", onIconSelected)
		:bindEvent("deselected", onIconDeselected)

	isWindowOpen:onChange(function(val)
		if val then
			topbarIcon:select()
		else
			topbarIcon:deselect()
		end
	end)
end

function ArenaAdminClient.init(): ()
	pcall(Iris.Init)

	Iris:Connect(function()
		if not isWindowOpen.value then
			return
		end

		Iris.Window({ "VDI VSA Panel" }, { isOpened = isWindowOpen })

		Iris.InputText({ "Username" }, { text = targetPlayerState })
		local target = targetPlayerState.value

		Iris.SeparatorText({ "Update Stats" })

		Iris.SeparatorText({ "All Time" })
		Iris.InputNum({ "Wins", 1, 0, 999999 }, { number = allTimeWins })
		Iris.InputNum({ "Losses", 1, 0, 999999 }, { number = allTimeLosses })
		Iris.InputNum({ "Kills", 1, 0, 999999 }, { number = allTimeKills })
		Iris.InputNum({ "Damage", 1, 0, 9999999 }, { number = allTimeDamage })

		Iris.SeparatorText({ "Weekly" })
		Iris.InputNum({ "Wins##wk", 1, 0, 999999 }, { number = weeklyWins })
		Iris.InputNum({ "Kills##wk", 1, 0, 999999 }, { number = weeklyKills })

		Iris.SeparatorText({ "Monthly" })
		Iris.InputNum({ "Wins##mo", 1, 0, 999999 }, { number = monthlyWins })
		Iris.InputNum({ "Kills##mo", 1, 0, 999999 }, { number = monthlyKills })

		if Iris.Button({ "Update Player Stats" }).clicked() then
			if target ~= "" then
				local payload = {
					AllTime = {
						MatchesWon = allTimeWins.value,
						MatchesLost = allTimeLosses.value,
						Kills = allTimeKills.value,
						Damage = allTimeDamage.value,
					},
					LastWeek = {
						MatchesWon = weeklyWins.value,
						Kills = weeklyKills.value,
					},
					LastMonth = {
						MatchesWon = monthlyWins.value,
						Kills = monthlyKills.value,
					},
				}
				task.spawn(Network.Spar.requestAdminEditStats, target, payload)
			end
		end

		Iris.SeparatorText({ "Inject Match History" })
		Iris.InputText({ "Map Name" }, { text = injectMapName })
		Iris.InputText({ "Opponent Name" }, { text = injectOpponentName })
		Iris.ComboArray({ "Result" }, { index = injectWinLoss }, { "Win", "Loss" })
		Iris.InputNum({ "Vultarian Score", 1, 0, 100 }, { number = injectVultarianScore })
		Iris.InputNum({ "Hostile Score", 1, 0, 100 }, { number = injectHostileScore })
		Iris.InputNum({ "Kills##inj", 1, 0, 999 }, { number = injectKills })
		Iris.InputNum({ "Damage##inj", 1, 0, 99999 }, { number = injectDamage })
		Iris.Checkbox({ "Developer Mandated Match History" }, { isChecked = injectDevMandated })

		if Iris.Button({ "Inject Match" }).clicked() then
			if target ~= "" then
				local win = injectWinLoss.value == "Win"
				local matchData = {
					MatchId = "Admin_" .. tostring(os.time()),
					GameType = "Spar",
					WinnerName = win and target or injectOpponentName.value,
					LoserName = win and injectOpponentName.value or target,
					Timestamp = os.time(),
					EndTimestamp = os.time(),
					Duration = 60,
					MapName = injectMapName.value,
					GunName = injectDevMandated.value and "VDI_INJECTED" or "Spar",
					Rounds = 1,
					HealthOption = "100",
					VultarianName = target,
					HostileName = injectOpponentName.value,
					VultarianWins = injectVultarianScore.value,
					HostileWins = injectHostileScore.value,
					Player1UserId = 0,
					Player2UserId = 0,
					RoundBreakdown = {},
					Player1EndHealth = 100,
					Player2EndHealth = 0,
					DeveloperMandated = injectDevMandated.value,
				}
				task.spawn(Network.Spar.requestAdminInjectMatch, target, matchData)
			end
		end

		Iris.End()
	end)
end

function ArenaAdminClient.start(): ()
	task.spawn(function()
		local hasAccess = Network.Spar.requestAdminCheckAccess()
		if hasAccess then
			ArenaAdminClient.createTopbarIcon()
		end
	end)
end

return ArenaAdminClient
