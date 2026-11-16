--!strict
--!native
--!optimize 2

local MainModule = script.Parent.Parent.Parent.Parent.Parent
local ObjectPool = require(MainModule.Shared.Utils.State.ObjectPool)

local Constants = require(script.Parent.Parent.Constants)
local Cache = require(script.Parent.Parent.Cache)

local FeedbackPools = {}

local labelPool: ObjectPool.ObjectPool<TextLabel>? = nil
local billboardPool: ObjectPool.ObjectPool<BillboardGui>? = nil
local attachmentPool: ObjectPool.ObjectPool<Attachment>? = nil

local function createLabel(): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Cache.getDamageIndicatorFont()
	label.TextStrokeTransparency = 1

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Constants.Colors.Stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	return label
end

local function createBillboard(): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "DamageIndicator"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.StudsOffset = Vector3.zero
	bb.MaxDistance = 10000
	bb.ResetOnSpawn = false
	return bb
end

local function createAttachment(): Attachment
	local att = Instance.new("Attachment")
	att.Name = "DamageAnchor"
	return att
end

function FeedbackPools.init(): ()
	labelPool = ObjectPool.new({
		factory = createLabel,
		maxSize = Constants.Pool.MaxLabels,
		onReset = function(label: TextLabel)
			label.Text = ""
			label.TextTransparency = 1
			label.Parent = nil
		end,
		onDestroy = function(label: TextLabel)
			label:Destroy()
		end,
	})

	billboardPool = ObjectPool.new({
		factory = createBillboard,
		maxSize = Constants.Pool.MaxBillboards,
		onReset = function(bb: BillboardGui)
			bb.Enabled = false
			bb.Parent = nil
			bb.Adornee = nil
			if labelPool then
				local label = bb:FindFirstChildWhichIsA("TextLabel")
				while label do
					labelPool:returnToPool(label)
					label = bb:FindFirstChildWhichIsA("TextLabel")
				end
			end
		end,
		onDestroy = function(bb: BillboardGui)
			bb:Destroy()
		end,
	})

	attachmentPool = ObjectPool.new({
		factory = createAttachment,
		maxSize = Constants.Pool.MaxAttachments,
		onReset = function(att: Attachment)
			att.Parent = nil
			att.Position = Vector3.zero
		end,
		onDestroy = function(att: Attachment)
			att:Destroy()
		end,
	})

	labelPool:preWarm(15)
	billboardPool:preWarm(15)
	attachmentPool:preWarm(15)
end

function FeedbackPools.getLabel(textSize: number, color: Color3, font: Enum.Font?): TextLabel
	if not labelPool then
		FeedbackPools.init()
	end

	local label = labelPool:get()

	local stroke = label:FindFirstChild("Outline") :: UIStroke?
	if stroke then
		stroke.Thickness = Cache.getDamageIndicatorOutline()
		stroke.Transparency = 0
	end

	label.Font = font or Cache.getDamageIndicatorFont()
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextTransparency = 0
	label.Text = ""
	return label
end

function FeedbackPools.returnLabel(label: TextLabel): ()
	if labelPool then
		labelPool:returnToPool(label)
	end
end

function FeedbackPools.getBillboard(): BillboardGui
	if not billboardPool then
		FeedbackPools.init()
	end
	local bb = billboardPool:get()
	bb.Enabled = true
	return bb
end

function FeedbackPools.returnBillboard(bb: BillboardGui): ()
	if billboardPool then
		billboardPool:returnToPool(bb)
	end
end

function FeedbackPools.getAttachment(): Attachment
	if not attachmentPool then
		FeedbackPools.init()
	end
	return attachmentPool:get()
end

function FeedbackPools.returnAttachment(att: Attachment): ()
	if attachmentPool then
		attachmentPool:returnToPool(att)
	end
end

function FeedbackPools.cleanup(): ()
	if labelPool then
		labelPool:clear()
		labelPool = nil
	end
	if billboardPool then
		billboardPool:clear()
		billboardPool = nil
	end
	if attachmentPool then
		attachmentPool:clear()
		attachmentPool = nil
	end
end

return FeedbackPools
