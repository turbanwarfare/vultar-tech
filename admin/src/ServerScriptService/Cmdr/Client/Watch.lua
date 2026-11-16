local Players = game:GetService("Players")

local watching: Player? = nil
local characterChanged: RBXScriptConnection? = nil

local function view(player: Player)
	local humanoid = player.Character and player.Character:WaitForChild("Humanoid", 10)
	if humanoid and (watching or Players.LocalPlayer) == player then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local Watch = {}

function Watch.SetTarget(target: Player?)
	if characterChanged then
		characterChanged:Disconnect()
		characterChanged = nil
	end

	if typeof(target) == "Instance" and target:IsA("Player") and target ~= Players.LocalPlayer then
		watching = target
		characterChanged = target:GetPropertyChangedSignal("Character"):Connect(function()
			view(target)
		end)
		view(target)
	else
		watching = nil
		view(Players.LocalPlayer)
	end
end

return Watch
