--!strict
--!native
--!optimize 2

local UserInputService = game:GetService("UserInputService")

export type InputCallbacks = {
	OnMenuToggle: () -> (),
	OnMenuClose: () -> (),
}

local InputHandler = {}

local connection: RBXScriptConnection? = nil
local menuOpenKey = Enum.KeyCode.M
local callbacks: InputCallbacks? = nil
local getIsVisible: (() -> boolean)? = nil
local isEnabled = true

function InputHandler.connect(inputCallbacks: InputCallbacks, isVisibleFn: () -> boolean): ()
	callbacks = inputCallbacks
	getIsVisible = isVisibleFn

	if connection then
		connection:Disconnect()
	end

	connection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if not callbacks or not isEnabled then
			return
		end

		if input.KeyCode == menuOpenKey then
			callbacks.OnMenuToggle()
		end

		if input.KeyCode == Enum.KeyCode.Escape and getIsVisible and getIsVisible() then
			callbacks.OnMenuClose()
		end
	end)
end

function InputHandler.disconnect(): ()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	callbacks = nil
	getIsVisible = nil
end

function InputHandler.setMenuKey(keyCode: Enum.KeyCode): ()
	menuOpenKey = keyCode
end

function InputHandler.setEnabled(enabled: boolean): ()
	isEnabled = enabled
end

return InputHandler
