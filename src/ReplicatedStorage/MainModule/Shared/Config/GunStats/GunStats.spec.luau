--!nocheck
return function()
	local GunStats = require(script.Parent)

	describe("GunStats", function()
		describe("module structure", function()
			it("should have Guns table", function()
				expect(GunStats.Guns).to.be.a("table")
			end)

			it("should have get function", function()
				expect(typeof(GunStats.get)).to.equal("function")
			end)
		end)

		describe("registered guns", function()
			it("should have H-82 registered", function()
				expect(GunStats.Guns["H-82"]).to.be.ok()
			end)

			it("should have BR-16 registered", function()
				expect(GunStats.Guns["BR-16"]).to.be.ok()
			end)

			it("should have Medi+ registered", function()
				expect(GunStats.Guns["Medi+"]).to.be.ok()
			end)
		end)

		describe("get function", function()
			it("should return gun properties for valid gun name", function()
				local h82 = GunStats.get("H-82")
				expect(h82).to.be.ok()
			end)

			it("should return nil for invalid gun name", function()
				local invalid = GunStats.get("NotARealGun")
				expect(invalid).to.equal(nil)
			end)

			it("should return nil for empty string", function()
				local invalid = GunStats.get("")
				expect(invalid).to.equal(nil)
			end)
		end)

		describe("H-82 properties", function()
			local h82 = GunStats.get("H-82")

			it("should have Mode property", function()
				expect(h82.Mode).to.be.a("string")
			end)

			it("should have GunImageId property", function()
				expect(h82.GunImageId).to.be.a("number")
			end)

			it("should have FireRate property", function()
				expect(h82.FireRate).to.be.a("number")
				expect(h82.FireRate).to.be.ok()
			end)

			it("should have MaxAmmo property", function()
				expect(h82.MaxAmmo).to.be.a("number")
				expect(h82.MaxAmmo > 0).to.equal(true)
			end)

			it("should have Range property", function()
				expect(h82.Range).to.be.a("number")
				expect(h82.Range > 0).to.equal(true)
			end)

			it("should have RechargePerSecond property", function()
				expect(h82.RechargePerSecond).to.be.a("number")
			end)

			it("should have BaseDamage property", function()
				expect(h82.BaseDamage).to.be.a("number")
				expect(h82.BaseDamage > 0).to.equal(true)
			end)

			it("should have Animations table", function()
				expect(h82.Animations).to.be.a("table")
			end)
		end)

		describe("BR-16 properties", function()
			local br16 = GunStats.get("BR-16")

			it("should have Mode property", function()
				expect(br16.Mode).to.be.a("string")
			end)

			it("should have valid fire rate", function()
				expect(br16.FireRate).to.be.a("number")
				expect(br16.FireRate > 0).to.equal(true)
			end)

			it("should have valid max ammo", function()
				expect(br16.MaxAmmo).to.be.a("number")
				expect(br16.MaxAmmo > 0).to.equal(true)
			end)
		end)

		describe("Medi+ properties", function()
			local medi = GunStats.get("Medi+")

			it("should have Medi mode", function()
				expect(medi.Mode).to.equal("Medi")
			end)

			it("should have HealAmount property", function()
				expect(medi.HealAmount).to.be.a("number")
				expect(medi.HealAmount > 0).to.equal(true)
			end)

			it("should have zero or no BaseDamage (healing weapon)", function()
				local hasNoDamage = medi.BaseDamage == nil or medi.BaseDamage == 0
				expect(hasNoDamage).to.equal(true)
			end)

			it("should have valid max ammo", function()
				expect(medi.MaxAmmo).to.be.a("number")
				expect(medi.MaxAmmo > 0).to.equal(true)
			end)

			it("should have valid range", function()
				expect(medi.Range).to.be.a("number")
				expect(medi.Range > 0).to.equal(true)
			end)
		end)

		describe("gun properties validation", function()
			for gunName, gun in GunStats.Guns do
				describe(gunName, function()
					it("should have required Mode property", function()
						expect(gun.Mode).to.be.a("string")
						expect(#gun.Mode > 0).to.equal(true)
					end)

					it("should have required GunImageId property", function()
						expect(gun.GunImageId).to.be.a("number")
					end)

					it("should have required FireRate property", function()
						expect(gun.FireRate).to.be.a("number")
						expect(gun.FireRate > 0).to.equal(true)
					end)

					it("should have required MaxAmmo property", function()
						expect(gun.MaxAmmo).to.be.a("number")
						expect(gun.MaxAmmo > 0).to.equal(true)
					end)

					it("should have required Range property", function()
						expect(gun.Range).to.be.a("number")
						expect(gun.Range > 0).to.equal(true)
					end)

					it("should have required RechargePerSecond property", function()
						expect(gun.RechargePerSecond).to.be.a("number")
					end)

					it("should have required Animations table", function()
						expect(gun.Animations).to.be.a("table")
					end)
				end)
			end
		end)
	end)
end
