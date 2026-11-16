--!nocheck
return function()
	local Constants = require(script.Parent.Constants)

	describe("Constants", function()
		describe("module structure", function()
			it("should have Enums table", function()
				expect(Constants.Enums).to.be.a("table")
			end)

			it("should have Colors table", function()
				expect(Constants.Colors).to.be.a("table")
			end)

			it("should have Ray table", function()
				expect(Constants.Ray).to.be.a("table")
			end)

			it("should have Pool table", function()
				expect(Constants.Pool).to.be.a("table")
			end)

			it("should have Sounds table", function()
				expect(Constants.Sounds).to.be.a("table")
			end)

			it("should have KillIndicator table", function()
				expect(Constants.KillIndicator).to.be.a("table")
			end)

			it("should have KillIndicatorColors table", function()
				expect(Constants.KillIndicatorColors).to.be.a("table")
			end)

			it("should have Hitmarker table", function()
				expect(Constants.Hitmarker).to.be.a("table")
			end)

			it("should have Indicator table", function()
				expect(Constants.Indicator).to.be.a("table")
			end)

			it("should have Raycast table", function()
				expect(Constants.Raycast).to.be.a("table")
			end)

			it("should have Highlight table", function()
				expect(Constants.Highlight).to.be.a("table")
			end)

			it("should have BloodSplatter table", function()
				expect(Constants.BloodSplatter).to.be.a("table")
			end)

			it("should have Defaults table", function()
				expect(Constants.Defaults).to.be.a("table")
			end)

			it("should have HitmarkerSpeedMultipliers table", function()
				expect(Constants.HitmarkerSpeedMultipliers).to.be.a("table")
			end)
		end)

		describe("Colors", function()
			it("should have Ray color as Color3", function()
				expect(typeof(Constants.Colors.Ray)).to.equal("Color3")
			end)

			it("should have RayInner color as Color3", function()
				expect(typeof(Constants.Colors.RayInner)).to.equal("Color3")
			end)

			it("should have Stroke color as Color3", function()
				expect(typeof(Constants.Colors.Stroke)).to.equal("Color3")
			end)

			it("should have DamageNormal color as Color3", function()
				expect(typeof(Constants.Colors.DamageNormal)).to.equal("Color3")
			end)

			it("should have DamageHead color as Color3", function()
				expect(typeof(Constants.Colors.DamageHead)).to.equal("Color3")
			end)

			it("should have Heal color as Color3", function()
				expect(typeof(Constants.Colors.Heal)).to.equal("Color3")
			end)
		end)

		describe("Ray constants", function()
			it("should have positive Transparency", function()
				expect(Constants.Ray.Transparency).to.be.a("number")
				expect(Constants.Ray.Transparency >= 0).to.equal(true)
			end)

			it("should have positive DefaultSpeed", function()
				expect(Constants.Ray.DefaultSpeed).to.be.a("number")
				expect(Constants.Ray.DefaultSpeed > 0).to.equal(true)
			end)

			it("should have valid BeamTexture", function()
				expect(Constants.Ray.BeamTexture).to.be.a("string")
				expect(#Constants.Ray.BeamTexture > 0).to.equal(true)
			end)

			it("should have positive FadeDuration", function()
				expect(Constants.Ray.FadeDuration).to.be.a("number")
				expect(Constants.Ray.FadeDuration > 0).to.equal(true)
			end)
		end)

		describe("Pool constants", function()
			it("should have positive MaxSize", function()
				expect(Constants.Pool.MaxSize).to.be.a("number")
				expect(Constants.Pool.MaxSize > 0).to.equal(true)
			end)

			it("should have positive InitialParts", function()
				expect(Constants.Pool.InitialParts).to.be.a("number")
				expect(Constants.Pool.InitialParts > 0).to.equal(true)
			end)

			it("should have InitialParts <= MaxSize", function()
				expect(Constants.Pool.InitialParts <= Constants.Pool.MaxSize).to.equal(true)
			end)

			it("should have positive SoundPoolSize", function()
				expect(Constants.Pool.SoundPoolSize).to.be.a("number")
				expect(Constants.Pool.SoundPoolSize > 0).to.equal(true)
			end)
		end)

		describe("Sounds", function()
			it("should have Hit sound ID", function()
				expect(Constants.Sounds.Hit).to.be.a("string")
				expect(Constants.Sounds.Hit:match("^rbxassetid://")).to.be.ok()
			end)

			it("should have Headshot sound ID", function()
				expect(Constants.Sounds.Headshot).to.be.a("string")
				expect(Constants.Sounds.Headshot:match("^rbxassetid://")).to.be.ok()
			end)

			it("should have Kill sound ID", function()
				expect(Constants.Sounds.Kill).to.be.a("string")
				expect(Constants.Sounds.Kill:match("^rbxassetid://")).to.be.ok()
			end)
		end)

		describe("KillIndicator constants", function()
			it("should have valid CircleImage", function()
				expect(Constants.KillIndicator.CircleImage).to.be.a("string")
			end)

			it("should have valid SkullImage", function()
				expect(Constants.KillIndicator.SkullImage).to.be.a("string")
			end)

			it("should have positive ExpandDuration", function()
				expect(Constants.KillIndicator.ExpandDuration).to.be.a("number")
				expect(Constants.KillIndicator.ExpandDuration > 0).to.equal(true)
			end)

			it("should have positive DefaultSize", function()
				expect(Constants.KillIndicator.DefaultSize).to.be.a("number")
				expect(Constants.KillIndicator.DefaultSize > 0).to.equal(true)
			end)
		end)

		describe("KillIndicatorColors", function()
			it("should have at least one color", function()
				expect(#Constants.KillIndicatorColors > 0).to.equal(true)
			end)

			it("should have all Color3 values", function()
				for _, color in Constants.KillIndicatorColors do
					expect(typeof(color)).to.equal("Color3")
				end
			end)
		end)

		describe("Hitmarker constants", function()
			it("should have SizeLarge as UDim2", function()
				expect(typeof(Constants.Hitmarker.SizeLarge)).to.equal("UDim2")
			end)

			it("should have SizeNormal as UDim2", function()
				expect(typeof(Constants.Hitmarker.SizeNormal)).to.equal("UDim2")
			end)

			it("should have positive AnimDuration", function()
				expect(Constants.Hitmarker.AnimDuration).to.be.a("number")
				expect(Constants.Hitmarker.AnimDuration > 0).to.equal(true)
			end)

			it("should have positive PoolSize", function()
				expect(Constants.Hitmarker.PoolSize).to.be.a("number")
				expect(Constants.Hitmarker.PoolSize > 0).to.equal(true)
			end)
		end)

		describe("Raycast constants", function()
			it("should have positive MaxAimDistance", function()
				expect(Constants.Raycast.MaxAimDistance).to.be.a("number")
				expect(Constants.Raycast.MaxAimDistance > 0).to.equal(true)
			end)
		end)

		describe("Defaults", function()
			it("should have DamageIndicators default", function()
				expect(Constants.Defaults.DamageIndicators).to.be.a("boolean")
			end)

			it("should have DamageIndicatorFont default", function()
				expect(Constants.Defaults.DamageIndicatorFont).to.be.a("string")
			end)

			it("should have HealIndicatorFont default", function()
				expect(Constants.Defaults.HealIndicatorFont).to.be.a("string")
			end)

			it("should have HitSounds default", function()
				expect(Constants.Defaults.HitSounds).to.be.a("boolean")
			end)

			it("should have KillSounds default", function()
				expect(Constants.Defaults.KillSounds).to.be.a("boolean")
			end)

			it("should have WeaponSounds default", function()
				expect(Constants.Defaults.WeaponSounds).to.be.a("boolean")
			end)

			it("should have valid DamageIndicatorSize", function()
				expect(Constants.Defaults.DamageIndicatorSize).to.be.a("number")
				expect(Constants.Defaults.DamageIndicatorSize > 0).to.equal(true)
			end)
		end)

		describe("HitmarkerSpeedMultipliers", function()
			it("should have at least one multiplier", function()
				expect(#Constants.HitmarkerSpeedMultipliers > 0).to.equal(true)
			end)

			it("should have all positive numbers", function()
				for _, mult in Constants.HitmarkerSpeedMultipliers do
					expect(mult).to.be.a("number")
					expect(mult > 0).to.equal(true)
				end
			end)

			it("should have 1.0 as one of the multipliers", function()
				local hasOne = false
				for _, mult in Constants.HitmarkerSpeedMultipliers do
					if mult == 1.0 then
						hasOne = true
						break
					end
				end
				expect(hasOne).to.equal(true)
			end)
		end)
	end)
end
