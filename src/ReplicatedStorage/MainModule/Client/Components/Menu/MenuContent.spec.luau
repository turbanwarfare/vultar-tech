--!nocheck

local RunService = game:GetService("RunService")

return function()
	if not RunService:IsClient() then
		return
	end

	local MainModule = script.Parent.Parent.Parent.Parent
	local Packages = MainModule:WaitForChild("Packages", 5)
	local Fusion = require(Packages:WaitForChild("Fusion", 5))
	local Theme = require(MainModule.Shared.UI.Theme)
	local Signal = require(MainModule.Shared.Utils.State.Signal)
	local DeepCopy = require(MainModule.Shared.Utils.Table.DeepCopy)
	local SettingsConfig = require(MainModule.Shared.Config.Settings.SettingsConfig)
	local MenuContent = require(script.Parent.MenuContent)
	local AvatarViewportLoader = require(MainModule.Client.Utils.AvatarViewportLoader)

	local function findTopLevelBoolean(): any
		for _, category in SettingsConfig.Categories do
			for _, settingDef in category.settings do
				if settingDef.type == "Boolean" then
					return settingDef
				end
			end
		end
		return nil
	end

	describe("Fusion New defaults", function()
		local scope

		beforeEach(function()
			scope = Fusion.scoped(Fusion)
		end)

		afterEach(function()
			Fusion.doCleanup(scope)
		end)

		it("keeps explicit props over class defaults", function()
			local label = scope:New("TextLabel")({
				Text = "VULTAR",
				TextSize = 22,
			})
			expect(label.Text).to.equal("VULTAR")
			expect(label.TextSize).to.equal(22)
			expect(label.Font).to.equal(Enum.Font.SourceSans)
		end)

		it("still applies defaults that are not overridden", function()
			local frame = scope:New("Frame")({})
			expect(frame.BorderSizePixel).to.equal(0)
			expect(frame.BackgroundColor3).to.equal(Color3.new(1, 1, 1))
		end)

		it("applies state-bound props over defaults", function()
			local text = scope:Value("A")
			local label = scope:New("TextLabel")({
				Text = text,
			})
			expect(label.Text).to.equal("A")
			text:set("B")
			expect(label.Text).to.equal("B")
		end)
	end)

	describe("MenuContent setting sync", function()
		local scope

		beforeEach(function()
			scope = Fusion.scoped(Fusion)
		end)

		afterEach(function()
			Fusion.doCleanup(scope)
		end)

		it("updates a row when SettingChanged fires for its key", function()
			local settingDef = findTopLevelBoolean()
			expect(settingDef).to.be.ok()

			local settings = DeepCopy.copy(SettingsConfig.DefaultSettings)
			settings.Settings[settingDef.key] = false
			local changed = Signal.new()

			local sections = MenuContent.createSettingsContent(scope, settings, nil, nil, nil, nil, changed)
			local holder = Instance.new("Folder")
			for _, section in sections do
				section.Parent = holder
			end
			local row = holder:FindFirstChild(settingDef.label or settingDef.key, true)
			expect(row).to.be.ok()

			local toggle = row:FindFirstChild("Toggle", true)
			expect(toggle).to.be.ok()
			expect(toggle.BackgroundColor3).to.equal(Theme.Toggle.Off.Background)

			changed:Fire(settingDef.key, true)
			expect(toggle.BackgroundColor3).to.equal(Theme.Toggle.On.Background)

			changed:Destroy()
			holder:Destroy()
		end)

		it("stops listening after the scope is cleaned up", function()
			local settings = DeepCopy.copy(SettingsConfig.DefaultSettings)
			local changed = Signal.new()
			local cleanupScope = Fusion.scoped(Fusion)
			MenuContent.createSettingsContent(cleanupScope, settings, nil, nil, nil, nil, changed)
			Fusion.doCleanup(cleanupScope)

			expect(function()
				changed:Fire("Time", 2)
			end).never.to.throw()

			changed:Destroy()
		end)
	end)

	describe("AvatarViewportLoader cache", function()
		it("returns nil for invalid user ids", function()
			expect(AvatarViewportLoader.loadCachedFromUserId(0)).to.equal(nil)
		end)

		it("clears without error when empty", function()
			expect(function()
				AvatarViewportLoader.clearCache()
			end).never.to.throw()
		end)
	end)
end
