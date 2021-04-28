--Made this local since this file is now mirrored in the public SCK addon, where GM isn't guarunteed to exist in the load order
SCKMaterials = {}

function CreateSCKMaterial(name, basetex, mat, trans)
	name = tostring(name)
	basetex = tostring(basetex)
	mat = isstring(mat) and mat or "metal"

	CreateMaterial(name, "VertexLitGeneric", {
		["$basetexture"] = basetex,
		["$surfaceprop"] = mat,
		["$translucent"] = trans
	})

	table.insert(SCKMaterials, name)
end

--[[#############################
	#		SCK MATERIALS		#
	#############################]]

--BRICK
CreateSCKMaterial("sck_brickfloor001a", "brick/brickfloor001a", "brick")
CreateSCKMaterial("sck_brickwall001a", "brick/brickwall001a", "brick")

--CONCRETE
CreateSCKMaterial("sck_concreteceiling001a", "concrete/concreteceiling001a", "concrete")
CreateSCKMaterial("sck_concretefloor001a", "concrete/concretefloor001a", "concrete")

--GLASS

--METAL
CreateSCKMaterial("sck_metalfloor001a", "metal/metalfloor001a", "metal")
CreateSCKMaterial("sck_metalceiling005a", "metal/metalceiling005a", "metal")
CreateSCKMaterial("sck_metalgibs", "models/gibs/metalgibs/metal_gibs", "metal")
CreateSCKMaterial("sck_phoenixstorms_dome", "phoenix_storms/dome", "metal")
CreateSCKMaterial("sck_phoenixstorms_greysteel", "phoenix_storms/grey_steel", "metal")

--PLASTER
CreateSCKMaterial("sck_plasterceiling003a", "plaster/plasterceiling003a", "plaster")
CreateSCKMaterial("sck_plasterwall003a", "plaster/plasterwall003a", "plaster")
CreateSCKMaterial("sck_plasterwall008a", "plaster/plasterwall008a", "plaster")

--STONE
CreateSCKMaterial("sck_stonefloor011a", "stone/stonefloor011a", "stone")
CreateSCKMaterial("sck_stonewall036a", "stone/stonewall036a", "stone")

--WOOD
CreateSCKMaterial("sck_woodfloor001a", "wood/woodfloor001a", "wood")
CreateSCKMaterial("sck_woodwall003a", "wood/woodwall003a", "wood")
CreateSCKMaterial("sck_woodstair002c", "wood/woodstair002c", "wood")
CreateSCKMaterial("sck_woodshelf001a", "wood/woodshelf001a", "wood")
CreateSCKMaterial("sck_woodshelf008a", "wood/woodshelf008a", "wood")

--##############################
