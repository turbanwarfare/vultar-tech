--!nocheck
--!native
--!optimize 2

local RunService = game:GetService("RunService")

return function()
	if not RunService:IsClient() then
		return
	end

	local SettingsMenu = require(script.Parent.Menu)
	local SettingsTab = require(script.Parent.Tab)
	local SettingsSection = require(script.Parent.Section)
	local SettingsRow = require(script.Parent.Row)
	local SettingsToggle = require(script.Parent.Toggle)
	local SettingsPicker = require(script.Parent.Picker)
	local SettingsInput = require(script.Parent.Input)
	local SettingsFontPicker = require(script.Parent.FontPicker)

	describe("Settings Components", function()
		describe("module exports", function()
			it("should export SettingsMenu as a function", function()
				expect(typeof(SettingsMenu)).to.equal("function")
			end)

			it("should export SettingsTab as a function", function()
				expect(typeof(SettingsTab)).to.equal("function")
			end)

			it("should export SettingsSection as a function", function()
				expect(typeof(SettingsSection)).to.equal("function")
			end)

			it("should export SettingsRow as a function", function()
				expect(typeof(SettingsRow)).to.equal("function")
			end)

			it("should export SettingsToggle as a function", function()
				expect(typeof(SettingsToggle)).to.equal("function")
			end)

			it("should export SettingsPicker as a function", function()
				expect(typeof(SettingsPicker)).to.equal("function")
			end)

			it("should export SettingsInput as a function", function()
				expect(typeof(SettingsInput)).to.equal("function")
			end)

			it("should export SettingsFontPicker as a function", function()
				expect(typeof(SettingsFontPicker)).to.equal("function")
			end)
		end)

		describe("SettingsToggle", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a toggle component", function()
				local value = scope:Value(false)
				local toggle = SettingsToggle(scope, {
					Value = value,
				})

				expect(toggle).to.be.ok()
				expect(toggle:IsA("TextButton")).to.equal(true)
				expect(toggle.Name).to.equal("Toggle")

				toggle:Destroy()
			end)

			it("should create with initial true value", function()
				local value = scope:Value(true)
				local toggle = SettingsToggle(scope, {
					Value = value,
				})

				expect(toggle).to.be.ok()
				toggle:Destroy()
			end)
		end)

		describe("SettingsPicker", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a picker component with options", function()
				local value = scope:Value(1)
				local picker = SettingsPicker(scope, {
					Value = value,
					Options = { "Option1", "Option2", "Option3" },
				})

				expect(picker).to.be.ok()
				expect(picker:IsA("Frame")).to.equal(true)
				expect(picker.Name).to.equal("SettingsPicker")

				picker:Destroy()
			end)

			it("should create buttons for each option", function()
				local value = scope:Value(1)
				local picker = SettingsPicker(scope, {
					Value = value,
					Options = { "A", "B" },
				})

				local buttonCount = 0
				for _, child in picker:GetChildren() do
					if child:IsA("TextButton") then
						buttonCount = buttonCount + 1
					end
				end

				expect(buttonCount).to.equal(2)

				task.defer(picker.Destroy, picker)
			end)
		end)

		describe("SettingsFontPicker", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a font picker component", function()
				local value = scope:Value("GothamBold")
				local fontPicker = SettingsFontPicker(scope, {
					Value = value,
				})

				expect(fontPicker).to.be.ok()
				expect(fontPicker:IsA("Frame")).to.equal(true)
				expect(fontPicker.Name).to.equal("FontPicker")

				fontPicker:Destroy()
			end)
		end)

		describe("SettingsInput", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create an input component", function()
				local value = scope:Value(0)
				local input = SettingsInput(scope, {
					Value = value,
				})

				expect(input).to.be.ok()
				expect(input:IsA("Frame")).to.equal(true)
				expect(input.Name).to.equal("Input")

				input:Destroy()
			end)

			it("should accept placeholder text", function()
				local value = scope:Value(0)
				local input = SettingsInput(scope, {
					Value = value,
					Placeholder = "Enter value",
				})

				expect(input).to.be.ok()
				input:Destroy()
			end)
		end)

		describe("SettingsRow", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a row with Boolean control", function()
				local value = scope:Value(true)
				local row = SettingsRow(scope, {
					Label = "Test Setting",
					ControlType = "Boolean",
					Value = value,
				})

				expect(row).to.be.ok()
				expect(row:IsA("Frame")).to.equal(true)

				row:Destroy()
			end)

			it("should create a row with Pick control", function()
				local value = scope:Value(1)
				local row = SettingsRow(scope, {
					Label = "Test Picker",
					ControlType = "Pick",
					Value = value,
					Options = { "A", "B", "C" },
				})

				expect(row).to.be.ok()
				row:Destroy()
			end)

			it("should create a row with TypeIn control", function()
				local value = scope:Value(0)
				local row = SettingsRow(scope, {
					Label = "Test Input",
					ControlType = "TypeIn",
					Value = value,
				})

				expect(row).to.be.ok()
				row:Destroy()
			end)

			it("should create a row with FontPick control", function()
				local value = scope:Value("GothamBold")
				local row = SettingsRow(scope, {
					Label = "Test Font",
					ControlType = "FontPick",
					Value = value,
				})

				expect(row).to.be.ok()
				row:Destroy()
			end)
		end)

		describe("SettingsSection", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a section with title", function()
				local section = SettingsSection(scope, {
					Title = "Test Section",
					Children = {},
				})

				expect(section).to.be.ok()
				expect(section:IsA("Frame")).to.equal(true)

				section:Destroy()
			end)

			it("should include title bar", function()
				local section = SettingsSection(scope, {
					Title = "My Section",
					Children = {},
				})

				local titleBar = section:FindFirstChild("TitleBar", true)
				expect(titleBar).to.be.ok()

				section:Destroy()
			end)
		end)

		describe("SettingsTab", function()
			local Fusion
			local scope

			beforeAll(function()
				local MainModule = script.Parent.Parent.Parent.Parent
				local Packages = MainModule:WaitForChild("Packages", 5)
				Fusion = require(Packages:WaitForChild("Fusion", 5)) :: any
			end)

			beforeEach(function()
				scope = Fusion.scoped(Fusion)
			end)

			afterEach(function()
				if scope then
					Fusion.doCleanup(scope)
					scope = nil
				end
			end)

			it("should create a tab with text", function()
				local isSelected = scope:Value(false)
				local tab = SettingsTab(scope, {
					Text = "Settings",
					IsSelected = isSelected,
				})

				expect(tab).to.be.ok()
				expect(tab:IsA("Frame")).to.equal(true)

				tab:Destroy()
			end)

			it("should display uppercase text", function()
				local isSelected = scope:Value(true)
				local tab = SettingsTab(scope, {
					Text = "rules",
					IsSelected = isSelected,
				})

				local label = tab:FindFirstChild("Label", true)
				expect(label).to.be.ok()
				if label and label:IsA("TextLabel") then
					expect(label.Text).to.equal("RULES")
				end

				tab:Destroy()
			end)
		end)
	end)
end
