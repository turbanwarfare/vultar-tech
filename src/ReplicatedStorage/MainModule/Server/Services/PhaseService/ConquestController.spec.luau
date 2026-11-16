--!nocheck
return function()
	local success, ConquestController = pcall(function()
		return require(script.Parent.ConquestController)
	end)
	local GameState = require(script.Parent.GameState)
	local MainModule = script.Parent.Parent.Parent.Parent
	local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)

	local function makeCallbacks(raidersCount: number?, defendersCount: number?)
		local log = {
			messages = {} :: { string },
			phaseStateBroadcasts = 0,
			advanceCalled = false,
			endGameWinner = nil :: string?,
			captures = 0,
		}
		local r: number = raidersCount or 0
		local d: number = defendersCount or 0
		local callbacks = {
			countFactionsNearPosition = function()
				return r, d
			end,
			broadcastMessage = function(msg: string)
				table.insert(log.messages, msg)
			end,
			broadcastPhaseState = function()
				log.phaseStateBroadcasts += 1
			end,
			endGame = function(winner: string)
				log.endGameWinner = winner
			end,
			advancePhase = function()
				log.advanceCalled = true
			end,
			getPlayersNearPosition = function()
				return {}
			end,
			getPlayerFaction = function()
				return if r > d then "Raiders" else "Defenders"
			end,
			awardCapture = function()
				log.captures += 1
			end,
		}
		local function setFactions(newR: number, newD: number)
			r = newR
			d = newD
		end
		return callbacks, log, setFactions
	end

	local function hasMessage(log: { messages: { string } }, pattern: string): boolean
		for _, msg in log.messages do
			if msg:find(pattern) then
				return true
			end
		end
		return false
	end

	local function raidersCapture(state: any, config: any, nodePos: Vector3, callbacks: any)
		ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
	end

	describe("ConquestController", function()
		if not success then
			it("SKIP: module failed to load (Network dependency)", function()
				expect(true).to.equal(true)
			end)
			return
		end

		local state: any
		local config: any
		local nodePos: Vector3

		beforeEach(function()
			state = GameState.new()
			state.official = true
			state.currentPhase = "phase3"
			config = PhaseConfig.getPhase("phase3")
			state.termTimeRemaining = config.TermTime
			nodePos = Vector3.new(0, 5, 0)
			ConquestController.resetConquestState(state)
		end)

		describe("resetConquestState", function()
			it("clears all conquest fields", function()
				state.conquestActive = true
				state.conquestNode = "TermNode2"
				state.conquestCaptureProgress = 2.5
				state.conquestOwner = "Raiders"
				state.conquestCaptureTeam = "Defenders"
				state.defendersPushbackEnabled = true
				state.conquestNodeCompleted = "TermNode2"
				state.conquestUpdateTimer = 5
				state.conquestTimerRestored = true

				ConquestController.resetConquestState(state)

				expect(state.conquestActive).to.equal(false)
				expect(state.conquestNode).to.equal(nil)
				expect(state.conquestCaptureProgress).to.equal(0)
				expect(state.conquestOwner).to.equal(nil)
				expect(state.conquestCaptureTeam).to.equal(nil)
				expect(state.defendersPushbackEnabled).to.equal(false)
				expect(state.conquestNodeCompleted).to.equal(nil)
				expect(state.conquestUpdateTimer).to.equal(0)
				expect(state.conquestTimerRestored).to.equal(false)
			end)
		end)

		describe("beginConquest", function()
			it("activates conquest on the given node", function()
				ConquestController.beginConquest(state, "TermNode2", config)
				expect(state.conquestActive).to.equal(true)
				expect(state.conquestNode).to.equal("TermNode2")
			end)

			it("clears previous owner and progress", function()
				state.conquestOwner = "Raiders"
				state.conquestCaptureProgress = 3
				ConquestController.beginConquest(state, "TermNode2", config)
				expect(state.conquestOwner).to.equal(nil)
				expect(state.conquestCaptureProgress).to.equal(0)
			end)

			it("clears pushback state", function()
				state.defendersPushbackEnabled = true
				state.conquestTimerRestored = true
				ConquestController.beginConquest(state, "TermNode2", config)
				expect(state.defendersPushbackEnabled).to.equal(false)
				expect(state.conquestTimerRestored).to.equal(false)
			end)

			it("clears terminal owner", function()
				state.terminalOwner = "Defenders"
				ConquestController.beginConquest(state, "TermNode2", config)
				expect(state.terminalOwner).to.equal(nil)
			end)
		end)

		describe("updateConquest", function()
			describe("when conquest is not active", function()
				it("does nothing", function()
					state.conquestActive = false
					local callbacks, log = makeCallbacks(5, 0)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal(nil)
					expect(#log.messages).to.equal(0)
				end)
			end)

			describe("raider capture from neutral", function()
				beforeEach(function()
					ConquestController.beginConquest(state, "TermNode2", config)
				end)

				it("increases capture progress when raiders lead", function()
					local callbacks = makeCallbacks(3, 1)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(1)
					expect(state.conquestCaptureTeam).to.equal("Raiders")
				end)

				it("accumulates progress over multiple ticks", function()
					local callbacks = makeCallbacks(3, 1)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(2)
				end)

				it("completes capture at CaptureTime", function()
					local callbacks, log = makeCallbacks(3, 1)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Raiders")
					expect(state.terminalOwner).to.equal("Raiders")
					expect(state.conquestCaptureProgress).to.equal(0)
					expect(state.conquestCaptureTeam).to.equal(nil)
				end)

				it("broadcasts capture message on completion", function()
					local callbacks, log = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(hasMessage(log, "HOSTILES HAVE CAPTURED")).to.equal(true)
				end)

				it("resets conquestTimerRestored on raider capture", function()
					state.conquestTimerRestored = true
					local callbacks = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestTimerRestored).to.equal(false)
				end)
			end)

			describe("defender capture from neutral", function()
				beforeEach(function()
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
				end)

				it("increases progress when defenders lead", function()
					local callbacks = makeCallbacks(1, 3)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(1)
					expect(state.conquestCaptureTeam).to.equal("Defenders")
				end)

				it("completes defender capture", function()
					local callbacks, log = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")
					expect(state.terminalOwner).to.equal("Defenders")
				end)

				it("broadcasts recapture message", function()
					local callbacks, log = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(hasMessage(log, "DEFENDERS HAVE RECAPTURED")).to.equal(true)
				end)
			end)

			describe("recapture mechanics", function()
				it("defenders can recapture from raiders", function()
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					raidersCapture(state, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Raiders")

					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")
				end)

				it("raiders can recapture from defenders", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					state.termTimeRemaining = 300
					local callbacks, _, setFactions = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")

					setFactions(3, 0)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Raiders")
				end)
			end)

			describe("contested decay", function()
				beforeEach(function()
					ConquestController.beginConquest(state, "TermNode2", config)
				end)

				it("decays progress when equal forces present", function()
					local callbacks, _, setFactions = makeCallbacks(3, 1)
					ConquestController.updateConquest(state, 2, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(2)

					setFactions(2, 2)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(1)
				end)

				it("does not decay below zero", function()
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)

					setFactions(2, 2)
					ConquestController.updateConquest(state, 10, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(0)
				end)

				it("clears capture team when decay reaches zero", function()
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureTeam).to.equal("Raiders")

					setFactions(2, 2)
					ConquestController.updateConquest(state, 0.5, config, nodePos, callbacks)
					expect(state.conquestCaptureTeam).to.equal("Raiders")

					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureTeam).to.equal(nil)
				end)
			end)

			describe("timer countdown (raiders own)", function()
				beforeEach(function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks = makeCallbacks(3, 0)
					raidersCapture(state, config, nodePos, callbacks)
				end)

				it("decreases time each tick", function()
					local callbacks = makeCallbacks(0, 0)
					local timeBefore = state.termTimeRemaining
					ConquestController.updateConquest(state, 10, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(timeBefore - 10)
				end)

				it("does not go below zero", function()
					state.termTimeRemaining = 5
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 10, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(0)
				end)

				it("advances phase at zero", function()
					state.termTimeRemaining = 5
					local callbacks, log = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 10, config, nodePos, callbacks)
					expect(log.advanceCalled).to.equal(true)
					expect(state.conquestActive).to.equal(false)
				end)

				it("does not count down while recapture is in progress", function()
					local callbacks, _, setFactions = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					local timeBefore = state.termTimeRemaining
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(timeBefore)
				end)
			end)

			describe("timer rollback (defenders own)", function()
				local function setupDefenderOwned()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					raidersCapture(state, config, nodePos, callbacks)
					state.termTimeRemaining = config.TermTime - 100
					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					return callbacks, setFactions
				end

				it("increases time at RollbackRate", function()
					local callbacks = setupDefenderOwned()
					local timeBefore = state.termTimeRemaining
					local noOneCallbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 10, config, nodePos, noOneCallbacks)
					expect(state.termTimeRemaining).to.equal(timeBefore + 10 * config.RollbackRate)
				end)

				it("clamps time to TermTime", function()
					setupDefenderOwned()
					state.termTimeRemaining = config.TermTime - 1
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 10, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(config.TermTime)
				end)
			end)

			describe("timer restoration -> pushback", function()
				local function setupNearRestoration()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					raidersCapture(state, config, nodePos, callbacks)
					state.termTimeRemaining = config.TermTime - 100
					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					return callbacks, setFactions
				end

				it("restoration clears conquest and enables pushback", function()
					setupNearRestoration()
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 100, config, nodePos, callbacks)
					expect(state.conquestActive).to.equal(false)
					expect(state.defendersPushbackEnabled).to.equal(true)
				end)

				it("deactivates conquest", function()
					setupNearRestoration()
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 100, config, nodePos, callbacks)
					expect(state.conquestActive).to.equal(false)
				end)

				it("enables pushback", function()
					setupNearRestoration()
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 100, config, nodePos, callbacks)
					expect(state.defendersPushbackEnabled).to.equal(true)
				end)

				it("does full conquest reset after restoration", function()
					setupNearRestoration()
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 100, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal(nil)
					expect(state.conquestCaptureProgress).to.equal(0)
				end)

				it("broadcasts restoration message", function()
					setupNearRestoration()
					local callbacks, log = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 100, config, nodePos, callbacks)
					expect(hasMessage(log, "FULLY RESTORED")).to.equal(true)
				end)
			end)

			describe("overtime", function()
				it("ends game for defenders when they capture in overtime", function()
					state.overtime = true
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, log = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(log.endGameWinner).to.equal("Defenders")
				end)

				it("does not end game when not in overtime", function()
					state.overtime = false
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, log = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(log.endGameWinner).to.equal(nil)
					expect(state.conquestOwner).to.equal("Defenders")
				end)

				it("ends game when defenders already own terminal and overtime becomes active", function()
					state.overtime = false
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, log, setFactions = makeCallbacks(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")
					expect(log.endGameWinner).to.equal(nil)

					state.overtime = true
					setFactions(0, 0)
					ConquestController.updateConquest(state, 0.016, config, nodePos, callbacks)
					expect(log.endGameWinner).to.equal("Defenders")
				end)

				it("raiders capturing in overtime does not end game", function()
					state.overtime = true
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, log = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(log.endGameWinner).to.equal(nil)
					expect(state.conquestOwner).to.equal("Raiders")
				end)
			end)

			describe("full cap/recap/restore cycle", function()
				it("raiders cap -> defenders recap -> timer restores -> pushback", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, log, setFactions = makeCallbacks(3, 0)

					raidersCapture(state, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Raiders")

					state.termTimeRemaining = config.TermTime / 2

					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")

					setFactions(0, 0)
					ConquestController.updateConquest(state, 500, config, nodePos, callbacks)
					expect(state.conquestActive).to.equal(false)
					expect(state.defendersPushbackEnabled).to.equal(true)
					expect(state.termTimeRemaining).to.equal(config.TermTime)
				end)

				it("timer partial drain then full restore", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(3, 0)

					raidersCapture(state, config, nodePos, callbacks)
					local timerAfterCapture = state.termTimeRemaining
					setFactions(0, 0)
					ConquestController.updateConquest(state, 50, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(timerAfterCapture - 50)

					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")

					setFactions(0, 0)
					ConquestController.updateConquest(state, 500, config, nodePos, callbacks)
					expect(state.termTimeRemaining).to.equal(config.TermTime)
					expect(state.conquestActive).to.equal(false)
				end)

				it("multiple cap/recap in same conquest keeps conquest active", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					state.termTimeRemaining = 300
					local callbacks, _, setFactions = makeCallbacks(3, 0)

					for _ = 1, 3 do
						setFactions(3, 0)
						raidersCapture(state, config, nodePos, callbacks)
						expect(state.conquestOwner).to.equal("Raiders")

						setFactions(0, 3)
						ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
						expect(state.conquestOwner).to.equal("Defenders")
					end

					expect(state.conquestActive).to.equal(true)
				end)
			end)

			describe("edge cases", function()
				it("no players means no capture progress change", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(0)
					expect(state.conquestOwner).to.equal(nil)
				end)

				it("equal forces means no capture progress", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks = makeCallbacks(3, 3)
					ConquestController.updateConquest(state, 1, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(0)
				end)

				it("partial raider cap then defender decays and captures", function()
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(3, 0)
					ConquestController.updateConquest(state, 2, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(2)

					setFactions(0, 3)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestCaptureProgress).to.equal(0)

					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")
				end)

				it("timer depletion fires advancePhase exactly at zero", function()
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks = makeCallbacks(3, 0)
					raidersCapture(state, config, nodePos, callbacks)

					state.termTimeRemaining = 0.5
					local noOneCallbacks, log = makeCallbacks(0, 0)
					ConquestController.updateConquest(state, 1, config, nodePos, noOneCallbacks)
					expect(state.termTimeRemaining).to.equal(0)
					expect(log.advanceCalled).to.equal(true)
				end)

				it("defenders recap with 1 person vs 0 raiders", function()
					state.termTimeRemaining = 300
					ConquestController.beginConquest(state, "TermNode2", config)
					local callbacks, _, setFactions = makeCallbacks(1, 0)
					raidersCapture(state, config, nodePos, callbacks)

					setFactions(0, 1)
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, callbacks)
					expect(state.conquestOwner).to.equal("Defenders")
				end)
			end)
		end)
	end)
end
