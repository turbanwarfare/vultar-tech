--!nocheck
return function()
	local Profile = require(script.Parent.Profile)

	local function noop() end

	local function addOne(value: number, tag: string): (number, string)
		return value + 1, tag
	end

	local function explode()
		error("boom", 0)
	end

	describe("Profile.run", function()
		it("returns every value from the wrapped function", function()
			local value, tag = Profile.run("Vultar::Spec::returns", addOne, 1, "tag")
			expect(value).to.equal(2)
			expect(tag).to.equal("tag")
		end)

		it("closes the scope and rethrows when the function errors", function()
			local ok, err = pcall(Profile.run, "Vultar::Spec::throws", explode)
			expect(ok).to.equal(false)
			expect(err).to.equal("boom")
			expect(Profile.run("Vultar::Spec::after", addOne, 5, "x")).to.equal(6)
		end)
	end)

	describe("Profile.wrap", function()
		it("keeps arguments and results", function()
			local wrapped = Profile.wrap("Vultar::Spec::wrapped", addOne)
			local value, tag = wrapped(10, "w")
			expect(value).to.equal(11)
			expect(tag).to.equal("w")
		end)
	end)

	describe("Profile.slowest", function()
		local function spin(seconds: number)
			local started = os.clock()
			while os.clock() - started < seconds do
			end
		end

		it("ranks scopes by duration, longest first", function()
			Profile.run("Vultar::Spec::quick", noop)
			Profile.run("Vultar::Spec::slow", spin, 0.01)
			local slowest = Profile.slowest(os.clock(), 1, 2)
			expect(#slowest).to.equal(2)
			expect(slowest[1].name).to.equal("Vultar::Spec::slow")
			expect(slowest[1].ms >= 10).to.equal(true)
			expect(slowest[2].name).to.equal("Vultar::Spec::quick")
		end)

		it("keeps the longest run of a repeated scope", function()
			Profile.run("Vultar::Spec::repeat", spin, 0.01)
			Profile.run("Vultar::Spec::repeat", noop)
			local slowest = Profile.slowest(os.clock(), 1, 1)
			expect(slowest[1].name).to.equal("Vultar::Spec::repeat")
			expect(slowest[1].ms >= 10).to.equal(true)
		end)

		it("honours the limit and the window", function()
			Profile.run("Vultar::Spec::a", noop)
			Profile.run("Vultar::Spec::b", noop)
			expect(#Profile.slowest(os.clock(), 1, 1)).to.equal(1)
			expect(#Profile.slowest(os.clock() + 5, 1, 8)).to.equal(0)
		end)

		it("skips a scope that is still open", function()
			Profile.begin("Vultar::Spec::open")
			local names = {}
			for _, entry in Profile.slowest(os.clock(), 1, 32) do
				names[entry.name] = true
			end
			Profile.stop()
			expect(names["Vultar::Spec::open"]).to.equal(nil)
		end)
	end)

	describe("Profile.recent", function()
		it("lists scopes newest first without duplicates", function()
			Profile.run("Vultar::Spec::first", noop)
			Profile.run("Vultar::Spec::second", noop)
			Profile.run("Vultar::Spec::first", noop)
			local names = Profile.recent(os.clock(), 1, 2)
			expect(#names).to.equal(2)
			expect(names[1]).to.equal("Vultar::Spec::first")
			expect(names[2]).to.equal("Vultar::Spec::second")
		end)

		it("records manual begin and stop pairs", function()
			Profile.begin("Vultar::Spec::manual")
			Profile.stop()
			expect(Profile.recent(os.clock(), 1, 1)[1]).to.equal("Vultar::Spec::manual")
		end)

		it("drops scopes older than the window", function()
			Profile.run("Vultar::Spec::old", noop)
			expect(#Profile.recent(os.clock() + 5, 1, 8)).to.equal(0)
		end)

		it("stays bounded when far more scopes run than it keeps", function()
			for _ = 1, 100 do
				Profile.run("Vultar::Spec::spam", noop)
			end
			local names = Profile.recent(os.clock(), 1, 64)
			expect(#names).to.equal(1)
			expect(names[1]).to.equal("Vultar::Spec::spam")
		end)
	end)
end
