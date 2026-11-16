--!nocheck
return function()
	local Maps = require(script.Parent)

	describe("Maps", function()
		local TARGET_PLACES = {
			Overwatch = 117954931852402,
			Nova = 118987827318205,
			Tridenthold = 113408083426676,
			Mataro = 82023579765520,
			MataroTesting = 86371032857491,
			Onyx = 70983359460672,
			Surrex = 106608091105526,
			Silo = 100112194136333,
			Testing = 134407518396463,
			Ironworks = 103242562426271,
			SparringArena = 106589413108827,
			AimChamber = 94785875266022,
			Pitgrounds = 111392438943897,
			Dreadspire = 88634683432584,
		}

		it("should resolve map names correctly", function()
			expect(Maps.getMapName(TARGET_PLACES.Overwatch)).to.equal("Overwatch")
			expect(Maps.getMapName(TARGET_PLACES.Nova)).to.equal("Nova")
			expect(Maps.getMapName(TARGET_PLACES.Tridenthold)).to.equal("Tridenthold")
			expect(Maps.getMapName(TARGET_PLACES.Mataro)).to.equal("Mataro")
			expect(Maps.getMapName(TARGET_PLACES.MataroTesting)).to.equal("MataroTesting")
			expect(Maps.getMapName(TARGET_PLACES.Onyx)).to.equal("Onyx")
			expect(Maps.getMapName(TARGET_PLACES.Surrex)).to.equal("Surrex")
			expect(Maps.getMapName(TARGET_PLACES.Silo)).to.equal("Silo")
			expect(Maps.getMapName(TARGET_PLACES.Testing)).to.equal("Testing")
			expect(Maps.getMapName(TARGET_PLACES.Ironworks)).to.equal("Ironworks")
			expect(Maps.getMapName(TARGET_PLACES.SparringArena)).to.equal("SparringArena")
			expect(Maps.getMapName(TARGET_PLACES.AimChamber)).to.equal("AimChamber")
			expect(Maps.getMapName(TARGET_PLACES.Pitgrounds)).to.equal("Pitgrounds")
			expect(Maps.getMapName(TARGET_PLACES.Dreadspire)).to.equal("Dreadspire")
		end)

		it("should return valid map config for all target places", function()
			for _, placeId in TARGET_PLACES do
				local config = Maps.getConfig(placeId)
				expect(config).to.be.ok()
				expect(typeof(config.GameType)).to.equal("string")
			end
		end)

		it("should force the side leaderboard only on Tridenthold and Dreadspire", function()
			expect(Maps.forcesSideLeaderboard(TARGET_PLACES.Tridenthold)).to.equal(true)
			expect(Maps.forcesSideLeaderboard(TARGET_PLACES.Dreadspire)).to.equal(true)
			expect(Maps.forcesSideLeaderboard(TARGET_PLACES.Overwatch)).to.equal(false)
			expect(Maps.forcesSideLeaderboard(TARGET_PLACES.Mataro)).to.equal(false)
			expect(Maps.forcesSideLeaderboard(1)).to.equal(false)
		end)

		it("should correctly identify Hardpoint maps", function()
			expect(Maps.isHardpointMap(TARGET_PLACES.Overwatch)).to.equal(true)
			expect(Maps.isHardpointMap(TARGET_PLACES.Silo)).to.equal(true)
			expect(Maps.isHardpointMap(TARGET_PLACES.Ironworks)).to.equal(false)
		end)

		it("should correctly identify Domination maps via flag", function()
			expect(Maps.isDominationMap(TARGET_PLACES.Ironworks)).to.equal(true)
			expect(Maps.isDominationMap(TARGET_PLACES.Testing)).to.equal(true)
			expect(Maps.isDominationMap(TARGET_PLACES.Overwatch)).to.equal(false)
			expect(Maps.isDominationMap(TARGET_PLACES.Mataro)).to.equal(false)
		end)

		it("should return correct force weapons on Silo", function()
			local defenderWeapon = Maps.getForceWeapon(TARGET_PLACES.Silo, "Defenders")
			local raiderWeapon = Maps.getForceWeapon(TARGET_PLACES.Silo, "Raiders")
			expect(defenderWeapon).to.equal("H-22")
			expect(raiderWeapon).to.equal("BR-22")
		end)

		it("should safely return DEFAULT_CONFIG for unknown placeId", function()
			local unknownConfig = Maps.getConfig(99999999999999)
			expect(unknownConfig).to.be.ok()
			expect(unknownConfig.GameType).to.equal("DT")
		end)
	end)
end
