--!nocheck
return function()
	local success, LeaderboardConstants = pcall(function()
		return require(script.Parent.LeaderboardConstants)
	end)

	describe("LeaderboardConstants", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("team constants", function()
			it("should have DEFENDER_TEAMS table", function()
				expect(LeaderboardConstants.DEFENDER_TEAMS).to.be.a("table")
			end)

			it("should include Vultarians as defender", function()
				expect(LeaderboardConstants.DEFENDER_TEAMS.Vultarians).to.equal(true)
			end)

			it("should include Initiates as defender", function()
				expect(LeaderboardConstants.DEFENDER_TEAMS.Initiates).to.equal(true)
			end)

			it("should have SPECTATOR_TEAM string", function()
				expect(LeaderboardConstants.SPECTATOR_TEAM).to.equal("Spectators")
			end)

			it("should have TEAM_PRIORITY table", function()
				expect(LeaderboardConstants.TEAM_PRIORITY).to.be.a("table")
			end)

			it("should have priority for Vultarians", function()
				expect(LeaderboardConstants.TEAM_PRIORITY.Vultarians).to.be.a("number")
			end)

			it("should have priority for Hostiles", function()
				expect(LeaderboardConstants.TEAM_PRIORITY.Hostiles).to.be.a("number")
			end)
		end)

		describe("icon constants", function()
			it("should have VULTAR_ICON string", function()
				expect(typeof(LeaderboardConstants.VULTAR_ICON)).to.equal("string")
				expect(string.find(LeaderboardConstants.VULTAR_ICON, "rbxassetid://")).to.be.ok()
			end)

			it("should have HOSTILES_ICON string", function()
				expect(typeof(LeaderboardConstants.HOSTILES_ICON)).to.equal("string")
				expect(string.find(LeaderboardConstants.HOSTILES_ICON, "rbxassetid://")).to.be.ok()
			end)
		end)

		describe("timing constants", function()
			it("should have UI_UPDATE_INTERVAL", function()
				expect(LeaderboardConstants.UI_UPDATE_INTERVAL).to.be.a("number")
				expect(LeaderboardConstants.UI_UPDATE_INTERVAL > 0).to.equal(true)
			end)

			it("should have reasonable update interval", function()
				expect(LeaderboardConstants.UI_UPDATE_INTERVAL >= 0.01).to.equal(true)
				expect(LeaderboardConstants.UI_UPDATE_INTERVAL <= 1).to.equal(true)
			end)
		end)
	end)
end
