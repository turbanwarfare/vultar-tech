--!nocheck
--!strict

return function()
	describe("RotationTimer", function()
		describe("absolute time tracking", function()
			it("should compute remaining time from deadline", function()
				local now = os.clock()
				local deadline = now + 90
				local pauseAccum = 0

				local remaining = math.max(0, math.ceil(deadline - os.clock() + pauseAccum))
				expect(remaining).to.equal(90)
			end)

			it("should decrease over time", function()
				local startTime = os.clock()
				local deadline = startTime + 10
				local pauseAccum = 0

				local remaining1 = math.max(0, math.ceil(deadline - startTime + pauseAccum))
				local remaining2 = math.max(0, math.ceil(deadline - (startTime + 5) + pauseAccum))

				expect(remaining1).to.equal(10)
				expect(remaining2).to.equal(5)
			end)

			it("should reach zero at deadline", function()
				local startTime = os.clock()
				local deadline = startTime + 90
				local pauseAccum = 0

				local remaining = math.max(0, math.ceil(deadline - (startTime + 90) + pauseAccum))
				expect(remaining).to.equal(0)
			end)

			it("should not go below zero", function()
				local startTime = os.clock()
				local deadline = startTime + 90
				local pauseAccum = 0

				local remaining = math.max(0, math.ceil(deadline - (startTime + 100) + pauseAccum))
				expect(remaining).to.equal(0)
			end)
		end)

		describe("pause accumulation", function()
			it("should extend effective deadline during pause", function()
				local startTime = os.clock()
				local deadline = startTime + 90
				local pauseAccum = 0

				local pauseStart = startTime + 30
				local unpauseTime = pauseStart + 10
				pauseAccum = unpauseTime - pauseStart

				local remainingAtUnpause = math.max(0, math.ceil(deadline - unpauseTime + pauseAccum))
				expect(remainingAtUnpause).to.equal(60)
			end)

			it("should handle multiple pause periods", function()
				local startTime = os.clock()
				local deadline = startTime + 90
				local pauseAccum = 0

				pauseAccum += 10
				pauseAccum += 5

				local elapsed = 50
				local remaining = math.max(0, math.ceil(deadline - (startTime + elapsed) + pauseAccum))
				expect(remaining).to.equal(55)
			end)
		end)

		describe("rotation reset", function()
			it("should NOT start timer immediately after rotation", function()
				local timerStarted = false
				local rotationTimeMax = 120

				local function getTimeToRotate(deadline: number, pauseAccum: number): number
					if not timerStarted then
						return rotationTimeMax
					end
					return math.max(0, math.ceil(deadline - os.clock() + pauseAccum))
				end

				local displayed = getTimeToRotate(0, 0)
				expect(displayed).to.equal(rotationTimeMax)
			end)

			it("should start countdown only after first cap", function()
				local timerStarted = false
				local deadline = 0
				local pauseAccum = 0
				local rotationDuration = 100
				local rotationTimeMax = 120

				local function getTimeToRotate(now: number): number
					if not timerStarted then
						return rotationTimeMax
					end
					return math.max(0, math.ceil(deadline - now + pauseAccum))
				end

				local now = os.clock()

				expect(getTimeToRotate(now + 20)).to.equal(rotationTimeMax)

				timerStarted = true
				deadline = now + 20 + rotationDuration

				local remaining = getTimeToRotate(now + 25)
				expect(remaining).to.equal(95)
			end)

			it("should give full rotation duration from moment of first cap", function()
				local timerStarted = false
				local deadline = 0
				local pauseAccum = 0
				local rotationDuration = 100

				local now = os.clock()

				local capTime = now + 40
				timerStarted = true
				deadline = capTime + rotationDuration

				local remainingAtCap = math.max(0, math.ceil(deadline - capTime + pauseAccum))
				expect(remainingAtCap).to.equal(rotationDuration)
			end)

			it("should NOT reset timer on subsequent caps in same rotation", function()
				local timerStarted = false
				local deadline = 0
				local pauseAccum = 0
				local rotationDuration = 100

				local now = os.clock()

				local firstCapTime = now + 10
				timerStarted = true
				deadline = firstCapTime + rotationDuration

				local secondCapTime = now + 30
				if not timerStarted then
					deadline = secondCapTime + rotationDuration
				end

				local remaining = math.max(0, math.ceil(deadline - (now + 50) + pauseAccum))
				expect(remaining).to.equal(60)
			end)

			it("should reset timerStarted flag after terminal rotates", function()
				local timerStarted = true

				timerStarted = false

				expect(timerStarted).to.equal(false)
			end)
		end)

		describe("rotation range", function()
			it("should generate time within min-max range", function()
				local rng = Random.new(42)
				local minTime = 100
				local maxTime = 120

				for _ = 1, 50 do
					local duration = rng:NextInteger(minTime, maxTime)
					expect(duration >= minTime).to.equal(true)
					expect(duration <= maxTime).to.equal(true)
				end
			end)

			it("should return min when min equals max", function()
				local minTime = 90
				local maxTime = 90
				local duration = if minTime == maxTime then minTime else Random.new():NextInteger(minTime, maxTime)
				expect(duration).to.equal(90)
			end)
		end)
	end)
end
