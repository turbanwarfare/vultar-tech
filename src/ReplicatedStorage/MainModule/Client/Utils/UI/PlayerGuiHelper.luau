--!strict
--!native
--!optimize 2

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PlayerGuiHelper = {}

local DEFAULT_TIMEOUT = 15

function PlayerGuiHelper.waitForPlayerGui(timeout: number?): PlayerGui?
	local player = LocalPlayer
	if not player then
		return nil
	end

	local gui = player:FindFirstChild("PlayerGui")
	if gui and gui:IsA("PlayerGui") then
		return gui
	end

	local maxTime = timeout or DEFAULT_TIMEOUT
	local success, result = pcall(function()
		return player:WaitForChild("PlayerGui", maxTime)
	end)

	if success and result and result:IsA("PlayerGui") then
		return result
	end

	return nil
end

function PlayerGuiHelper.getPlayerGui(): PlayerGui?
	local player = LocalPlayer
	if not player then
		return nil
	end

	local gui = player:FindFirstChild("PlayerGui")
	if gui and gui:IsA("PlayerGui") then
		return gui
	end

	return nil
end

function PlayerGuiHelper.isScreenGuiActive(guiName: string, playerGui: PlayerGui?): boolean
	local gui = playerGui or PlayerGuiHelper.getPlayerGui()
	if not gui then
		return false
	end

	local screenGui = gui:FindFirstChild(guiName)
	if screenGui and screenGui:IsA("ScreenGui") and screenGui.Enabled then
		return true
	end

	return false
end

return PlayerGuiHelper
