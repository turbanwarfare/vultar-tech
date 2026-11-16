--!strict
--!native
--!optimize 2

local Theme = {}

Theme.Colors = {
	White = Color3.fromRGB(255, 255, 255),
	Transparent = Color3.fromRGB(0, 0, 0),

	Success = Color3.fromRGB(0, 122, 85),
	SuccessHover = Color3.fromRGB(0, 140, 98),
	SuccessMuted = Color3.fromRGB(0, 102, 71),

	Warning = Color3.fromRGB(255, 165, 0),
	WarningHover = Color3.fromRGB(255, 180, 40),
	WarningMuted = Color3.fromRGB(220, 140, 0),

	Destructive = Color3.fromRGB(255, 100, 103),
	DestructiveHover = Color3.fromRGB(255, 120, 122),
	DestructiveMuted = Color3.fromRGB(220, 85, 88),

	Silver = Color3.fromRGB(192, 192, 210),
	SilverBright = Color3.fromRGB(220, 220, 235),
	SilverMuted = Color3.fromRGB(140, 140, 160),

	Black = {
		[950] = Color3.fromRGB(0, 0, 0),
		[900] = Color3.fromRGB(8, 8, 8),
		[850] = Color3.fromRGB(14, 14, 14),
		[800] = Color3.fromRGB(20, 20, 20),
		[750] = Color3.fromRGB(26, 26, 26),
		[700] = Color3.fromRGB(32, 32, 32),
		[650] = Color3.fromRGB(40, 40, 40),
		[600] = Color3.fromRGB(48, 48, 48),
		[550] = Color3.fromRGB(56, 56, 56),
		[500] = Color3.fromRGB(65, 65, 65),
		[450] = Color3.fromRGB(75, 75, 75),
		[400] = Color3.fromRGB(90, 90, 90),
		[300] = Color3.fromRGB(120, 120, 120),
		[200] = Color3.fromRGB(170, 170, 170),
		[100] = Color3.fromRGB(210, 210, 210),
		[50] = Color3.fromRGB(240, 240, 240),
	},

	Gray = {
		[950] = Color3.fromRGB(0, 0, 0),
		[900] = Color3.fromRGB(8, 8, 8),
		[850] = Color3.fromRGB(14, 14, 14),
		[800] = Color3.fromRGB(20, 20, 20),
		[750] = Color3.fromRGB(26, 26, 26),
		[700] = Color3.fromRGB(32, 32, 32),
		[650] = Color3.fromRGB(40, 40, 40),
		[600] = Color3.fromRGB(48, 48, 48),
		[550] = Color3.fromRGB(56, 56, 56),
		[500] = Color3.fromRGB(65, 65, 65),
		[450] = Color3.fromRGB(75, 75, 75),
		[400] = Color3.fromRGB(90, 90, 90),
		[300] = Color3.fromRGB(120, 120, 120),
		[200] = Color3.fromRGB(170, 170, 170),
		[100] = Color3.fromRGB(210, 210, 210),
		[50] = Color3.fromRGB(240, 240, 240),
	},
}

Theme.Transparency = {
	Solid = 0,
	Subtle = 0.05,
	Light = 0.15,
	ChatWindow = 0.35,
	Medium = 0.25,
	Heavy = 0.4,
	VeryHeavy = 0.6,
	Overlay = 0.7,
	Ghost = 0.85,
	Invisible = 1,
}

Theme.Background = {
	Base = Theme.Colors.Black[950],
	Primary = Theme.Colors.Black[900],
	Secondary = Theme.Colors.Black[850],
	Tertiary = Theme.Colors.Black[800],
	Elevated = Theme.Colors.Black[750],
	Overlay = Theme.Colors.Black[700],
	Accent = Theme.Colors.Black[650],
}

Theme.Foreground = {
	Primary = Theme.Colors.White,
	Secondary = Theme.Colors.Black[100],
	Tertiary = Theme.Colors.Black[200],
	Muted = Theme.Colors.Black[300],
	Subtle = Theme.Colors.Black[400],
	Disabled = Theme.Colors.Black[500],
}

Theme.Border = {
	Subtle = Theme.Colors.Black[800],
	Default = Color3.fromRGB(75, 73, 75),
	Active = Color3.fromRGB(240, 240, 240),
	Strong = Theme.Colors.Black[600],
	Accent = Color3.fromRGB(60, 58, 60),
	Visible = Theme.Colors.Black[500],
	Silver = Theme.Colors.Silver,
	SilverBright = Theme.Colors.SilverBright,
}

Theme.Stroke = {
	Subtle = 0.7,
	Default = 0.5,
	Strong = 0.3,
	Visible = 0.15,
	Solid = 0,
}

Theme.Radius = {
	None = UDim.new(0, 0),
	Small = UDim.new(0, 2),
	Medium = UDim.new(0, 4),
	Large = UDim.new(0, 6),
	XLarge = UDim.new(0, 8),
	Full = UDim.new(0.5, 0),
}

Theme.Spacing = {
	None = 0,
	XSmall = 4,
	Small = 8,
	Medium = 12,
	Large = 16,
	XLarge = 20,
	XXLarge = 24,
	Huge = 32,
}

Theme.Text = {
	XSmall = 10,
	Small = 11,
	Medium = 13,
	Large = 15,
	XLarge = 17,
	XXLarge = 20,
	Title = 24,
	Display = 32,
	Hero = 42,

	Regular = Enum.Font.Gotham,
	Semibold = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
}

Theme.Blur = {
	None = 0,
	Subtle = 6,
	Light = 12,
	Medium = 18,
	Strong = 24,
	Heavy = 32,
}

Theme.Spring = {
	Responsive = { Speed = 28, Damping = 1.2 },
	Snappy = { Speed = 25, Damping = 1.2 },
	Default = { Speed = 22, Damping = 1.2 },
	Gentle = { Speed = 18, Damping = 1.2 },
	Slow = { Speed = 14, Damping = 1.2 },
	Linear = { Speed = 20, Damping = 1.5 },
	Bouncy = { Speed = 20, Damping = 0.7 },
}

Theme.Tween = {
	Quick = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Default = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	Slow = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

Theme.ZIndex = {
	Base = 1,
	Dropdown = 10,
	Modal = 100,
	Overlay = 1000,
	Toast = 10000,
}

Theme.Chat = {
	Window = {
		Background = Theme.Colors.Black[900],
		BackgroundTransparency = Theme.Transparency.ChatWindow,
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
	Input = {
		Background = Theme.Colors.Black[850],
		BackgroundFocused = Theme.Colors.Black[800],
		BackgroundTransparency = Theme.Transparency.ChatWindow,
		BackgroundFocusedTransparency = 0.2,
		Border = Theme.Border.Default,
		BorderFocused = Theme.Border.Active,
		BorderTransparency = 0,
		BorderFocusedTransparency = 0,
		Placeholder = Theme.Colors.Black[400],
		Text = Theme.Colors.Black[100],
		Cursor = Theme.Colors.Black[100],
	},
	Name = {
		Default = Color3.fromRGB(200, 200, 205),
	},
	Tab = {
		Background = Theme.Colors.Black[850],
		BackgroundSelected = Theme.Colors.Black[800],
		BackgroundHover = Theme.Colors.Black[750],
		BackgroundTransparency = Theme.Transparency.ChatWindow,
		BackgroundSelectedTransparency = 0.2,
		Border = Theme.Border.Default,
		BorderSelected = Theme.Border.Active,
		BorderHover = Theme.Border.Default,
		BorderTransparency = 0,
		BorderSelectedTransparency = 0,
		Text = Theme.Colors.Black[300],
		TextSelected = Theme.Colors.White,
		TextHover = Theme.Colors.Black[100],
	},
	Message = {
		Text = Theme.Colors.Black[100],
		SystemText = Color3.fromRGB(255, 230, 100),
		MentionHex = "FFDD44",
		TeamPrefixHex = "66BBFF",
		WhisperHex = "D8A0FF",
	},
	Channel = {
		Background = Theme.Colors.Black[850],
		BackgroundSelected = Theme.Colors.Black[800],
		BackgroundHover = Theme.Colors.Black[750],
		BackgroundTransparency = Theme.Transparency.ChatWindow,
		BackgroundSelectedTransparency = 0.2,
		Border = Theme.Border.Default,
		BorderSelected = Theme.Border.Active,
		BorderHover = Theme.Border.Default,
		BorderTransparency = 0,
		BorderSelectedTransparency = 0,
		Text = Theme.Colors.Black[300],
		TextSelected = Theme.Colors.White,
		TextHover = Theme.Colors.Black[100],
	},
	Bubble = {
		Background = Theme.Colors.Black[900],
		BackgroundTransparency = 0.1,
		Border = Theme.Border.Default,
		Text = Theme.Colors.White,
	},
	MicButton = {
		Background = Theme.Colors.Black[900],
		BackgroundHover = Theme.Colors.Black[750],
		BackgroundTransparency = 0.2,
		Border = Theme.Border.Default,
		Icon = Theme.Colors.Black[100],
	},
	Tooltip = {
		Background = Theme.Colors.Black[800],
		BackgroundTransparency = 0.05,
		Border = Theme.Border.Default,
		Text = Theme.Colors.Black[200],
	},
}

Theme.Navbar = {
	Background = Theme.Colors.Black[850],
	BackgroundTransparency = Theme.Transparency.Light,
	Border = Theme.Border.Default,
	BorderTransparency = 0,
	Tab = {
		Background = Theme.Colors.Black[850],
		BackgroundSelected = Theme.Colors.SilverBright,
		BackgroundHover = Theme.Colors.Black[700],
		BackgroundTransparency = 1,
		BackgroundSelectedTransparency = 0,
		BackgroundHoverTransparency = 0.5,
		Text = Theme.Colors.Black[100],
		TextSelected = Theme.Colors.Black[950],
		TextHover = Theme.Colors.White,
	},
}

Theme.TopBar = {
	Background = Color3.fromRGB(13, 13, 13),
	BackgroundTransparency = 0,
	Height = 70,
	Tab = {
		Text = Color3.fromRGB(140, 140, 145),
		TextSelected = Color3.fromRGB(255, 255, 255),
		TextHover = Color3.fromRGB(200, 200, 205),
		TextSize = 16,
		Accent = Color3.fromRGB(255, 140, 0),
		AccentHeight = 4,
		AccentRadius = UDim.new(1, 0),
		AccentBottomOffset = 18,
	},
}

Theme.MenuBackground = {
	Background = Color3.fromRGB(18, 18, 21),
	BackgroundTransparency = 0,
	Pattern = "rbxassetid://0",
	PatternTransparency = 0.96,
	PatternColor = Theme.Colors.SilverBright,
	PatternTileSize = 1024,
}

Theme.Patterns = {
	DiagonalStripes = {
		Thin = "rbxassetid://140384357197755",
		Fat = "rbxassetid://76930192397001",
	},
}

Theme.Store = {
	Title = {
		Text = Theme.Colors.White,
		Size = 48,
		Font = Enum.Font.GothamBlack,
	},
	Tab = {
		Text = Color3.fromRGB(100, 100, 105),
		TextSelected = Theme.Colors.White,
		TextHover = Color3.fromRGB(180, 180, 185),
		TextSize = 14,
		Accent = Color3.fromRGB(255, 140, 0),
		AccentHeight = 3,
		AccentRadius = UDim.new(1, 0),
	},
}

Theme.Settings = {
	Title = {
		Text = Theme.Colors.White,
		Size = 48,
		Font = Enum.Font.GothamBlack,
	},
	SearchBar = {
		Background = Theme.Colors.Black[850],
		BackgroundTransparency = 0.15,
		Border = Theme.Border.Default,
		BorderTransparency = Theme.Stroke.Strong,
		Placeholder = Theme.Colors.Black[400],
		Text = Theme.Colors.Black[100],
		Icon = Theme.Colors.Black[400],
		Width = 400,
		Height = 36,
	},
	Preview = {
		LabelTitle = Color3.fromRGB(90, 90, 95),
		LabelTitleSize = 10,
		LabelSubtitle = Color3.fromRGB(200, 200, 205),
		LabelSubtitleSize = 15,
		Height = 550,
		DividerHeight = 40,
	},
	Sidebar = {
		Width = 140,
		ItemHeight = 34,
		ItemGap = 3,
		Background = Color3.fromRGB(30, 30, 34),
		BackgroundTransparency = 0.5,
		ItemBackground = Color3.fromRGB(45, 45, 50),
		ItemBackgroundSelected = Color3.fromRGB(35, 35, 40),
		ItemText = Color3.fromRGB(140, 140, 150),
		ItemTextHover = Color3.fromRGB(200, 200, 210),
		ItemTextSelected = Theme.Colors.White,
		Accent = Color3.fromRGB(255, 140, 0),
		PreviewAccent = Color3.fromRGB(100, 180, 255),
	},
	ContentWidth = 880,
}

Theme.Inventory = {
	Title = {
		Text = Theme.Colors.White,
		Size = 54,
		Font = Enum.Font.GothamBlack,
	},
	SkinCard = {
		Background = Color3.fromRGB(28, 28, 32),
		BackgroundHover = Color3.fromRGB(38, 38, 42),
		Border = Color3.fromRGB(50, 50, 55),
		BorderHover = Color3.fromRGB(70, 70, 75),
		BorderEquipped = Color3.fromRGB(255, 140, 0),
		NameBackground = Color3.fromRGB(0, 0, 0),
		NameBackgroundTransparency = 0.4,
		NameText = Theme.Colors.White,
		NameTextSize = 13,
		CornerRadius = UDim.new(0, 8),
		AspectRatio = 16 / 9,
		Padding = 8,
		ColumnsPerRow = 4,
	},
	Preview = {
		Background = Color3.fromRGB(20, 20, 24),
		Border = Color3.fromRGB(45, 45, 50),
		TitleText = Color3.fromRGB(120, 120, 125),
		TitleSize = 12,
		Height = 200,
	},
	CategoryTab = {
		Text = Theme.Colors.White,
		TextSelected = Color3.fromRGB(255, 140, 0),
		TextHover = Color3.fromRGB(255, 200, 150),
		TextSize = 20,
		Accent = Color3.fromRGB(255, 140, 0),
		AccentHeight = 3,
		AccentRadius = UDim.new(1, 0),
		AccentBottomOffset = 2,
		PaddingRight = 24,
	},
	GunTab = {
		Text = Color3.fromRGB(120, 120, 125),
		TextSelected = Theme.Colors.White,
		TextHover = Color3.fromRGB(200, 200, 205),
		TextSize = 12,
		Accent = Color3.fromRGB(255, 140, 0),
		AccentHeight = 2,
		AccentRadius = UDim.new(1, 0),
		AccentBottomOffset = 1,
		PaddingRight = 14,
	},
	Faction = {
		Vultarian = Color3.fromRGB(180, 70, 70),
		Hostile = Color3.fromRGB(70, 130, 180),
		LabelSize = 10,
	},
	Divider = Color3.fromRGB(50, 50, 55),
	Slot = {
		Background = Theme.Colors.Black[800],
		BackgroundHover = Theme.Colors.Black[700],
		BackgroundEquipped = Theme.Colors.Black[650],
		BackgroundTransparency = Theme.Transparency.Light,
		Border = Theme.Border.Default,
		BorderHover = Theme.Border.Default,
		BorderEquipped = Theme.Border.Active,
		BorderTransparency = 0,
		BorderHoverTransparency = 0,
		BorderEquippedTransparency = 0,
		Text = Theme.Colors.White,
		TextTransparency = 0.35,
		SlotNumber = Theme.Colors.White,
		SlotNumberTransparency = 0.35,
	},
}

Theme.Button = {
	Primary = {
		Background = Theme.Colors.Success,
		BackgroundHover = Theme.Colors.SuccessHover,
		Foreground = Theme.Colors.White,
		Border = Theme.Colors.Success,
	},
	Secondary = {
		Background = Theme.Colors.Black[700],
		BackgroundHover = Theme.Colors.Black[650],
		Foreground = Theme.Colors.Black[100],
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
	Destructive = {
		Background = Theme.Colors.Destructive,
		BackgroundHover = Theme.Colors.DestructiveHover,
		Foreground = Theme.Colors.White,
		Border = Theme.Colors.Destructive,
	},
	Ghost = {
		Background = Theme.Colors.Transparent,
		BackgroundHover = Theme.Colors.Black[750],
		Foreground = Theme.Colors.Black[200],
		Border = Theme.Colors.Transparent,
	},
	Outline = {
		Background = Theme.Colors.Transparent,
		BackgroundHover = Theme.Colors.Black[800],
		Foreground = Theme.Colors.Black[200],
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
}

Theme.Row = {
	Background = Theme.Colors.Black[800],
	BackgroundTransparency = 0.25,
	Border = Theme.Border.Default,
	BorderTransparency = 0,
}

Theme.Toggle = {
	On = {
		Background = Theme.Colors.Success,
		BackgroundHover = Theme.Colors.SuccessHover,
	},
	Off = {
		Background = Theme.Colors.Destructive,
		BackgroundHover = Theme.Colors.DestructiveHover,
	},
}

Theme.Input = {
	Background = Theme.Colors.Black[800],
	BackgroundFocused = Theme.Colors.Black[750],
	BackgroundTransparency = Theme.Transparency.Light,
	BackgroundFocusedTransparency = 0.08,
	Border = Theme.Border.Default,
	BorderFocused = Theme.Border.Active,
	BorderTransparency = 0,
	BorderFocusedTransparency = 0,
	Placeholder = Theme.Colors.Black[400],
	Text = Theme.Colors.Black[100],
}

Theme.Card = {
	Background = Theme.Colors.Black[850],
	BackgroundTransparency = Theme.Transparency.Light,
	BackgroundElevated = Theme.Colors.Black[800],
	Border = Theme.Border.Default,
	Header = Theme.Colors.Black[900],
}

Theme.Modal = {
	Overlay = Theme.Colors.Black[950],
	OverlayTransparency = 0.3,
	Background = Theme.Colors.Black[850],
	BackgroundTransparency = Theme.Transparency.Subtle,
	Border = Theme.Border.Default,
	Header = Theme.Colors.Black[900],
	HeaderTransparency = 0,
}

Theme.Scrollbar = {
	Track = Theme.Colors.Transparent,
	Thumb = Theme.Colors.Black[650],
}

Theme.Radial = {
	Segment = Theme.Colors.Black[800],
	SegmentHover = Theme.Colors.Black[700],
	SegmentSelected = Theme.Colors.Black[650],
	Border = Theme.Border.Default,
	Center = Theme.Colors.Black[900],
}

Theme.Progress = {
	Background = Theme.Colors.Black[900],
	BackgroundTransparency = 0.3,
	Border = Theme.Border.Default,
	BorderTransparency = 0,
	Bar = Theme.Colors.White,
}

Theme.Section = {
	Background = Color3.fromRGB(35, 35, 40),
	BackgroundTransparency = 0,
	Text = Theme.Colors.White,
	Divider = Theme.Colors.SilverMuted,
	Stripe = {
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.88,
		TileSize = 48,
	},
}

Theme.Shop = {
	Header = {
		Background = Theme.Colors.Black[900],
		BackgroundTransparency = 0.2,
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
	Card = {
		Background = Theme.Colors.Black[850],
		BackgroundTransparency = 0.15,
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
	Button = {
		Background = Theme.Colors.Black[800],
		BackgroundTransparency = 0.2,
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
}

Theme.Leaderboard = {
	Panel = {
		Background = Theme.Colors.Black[900],
		BackgroundTransparency = 0.35,
		Border = Theme.Border.Default,
		BorderTransparency = 0,
	},
	Header = {
		Background = Theme.Colors.Black[950],
		BackgroundTransparency = 0.15,
		Border = Theme.Border.Default,
		Text = Theme.Colors.White,
		TextMuted = Theme.Colors.Black[300],
	},
	SubHeader = {
		Background = Theme.Colors.Black[900],
		BackgroundTransparency = 0.25,
		Text = Color3.fromRGB(180, 140, 50),
		StatLabel = Theme.Colors.Black[300],
		StatValue = Theme.Colors.White,
	},
	Row = {
		Background = Theme.Colors.Transparent,
		BackgroundHover = Theme.Colors.Black[800],
		BackgroundSelf = Color3.fromRGB(140, 45, 45),
		BackgroundSelfTransparency = 0.4,
		Text = Theme.Colors.White,
		TextMuted = Theme.Colors.Black[200],
		Divider = Theme.Border.Default,
	},
	Defenders = {
		Accent = Color3.fromRGB(140, 40, 40),
		AccentBright = Color3.fromRGB(180, 60, 60),
		Text = Color3.fromRGB(255, 200, 80),
	},
	Raiders = {
		Accent = Color3.fromRGB(50, 100, 180),
		AccentBright = Color3.fromRGB(70, 130, 220),
		Text = Color3.fromRGB(255, 200, 80),
	},
}

Theme.HighlightColors = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 230, 50),
	Color3.fromRGB(255, 50, 50),
	Color3.fromRGB(50, 255, 100),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(50, 150, 255),
}

Theme.GunHUD = {
	OuterFrame = {
		Background = Color3.fromRGB(70, 75, 85),
		BackgroundTransparency = 0.08,
	},
	InnerFrame = {
		Background = Color3.fromRGB(35, 40, 50),
		BackgroundTransparency = 0.05,
	},
	AmmoBar = {
		Background = Color3.fromRGB(50, 55, 65),
		BackgroundTransparency = 0.3,
		Fill = Theme.Colors.White,
		FillTransparency = 0.05,
		FillLow = Theme.Colors.Destructive,
	},
	Text = {
		Primary = Theme.Colors.White,
		Secondary = Color3.fromRGB(130, 135, 150),
		Muted = Theme.Colors.Black[400],
		Low = Theme.Colors.Destructive,
	},
	Divider = {
		Color = Color3.fromRGB(70, 75, 85),
		Transparency = 0.5,
	},
	Size = {
		Width = 320,
		Height = 90,
		AmmoBarHeight = 10,
		OuterInset = 6,
		Padding = 20,
		CornerCut = 25,
		LeftAngle = 20,
	},
}

Theme.Lobby = {
	Background = Theme.Colors.Black[900],
	CardBackground = Theme.Colors.Black[800],
	SlotBackground = Theme.Colors.Black[700],
	AccentColor = Color3.fromRGB(0, 120, 255),
	AccentHover = Color3.fromRGB(30, 145, 255),
	ButtonText = Theme.Colors.White,
	HeaderText = Theme.Colors.White,
	MutedText = Theme.Colors.Black[300],
}

Theme.Gold = Color3.fromRGB(255, 215, 0)
Theme.Silver = Color3.fromRGB(192, 192, 192)
Theme.Bronze = Color3.fromRGB(205, 127, 50)

local function deepFreeze(t: { [any]: any }): { [any]: any }
	for key, value in t do
		if type(value) == "table" then
			t[key] = deepFreeze(value)
		end
	end
	return table.freeze(t)
end

return deepFreeze(Theme) :: typeof(Theme)
