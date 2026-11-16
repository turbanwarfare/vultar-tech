--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope

local CARD_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.85),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(1, 0.05),
})

local NewDeathScreen = {}

NewDeathScreen.Styles = {
	Row = {
		Normal = {
			TextColor = Color3.fromRGB(230, 230, 240),
			PartColor = Color3.fromRGB(197, 197, 197),
			GunImageColor = Color3.fromRGB(160, 160, 175),
		},
		Headshot = {
			TextColor = Color3.fromRGB(200, 50, 50),
			PartColor = Color3.fromRGB(200, 50, 50),
			GunImageColor = Color3.fromRGB(220, 160, 160),
		},
	},
	Dot = {
		Body = {
			Color = Color3.fromRGB(130, 145, 200),
			Size = 8,
		},
		Headshot = {
			Color = Color3.fromRGB(220, 55, 55),
			Size = 10,
		},
	},
}

function NewDeathScreen.createIncomingRow(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "GunName",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Size = UDim2.fromOffset(54, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(230, 230, 240),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("ImageLabel")({
				Name = "GunImage",
				BackgroundTransparency = 1,
				Image = "",
				ImageColor3 = Color3.fromRGB(160, 160, 175),
				Position = UDim2.fromOffset(58, 6),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(44, 18),
			}),

			scope:New("TextLabel")({
				Name = "Dmg",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = UDim2.fromOffset(108, 0),
				Size = UDim2.fromOffset(50, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(230, 230, 240),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Name",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, -170, 0, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(197, 197, 197),
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			scope:New("Frame")({
				Name = "Separator",
				BackgroundColor3 = Color3.fromRGB(88, 88, 88),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -1),
				Size = UDim2.new(1, 0, 0, 1),
			}),
		},
	})
end

function NewDeathScreen.createOutgoingRow(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),

		[Fusion.Children] = {
			scope:New("TextLabel")({
				Name = "GunName",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Size = UDim2.fromOffset(54, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(230, 230, 240),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("ImageLabel")({
				Name = "GunImage",
				BackgroundTransparency = 1,
				Image = "",
				ImageColor3 = Color3.fromRGB(160, 160, 175),
				Position = UDim2.fromOffset(58, 6),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(44, 18),
			}),

			scope:New("TextLabel")({
				Name = "Dmg",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = UDim2.fromOffset(108, 0),
				Size = UDim2.fromOffset(50, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(230, 230, 240),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Part",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromOffset(170, 0),
				Size = UDim2.fromOffset(150, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(197, 197, 197),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Name",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, -170, 0, 30),
				Text = "",
				TextColor3 = Color3.fromRGB(197, 197, 197),
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			scope:New("Frame")({
				Name = "Separator",
				BackgroundColor3 = Color3.fromRGB(88, 88, 88),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -1),
				Size = UDim2.new(1, 0, 0, 1),
			}),
		},
	})
end

function NewDeathScreen.createHitDot(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Dot",
		BackgroundColor3 = Color3.fromRGB(130, 145, 200),
		BackgroundTransparency = 0.75,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(8, 8),
		ZIndex = 5,

		[Fusion.Children] = {
			scope:New("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0.5, 0),
			}),

			scope:New("UIStroke")({
				Name = "UIStroke",
				Color = Color3.fromRGB(130, 145, 200),
				Thickness = 2.5,
			}),
		},
	})
end

function NewDeathScreen.create(scope: FusionScope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "DeathScreen",
		AutoLocalize = false,
		Enabled = false,
		DisplayOrder = 50,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Overlay",
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = 0.15,
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}),

			scope:New("Frame")({
				Name = "Canvas",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(1920, 1080),

				[Fusion.Children] = {
					scope:New("UIScale")({
						Name = "UIScale",
						Scale = 1,
					}),

					scope:New("Frame")({
						Name = "Eliminated",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(56, 90),
						Size = UDim2.fromOffset(400, 36),

						[Fusion.Children] = {
							scope:New("UIListLayout")({
								Name = "UIListLayout",
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 12),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),

							scope:New("ImageLabel")({
								Name = "Skull",
								BackgroundTransparency = 1,
								Image = "rbxassetid://113780006558360",
								LayoutOrder = 1,
								Size = UDim2.fromOffset(36, 36),
							}),

							scope:New("TextLabel")({
								Name = "Label",
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
								LayoutOrder = 2,
								Size = UDim2.fromOffset(0, 36),
								Text = "ELIMINATED",
								TextColor3 = Color3.fromRGB(202, 202, 202),
								TextSize = 16,
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Content",
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 56, 1, -52),
						Size = UDim2.fromOffset(720, 182),

						[Fusion.Children] = {
							scope:New("CanvasGroup")({
								Name = "CardBox",
								BackgroundColor3 = Color3.fromRGB(18, 18, 18),
								BackgroundTransparency = 0.15,
								Position = UDim2.fromOffset(-10, 18),
								Size = UDim2.fromOffset(740, 140),
								Visible = false,

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 4),
									}),

									scope:New("UIStroke")({
										Name = "UIStroke",
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(88, 88, 88),
									}),

									scope:New("ImageLabel")({
										Name = "CardImage",
										BackgroundTransparency = 1,
										Image = "",
										ScaleType = Enum.ScaleType.Crop,
										Size = UDim2.fromScale(1, 1),
										Visible = false,

										[Fusion.Children] = {
											scope:New("UIGradient")({
												Name = "UIGradient",
												Transparency = CARD_FADE,
											}),
										},
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "Title",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
								Size = UDim2.fromOffset(400, 16),
								Text = "YOU WERE KILLED BY",
								TextColor3 = Color3.fromRGB(180, 180, 190),
								TextSize = 13,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),

							scope:New("ImageLabel")({
								Name = "Avatar",
								BackgroundColor3 = Color3.fromRGB(18, 18, 18),
								BackgroundTransparency = 0.15,
								Image = "",
								Position = UDim2.fromOffset(0, 26),
								Size = UDim2.fromOffset(124, 124),
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 4),
									}),

									scope:New("UIStroke")({
										Name = "UIStroke",
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(80, 140, 220),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Info",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(142, 26),
								Size = UDim2.fromOffset(578, 124),

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "KillerName",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromOffset(0, 6),
										Size = UDim2.fromOffset(578, 64),
										Text = "",
										TextColor3 = Color3.new(1, 1, 1),
										TextSize = 62,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("Frame")({
										Name = "Stats",
										BackgroundTransparency = 1,
										Position = UDim2.fromOffset(0, 84),
										Size = UDim2.fromOffset(578, 28),

										[Fusion.Children] = {
											scope:New("UIListLayout")({
												Name = "UIListLayout",
												FillDirection = Enum.FillDirection.Horizontal,
												Padding = UDim.new(0, 14),
												SortOrder = Enum.SortOrder.LayoutOrder,
												VerticalAlignment = Enum.VerticalAlignment.Center,
											}),

											scope:New("Frame")({
												Name = "TeamGroup",
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												LayoutOrder = 1,
												Size = UDim2.fromOffset(0, 28),

												[Fusion.Children] = {
													scope:New("UIListLayout")({
														Name = "UIListLayout",
														FillDirection = Enum.FillDirection.Horizontal,
														Padding = UDim.new(0, 6),
														SortOrder = Enum.SortOrder.LayoutOrder,
														VerticalAlignment = Enum.VerticalAlignment.Center,
													}),

													scope:New("ImageLabel")({
														Name = "Icon",
														BackgroundTransparency = 1,
														Image = "",
														LayoutOrder = 1,
														ScaleType = Enum.ScaleType.Fit,
														Size = UDim2.fromOffset(18, 18),
													}),

													scope:New("TextLabel")({
														Name = "Team",
														AutomaticSize = Enum.AutomaticSize.X,
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.ExtraBold,
															Enum.FontStyle.Normal
														),
														LayoutOrder = 2,
														Size = UDim2.fromOffset(0, 28),
														Text = "",
														TextColor3 = Color3.fromRGB(80, 140, 220),
														TextSize = 14,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Separator",
												BackgroundColor3 = Color3.fromRGB(149, 149, 149),
												BackgroundTransparency = 0.1,
												BorderColor3 = Color3.new(),
												BorderSizePixel = 0,
												LayoutOrder = 2,
												Size = UDim2.fromOffset(2, 16),
											}),

											scope:New("Frame")({
												Name = "GunGroup",
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												LayoutOrder = 3,
												Size = UDim2.fromOffset(0, 28),

												[Fusion.Children] = {
													scope:New("UIListLayout")({
														Name = "UIListLayout",
														FillDirection = Enum.FillDirection.Horizontal,
														Padding = UDim.new(0, 8),
														SortOrder = Enum.SortOrder.LayoutOrder,
														VerticalAlignment = Enum.VerticalAlignment.Center,
													}),

													scope:New("ImageLabel")({
														Name = "GunImage",
														BackgroundTransparency = 1,
														Image = "",
														LayoutOrder = 1,
														ScaleType = Enum.ScaleType.Fit,
														Size = UDim2.fromOffset(48, 22),
													}),

													scope:New("TextLabel")({
														Name = "Gun",
														AutomaticSize = Enum.AutomaticSize.X,
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														LayoutOrder = 2,
														Size = UDim2.fromOffset(0, 28),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextSize = 14,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Separator",
												BackgroundColor3 = Color3.fromRGB(149, 149, 149),
												BackgroundTransparency = 0.1,
												BorderColor3 = Color3.new(),
												BorderSizePixel = 0,
												LayoutOrder = 4,
												Size = UDim2.fromOffset(2, 16),
											}),

											scope:New("TextLabel")({
												Name = "Studs",
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												LayoutOrder = 5,
												Size = UDim2.fromOffset(0, 28),
												Text = "",
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 14,
											}),

											scope:New("Frame")({
												Name = "Separator",
												BackgroundColor3 = Color3.fromRGB(149, 149, 149),
												BackgroundTransparency = 0.1,
												BorderColor3 = Color3.new(),
												BorderSizePixel = 0,
												LayoutOrder = 6,
												Size = UDim2.fromOffset(2, 16),
											}),

											scope:New("TextLabel")({
												Name = "HP",
												AutomaticSize = Enum.AutomaticSize.X,
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												LayoutOrder = 7,
												Size = UDim2.fromOffset(0, 28),
												Text = "",
												TextColor3 = Color3.new(1, 1, 1),
												TextSize = 14,
											}),
										},
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "RespawnContent",
						AnchorPoint = Vector2.one,
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -56, 1, -36),
						Size = UDim2.fromOffset(594, 97),

						[Fusion.Children] = {
							scope:New("Frame")({
								Name = "DeathReport",
								BackgroundColor3 = Color3.fromRGB(25, 25, 25),
								BackgroundTransparency = 0.25,
								Size = UDim2.new(1, 0, 0, 50),

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 4),
									}),

									scope:New("UIStroke")({
										Name = "UIStroke",
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(88, 88, 88),
									}),

									scope:New("TextLabel")({
										Name = "Label",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromOffset(16, 0),
										Size = UDim2.fromOffset(300, 50),
										Text = "VDI DEATH REPORT",
										TextColor3 = Color3.fromRGB(209, 209, 209),
										TextSize = 16,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("Frame")({
										Name = "Extend",
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.new(1, -16, 0.5, 0),
										Size = UDim2.fromOffset(28, 28),
										ZIndex = 5,

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Name = "UIStroke",
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Color = Color3.fromRGB(88, 88, 88),
											}),

											scope:New("TextButton")({
												Name = "Button",
												AutoButtonColor = false,
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Size = UDim2.fromScale(1, 1),
												Text = "V",
												TextColor3 = Color3.fromRGB(209, 209, 209),
												TextSize = 14,
												ZIndex = 10,
											}),
										},
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "Label",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromOffset(0, 63),
								Size = UDim2.new(0.5, 0, 0, 18),
								Text = "RESPAWNING",
								TextColor3 = Color3.fromRGB(209, 209, 209),
								TextSize = 14,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),

							scope:New("TextLabel")({
								Name = "Time",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.new(0.5, 0, 0, 63),
								Size = UDim2.new(0.5, 0, 0, 18),
								Text = "",
								TextColor3 = Color3.fromRGB(209, 209, 209),
								TextSize = 14,
								TextXAlignment = Enum.TextXAlignment.Right,
								TextYAlignment = Enum.TextYAlignment.Bottom,
							}),

							scope:New("Frame")({
								Name = "RespawnBar",
								BackgroundColor3 = Color3.new(),
								BackgroundTransparency = 0.5,
								ClipsDescendants = true,
								Position = UDim2.fromOffset(0, 89),
								Size = UDim2.new(1, 0, 0, 8),

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 4),
									}),

									scope:New("UIStroke")({
										Name = "UIStroke",
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(88, 88, 88),
									}),

									scope:New("Frame")({
										Name = "Filler",
										BackgroundColor3 = Color3.new(1, 1, 1),
										Size = UDim2.fromScale(1, 1),

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 4),
											}),
										},
									}),
								},
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Report",
						Visible = false,
						BackgroundColor3 = Color3.fromRGB(25, 25, 25),
						BackgroundTransparency = 0.35,
						AnchorPoint = Vector2.one,
						Position = UDim2.new(1, -56, 1, -157),
						Size = UDim2.fromOffset(594, 627),

						[Fusion.Children] = {
							scope:New("UIStroke")({
								Name = "UIStroke",
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.fromRGB(88, 88, 88),
							}),

							scope:New("UICorner")({
								Name = "UICorner",
								CornerRadius = UDim.new(0, 4),
							}),

							scope:New("TextLabel")({
								Name = "Title",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromOffset(16, 0),
								Size = UDim2.fromOffset(300, 50),
								Text = "VDI DEATH REPORT",
								TextColor3 = Color3.fromRGB(209, 209, 209),
								TextSize = 16,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("Frame")({
								Name = "Close",
								AnchorPoint = Vector2.new(1, 0),
								BackgroundTransparency = 1,
								Position = UDim2.new(1, -16, 0, 0),
								Size = UDim2.fromOffset(200, 50),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Right,
										Padding = UDim.new(0, 8),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),

									scope:New("TextLabel")({
										Name = "Label",
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										LayoutOrder = 1,
										Size = UDim2.fromOffset(0, 50),
										Text = "CLOSE",
										TextColor3 = Color3.fromRGB(160, 160, 175),
										TextSize = 12,
									}),

									scope:New("Frame")({
										Name = "Extend",
										BackgroundTransparency = 1,
										LayoutOrder = 2,
										Size = UDim2.fromOffset(28, 28),
										ZIndex = 5,

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Name = "UIStroke",
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Color = Color3.fromRGB(88, 88, 88),
											}),

											scope:New("TextButton")({
												Name = "Button",
												AutoButtonColor = false,
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Size = UDim2.fromScale(1, 1),
												Text = "V",
												TextColor3 = Color3.fromRGB(209, 209, 209),
												TextSize = 14,
												ZIndex = 10,
											}),
										},
									}),
								},
							}),

							scope:New("Frame")({
								Name = "HeaderSeparator",
								BackgroundColor3 = Color3.fromRGB(88, 88, 88),
								BorderColor3 = Color3.new(),
								BorderSizePixel = 0,
								Position = UDim2.fromOffset(0, 50),
								Size = UDim2.new(1, 0, 0, 1),
							}),

							scope:New("Frame")({
								Name = "IncomingHeader",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(16, 62),
								Size = UDim2.fromOffset(562, 18),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 12),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),

									scope:New("TextLabel")({
										Name = "Label",
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										LayoutOrder = 1,
										Size = UDim2.fromOffset(0, 18),
										Text = "RECEIVED",
										TextColor3 = Color3.fromRGB(209, 209, 209),
										TextSize = 13,
									}),

									scope:New("Frame")({
										Name = "Separator",
										BackgroundColor3 = Color3.fromRGB(88, 88, 88),
										BorderColor3 = Color3.new(),
										BorderSizePixel = 0,
										LayoutOrder = 2,
										Size = UDim2.fromOffset(0, 1),

										[Fusion.Children] = {
											scope:New("UIFlexItem")({
												Name = "UIFlexItem",
												FlexMode = Enum.UIFlexMode.Fill,
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "Summary",
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										LayoutOrder = 3,
										Size = UDim2.fromOffset(0, 18),
										Text = "",
										TextColor3 = Color3.fromRGB(209, 209, 209),
										TextSize = 13,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "VP",
								BackgroundTransparency = 1,
								ClipsDescendants = true,
								Position = UDim2.fromOffset(16, 90),
								Size = UDim2.fromOffset(260, 309),
								ZIndex = 5,

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 6),
									}),

									scope:New("ViewportFrame")({
										Name = "View",
										Ambient = Color3.fromRGB(180, 185, 195),
										BackgroundTransparency = 1,
										LightColor = Color3.new(1, 1, 1),
										LightDirection = Vector3.new(-0.35856857895851135, -0.7171371579170227, -0.5976142883300781),
										Size = UDim2.fromScale(1, 1),

										[Fusion.Children] = {
											scope:New("WorldModel")({
												Name = "WorldModel",
											}),

											scope:New("Camera")({
												Name = "Camera",
												CFrame = CFrame.new(0, 19, 15, -1, 0, 0, 0, 0.992877, 0.119145, 0, 0.119145, -0.992877),
												CameraType = Enum.CameraType.Scriptable,
												FieldOfView = 50,
											}),
										},
									}),
								},
							}),

							scope:New("ScrollingFrame")({
								Name = "List",
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								CanvasSize = UDim2.new(),
								Position = UDim2.fromOffset(292, 90),
								ScrollBarImageColor3 = Color3.fromRGB(60, 60, 72),
								ScrollBarThickness = 3,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								Size = UDim2.fromOffset(286, 314),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),

									scope:New("UIPadding")({
										Name = "UIPadding",
										PaddingBottom = UDim.new(0, 6),
										PaddingRight = UDim.new(0, 16),
										PaddingTop = UDim.new(0, 6),
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Total",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(292, 410),
								Size = UDim2.fromOffset(270, 28),

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Label",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Size = UDim2.fromScale(0.6, 1),
										Text = "TOTAL TAKEN",
										TextColor3 = Color3.fromRGB(197, 197, 197),
										TextSize = 14,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("TextLabel")({
										Name = "Value",
										AnchorPoint = Vector2.new(1, 0),
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(1, 0),
										Size = UDim2.fromScale(0.4, 1),
										Text = "",
										TextColor3 = Color3.fromRGB(230, 230, 240),
										TextSize = 18,
										TextXAlignment = Enum.TextXAlignment.Right,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "OutgoingHeader",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(16, 454),
								Size = UDim2.fromOffset(562, 18),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 12),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),

									scope:New("TextLabel")({
										Name = "Label",
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										LayoutOrder = 1,
										Size = UDim2.fromOffset(0, 18),
										Text = "DEALT",
										TextColor3 = Color3.fromRGB(209, 209, 209),
										TextSize = 13,
									}),

									scope:New("Frame")({
										Name = "Separator",
										BackgroundColor3 = Color3.fromRGB(88, 88, 88),
										BorderColor3 = Color3.new(),
										BorderSizePixel = 0,
										LayoutOrder = 2,
										Size = UDim2.fromOffset(0, 1),

										[Fusion.Children] = {
											scope:New("UIFlexItem")({
												Name = "UIFlexItem",
												FlexMode = Enum.UIFlexMode.Fill,
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "Summary",
										AutomaticSize = Enum.AutomaticSize.X,
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										LayoutOrder = 3,
										Size = UDim2.fromOffset(0, 18),
										Text = "",
										TextColor3 = Color3.fromRGB(209, 209, 209),
										TextSize = 13,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Outgoing",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(16, 482),
								Size = UDim2.fromOffset(562, 98),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "FooterSeparator",
								BackgroundColor3 = Color3.fromRGB(88, 88, 88),
								BorderColor3 = Color3.new(),
								BorderSizePixel = 0,
								Position = UDim2.fromOffset(0, 596),
								Size = UDim2.new(1, 0, 0, 1),
							}),

							scope:New("TextLabel")({
								Name = "Accuracy",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
								Position = UDim2.fromOffset(0, 597),
								Size = UDim2.new(0.5, 0, 0, 30),
								Text = "",
								TextColor3 = Color3.fromRGB(160, 160, 175),
								TextSize = 11,
							}),

							scope:New("TextLabel")({
								Name = "MatchAccuracy",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
								Position = UDim2.new(0.5, 0, 0, 597),
								Size = UDim2.new(0.5, 0, 0, 30),
								Text = "",
								TextColor3 = Color3.fromRGB(160, 160, 175),
								TextSize = 11,
							}),
						},
					}),
				},
			}),
		},
	})
end

return NewDeathScreen
