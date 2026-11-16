--!nocheck
--!strict

return function()
	describe("ChatMessageOrdering", function()
		local function makeMessage(id: string, timestamp: number, channelId: string?): any
			return {
				id = id,
				channelId = channelId or "GLOBAL",
				senderId = 1,
				senderName = "TestUser",
				senderDisplayName = "TestUser",
				content = "msg_" .. id,
				timestamp = timestamp,
				tags = {},
			}
		end

		describe("sorted insert by timestamp", function()
			local function sortedInsert(messages: { any }, message: any): { any }
				local result: { any } = {}
				local inserted = false
				for _, existing in messages do
					if not inserted and existing.timestamp > message.timestamp then
						table.insert(result, message)
						inserted = true
					end
					table.insert(result, existing)
				end
				if not inserted then
					table.insert(result, message)
				end
				return result
			end

			it("should insert at end when timestamp is latest", function()
				local messages = {
					makeMessage("a", 100),
					makeMessage("b", 200),
				}
				local result = sortedInsert(messages, makeMessage("c", 300))
				expect(#result).to.equal(3)
				expect(result[3].id).to.equal("c")
			end)

			it("should insert at beginning when timestamp is earliest", function()
				local messages = {
					makeMessage("a", 200),
					makeMessage("b", 300),
				}
				local result = sortedInsert(messages, makeMessage("c", 100))
				expect(#result).to.equal(3)
				expect(result[1].id).to.equal("c")
			end)

			it("should insert in middle for intermediate timestamp", function()
				local messages = {
					makeMessage("a", 100),
					makeMessage("b", 300),
				}
				local result = sortedInsert(messages, makeMessage("c", 200))
				expect(#result).to.equal(3)
				expect(result[2].id).to.equal("c")
			end)

			it("should place same-timestamp after existing messages", function()
				local messages = {
					makeMessage("a", 100),
					makeMessage("b", 200),
				}
				local result = sortedInsert(messages, makeMessage("c", 200))
				expect(#result).to.equal(3)
				expect(result[2].id).to.equal("b")
				expect(result[3].id).to.equal("c")
			end)

			it("should maintain chronological order after multiple inserts", function()
				local messages: { any } = {}
				messages = sortedInsert(messages, makeMessage("first", 100))
				messages = sortedInsert(messages, makeMessage("third", 300))
				messages = sortedInsert(messages, makeMessage("second", 200))
				messages = sortedInsert(messages, makeMessage("fourth", 400))

				expect(messages[1].id).to.equal("first")
				expect(messages[2].id).to.equal("second")
				expect(messages[3].id).to.equal("third")
				expect(messages[4].id).to.equal("fourth")
			end)

			it("should handle PM arriving after regular message with later timestamp", function()
				local messages: { any } = {}
				messages = sortedInsert(messages, makeMessage("regular1", 100))
				messages = sortedInsert(messages, makeMessage("regular2", 101))
				messages = sortedInsert(messages, makeMessage("pm_confirm", 102))
				messages = sortedInsert(messages, makeMessage("regular3", 103))

				expect(messages[1].id).to.equal("regular1")
				expect(messages[2].id).to.equal("regular2")
				expect(messages[3].id).to.equal("pm_confirm")
				expect(messages[4].id).to.equal("regular3")
			end)
		end)

		describe("orderMap generation", function()
			local function buildOrderMap(messages: { any }): { [string]: number }
				local map: { [string]: number } = {}
				for i, msg in messages do
					map[msg.id] = i
				end
				return map
			end

			it("should assign sequential indices", function()
				local messages = {
					makeMessage("a", 100),
					makeMessage("b", 200),
					makeMessage("c", 300),
				}
				local map = buildOrderMap(messages)
				expect(map["a"]).to.equal(1)
				expect(map["b"]).to.equal(2)
				expect(map["c"]).to.equal(3)
			end)

			it("should update indices when messages shift", function()
				local messages = {
					makeMessage("b", 200),
					makeMessage("c", 300),
					makeMessage("d", 400),
				}
				local map = buildOrderMap(messages)
				expect(map["b"]).to.equal(1)
				expect(map["c"]).to.equal(2)
				expect(map["d"]).to.equal(3)
			end)

			it("should reflect correct order after insert and removal", function()
				local messages = {
					makeMessage("a", 100),
					makeMessage("b", 200),
					makeMessage("pm", 150),
					makeMessage("c", 300),
				}
				table.sort(messages, function(x, y) return x.timestamp < y.timestamp end)

				local map = buildOrderMap(messages)
				expect(map["a"]).to.equal(1)
				expect(map["pm"]).to.equal(2)
				expect(map["b"]).to.equal(3)
				expect(map["c"]).to.equal(4)
			end)

			it("should give PM correct position even after history trim", function()
				local maxHistory = 5
				local allMessages = {
					makeMessage("msg1", 101),
					makeMessage("msg2", 102),
					makeMessage("msg3", 103),
					makeMessage("pm", 103),
					makeMessage("msg4", 104),
					makeMessage("msg5", 105),
					makeMessage("msg6", 106),
				}

				local trimmed: { any } = {}
				local startIdx = #allMessages - maxHistory + 1
				for i = startIdx, #allMessages do
					table.insert(trimmed, allMessages[i])
				end

				local map = buildOrderMap(trimmed)
				local ids: { string } = {}
				for i = 1, #trimmed do
					table.insert(ids, trimmed[i].id)
				end

				for i = 1, #ids - 1 do
					local currentOrder = map[ids[i]]
					local nextOrder = map[ids[i + 1]]
					expect(currentOrder < nextOrder).to.equal(true)
				end
			end)
		end)

		describe("deduplication", function()
			it("should reject duplicate message IDs", function()
				local idSet: { [string]: boolean } = {}
				local messages: { any } = {}

				local function addMessage(msg: any): boolean
					if idSet[msg.id] then
						return false
					end
					idSet[msg.id] = true
					table.insert(messages, msg)
					return true
				end

				expect(addMessage(makeMessage("a", 100))).to.equal(true)
				expect(addMessage(makeMessage("a", 100))).to.equal(false)
				expect(addMessage(makeMessage("b", 200))).to.equal(true)
				expect(#messages).to.equal(2)
			end)
		end)
	end)
end
