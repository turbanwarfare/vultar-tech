--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainModule = script.Parent.Parent.Parent.Parent
local Network = require(MainModule.Shared.Network)

local GunSkinUtils = {}

local function getSkinTemplatesFolder(): Folder?
	return ReplicatedStorage:FindFirstChild("SkinTemplates") :: Folder?
end

function GunSkinUtils.getSkinModel(skinId: string, gunName: string): Model?
	local templates = getSkinTemplatesFolder()
	if not templates then
		return nil
	end

	local skinFolder = templates:FindFirstChild(skinId)
	if not skinFolder then
		return nil
	end

	local model = skinFolder:FindFirstChild(gunName) :: Model?
	if not model then
		local GunStats = require(MainModule.Shared.Config.GunStats)
		local refGun = GunStats.get(gunName) and GunStats.get(gunName).SkinReferenceGun
		if refGun then
			model = skinFolder:FindFirstChild(refGun) :: Model?
		end
	end
	return model
end

function GunSkinUtils.cloneSkinnedTool(gunName: string, skinId: string): Tool?
	local toolTemplates = ReplicatedStorage:FindFirstChild("ToolTemplates")
	local template = toolTemplates and toolTemplates:FindFirstChild(gunName)
	if not template or not template:IsA("Tool") then
		return nil
	end

	local tool = template:Clone()
	local skinModel = if skinId ~= "Default" then GunSkinUtils.getSkinModel(skinId, gunName) else nil
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local oldGun = tool:FindFirstChild("GunModel") :: Model? or tool:FindFirstChildOfClass("Model")
	if not (skinModel and handle and oldGun) then
		return tool
	end

	local offsets: { [string]: CFrame } = {}
	for _, part in oldGun:GetDescendants() do
		if part:IsA("BasePart") then
			offsets[part.Name] = handle.CFrame:Inverse() * part.CFrame
		end
	end

	local newGun = skinModel:Clone()
	newGun.Name = "GunModel"

	local transform = handle.CFrame * newGun:GetPivot():Inverse()
	for _, part in newGun:GetDescendants() do
		if part:IsA("BasePart") and offsets[part.Name] then
			transform = handle.CFrame * offsets[part.Name] * part.CFrame:Inverse()
			break
		end
	end

	for _, desc in newGun:GetDescendants() do
		if desc:IsA("JointInstance") or desc:IsA("WeldConstraint") then
			desc:Destroy()
		end
	end
	local anchor = tool:FindFirstChild("BodyAttach") :: BasePart? or handle
	for _, part in newGun:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = transform * part.CFrame
			local weld = Instance.new("Weld")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.C0 = anchor.CFrame:Inverse() * part.CFrame
			weld.Parent = part
		end
	end

	newGun.Parent = tool
	oldGun:Destroy()
	return tool
end

function GunSkinUtils.skinHasGun(skinId: string, gunName: string): boolean
	return GunSkinUtils.getSkinModel(skinId, gunName) ~= nil
end

function GunSkinUtils.isOwnedFor(ownedItems: { [string]: boolean }?, skinId: string, gunName: string): boolean
	return ownedItems ~= nil and (ownedItems[skinId] == true or ownedItems[`{skinId}:{gunName}`] == true)
end

function GunSkinUtils.equipOnGuns(skinId: string, gunNames: { string }, ownedItems: { [string]: boolean }?): number
	local equipped = 0
	for _, gunName in gunNames do
		local allowed = skinId == "Default" or (GunSkinUtils.isOwnedFor(ownedItems, skinId, gunName) and GunSkinUtils.skinHasGun(skinId, gunName))
		if allowed then
			Network.Cosmetic.equip("GunSkin", `{skinId}:{gunName}`)
			equipped += 1
		end
	end
	return equipped
end

return GunSkinUtils
