--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = ReplicatedStorage:WaitForChild("MainModule")
local Packages = MainModule:WaitForChild("Packages")
local TestEZ = require(Packages:WaitForChild("TestEZ"))

local function findSpecFiles(root: Instance): { ModuleScript }
	local specs: { ModuleScript } = {}

	local function search(instance: Instance)
		for _, child in instance:GetChildren() do
			if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
				table.insert(specs, child)
			end
			search(child)
		end
	end

	search(root)
	return specs
end
local specFiles = findSpecFiles(MainModule)

print("Found " .. #specFiles .. " spec files:")
for _, spec in specFiles do
	print("  - " .. spec:GetFullName())
end
print("")

local results = TestEZ.TestBootstrap:run(specFiles)

print("")
print("=== TEST RESULTS ===")
print("Passed: " .. results.successCount)
print("Failed: " .. results.failureCount)
print("Skipped: " .. results.skippedCount)

if results.failureCount > 0 then
	print("")
	print("TESTS FAILED")
	error("Tests failed: " .. results.failureCount .. " failures")
else
	print("")
	print("ALL TESTS PASSED")
end
