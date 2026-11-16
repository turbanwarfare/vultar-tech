--!strict
--!native
--!optimize 2

local Workspace = workspace

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages.Fusion)

local AimChamberConfig = require(MainModule.Shared.Config.AimChamberConfig)
local Network = require(MainModule.Shared.Network)
local LeaderboardBoard = require(MainModule.Client.Components.LeaderboardBoard)

local AimChamberLeaderboardClient = {}

local scope: Fusion.Scope<any>? = nil
local activeBoards: { [Instance]: any } = {}

local function fetchLeaderboard(_stat: string, fetchScope: string): any
	return Network.AimChamber.requestLeaderboard(fetchScope)
end

function AimChamberLeaderboardClient.start(): ()
	if scope then
		return
	end
	scope = Fusion.scoped(Fusion)

	local partsFolder = Workspace:WaitForChild("LeaderboardParts", 5)
	if not partsFolder then
		warn("[AimChamberLeaderboardClient] No LeaderboardParts folder found in Workspace")
		return
	end

	for partName, config in pairs(AimChamberConfig.LeaderboardParts or {}) do
		local part = partsFolder:WaitForChild(partName, 5)
		if not part or not part:IsA("BasePart") then
			warn("[AimChamberLeaderboardClient] Display part", partName, "not found in LeaderboardParts")
			continue
		end

		print("[AimChamberLeaderboardClient] Found part", partName, "- mounting SurfaceGui")

		local boardProps = {
			Stat = config.Stat,
			DefaultScope = config.Scope,
			Label = config.Label,
			Face = config.Face,
			PixelsPerStud = config.PixelsPerStud,
			FetchFn = fetchLeaderboard,
		}

		local surfaceGui = LeaderboardBoard(scope :: any, boardProps)
		surfaceGui.Adornee = part
		surfaceGui.Parent = part

		activeBoards[part] = surfaceGui
	end
end

function AimChamberLeaderboardClient.cleanup(): ()
	if scope then
		Fusion.doCleanup(scope)
		scope = nil
	end
	table.clear(activeBoards)
end

return AimChamberLeaderboardClient
