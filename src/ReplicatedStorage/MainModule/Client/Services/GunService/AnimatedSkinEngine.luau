--!strict
--!native
--!optimize 2

local RunService = game:GetService("RunService")

local MainModule = script.Parent.Parent.Parent.Parent

local AnimatedSkinEngine = {}

local CosmeticService: any = nil

local ALL_FACES: { Enum.NormalId } = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Right,
	Enum.NormalId.Left,
}

local TILE_SIZE = 3
local SCROLL_DURATION_U = 12
local SCROLL_DURATION_V = 20

type ScrollEntry = {
	tex: Texture,
	speedU: number,
	speedV: number,
	tileU: number,
	tileV: number,
	baseOffsetU: number,
	baseOffsetV: number,
}

local isActive = false
local activeScrolls: { ScrollEntry } = {}
local createdTextures: { Texture } = {}
local cachedParts: { BasePart } = {}
local savedTextureIds: { [BasePart]: string } = {}
local savedTextureOffsets: { [Texture]: { number } } = {}
local savedDecalTransparencies: { [Decal]: number } = {}
local removedSurfaceAppearances: { [BasePart]: SurfaceAppearance } = {}

local scrollConnection: RBXScriptConnection? = nil

local function runScrollUpdate()
	local now = os.clock()
	for _, entry in activeScrolls do
		entry.tex.OffsetStudsU = entry.baseOffsetU + (now * entry.speedU) % entry.tileU
		entry.tex.OffsetStudsV = entry.baseOffsetV + (now * entry.speedV) % entry.tileV
	end
end

local function ensureScrollRunning(): ()
	if not scrollConnection then
		scrollConnection = RunService.Heartbeat:Connect(runScrollUpdate)
	end
end

local function getCosmeticService(): any
	if CosmeticService then return CosmeticService end
	local ok, svc = pcall(require, MainModule.Client.Services.CosmeticService :: any)
	if ok and svc then
		CosmeticService = svc
	end
	return CosmeticService
end

local function isAnimatedSkinForGun(gunName: string): boolean
	local svc = getCosmeticService()
	if not svc or not svc.GetEquippedGunSkin then return false end
	return svc:GetEquippedGunSkin(gunName) == "Animated"
end

local function trackTexture(tex: Texture): ()
	table.insert(createdTextures, tex)
end

local function cacheParts(tool: Tool): ()
	local gunModel = tool:FindFirstChild("GunModel")
	if not gunModel then return end

	for _, child in gunModel:GetChildren() do
		if not child:IsA("BasePart") then continue end

		local hasTexture = false
		if child:IsA("MeshPart") and (child :: MeshPart).TextureID ~= "" then
			hasTexture = true
		end
		if not hasTexture then
			hasTexture = child:FindFirstChildWhichIsA("Texture") ~= nil
				or child:FindFirstChildWhichIsA("Decal") ~= nil
				or child:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil
		end

		if not hasTexture then continue end

		table.insert(cachedParts, child)
	end
end

local function collectScrollableTextures(part: BasePart): { Texture }
	local existing: { Texture } = {}
	for _, child in part:GetChildren() do
		if child:IsA("Texture") then
			table.insert(existing, child :: Texture)
		end
	end

	if #existing > 0 then
		for _, tex in existing do
			savedTextureOffsets[tex] = { tex.OffsetStudsU, tex.OffsetStudsV }
		end
		return existing
	end

	local assetId = ""

	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		local saTyped = sa :: SurfaceAppearance
		assetId = saTyped.ColorMap
		saTyped.Parent = nil
		removedSurfaceAppearances[part] = saTyped
	end

	if assetId == "" then
		for _, child in part:GetChildren() do
			if not child:IsA("Decal") then continue end
			local decal = child :: Decal
			if decal.Texture == "" then continue end
			if assetId == "" then
				assetId = decal.Texture
			end
			savedDecalTransparencies[decal] = decal.Transparency
			decal.Transparency = 1
		end
	end

	if assetId == "" and part:IsA("MeshPart") then
		local mp = part :: MeshPart
		if mp.TextureID ~= "" then
			assetId = mp.TextureID
			savedTextureIds[part] = mp.TextureID
			mp.TextureID = ""
		end
	end

	if assetId == "" then return {} end

	local created: { Texture } = {}
	for _, face in ALL_FACES do
		local tex = Instance.new("Texture")
		tex.Face = face
		tex.Texture = assetId
		tex.Transparency = 0
		tex.StudsPerTileU = TILE_SIZE
		tex.StudsPerTileV = TILE_SIZE
		tex.Parent = part
		trackTexture(tex)
		table.insert(created, tex)
	end
	return created
end

local function setupScrollingTextures(): ()
	for _, part in cachedParts do
		local textures = collectScrollableTextures(part)

		for _, tex in textures do
			local tileU = tex.StudsPerTileU
			local tileV = tex.StudsPerTileV
			if tileU <= 0 then
				tileU = TILE_SIZE
			end
			if tileV <= 0 then
				tileV = TILE_SIZE
			end

			local speedU = tileU / SCROLL_DURATION_U
			local speedV = tileV / SCROLL_DURATION_V

			local entry: ScrollEntry = {
				tex = tex,
				speedU = speedU,
				speedV = speedV,
				tileU = tileU,
				tileV = tileV,
				baseOffsetU = tex.OffsetStudsU,
				baseOffsetV = tex.OffsetStudsV,
			}
			table.insert(activeScrolls, entry)
		end
	end

	if #activeScrolls > 0 then
		ensureScrollRunning()
	end
end

local function restoreOriginals(): ()
	for part, texId in savedTextureIds do
		if part:IsA("MeshPart") then
			(part :: MeshPart).TextureID = texId
		end
	end
	table.clear(savedTextureIds)

	for tex, offsets in savedTextureOffsets do
		tex.OffsetStudsU = offsets[1]
		tex.OffsetStudsV = offsets[2]
	end
	table.clear(savedTextureOffsets)

	for decal, transparency in savedDecalTransparencies do
		decal.Transparency = transparency
	end
	table.clear(savedDecalTransparencies)

	for part, sa in removedSurfaceAppearances do
		sa.Parent = part
	end
	table.clear(removedSurfaceAppearances)
end

local function destroyEffects(): ()
	isActive = false

	if scrollConnection then
		scrollConnection:Disconnect()
		scrollConnection = nil
	end
	table.clear(activeScrolls)

	for _, tex in createdTextures do
		tex:Destroy()
	end
	table.clear(createdTextures)

	restoreOriginals()

	table.clear(cachedParts)
end

function AnimatedSkinEngine.onEquip(tool: Tool): ()
	if isActive then
		destroyEffects()
	end
	if not isAnimatedSkinForGun(tool.Name) then return end

	cacheParts(tool)
	if #cachedParts == 0 then return end

	isActive = true
	setupScrollingTextures()
end

function AnimatedSkinEngine.onUnequip(): ()
	if not isActive then return end
	destroyEffects()
end

function AnimatedSkinEngine.init(): ()
	CosmeticService = nil
end

function AnimatedSkinEngine.cleanup(): ()
	destroyEffects()
	CosmeticService = nil
end

return AnimatedSkinEngine
