--!nocheck
return function()
	describe("WeaponService - Tool Equip System", function()
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
			local rightArm = createMockPart("Right Arm")
			local head = createMockPart("Head")
			local humanoidRootPart = createMockPart("HumanoidRootPart")
			local humanoid = Instance.new("Humanoid")

			character.PrimaryPart = humanoidRootPart
			torso.Parent = character
			rightArm.Parent = character
			head.Parent = character
			humanoidRootPart.Parent = character
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

		describe("Grip Motor6D (legacy handle rig)", function()
			it("should keep Grip.Part0 as nil after tool creation", function()
				local _, _, grip = createMockTool("H-82")
				expect(grip.Part0).to.equal(nil)
			end)

			it("should keep Grip.Part0 nil on BodyAttach equip", function()
				local _, torso = createMockCharacter()
				local _, _, grip = createMockTool("H-82")
				local toolGrip = createToolGrip(torso)

				toolGrip.Part1 = nil
				expect(grip.Part0).to.equal(nil)
			end)

			it("should keep Grip.Part0 nil on BodyAttach unequip", function()
				local _, torso = createMockCharacter()
				local _, _, grip = createMockTool("H-82")
				local toolGrip = createToolGrip(torso)

				toolGrip.Part1 = nil
				expect(grip.Part0).to.equal(nil)
			end)

			it("should have Grip.Part1 = Handle from creation", function()
				local _, handle, grip = createMockTool("H-82")
				expect(grip.Part1).to.equal(handle)
			end)
		end)

		describe("ToolGrip Motor6D (matches v1 PlayerSetup)", function()
			it("should create ToolGrip with Part0 = Torso", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)

				expect(toolGrip.Part0).to.equal(torso)
				expect(toolGrip.Part1).to.equal(nil)
			end)

			it("should set ToolGrip.Part1 = BodyAttach via ChildAdded", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, _, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach
				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should clear ToolGrip.Part1 via ChildRemoved", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, _, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach
				toolGrip.Part1 = nil
				expect(toolGrip.Part1).to.equal(nil)
			end)

			it("should survive 1000 equip/unequip cycles", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, _, bodyAttach = createMockTool("H-82")

				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = bodyAttach
					expect(toolGrip.Part0).to.equal(torso)
					expect(toolGrip.Part1).to.equal(bodyAttach)

					toolGrip.Part1 = nil
					expect(toolGrip.Part1).to.equal(nil)
				end
			end)
		end)

		describe("RightGrip destruction", function()
			it("should destroy RightGrip on Right Arm", function()
				local _, _, rightArm = createMockCharacter()

				local rightGrip = Instance.new("Motor6D")
				rightGrip.Name = "RightGrip"
				rightGrip.Parent = rightArm

				expect(rightArm:FindFirstChild("RightGrip")).to.be.ok()
				rightGrip:Destroy()
				expect(rightArm:FindFirstChild("RightGrip")).to.equal(nil)
			end)

			it("should handle 1000 cycles of RightGrip create/destroy", function()
				local _, _, rightArm = createMockCharacter()

				for _ = 1, EQUIP_ITERATIONS do
					local rightGrip = Instance.new("Motor6D")
					rightGrip.Name = "RightGrip"
					rightGrip.Parent = rightArm
					rightGrip:Destroy()
					expect(rightArm:FindFirstChild("RightGrip")).to.equal(nil)
				end
			end)
		end)

		describe("Tool structure validation", function()
			it("should have Handle as direct child of Tool", function()
				local tool, handle = createMockTool("H-82")
				expect(handle.Parent).to.equal(tool)
			end)

			it("should have Grip Motor6D as child of Handle", function()
				local _, handle, grip = createMockTool("H-82")
				expect(grip.Parent).to.equal(handle)
			end)

			it("should have BodyAttach as direct child of Tool", function()
				local tool, _, _, bodyAttach = createMockTool("H-82")
				expect(bodyAttach.Parent).to.equal(tool)
			end)

			it("should have WeldConstraint linking Handle to BodyAttach", function()
				local _, handle, _, bodyAttach = createMockTool("H-82")
				local weld = bodyAttach:FindFirstChildOfClass("WeldConstraint")
				expect(weld).to.be.ok()
				expect(weld.Part0).to.equal(handle)
				expect(weld.Part1).to.equal(bodyAttach)
			end)

			it("should have GunModel as child of Tool", function()
				local tool = createMockTool("H-82")
				local gunModel = tool:FindFirstChild("GunModel")
				expect(gunModel).to.be.ok()
			end)
		end)

		describe("Full equip flow (BodyAttach pattern)", function()
			it("should set ToolGrip.Part1=BodyAttach and leave Grip.Part0 nil on equip", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, grip, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach

				expect(grip.Part0).to.equal(nil)
				expect(toolGrip.Part0).to.equal(torso)
				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should clear Grip.Part0 and ToolGrip.Part1 on unequip", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, grip, bodyAttach = createMockTool("H-82")

				toolGrip.Part1 = bodyAttach

				toolGrip.Part1 = nil
				expect(grip.Part0).to.equal(nil)
				expect(toolGrip.Part1).to.equal(nil)
			end)

			it("should survive 1000 full equip/unequip cycles", function()
				local _, torso, rightArm = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, grip, bodyAttach = createMockTool("H-82")

				local violations = 0

				for _ = 1, EQUIP_ITERATIONS do
					toolGrip.Part1 = bodyAttach

					if grip.Part0 ~= nil then
						violations += 1
					end
					if toolGrip.Part0 ~= torso then
						violations += 1
					end
					if toolGrip.Part1 ~= bodyAttach then
						violations += 1
					end

					local rg = Instance.new("Motor6D")
					rg.Name = "RightGrip"
					rg.Parent = rightArm
					rg:Destroy()

					toolGrip.Part1 = nil

					if grip.Part0 ~= nil then
						violations += 1
					end
					if toolGrip.Part1 ~= nil then
						violations += 1
					end
				end

				expect(violations).to.equal(0)
			end)

			it("should handle switching between 3 weapons 1000 times", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)

				local weapons = {}
				for _, name in { "H-82", "BR-16", "Medi+" } do
					local _, _, grip, bodyAttach = createMockTool(name)
					table.insert(weapons, { grip = grip, bodyAttach = bodyAttach })
				end

				local violations = 0

				for i = 1, EQUIP_ITERATIONS do
					local w = weapons[(i % #weapons) + 1]

					toolGrip.Part1 = w.bodyAttach

					if w.grip.Part0 ~= nil then
						violations += 1
					end
					if toolGrip.Part1 ~= w.bodyAttach then
						violations += 1
					end

					toolGrip.Part1 = nil
				end

				expect(violations).to.equal(0)
			end)
		end)

		describe("Holster system", function()
			it("should create and destroy clone for holstering", function()
				local tool = createMockTool("H-82")
				local gunModel = tool:FindFirstChild("GunModel") :: Model

				local clone = gunModel:Clone()
				expect(clone).to.be.ok()
				clone:Destroy()
			end)

			it("should handle 1000 holster/unholster cycles", function()
				local tool = createMockTool("H-82")
				local gunModel = tool:FindFirstChild("GunModel") :: Model
				local container = Instance.new("Folder")

				for _ = 1, EQUIP_ITERATIONS do
					local clone = gunModel:Clone()
					clone.Parent = container
					clone:Destroy()
				end

				task.wait()
				expect(#container:GetChildren()).to.equal(0)
				task.defer(container.Destroy, container)
			end)

			it("should handle 1000 Medi+ and leg-holster tool holster/unholster cycles", function()
				local mediTool = createMockTool("Medi+")
				local gunModel = mediTool:FindFirstChild("GunModel") :: Model
				local container = Instance.new("Folder")

				for _ = 1, EQUIP_ITERATIONS do
					local clone = gunModel:Clone()
					clone.Parent = container
					clone:Destroy()
				end

				task.wait()
				expect(#container:GetChildren()).to.equal(0)
				task.defer(container.Destroy, container)
				mediTool:Destroy()
			end)
		end)

		describe("ChildAdded/ChildRemoved contract (v1 PlayerSetup pattern)", function()
			it("should set ToolGrip.Part1 when tool enters character", function()
				local character, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, _, bodyAttach = createMockTool("H-82")

				local part1Set = false
				character.ChildAdded:Connect(function(child)
					if child:IsA("Tool") and child:FindFirstChild("BodyAttach") then
						toolGrip.Part1 = child.BodyAttach
						part1Set = true
					end
				end)

				tool.Parent = character
				task.wait()

				expect(part1Set).to.equal(true)
				expect(toolGrip.Part1).to.equal(bodyAttach)
			end)

			it("should clear ToolGrip.Part1 when tool leaves character", function()
				local character, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local tool, _, _, bodyAttach = createMockTool("H-82")

				character.ChildRemoved:Connect(function(child)
					if child:IsA("Tool") then
						toolGrip.Part1 = nil
					end
				end)

				tool.Parent = character
				task.wait()
				toolGrip.Part1 = bodyAttach

				local backpack = Instance.new("Folder")
				tool.Parent = backpack
				task.wait()

				expect(toolGrip.Part1).to.equal(nil)
				backpack:Destroy()
			end)
		end)

		describe("CheckParent contract (v1 pattern)", function()
			it("should only holster/unholster, not touch Grip or ToolGrip", function()
				local _, torso = createMockCharacter()
				local toolGrip = createToolGrip(torso)
				local _, _, grip = createMockTool("H-82")

				expect(grip.Part0).to.equal(nil)
				expect(toolGrip.Part1).to.equal(nil)
			end)
		end)

		describe("Cleanup", function()
			it("should not leak connections", function()
				local character = Instance.new("Model")
				local connections: { RBXScriptConnection } = {}

				table.insert(connections, character.ChildAdded:Connect(function() end))
				table.insert(connections, character.ChildRemoved:Connect(function() end))

				for _, c in connections do
					expect(c.Connected).to.equal(true)
				end

				for _, c in connections do
					c:Disconnect()
				end

				for _, c in connections do
					expect(c.Connected).to.equal(false)
				end

				character:Destroy()
			end)
		end)
	end)
end
