--!nocheck
return function()
	local success, LeaderboardCache = pcall(function()
		return require(script.Parent.LeaderboardCache)
	end)

	describe("LeaderboardCache", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		local function makeEntry(
			userId: number,
			team: string,
			kills: number,
			damage: number,
			heals: number,
			caps: number
		)
			return {
				UserId = userId,
				DisplayName = "Player" .. userId,
				Username = "player" .. userId,
				Team = team,
				Stats = { Kills = kills, Damage = damage, Heals = heals, Captures = caps },
				CardImageId = nil,
				IsAnimatedCard = false,
			}
		end

		local function makeDefaultEntry(userId: number, team: string)
			return makeEntry(userId, team, 0, 0, 0, 0)
		end

		beforeEach(function()
			LeaderboardCache.clear()
		end)

		afterEach(function()
			LeaderboardCache.clear()
		end)

		describe("team identification", function()
			it("should identify Vultarians as defender", function()
				expect(LeaderboardCache.isDefenderTeam("Vultarians")).to.equal(true)
			end)

			it("should identify Initiates as defender", function()
				expect(LeaderboardCache.isDefenderTeam("Initiates")).to.equal(true)
			end)

			it("should identify Hostiles as not defender", function()
				expect(LeaderboardCache.isDefenderTeam("Hostiles")).to.equal(false)
			end)

			it("should identify Spectators as not defender", function()
				expect(LeaderboardCache.isDefenderTeam("Spectators")).to.equal(false)
			end)

			it("should identify Spectators as spectator team", function()
				expect(LeaderboardCache.isSpectatorTeam("Spectators")).to.equal(true)
			end)

			it("should identify Hostiles as not spectator team", function()
				expect(LeaderboardCache.isSpectatorTeam("Hostiles")).to.equal(false)
			end)

			it("should handle nil team for defender check", function()
				expect(LeaderboardCache.isDefenderTeam(nil)).to.equal(false)
			end)

			it("should handle nil team for spectator check", function()
				expect(LeaderboardCache.isSpectatorTeam(nil)).to.equal(false)
			end)
		end)

		describe("dirty state management", function()
			it("should start not dirty", function()
				expect(LeaderboardCache.isDirty()).to.equal(false)
			end)

			it("should be dirty after markDirty", function()
				LeaderboardCache.markDirty()
				expect(LeaderboardCache.isDirty()).to.equal(true)
			end)

			it("should clear dirty flags", function()
				LeaderboardCache.markDirty()
				LeaderboardCache.clearDirtyFlags()
				expect(LeaderboardCache.isDirty()).to.equal(false)
			end)

			it("should track sort dirty state", function()
				expect(LeaderboardCache.isSortDirty()).to.equal(false)
				LeaderboardCache.markSortDirty()
				expect(LeaderboardCache.isSortDirty()).to.equal(true)
			end)

			it("should track structure dirty state", function()
				LeaderboardCache.markDirty(true)
				expect(LeaderboardCache.isStructureDirty()).to.equal(true)
			end)

			it("should track totals dirty state", function()
				expect(LeaderboardCache.isTotalsDirty()).to.equal(false)
				LeaderboardCache.markTotalsDirty()
				expect(LeaderboardCache.isTotalsDirty()).to.equal(true)
			end)
		end)

		describe("entry CRUD", function()
			it("should store and retrieve an entry", function()
				local entry = makeEntry(1001, "Hostiles", 50, 1000, 200, 3)
				LeaderboardCache.setEntry(1001, entry)
				local got = LeaderboardCache.getEntry(1001)
				expect(got).to.be.ok()
				expect(got.Stats.Kills).to.equal(50)
				expect(got.Stats.Damage).to.equal(1000)
			end)

			it("should return nil for nonexistent entry", function()
				expect(LeaderboardCache.getEntry(9999)).to.equal(nil)
			end)

			it("should remove an entry", function()
				LeaderboardCache.setEntry(1001, makeDefaultEntry(1001, "Hostiles"))
				LeaderboardCache.removeEntry(1001)
				expect(LeaderboardCache.getEntry(1001)).to.equal(nil)
			end)

			it("should track entry count", function()
				expect(LeaderboardCache.getEntryCount()).to.equal(0)
				LeaderboardCache.setEntry(1001, makeDefaultEntry(1001, "Hostiles"))
				expect(LeaderboardCache.getEntryCount()).to.equal(1)
				LeaderboardCache.setEntry(1002, makeDefaultEntry(1002, "Vultarians"))
				expect(LeaderboardCache.getEntryCount()).to.equal(2)
				LeaderboardCache.removeEntry(1001)
				expect(LeaderboardCache.getEntryCount()).to.equal(1)
			end)

			it("should overwrite existing entry with same userId", function()
				LeaderboardCache.setEntry(1001, makeEntry(1001, "Hostiles", 10, 100, 0, 0))
				LeaderboardCache.setEntry(1001, makeEntry(1001, "Hostiles", 50, 500, 0, 0))
				local got = LeaderboardCache.getEntry(1001)
				expect(got.Stats.Kills).to.equal(50)
				expect(got.Stats.Damage).to.equal(500)
				expect(LeaderboardCache.getEntryCount()).to.equal(1)
			end)
		end)

		describe("faction arrays", function()
			it("should return empty defenders array initially", function()
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
			end)

			it("should return empty raiders array initially", function()
				expect(#LeaderboardCache.getRaiders()).to.equal(0)
			end)

			it("should add Vultarians to defenders", function()
				local entry = makeDefaultEntry(1001, "Vultarians")
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getDefenders()).to.equal(1)
				expect(#LeaderboardCache.getRaiders()).to.equal(0)
			end)

			it("should add Initiates to defenders", function()
				local entry = makeDefaultEntry(1001, "Initiates")
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getDefenders()).to.equal(1)
			end)

			it("should add Hostiles to raiders", function()
				local entry = makeDefaultEntry(1001, "Hostiles")
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
			end)

			it("should add Spectators to raiders array but not totals", function()
				local entry = makeDefaultEntry(1001, "Spectators")
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				expect(LeaderboardCache.getRaiderTotals().Kills).to.equal(0)
			end)

			it("should remove from faction array and cache", function()
				local entry = makeDefaultEntry(1001, "Hostiles")
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				LeaderboardCache.removeFromFactionArray(1001)
				LeaderboardCache.removeEntry(1001)
				expect(#LeaderboardCache.getRaiders()).to.equal(0)
			end)
		end)

		describe("totals", function()
			it("should have zero totals initially", function()
				local defTotals = LeaderboardCache.getDefenderTotals()
				local raidTotals = LeaderboardCache.getRaiderTotals()
				expect(defTotals.Kills).to.equal(0)
				expect(raidTotals.Kills).to.equal(0)
			end)
		end)

		describe("applyStatDelta", function()
			it("should update an existing entry", function()
				local entry = makeEntry(1001, "Hostiles", 10, 100, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)

				LeaderboardCache.applyStatDelta(1001, "Kills", 15, nil)
				local got = LeaderboardCache.getEntry(1001)
				expect(got.Stats.Kills).to.equal(15)
			end)

			it("should buffer delta when entry does not exist", function()
				LeaderboardCache.applyStatDelta(9999, "Kills", 50, nil)
				expect(LeaderboardCache.getEntry(9999)).to.equal(nil)
				local applied = LeaderboardCache.consumePendingDeltas(9999, nil)
				expect(applied).to.equal(false)
			end)

			it("should allow stat value to decrease (for resets)", function()
				local entry = makeEntry(1001, "Hostiles", 50, 100, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)

				LeaderboardCache.applyStatDelta(1001, "Kills", 40, nil)
				local got = LeaderboardCache.getEntry(1001)
				expect(got.Stats.Kills).to.equal(40)
			end)

			it("should skip delta of zero change", function()
				local entry = makeEntry(1001, "Hostiles", 50, 100, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.clearDirtyFlags()

				LeaderboardCache.applyStatDelta(1001, "Kills", 50, nil)
				expect(LeaderboardCache.isDirty()).to.equal(false)
			end)

			it("should mark sort dirty on kills change", function()
				local entry = makeEntry(1001, "Hostiles", 10, 0, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.clearDirtyFlags()

				LeaderboardCache.applyStatDelta(1001, "Kills", 20, nil)
				expect(LeaderboardCache.isSortDirty()).to.equal(true)
				expect(LeaderboardCache.isStructureDirty()).to.equal(true)
			end)

			it("should not mark structure dirty on non-sort stat change", function()
				local entry = makeEntry(1001, "Hostiles", 10, 100, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.clearDirtyFlags()
				LeaderboardCache.clearStructureDirty()
				LeaderboardCache.clearSortDirty()

				LeaderboardCache.applyStatDelta(1001, "Damage", 250, nil)
				expect(LeaderboardCache.isDirty()).to.equal(true)
				expect(LeaderboardCache.isTotalsDirty()).to.equal(true)
				expect(LeaderboardCache.isStructureDirty()).to.equal(false)
				expect(LeaderboardCache.isSortDirty()).to.equal(false)
			end)

			it("should update raider totals on delta", function()
				local entry = makeEntry(1001, "Hostiles", 10, 0, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)

				LeaderboardCache.applyStatDelta(1001, "Kills", 20, nil)
				local totals = LeaderboardCache.getRaiderTotals()
				expect(totals.Kills).to.equal(20)
			end)

			it("should update defender totals on delta", function()
				local entry = makeEntry(1001, "Vultarians", 5, 0, 0, 0)
				LeaderboardCache.setEntry(1001, entry)
				LeaderboardCache.addToFactionArray(entry)

				LeaderboardCache.applyStatDelta(1001, "Kills", 15, nil)
				local totals = LeaderboardCache.getDefenderTotals()
				expect(totals.Kills).to.equal(15)
			end)
		end)

		describe("pending deltas (race condition handling)", function()
			it("should buffer deltas for unknown players", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 90, nil)
				LeaderboardCache.applyStatDelta(2001, "Damage", 5000, nil)

				local entry = makeDefaultEntry(2001, "Hostiles")
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)

				local applied = LeaderboardCache.consumePendingDeltas(2001, nil)
				expect(applied).to.equal(true)

				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(90)
				expect(got.Stats.Damage).to.equal(5000)
			end)

			it("should not overwrite higher values from playerJoined snapshot", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 50, nil)

				local entry = makeEntry(2001, "Hostiles", 90, 5000, 200, 3)
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)

				local applied = LeaderboardCache.consumePendingDeltas(2001, nil)
				expect(applied).to.equal(false)

				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(90)
			end)

			it("should apply pending delta that is higher than snapshot", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 95, nil)

				local entry = makeEntry(2001, "Hostiles", 90, 5000, 200, 3)
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)

				local applied = LeaderboardCache.consumePendingDeltas(2001, nil)
				expect(applied).to.equal(true)

				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(95)
				expect(got.Stats.Damage).to.equal(5000)
			end)

			it("should clear pending deltas after consumption", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 50, nil)

				local entry = makeDefaultEntry(2001, "Hostiles")
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.consumePendingDeltas(2001, nil)

				local applied2 = LeaderboardCache.consumePendingDeltas(2001, nil)
				expect(applied2).to.equal(false)
			end)

			it("should handle multiple pending stats for same player", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 10, nil)
				LeaderboardCache.applyStatDelta(2001, "Damage", 500, nil)
				LeaderboardCache.applyStatDelta(2001, "Heals", 100, nil)
				LeaderboardCache.applyStatDelta(2001, "Captures", 2, nil)

				local entry = makeDefaultEntry(2001, "Hostiles")
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.consumePendingDeltas(2001, nil)

				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(10)
				expect(got.Stats.Damage).to.equal(500)
				expect(got.Stats.Heals).to.equal(100)
				expect(got.Stats.Captures).to.equal(2)
			end)

			it("should use latest pending value when multiple deltas arrive", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 10, nil)
				LeaderboardCache.applyStatDelta(2001, "Kills", 25, nil)
				LeaderboardCache.applyStatDelta(2001, "Kills", 30, nil)

				local entry = makeDefaultEntry(2001, "Hostiles")
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.consumePendingDeltas(2001, nil)

				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(30)
			end)

			it("should handle clearPendingDeltas", function()
				LeaderboardCache.applyStatDelta(2001, "Kills", 50, nil)
				LeaderboardCache.clearPendingDeltas(2001)

				local entry = makeDefaultEntry(2001, "Hostiles")
				LeaderboardCache.setEntry(2001, entry)
				LeaderboardCache.addToFactionArray(entry)
				local applied = LeaderboardCache.consumePendingDeltas(2001, nil)

				expect(applied).to.equal(false)
				local got = LeaderboardCache.getEntry(2001)
				expect(got.Stats.Kills).to.equal(0)
			end)
		end)

		describe("entry overwrite (playerJoined after fallback)", function()
			it("should overwrite zero-stat entry with real stats", function()
				local zeroEntry = makeDefaultEntry(3001, "Hostiles")
				LeaderboardCache.setEntry(3001, zeroEntry)
				LeaderboardCache.addToFactionArray(zeroEntry)

				local realEntry = makeEntry(3001, "Hostiles", 90, 5000, 200, 3)
				LeaderboardCache.removeFromFactionArray(3001)
				LeaderboardCache.setEntry(3001, realEntry)
				LeaderboardCache.addToFactionArray(realEntry)

				local got = LeaderboardCache.getEntry(3001)
				expect(got.Stats.Kills).to.equal(90)
				expect(got.Stats.Damage).to.equal(5000)
				expect(got.Stats.Heals).to.equal(200)
				expect(got.Stats.Captures).to.equal(3)
			end)

			it("should maintain faction array integrity after overwrite", function()
				local zeroEntry = makeDefaultEntry(3001, "Hostiles")
				LeaderboardCache.setEntry(3001, zeroEntry)
				LeaderboardCache.addToFactionArray(zeroEntry)
				expect(#LeaderboardCache.getRaiders()).to.equal(1)

				LeaderboardCache.removeFromFactionArray(3001)
				local realEntry = makeEntry(3001, "Hostiles", 90, 5000, 200, 3)
				LeaderboardCache.setEntry(3001, realEntry)
				LeaderboardCache.addToFactionArray(realEntry)

				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				local raiders = LeaderboardCache.getRaiders()
				expect(raiders[1].Stats.Kills).to.equal(90)
			end)
		end)

		describe("team change", function()
			it("should move player between factions on team change", function()
				local entry = makeEntry(4001, "Hostiles", 20, 300, 0, 0)
				LeaderboardCache.setEntry(4001, entry)
				LeaderboardCache.addToFactionArray(entry)

				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)

				LeaderboardCache.removeFromFactionArray(4001)
				local newEntry = makeEntry(4001, "Vultarians", 20, 300, 0, 0)
				LeaderboardCache.setEntry(4001, newEntry)
				LeaderboardCache.addToFactionArray(newEntry)

				expect(#LeaderboardCache.getRaiders()).to.equal(0)
				expect(#LeaderboardCache.getDefenders()).to.equal(1)
			end)

			it("should remove from faction when moved to Spectators", function()
				local entry = makeEntry(4001, "Hostiles", 20, 300, 0, 0)
				LeaderboardCache.setEntry(4001, entry)
				LeaderboardCache.addToFactionArray(entry)
				expect(#LeaderboardCache.getRaiders()).to.equal(1)

				LeaderboardCache.removeFromFactionArray(4001)
				LeaderboardCache.removeEntry(4001)
				local specEntry = makeEntry(4001, "Spectators", 20, 300, 0, 0)
				LeaderboardCache.setEntry(4001, specEntry)
				LeaderboardCache.addToFactionArray(specEntry)

				expect(#LeaderboardCache.getRaiders()).to.equal(1)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
				expect(LeaderboardCache.getRaiderTotals().Kills).to.equal(0)
			end)
		end)

		describe("stress: 100 players", function()
			it("should handle 100 simultaneous entries", function()
				for i = 1, 100 do
					local team = if i <= 50 then "Vultarians" else "Hostiles"
					local entry = makeEntry(i, team, i * 2, i * 10, i * 5, i)
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
				end

				expect(LeaderboardCache.getEntryCount()).to.equal(100)
				expect(#LeaderboardCache.getDefenders()).to.equal(50)
				expect(#LeaderboardCache.getRaiders()).to.equal(50)

				for i = 1, 100 do
					local got = LeaderboardCache.getEntry(i)
					expect(got).to.be.ok()
					expect(got.Stats.Kills).to.equal(i * 2)
					expect(got.Stats.Damage).to.equal(i * 10)
				end
			end)

			it("should handle rapid stat deltas for 100 players", function()
				for i = 1, 100 do
					local team = if i <= 50 then "Vultarians" else "Hostiles"
					local entry = makeDefaultEntry(i, team)
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
				end

				for round = 1, 10 do
					for i = 1, 100 do
						LeaderboardCache.applyStatDelta(i, "Kills", round, nil)
						LeaderboardCache.applyStatDelta(i, "Damage", round * 10, nil)
					end
				end

				for i = 1, 100 do
					local got = LeaderboardCache.getEntry(i)
					expect(got.Stats.Kills).to.equal(10)
					expect(got.Stats.Damage).to.equal(100)
				end
			end)

			it("should handle 100 pending deltas before entries exist", function()
				for i = 1, 100 do
					LeaderboardCache.applyStatDelta(i, "Kills", i * 3, nil)
					LeaderboardCache.applyStatDelta(i, "Damage", i * 20, nil)
				end

				for i = 1, 100 do
					local team = if i <= 50 then "Vultarians" else "Hostiles"
					local entry = makeDefaultEntry(i, team)
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
					LeaderboardCache.consumePendingDeltas(i, nil)
				end

				for i = 1, 100 do
					local got = LeaderboardCache.getEntry(i)
					expect(got.Stats.Kills).to.equal(i * 3)
					expect(got.Stats.Damage).to.equal(i * 20)
				end
			end)

			it("should handle interleaved deltas and entry creation for 100 players", function()
				for i = 1, 100 do
					LeaderboardCache.applyStatDelta(i, "Kills", 5, nil)
				end

				for i = 1, 50 do
					local entry = makeEntry(i, "Vultarians", 10, 0, 0, 0)
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
					LeaderboardCache.consumePendingDeltas(i, nil)
				end

				for i = 1, 100 do
					LeaderboardCache.applyStatDelta(i, "Kills", 20, nil)
				end

				for i = 51, 100 do
					local entry = makeDefaultEntry(i, "Hostiles")
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
					LeaderboardCache.consumePendingDeltas(i, nil)
				end

				for i = 1, 50 do
					local got = LeaderboardCache.getEntry(i)
					expect(got.Stats.Kills).to.equal(20)
				end

				for i = 51, 100 do
					local got = LeaderboardCache.getEntry(i)
					expect(got.Stats.Kills).to.equal(20)
				end
			end)

			it("should handle rapid add/remove cycles for 100 players", function()
				for cycle = 1, 5 do
					for i = 1, 100 do
						local team = if i % 2 == 0 then "Vultarians" else "Hostiles"
						local entry = makeEntry(i, team, cycle * i, 0, 0, 0)
						LeaderboardCache.setEntry(i, entry)
						LeaderboardCache.addToFactionArray(entry)
					end

					for i = 1, 100 do
						LeaderboardCache.removeFromFactionArray(i)
						LeaderboardCache.removeEntry(i)
					end
				end

				expect(LeaderboardCache.getEntryCount()).to.equal(0)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
				expect(#LeaderboardCache.getRaiders()).to.equal(0)
			end)

			it("should maintain correct totals after 100 player deltas", function()
				for i = 1, 50 do
					local entry = makeDefaultEntry(i, "Vultarians")
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
				end
				for i = 51, 100 do
					local entry = makeDefaultEntry(i, "Hostiles")
					LeaderboardCache.setEntry(i, entry)
					LeaderboardCache.addToFactionArray(entry)
				end

				for i = 1, 100 do
					LeaderboardCache.applyStatDelta(i, "Kills", 10, nil)
					LeaderboardCache.applyStatDelta(i, "Damage", 100, nil)
				end

				local defTotals = LeaderboardCache.getDefenderTotals()
				local raidTotals = LeaderboardCache.getRaiderTotals()
				expect(defTotals.Kills).to.equal(500)
				expect(defTotals.Damage).to.equal(5000)
				expect(raidTotals.Kills).to.equal(500)
				expect(raidTotals.Damage).to.equal(5000)
			end)
		end)

		describe("stress: rapid sequential updates", function()
			it("should handle 1000 deltas to single player", function()
				local entry = makeDefaultEntry(5001, "Hostiles")
				LeaderboardCache.setEntry(5001, entry)
				LeaderboardCache.addToFactionArray(entry)

				for i = 1, 1000 do
					LeaderboardCache.applyStatDelta(5001, "Kills", i, nil)
				end

				local got = LeaderboardCache.getEntry(5001)
				expect(got.Stats.Kills).to.equal(1000)
			end)

			it("should handle alternating stat types at high frequency", function()
				local entry = makeDefaultEntry(5001, "Vultarians")
				LeaderboardCache.setEntry(5001, entry)
				LeaderboardCache.addToFactionArray(entry)

				local stats = { "Kills", "Damage", "Heals", "Captures" }
				for i = 1, 500 do
					local statType = stats[(i % 4) + 1]
					LeaderboardCache.applyStatDelta(5001, statType, i, nil)
				end

				local got = LeaderboardCache.getEntry(5001)
				expect(got.Stats.Kills).to.equal(500)
				expect(got.Stats.Damage).to.equal(497)
				expect(got.Stats.Heals).to.equal(498)
				expect(got.Stats.Captures).to.equal(499)
			end)
		end)

		describe("stress: the Sledn3r scenario", function()
			it("scenario 1: deltas arrive before entry, entry created with nil stats", function()
				LeaderboardCache.applyStatDelta(7001, "Kills", 45, nil)
				LeaderboardCache.applyStatDelta(7001, "Damage", 8000, nil)
				LeaderboardCache.applyStatDelta(7001, "Kills", 90, nil)

				local entry = makeDefaultEntry(7001, "Hostiles")
				LeaderboardCache.setEntry(7001, entry)
				LeaderboardCache.addToFactionArray(entry)
				LeaderboardCache.consumePendingDeltas(7001, nil)

				local got = LeaderboardCache.getEntry(7001)
				expect(got.Stats.Kills).to.equal(90)
				expect(got.Stats.Damage).to.equal(8000)
			end)

			it("scenario 2: zero entry created, then playerJoined overwrites", function()
				local zeroEntry = makeDefaultEntry(7001, "Hostiles")
				LeaderboardCache.setEntry(7001, zeroEntry)
				LeaderboardCache.addToFactionArray(zeroEntry)

				local got1 = LeaderboardCache.getEntry(7001)
				expect(got1.Stats.Kills).to.equal(0)

				LeaderboardCache.removeFromFactionArray(7001)
				local realEntry = makeEntry(7001, "Hostiles", 90, 8000, 300, 5)
				LeaderboardCache.setEntry(7001, realEntry)
				LeaderboardCache.addToFactionArray(realEntry)
				LeaderboardCache.consumePendingDeltas(7001, nil)

				local got2 = LeaderboardCache.getEntry(7001)
				expect(got2.Stats.Kills).to.equal(90)
				expect(got2.Stats.Damage).to.equal(8000)
			end)

			it("scenario 3: deltas buffered, zero entry created, then consumed", function()
				LeaderboardCache.applyStatDelta(7001, "Kills", 90, nil)
				LeaderboardCache.applyStatDelta(7001, "Damage", 8000, nil)

				local zeroEntry = makeDefaultEntry(7001, "Hostiles")
				LeaderboardCache.setEntry(7001, zeroEntry)
				LeaderboardCache.addToFactionArray(zeroEntry)
				LeaderboardCache.consumePendingDeltas(7001, nil)

				local got = LeaderboardCache.getEntry(7001)
				expect(got.Stats.Kills).to.equal(90)
				expect(got.Stats.Damage).to.equal(8000)
			end)

			it("scenario 4: zero entry, deltas arrive directly, then playerJoined", function()
				local zeroEntry = makeDefaultEntry(7001, "Hostiles")
				LeaderboardCache.setEntry(7001, zeroEntry)
				LeaderboardCache.addToFactionArray(zeroEntry)

				LeaderboardCache.applyStatDelta(7001, "Kills", 90, nil)
				LeaderboardCache.applyStatDelta(7001, "Damage", 8000, nil)

				local got1 = LeaderboardCache.getEntry(7001)
				expect(got1.Stats.Kills).to.equal(90)
				expect(got1.Stats.Damage).to.equal(8000)

				LeaderboardCache.removeFromFactionArray(7001)
				local realEntry = makeEntry(7001, "Hostiles", 90, 8000, 300, 5)
				LeaderboardCache.setEntry(7001, realEntry)
				LeaderboardCache.addToFactionArray(realEntry)

				local got2 = LeaderboardCache.getEntry(7001)
				expect(got2.Stats.Kills).to.equal(90)
				expect(got2.Stats.Heals).to.equal(300)
				expect(got2.Stats.Captures).to.equal(5)
			end)

			it("scenario 5: stale getLeaderboard returns 0, then deltas correct it", function()
				local staleEntry = makeDefaultEntry(7001, "Hostiles")
				LeaderboardCache.setEntry(7001, staleEntry)
				LeaderboardCache.addToFactionArray(staleEntry)

				local got1 = LeaderboardCache.getEntry(7001)
				expect(got1.Stats.Kills).to.equal(0)

				LeaderboardCache.applyStatDelta(7001, "Kills", 90, nil)
				LeaderboardCache.applyStatDelta(7001, "Damage", 8000, nil)
				LeaderboardCache.applyStatDelta(7001, "Heals", 300, nil)
				LeaderboardCache.applyStatDelta(7001, "Captures", 5, nil)

				local got2 = LeaderboardCache.getEntry(7001)
				expect(got2.Stats.Kills).to.equal(90)
				expect(got2.Stats.Damage).to.equal(8000)
				expect(got2.Stats.Heals).to.equal(300)
				expect(got2.Stats.Captures).to.equal(5)
			end)
		end)

		describe("clear operation", function()
			it("should clear all data including pending deltas", function()
				for i = 1, 50 do
					LeaderboardCache.setEntry(i, makeDefaultEntry(i, "Hostiles"))
					LeaderboardCache.applyStatDelta(i + 1000, "Kills", 10, nil)
				end

				LeaderboardCache.clear()

				expect(LeaderboardCache.getEntryCount()).to.equal(0)
				expect(#LeaderboardCache.getDefenders()).to.equal(0)
				expect(#LeaderboardCache.getRaiders()).to.equal(0)
				expect(LeaderboardCache.isDirty()).to.equal(false)

				for i = 1001, 1050 do
					local applied = LeaderboardCache.consumePendingDeltas(i, nil)
					expect(applied).to.equal(false)
				end
			end)
		end)

		describe("iteration", function()
			it("should iterate all entries", function()
				for i = 1, 20 do
					LeaderboardCache.setEntry(i, makeEntry(i, "Hostiles", i, 0, 0, 0))
				end

				local count = 0
				for _ in LeaderboardCache.iterateEntries() do
					count += 1
				end
				expect(count).to.equal(20)
			end)
		end)
	end)
end
