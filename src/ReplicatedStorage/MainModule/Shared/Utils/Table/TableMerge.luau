--!strict
--!native
--!optimize 2

local DeepCopy = require(script.Parent.DeepCopy)

local TableMerge = {}

function TableMerge.mergeWithDefaults<T>(data: any?, defaults: T): T
	if type(data) ~= "table" then
		return DeepCopy.copy(defaults)
	end

	local result = {} :: any

	for section, sectionDefaults in defaults :: any do
		if type(sectionDefaults) == "table" then
			result[section] = {}
			local dataSection = data[section]
			local hasDataSection = type(dataSection) == "table"

			for key, defaultValue in sectionDefaults do
				if hasDataSection then
					local savedValue = dataSection[key]
					if savedValue ~= nil and type(savedValue) == type(defaultValue) then
						result[section][key] = savedValue
					else
						result[section][key] = defaultValue
					end
				else
					result[section][key] = defaultValue
				end
			end
		else
			result[section] = sectionDefaults
		end
	end

	return result :: T
end

function TableMerge.shallowMerge<T>(target: T, source: { [string]: any }?): T
	local result = DeepCopy.copy(target)

	if type(source) ~= "table" then
		return result
	end

	for key, value in source do
		(result :: any)[key] = value
	end

	return result
end

return TableMerge
