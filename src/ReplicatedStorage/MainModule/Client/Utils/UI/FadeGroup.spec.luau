--!nocheck
return function()
	local FadeGroup = require(script.Parent.FadeGroup)

	describe("FadeGroup", function()
		it("fades every captured element from its own base transparency", function()
			local frame = Instance.new("Frame")
			frame.BackgroundTransparency = 0.2
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.TextTransparency = 0
			label.Parent = frame

			local group = FadeGroup.new()
			FadeGroup.capture(group, { frame })

			FadeGroup.set(group, 0)
			expect(frame.BackgroundTransparency).to.equal(1)
			expect(label.TextTransparency).to.equal(1)

			FadeGroup.set(group, 0.5)
			expect(math.abs(frame.BackgroundTransparency - 0.6) < 0.001).to.equal(true)
			expect(math.abs(label.TextTransparency - 0.5) < 0.001).to.equal(true)

			FadeGroup.set(group, 1)
			expect(math.abs(frame.BackgroundTransparency - 0.2) < 0.001).to.equal(true)
			expect(label.TextTransparency).to.equal(0)
			expect(label.BackgroundTransparency).to.equal(1)

			FadeGroup.destroy(group)
			frame:Destroy()
		end)
	end)
end
