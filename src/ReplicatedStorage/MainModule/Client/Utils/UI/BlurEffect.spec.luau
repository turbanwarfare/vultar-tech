--!nocheck
--!strict

local Lighting = game:GetService("Lighting")
local BlurEffect = require(script.Parent.BlurEffect)

return function()
	describe("BlurEffect", function()
		afterEach(function()
			local testBlur = Lighting:FindFirstChild("TestBlur")
			if testBlur then
				testBlur:Destroy()
			end
			local testBlur2 = Lighting:FindFirstChild("TestBlur2")
			if testBlur2 then
				testBlur2:Destroy()
			end
		end)

		describe("create", function()
			it("should create a blur effect in Lighting", function()
				local blur = BlurEffect.create("TestBlur")

				expect(blur).to.be.ok()
				expect(blur:IsA("BlurEffect")).to.equal(true)
				expect(blur.Parent).to.equal(Lighting)
				expect(blur.Name).to.equal("TestBlur")
			end)

			it("should use default size of 0", function()
				local blur = BlurEffect.create("TestBlur")

				expect(blur.Size).to.equal(0)
			end)

			it("should accept custom initial size", function()
				local blur = BlurEffect.create("TestBlur", 12)

				expect(blur.Size).to.equal(12)
			end)

			it("should be enabled by default", function()
				local blur = BlurEffect.create("TestBlur")

				expect(blur.Enabled).to.equal(true)
			end)
		end)

		describe("find", function()
			it("should return nil when blur does not exist", function()
				local result = BlurEffect.find("NonExistentBlur12345")

				expect(result).to.equal(nil)
			end)

			it("should find existing blur effect", function()
				local created = BlurEffect.create("TestBlur")
				local found = BlurEffect.find("TestBlur")

				expect(found).to.equal(created)
			end)
		end)

		describe("getOrCreate", function()
			it("should create new blur if none exists", function()
				local blur = BlurEffect.getOrCreate("TestBlur", 5)

				expect(blur).to.be.ok()
				expect(blur.Name).to.equal("TestBlur")
				expect(blur.Size).to.equal(5)
			end)

			it("should return existing blur if it exists", function()
				local first = BlurEffect.create("TestBlur", 10)
				local second = BlurEffect.getOrCreate("TestBlur", 20)

				expect(second).to.equal(first)
				expect(second.Size).to.equal(10)
			end)
		end)

		describe("tweenTo", function()
			it("should return a Tween object", function()
				local blur = BlurEffect.create("TestBlur", 0)
				local tween = BlurEffect.tweenTo(blur, 10, 0.1)

				expect(tween).to.be.ok()
				expect(typeof(tween)).to.equal("Instance")
			end)
		end)
	end)
end
