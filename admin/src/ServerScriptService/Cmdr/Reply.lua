local Reply = {}

Reply.ErrorColor = Color3.fromRGB(255, 73, 73)

function Reply.Error(context, text: string): string
	context:Reply(text, Reply.ErrorColor)
	return ""
end

function Reply.Summary(action: string, done: { string }, skipped: { string }): string
	local lines = {}
	if #done > 0 then
		table.insert(lines, `{action}: {table.concat(done, ", ")}.`)
	end
	if #skipped > 0 then
		table.insert(lines, `Skipped {table.concat(skipped, ", ")}.`)
	end
	if #lines == 0 then
		return "Nobody matched."
	end
	return table.concat(lines, "\n")
end

function Reply.Duration(seconds: number): string
	local parts = {}
	for _, unit in { { "d", 86400 }, { "h", 3600 }, { "m", 60 }, { "s", 1 } } do
		local amount = seconds // unit[2]
		if amount > 0 then
			table.insert(parts, `{amount}{unit[1]}`)
			seconds -= amount * unit[2]
		end
	end
	return table.concat(parts, " ")
end

return Reply
