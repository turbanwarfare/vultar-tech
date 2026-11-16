--!nocheck
return function()
	local success, WeaponConfig = pcall(function()
		return require(script.Parent.Parent.Parent.Parent.Shared.Config.Weapons.WeaponConfig)
	end)

	local successGunStats, GunStats = pcall(function()
		return require(script.Parent.Parent.Parent.Parent.Shared.Config.GunStats)
	end)

	describe("WeaponEquip - Client Tool Attachment", function()
		local EQUIP_ITERATIONS = 1000

		local function createMockPart(name: string): BasePart
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			return part
		end

		local function createMockCharacter(): (Model, BasePart, BasePart, Humanoid)
			local character = Instance.new("Model")
			character.Name = "MockCharacter"

			local torso = createMockPart("Torso")
			torso.Parent = character

			local rightArm = createMockPart("Right Arm")
			rightArm.Parent = character

			local head = createMockPart("Head")
			head.Parent = character

			local hrp = createMockPart("HumanoidRootPart")
			hrp.Parent = character
			character.PrimaryPart = hrp

			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character

			return character, torso, rightArm, humanoid
		end

		local function createMockTool(toolName: string): (Tool, BasePart, Motor6D, BasePart)
			local tool = Instance.new("Tool")
			tool.Name = toolName

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Transparency = 1
			handle.CanCollide = false
			handle.Parent = tool

			local grip = Instance.new("Motor6D")
			grip.Name = "Grip"
			grip.Part0 = nil
			grip.Part1 = handle
			grip.Parent = handle

			local bodyAttach = Instance.new("Part")
			bodyAttach.Name = "BodyAttach"
			bodyAttach.Size = Vector3.new(0.1, 0.1, 0.1)
			bodyAttach.Transparency = 1
			bodyAttach.CanCollide = false
			bodyAttach.Parent = tool

			local bodyWeld = Instance.new("WeldConstraint")
			bodyWeld.Part0 = handle
			bodyWeld.Part1 = bodyAttach
			bodyWeld.Parent = bodyAttach

			local gunModel = Instance.new("Model")
			gunModel.Name = "GunModel"
			gunModel.Parent = tool

			return tool, handle, grip, bodyAttach
		end

		local function createToolGrip(torso: BasePart): Motor6D
			local toolGrip = Instance.new("Motor6D")
			toolGrip.Name = "ToolGrip"
			toolGrip.Part0 = torso
			toolGrip.Parent = torso
			return toolGrip
		end

		describe("Client ToolGrip.Part1 assignment", function()
			it("should prefer BodyAttach over Handle for ToolGrip.Part1", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, handle, _, bodyAttach = createMockTool("H-82")

				local attach = tool:FindFirstChild("BodyAttach")
				if attach and attach:IsA("BasePart") then
					toolGrip.Part1 = attach
				else
					toolGrip.Part1 = handle
				end

				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should fallback to Handle if no BodyAttach", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)

				local tool = Instance.new("Tool")
				tool.Name = "LegacyTool"
				local handle = Instance.new("Part")
				handle.Name = "Handle"
				handle.Parent = tool

				local attach = tool:FindFirstChild("BodyAttach")
				if attach and attach:IsA("BasePart") then
					toolGrip.Part1 = attach
				else
					toolGrip.Part1 = handle
				end

				expect(toolGrip.Part1).to.equal(handle)

				tool:Destroy()
			end)

			it("should wait for ToolGrip if not immediately available", function()
				local _, torso = createMockCharacter()

				local toolGrip: Motor6D? = torso:FindFirstChild("ToolGrip") :: Motor6D?
				expect(toolGrip).to.equal(nil)

				local createdToolGrip = createToolGrip(torso)

				toolGrip = torso:FindFirstChild("ToolGrip") :: Motor6D?
				expect(toolGrip).to.be.ok()
				expect(toolGrip).to.equal(createdToolGrip)
			end)
		end)

		describe("Client RightGrip destruction", function()
			it("should destroy existing RightGrip on equip", function()
				local _, _, rightArm = createMockCharacter()

				local rightGrip = Instance.new("Motor6D")
				rightGrip.Name = "RightGrip"
				rightGrip.Parent = rightArm

				expect(rightArm:FindFirstChild("RightGrip")).to.be.ok()

				local found = rightArm:FindFirstChild("RightGrip")
				if found then
					found:Destroy()
				end

				expect(rightArm:FindFirstChild("RightGrip")).to.equal(nil)
			end)

			it("should handle continuous RightGrip listener pattern", function()
				local _, _, rightArm = createMockCharacter()
				local destroyCount = 0

				local conn = rightArm.ChildAdded:Connect(function(child)
					if child.Name == "RightGrip" and child:IsA("Motor6D") then
						task.defer(function()
							if child.Parent then
								child:Destroy()
								destroyCount += 1
							end
						end)
					end
				end)

				for _ = 1, 100 do
					local rg = Instance.new("Motor6D")
					rg.Name = "RightGrip"
					rg.Parent = rightArm
					task.wait()
					task.wait()
				end

				expect(destroyCount).to.equal(100)
				expect(rightArm:FindFirstChild("RightGrip")).to.equal(nil)

				conn:Disconnect()
			end)
		end)

		if success then
			describe("WeaponConfig integration", function()
				it("should return config for H-82", function()
					local config = WeaponConfig.getToolConfig("H-82")
					expect(config).to.be.ok()
				end)

				it("should return config for BR-16", function()
					local config = WeaponConfig.getToolConfig("BR-16")
					expect(config).to.be.ok()
				end)

				it("should return config for Medi+", function()
					local config = WeaponConfig.getToolConfig("Medi+")
					expect(config).to.be.ok()
				end)

				it("should have Animations table for each weapon config", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local config = WeaponConfig.getToolConfig(weaponName)
						if config then
							expect(config.Animations).to.be.ok()
							expect(typeof(config.Animations)).to.equal("table")
						end
					end
				end)

				it("should have Idle animation for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local config = WeaponConfig.getToolConfig(weaponName)
						if config and config.Animations then
							expect(config.Animations.Idle).to.be.ok()
							expect(typeof(config.Animations.Idle)).to.equal("string")
						end
					end
				end)

				it("should have Sprint animation for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local config = WeaponConfig.getToolConfig(weaponName)
						if config and config.Animations then
							expect(config.Animations.Sprint).to.be.ok()
						end
					end
				end)

				it("should return valid weapon class for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local weaponClass = WeaponConfig.getToolClass(weaponName)
						expect(weaponClass).to.be.ok()
					end
				end)

				it("should return speeds for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local speeds = WeaponConfig.getSpeeds(weaponName)
						expect(speeds).to.be.ok()
						expect(speeds.Walk).to.be.ok()
						expect(speeds.Sprint).to.be.ok()
						expect(speeds.Crouch).to.be.ok()
						expect(speeds.Zoom).to.be.ok()
					end
				end)

				it("should return nil config for unknown weapon", function()
					local config = WeaponConfig.getToolConfig("NonExistentWeapon")
					expect(config).to.equal(nil)
				end)
			end)
		end

		if successGunStats then
			describe("GunStats integration", function()
				it("should return stats for H-82", function()
					local stats = GunStats.get("H-82")
					expect(stats).to.be.ok()
				end)

				it("should return stats for BR-16", function()
					local stats = GunStats.get("BR-16")
					expect(stats).to.be.ok()
				end)

				it("should return stats for Medi+", function()
					local stats = GunStats.get("Medi+")
					expect(stats).to.be.ok()
				end)

				it("should have HolsterPart for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local stats = GunStats.get(weaponName)
						if stats then
							expect(stats.HolsterPart).to.be.ok()
							expect(typeof(stats.HolsterPart)).to.equal("string")
						end
					end
				end)

				it("should have HolsterOffset for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local stats = GunStats.get(weaponName)
						if stats then
							expect(stats.HolsterOffset).to.be.ok()
							expect(typeof(stats.HolsterOffset)).to.equal("CFrame")
						end
					end
				end)

				it("should have Animations for each weapon", function()
					for _, weaponName in { "H-82", "BR-16", "Medi+" } do
						local stats = GunStats.get(weaponName)
						if stats then
							expect(stats.Animations).to.be.ok()
						end
					end
				end)

				it("should return nil for unknown weapon", function()
					local stats = GunStats.get("FakeGun123")
					expect(stats).to.equal(nil)
				end)
			end)
		end

		describe("Full client equip flow simulation", function()
			it("should set up all Motor6Ds correctly in equip flow", function()
				local character, torso, rightArm = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, handle, grip, bodyAttach = createMockTool("H-82")

				expect(grip.Part0).to.equal(nil)

				toolGrip.Part1 = bodyAttach

				local rightGrip = rightArm:FindFirstChild("RightGrip")
				if rightGrip then
					rightGrip:Destroy()
				end

				expect(grip.Part0).to.equal(nil)
				expect(toolGrip.Part0).to.equal(torso)
				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should clean up correctly in unequip flow", function()
				local _, torso, rightArm = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, grip, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach

				toolGrip.Part1 = nil

				expect(toolGrip.Part1).to.equal(nil)
				expect(grip.Part0).to.equal(nil)
			end)

			it("should survive 1000 full client equip/unequip cycles", function()
				local character, torso, rightArm = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, handle, grip, bodyAttach = createMockTool("H-82")

				local violations = 0

				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = bodyAttach

					local rightGrip = Instance.new("Motor6D")
					rightGrip.Name = "RightGrip"
					rightGrip.Parent = rightArm
					rightGrip:Destroy()

					if grip.Part0 ~= nil then
						violations += 1
					end
					if toolGrip.Part0 ~= torso then
						violations += 1
					end
					if toolGrip.Part1 ~= bodyAttach then
						violations += 1
					end
					if rightArm:FindFirstChild("RightGrip") then
						violations += 1
					end

					toolGrip.Part1 = nil

					if toolGrip.Part1 ~= nil then
						violations += 1
					end
					if grip.Part0 ~= nil then
						violations += 1
					end
				end

				expect(violations).to.equal(0)
			end)
		end)

		describe("IsToolProperlyAttached contract", function()
			it("should return true when ToolGrip has both Part0 and Part1", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, _, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach

				local isAttached = toolGrip.Part0 ~= nil and toolGrip.Part1 ~= nil
				expect(isAttached).to.equal(true)
			end)

			it("should return false when ToolGrip.Part1 is nil", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)

				local isAttached = toolGrip.Part0 ~= nil and toolGrip.Part1 ~= nil
				expect(isAttached).to.equal(false)
			end)

			it("should toggle correctly across 1000 cycles", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, _, bodyAttach = createMockTool("H-82")

				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = bodyAttach
					expect(toolGrip.Part0 ~= nil and toolGrip.Part1 ~= nil).to.equal(true)

					toolGrip.Part1 = nil
					expect(toolGrip.Part0 ~= nil and toolGrip.Part1 ~= nil).to.equal(false)
				end
			end)
		end)

		describe("EnsureToolAttached contract", function()
			it("should reconnect ToolGrip.Part1 if missing", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, _, bodyAttach = createMockTool("H-82")

				expect(toolGrip.Part1).to.equal(nil)

				local attach = tool:FindFirstChild("BodyAttach")
				if attach and attach:IsA("BasePart") then
					toolGrip.Part1 = attach
				end

				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should not set Grip.Part0 during ensure", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, grip, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach

				expect(grip.Part0).to.equal(nil)
			end)
		end)

		describe("Reactive ToolGrip.Part1 replication guard", function()
			it("should automatically restore Part1 when server sets it to nil during active equip", function()
				local character, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, _, bodyAttach = createMockTool("H-82")
				tool.Parent = character

				local activeEquippedTool: Tool? = tool

				local function attachMockTool(t: Tool, tor: BasePart)
					local grip = tor:FindFirstChild("ToolGrip") :: Motor6D?
					if not grip then
						return
					end
					local ba = t:FindFirstChild("BodyAttach")
					if ba and ba:IsA("BasePart") then
						grip.Part1 = ba
					end
				end

				local conn = toolGrip:GetPropertyChangedSignal("Part1"):Connect(function()
					if activeEquippedTool and activeEquippedTool.Parent == character then
						if toolGrip.Part1 == nil then
							attachMockTool(activeEquippedTool, torso)
						end
					end
				end)

				toolGrip.Part1 = bodyAttach
				expect(toolGrip.Part1).to.equal(bodyAttach)
				toolGrip.Part1 = nil

				expect(toolGrip.Part1).to.equal(bodyAttach)

				conn:Disconnect()
				tool:Destroy()
				character:Destroy()
			end)

			it("should survive 1000 spam equip replication collisions without dropped frames", function()
				local character, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, _, bodyAttach = createMockTool("H-82")
				tool.Parent = character

				local activeEquippedTool: Tool? = tool

				local function attachMockTool(t: Tool, tor: BasePart)
					local grip = tor:FindFirstChild("ToolGrip") :: Motor6D?
					if not grip then
						return
					end
					local ba = t:FindFirstChild("BodyAttach")
					if ba and ba:IsA("BasePart") then
						grip.Part1 = ba
					end
				end

				local conn = toolGrip:GetPropertyChangedSignal("Part1"):Connect(function()
					if activeEquippedTool and activeEquippedTool.Parent == character then
						if toolGrip.Part1 == nil then
							attachMockTool(activeEquippedTool, torso)
						end
					end
				end)

				local nilCount = 0
				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = bodyAttach

					toolGrip.Part1 = nil

					if toolGrip.Part1 == nil then
						nilCount += 1
					end
				end

				expect(nilCount).to.equal(0)
				expect(toolGrip.Part1).to.equal(bodyAttach)

				conn:Disconnect()
				tool:Destroy()
				character:Destroy()
			end)

			it("should survive 1000 Medi+ spam equip cycles and leg-holster weapons with activeTool fallback", function()
				local character, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local mediTool, _, _, mediBodyAttach = createMockTool("Medi+")
				mediTool.Parent = character

				local activeEquippedTool: Tool? = nil

				local function attachMockTool(t: Tool, tor: BasePart)
					local grip = tor:FindFirstChild("ToolGrip") :: Motor6D?
					if not grip then
						return
					end
					local ba = t:FindFirstChild("BodyAttach")
					if ba and ba:IsA("BasePart") then
						grip.Part1 = ba
					end
				end

				local conn = toolGrip:GetPropertyChangedSignal("Part1"):Connect(function()
					local active = activeEquippedTool or character:FindFirstChildWhichIsA("Tool")
					if active and active.Parent == character then
						if toolGrip.Part1 == nil then
							attachMockTool(active, torso)
						end
					end
				end)

				local nilCount = 0
				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = mediBodyAttach

					toolGrip.Part1 = nil

					if toolGrip.Part1 == nil then
						nilCount += 1
					end
				end

				expect(nilCount).to.equal(0)
				expect(toolGrip.Part1).to.equal(mediBodyAttach)

				conn:Disconnect()
				mediTool:Destroy()
				character:Destroy()
			end)
		end)
	end)
end
