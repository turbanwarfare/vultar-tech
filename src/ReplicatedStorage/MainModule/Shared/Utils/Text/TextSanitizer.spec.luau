--!nocheck
--!strict

local TextSanitizer = require(script.Parent.TextSanitizer)

return function()
	describe("TextSanitizer", function()
		describe("escapeRichText", function()
			it("should return empty string for nil or empty input", function()
				expect(TextSanitizer.escapeRichText("")).to.equal("")
			end)

			it("should escape less than symbol", function()
				expect(TextSanitizer.escapeRichText("<")).to.equal("&lt;")
			end)

			it("should escape greater than symbol", function()
				expect(TextSanitizer.escapeRichText(">")).to.equal("&gt;")
			end)

			it("should escape ampersand", function()
				expect(TextSanitizer.escapeRichText("&")).to.equal("&amp;")
			end)

			it("should escape double quotes", function()
				expect(TextSanitizer.escapeRichText('"')).to.equal("&quot;")
			end)

			it("should escape single quotes", function()
				expect(TextSanitizer.escapeRichText("'")).to.equal("&apos;")
			end)

			it("should escape all special characters in a string", function()
				local input = [[<script>alert("test's & more")</script>]]
				local expected = "&lt;script&gt;alert(&quot;test&apos;s &amp; more&quot;)&lt;/script&gt;"
				expect(TextSanitizer.escapeRichText(input)).to.equal(expected)
			end)

			it("should leave normal text unchanged", function()
				expect(TextSanitizer.escapeRichText("Hello World")).to.equal("Hello World")
			end)
		end)

		describe("stripRichTextTags", function()
			it("should return empty string for nil or empty input", function()
				expect(TextSanitizer.stripRichTextTags("")).to.equal("")
			end)

			it("should remove simple tags", function()
				expect(TextSanitizer.stripRichTextTags("<b>bold</b>")).to.equal("bold")
			end)

			it("should remove tags with attributes", function()
				expect(TextSanitizer.stripRichTextTags('<font color="#FF0000">red</font>')).to.equal("red")
			end)

			it("should remove nested tags", function()
				expect(TextSanitizer.stripRichTextTags("<b><i>bold italic</i></b>")).to.equal("bold italic")
			end)

			it("should leave text without tags unchanged", function()
				expect(TextSanitizer.stripRichTextTags("plain text")).to.equal("plain text")
			end)
		end)

		describe("sanitizeForChat", function()
			it("should return empty string for nil or empty input", function()
				expect(TextSanitizer.sanitizeForChat("")).to.equal("")
			end)

			it("should escape HTML special characters", function()
				expect(TextSanitizer.sanitizeForChat("<script>")).to.equal("&lt;script&gt;")
			end)

			it("should not double escape text Roblox already escaped", function()
				expect(TextSanitizer.sanitizeForChat("a &lt; b &gt; c")).to.equal("a &lt; b &gt; c")
				expect(TextSanitizer.sanitizeForChat("&amp;lt;")).to.equal("&amp;lt;")
			end)

			it("should remove control characters", function()
				local input = "hello\0world"
				local result = TextSanitizer.sanitizeForChat(input)
				expect(result:find("\0")).to.equal(nil)
			end)

			it("should preserve normal text", function()
				expect(TextSanitizer.sanitizeForChat("Hello World!")).to.equal("Hello World!")
			end)

			it("should preserve newlines and tabs", function()
				local input = "line1\nline2\ttab"
				local result = TextSanitizer.sanitizeForChat(input)
				expect(result:find("\n")).to.be.ok()
				expect(result:find("\t")).to.be.ok()
			end)
		end)

		describe("sanitizeUsername", function()
			it("should return empty string for nil or empty input", function()
				expect(TextSanitizer.sanitizeUsername("")).to.equal("")
			end)

			it("should escape HTML in usernames", function()
				expect(TextSanitizer.sanitizeUsername("<Admin>")).to.equal("&lt;Admin&gt;")
			end)

			it("should preserve normal usernames", function()
				expect(TextSanitizer.sanitizeUsername("Player123")).to.equal("Player123")
			end)
		end)
	end)
end
