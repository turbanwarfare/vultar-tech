--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local Network = require(MainModule.Shared.Network)

type FusionScope = Types.FusionScope
type FusionValue<T> = Types.FusionValue<T>
type FusionCanBeState<T> = Types.FusionCanBeState<T>
type FusionUseFn = Types.FusionUseFn

local peek: <T>(state: FusionCanBeState<T>) -> T = Fusion.peek

export type SettingsSharingProps = {
	Visible: FusionCanBeState<boolean>,
	OnClose: (() -> ())?,
	OnImportSuccess: ((any) -> ())?,
}

local MODAL_WIDTH = 520
local MODAL_HEIGHT = 340
local PANEL_GAP = 16

local function SettingsSharing(scope: FusionScope, props: SettingsSharingProps): Frame
	local exportCode = scope:Value("")
	local importCode = scope:Value("")
	local exportStatus = scope:Value("")
	local importStatus = scope:Value("")
	local isExporting = scope:Value(false)
	local isImporting = scope:Value(false)

	local modalVisible = scope:Computed(function(use: FusionUseFn)
		return use(props.Visible)
	end)

	local backgroundTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and 0.25 or 1
		end),
		Theme.Spring.Default.Speed,
		Theme.Spring.Default.Damping
	)

	local modalScale = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and 1 or 0.95
		end),
		Theme.Spring.Gentle.Speed,
		Theme.Spring.Gentle.Damping
	)

	local modalTransparency = scope:Spring(
		scope:Computed(function(use: FusionUseFn)
			return use(modalVisible) and 0 or 1
		end),
		Theme.Spring.Gentle.Speed,
		Theme.Spring.Gentle.Damping
	)

	scope:Observer(props.Visible):onChange(function()
		local visible = peek(props.Visible)
		if visible then
			exportCode:set("")
			importCode:set("")
			exportStatus:set("")
			importStatus:set("")
			isExporting:set(false)
			isImporting:set(false)
		end
	end)

	local function handleExport()
		if peek(isExporting) then return end

		isExporting:set(true)
		exportStatus:set("Generating...")

		task.spawn(function()			local result = Network.Settings.exportSettings()
			if result.success and result.code then
				exportCode:set(result.code)
				exportStatus:set("Select and copy the code above")
			else
				exportStatus:set("Failed to generate")
			end
			isExporting:set(false)
		end)
	end

	local function handleImport()
		local code = peek(importCode)
		if code == "" then
			importStatus:set("Enter a code first")
			return
		end

		if peek(isImporting) then return end

		isImporting:set(true)
		importStatus:set("Importing...")

		task.spawn(function()			local result = Network.Settings.importSettings(code)
			if result.success and result.settings then
				importStatus:set("Success!")
				if props.OnImportSuccess then
					props.OnImportSuccess(result.settings)
				end
				task.delay(1.5, function()
					if props.OnClose then
						props.OnClose()
					end
				end)
			else
				importStatus:set(result.error or "Invalid code")
			end
			isImporting:set(false)
		end)
	end

	local closeHovered = scope:Value(false)

	local function createActionButton(text: string, color: Color3, onClick: () -> (), loading: FusionCanBeState<boolean>): Frame
		local isHovered = scope:Value(false)

		local bgColor = scope:Spring(
			scope:Computed(function(use: FusionUseFn)
				if use(loading) then return Color3.fromRGB(60, 60, 65) end
				return if use(isHovered) then color else Color3.new(color.R * 0.8, color.G * 0.8, color.B * 0.8)
			end),
			Theme.Spring.Snappy.Speed,
			Theme.Spring.Snappy.Damping
		)

		return scope:New("Frame")({
			Name = text,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = bgColor,
			BorderSizePixel = 0,
			ClipsDescendants = true,

			[Fusion.Children] = {
				scope:New("UICorner")({
					CornerRadius = UDim.new(0, 4),
				}),

				scope:New("ImageLabel")({
					Name = "Stripes",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = Theme.Patterns.DiagonalStripes.Fat,
					ImageColor3 = color,
					ImageTransparency = 0.85,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromOffset(32, 32),
					ZIndex = 1,
				}),

				scope:New("TextLabel")({
					Name = "Label",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use: FusionUseFn)
						return if use(loading) then "..." else text
					end),
					TextColor3 = Theme.Colors.White,
					TextSize = 12,
					Font = Theme.Text.Bold,
					ZIndex = 2,
				}),

				scope:New("TextButton")({
					Name = "Hitbox",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 10,

					[Fusion.OnEvent("MouseEnter")] = function()
						isHovered:set(true)
					end,

					[Fusion.OnEvent("MouseLeave")] = function()
						isHovered:set(false)
					end,

					[Fusion.OnEvent("Activated")] = onClick,
				}),
			},
		})
	end

	return scope:New("Frame")({
		Name = "SettingsSharingModalContainer",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZIndex.Modal,
		Visible = modalVisible,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Black[950],
				BackgroundTransparency = backgroundTransparency,
				BorderSizePixel = 0,
				ZIndex = Theme.ZIndex.Modal,

				[Fusion.Children] = {
					scope:New("TextButton")({
						Name = "OverlayHitbox",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 1,

						[Fusion.OnEvent("Activated")] = function()
							if props.OnClose then
								props.OnClose()
							end
						end,
					}),
				},
			}),

			scope:New("CanvasGroup")({
				Name = "ModalContainer",
				Size = UDim2.fromOffset(MODAL_WIDTH, MODAL_HEIGHT),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(22, 22, 26),
				BorderSizePixel = 0,
				ZIndex = Theme.ZIndex.Modal + 1,
				GroupTransparency = modalTransparency,

				[Fusion.Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 8),
					}),

					scope:New("UIStroke")({
						Color = Color3.fromRGB(50, 50, 55),
						Thickness = 1,
					}),

					scope:New("UIScale")({
						Scale = modalScale,
					}),

					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 52),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("TextLabel")({
								Name = "Title",
								Size = UDim2.new(1, -60, 0, 32),
								Position = UDim2.fromOffset(20, 14),
								BackgroundTransparency = 1,
								Text = "SHARE SETTINGS",
								TextColor3 = Theme.Colors.White,
								TextSize = 18,
								Font = Enum.Font.GothamBlack,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = Theme.ZIndex.Modal + 3,
							}),

							scope:New("TextButton")({
								Name = "CloseButton",
								Size = UDim2.fromOffset(32, 32),
								Position = UDim2.new(1, -14, 0, 12),
								AnchorPoint = Vector2.new(1, 0),
								BackgroundColor3 = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(closeHovered) then Color3.fromRGB(60, 60, 65) else Color3.fromRGB(40, 40, 45)
									end),
									Theme.Spring.Snappy.Speed,
									Theme.Spring.Snappy.Damping
								),
								BorderSizePixel = 0,
								Text = "X",
								TextColor3 = scope:Spring(
									scope:Computed(function(use: FusionUseFn)
										return if use(closeHovered) then Theme.Colors.Destructive else Color3.fromRGB(120, 120, 125)
									end),
									Theme.Spring.Snappy.Speed,
									Theme.Spring.Snappy.Damping
								),
								TextSize = 14,
								Font = Theme.Text.Bold,
								ZIndex = Theme.ZIndex.Modal + 4,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 4),
									}),
								},

								[Fusion.OnEvent("MouseEnter")] = function()
									closeHovered:set(true)
								end,

								[Fusion.OnEvent("MouseLeave")] = function()
									closeHovered:set(false)
								end,

								[Fusion.OnEvent("Activated")] = function()
									if props.OnClose then
										props.OnClose()
									end
								end,
							}),

							scope:New("Frame")({
								Name = "Divider",
								Size = UDim2.new(1, -32, 0, 1),
								Position = UDim2.fromScale(0.5, 1),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Color3.fromRGB(45, 45, 50),
								BorderSizePixel = 0,
								ZIndex = Theme.ZIndex.Modal + 2,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Content",
						Size = UDim2.new(1, -32, 1, -68),
						Position = UDim2.fromOffset(16, 60),
						BackgroundTransparency = 1,
						ZIndex = Theme.ZIndex.Modal + 2,

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, PANEL_GAP),
							}),

							scope:New("Frame")({
								Name = "ExportPanel",
								Size = UDim2.new(0.5, -PANEL_GAP / 2, 1, 0),
								BackgroundColor3 = Color3.fromRGB(28, 28, 32),
								BorderSizePixel = 0,
								LayoutOrder = 1,
								ZIndex = Theme.ZIndex.Modal + 3,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 6),
									}),

									scope:New("UIStroke")({
										Color = Color3.fromRGB(45, 45, 50),
										Thickness = 1,
									}),

									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 16),
										PaddingBottom = UDim.new(0, 16),
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 16),
									}),

									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, 0, 0, 20),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = "SHARE YOUR SETTINGS",
										TextColor3 = Theme.Colors.White,
										TextSize = 13,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),

									scope:New("TextLabel")({
										Name = "Description",
										Size = UDim2.new(1, 0, 0, 32),
										Position = UDim2.fromOffset(0, 24),
										BackgroundTransparency = 1,
										Text = "Generate a code and share it with friends. Select the text to copy.",
										TextColor3 = Color3.fromRGB(100, 100, 105),
										TextSize = 11,
										Font = Theme.Text.Regular,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),

									scope:New("Frame")({
										Name = "CodeDisplay",
										Size = UDim2.new(1, 0, 0, 44),
										Position = UDim2.fromOffset(0, 64),
										BackgroundColor3 = Color3.fromRGB(18, 18, 22),
										BorderSizePixel = 0,
										ZIndex = Theme.ZIndex.Modal + 4,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Color = Color3.fromRGB(40, 40, 45),
												Thickness = 1,
											}),

											scope:New("TextBox")({
												Name = "CodeText",
												Size = UDim2.new(1, -16, 1, 0),
												Position = UDim2.fromOffset(8, 0),
												BackgroundTransparency = 1,
												Text = scope:Computed(function(use: FusionUseFn)
													local code = use(exportCode)
													return if code ~= "" then code else "Click generate below"
												end),
												TextColor3 = scope:Computed(function(use: FusionUseFn)
													local code = use(exportCode)
													return if code ~= "" then Color3.fromRGB(120, 200, 160) else Color3.fromRGB(70, 70, 75)
												end),
												TextSize = 14,
												Font = Enum.Font.Code,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextEditable = false,
												ClearTextOnFocus = false,
												ZIndex = Theme.ZIndex.Modal + 5,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Buttons",
										Size = UDim2.new(1, 0, 0, 36),
										Position = UDim2.new(0, 0, 1, -36),
										BackgroundTransparency = 1,
										ZIndex = Theme.ZIndex.Modal + 4,

										[Fusion.Children] = {
											createActionButton("GENERATE CODE", Color3.fromRGB(60, 140, 100), handleExport, isExporting),
										},
									}),

									scope:New("TextLabel")({
										Name = "Status",
										Size = UDim2.new(1, 0, 0, 16),
										Position = UDim2.fromOffset(0, 116),
										BackgroundTransparency = 1,
										Text = exportStatus,
										TextColor3 = scope:Computed(function(use: FusionUseFn)
											local status = use(exportStatus)
											if string.find(status, "copy") then return Color3.fromRGB(120, 200, 160) end
											if status == "Failed to generate" then return Theme.Colors.Destructive end
											return Color3.fromRGB(100, 100, 105)
										end),
										TextSize = 10,
										Font = Theme.Text.Semibold,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ImportPanel",
								Size = UDim2.new(0.5, -PANEL_GAP / 2, 1, 0),
								BackgroundColor3 = Color3.fromRGB(28, 28, 32),
								BorderSizePixel = 0,
								LayoutOrder = 2,
								ZIndex = Theme.ZIndex.Modal + 3,

								[Fusion.Children] = {
									scope:New("UICorner")({
										CornerRadius = UDim.new(0, 6),
									}),

									scope:New("UIStroke")({
										Color = Color3.fromRGB(45, 45, 50),
										Thickness = 1,
									}),

									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 16),
										PaddingBottom = UDim.new(0, 16),
										PaddingLeft = UDim.new(0, 16),
										PaddingRight = UDim.new(0, 16),
									}),

									scope:New("TextLabel")({
										Name = "Title",
										Size = UDim2.new(1, 0, 0, 20),
										Position = UDim2.fromOffset(0, 0),
										BackgroundTransparency = 1,
										Text = "IMPORT SETTINGS",
										TextColor3 = Theme.Colors.White,
										TextSize = 13,
										Font = Theme.Text.Bold,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),

									scope:New("TextLabel")({
										Name = "Description",
										Size = UDim2.new(1, 0, 0, 32),
										Position = UDim2.fromOffset(0, 24),
										BackgroundTransparency = 1,
										Text = "Paste a code from someone else to use their settings.",
										TextColor3 = Color3.fromRGB(100, 100, 105),
										TextSize = 11,
										Font = Theme.Text.Regular,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextYAlignment = Enum.TextYAlignment.Top,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),

									scope:New("Frame")({
										Name = "CodeInput",
										Size = UDim2.new(1, 0, 0, 44),
										Position = UDim2.fromOffset(0, 64),
										BackgroundColor3 = Color3.fromRGB(18, 18, 22),
										BorderSizePixel = 0,
										ZIndex = Theme.ZIndex.Modal + 4,

										[Fusion.Children] = {
											scope:New("UICorner")({
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Color = Color3.fromRGB(40, 40, 45),
												Thickness = 1,
											}),

											scope:New("TextBox")({
												Name = "Input",
												Size = UDim2.new(1, -16, 1, 0),
												Position = UDim2.fromOffset(8, 0),
												BackgroundTransparency = 1,
												Text = "",
												PlaceholderText = "Paste code here...",
												PlaceholderColor3 = Color3.fromRGB(70, 70, 75),
												TextColor3 = Color3.fromRGB(120, 170, 220),
												TextSize = 14,
												Font = Enum.Font.Code,
												TextXAlignment = Enum.TextXAlignment.Left,
												ClearTextOnFocus = false,
												ZIndex = Theme.ZIndex.Modal + 5,

												[Fusion.OnChange("Text")] = function(text: string)
													importCode:set(text)
													importStatus:set("")
												end,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Buttons",
										Size = UDim2.new(1, 0, 0, 36),
										Position = UDim2.new(0, 0, 1, -36),
										BackgroundTransparency = 1,
										ZIndex = Theme.ZIndex.Modal + 4,

										[Fusion.Children] = {
											createActionButton("IMPORT SETTINGS", Color3.fromRGB(100, 140, 200), handleImport, isImporting),
										},
									}),

									scope:New("TextLabel")({
										Name = "Status",
										Size = UDim2.new(1, 0, 0, 16),
										Position = UDim2.fromOffset(0, 116),
										BackgroundTransparency = 1,
										Text = importStatus,
										TextColor3 = scope:Computed(function(use: FusionUseFn)
											local status = use(importStatus)
											if status == "Success!" then return Color3.fromRGB(120, 200, 160) end
											if status == "Invalid code" or status == "Enter a code first" then return Theme.Colors.Destructive end
											return Color3.fromRGB(100, 100, 105)
										end),
										TextSize = 10,
										Font = Theme.Text.Semibold,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = Theme.ZIndex.Modal + 4,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

return SettingsSharing
