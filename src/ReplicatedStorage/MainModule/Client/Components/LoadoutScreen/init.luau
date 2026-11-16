--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)

type FusionScope = Types.FusionScope

local LoadoutScreen = {}

LoadoutScreen.Styles = {
	Card = {
		Selected = {
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BackgroundTransparency = 0.05,
			StrokeColor = Color3.fromRGB(240, 240, 240),
			StrokeTransparency = 0,
			GunImageTransparency = 0.05,
			TextTransparency = 0,
			PlayersColor = Color3.fromRGB(120, 120, 120),
			SlotCountColor = Color3.fromRGB(240, 240, 240),
		},
		Open = {
			BackgroundColor3 = Color3.fromRGB(14, 14, 14),
			BackgroundTransparency = 0.15,
			StrokeColor = Color3.fromRGB(75, 73, 75),
			StrokeTransparency = 0,
			GunImageTransparency = 0.6,
			TextTransparency = 0,
			PlayersColor = Color3.fromRGB(90, 90, 90),
			SlotCountColor = Color3.fromRGB(240, 240, 240),
		},
		Full = {
			BackgroundColor3 = Color3.fromRGB(14, 14, 14),
			BackgroundTransparency = 0.5325,
			StrokeColor = Color3.fromRGB(75, 73, 75),
			StrokeTransparency = 0.45,
			GunImageTransparency = 0.78,
			TextTransparency = 0.45,
			PlayersColor = Color3.fromRGB(170, 170, 170),
			SlotCountColor = Color3.fromRGB(255, 100, 103),
		},
	},
	Pip = {
		Filled = {
			BackgroundColor3 = Color3.fromRGB(240, 240, 240),
			BackgroundTransparency = 0.45,
			StrokeTransparency = 1,
		},
		Empty = {
			BackgroundColor3 = Color3.fromRGB(240, 240, 240),
			BackgroundTransparency = 1,
			StrokeTransparency = 0,
		},
	},
}

function LoadoutScreen.createClassCard(scope: FusionScope): TextButton
	return scope:New("TextButton")({
		Name = "ClassCard",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(14, 14, 14),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 0.185185),
		Text = "",

		[Fusion.Children] = {
			scope:New("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 6),
			}),

			scope:New("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(75, 73, 75),
			}),

			scope:New("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.0454545, 0.275),
				Size = UDim2.fromScale(0.418182, 0.15),
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Loadout",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.0454545, 0.483333),
				Size = UDim2.fromScale(0.418182, 0.0916667),
				Text = "",
				TextColor3 = Color3.fromRGB(120, 120, 120),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("TextLabel")({
				Name = "Players",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.0454545, 0.633333),
				Size = UDim2.fromScale(0.418182, 0.0916667),
				Text = "",
				TextColor3 = Color3.fromRGB(90, 90, 90),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			scope:New("ImageLabel")({
				Name = "GunImage",
				BackgroundTransparency = 1,
				Image = "",
				ImageColor3 = Color3.fromRGB(240, 240, 240),
				ImageTransparency = 0.6,
				Position = UDim2.fromScale(0.504545, 0.333333),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.3, 0.333333),
			}),

			scope:New("TextLabel")({
				Name = "SlotCount",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.772727, 0.358333),
				Size = UDim2.fromScale(0.181818, 0.116667),
				Text = "",
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),

			scope:New("Frame")({
				Name = "Slots",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.681818, 0.55),
				Size = UDim2.fromScale(0.272727, 0.0833333),

				[Fusion.Children] = {
					scope:New("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0.0333333, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Current",
				Visible = false,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.240909, 0.308333),
				Size = UDim2.fromScale(0.181818, 0.0833333),
				Text = "CURRENT",
				TextColor3 = Color3.fromRGB(212, 166, 74),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

function LoadoutScreen.createSlotPip(scope: FusionScope): Frame
	return scope:New("Frame")({
		Name = "Pip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.0833333, 1),

		[Fusion.Children] = {
			scope:New("UICorner")({
				Name = "UICorner",
				CornerRadius = UDim.new(0, 2),
			}),

			scope:New("UIStroke")({
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(90, 90, 90),
			}),
		},
	})
end

function LoadoutScreen.create(scope: FusionScope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "LoadoutScreen",
		AutoLocalize = false,
		DisplayOrder = 50,
		Enabled = false,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "Frame",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Holder",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.8),

						[Fusion.Children] = {
							scope:New("UIAspectRatioConstraint")({
								Name = "UIAspectRatioConstraint",
								AspectRatio = 1.77778,
							}),

							scope:New("Frame")({
								Name = "Header",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.0333333, 0.0518519),
								Size = UDim2.fromScale(0.364583, 0.0666667),

								[Fusion.Children] = {
									scope:New("TextLabel")({
										Name = "Title",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
										Size = UDim2.fromScale(1, 0.666667),
										Text = "SELECT CLASS",
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("TextLabel")({
										Name = "Faction",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(-0.00100906, 0.661138),
										Size = UDim2.fromScale(0.428571, 0.180556),
										Text = "",
										TextColor3 = Color3.fromRGB(210, 210, 210),
										TextScaled = true,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "ClassList",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.0333333, 0.181481),
								Size = UDim2.fromScale(0.229167, 0.6),

								[Fusion.Children] = {
									scope:New("UIListLayout")({
										Name = "UIListLayout",
										Padding = UDim.new(0.0185185, 0),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
								},
							}),

							scope:New("Frame")({
								Name = "Loadout",
								BackgroundColor3 = Color3.fromRGB(14, 14, 14),
								BackgroundTransparency = 0.15,
								Position = UDim2.fromScale(0.69375, 0.181481),
								Size = UDim2.fromScale(0.272917, 0.750926),

								[Fusion.Children] = {
									scope:New("UICorner")({
										Name = "UICorner",
										CornerRadius = UDim.new(0, 8),
									}),

									scope:New("UIStroke")({
										Name = "UIStroke",
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(75, 73, 75),
									}),

									scope:New("Frame")({
										Name = "Header",
										BackgroundColor3 = Color3.fromRGB(35, 35, 40),
										Position = UDim2.fromScale(0.0267176, 0.0172626),
										Size = UDim2.fromScale(0.946565, 0.054254),

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 4),
											}),

											scope:New("UIStroke")({
												Name = "UIStroke",
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Color = Color3.fromRGB(75, 73, 75),
												Transparency = 0.3,
											}),

											scope:New("UIGradient")({
												Name = "UIGradient",
												Color = ColorSequence.new({
													ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
													ColorSequenceKeypoint.new(1, Color3.fromRGB(179, 179, 179)),
												}),
												Rotation = 90,
											}),

											scope:New("TextLabel")({
												Name = "Title",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Position = UDim2.fromScale(0.0322581, 0.329545),
												Size = UDim2.fromScale(0.604839, 0.340909),
												Text = "",
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("TextLabel")({
												Name = "Health",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Position = UDim2.fromScale(0.362903, 0.352273),
												Size = UDim2.fromScale(0.604839, 0.295455),
												Text = "",
												TextColor3 = Color3.fromRGB(210, 210, 210),
												TextScaled = true,
												TextXAlignment = Enum.TextXAlignment.Right,
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Primary",
										BackgroundColor3 = Color3.fromRGB(8, 8, 8),
										Position = UDim2.fromScale(0.0267176, 0.0912454),
										Size = UDim2.fromScale(0.946565, 0.323058),

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 6),
											}),

											scope:New("UIStroke")({
												Name = "UIStroke",
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Color = Color3.fromRGB(32, 32, 32),
											}),

											scope:New("TextLabel")({
												Name = "Slot",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Position = UDim2.fromScale(0.0282258, 0.0458015),
												Size = UDim2.fromScale(0.201613, 0.0381679),
												Text = "PREVIEW",
												TextColor3 = Color3.fromRGB(90, 90, 90),
												TextScaled = true,
												TextXAlignment = Enum.TextXAlignment.Left,
											}),

											scope:New("ImageLabel")({
												Name = "GunImage",
												BackgroundTransparency = 1,
												Image = "",
												ImageColor3 = Color3.fromRGB(240, 240, 240),
												Position = UDim2.fromScale(0.0967742, 0.21374),
												ScaleType = Enum.ScaleType.Fit,
												Size = UDim2.fromScale(0.806452, 0.572519),
											}),
										},
									}),

									scope:New("TextLabel")({
										Name = "GunName",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0.0343511, 0.437731),
										Size = UDim2.fromScale(0.381679, 0.0345253),
										Text = "",
										TextColor3 = Color3.new(1, 1, 1),
										TextScaled = true,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),

									scope:New("TextLabel")({
										Name = "Mode",
										BackgroundTransparency = 1,
										FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0.39313, 0.448212),
										Size = UDim2.fromScale(0.572519, 0.0135635),
										Text = "",
										TextColor3 = Color3.fromRGB(170, 170, 170),
										TextScaled = true,
										TextXAlignment = Enum.TextXAlignment.Right,
									}),

									scope:New("Frame")({
										Name = "Stats",
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0.0343511, 0.495684),
										Size = UDim2.fromScale(0.931298, 0.199753),

										[Fusion.Children] = {
											scope:New("Frame")({
												Name = "Damage",
												BackgroundTransparency = 1,
												LayoutOrder = 1,
												Size = UDim2.fromScale(1, 0.111111),

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Label",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0, 0.194444),
														Size = UDim2.fromScale(0.213115, 0.611111),
														Text = "DAMAGE",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("Frame")({
														Name = "Bar",
														BackgroundColor3 = Color3.fromRGB(40, 40, 40),
														Position = UDim2.fromScale(0.245902, 0.388889),
														Size = UDim2.fromScale(0.45082, 0.222222),

														[Fusion.Children] = {
															scope:New("UICorner")({
																Name = "UICorner",
																CornerRadius = UDim.new(0, 2),
															}),

															scope:New("Frame")({
																Name = "Fill",
																BackgroundColor3 = Color3.fromRGB(240, 240, 240),
																Size = UDim2.fromScale(0, 1),

																[Fusion.Children] = {
																	scope:New("UICorner")({
																		Name = "UICorner",
																		CornerRadius = UDim.new(0, 2),
																	}),
																},
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Value",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.729508, 0.166667),
														Size = UDim2.fromScale(0.270492, 0.666667),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "FireRate",
												BackgroundTransparency = 1,
												LayoutOrder = 2,
												Position = UDim2.fromScale(0, 0.222222),
												Size = UDim2.fromScale(1, 0.111111),

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Label",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0, 0.194444),
														Size = UDim2.fromScale(0.213115, 0.611111),
														Text = "FIRE RATE",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("Frame")({
														Name = "Bar",
														BackgroundColor3 = Color3.fromRGB(40, 40, 40),
														Position = UDim2.fromScale(0.245902, 0.388889),
														Size = UDim2.fromScale(0.45082, 0.222222),

														[Fusion.Children] = {
															scope:New("UICorner")({
																Name = "UICorner",
																CornerRadius = UDim.new(0, 2),
															}),

															scope:New("Frame")({
																Name = "Fill",
																BackgroundColor3 = Color3.fromRGB(240, 240, 240),
																Size = UDim2.fromScale(0, 1),

																[Fusion.Children] = {
																	scope:New("UICorner")({
																		Name = "UICorner",
																		CornerRadius = UDim.new(0, 2),
																	}),
																},
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Value",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.729508, 0.166667),
														Size = UDim2.fromScale(0.270492, 0.666667),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Range",
												BackgroundTransparency = 1,
												LayoutOrder = 3,
												Position = UDim2.fromScale(0, 0.444444),
												Size = UDim2.fromScale(1, 0.111111),

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Label",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0, 0.194444),
														Size = UDim2.fromScale(0.213115, 0.611111),
														Text = "RANGE",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("Frame")({
														Name = "Bar",
														BackgroundColor3 = Color3.fromRGB(40, 40, 40),
														Position = UDim2.fromScale(0.245902, 0.388889),
														Size = UDim2.fromScale(0.45082, 0.222222),

														[Fusion.Children] = {
															scope:New("UICorner")({
																Name = "UICorner",
																CornerRadius = UDim.new(0, 2),
															}),

															scope:New("Frame")({
																Name = "Fill",
																BackgroundColor3 = Color3.fromRGB(240, 240, 240),
																Size = UDim2.fromScale(0, 1),

																[Fusion.Children] = {
																	scope:New("UICorner")({
																		Name = "UICorner",
																		CornerRadius = UDim.new(0, 2),
																	}),
																},
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Value",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.729508, 0.166667),
														Size = UDim2.fromScale(0.270492, 0.666667),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Accuracy",
												BackgroundTransparency = 1,
												LayoutOrder = 4,
												Position = UDim2.fromScale(0, 0.666667),
												Size = UDim2.fromScale(1, 0.111111),

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Label",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0, 0.194444),
														Size = UDim2.fromScale(0.213115, 0.611111),
														Text = "ACCURACY",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("Frame")({
														Name = "Bar",
														BackgroundColor3 = Color3.fromRGB(40, 40, 40),
														Position = UDim2.fromScale(0.245902, 0.388889),
														Size = UDim2.fromScale(0.45082, 0.222222),

														[Fusion.Children] = {
															scope:New("UICorner")({
																Name = "UICorner",
																CornerRadius = UDim.new(0, 2),
															}),

															scope:New("Frame")({
																Name = "Fill",
																BackgroundColor3 = Color3.fromRGB(240, 240, 240),
																Size = UDim2.fromScale(0, 1),

																[Fusion.Children] = {
																	scope:New("UICorner")({
																		Name = "UICorner",
																		CornerRadius = UDim.new(0, 2),
																	}),
																},
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Value",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.729508, 0.166667),
														Size = UDim2.fromScale(0.270492, 0.666667),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Magazine",
												BackgroundTransparency = 1,
												LayoutOrder = 5,
												Position = UDim2.fromScale(0, 0.888889),
												Size = UDim2.fromScale(1, 0.111111),

												[Fusion.Children] = {
													scope:New("TextLabel")({
														Name = "Label",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0, 0.194444),
														Size = UDim2.fromScale(0.213115, 0.611111),
														Text = "AMMO",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("Frame")({
														Name = "Bar",
														BackgroundColor3 = Color3.fromRGB(40, 40, 40),
														Position = UDim2.fromScale(0.245902, 0.388889),
														Size = UDim2.fromScale(0.45082, 0.222222),

														[Fusion.Children] = {
															scope:New("UICorner")({
																Name = "UICorner",
																CornerRadius = UDim.new(0, 2),
															}),

															scope:New("Frame")({
																Name = "Fill",
																BackgroundColor3 = Color3.fromRGB(240, 240, 240),
																Size = UDim2.fromScale(0, 1),

																[Fusion.Children] = {
																	scope:New("UICorner")({
																		Name = "UICorner",
																		CornerRadius = UDim.new(0, 2),
																	}),
																},
															}),
														},
													}),

													scope:New("TextLabel")({
														Name = "Value",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.729508, 0.166667),
														Size = UDim2.fromScale(0.270492, 0.666667),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),
												},
											}),
										},
									}),

									scope:New("Frame")({
										Name = "Divider",
										BackgroundColor3 = Color3.fromRGB(40, 40, 40),
										BorderSizePixel = 0,
										Position = UDim2.fromScale(0.0267176, 0.715166),
										Size = UDim2.new(0.946565, 0, 0, 1),
									}),

									scope:New("Frame")({
										Name = "Extras",
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0.0267176, 0.736128),
										Size = UDim2.fromScale(0.946565, 0.15783),

										[Fusion.Children] = {
											scope:New("Frame")({
												Name = "Secondary",
												BackgroundColor3 = Color3.fromRGB(14, 14, 14),
												Size = UDim2.fromScale(0.489919, 1),

												[Fusion.Children] = {
													scope:New("UICorner")({
														Name = "UICorner",
														CornerRadius = UDim.new(0, 6),
													}),

													scope:New("UIStroke")({
														Name = "UIStroke",
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
														Color = Color3.fromRGB(48, 48, 48),
													}),

													scope:New("ImageLabel")({
														Name = "GunImage",
														BackgroundTransparency = 1,
														Image = "",
														ImageColor3 = Color3.fromRGB(240, 240, 240),
														ImageTransparency = 0.1,
														Position = UDim2.fromScale(0.0658436, 0.109375),
														ScaleType = Enum.ScaleType.Fit,
														Size = UDim2.fromScale(0.272578, 0.34375),
													}),

													scope:New("TextLabel")({
														Name = "Slot",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.242188),
														Size = UDim2.fromScale(0.868313, 0.078125),
														Text = "SECONDARY",
														TextColor3 = Color3.fromRGB(90, 90, 90),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),

													scope:New("TextLabel")({
														Name = "Title",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Heavy,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.664062),
														Size = UDim2.fromScale(0.868313, 0.109375),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("TextLabel")({
														Name = "Detail",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.8125),
														Size = UDim2.fromScale(0.868313, 0.078125),
														Text = "",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),
												},
											}),

											scope:New("Frame")({
												Name = "Medi",
												BackgroundColor3 = Color3.fromRGB(14, 14, 14),
												Position = UDim2.fromScale(0.510081, 0),
												Size = UDim2.fromScale(0.489919, 1),

												[Fusion.Children] = {
													scope:New("UICorner")({
														Name = "UICorner",
														CornerRadius = UDim.new(0, 6),
													}),

													scope:New("UIStroke")({
														Name = "UIStroke",
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
														Color = Color3.fromRGB(48, 48, 48),
													}),

													scope:New("ImageLabel")({
														Name = "GunImage",
														BackgroundTransparency = 1,
														Image = "",
														ImageColor3 = Color3.fromRGB(240, 240, 240),
														ImageTransparency = 0.1,
														Position = UDim2.fromScale(0.0658436, 0.109375),
														ScaleType = Enum.ScaleType.Fit,
														Size = UDim2.fromScale(0.279593, 0.34375),
													}),

													scope:New("TextLabel")({
														Name = "Slot",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.242188),
														Size = UDim2.fromScale(0.868313, 0.078125),
														Text = "MEDI",
														TextColor3 = Color3.fromRGB(90, 90, 90),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Right,
													}),

													scope:New("TextLabel")({
														Name = "Title",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Heavy,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.664062),
														Size = UDim2.fromScale(0.868313, 0.109375),
														Text = "",
														TextColor3 = Color3.new(1, 1, 1),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),

													scope:New("TextLabel")({
														Name = "Detail",
														BackgroundTransparency = 1,
														FontFace = Font.new(
															"rbxasset://fonts/families/GothamSSm.json",
															Enum.FontWeight.Bold,
															Enum.FontStyle.Normal
														),
														Position = UDim2.fromScale(0.0658436, 0.8125),
														Size = UDim2.fromScale(0.868313, 0.078125),
														Text = "",
														TextColor3 = Color3.fromRGB(120, 120, 120),
														TextScaled = true,
														TextXAlignment = Enum.TextXAlignment.Left,
													}),
												},
											}),
										},
									}),

									scope:New("TextButton")({
										Name = "Deploy",
										AutoButtonColor = false,
										BackgroundColor3 = Color3.fromRGB(30, 30, 30),
										Position = UDim2.fromScale(0.0267176, 0.913687),
										Size = UDim2.fromScale(0.946565, 0.0690506),
										Text = "",

										[Fusion.Children] = {
											scope:New("UICorner")({
												Name = "UICorner",
												CornerRadius = UDim.new(0, 6),
											}),

											scope:New("UIStroke")({
												Name = "UIStroke",
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												Color = Color3.fromRGB(240, 240, 240),
											}),

											scope:New("UIGradient")({
												Name = "UIGradient",
												Color = ColorSequence.new({
													ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
													ColorSequenceKeypoint.new(1, Color3.fromRGB(187, 187, 187)),
												}),
												Rotation = 90,
											}),

											scope:New("TextLabel")({
												Name = "Label",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Position = UDim2.fromScale(0, 0.348214),
												Size = UDim2.fromScale(1, 0.303571),
												Text = "DEPLOY",
												TextColor3 = Color3.new(1, 1, 1),
												TextScaled = true,
											}),
										},
									}),
								},
							}),

							scope:New("TextLabel")({
								Name = "Hint",
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.0333333, 0.905556),
								RichText = true,
								Size = UDim2.fromScale(0.364583, 0.0111111),
								Text = '[LMB] <font color="#787878">DRAG TO ROTATE</font>        [ESC] <font color="#787878">CLOSE</font>',
								TextColor3 = Color3.new(1, 1, 1),
								TextScaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),

							scope:New("ViewportFrame")({
								Name = "ClassViewport",
								Ambient = Color3.fromRGB(120, 125, 135),
								BackgroundTransparency = 1,
								LightColor = Color3.fromRGB(255, 250, 240),
								LightDirection = Vector3.new(-0.4239991307258606, -0.8479982614517212, -0.31799936294555664),
								Position = UDim2.fromScale(0.270833, 0.166667),
								Size = UDim2.fromScale(0.414583, 0.731481),
								ZIndex = 3,

								[Fusion.Children] = {
									scope:New("Camera")({
										Name = "Camera",
										CFrame = CFrame.new(
											-1.24296,
											19.2203,
											16.6894,
											-0.978596,
											0.0286408,
											-0.20379,
											0,
											0.990268,
											0.139173,
											0.205792,
											0.136194,
											-0.969072
										),
										CameraType = Enum.CameraType.Scriptable,
										FieldOfView = 35,
									}),

									scope:New("WorldModel")({
										Name = "WorldModel",
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Background",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = -1,

				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Frame",
						BackgroundColor3 = Color3.fromRGB(18, 18, 21),
						BackgroundTransparency = 0.1,
						BorderColor3 = Color3.new(),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = -2,
					}),

					scope:New("ImageLabel")({
						Name = "PatternImage",
						BackgroundTransparency = 1,
						Image = "rbxassetid://0",
						ImageColor3 = Color3.fromRGB(220, 220, 235),
						ImageTransparency = 0.96,
						ScaleType = Enum.ScaleType.Tile,
						Size = UDim2.fromScale(1, 1),
						TileSize = UDim2.fromOffset(1024, 1024),
						ZIndex = 0,
					}),

					scope:New("Frame")({
						Name = "Vignette",
						BackgroundColor3 = Color3.fromRGB(8, 8, 10),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),

						[Fusion.Children] = {
							scope:New("UIGradient")({
								Name = "UIGradient",
								Rotation = 90,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.55, 1),
									NumberSequenceKeypoint.new(1, 0.3),
								}),
							}),
						},
					}),
				},
			}),
		},
	})
end

return LoadoutScreen
