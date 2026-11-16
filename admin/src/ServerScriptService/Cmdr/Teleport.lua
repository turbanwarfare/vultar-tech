return function(character: Model, cframe: CFrame)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local seatWeld = humanoid.SeatPart and humanoid.SeatPart:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
		humanoid.Sit = false
	end

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
		end
	end

	character:PivotTo(cframe + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)) / 10)
end
