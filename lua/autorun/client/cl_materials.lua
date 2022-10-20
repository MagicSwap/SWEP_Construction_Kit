--Made this local since this file is now mirrored in the public SCK addon, where GM isn't guarunteed to exist in the load order
SCKMaterials = {}
SCKMaterialFavs = {}
SCKMaterialCompat = {
	["!sck_snow"] = "ground/snow01",
}

local conv_mat = {
	["lightmappedgeneric"] = true,
	["lightmappedgeneric_hdr_dx9"] = true,
	["lightmappedgeneric_dx9"] = true,
	["lightmappedgeneric_dx8"] = true,
	["lightmappedgeneric_dx6"] = true,

	["worldtwotextureblend"] = true,
	["worldtwotextureblend_dx8"] = true,
	["worldtwotextureblend_dx6"] = true,

	["worldvertextransition"] = true,
	["worldvertextransition_dx9"] = true,
	["worldvertextransition_dx8"] = true,
	["worldvertextransition_dx6"] = true,
}

function ConvertSCKMaterial(basetex)
	local mat = Material(basetex)

	local shader = mat:GetShader()

	shader = string.lower(shader)

	if not conv_mat[shader] then return basetex end

	local matfilename = string.GetFileFromFilename(basetex)
	local newname = "sck_"..matfilename --can create issues, but good for backwards compat
	local sp = mat:GetString("$surfaceprop") or "metal"
	local trans = mat:GetInt("$translucent") or 0
	local at = mat:GetInt("$alphatest") or 0

	local vta = mat:GetInt("$vertexalpha") or 0
	local vtc = mat:GetInt("$vertexcolor") or 0

	CreateMaterial(newname, "VertexLitGeneric",  {
		["$basetexture"] = basetex,
		["$surfaceprop"] = sp,
		["$translucent"] = trans,
		["$alphatest"] = at,
		["$vertexalpha"] = vta,
		["$vertexcolor"] = vtc,
	})

	SCKMaterials[basetex] = "!"..newname

	return SCKMaterials[basetex]
end

function AddMaterialFavorite(basetex, default)
	if default then --so we need to keep track of the defaults on new system, so old SCK that use !sck_ can be loaded
		local name = string.GetFileFromFilename(basetex)
		SCKMaterialCompat["!sck_"..name] = basetex
	end

	if default and SCKMaterialFavs[basetex] ~= nil then return end --Hack, maybe people don't like the defaults, don't readd every time
	SCKMaterialFavs[basetex] = default and 1 or 2

	if not default then
		SaveMaterialData()
	end
end

function RemoveMaterialFavorite(basetex)
	local cur = SCKMaterialFavs[basetex]

	if cur == 1 then --not the cleanest way, helps logic above work
		SCKMaterialFavs[basetex] = false
	else
		SCKMaterialFavs[basetex] = nil
	end

	SaveMaterialData()
end

function SaveMaterialData()
	file.Write("sck_materialfavs.dat", util.TableToJSON(SCKMaterialFavs, true))
end

function LoadMaterialData()
	if file.Exists("sck_materialfavs.dat", "DATA") then
		local info = file.Read("sck_materialfavs.dat", "DATA")

		SCKMaterialFavs = util.JSONToTable(info)
	end
end

LoadMaterialData()

--[[#############################
	#		SCK MATERIALS		#
	#############################]]

AddMaterialFavorite("brick/brickfloor001a", true)
AddMaterialFavorite("brick/brickwall001a", true)

AddMaterialFavorite("concrete/concreteceiling001a", true)
AddMaterialFavorite("concrete/concretefloor001a", true)
AddMaterialFavorite("concrete/milwall002", true)

AddMaterialFavorite("metal/metalfloor001a", true)
AddMaterialFavorite("metal/metalceiling005a", true)
AddMaterialFavorite("models/gibs/metalgibs/metal_gibs", true)
AddMaterialFavorite("phoenix_storms/dome", true)
AddMaterialFavorite("phoenix_storms/grey_steel", true)

AddMaterialFavorite("plaster/plasterceiling003a", true)
AddMaterialFavorite("plaster/plasterwall003a", true)
AddMaterialFavorite("plaster/plasterwall008a", true)

AddMaterialFavorite("stone/stonefloor011a", true)
AddMaterialFavorite("stone/stonewall036a", true)

AddMaterialFavorite("wood/woodfloor001a", true)
AddMaterialFavorite("wood/woodwall003a", true)
AddMaterialFavorite("wood/woodstair002c", true)
AddMaterialFavorite("wood/woodshelf001a", true)
AddMaterialFavorite("wood/woodshelf008a", true)

AddMaterialFavorite("nature/snowfloor002a", true)
AddMaterialFavorite("ground/snow01", true)

--##############################
