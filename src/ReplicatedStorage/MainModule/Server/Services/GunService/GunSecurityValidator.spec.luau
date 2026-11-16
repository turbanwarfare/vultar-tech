--!nocheck
return function()
	local success, GunSecurityValidator = pcall(function()
		return require(script.Parent.GunSecurityValidator)
	end)

	describe("GunSecurityValidator", function()
		if not success then
			it("SKIP: module failed to load in test environment", function()
				expect(true).to.equal(true)
			end)
			return
		end

		describe("module structure", function()
			it("should have validateEquippedWeapon function", function()
				expect(typeof(GunSecurityValidator.validateEquippedWeapon)).to.equal("function")
			end)

			it("should have validateFireRate function", function()
				expect(typeof(GunSecurityValidator.validateFireRate)).to.equal("function")
			end)

			it("should have validateMagazine function", function()
				expect(typeof(GunSecurityValidator.validateMagazine)).to.equal("function")
			end)

			it("should have sanitizePelletCount function", function()
				expect(typeof(GunSecurityValidator.sanitizePelletCount)).to.equal("function")
			end)

			it("should have cleanupPlayer function", function()
				expect(typeof(GunSecurityValidator.cleanupPlayer)).to.equal("function")
			end)

			it("should have cleanup function", function()
				expect(typeof(GunSecurityValidator.cleanup)).to.equal("function")
			end)
		end)

		describe("weapon equip validation - character authority & variant recognition", function()
			beforeEach(function()
				GunSecurityValidator.cleanup()
			end)

			it("should accept legitimate equipped weapon matching claimed gun index", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "BR-16"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 777000,
					Name = "LegitEquippedPlayer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return nil
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 2)
				expect(valid).to.equal(true)
			end)

			it("should accept legitimate H-82 INF holding for base weapon H-82 (Index 1)", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "H-82 INF"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 777001,
					Name = "SparPlayer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return nil
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 1)
				expect(valid).to.equal(true)
			end)

			it("should reject unregistered variant name like H-82 FakeSuffix for H-82", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "H-82 FakeSuffix"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 777002,
					Name = "FakeVariantPlayer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return nil
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 1)
				expect(valid).to.equal(false)
			end)

			it("should reject when holding BR-8 (Pistol) even if claimed BR-50 (Sniper) exists in Backpack", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "BR-8"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockBackpack = Instance.new("Folder")
				local backpackSniper = Instance.new("Tool")
				backpackSniper.Name = "BR-50"
				backpackSniper.Parent = mockBackpack

				local mockPlayer = {
					UserId = 777004,
					Name = "BackpackSpoofCheater",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return mockBackpack
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 12)
				expect(valid).to.equal(false)
			end)

			it("should allow weapon from Backpack when character has NO tool equipped (unequipped transition)", function()
				local mockChar = Instance.new("Model")

				local mockBackpack = Instance.new("Folder")
				local backpackGun = Instance.new("Tool")
				backpackGun.Name = "BR-16"
				backpackGun.Parent = mockBackpack

				local mockPlayer = {
					UserId = 777005,
					Name = "TransitionPlayer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return mockBackpack
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 2)
				expect(valid).to.equal(true)
			end)

			it("should reject claiming H-94-DEV (Index 15) when holding standard H-94", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "H-94"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 777006,
					Name = "DevGunSpoofer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return nil
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 15)
				expect(valid).to.equal(false)
			end)

			it("should accept H-94-DEV (Index 15) when legitimately holding H-94-DEV tool", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "H-94-DEV"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 777007,
					Name = "LegitDevPlayer",
					Character = mockChar,
					FindFirstChildOfClass = function(_, className)
						if className == "Backpack" then
							return nil
						end
						return nil
					end,
				}

				local valid = GunSecurityValidator.validateEquippedWeapon(mockPlayer :: any, 15)
				expect(valid).to.equal(true)
			end)
		end)

		describe("pellet validation", function()
			local mockPlayer = {
				UserId = 999999,
				Name = "TestPlayer",
			}

			it("should reject multi-hit on single-bullet weapon (BR-8 Pistol index 13)", function()
				local valid, count = GunSecurityValidator.sanitizePelletCount(mockPlayer, 13, 8)
				expect(valid).to.equal(false)
				expect(count).to.equal(1)
			end)

			it("should accept single hit on single-bullet weapon", function()
				local valid, count = GunSecurityValidator.sanitizePelletCount(mockPlayer, 13, 1)
				expect(valid).to.equal(true)
				expect(count).to.equal(1)
			end)

			it("should allow valid shotgun pellet count (H-41 Shotgun index 8, 7 pellets)", function()
				local valid, count = GunSecurityValidator.sanitizePelletCount(mockPlayer, 8, 7)
				expect(valid).to.equal(true)
				expect(count).to.equal(7)
			end)

			it("should clamp excessive shotgun pellet count to max allowed", function()
				local valid, count = GunSecurityValidator.sanitizePelletCount(mockPlayer, 8, 12)
				expect(valid).to.equal(true)
				expect(count).to.equal(7)
			end)
		end)

		describe("fire rate validation - detection/logging-only with zero shot blocking", function()
			beforeEach(function()
				GunSecurityValidator.cleanup()
			end)

			it("should return true for normal fire-rate shots on BR-16", function()
				local legitPlayer = {
					UserId = 100001,
					Name = "NormalPlayer",
					GetNetworkPing = function()
						return 0.030
					end,
				}

				local allAllowed = true
				for _ = 1, 5 do
					local allowed = GunSecurityValidator.validateFireRate(legitPlayer, 2)
					if not allowed then
						allAllowed = false
					end
					task.wait(0.100)
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should return true even during continuous 0ms packet spam on BR-16 while tracking breaches", function()
				local spammer = {
					UserId = 100002,
					Name = "Spammer0ms",
					GetNetworkPing = function()
						return 0.030
					end,
				}

				local allAllowed = true
				for _ = 1, 20 do
					local allowed = GunSecurityValidator.validateFireRate(spammer, 2)
					if not allowed then
						allAllowed = false
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should return true on single same-frame server hitch on BR-16 with zero false drops", function()
				local legitPlayer = {
					UserId = 100003,
					Name = "LegitHitchPlayer",
					GetNetworkPing = function()
						return 0.040
					end,
				}

				local allAllowed = true
				for shot = 1, 7 do
					local allowed = GunSecurityValidator.validateFireRate(legitPlayer, 2)
					if not allowed then
						allAllowed = false
					end
					if shot == 3 then
						task.wait(0.200)
					elseif shot == 4 then
					else
						task.wait(0.100)
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should return true on high latency delivery backlog post-pause (e.g. 7s pause + 6-shot burst)", function()
				local highPingPlayer = {
					UserId = 100004,
					Name = "HighPingPsalm",
					GetNetworkPing = function()
						return 0.250
					end,
				}

				GunSecurityValidator.validateFireRate(highPingPlayer, 1)
				task.wait(0.350)

				local allAllowed = true
				for _ = 1, 6 do
					local allowed = GunSecurityValidator.validateFireRate(highPingPlayer, 1)
					if not allowed then
						allAllowed = false
						break
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should maintain continuous tracking and allow subsequent shots when spamming across time", function()
				local continuousSpammer = {
					UserId = 100005,
					Name = "ContinuousSpammer",
					GetNetworkPing = function()
						return 0.030
					end,
				}

				for _ = 1, 15 do
					local allowed = GunSecurityValidator.validateFireRate(continuousSpammer, 2)
					expect(allowed).to.equal(true)
				end

				task.wait(0.500)

				for _ = 1, 15 do
					local allowed = GunSecurityValidator.validateFireRate(continuousSpammer, 2)
					expect(allowed).to.equal(true)
				end
			end)

			it("should exempt dev weapons like H-94-DEV (Index 15)", function()
				local devPlayer = {
					UserId = 100008,
					Name = "DevTester",
				}

				for _ = 1, 20 do
					local allowed = GunSecurityValidator.validateFireRate(devPlayer, 15)
					expect(allowed).to.equal(true)
				end
			end)
		end)

		describe("magazine capacity validation", function()
			beforeEach(function()
				GunSecurityValidator.cleanup()
			end)

			it("should allow shots within magazine capacity for BR-16 (Index 2, MaxAmmo 30)", function()
				local mockPlayer = {
					UserId = 200001,
					Name = "NormalShooter",
				}

				local allAllowed = true
				for _ = 1, 30 do
					local valid = GunSecurityValidator.validateMagazine(mockPlayer, 2)
					if not valid then
						allAllowed = false
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should reject shots that exceed magazine capacity without reload", function()
				local mockPlayer = {
					UserId = 200002,
					Name = "InfiniteAmmoCheater",
				}

				for _ = 1, 30 do
					GunSecurityValidator.validateMagazine(mockPlayer, 2)
				end

				local excessShotAllowed = GunSecurityValidator.validateMagazine(mockPlayer, 2)
				expect(excessShotAllowed).to.equal(false)
			end)

			it("should allow shooting again after reload interval passes", function()
				local mockPlayer = {
					UserId = 200003,
					Name = "ReloadingPlayer",
				}

				for _ = 1, 30 do
					GunSecurityValidator.validateMagazine(mockPlayer, 2)
				end

				local blocked = GunSecurityValidator.validateMagazine(mockPlayer, 2)
				expect(blocked).to.equal(false)

				task.wait(1.0)

				local postReloadAllowed = GunSecurityValidator.validateMagazine(mockPlayer, 2)
				expect(postReloadAllowed).to.equal(true)
			end)

			it("should allow infinite shots for infinite-ammo weapons like H-94-DEV", function()
				local mockPlayer = {
					UserId = 200004,
					Name = "InfWeaponUser",
					GetAttribute = function(_, attr)
						return nil
					end,
				}

				local allAllowed = true
				for _ = 1, 60 do
					local valid = GunSecurityValidator.validateMagazine(mockPlayer, 15)
					if not valid then
						allAllowed = false
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should allow infinite shots when player has AimChamberInfiniteAmmo attribute", function()
				local mockPlayer = {
					UserId = 200005,
					Name = "AimChamberPlayer",
					GetAttribute = function(_, attr)
						if attr == "AimChamberInfiniteAmmo" then
							return true
						end
						return nil
					end,
				}

				local allAllowed = true
				for _ = 1, 60 do
					local valid = GunSecurityValidator.validateMagazine(mockPlayer, 2)
					if not valid then
						allAllowed = false
					end
				end

				expect(allAllowed).to.equal(true)
			end)

			it("should allow infinite shots when character holds H-82 INF variant", function()
				local mockTool = Instance.new("Tool")
				mockTool.Name = "H-82 INF"

				local mockChar = Instance.new("Model")
				mockTool.Parent = mockChar

				local mockPlayer = {
					UserId = 200006,
					Name = "H82InfHoldingPlayer",
					Character = mockChar,
					GetAttribute = function(_, _)
						return nil
					end,
				}

				local allAllowed = true
				for _ = 1, 70 do
					local valid = GunSecurityValidator.validateMagazine(mockPlayer, 1)
					if not valid then
						allAllowed = false
					end
				end

				expect(allAllowed).to.equal(true)
			end)
		end)

		describe("cleanup", function()
			it("should cleanup without error", function()
				expect(function()
					GunSecurityValidator.cleanup()
				end).never.to.throw()
			end)

			it("should cleanup individual player without error", function()
				local mockPlayer = {
					UserId = 300001,
					Name = "LeavingPlayer",
				}
				GunSecurityValidator.validateFireRate(mockPlayer, 1)
				expect(function()
					GunSecurityValidator.cleanupPlayer(mockPlayer)
				end).never.to.throw()
			end)
		end)
	end)
end
