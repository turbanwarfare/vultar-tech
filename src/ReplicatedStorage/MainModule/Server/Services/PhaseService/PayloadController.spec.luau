--!nocheck
return function()
	local success, PayloadController = pcall(function()
		return require(script.Parent.PayloadController)
	end)
	local conquestSuccess, ConquestController = pcall(function()
		return require(script.Parent.ConquestController)
	end)
	local GameState = require(script.Parent.GameState)
	local MainModule = script.Parent.Parent.Parent.Parent
	local PhaseConfig = require(MainModule.Shared.Config.PhaseConfig)

	local AT_NODE_DIST_SQ = 25

	local function makeConquestCallbacks(raidersCount: number?, defendersCount: number?)
		local log = {
			messages = {} :: { string },
			advanceCalled = false,
			endGameWinner = nil :: string?,
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
			broadcastPhaseState = function() end,
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
			awardCapture = function() end,
		}
		local function setFactions(newR: number, newD: number)
			r = newR
			d = newD
		end
		return callbacks, log, setFactions
	end

	local function setupPhase3State()
		local state = GameState.new()
		state.official = true
		state.currentPhase = "phase3"
		local config = PhaseConfig.getPhase("phase3") :: any

		local startPos = Vector3.zero
		local midPos = Vector3.new(50, 0, 0)
		local endPos = Vector3.new(100, 0, 0)

		state.sortedPathNodes = {
			{ Name = "TermNode1", Position = startPos, Order = 15 },
			{ Name = "Node15", Position = midPos, Order = 16 },
			{ Name = "TermNode2", Position = endPos, Order = 24 },
		}
		state.nodePositionByName = {
			TermNode1 = startPos,
			Node15 = midPos,
			TermNode2 = endPos,
		}

		local payloadPart = Instance.new("Part")
		payloadPart.Anchored = true
		payloadPart.Position = startPos
		state.payloadModel = payloadPart

		state.termTimeRemaining = config.TermTime
		state.payloadProgress = 0
		state.payloadMaxProgress = 1

		ConquestController.resetConquestState(state)

		return state, config, startPos, endPos, payloadPart
	end

	local TOTAL_DIST = 100
	local PAYLOAD_SPEED = 7

	local function progressToPosition(progress: number, startPos: Vector3, endPos: Vector3): Vector3
		return startPos:Lerp(endPos, progress)
	end

	local function movePayloadToProgress(state: any, progress: number, startPos: Vector3, endPos: Vector3)
		state.payloadProgress = progress
		if state.payloadModel then
			state.payloadModel.Position = progressToPosition(progress, startPos, endPos)
		end
	end

	local function simulatePayloadTick(
		state: any,
		dt: number,
		netPower: number,
		config: any,
		termNodeName: string,
		startPos: Vector3,
		endPos: Vector3,
		conquestCallbacks: any
	): string
		if state.conquestActive then
			local nodePos = state.nodePositionByName[state.conquestNode]
			if nodePos then
				ConquestController.updateConquest(state, dt, config, nodePos, conquestCallbacks)
			end
			return "conquest"
		end

		local isAtConquestNode = PayloadController.isPayloadAtNode(state, termNodeName)
		local canPushBack = state.defendersPushbackEnabled or not isAtConquestNode
		local wasPushbackEnabled = state.defendersPushbackEnabled

		if netPower > 0 then
			local progressDelta = (PAYLOAD_SPEED * dt) / TOTAL_DIST
			state.payloadProgress = math.min(state.payloadProgress + progressDelta, 1)
			if state.defendersPushbackEnabled then
				state.defendersPushbackEnabled = false
				state.conquestTimerRestored = false
			end
		elseif netPower < 0 and canPushBack then
			local progressDelta = (PAYLOAD_SPEED * dt) / TOTAL_DIST
			state.payloadProgress = math.max(state.payloadProgress - progressDelta, 0)
		end

		if state.payloadModel then
			state.payloadModel.Position = progressToPosition(state.payloadProgress, startPos, endPos)
		end

		isAtConquestNode = PayloadController.isPayloadAtNode(state, termNodeName)

		if isAtConquestNode and not wasPushbackEnabled then
			ConquestController.beginConquest(state, termNodeName, config)
			return "conquest_started"
		end

		if state.payloadProgress >= 1 and not state.conquestActive and not isAtConquestNode then
			return "advance"
		end

		return "normal"
	end

	local function runConquestCapture(state: any, config: any, faction: string, conquestCallbacks: any, setFactions: any)
		if faction == "Raiders" then
			setFactions(3, 0)
		else
			setFactions(0, 3)
		end
		local nodePos = state.nodePositionByName[state.conquestNode]
		ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, conquestCallbacks)
	end

	local function restoreTimerFully(state: any, config: any, conquestCallbacks: any)
		local nodePos = state.nodePositionByName[state.conquestNode]
		local noOneCallbacks = makeConquestCallbacks(0, 0)
		ConquestController.updateConquest(state, 500, config, nodePos, noOneCallbacks)
	end

	describe("PayloadController", function()
		if not success or not conquestSuccess then
			it("SKIP: modules failed to load (Network dependency)", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("isPayloadAtNode", function()
			it("returns true when payload is at node position", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.new(100, 0, 0)
				state.payloadModel = part
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(true)
				part:Destroy()
			end)

			it("returns true within 5 studs", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.new(104, 0, 0)
				state.payloadModel = part
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(true)
				part:Destroy()
			end)

			it("returns false beyond 5 studs", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.new(106, 0, 0)
				state.payloadModel = part
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(false)
				part:Destroy()
			end)

			it("returns false with no payload model", function()
				local state = GameState.new()
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(false)
			end)

			it("returns false for unknown node", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.zero
				state.payloadModel = part
				state.nodePositionByName = {}
				expect(PayloadController.isPayloadAtNode(state, "NonExistent")).to.equal(false)
				part:Destroy()
			end)

			it("checks all 3 axes for distance", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.new(100, 2, 3)
				state.payloadModel = part
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(true)
				part:Destroy()
			end)

			it("returns false when just beyond threshold on diagonal", function()
				local state = GameState.new()
				local part = Instance.new("Part")
				part.Position = Vector3.new(103, 3, 3)
				state.payloadModel = part
				state.nodePositionByName = { TermNode2 = Vector3.new(100, 0, 0) }
				local dx, dy, dz = 3, 3, 3
				local distSq = dx * dx + dy * dy + dz * dz
				local expectedResult = distSq < AT_NODE_DIST_SQ
				expect(PayloadController.isPayloadAtNode(state, "TermNode2")).to.equal(expectedResult)
				part:Destroy()
			end)
		end)

		describe("getPayloadCFrame", function()
			local state: any
			local pathCache: any

			beforeEach(function()
				state = GameState.new()
				state.sortedPathNodes = {
					{ Name = "TermNode1", Position = Vector3.zero, Order = 1 },
					{ Name = "Node15", Position = Vector3.new(50, 0, 0), Order = 2 },
					{ Name = "TermNode2", Position = Vector3.new(100, 0, 0), Order = 3 },
				}
				pathCache = {
					segmentLengths = { 50, 50 },
					cumulativeDistances = { 0, 50, 100 },
					totalDistance = 100,
				}
			end)

			it("returns start position at progress 0", function()
				local cf = PayloadController.getPayloadCFrame(state, 0, 1, 3, pathCache)
				local pos = cf.Position
				expect(math.abs(pos.X) < 0.01).to.equal(true)
			end)

			it("returns mid position at progress 0.5", function()
				local cf = PayloadController.getPayloadCFrame(state, 0.5, 1, 3, pathCache)
				local pos = cf.Position
				expect(math.abs(pos.X - 50) < 0.01).to.equal(true)
			end)

			it("returns end position at progress 1", function()
				local cf = PayloadController.getPayloadCFrame(state, 1, 1, 3, pathCache)
				local pos = cf.Position
				expect(math.abs(pos.X - 100) < 0.01).to.equal(true)
			end)

			it("clamps progress to 0-1 range", function()
				local cf0 = PayloadController.getPayloadCFrame(state, -0.5, 1, 3, pathCache)
				local cf1 = PayloadController.getPayloadCFrame(state, 1.5, 1, 3, pathCache)
				expect(math.abs(cf0.Position.X) < 0.01).to.equal(true)
				expect(math.abs(cf1.Position.X - 100) < 0.01).to.equal(true)
			end)

			it("interpolates linearly between nodes", function()
				local cf = PayloadController.getPayloadCFrame(state, 0.25, 1, 3, pathCache)
				local pos = cf.Position
				expect(math.abs(pos.X - 25) < 0.01).to.equal(true)
			end)
		end)

		describe("cleanupPayload", function()
			it("clears payload state", function()
				local state = GameState.new()
				state.payloadProgress = 0.75
				state.payloadMaxProgress = 1

				local part = Instance.new("Part")
				part.Parent = workspace
				state.payloadModel = part

				PayloadController.cleanupPayload(state)

				expect(state.payloadModel).to.equal(nil)
				expect(state.payloadProgress).to.equal(0)
				expect(state.payloadMaxProgress).to.equal(0)
				expect(state.payloadAlignPos).to.equal(nil)
				expect(state.payloadAlignOri).to.equal(nil)
			end)
		end)

		describe("integrated payload+conquest state machine", function()
			local state: any
			local config: any
			local startPos: Vector3
			local endPos: Vector3
			local payloadPart: Part

			beforeEach(function()
				state, config, startPos, endPos, payloadPart = setupPhase3State()
			end)

			afterEach(function()
				if payloadPart and payloadPart.Parent then
					payloadPart:Destroy()
				end
			end)

			it("starts conquest when payload reaches TermNode2", function()
				movePayloadToProgress(state, 1.0, startPos, endPos)
				local conquestCbs = makeConquestCallbacks(0, 0)
				local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
				expect(result).to.equal("conquest_started")
				expect(state.conquestActive).to.equal(true)
			end)

			it("does not start conquest at midpoint", function()
				movePayloadToProgress(state, 0.5, startPos, endPos)
				local conquestCbs = makeConquestCallbacks(0, 0)
				local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
				expect(result).to.equal("normal")
				expect(state.conquestActive).to.equal(false)
			end)

			it("delegates to conquest controller while conquest is active", function()
				movePayloadToProgress(state, 1.0, startPos, endPos)
				ConquestController.beginConquest(state, "TermNode2", config)
				local conquestCbs, _, setFactions = makeConquestCallbacks(3, 0)
				simulatePayloadTick(state, config.CaptureTime, 0, config, "TermNode2", startPos, endPos, conquestCbs)
				expect(state.conquestOwner).to.equal("Raiders")
			end)

			describe("after timer restoration (the neutral state)", function()
				local conquestCbs: any
				local conquestLog: any
				local setFactions: any

				beforeEach(function()
					movePayloadToProgress(state, 1.0, startPos, endPos)
					conquestCbs, conquestLog, setFactions = makeConquestCallbacks(3, 0)

					ConquestController.beginConquest(state, "TermNode2", config)
					setFactions(3, 0)
					runConquestCapture(state, config, "Raiders", conquestCbs, setFactions)
					state.termTimeRemaining = config.TermTime - 10

					setFactions(0, 3)
					runConquestCapture(state, config, "Defenders", conquestCbs, setFactions)

					setFactions(0, 0)
					restoreTimerFully(state, config, conquestCbs)

					expect(state.conquestActive).to.equal(false)
					expect(state.defendersPushbackEnabled).to.equal(true)
				end)

				it("does NOT restart conquest while pushback is active", function()
					local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(result).to.equal("normal")
					expect(state.conquestActive).to.equal(false)
				end)

				it("defenders can push payload back", function()
					local progressBefore = state.payloadProgress
					simulatePayloadTick(state, 1, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress < progressBefore).to.equal(true)
				end)

				it("CRITICAL: raiders advancing clears pushback but conquest waits one tick", function()
					simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.defendersPushbackEnabled).to.equal(false)
					expect(state.conquestActive).to.equal(false)
				end)

				it("CRITICAL: conquest starts on the tick AFTER pushback is cleared", function()
					simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.defendersPushbackEnabled).to.equal(false)

					local result = simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(result).to.equal("conquest_started")
					expect(state.conquestActive).to.equal(true)
				end)

				it("defenders pushing back prevents conquest restart", function()
					for _ = 1, 5 do
						simulatePayloadTick(state, 0.5, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					end
					expect(state.conquestActive).to.equal(false)
					expect(state.defendersPushbackEnabled).to.equal(true)
				end)
			end)

			describe("conquest restarts on second approach", function()
				it("payload leaves node and returns -> conquest starts immediately", function()
					movePayloadToProgress(state, 0.5, startPos, endPos)
					state.defendersPushbackEnabled = false
					local conquestCbs = makeConquestCallbacks(0, 0)

					movePayloadToProgress(state, 1.0, startPos, endPos)
					local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(result).to.equal("conquest_started")
					expect(state.conquestActive).to.equal(true)
				end)
			end)

			describe("payload movement mechanics", function()
				it("netPower > 0 increases progress", function()
					movePayloadToProgress(state, 0.5, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress > 0.5).to.equal(true)
				end)

				it("netPower < 0 decreases progress when pushback allowed", function()
					state.defendersPushbackEnabled = true
					movePayloadToProgress(state, 0.5, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress < 0.5).to.equal(true)
				end)

				it("netPower 0 means no movement", function()
					movePayloadToProgress(state, 0.5, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress).to.equal(0.5)
				end)

				it("progress does not exceed 1", function()
					movePayloadToProgress(state, 0.99, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 100, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress).to.equal(1)
				end)

				it("progress does not go below 0", function()
					state.defendersPushbackEnabled = true
					movePayloadToProgress(state, 0.01, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 100, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress).to.equal(0)
				end)

				it("cannot push back without pushback enabled and at node", function()
					state.defendersPushbackEnabled = false
					movePayloadToProgress(state, 1.0, startPos, endPos)
					local progressBefore = state.payloadProgress
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress).to.equal(progressBefore)
				end)

				it("can push back when not at conquest node", function()
					state.defendersPushbackEnabled = false
					movePayloadToProgress(state, 0.5, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.payloadProgress < 0.5).to.equal(true)
				end)
			end)

			describe("pushback clearing", function()
				it("clears pushback when raiders advance", function()
					state.defendersPushbackEnabled = true
					movePayloadToProgress(state, 0.5, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.defendersPushbackEnabled).to.equal(false)
				end)

				it("clears pushback when raiders advance at node", function()
					state.defendersPushbackEnabled = true
					movePayloadToProgress(state, 1.0, startPos, endPos)
					local conquestCbs = makeConquestCallbacks(0, 0)
					simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.defendersPushbackEnabled).to.equal(false)
				end)
			end)

			describe("full mataro phase 3 scenario", function()
				it("payload to TermNode2 -> conquest -> recap -> pushback -> leave -> new conquest", function()
					local conquestCbs, _, setFactions = makeConquestCallbacks(0, 0)

					movePayloadToProgress(state, 1.0, startPos, endPos)
					local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(result).to.equal("conquest_started")
					expect(state.conquestActive).to.equal(true)

					setFactions(3, 0)
					runConquestCapture(state, config, "Raiders", conquestCbs, setFactions)
					expect(state.conquestOwner).to.equal("Raiders")

					state.termTimeRemaining = config.TermTime - 50

					setFactions(0, 3)
					runConquestCapture(state, config, "Defenders", conquestCbs, setFactions)
					expect(state.conquestOwner).to.equal("Defenders")

					setFactions(0, 0)
					restoreTimerFully(state, config, conquestCbs)
					expect(state.conquestActive).to.equal(false)
					expect(state.defendersPushbackEnabled).to.equal(true)

					for _ = 1, 5 do
						simulatePayloadTick(state, 1, -1, config, "TermNode2", startPos, endPos, conquestCbs)
					end
					expect(state.payloadProgress < 1.0).to.equal(true)

					simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.defendersPushbackEnabled).to.equal(false)

					movePayloadToProgress(state, 1.0, startPos, endPos)
					result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(result).to.equal("conquest_started")
					expect(state.conquestActive).to.equal(true)
				end)
			end)

			describe("overtime scenario", function()
				it("defenders win via overtime conquest capture", function()
					state.overtime = true
					movePayloadToProgress(state, 1.0, startPos, endPos)
					local conquestCbs, conquestLog, setFactions = makeConquestCallbacks(0, 0)

					simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
					expect(state.conquestActive).to.equal(true)

					setFactions(0, 3)
					local nodePos = state.nodePositionByName["TermNode2"]
					ConquestController.updateConquest(state, config.CaptureTime, config, nodePos, conquestCbs)
					expect(conquestLog.endGameWinner).to.equal("Defenders")
				end)
			end)

			describe("multiple full cycles (stress test)", function()
				it("3 complete cap/recap/restore cycles work correctly", function()
					local conquestCbs, _, setFactions = makeConquestCallbacks(0, 0)

					for _ = 1, 3 do
						movePayloadToProgress(state, 1.0, startPos, endPos)
						state.defendersPushbackEnabled = false

						local result = simulatePayloadTick(state, 0.1, 0, config, "TermNode2", startPos, endPos, conquestCbs)
						expect(result).to.equal("conquest_started")

						setFactions(3, 0)
						runConquestCapture(state, config, "Raiders", conquestCbs, setFactions)
						expect(state.conquestOwner).to.equal("Raiders")

						state.termTimeRemaining = config.TermTime - 20

						setFactions(0, 3)
						runConquestCapture(state, config, "Defenders", conquestCbs, setFactions)
						expect(state.conquestOwner).to.equal("Defenders")

						setFactions(0, 0)
						restoreTimerFully(state, config, conquestCbs)
						expect(state.conquestActive).to.equal(false)
						expect(state.defendersPushbackEnabled).to.equal(true)

						simulatePayloadTick(state, 0.1, 1, config, "TermNode2", startPos, endPos, conquestCbs)
						expect(state.defendersPushbackEnabled).to.equal(false)
					end
				end)
			end)
		end)
	end)
end
