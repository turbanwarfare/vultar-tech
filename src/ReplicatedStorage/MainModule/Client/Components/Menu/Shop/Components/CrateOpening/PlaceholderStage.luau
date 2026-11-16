--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local Packages = MainModule:WaitForChild("Packages", 5)
local Fusion = require(Packages:WaitForChild("Fusion", 5))
local Types = require(MainModule.Shared.Types)
local Theme = require(MainModule.Shared.UI.Theme)
local CratesConfig = require(MainModule.Shared.Config.Cosmetics.Crates)

local CrateModelCache = require(script.Parent.Parent.Parent.Cache.CrateModelCache)
local CrateViewportFactory = require(MainModule.Client.Utils.CrateViewportFactory)
local RevealEffects = require(script.Parent.RevealEffects)
local CrateAudio = require(script.Parent.CrateAudio)

type FusionScope = Types.FusionScope
type CrateRarity = CratesConfig.CrateRarity

export type PlaceholderStageProps = {
	Crate: CrateConfig,
	HighestRarity: (CrateRarity | FusionValue<CrateRarity?>)?,
	HasLegendary: (boolean | FusionValue<boolean>)?,
}

local DEBUG_LOGGING = false

local function applyPivot(target: PVInstance, cframe: CFrame): ()
	target:PivotTo(cframe)
end

local function debugLog(...: any)
	if DEBUG_LOGGING then
		print(...)
	end
end

local function playSound(sndCfg: { AssetId: string, Volume: number?, PlaybackSpeed: number? }?, overrideVolume: number?, overridePlaybackSpeed: number?): number
	local startTick = CrateAudio.play(sndCfg, overrideVolume, overridePlaybackSpeed)
	return startTick
end

local function findEmblemDecal(model: Model): (Decal?, BasePart?)
	for _, desc in model:GetDescendants() do
		if desc:IsA("Decal") then
			local parent = desc.Parent
			if parent and parent:IsA("BasePart") then
				return desc, parent
			end
		end
	end
	return nil, nil
end

local function PlaceholderStage(scope: FusionScope, props: PlaceholderStageProps): Frame
	local crate = props.Crate
	local rarityColor = CratesConfig.getRarityColor(crate.rarity)

	local function resolveHighestRarity(): CrateRarity?
		if props.HighestRarity ~= nil then
			if typeof(props.HighestRarity) == "table" and (props.HighestRarity :: any).type == "State" then
				return Fusion.peek(props.HighestRarity :: any)
			end
			return props.HighestRarity :: CrateRarity?
		end
		if props.HasLegendary ~= nil then
			local leg = false
			if typeof(props.HasLegendary) == "table" and (props.HasLegendary :: any).type == "State" then
				leg = Fusion.peek(props.HasLegendary :: any) == true
			else
				leg = (props.HasLegendary :: any) == true
			end
			if leg then
				return "Legendary"
			end
		end
		return nil
	end

	local dimTransparency = scope:Value(1.0)
	local boxOpeningStage: Frame? = nil
	local seamController: RevealEffects.SeamBreachController? = nil

	local viewportHolder = scope:New("Frame")({
		Name = "ViewportHolder",
		Size = UDim2.fromOffset(560, 460),
		Position = UDim2.fromScale(0.5, 0.40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})

	local model = CrateModelCache.cloneModel(crate.modelName)
	if not model then
		CrateModelCache.waitForLoaded(2.5)
		model = CrateModelCache.cloneModel(crate.modelName)
	end

	local animActive = true
	local animThread: thread? = nil
	local activeTweens: { Tween } = {}
	local viewportRef: ViewportFrame? = nil
	local cloneModelRef: Model? = nil

	local stageCaption = scope:Value(if model then "UNLOCKING CRATE..." else "CRATE ASSET UNAVAILABLE")

	if model then
		debugLog(string.format("[PlaceholderStage] === MOUNTING CRATE: %s ===", crate.modelName))
		local viewport, cloneModel, crateCamDistance = CrateViewportFactory.create(model, {
			fov = 35,
			paddingMultiplier = crate.paddingMultiplier or 1.16,
			yawAngleDeg = crate.yawAngleDeg or 152,
			cameraElevationDeg = crate.cameraElevationDeg or 12,
			verticalOffset = 0.08,
			ambient = Color3.fromRGB(140, 140, 150),
			lightDirection = Vector3.new(-0.3, -0.8, -0.4),
		})
		viewportRef = viewport
		cloneModelRef = cloneModel
		viewport.Name = "CrateViewport"
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 3
		viewport.Parent = viewportHolder

		debugLog(`[PlaceholderStage] Clone instance rendered: {cloneModel:GetFullName()} (Parent: {cloneModel.Parent})`)

		if DEBUG_LOGGING then
			debugLog(string.format("[PlaceholderStage] Model '%s' Descendants:", cloneModel.Name))
			for _, desc in cloneModel:GetDescendants() do
				debugLog(`  - {desc.Name} (Class: {desc.ClassName}, Parent: {desc.Parent and desc.Parent.Name})`)
			end
		end

		for _, desc in cloneModel:GetDescendants() do
			if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") then
				desc:Destroy()
			end
		end

		local upperSection: PVInstance? = nil
		local bodySection: PVInstance? = nil
		local resolutionPath = "none"

		for _, child in cloneModel:GetChildren() do
			if child:IsA("Model") then
				local lower = string.lower(child.Name)
				if string.find(lower, "upper") or string.find(lower, "lid") or string.find(lower, "toppart") or lower == "top" then
					upperSection = child :: PVInstance
					break
				end
			end
		end

		if not upperSection then
			for _, child in cloneModel:GetChildren() do
				if child:IsA("BasePart") then
					local lower = string.lower(child.Name)
					if string.find(lower, "upper") or string.find(lower, "lid") or string.find(lower, "top") then
						upperSection = child :: PVInstance
						break
					end
				end
			end
		end

		if upperSection then
			for _, child in cloneModel:GetChildren() do
				if child ~= upperSection and (child:IsA("Model") or child:IsA("BasePart")) then
					bodySection = child :: PVInstance
					break
				end
			end
			resolutionPath = "name-match"
		else
			for _, descendant in cloneModel:GetDescendants() do
				if descendant.Name == "Cube.009" or descendant.Name == "Cube.008" then
					local child: Instance? = descendant
					while child and child.Parent ~= cloneModel do
						child = child.Parent
					end
					if child and child ~= descendant and (child:IsA("Model") or child:IsA("BasePart")) then
						if descendant.Name == "Cube.009" then
							upperSection = child :: PVInstance
						else
							bodySection = child :: PVInstance
						end
					end
				end
			end

			if not upperSection then
				local markerPart = cloneModel:FindFirstChild("Cube.009", true)
				if markerPart and markerPart:IsA("BasePart") then
					if markerPart.Parent and markerPart.Parent:IsA("Model") and markerPart.Parent ~= cloneModel then
						upperSection = markerPart.Parent
					else
						upperSection = markerPart
					end
				end
			end

			if not bodySection then
				local markerPart = cloneModel:FindFirstChild("Cube.008", true)
				if markerPart and markerPart:IsA("BasePart") then
					if markerPart.Parent and markerPart.Parent:IsA("Model") and markerPart.Parent ~= cloneModel then
						bodySection = markerPart.Parent
					else
						bodySection = markerPart
					end
				end
			end

			if upperSection or bodySection then
				resolutionPath = "marker-fallback"
			end
		end

		if upperSection then
			local lidModel: Model
			if upperSection:IsA("Model") then
				lidModel = upperSection :: Model
			else
				lidModel = Instance.new("Model")
				lidModel.Name = "ResolvedLidModel"
				lidModel.Parent = cloneModel
				upperSection.Parent = lidModel
				upperSection = lidModel
			end

			local lidNames: { [string]: boolean } = {
				toppartcover = true,
				toppartmain = true,
				toppartdecor = true,
				logo = true,
				cornerparts = true,
			}
			for _, desc in cloneModel:GetDescendants() do
				if desc:IsA("BasePart") and desc.Parent ~= lidModel and not desc:IsDescendantOf(lidModel) then
					local lower = string.lower(desc.Name)
					if lidNames[lower] or string.find(lower, "toppart") or string.find(lower, "lid") then
						desc.Parent = lidModel
					end
				end
			end
		end

		if upperSection then
			debugLog(
				string.format(
					"[PlaceholderStage] Successfully resolved Upper Section / Lid via [%s]: %s (Class: %s)",
					resolutionPath,
					upperSection:GetFullName(),
					upperSection.ClassName
				)
			)
		else
			warn(string.format("[PlaceholderStage] CRITICAL: Failed to resolve Upper Section / Lid! Crate '%s'. Lid pop will not animate.", crate.modelName))
		end

		if bodySection then
			debugLog(
				string.format(
					"[PlaceholderStage] Successfully resolved Body Section via [%s]: %s (Class: %s)",
					resolutionPath,
					bodySection:GetFullName(),
					bodySection.ClassName
				)
			)
		end

		local initialRootCF = cloneModel:GetPivot()
		local initialLidCF = if upperSection then upperSection:GetPivot() else initialRootCF
		debugLog(
			string.format(
				"[PlaceholderStage] Captured initialRootCF: Pos=(%.2f, %.2f, %.2f)",
				initialRootCF.Position.X,
				initialRootCF.Position.Y,
				initialRootCF.Position.Z
			)
		)
		debugLog(
			string.format(
				"[PlaceholderStage] Captured initialLidCF: Pos=(%.2f, %.2f, %.2f)",
				initialLidCF.Position.X,
				initialLidCF.Position.Y,
				initialLidCF.Position.Z
			)
		)

		local function getCorePart(container: PVInstance?): BasePart?
			if not container then
				return nil
			end
			local largest: BasePart? = nil
			local maxVol = 0
			for _, desc in container:GetDescendants() do
				if desc:IsA("BasePart") then
					local vol = desc.Size.X * desc.Size.Y * desc.Size.Z
					if vol > maxVol then
						maxVol = vol
						largest = desc
					end
				end
			end
			return largest
		end

		local lidCF: CFrame
		local lidSize: Vector3
		if upperSection then
			lidCF, lidSize = upperSection:GetBoundingBox()
		else
			lidCF = initialLidCF
			lidSize = Vector3.zero
		end

		local bodyCF: CFrame
		local bodySize: Vector3
		if bodySection then
			bodyCF, bodySize = bodySection:GetBoundingBox()
		else
			bodyCF = initialRootCF
			bodySize = Vector3.zero
		end

		local lidCenterLocal = initialLidCF:PointToObjectSpace(lidCF.Position)
		local coreBody = getCorePart(bodySection)
		local coreLid = getCorePart(upperSection)

		local hingeY: number
		local hingeZ: number

		if coreBody and coreLid then
			local coreBodyPosLocal = initialLidCF:PointToObjectSpace(coreBody.Position)
			local coreLidPosLocal = initialLidCF:PointToObjectSpace(coreLid.Position)
			hingeY = coreBodyPosLocal.Y + coreBody.Size.Y * 0.5
			hingeZ = coreLidPosLocal.Z + coreLid.Size.Z * 0.5
		else
			local bodyTopLocal = if bodySection
				then initialLidCF:PointToObjectSpace(bodyCF.Position).Y + bodySize.Y * 0.5
				else (lidCenterLocal.Y - lidSize.Y * 0.5)
			local bodyRearLocal = if bodySection
				then initialLidCF:PointToObjectSpace(bodyCF.Position).Z + bodySize.Z * 0.5
				else (lidCenterLocal.Z + lidSize.Z * 0.5)
			hingeY = math.max(lidCenterLocal.Y - lidSize.Y * 0.5, bodyTopLocal)
			hingeZ = math.max(lidCenterLocal.Z + lidSize.Z * 0.5, bodyRearLocal)
		end

		local hingeLocal = Vector3.new(lidCenterLocal.X, hingeY, hingeZ)

		local function getLidHingeTransform(tiltDeg: number): CFrame
			if tiltDeg == 0 then
				return CFrame.identity
			end
			return CFrame.new(hingeLocal) * CFrame.Angles(math.rad(tiltDeg), 0, 0) * CFrame.new(-hingeLocal)
		end

		local emblemDecal = findEmblemDecal(cloneModel)
		local initialDecalTransparency = if emblemDecal then emblemDecal.Transparency else 0.70

		animThread = task.spawn(function()
			xpcall(function()
				local waitStart = os.clock()
				local resolvedTier = resolveHighestRarity()
				while not resolvedTier and (os.clock() - waitStart) < 2.5 do
					task.wait(0.02)
					if not animActive then
						return
					end
					resolvedTier = resolveHighestRarity()
				end

				local finalTier: CrateRarity = resolvedTier or "Common"
				local isMythicVal = finalTier == "Mythic"
				local isLegendaryVal = finalTier == "Legendary"
				local isRareVal = finalTier == "Rare"
				debugLog(
					`[PlaceholderStage] Starting sequence with Escalation Tier: {finalTier} (isMythic={isMythicVal}, isLeg={isLegendaryVal}, isRare={isRareVal})`
				)

				local animCfg = CratesConfig.BOX_ANIMATIONS[crate.rarity] or CratesConfig.BOX_ANIMATIONS.Common
				local rareCfg = CratesConfig.BOX_ANIMATIONS.RareOverlay
				local legCfg = CratesConfig.BOX_ANIMATIONS.LegendaryOverlay

				local baseSeamCfg = animCfg.SeamBreach or {}
				local overlaySeamCfg = if (isMythicVal or isLegendaryVal) and legCfg.SeamBreach
					then legCfg.SeamBreach
					elseif isRareVal and rareCfg.SeamBreach then rareCfg.SeamBreach
					else nil

				local seamCfg = if overlaySeamCfg
					then {
						SeamWidth = math.max(baseSeamCfg.SeamWidth or 260, overlaySeamCfg.SeamWidth or 260),
						SeamYScale = baseSeamCfg.SeamYScale or overlaySeamCfg.SeamYScale or 0.452,
						MaxBreachHeight = overlaySeamCfg.MaxBreachHeight or baseSeamCfg.MaxBreachHeight or 16,
						GlowBloomWidth = math.max(baseSeamCfg.GlowBloomWidth or 340, overlaySeamCfg.GlowBloomWidth or 340),
						GlowBloomHeight = math.max(overlaySeamCfg.GlowBloomHeight or 75, baseSeamCfg.GlowBloomHeight or 75),
						BeamWidth = math.max(baseSeamCfg.BeamWidth or 140, overlaySeamCfg.BeamWidth or 140),
						BeamHeight = math.max(baseSeamCfg.BeamHeight or 420, overlaySeamCfg.BeamHeight or 420),
						BeamDuration = overlaySeamCfg.BeamDuration or baseSeamCfg.BeamDuration or 0.40,
						VignetteDuration = overlaySeamCfg.VignetteDuration or baseSeamCfg.VignetteDuration or 0.35,
						VignettePeakTransparency = overlaySeamCfg.VignettePeakTransparency or baseSeamCfg.VignettePeakTransparency or 0.80,
					}
					else baseSeamCfg

				local fov = 35
				local elevationDeg = crate.cameraElevationDeg or 12
				local camDist = crateCamDistance or 28
				local viewHeightStuds = 2 * camDist * math.tan(math.rad(fov * 0.5))
				local studsToYScale = math.cos(math.rad(elevationDeg)) / math.max(1, viewHeightStuds)

				local function getSeamYScale(bodyOffsetStuds: number?): number
					local offset = bodyOffsetStuds or 0
					return (seamCfg.SeamYScale or 0.452) + (-offset * studsToYScale)
				end

				local activeColor = CratesConfig.getRarityColor(finalTier)

				seamController = RevealEffects.createSeamBreach(viewportHolder, {
					color = activeColor,
					width = seamCfg.SeamWidth or 260,
					seamYScale = seamCfg.SeamYScale or 0.452,
					maxBreachHeight = seamCfg.MaxBreachHeight or 16,
					glowBloomWidth = seamCfg.GlowBloomWidth or 340,
					glowBloomHeight = seamCfg.GlowBloomHeight or 75,
					beamWidth = seamCfg.BeamWidth or 140,
					beamHeight = seamCfg.BeamHeight or 420,
					beamDuration = seamCfg.BeamDuration or 0.40,
				})

				if DEBUG_LOGGING and upperSection and viewport.CurrentCamera then
					local diagLidCF, diagLidSize = upperSection:GetBoundingBox()
					local seamWorldPos = diagLidCF.Position - Vector3.new(0, diagLidSize.Y * 0.5, 0)
					local screenPoint = viewport.CurrentCamera:WorldToViewportPoint(seamWorldPos)
					local viewportH = viewportHolder.Size.Y.Offset
					if viewportH > 0 then
						local measuredYScale = screenPoint.Y / viewportH
						debugLog(
							string.format(
								"[PlaceholderStage] Exact WorldToViewportPoint Seam: PixelY=%.1f / ViewportH=%.1f => Measured YScale=%.4f (Configured=%.4f, Delta=%.1fpx)",
								screenPoint.Y,
								viewportH,
								measuredYScale,
								seamCfg.SeamYScale or 0.452,
								(measuredYScale - (seamCfg.SeamYScale or 0.452)) * viewportH
							)
						)
					end
				end

				if isMythicVal or isLegendaryVal then
					debugLog(string.format("[PlaceholderStage] >>> Beat 0: High-tier Full UI Dim & Spotlight starting (tier=%s)...", finalTier))
					playSound(legCfg.Sounds and legCfg.Sounds.EscalationCharge)

					dimTransparency:set(legCfg.DimTransparency or 0.30)

					if emblemDecal then
						emblemDecal.Color3 = if isMythicVal then CratesConfig.getRarityColor("Mythic") else legCfg.EmblemFlashColor
					end
				elseif isRareVal then
					debugLog("[PlaceholderStage] >>> Beat 0: Rare Escalation detected (Gold seam tint)")
					playSound(rareCfg.Sounds and rareCfg.Sounds.EscalationCharge)
				end

				local shakeCfg = animCfg.Beat0_Shake
				if shakeCfg then
					debugLog("[PlaceholderStage] >>> Beat 0.5: Extended Anticipation Shakes starting...")
					stageCaption:set("UNLATCHING VAULT...")

					local p1Dur = shakeCfg.Pulse1_Duration or 0.10
					local p1Angle = shakeCfg.Pulse1_AngleDeg or 1.2
					playSound(animCfg.Sounds and animCfg.Sounds.AnticipationShake, 0.60, 0.95)
					local p1Start = os.clock()
					while (os.clock() - p1Start) < p1Dur do
						if not animActive then
							return
						end
						local a = (os.clock() - p1Start) / p1Dur
						local wave = math.sin(a * math.pi * 4)
						applyPivot(cloneModel, initialRootCF * CFrame.Angles(0, 0, math.rad(p1Angle * wave)))
						task.wait()
					end

					local p2Dur = shakeCfg.Pulse2_Duration or 0.14
					local p2Angle = shakeCfg.Pulse2_AngleDeg or 2.4
					playSound(animCfg.Sounds and animCfg.Sounds.AnticipationShake, 0.72, 1.12)
					local p2Start = os.clock()
					while (os.clock() - p2Start) < p2Dur do
						if not animActive then
							return
						end
						local a = (os.clock() - p2Start) / p2Dur
						local wave = math.sin(a * math.pi * 6)
						applyPivot(cloneModel, initialRootCF * CFrame.Angles(0, 0, math.rad(p2Angle * wave)))
						task.wait()
					end

					applyPivot(cloneModel, initialRootCF)
					if shakeCfg.Pause and shakeCfg.Pause > 0 then
						task.wait(shakeCfg.Pause)
					end
					if not animActive then
						return
					end
				end

				local settleDip = animCfg.Beat1_Settle.DipDistance
				local settleDuration = animCfg.Beat1_Settle.Duration
				debugLog(
					string.format("[PlaceholderStage] >>> Beat 1 START: Settle & Anticipation (Dip = %.2f studs, Duration = %.2fs)", settleDip, settleDuration)
				)
				stageCaption:set("UNLOCKING CRATE...")
				playSound(animCfg.Sounds and animCfg.Sounds.ChargeUp)

				local settleStartTime = os.clock()
				while (os.clock() - settleStartTime) < settleDuration do
					if not animActive then
						return
					end
					local alpha = math.clamp((os.clock() - settleStartTime) / settleDuration, 0, 1)
					local easeAlpha = math.sin(alpha * math.pi * 0.5)
					local currentDip = settleDip * easeAlpha

					applyPivot(cloneModel, CFrame.new(0, -currentDip, 0) * initialRootCF)

					if seamController then
						seamController.setAnticipation(easeAlpha, getSeamYScale(-currentDip))
					end

					if emblemDecal then
						local flashAlpha = math.sin(alpha * math.pi)
						local peakTrans = animCfg.Beat1_Settle.EmblemPeakTransparency
						emblemDecal.Transparency = initialDecalTransparency + (peakTrans - initialDecalTransparency) * flashAlpha
					end

					task.wait()
				end

				if not animActive then
					return
				end
				if emblemDecal then
					emblemDecal.Transparency = initialDecalTransparency
				end
				debugLog("[PlaceholderStage] <<< Beat 1 COMPLETE")

				if (isMythicVal or isLegendaryVal) and upperSection then
					debugLog("[PlaceholderStage] >>> Beat 1.5: High-tier Pre-Jerk & Deliberate Held Pause...")
					local jerkDist = legCfg.PreJerkDistance or 0.05
					local dipCF = CFrame.new(0, -settleDip, 0)
					applyPivot(upperSection, dipCF * CFrame.new(0, jerkDist, 0) * initialLidCF)
					task.wait(legCfg.PreJerkDuration or 0.08)
					if not animActive then
						return
					end
					applyPivot(upperSection, dipCF * initialLidCF)

					task.wait(legCfg.HeldJerkPause or 0.12)
					if not animActive then
						return
					end
				end

				local crackTilt = (animCfg.Beat2_LidPop and animCfg.Beat2_LidPop.CrackTiltDeg) or 0
				local crackDur = (animCfg.Beat2_LidPop and animCfg.Beat2_LidPop.CrackDuration) or 0
				local crackHold = (animCfg.Beat2_LidPop and animCfg.Beat2_LidPop.CrackHold) or 0

				if crackTilt > 0 and upperSection then
					debugLog(
						string.format(
							"[PlaceholderStage] >>> Unlatching Chest Crack: %.1f deg tilt around hinge (Z=%.2f, Y=%.2f)",
							crackTilt,
							hingeLocal.Z,
							hingeLocal.Y
						)
					)
					playSound(animCfg.Sounds and animCfg.Sounds.LidPop)
					local dipCF = CFrame.new(0, -settleDip, 0)
					local crackStart = os.clock()
					while (os.clock() - crackStart) < crackDur do
						if not animActive then
							return
						end
						local a = math.clamp((os.clock() - crackStart) / crackDur, 0, 1)
						local c = 1.15
						local ease = 1 + (c + 1) * math.pow(a - 1, 3) + c * math.pow(a - 1, 2)
						applyPivot(upperSection, dipCF * initialLidCF * getLidHingeTransform(crackTilt * ease))

						if seamController then
							seamController.setBreachProgress(math.clamp(a * 0.25, 0, 0.25), 1.0, getSeamYScale(-settleDip))
						end

						task.wait()
					end
					applyPivot(upperSection, dipCF * initialLidCF * getLidHingeTransform(crackTilt))
					if seamController then
						seamController.setBreachProgress(0.25, 1.0, getSeamYScale(-settleDip))
					end
					if crackHold > 0 then
						task.wait(crackHold)
					end
					if not animActive then
						return
					end
				end

				local extraLift = if isMythicVal or isLegendaryVal then (legCfg.LidEmphasisExtraLift or 0.15) else 0
				local popLift = animCfg.Beat2_LidPop.LiftDistance + extraLift
				local popDuration = animCfg.Beat2_LidPop.Duration
				local maxSwing = animCfg.Beat2_LidPop and animCfg.Beat2_LidPop.MaxSwingAngle
				debugLog(
					string.format(
						"[PlaceholderStage] >>> Beat 2 START: Lid Pop/Swing (Lift = %.2f studs, MaxSwing = %s, Duration = %.2fs, Tier = %s)",
						popLift,
						maxSwing,
						popDuration,
						finalTier
					)
				)
				stageCaption:set("OPENING CRATE...")
				if crackTilt == 0 then
					playSound(animCfg.Sounds and animCfg.Sounds.LidPop)
				end

				local popStartTime = os.clock()
				while (os.clock() - popStartTime) < popDuration do
					if not animActive then
						return
					end
					local alpha = math.clamp((os.clock() - popStartTime) / popDuration, 0, 1)

					local progress = if isRareVal or isLegendaryVal or isMythicVal then 1 - math.pow(1 - alpha, 3) else 1 - (1 - alpha) * (1 - alpha)

					local brightnessMult = 1.0
					if (isRareVal or isLegendaryVal or isMythicVal) and alpha >= 0.50 and alpha <= 0.92 then
						local freq = if isLegendaryVal or isMythicVal then 32 else 24
						local wave = math.sin((alpha - 0.50) * freq)
						brightnessMult = if wave > 0 then 1.45 else 0.35
					end

					local currentBodyDip = -settleDip * (1 - progress)
					applyPivot(cloneModel, CFrame.new(0, currentBodyDip, 0) * initialRootCF)

					if upperSection then
						if maxSwing then
							local currentAngle = crackTilt + (maxSwing - crackTilt) * progress
							local clearanceProgress = math.clamp((currentAngle - crackTilt) / (maxSwing - crackTilt), 0, 1)
							local clearanceCurve = clearanceProgress * clearanceProgress
							local clearanceLift = 0.15 * clearanceCurve
							local clearanceBack = 0.10 * clearanceCurve
							applyPivot(
								upperSection,
								CFrame.new(0, currentBodyDip + clearanceLift, clearanceBack) * initialLidCF * getLidHingeTransform(currentAngle)
							)
						else
							local currentLift = popLift * progress
							local currentTilt = crackTilt * (1 - progress)
							applyPivot(upperSection, CFrame.new(0, currentBodyDip + currentLift, 0) * initialLidCF * getLidHingeTransform(currentTilt))
						end
					end

					if seamController then
						seamController.setBreachProgress(progress, brightnessMult, getSeamYScale(currentBodyDip))
					end

					task.wait()
				end

				if not animActive then
					return
				end
				applyPivot(cloneModel, initialRootCF)
				debugLog("[PlaceholderStage] <<< Beat 2 COMPLETE")

				local revealClearLift = animCfg.Beat3_Reveal.ClearLiftDistance
				local revealDuration = animCfg.Beat3_Reveal.Duration
				local finalSwing = (animCfg.Beat3_Reveal and animCfg.Beat3_Reveal.FinalSwingAngle) or (maxSwing and (maxSwing + 14.0))
				debugLog(
					string.format(
						"[PlaceholderStage] >>> Beat 3 START: Reveal & Clear Lift (ClearLift = %.2f studs, FinalSwing = %s, Duration = %.2fs, Tier = %s)",
						revealClearLift,
						finalSwing,
						revealDuration,
						finalTier
					)
				)
				stageCaption:set("REVEALING REWARDS...")
				if seamController then
					seamController.triggerBurst(revealDuration, getSeamYScale(0))
				end
				playSound(animCfg.Sounds and animCfg.Sounds.Reveal)

				local revealStartTime = os.clock()
				while (os.clock() - revealStartTime) < revealDuration do
					if not animActive then
						return
					end
					local alpha = math.clamp((os.clock() - revealStartTime) / revealDuration, 0, 1)

					if upperSection then
						if maxSwing and finalSwing then
							local currentAngle = maxSwing + (finalSwing - maxSwing) * alpha
							local revealLift = 0.15 + (0.45 - 0.15) * alpha
							local revealBack = 0.10 + 0.05 * alpha
							applyPivot(upperSection, CFrame.new(0, revealLift, revealBack) * initialLidCF * getLidHingeTransform(currentAngle))
						else
							local currentLift = popLift + (revealClearLift - popLift) * alpha
							applyPivot(upperSection, CFrame.new(0, currentLift, 0) * initialLidCF)
						end

						if animCfg.Beat3_Reveal.FadeLid then
							for _, p in upperSection:GetDescendants() do
								if p:IsA("BasePart") then
									p.Transparency = math.clamp(alpha, 0, 1)
								end
							end
						end
					end

					task.wait()
				end

				if not animActive then
					return
				end

				if boxOpeningStage then
					RevealEffects.triggerVignetteFlash(boxOpeningStage, activeColor, seamCfg.VignetteDuration or 0.35, seamCfg.VignettePeakTransparency or 0.80)
				end

				debugLog(string.format("[PlaceholderStage] <<< Beat 3 COMPLETE - Sequence Finished! (Tier = %s)", finalTier))
			end, function(err)
				warn("[PlaceholderStage] CRITICAL RUNTIME ERROR in animation loop: " .. tostring(err) .. "\n" .. debug.traceback())
			end)
		end)
	end

	local isCleanedUp = false
	local function doCleanup()
		if isCleanedUp then
			return
		end
		isCleanedUp = true
		animActive = false
		if animThread then
			task.cancel(animThread)
			animThread = nil
		end
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
		if seamController then
			seamController.destroy()
			seamController = nil
		end
		if viewportRef then
			viewportRef:Destroy()
			viewportRef = nil
		end
		if cloneModelRef then
			cloneModelRef:Destroy()
			cloneModelRef = nil
		end
	end

	table.insert(scope, doCleanup)

	boxOpeningStage = scope:New("Frame")({
		Name = "BoxOpeningStage",
		Size = UDim2.fromOffset(600, 560),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,

		[Fusion.Children] = {
			viewportHolder,

			scope:New("Frame")({
				Name = "TextContainer",
				Size = UDim2.new(1, 0, 0, 60),
				Position = UDim2.fromScale(0.5, 0.86),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 5,

				[Fusion.Children] = {
					scope:New("TextLabel")({
						Name = "OpeningLabel",
						Size = UDim2.new(1, 0, 0, 24),
						Position = UDim2.fromScale(0, 0),
						BackgroundTransparency = 1,
						Text = stageCaption,
						TextColor3 = if model then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 90, 90),
						TextSize = 20,
						Font = Theme.Text.Black,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,

						[Fusion.Children] = {
							scope:New("UIStroke")({
								Color = Color3.fromRGB(0, 0, 0),
								Thickness = 1.5,
								Transparency = 0.4,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "CrateName",
						Size = UDim2.new(1, 0, 0, 18),
						Position = UDim2.fromOffset(0, 26),
						BackgroundTransparency = 1,
						Text = if model then string.upper(crate.name) else "Unable to load 3D model from ModelsService",
						TextColor3 = if model then rarityColor else Color3.fromRGB(180, 180, 190),
						TextSize = 13,
						Font = Theme.Text.Bold,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
				},
			}),
		},
	})

	local rootStage = scope:New("Frame")({
		Name = "PlaceholderStageRoot",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,

		[Fusion.Children] = {
			scope:New("Frame")({
				Name = "DimOverlay",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = dimTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),

			boxOpeningStage,
		},
	})

	rootStage.Destroying:Once(doCleanup)
	table.insert(
		scope,
		rootStage.AncestryChanged:Connect(function(_, parent)
			if not parent then
				doCleanup()
			end
		end)
	)

	return rootStage
end

return PlaceholderStage
