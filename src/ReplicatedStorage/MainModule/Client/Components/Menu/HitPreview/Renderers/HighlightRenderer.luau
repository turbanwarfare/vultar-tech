--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local Constants = require(script.Parent.Parent.Constants)
local SettingsHelper = require(script.Parent.Parent.Utils.SettingsHelper)

export type HighlightData = {
	box: Model,
	cleanupTime: number,
}

export type HighlightState = {
	recentParts: { [BasePart]: number },
	activeHighlights: { HighlightData },
	highlightCount: number,
}

local HighlightRenderer = {}

function HighlightRenderer.createState(): HighlightState
	return {
		recentParts = {},
		activeHighlights = {},
		highlightCount = 0,
	}
end

local function createEdge(size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local edge = Instance.new("Part")
	edge.Name = "HighlightEdge"
	edge.Size = size
	edge.CFrame = cframe
	edge.Color = color
	edge.Material = Enum.Material.Neon
	edge.Transparency = 1
	edge.CanCollide = false
	edge.Anchored = true
	edge.CastShadow = false
	edge.Parent = parent
	return edge
end

function HighlightRenderer.show(state: HighlightState, part: BasePart, isHeadshot: boolean, worldModel: WorldModel): ()
	if not SettingsHelper.getSetting("HitHighlights") then
		return
	end

	local now = os.clock()
	local lastTime = state.recentParts[part]
	if lastTime and (now - lastTime) < Constants.HIGHLIGHT_DEBOUNCE then
		return
	end
	state.recentParts[part] = now

	local color = SettingsHelper.getHighlightColor(isHeadshot)
	local transparency = SettingsHelper.getSetting("HitHighlightTransparency") or 0.65
	local thickness = SettingsHelper.getSetting("HitHighlightThickness") or 0.04
	local fadeIn = SettingsHelper.getSetting("HitHighlightFadeIn") or 0.12
	local duration = SettingsHelper.getSetting("HitHighlightDuration") or 0.18

	local partCF = part.CFrame
	local sx, sy, sz = part.Size.X / 2 + 0.01, part.Size.Y / 2 + 0.01, part.Size.Z / 2 + 0.01
	local t = math.max(thickness, 0.02)

	local container = Instance.new("Model")
	container.Name = "HitHighlight"
	container.Parent = worldModel

	local edges = {}

	table.insert(edges, createEdge(Vector3.new(sx * 2, t, t), partCF * CFrame.new(0, sy, sz), color, container))
	table.insert(edges, createEdge(Vector3.new(sx * 2, t, t), partCF * CFrame.new(0, sy, -sz), color, container))
	table.insert(edges, createEdge(Vector3.new(sx * 2, t, t), partCF * CFrame.new(0, -sy, sz), color, container))
	table.insert(edges, createEdge(Vector3.new(sx * 2, t, t), partCF * CFrame.new(0, -sy, -sz), color, container))

	table.insert(edges, createEdge(Vector3.new(t, sy * 2, t), partCF * CFrame.new(sx, 0, sz), color, container))
	table.insert(edges, createEdge(Vector3.new(t, sy * 2, t), partCF * CFrame.new(sx, 0, -sz), color, container))
	table.insert(edges, createEdge(Vector3.new(t, sy * 2, t), partCF * CFrame.new(-sx, 0, sz), color, container))
	table.insert(edges, createEdge(Vector3.new(t, sy * 2, t), partCF * CFrame.new(-sx, 0, -sz), color, container))

	table.insert(edges, createEdge(Vector3.new(t, t, sz * 2), partCF * CFrame.new(sx, sy, 0), color, container))
	table.insert(edges, createEdge(Vector3.new(t, t, sz * 2), partCF * CFrame.new(sx, -sy, 0), color, container))
	table.insert(edges, createEdge(Vector3.new(t, t, sz * 2), partCF * CFrame.new(-sx, sy, 0), color, container))
	table.insert(edges, createEdge(Vector3.new(t, t, sz * 2), partCF * CFrame.new(-sx, -sy, 0), color, container))

	local tweenInfo = TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, edge in edges do
		local tween = TweenService:Create(edge, tweenInfo, { Transparency = transparency })
		tween:Play()
	end

	local cleanupTime = now + fadeIn + duration
	state.highlightCount += 1
	state.activeHighlights[state.highlightCount] = {
		box = container,
		cleanupTime = cleanupTime,
	}
end

function HighlightRenderer.update(state: HighlightState): ()
	local now = os.clock()
	local j = 1
	while j <= state.highlightCount do
		local data = state.activeHighlights[j]
		if now >= data.cleanupTime then
			if data.box then
				data.box:Destroy()
			end
			state.activeHighlights[j] = state.activeHighlights[state.highlightCount]
			state.activeHighlights[state.highlightCount] = nil :: any
			state.highlightCount -= 1
		else
			j += 1
		end
	end
end

function HighlightRenderer.cleanup(state: HighlightState): ()
	for i = 1, state.highlightCount do
		local data = state.activeHighlights[i]
		if data and data.box then
			data.box:Destroy()
		end
	end
	table.clear(state.activeHighlights)
	state.highlightCount = 0
	table.clear(state.recentParts)
end

return HighlightRenderer
