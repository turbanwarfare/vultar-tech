--!nocheck
return function()
	local GameState = require(script.Parent.GameState)

	describe("GameState", function()
		describe("new", function()
			it("creates a valid state", function()
				local state = GameState.new()
				expect(state).to.be.ok()
			end)

			it("starts in idle phase", function()
				expect(GameState.new().currentPhase).to.equal("idle")
			end)

			it("starts not official", function()
				expect(GameState.new().official).to.equal(false)
			end)

			it("starts with zero timers", function()
				local state = GameState.new()
				expect(state.raidTimeRemaining).to.equal(0)
				expect(state.termTimeRemaining).to.equal(0)
			end)

			it("starts with no winner or overtime", function()
				local state = GameState.new()
				expect(state.winner).to.equal(nil)
				expect(state.overtime).to.equal(false)
			end)

			it("starts with conquest inactive", function()
				local state = GameState.new()
				expect(state.conquestActive).to.equal(false)
				expect(state.conquestNode).to.equal(nil)
				expect(state.conquestCaptureProgress).to.equal(0)
				expect(state.conquestOwner).to.equal(nil)
				expect(state.conquestCaptureTeam).to.equal(nil)
				expect(state.defendersPushbackEnabled).to.equal(false)
				expect(state.conquestNodeCompleted).to.equal(nil)
				expect(state.conquestTimerRestored).to.equal(false)
			end)

			it("starts with zero payload progress", function()
				local state = GameState.new()
				expect(state.payloadProgress).to.equal(0)
				expect(state.payloadMaxProgress).to.equal(0)
				expect(state.payloadModel).to.equal(nil)
			end)

			it("starts with empty collections", function()
				local state = GameState.new()
				expect(#state.sortedPathNodes).to.equal(0)
				expect(next(state.nodePositionByName)).to.equal(nil)
				expect(#state.connections).to.equal(0)
				expect(next(state.spawnCache)).to.equal(nil)
			end)
		end)

		describe("reset", function()
			it("resets all modified fields to defaults", function()
				local state = GameState.new()
				state.currentPhase = "phase3"
				state.official = true
				state.raidTimeRemaining = 500
				state.termTimeRemaining = 300
				state.winner = "Raiders"
				state.overtime = true
				state.conquestActive = true
				state.conquestNode = "TermNode2"
				state.conquestOwner = "Raiders"
				state.defendersPushbackEnabled = true
				state.conquestNodeCompleted = "TermNode2"
				state.conquestTimerRestored = true
				state.payloadProgress = 0.75
				state.waitingForTrainDelivery = true

				GameState.reset(state)

				expect(state.currentPhase).to.equal("idle")
				expect(state.official).to.equal(false)
				expect(state.raidTimeRemaining).to.equal(0)
				expect(state.termTimeRemaining).to.equal(0)
				expect(state.winner).to.equal(nil)
				expect(state.overtime).to.equal(false)
				expect(state.conquestActive).to.equal(false)
				expect(state.conquestNode).to.equal(nil)
				expect(state.conquestOwner).to.equal(nil)
				expect(state.defendersPushbackEnabled).to.equal(false)
				expect(state.conquestNodeCompleted).to.equal(nil)
				expect(state.conquestTimerRestored).to.equal(false)
				expect(state.payloadProgress).to.equal(0)
				expect(state.waitingForTrainDelivery).to.equal(false)
			end)

			it("clears path node tables", function()
				local state = GameState.new()
				table.insert(state.sortedPathNodes, { Name = "N1", Position = Vector3.zero, Order = 1 })
				state.nodePositionByName["N1"] = Vector3.zero

				GameState.reset(state)

				expect(#state.sortedPathNodes).to.equal(0)
				expect(next(state.nodePositionByName)).to.equal(nil)
			end)

			it("clears spawn caches", function()
				local state = GameState.new()
				state.spawnCache["Phase 1"] = {}
				table.insert(state.allPhaseSpawns, Instance.new("SpawnLocation"))

				GameState.reset(state)

				expect(next(state.spawnCache)).to.equal(nil)
				expect(#state.allPhaseSpawns).to.equal(0)
			end)

			it("clears thread and connection references", function()
				local state = GameState.new()
				state.gameLoopThread = coroutine.create(function() end)

				GameState.reset(state)

				expect(state.gameLoopThread).to.equal(nil)
				expect(state.heartbeatConnection).to.equal(nil)
			end)
		end)
	end)
end
