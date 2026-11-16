local Players = game:GetService("Players")

local Cmdr = require(script.Parent.Library)

export type Banner = {
	Title: string,
	Subtitle: string?,
	Text: string?,
	Icon: ("alert" | "avatar" | "error")?,
	UserId: number?,
	Countdown: number?,
	Duration: number?,
}

local Notify = {}

function Notify.Banner(player: Player, banner: Banner)
	if player.Parent == Players then
		Cmdr.Dispatcher:SendEvent(player, "Banner", banner)
	end
end

function Notify.Alert(player: Player, text: string)
	Notify.Banner(player, { Title = "Notification", Subtitle = "System Alert", Text = text, Icon = "alert" })
end

return Notify
