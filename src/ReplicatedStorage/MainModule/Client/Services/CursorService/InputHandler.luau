--!strict
--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

export type RadialCallbacks = {
	OnOpen: () -> (),
	OnClose: () -> (),
	OnQuickSwitch: (() -> ())?,
}

local InputHandler = {}

local keyConnection: RBXScriptConnection? = nil
local keyReleaseConnection: RBXScriptConnection? = nil

local radialKey = Enum.KeyCode.T
local quickSwitchKey = Enum.KeyCode.X
local callbacks: RadialCallbacks? = nil
local isOpen = false

function InputHandler.connect(inputCallbacks: RadialCallbacks): ()
	callbacks = inputCallbacks

	if keyConnection then
		keyConnection:Disconnect()
	end

	if keyReleaseConnection then
		keyReleaseConnection:Disconnect()
	end

	keyConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == radialKey and callbacks then
			isOpen = true
			callbacks.OnOpen()
		elseif input.KeyCode == quickSwitchKey and callbacks and callbacks.OnQuickSwitch then
			callbacks.OnQuickSwitch()
		end
	end)

	keyReleaseConnection = UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.KeyCode == radialKey and callbacks then
			isOpen = false
			callbacks.OnClose()
		end
	end)
end

function InputHandler.disconnect(): ()
	if keyConnection then
		keyConnection:Disconnect()
		keyConnection = nil
	end

	if keyReleaseConnection then
		keyReleaseConnection:Disconnect()
		keyReleaseConnection = nil
	end

	callbacks = nil
	isOpen = false
end

function InputHandler.getMouseLocation(): Vector2
	return UserInputService:GetMouseLocation()
end

function InputHandler.setRadialKey(keyCode: Enum.KeyCode): ()
	radialKey = keyCode
end

function InputHandler.isRadialOpen(): boolean
	return isOpen
end

return InputHandler
