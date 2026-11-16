--!strict
--!native
--!optimize 2

local Maps = require(script.Parent.Maps)

export type FeatureFlagName = Maps.FeatureFlagName

local FeatureFlags = {}

local resolvedFlags: { [FeatureFlagName]: boolean } = {}
local initialized = false

local function initialize()
	if initialized then
		return
	end

	local mapFlags = Maps.getFeatureFlags()
	local mapConfig = Maps.getConfig()
	resolvedFlags["ClassSystem"] = mapFlags.ClassSystem == true or mapConfig.ClassSystem == true
	resolvedFlags["Nades"] = mapFlags.Nades == true
	resolvedFlags["Roll"] = mapFlags.Roll == true

	initialized = true
end

function FeatureFlags.isEnabled(flagName: FeatureFlagName): boolean
	initialize()
	return resolvedFlags[flagName] == true
end

function FeatureFlags.getAll(): { [FeatureFlagName]: boolean }
	initialize()
	return table.clone(resolvedFlags)
end

function FeatureFlags.getAllEnabled(): { FeatureFlagName }
	initialize()

	local enabled: { FeatureFlagName } = {}
	for flagName, value in resolvedFlags do
		if value then
			table.insert(enabled, flagName)
		end
	end
	return enabled
end

return FeatureFlags
