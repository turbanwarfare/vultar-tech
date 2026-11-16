--!strict
--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local FadeGroup = {}

type FadeEntry = {
	object: Instance,
	property: string,
	base: number,
}

export type FadeGroup = {
	entries: { FadeEntry },
	value: NumberValue,
	tween: Tween?,
	connection: RBXScriptConnection,
}

local function apply(group: FadeGroup, alpha: number): ()
	for _, entry in group.entries do
		(entry.object :: any)[entry.property] = 1 - alpha * (1 - entry.base)
	end
end

local function addEntry(group: FadeGroup, object: Instance, property: string): ()
	local base = (object :: any)[property]
	if base < 1 then
		table.insert(group.entries, { object = object, property = property, base = base })
	end
end

local function addObject(group: FadeGroup, object: Instance): ()
	if object:IsA("GuiObject") then
		addEntry(group, object, "BackgroundTransparency")
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		addEntry(group, object, "TextTransparency")
	elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
		addEntry(group, object, "ImageTransparency")
	elseif object:IsA("UIStroke") then
		addEntry(group, object, "Transparency")
	end
end

function FadeGroup.new(): FadeGroup
	local value = Instance.new("NumberValue")
	value.Value = 1
	local group: FadeGroup = {
		entries = {},
		value = value,
		tween = nil,
		connection = nil :: any,
	}
	group.connection = value.Changed:Connect(function(alpha: number)
		apply(group, alpha)
	end)
	return group
end

function FadeGroup.capture(group: FadeGroup, roots: { GuiObject }): ()
	table.clear(group.entries)
	for _, root in roots do
		addObject(group, root)
		for _, descendant in root:GetDescendants() do
			addObject(group, descendant)
		end
	end
end

function FadeGroup.set(group: FadeGroup, alpha: number): ()
	if group.tween then
		group.tween:Cancel()
		group.tween = nil
	end
	group.value.Value = alpha
	apply(group, alpha)
end

function FadeGroup.tweenTo(group: FadeGroup, target: number, info: TweenInfo, onDone: (() -> ())?): ()
	if group.tween then
		group.tween:Cancel()
	end

	local tween = TweenService:Create(group.value, info, { Value = target })
	group.tween = tween
	if onDone then
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

function FadeGroup.destroy(group: FadeGroup): ()
	if group.tween then
		group.tween:Cancel()
		group.tween = nil
	end
	group.connection:Disconnect()
	group.value:Destroy()
	table.clear(group.entries)
end

return FadeGroup
