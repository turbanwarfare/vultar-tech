--!nocheck
return function()
	local ChatConfig = require(script.Parent.ChatConfig)

	describe("ChatConfig", function()
		describe("Channels", function()
			it("should have channels array", function()
				expect(ChatConfig.Channels).to.be.ok()
				expect(typeof(ChatConfig.Channels)).to.equal("table")
				expect(#ChatConfig.Channels > 0).to.equal(true)
			end)

			it("should have valid structure for each channel", function()
				for _, channel in ChatConfig.Channels do
					expect(channel.id).to.be.ok()
					expect(typeof(channel.id)).to.equal("string")
					expect(channel.name).to.be.ok()
					expect(typeof(channel.name)).to.equal("string")
					expect(channel.icon).to.be.ok()
					expect(typeof(channel.order)).to.equal("number")
				end
			end)

			it("should have GLOBAL channel", function()
				local found = false
				for _, channel in ChatConfig.Channels do
					if channel.id == "GLOBAL" then
						found = true
						break
					end
				end
				expect(found).to.equal(true)
			end)
		end)

		describe("ChannelRequirements", function()
			it("should have requirements for each channel", function()
				for _, channel in ChatConfig.Channels do
					expect(ChatConfig.ChannelRequirements[channel.id]).to.be.ok()
				end
			end)

			it("should have type field for each requirement", function()
				for channelId, requirement in ChatConfig.ChannelRequirements do
					expect(requirement.type).to.be.ok()
					expect(typeof(requirement.type)).to.equal("string")
				end
			end)
		end)

		describe("Roles", function()
			it("should have roles array", function()
				expect(ChatConfig.Roles).to.be.ok()
				expect(typeof(ChatConfig.Roles)).to.equal("table")
			end)

			it("should have valid structure for each role", function()
				for _, role in ChatConfig.Roles do
					expect(role.groupId).to.be.ok()
					expect(typeof(role.groupId)).to.equal("number")
					expect(role.name).to.be.ok()
					expect(typeof(role.name)).to.equal("string")
					expect(role.prefix).to.be.ok()
					expect(role.color).to.be.ok()
					expect(typeof(role.rank)).to.equal("number")
				end
			end)
		end)

		describe("Tags", function()
			it("should have tags array", function()
				expect(ChatConfig.Tags).to.be.ok()
				expect(typeof(ChatConfig.Tags)).to.equal("table")
			end)

			it("should have valid structure for each tag", function()
				for _, tag in ChatConfig.Tags do
					expect(tag.id).to.be.ok()
					local hasText = tag.text ~= nil
					local hasIcon = tag.icon ~= nil
					expect(hasText or hasIcon).to.equal(true)
					expect(typeof(tag.priority)).to.equal("number")
					expect(tag.requirement).to.be.ok()
				end
			end)
		end)

		describe("getTagConfig", function()
			it("should return config for valid tag id", function()
				local firstTag = ChatConfig.Tags[1]
				if firstTag then
					local config = ChatConfig.getTagConfig(firstTag.id)
					expect(config).to.be.ok()
					expect(config.text).to.equal(firstTag.text)
				end
			end)

			it("should return nil for invalid tag id", function()
				local config = ChatConfig.getTagConfig("INVALID_TAG_ID_12345")
				expect(config).to.equal(nil)
			end)
		end)

		describe("getChannelConfig", function()
			it("should return config for valid channel id", function()
				local config = ChatConfig.getChannelConfig("GLOBAL")
				expect(config).to.be.ok()
				expect(config.name).to.equal("GLOBAL")
			end)

			it("should return nil for invalid channel id", function()
				local config = ChatConfig.getChannelConfig("INVALID_CHANNEL_12345")
				expect(config).to.equal(nil)
			end)
		end)

		describe("getChannelIdFromCommand", function()
			it("should return channel id for valid command", function()
				local channelId = ChatConfig.getChannelIdFromCommand("global")
				expect(channelId).to.equal("GLOBAL")
			end)

			it("should handle shorthand commands", function()
				local channelId = ChatConfig.getChannelIdFromCommand("g")
				expect(channelId).to.equal("GLOBAL")
			end)

			it("should be case insensitive", function()
				local lower = ChatConfig.getChannelIdFromCommand("global")
				local upper = ChatConfig.getChannelIdFromCommand("GLOBAL")
				expect(lower).to.equal(upper)
			end)

			it("should return nil for invalid command", function()
				local channelId = ChatConfig.getChannelIdFromCommand("invalidcommand12345")
				expect(channelId).to.equal(nil)
			end)
		end)

		describe("Settings", function()
			it("should have settings table", function()
				expect(ChatConfig.Settings).to.be.ok()
			end)

			it("should have maxMessageLength", function()
				expect(ChatConfig.Settings.maxMessageLength).to.be.ok()
				expect(typeof(ChatConfig.Settings.maxMessageLength)).to.equal("number")
			end)

			it("should have rate limit settings", function()
				expect(ChatConfig.Settings.rateLimitMessages).to.be.ok()
				expect(ChatConfig.Settings.rateLimitWindow).to.be.ok()
			end)
		end)
	end)
end
