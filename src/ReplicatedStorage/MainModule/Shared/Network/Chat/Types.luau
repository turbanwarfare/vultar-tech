--!strict
--!native
--!optimize 2

export type ChannelId = "GLOBAL" | "OFFICER" | "HICOM" | "RAID" | "ROYAL" | "DREAD"

export type GlobalFilter = "ALL" | "TEAM"

export type ChannelConfig = {
	id: ChannelId,
	name: string,
	icon: string?,
	color: Color3,
	order: number,
}

export type TagConfig = {
	id: string,
	text: string,
	textColor: Color3,
	backgroundColor: Color3,
	priority: number,
}

export type GradientConfig = {
	colors: { Color3 },
	rotation: number?,
}

export type ChatMessage = {
	id: string,
	channelId: ChannelId,
	senderId: number,
	senderName: string,
	senderDisplayName: string,
	content: string,
	timestamp: number,
	tags: { string },
	nameColor: Color3?,
	rolePrefix: string?,
	roleColor: Color3?,
	isSystem: boolean?,
	isTeamOnly: boolean?,
	senderTeam: string?,
	isWhisper: boolean?,
	whisperTargetId: number?,
	whisperTargetName: string?,
	gradient: GradientConfig?,
}

export type PlayerChatData = {
	visibleChannels: { ChannelId },
	tags: { string },
	nameColor: Color3?,
	rolePrefix: string?,
	roleColor: Color3?,
	isRaidLeader: boolean,
}

export type PlayerMeta = {
	userId: number,
	bubbleEveryone: boolean,
	tags: { string },
	nameColor: Color3?,
	rolePrefix: string?,
	roleColor: Color3?,
	gradient: GradientConfig?,
}

export type SystemMessage = {
	channelId: ChannelId?,
	content: string,
	color: Color3?,
}

return nil
