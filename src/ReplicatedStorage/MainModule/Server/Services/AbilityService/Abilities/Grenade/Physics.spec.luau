--!nocheck
return function()
	local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent
	local Physics = require(script.Parent.Physics)
	local Stats = require(MainModule.Shared.Config.AbilityConfig).Abilities.Grenade.Stats

	local function noHits()
		return nil, nil
	end

	local function floorAtZero(origin: Vector3, direction: Vector3)
		local target = origin + direction
		if target.Y <= 0 and origin.Y > 0 then
			local t = origin.Y / (origin.Y - target.Y)
			return origin + direction * t, Vector3.yAxis
		end
		return nil, nil
	end

	describe("Physics.simulate", function()
		it("produces one frame per tick for the whole fuse", function()
			local frames = Physics.simulate(Vector3.new(0, 10, 0), Vector3.new(10, 0, 0), noHits)
			expect(#frames).to.equal(2 + Stats.FUSE_TIME // Stats.FRAME_TIME)
		end)

		it("falls under gravity in open air", function()
			local frames = Physics.simulate(Vector3.new(0, 100, 0), Vector3.zero, noHits)
			expect(frames[#frames].Y < 100).to.equal(true)
		end)

		it("bounces and rolls a few studs past where it lands, then settles", function()
			local origin = Vector3.new(0, 5, 0)
			local target = Vector3.new(20, 0, 0)
			local frames = Physics.simulate(origin, Physics.launchVelocity(origin, target), floorAtZero)
			local final = frames[#frames]
			expect(final.X > target.X + 1).to.equal(true)
			expect(final.X < target.X + 15).to.equal(true)
			expect(final).to.equal(frames[#frames - 1])
		end)

		it("sticks where it first hits a wall in sticky mode", function()
			local function wallAtTen(origin: Vector3, direction: Vector3)
				local target = origin + direction
				if target.X >= 10 and origin.X < 10 then
					local t = (10 - origin.X) / (target.X - origin.X)
					return origin + direction * t, -Vector3.xAxis
				end
				return nil, nil
			end
			local frames = Physics.simulate(Vector3.new(0, 20, 0), Vector3.new(30, 0, 0), wallAtTen, true)
			local final = frames[#frames]
			expect(math.abs(final.X - 10) < 0.1).to.equal(true)
			expect(final.Y > 10).to.equal(true)
			expect(final).to.equal(frames[#frames - 1])
		end)

		it("never ends up below a floor it hits", function()
			local frames = Physics.simulate(Vector3.new(0, 5, 0), Vector3.new(20, 0, 0), floorAtZero)
			for _, position in frames do
				expect(position.Y >= -0.01).to.equal(true)
			end
		end)
	end)

	describe("Physics.launchVelocity", function()
		local function closestDistance(frames, target)
			local best = math.huge
			for _, position in frames do
				best = math.min(best, (position - target).Magnitude)
			end
			return best
		end

		it("lands on the target in open air", function()
			local origin = Vector3.new(0, 5, 0)
			for _, target in { Vector3.new(30, 0, 10), Vector3.new(-40, 2, 30), Vector3.new(4, 0, 0) } do
				local frames = Physics.simulate(origin, Physics.launchVelocity(origin, target), noHits)
				expect(closestDistance(frames, target) < 1).to.equal(true)
			end
		end)

		it("never throws further than the max range", function()
			local origin = Vector3.zero
			local target = Vector3.new(5000, 0, 0)
			local frames = Physics.simulate(origin, Physics.launchVelocity(origin, target), noHits)
			local limit = Vector3.new(Stats.MAX_RANGE, 0, 0)
			expect(closestDistance(frames, limit) < 1).to.equal(true)
		end)
	end)

	describe("Physics.damageAt", function()
		it("kills inside the kill radius and falls off to zero", function()
			expect(Physics.damageAt(0)).to.equal(Stats.MAX_DAMAGE)
			expect(Physics.damageAt(Stats.KILL_RADIUS)).to.equal(Stats.MAX_DAMAGE)
			expect(Physics.damageAt(Stats.DAMAGE_RADIUS)).to.equal(0)
			local mid = Physics.damageAt((Stats.KILL_RADIUS + Stats.DAMAGE_RADIUS) / 2)
			expect(mid > 0 and mid < Stats.MAX_DAMAGE).to.equal(true)
		end)
	end)

	describe("Physics.isBlocked", function()
		local THIN = Stats.MAX_WALL_THICKNESS * 0.8
		local THICK = Stats.MAX_WALL_THICKNESS * 2

		local function isBlocked(walls)
			local parts = {}
			for _, wall in walls do
				local part = Instance.new("Part")
				part.Anchored = true
				part.Size = Vector3.new(wall[2], 20, 20)
				part.Position = Vector3.new(wall[1], 1000, 0)
				part.Parent = workspace
				table.insert(parts, part)
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = parts
			local blocked = Physics.isBlocked(Vector3.new(0, 1000, 0), Vector3.new(10, 1000, 0), params)
			for _, part in parts do
				part:Destroy()
			end
			return blocked
		end

		it("lets the blast through open air and thin walls", function()
			expect(isBlocked({})).to.equal(false)
			expect(isBlocked({ { 5, THIN } })).to.equal(false)
			expect(isBlocked({ { 3, THIN }, { 7, THIN } })).to.equal(false)
		end)

		it("stops the blast at a wall thicker than the limit", function()
			expect(isBlocked({ { 5, THICK } })).to.equal(true)
			expect(isBlocked({ { 3, THIN }, { 7, THICK } })).to.equal(true)
		end)
	end)
end
