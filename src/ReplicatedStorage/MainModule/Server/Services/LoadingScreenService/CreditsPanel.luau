--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Credits = require(MainModule.Shared.Config.Credits)

type FusionScope = Types.FusionScope

type Group = {
	title: string,
	isDirector: boolean,
	members: { Credits.TeamMember },
}

local CreditsPanel = {}

local EDGE_MARGIN = 64
local ROSTER_BOTTOM = 172
local ROSTER_HEIGHT = 268
local TITLE_GAP = 30
local TITLE_SIZE = 28
local GROUP_GAP = 36
local CARD_GAP = 12
local HEADER_HEIGHT = 14
local HEADER_GAP = 10
local CARD_WIDTH = 176
local DIRECTOR_CARD_WIDTH = 240
local CARD_HEIGHT = 240
local CARD_PADDING = 14
local PORTRAIT_HEIGHT = 176
local DIRECTOR_AVATAR_OFFSET = -8
local NAME_SIZE = 14
local STRIPE_TRANSPARENCY = 0.95

local CARD_COLOR = Color3.fromRGB(18, 18, 20)
local MUTED_COLOR = Color3.fromRGB(140, 140, 145)

local GROUP_TITLES: { [string]: string } = {
	Director = "DIRECTOR",
	Scripting = "SCRIPTING",
	Developer = "DEVELOPMENT",
	Former = "FORMER",
}

local SCRIM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.38, 1),
	NumberSequenceKeypoint.new(0.64, 0.3),
	NumberSequenceKeypoint.new(1, 0.08),
})

local function groupTeam(): { Group }
	local groups: { Group } = {}
	local groupsByCategory: { [string]: Group } = {}

	local function getGroup(category: string): Group
		local existing = groupsByCategory[category]
		if existing then
			return existing
		end

		local group: Group = {
			title = GROUP_TITLES[category] or string.upper(category),
			isDirector = category == "Director",
			members = {},
		}
		groupsByCategory[category] = group
		table.insert(groups, group)
		return group
	end

	for _, member in Credits.Team do
		table.insert(getGroup(member.category).members, member)
	end

	return groups
end

local function formatRole(role: string): string
	return (string.gsub(string.upper(role), "%s*/%s*", " / "))
end

local function createCard(scope: FusionScope, member: Credits.TeamMember, width: number, isDirector: boolean): Frame
	local avatarSize = if isDirector then width else PORTRAIT_HEIGHT
	local avatarImage = if isDirector
		then `rbxthumb://type=Avatar&id={member.userId}&w=420&h=420`
		else `rbxthumb://type=AvatarHeadShot&id={member.userId}&w=420&h=420`

	return scope:New("Frame")({
		Name = member.name,
		Size = UDim2.fromOffset(width, CARD_HEIGHT),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Card",
				Size = UDim2.fromOffset(width, CARD_HEIGHT),
				BackgroundColor3 = CARD_COLOR,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = Theme.Radius.XLarge,
					}),

					scope:New("UIStroke")({
						Color = if isDirector then Theme.Border.Active else Theme.Border.Default,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),

					scope:New("Frame")({
						Name = "Portrait",
						Size = UDim2.fromOffset(width, PORTRAIT_HEIGHT + 8),
						BackgroundColor3 = Theme.Section.Background,
						ClipsDescendants = true,
						ZIndex = 2,

						[Fusion.Children] = {
							scope:New("UICorner")({
								CornerRadius = Theme.Radius.XLarge,
							}),

							scope:New("ImageLabel")({
								Name = "Stripes",
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Image = Theme.Patterns.DiagonalStripes.Fat,
								ImageColor3 = Theme.Section.Stripe.Color,
								ImageTransparency = STRIPE_TRANSPARENCY,
								ScaleType = Enum.ScaleType.Tile,
								TileSize = UDim2.fromOffset(Theme.Section.Stripe.TileSize, Theme.Section.Stripe.TileSize),

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = Theme.Radius.XLarge,
									}),
								},
							}),

							scope:New("ImageLabel")({
								Name = "Avatar",
								Size = UDim2.fromOffset(avatarSize, avatarSize),
								Position = UDim2.new(0.5, 0, 0, if isDirector then DIRECTOR_AVATAR_OFFSET else 0),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								Image = avatarImage,
								ScaleType = Enum.ScaleType.Fit,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Cover",
						Size = UDim2.fromOffset(width, 10),
						Position = UDim2.fromOffset(0, PORTRAIT_HEIGHT),
						BackgroundColor3 = CARD_COLOR,
						ZIndex = 3,
					}),

					scope:New("TextLabel")({
						Name = "MemberName",
						Size = UDim2.fromOffset(width - CARD_PADDING * 2, 18),
						Position = UDim2.fromOffset(CARD_PADDING, PORTRAIT_HEIGHT + 12),
						BackgroundTransparency = 1,
						Text = string.upper(member.name),
						TextColor3 = Theme.Foreground.Primary,
						TextSize = NAME_SIZE,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 4,
					}),

					scope:New("TextLabel")({
						Name = "Role",
						Size = UDim2.fromOffset(width - CARD_PADDING * 2, 14),
						Position = UDim2.fromOffset(CARD_PADDING, PORTRAIT_HEIGHT + 33),
						BackgroundTransparency = 1,
						Text = formatRole(member.role),
						TextColor3 = MUTED_COLOR,
						TextSize = Theme.Text.Small,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 4,
					}),
				},
			}),
		},
	})
end

local function createGroup(scope: FusionScope, group: Group, order: number): Frame
	local cardWidth = if group.isDirector then DIRECTOR_CARD_WIDTH else CARD_WIDTH
	local width = cardWidth * #group.members + CARD_GAP * (#group.members - 1)

	local cards: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CARD_GAP),
		}),
	}
	for index, member in group.members do
		local card = createCard(scope, member, cardWidth, group.isDirector)
		card.LayoutOrder = index
		table.insert(cards, card)
	end

	return scope:New("Frame")({
		Name = group.title,
		Size = UDim2.fromOffset(width, ROSTER_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.fromOffset(width, HEADER_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, HEADER_GAP),
					}),

					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.fromOffset(0, HEADER_HEIGHT),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = group.title,
						TextColor3 = MUTED_COLOR,
						TextSize = Theme.Text.XSmall,
						Font = Theme.Text.Bold,
						LayoutOrder = 1,
					}),

					scope:New("Frame")({
						Name = "Line",
						Size = UDim2.fromOffset(0, 1),
						BackgroundColor3 = Theme.Border.Default,
						LayoutOrder = 2,

						[Fusion.Children] = {
							scope:New("UIFlexItem")({
								FlexMode = Enum.UIFlexMode.Fill,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Cards",
				Size = UDim2.fromOffset(width, CARD_HEIGHT),
				Position = UDim2.fromOffset(0, ROSTER_HEIGHT - CARD_HEIGHT),
				BackgroundTransparency = 1,

				[Fusion.Children] = cards,
			}),
		},
	})
end

function CreditsPanel.create(scope: FusionScope): Frame
	local rosterChildren: { Instance } = {
		scope:New("UIScale")({
			Name = "RosterScale",
		}),

		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GROUP_GAP),
		}),
	}

	local rosterWidth = 0
	for index, group in groupTeam() do
		local groupFrame = createGroup(scope, group, index)
		rosterWidth += groupFrame.Size.X.Offset + if index > 1 then GROUP_GAP else 0
		table.insert(rosterChildren, groupFrame)
	end

	return scope:New("Frame")({
		Name = "CreditsOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Black[950],
		Visible = false,
		ZIndex = 8,

		[Fusion.Children] = {
			scope:New("UIGradient")({
				Rotation = 90,
				Transparency = SCRIM_TRANSPARENCY,
			}),

			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.fromOffset(0, 32),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(0, EDGE_MARGIN, 1, -(ROSTER_BOTTOM + ROSTER_HEIGHT + TITLE_GAP)),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Text = "CREDITS",
				TextColor3 = Theme.Foreground.Primary,
				TextSize = TITLE_SIZE,
				Font = Theme.Text.Black,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("Frame")({
				Name = "Roster",
				Size = UDim2.fromOffset(rosterWidth, ROSTER_HEIGHT),
				Position = UDim2.new(0, EDGE_MARGIN, 1, -ROSTER_BOTTOM),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,

				[Fusion.Children] = rosterChildren,
			}),
		},
	})
end

return CreditsPanel
