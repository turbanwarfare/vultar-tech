--!strict
--!native
--!optimize 2

local Workspace = workspace
local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local LeaderboardBoard = require(MainModule.Client.Components.LeaderboardBoard)
local SparConfig = require(MainModule.Shared.Config.SparConfig)

local ArenaLeaderboardClient = {}

local scope: any = nil
local activeGuis: { SurfaceGui } = {}

function ArenaLeaderboardClient.init(): () end

function ArenaLeaderboardClient.start(): ()
	if not SparConfig.LeaderboardParts then
		return
	end

	scope = Fusion.scoped(Fusion)

	local partsFolder = Workspace:FindFirstChild("LeaderboardParts")
	if not partsFolder then
		warn("[ArenaLeaderboardClient] LeaderboardParts folder not found in workspace")
		return
	end

	for partName, config in pairs(SparConfig.LeaderboardParts) do
		local part = partsFolder:FindFirstChild(partName) :: BasePart?
		if not part then
			warn("[ArenaLeaderboardClient] Display part", partName, "not found in workspace.LeaderboardParts")
			continue
		end

		local gui = LeaderboardBoard(scope, {
			Stat = config.Stat,
			DefaultScope = config.Scope,
			Label = config.Label,
			Face = config.Face,
			PixelsPerStud = config.PixelsPerStud,
		})
		gui.Adornee = part
		gui.Parent = part
		table.insert(activeGuis, gui)
	end
end

function ArenaLeaderboardClient.cleanup(): ()
	for _, gui in activeGuis do
		gui:Destroy()
	end
	table.clear(activeGuis)

	if scope then
		scope:doCleanup()
		scope = nil
	end
end

return ArenaLeaderboardClient
