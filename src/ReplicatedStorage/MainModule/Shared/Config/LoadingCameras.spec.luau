--!nocheck
return function()
	local Credits = require(script.Parent.Credits)
	local LoadingCameras = require(script.Parent.LoadingCameras)

	describe("LoadingCameras", function()
		it("only uses base names that exist in Credits.Bases", function()
			local knownBases = {}
			for _, base in Credits.Bases do
				knownBases[base.name] = true
			end

			for baseName in LoadingCameras.Bases do
				expect(knownBases[baseName]).to.equal(true)
			end
		end)

		it("gives every camera a position and an orientation", function()
			for _, cameras in LoadingCameras.Bases do
				for _, camera in cameras do
					expect(typeof(camera.position)).to.equal("Vector3")
					expect(typeof(camera.orientation)).to.equal("Vector3")
				end
			end
		end)

		it("turns orientation degrees into the matching CFrame", function()
			local cframe = LoadingCameras.toCFrame({
				position = Vector3.new(10, 20, 30),
				orientation = Vector3.new(0, 90, 0),
			})

			expect(cframe.Position:FuzzyEq(Vector3.new(10, 20, 30))).to.equal(true)
			expect(cframe.LookVector:FuzzyEq(Vector3.new(-1, 0, 0), 1e-4)).to.equal(true)
		end)
	end)
end
