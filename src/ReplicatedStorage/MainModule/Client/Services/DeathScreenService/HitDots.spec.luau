--!nocheck
return function()
	local HitDots = require(script.Parent.HitDots)

	local PART_NAMES = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart" }
	local SCATTER = {
		Vector3.new(5, -3, 2),
		Vector3.zero,
		Vector3.new(-4, 6, -1),
		Vector3.new(3, 2, -5),
		Vector3.new(-6, -4, 4),
		Vector3.new(2, -6, -3),
		Vector3.new(6, 5, 1),
	}

	local function makeFallenR6(): Model
		local model = Instance.new("Model")
		local fallen = CFrame.new(10, 1, 4) * CFrame.Angles(math.rad(90), math.rad(35), 0)
		for index, name in PART_NAMES do
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.CFrame = fallen * CFrame.new(SCATTER[index])
			part.Parent = model
		end
		return model
	end

	describe("HitDots.prepareAvatar", function()
		it("stands a fallen body upright so the camera sees it face on", function()
			local model = makeFallenR6()
			HitDots.prepareAvatar(model)

			local torso = model.Torso
			local rootGap = model.HumanoidRootPart.Position - torso.Position
			expect(torso.CFrame.UpVector.Y > 0.99).to.equal(true)
			expect(model.Head.Position.Y > torso.Position.Y + 1).to.equal(true)
			expect(model["Left Leg"].Position.Y < torso.Position.Y - 1).to.equal(true)
			expect(rootGap:Dot(rootGap) < 0.0001).to.equal(true)

			model:Destroy()
		end)
	end)
end
