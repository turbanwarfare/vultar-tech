--!nocheck
return function()
	local MainModule = script.Parent.Parent.Parent.Parent
	local ReconWeaponBalanceConfig = require(MainModule.Shared.Config.Weapons.ReconWeaponBalanceConfig)
	local ReconAntiMacroService = require(script.Parent)

	local function createFakePlayer(userId: number, name: string): Player
		local p = Instance.new("Folder")
		p.Name = name
		p:SetAttribute("UserId", userId)
		return p :: any
	end

	describe("ReconAntiMacroService", function()
		beforeEach(function()
			ReconAntiMacroService.Cleanup()
			ReconAntiMacroService.init()
		end)

		afterEach(function()
			ReconAntiMacroService.Cleanup()
		end)

		describe("module structure", function()
			it("should have all required interface functions", function()
				expect(typeof(ReconAntiMacroService.init)).to.equal("function")
				expect(typeof(ReconAntiMacroService.Cleanup)).to.equal("function")
				expect(typeof(ReconAntiMacroService.RegisterRifleDischarge)).to.equal("function")
				expect(typeof(ReconAntiMacroService.RecordRifleHit)).to.equal("function")
				expect(typeof(ReconAntiMacroService.IsSwitchLocked)).to.equal("function")
				expect(typeof(ReconAntiMacroService.RecordSwitchAttempt)).to.equal("function")
				expect(typeof(ReconAntiMacroService.RegisterKill)).to.equal("function")
				expect(typeof(ReconAntiMacroService.ClearLockout)).to.equal("function")
				expect(typeof(ReconAntiMacroService.ClearPlayer)).to.equal("function")
				expect(typeof(ReconAntiMacroService.GetLockoutStatus)).to.equal("function")
			end)
		end)

		describe("lockout duration formula and pairing enforcement", function()
			it("should lock switch to paired pistol BR-8 when BR-50 is discharged at 64% charge", function()
				local player = createFakePlayer(1001, "TestRaider")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 0.64)

				local isLockedToPistol, remaining, lockedPistol = ReconAntiMacroService.GetLockoutStatus(player)
				expect(isLockedToPistol).to.equal(true)
				expect(lockedPistol).to.equal("BR-8")
				expect(remaining > 0).to.equal(true)

				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(true)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "H-12")).to.equal(false)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "Medi+")).to.equal(false)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "Sword")).to.equal(false)
			end)

			it("should lock switch to paired pistol H-12 when H-50 is discharged at 50% charge", function()
				local player = createFakePlayer(1002, "TestDefender")
				ReconAntiMacroService.RegisterRifleDischarge(player, "H-50", 0.50)

				expect(ReconAntiMacroService.IsSwitchLocked(player, "H-12")).to.equal(true)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(false)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "Medi+")).to.equal(false)
			end)

			it("should not lock switch when non-recon weapons are discharged", function()
				local player = createFakePlayer(1003, "TestAssault")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-16", 0.5)

				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(false)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "H-12")).to.equal(false)
			end)

			it("should not lock switch when fired at 100% charge", function()
				local player = createFakePlayer(1004, "TestFullCharge")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 1.0)

				local isLocked, remaining = ReconAntiMacroService.GetLockoutStatus(player)
				expect(isLocked).to.equal(false)
				expect(remaining).to.equal(0)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(false)
			end)

			it("should not lock switch when fired at 0% charge", function()
				local player = createFakePlayer(1005, "TestZeroCharge")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 0.0)

				local isLocked, remaining = ReconAntiMacroService.GetLockoutStatus(player)
				expect(isLocked).to.equal(false)
				expect(remaining).to.equal(0)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(false)
			end)
		end)

		describe("state clearing on death and respawn", function()
			it("should clear active lockout immediately when ClearLockout is called", function()
				local player = createFakePlayer(1006, "TestRespawn")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 0.5)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(true)

				ReconAntiMacroService.ClearLockout(player)
				expect(ReconAntiMacroService.IsSwitchLocked(player, "BR-8")).to.equal(false)
			end)

			it("should clean up player state completely on ClearPlayer", function()
				local player = createFakePlayer(1007, "TestLeave")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 0.5)

				ReconAntiMacroService.ClearPlayer(player)
				local isLocked = ReconAntiMacroService.IsSwitchLocked(player, "BR-8")
				expect(isLocked).to.equal(false)
			end)
		end)

		describe("behavioral signals", function()
			it("should record early switch latency attempts on blocked switches", function()
				local player = createFakePlayer(1008, "TestMacroUser")
				ReconAntiMacroService.RegisterRifleDischarge(player, "BR-50", 0.64)

				ReconAntiMacroService.RecordSwitchAttempt(player, "BR-8")
				ReconAntiMacroService.RecordSwitchAttempt(player, "BR-8")
				ReconAntiMacroService.RecordSwitchAttempt(player, "BR-8")
			end)

			it("should record lethal damage precision combos on kill", function()
				local killer = createFakePlayer(1009, "TestComboKiller")
				local victimId = 2001

				ReconAntiMacroService.RegisterRifleDischarge(killer, "BR-50", 0.64)
				ReconAntiMacroService.RecordRifleHit(killer, victimId, 88)
				ReconAntiMacroService.RegisterKill(killer, victimId, "BR-8")
			end)
		end)
	end)
end
