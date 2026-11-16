--!strict
--!native
--!optimize 2

local StarterGui = game:GetService("StarterGui")

local CoreGuiManager = {}

local coreGuiStates: { [Enum.CoreGuiType]: boolean } = {}
local screenGuiStates: { [ScreenGui]: boolean } = {}

local CORE_TYPES = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
}

function CoreGuiManager.disableCoreGui(): ()
	for _, coreType in CORE_TYPES do
		local success, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(coreType)
		end)

		if success then
			coreGuiStates[coreType] = enabled
			pcall(function()
				StarterGui:SetCoreGuiEnabled(coreType, false)
			end)
		end
	end
end

function CoreGuiManager.restoreCoreGui(): ()
	for coreType, enabled in coreGuiStates do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, enabled)
		end)
	end
	table.clear(coreGuiStates)
end

function CoreGuiManager.disableOtherScreenGuis(playerGui: PlayerGui, excludeName: string): ()
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name ~= excludeName then
			screenGuiStates[gui] = gui.Enabled
			pcall(function()
				gui.Enabled = false
			end)
		end
	end
end

function CoreGuiManager.restoreOtherScreenGuis(): ()
	for gui, enabled in screenGuiStates do
		if gui and gui.Parent then
			pcall(function()
				gui.Enabled = enabled
			end)
		end
	end
	table.clear(screenGuiStates)
end

return CoreGuiManager
