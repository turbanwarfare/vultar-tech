--!strict
--!native
--!optimize 2

local DeepCopy = {}

function DeepCopy.copy<T>(original: T): T
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in original :: any do
		copy[key] = DeepCopy.copy(value)
	end

	return (copy :: any) :: T
end

return DeepCopy
