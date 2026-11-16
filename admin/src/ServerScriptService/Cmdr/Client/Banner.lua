local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RICH_TEXT_ESCAPES = { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }

local SLIDE_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0, 70)
local SHOWN_POSITION = UDim2.new(0.5, 0, 0, 110)

local screenGui: ScreenGui? = nil
local current: Frame? = nil

local function getScreenGui(): ScreenGui
	if screenGui and screenGui.Parent then
		return screenGui
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VultarBanner"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui
	return gui
end

local function create(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for property, value in properties do
		instance[property] = value
	end
	return instance
end

local function slideOutAndDestroy(container: Frame)
	if not container.Parent then
		return
	end
	TweenService:Create(container, SLIDE_OUT, { Position = HIDDEN_POSITION }):Play()
	task.delay(SLIDE_OUT.Time + 0.01, container.Destroy, container)
end

local Banner = {}

function Banner.Show(banner: { [string]: any })
	if typeof(banner) ~= "table" or typeof(banner.Title) ~= "string" then
		return
	end

	local icon = if typeof(banner.Icon) == "string" then banner.Icon else "alert"
	local isError = icon == "error"
	local text = if typeof(banner.Text) == "string" then banner.Text else ""
	local countdown = if typeof(banner.Countdown) == "number" then banner.Countdown else nil
	local duration = if typeof(banner.Duration) == "number"
		then banner.Duration
		else math.clamp(math.sqrt(#text) + 2.5, 4, 10)

	if current then
		current:Destroy()
	end

	local container = create("Frame", {
		Name = "VultarBannerAlert",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = HIDDEN_POSITION,
		Size = UDim2.new(0, 360, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 100,
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = container,
	})

	local diamondHolder = create("Frame", {
		Name = "DiamondHolder",
		LayoutOrder = 1,
		Size = UDim2.new(0, 38, 0, 38),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local diamond = create("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 26, 0, 26),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(14, 14, 14),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = diamondHolder,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = diamond })
	create("UIStroke", {
		Color = if isError then Color3.fromRGB(255, 80, 85) else Color3.fromRGB(220, 220, 235),
		Thickness = 1.5,
		Parent = diamond,
	})

	if icon == "avatar" and typeof(banner.UserId) == "number" then
		local avatar = create("ImageLabel", {
			Name = "Avatar",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 20, 0, 20),
			ZIndex = 102,
			BackgroundTransparency = 1,
			Image = `rbxthumb://type=AvatarHeadShot&id={banner.UserId}&w=100&h=100`,
			Parent = diamondHolder,
		})
		create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = avatar })
	else
		create("TextLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.51, -1, 0.5, 0),
			Size = UDim2.new(0, 26, 0, 26),
			ZIndex = 102,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = if isError then Color3.fromRGB(255, 90, 95) else Color3.fromRGB(255, 255, 255),
			Text = "!",
			Parent = diamondHolder,
		})
	end

	local tagBox = create("Frame", {
		Name = "TagBox",
		LayoutOrder = 2,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(12, 12, 14),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = container,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 3), Parent = tagBox })
	create("UIStroke", {
		Color = if isError then Color3.fromRGB(90, 40, 45) else Color3.fromRGB(50, 50, 55),
		Thickness = 1,
		Parent = tagBox,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		Parent = tagBox,
	})
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 1),
		Parent = tagBox,
	})
	create("TextLabel", {
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(0, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = if isError then Color3.fromRGB(255, 110, 115) else Color3.fromRGB(255, 255, 255),
		Text = string.upper(banner.Title),
		Parent = tagBox,
	})
	if typeof(banner.Subtitle) == "string" and banner.Subtitle ~= "" then
		create("TextLabel", {
			Name = "Subtitle",
			LayoutOrder = 2,
			Size = UDim2.new(0, 0, 0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(180, 180, 190),
			Text = string.upper(banner.Subtitle),
			Parent = tagBox,
		})
	end

	container.Parent = getScreenGui()
	current = container
	TweenService:Create(container, SLIDE_IN, { Position = SHOWN_POSITION }):Play()

	if countdown then
		local countdownLabel = create("TextLabel", {
			Name = "CountdownText",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextStrokeTransparency = 0.5,
			Text = tostring(countdown),
			Parent = container,
		})

		local endTime = os.clock() + countdown
		task.spawn(function()
			while container.Parent and os.clock() < endTime do
				countdownLabel.Text = tostring(math.ceil(endTime - os.clock()))
				task.wait(0.05)
			end
			countdownLabel.Text = "0"
			slideOutAndDestroy(container)
		end)
	else
		local message = create("TextLabel", {
			Name = "Message",
			LayoutOrder = 3,
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextStrokeTransparency = 0.5,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextWrapped = true,
			RichText = true,
			Text = (text:gsub("[<>&]", RICH_TEXT_ESCAPES)),
			Parent = container,
		})
		create("UISizeConstraint", { MaxSize = Vector2.new(360, math.huge), Parent = message })

		task.delay(duration, slideOutAndDestroy, container)
	end
end

return Banner
