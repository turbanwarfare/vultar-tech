--!strict
--!native
--!optimize 2

local PlayerGuiHelper = require(script.Parent.PlayerGuiHelper)

local LoadingState = {}

local LOADING_SCREEN_NAME = "VultarLoadingScreen"

function LoadingState.isLoadingActive(LoadingService: any?, playerGui: PlayerGui?): boolean
	if LoadingService then
		local success, active = pcall(function()
			return LoadingService:IsActive()
		end)
		if success and active then
			return true
		end
	end

	local gui = playerGui or PlayerGuiHelper.getPlayerGui()
	if gui then
		local loadingScreen = gui:FindFirstChild(LOADING_SCREEN_NAME)
		if loadingScreen and loadingScreen:IsA("ScreenGui") and loadingScreen.Enabled then
			return true
		end
	end

	return false
end

function LoadingState.getLoadingScreenName(): string
	return LOADING_SCREEN_NAME
end

function LoadingState.waitForLoadingComplete(LoadingService: any?, timeout: number?): boolean
	local startTime = os.clock()
	local maxTime = timeout or 60

	while os.clock() - startTime < maxTime do
		if not LoadingState.isLoadingActive(LoadingService) then
			return true
		end
		task.wait(0.1)
	end

	return false
end

return LoadingState
