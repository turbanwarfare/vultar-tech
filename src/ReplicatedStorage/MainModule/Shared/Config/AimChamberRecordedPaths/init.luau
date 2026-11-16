--!strict

type PathFrame = {
	Position: Vector3,
	Crouching: boolean,
	Jumping: boolean,
	Time: number,
}

export type RecordedPath = { PathFrame }

local AimChamberRecordedPaths: { [string]: RecordedPath } = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then
		local success, result = pcall(require, module)
		if success and type(result) == "table" then
			AimChamberRecordedPaths[module.Name] = result :: RecordedPath
		else
			warn("Failed to load AimChamber recorded path: " .. module.Name)
		end
	end
end

return AimChamberRecordedPaths
