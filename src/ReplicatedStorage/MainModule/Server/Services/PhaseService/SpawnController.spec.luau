--!nocheck
return function()
	local SpawnController = require(script.Parent.SpawnController)
	local GameState = require(script.Parent.GameState)

	local function createMockSpawn(name: string): SpawnLocation
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = name
		spawn.Enabled = false
		return spawn
	end

	describe("SpawnController", function()
		describe("setSpawnsForPhase", function()
			it("enables correct phase spawns and disables previous phase spawns", function()
				local state = GameState.new()
				local p1Spawn1 = createMockSpawn("P1_Defenders")
				local p1Spawn2 = createMockSpawn("P1_Raiders")
				local p2Spawn1 = createMockSpawn("P2_Defenders")
				local p2Spawn2 = createMockSpawn("P2_Raiders")
				local p3Spawn1 = createMockSpawn("P3_Defenders")
				local p3Spawn2 = createMockSpawn("P3_Raiders")

				state.allPhaseSpawns = { p1Spawn1, p1Spawn2, p2Spawn1, p2Spawn2, p3Spawn1, p3Spawn2 }
				state.spawnCache["Phase 1"] = { p1Spawn1, p1Spawn2 }
				state.spawnCache["Phase 2"] = { p2Spawn1, p2Spawn2 }
				state.spawnCache["Phase 3"] = { p3Spawn1, p3Spawn2 }

				SpawnController.setSpawnsForPhase(state, "phase1")
				expect(p1Spawn1.Enabled).to.equal(true)
				expect(p1Spawn2.Enabled).to.equal(true)
				expect(p2Spawn1.Enabled).to.equal(false)
				expect(p2Spawn2.Enabled).to.equal(false)
				expect(p3Spawn1.Enabled).to.equal(false)
				expect(p3Spawn2.Enabled).to.equal(false)

				SpawnController.setSpawnsForPhase(state, "phase2")
				expect(p1Spawn1.Enabled).to.equal(false)
				expect(p1Spawn2.Enabled).to.equal(false)
				expect(p2Spawn1.Enabled).to.equal(true)
				expect(p2Spawn2.Enabled).to.equal(true)
				expect(p3Spawn1.Enabled).to.equal(false)
				expect(p3Spawn2.Enabled).to.equal(false)

				SpawnController.setSpawnsForPhase(state, "phase3")
				expect(p1Spawn1.Enabled).to.equal(false)
				expect(p1Spawn2.Enabled).to.equal(false)
				expect(p2Spawn1.Enabled).to.equal(false)
				expect(p2Spawn2.Enabled).to.equal(false)
				expect(p3Spawn1.Enabled).to.equal(true)
				expect(p3Spawn2.Enabled).to.equal(true)
			end)

			it("preserves active spawns when called with ended or idle", function()
				local state = GameState.new()
				local p3Spawn = createMockSpawn("P3_Spawn")
				p3Spawn.Enabled = true

				state.allPhaseSpawns = { p3Spawn }
				state.spawnCache["Phase 3"] = { p3Spawn }

				SpawnController.setSpawnsForPhase(state, "ended")
				expect(p3Spawn.Enabled).to.equal(true)

				SpawnController.setSpawnsForPhase(state, "idle")
				expect(p3Spawn.Enabled).to.equal(true)
			end)

			it("does not disable active spawns when target folder is missing from cache", function()
				local state = GameState.new()
				local activeSpawn = createMockSpawn("Active_Spawn")
				activeSpawn.Enabled = true

				state.allPhaseSpawns = { activeSpawn }

				SpawnController.setSpawnsForPhase(state, "phase1")
				expect(activeSpawn.Enabled).to.equal(true)
			end)
		end)

		describe("cleanup", function()
			it("enables all phase spawns and clears state tables", function()
				local state = GameState.new()
				local p1Spawn = createMockSpawn("P1_Spawn")
				local p2Spawn = createMockSpawn("P2_Spawn")
				p1Spawn.Enabled = false
				p2Spawn.Enabled = false

				state.allPhaseSpawns = { p1Spawn, p2Spawn }
				state.spawnCache["Phase 1"] = { p1Spawn }
				state.spawnCache["Phase 2"] = { p2Spawn }
				state.spectatorSpawns = { createMockSpawn("Spec_Spawn") }

				SpawnController.cleanup(state)

				expect(p1Spawn.Enabled).to.equal(true)
				expect(p2Spawn.Enabled).to.equal(true)
				expect(#state.allPhaseSpawns).to.equal(0)
				expect(next(state.spawnCache)).to.equal(nil)
				expect(#state.spectatorSpawns).to.equal(0)
			end)
		end)
	end)
end
