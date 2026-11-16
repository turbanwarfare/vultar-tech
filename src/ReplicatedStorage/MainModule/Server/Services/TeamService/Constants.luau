--!strict
--!native
--!optimize 2

local Types = require(script.Parent.Types)
local SharedConstants = require(script.Parent.Parent.Parent.Parent.Shared.Config.Constants)
local Maps = require(script.Parent.Parent.Parent.Parent.Shared.Config.Maps)

type TeamConfig = Types.TeamConfig
type Faction = Types.Faction

local Constants = {}

Constants.TEAMS = Maps.getTeams() :: { TeamConfig }

Constants.FACTIONS = Maps.getFactionLists() :: { [Faction]: { string } }

Constants.GROUPS = {
	Vultarians = SharedConstants.GROUPS.VULTAR,
	Initiates = SharedConstants.GROUPS.VIA,
}

return Constants
