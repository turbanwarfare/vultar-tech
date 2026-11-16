--!nocheck
return function()
	local Constants = require(script.Parent.Constants)
	local Types = require(script.Parent.Types)

	describe("TeamService Constants", function()
		describe("TEAMS", function()
			it("should have teams array", function()
				expect(Constants.TEAMS).to.be.ok()
				expect(typeof(Constants.TEAMS)).to.equal("table")
				expect(#Constants.TEAMS > 0).to.equal(true)
			end)

			it("should have valid structure for each team", function()
				for _, team in Constants.TEAMS do
					expect(team.Name).to.be.ok()
					expect(typeof(team.Name)).to.equal("string")
					expect(team.Color).to.be.ok()
					expect(typeof(team.AutoAssignable)).to.equal("boolean")
				end
			end)

			it("should have required teams", function()
				local teamNames = {}
				for _, team in Constants.TEAMS do
					teamNames[team.Name] = true
				end

				expect(teamNames["Vultarians"]).to.equal(true)
				expect(teamNames["Initiates"]).to.equal(true)
				expect(teamNames["Hostiles"]).to.equal(true)
				expect(teamNames["Spectators"]).to.equal(true)
			end)
		end)

		describe("FACTIONS", function()
			it("should have factions table", function()
				expect(Constants.FACTIONS).to.be.ok()
				expect(typeof(Constants.FACTIONS)).to.equal("table")
			end)

			it("should have Defenders faction", function()
				expect(Constants.FACTIONS.Defenders).to.be.ok()
				expect(typeof(Constants.FACTIONS.Defenders)).to.equal("table")
			end)

			it("should have Raiders faction", function()
				expect(Constants.FACTIONS.Raiders).to.be.ok()
				expect(typeof(Constants.FACTIONS.Raiders)).to.equal("table")
			end)

			it("should have Neutral faction", function()
				expect(Constants.FACTIONS.Neutral).to.be.ok()
				expect(typeof(Constants.FACTIONS.Neutral)).to.equal("table")
			end)

			it("should map teams to factions correctly", function()
				expect(table.find(Constants.FACTIONS.Defenders, "Vultarians")).to.be.ok()
				expect(table.find(Constants.FACTIONS.Defenders, "Initiates")).to.be.ok()
				expect(table.find(Constants.FACTIONS.Raiders, "Hostiles")).to.be.ok()
				expect(table.find(Constants.FACTIONS.Neutral, "Spectators")).to.be.ok()
			end)
		end)

		describe("GROUPS", function()
			it("should have group IDs", function()
				expect(Constants.GROUPS).to.be.ok()
				expect(typeof(Constants.GROUPS.Vultarians)).to.equal("number")
				expect(typeof(Constants.GROUPS.Initiates)).to.equal("number")
			end)
		end)
	end)

	describe("TeamService Types", function()
		it("should export types module", function()
			expect(Types).to.equal(nil)
		end)
	end)
end
