
include("glon.lua")

surface.CreateFont("12ptFont", {font = "Arial", size = 12, width = 500, antialias = true, additive = false})
surface.CreateFont("24ptFont", {font = "Arial", size = 24, width = 500, antialias = true, additive = false})

SWEP.selectedElement = ""
SWEP.useThirdPerson = false
SWEP.lockRelativePositions = false
SWEP.thirdPersonAngle = Angle(0,-90,0)
SWEP.thirdPersonAngleView = Angle( 0, 0, 0 )
SWEP.thirdPersonDis = 100
SWEP.mlast_x = ScrW()/2
SWEP.mlast_y = ScrH()/2

local playerBones = {
	"ValveBiped.Bip01_Head1",
	"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_Spine",
	"ValveBiped.Bip01_Spine1",
	"ValveBiped.Bip01_Spine2",
	"ValveBiped.Bip01_Spine4",
	"ValveBiped.Anim_Attachment_RH",
	"ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_R_UpperArm",
	"ValveBiped.Bip01_R_Clavicle",
	"ValveBiped.Bip01_R_Foot",
	"ValveBiped.Bip01_R_Toe0",
	"ValveBiped.Bip01_R_Thigh",
	"ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_R_Shoulder",
	"ValveBiped.Bip01_R_Elbow",
	"ValveBiped.Bip01_Neck1",
	"ValveBiped.Anim_Attachment_LH",
	"ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_L_Forearm",
	"ValveBiped.Bip01_L_UpperArm",
	"ValveBiped.Bip01_L_Clavicle",
	"ValveBiped.Bip01_L_Foot",
	"ValveBiped.Bip01_L_Toe0",
	"ValveBiped.Bip01_L_Thigh",
	"ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_L_Shoulder",
	"ValveBiped.Bip01_L_Elbow"
	}

local model_drag_modes = {
	//["_x /y |z"] = { "x", "z", "y", "p", "r", "y" }, // this one is bad
	["_y /x |z"] = { "y", "z", "x", "y", "r", "p" },
	["view space"] = { "y", "z", "x", "y", "r", "p", vs = true },
}

SWEP.selectedModelDragMode = "view space"
SWEP.selectedModelDragPrecision = 0.01
SWEP.ModelDragAngleSnap = 0

SWEP.v_models = {}
SWEP.v_panelCache = {}
SWEP.v_modelListing = nil
SWEP.v_bonemods = {}
SWEP.v_modelbonebox = nil

SWEP.w_models = {}
SWEP.w_panelCache = {}
SWEP.w_modelListing = nil

SWEP.world_model = nil
SWEP.cur_wmodel = nil

SWEP.browser_callback = nil
SWEP.modelbrowser = nil
SWEP.modelbrowser_list = nil
SWEP.matbrowser = nil
SWEP.matbrowser_list = nil

SWEP.tpsfocusbone = "ValveBiped.Bip01_R_Hand"

SWEP.save_data = {}
local save_data_template = {
	ViewModel = SWEP.ViewModel,
	CurWorldModel = SWEP.CurWorldModel,
	w_models = {},
	v_models = {},
	v_bonemods = {},
	ViewModelFOV = SWEP.ViewModelFOV,
	HoldType = SWEP.HoldType,
	ViewModelFlip = SWEP.ViewModelFlip,
	UseHands = SWEP.UseHands,
	IronSightsEnabled = true,
	IronSightsPos = SWEP.IronSightsPos,
	IronSightsAng = SWEP.IronSightsAng,
	ShowViewModel = true,
	ShowWorldModel = true
}

SWEP.ir_drag = {
	x = { true, "-x", 25 },
	y = { false, "y", 25 },
	z = { true, "y", 25 },
	pitch = { false, "y", 10 },
	yaw = { false, "x", 10 },
	roll = { false, "y", 10 }
}

SWEP.Frame = nil
SWEP.cur_drag_mode = "x / z"

function SWEP:ClientInit()
	SCKDebug("Client init start")

	if (IsValid(self:GetOwner())) then
		-- init view model bone mods
		local vm = self:GetOwner():GetViewModel()
		if IsValid(vm) then
			self:ResetBonePositions(vm)
		end
	end
end

function SimplePanel( parent, scroll )
	local p = vgui.Create( scroll and "DScrollPanel" or "DPanel", parent)
	p.Paint = function() end
	if parent._passdata then
		p._passdata = table.Copy(parent._passdata)
	end
	return p
end

function PrintVec( vec )
	local px, py, pz = vec.x, vec.y, vec.z

	px = math.Round(px, 5)
	py = math.Round(py, 5)
	pz = math.Round(pz, 5)

	return "Vector("..px..", "..py..", "..pz..")"
end

function PrintAngle( angle )
	local pp, py, pr = angle.p, angle.y, angle.r

	pp = math.Round(pp, 5)
	py = math.Round(py, 5)
	pr = math.Round(pr, 5)

	return "Angle("..pp..", "..py..", "..pr..")"
end

function PrintColor( col )
	return "Color("..col.r..", "..col.g..", "..col.b..", "..col.a..")"
end

-- We can't expect Garry to do all the work
local function ResolveInvalidBones( self )
	for k, v in pairs( self.Choices ) do
		if self.Data[ k ] and v == "__INVALIDBONE__" then
			local ent = self.Data[ k ].ent
			local bone = self.Data[ k ].bone_id
			local name = ent:GetBoneName( bone )
			if ent:LookupBone( name ) then
				self.Choices[ k ] = name
			end
		end
	end
end

-- Populates a DChoiceList with all the bones of the specified entity
-- returns if it has a first option
function PopulateBoneList( choicelist, ent )
	if (!IsValid(choicelist)) then return false end
	if (!IsValid(ent)) then return end

	SCKDebug("Populating bone list for entity "..tostring(ent))

	choicelist:Clear()

	if not choicelist.ResolveInvalidBones then
		local oldOpen = choicelist.OpenMenu
		choicelist.ResolveInvalidBones = ResolveInvalidBones

		choicelist.OpenMenu = function( self )
			self:ResolveInvalidBones()
			oldOpen( self )
		end
	end

	if (ent == LocalPlayer()) then
		-- if the local player is in third person, his bone lookup is all messed up so
		-- we just use the predefined playerBones table
		for i = 0, ent:GetBoneCount() - 1 do
			local name = ent:GetBoneName(i)
			if (ent:LookupBone(name)) then
				choicelist:AddChoice(name)
			end
		end

		return true
	else
		local hasfirstoption
		for i = 0, ent:GetBoneCount() - 1 do
			local name = ent:GetBoneName(i)
			if ent:LookupBone(name) then -- filter out invalid bones
				choicelist:AddChoice(name)
				if (!firstoption) then hasfirstoption = true end
			else
				if name == "__INVALIDBONE__" then -- store the unknown bone and see if it can be fixed later
					choicelist:AddChoice(name, { ent = ent, bone_id = i })
					if (!firstoption) then hasfirstoption = true end
				end
			end
		end

		return hasfirstoption
	end
end

function SWEP:CreateWeaponWorldModel()
	local model = self.CurWorldModel
	SCKDebug("Creating weapon world model")

	if ((!self.world_model or (IsValid(self.world_model) and self.cur_wmodel != model)) and
		string.find(model, ".mdl") and file.Exists(model,"GAME") ) then

		if IsValid(self.world_model) then self.world_model:Remove() end
		self.world_model = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
		if (IsValid(self.world_model)) then
			self.world_model:SetParent(self:GetOwner())
			self.world_model:SetNoDraw(true)
			self.cur_wmodel = model
			if (self.world_model:LookupBone( "ValveBiped.Bip01_R_Hand" )) then
				self.world_model:AddEffects(EF_BONEMERGE)
			end
		else
			self.world_model = nil
			self.cur_wmodel = nil
		end
	end
end

function SWEP:CreateModels( tab )
	--if true then return end
	-- Create the clientside models here because Garry says we can't do it in the render hook
	for k, v in pairs( tab ) do
		if (v.type == "Model" and v.model and v.model != "" and (!IsValid(v.modelEnt) or v.createdModel != v.model) and
				string.find(v.model, ".mdl") and file.Exists(v.model,"GAME") ) then

			SCKDebug("Creating new ClientSideModel "..v.model)

			v.modelEnt = ClientsideModel(v.model, RENDERGROUP_TRANSLUCENT)
			if (IsValid(v.modelEnt)) then
				v.modelEnt:SetPos(self:GetPos())
				v.modelEnt:SetAngles(self:GetAngles())
				v.modelEnt:SetParent(self)
				v.modelEnt:SetNoDraw(true)
				--v.modelEnt:SetRenderMode( RENDERMODE_TRANSCOLOR )
				v.createdModel = v.model
			else
				v.modelEnt = nil
			end

		elseif (v.type == "Sprite" and v.sprite and v.sprite != "" and (!v.spriteMaterial or v.createdSprite != v.sprite) and file.Exists("materials/"..v.sprite..".vmt", "GAME")) then

			SCKDebug("Creating new sprite "..v.sprite)

			local name = v.sprite.."-"
			local params = { ["$basetexture"] = v.sprite }
			-- make sure we create a unique name based on the selected options
			local tocheck = { "nocull", "additive", "vertexalpha", "vertexcolor", "ignorez" }
			for i, j in pairs( tocheck ) do
				if (v[j]) then
					params["$"..j] = 1
					name = name.."1"
				else
					name = name.."0"
				end
			end

			v.createdSprite = v.sprite
			v.spriteMaterial = CreateMaterial(name,"UnlitGeneric",params)
		end
	end
end

function SWEP:Think()
	self:CreateModels( self.v_models )
	self:CreateModels( self.w_models )

	-- Some hacky shit to get 3rd person view compatible with
	-- other addons that override CalcView
	self:CalcViewHookManagement()

	--[[***********************
		Camera fiddling
	***********************]]
	self.useThirdPerson = self:GetThirdPerson()

	local mx, my = gui.MousePos()
	local diffx, diffy = (mx - self.mlast_x), (my - self.mlast_y)

	// model positioning

	local element_mode = input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_LSHIFT )
	local vm = self:GetOwner():GetViewModel()

	if element_mode and self.Frame and self.Frame:IsVisible() then
		local tbl = self.useThirdPerson and self.w_models or self.v_models
		local ent = self.useThirdPerson and self:GetOwner() or vm

		if not (tbl and tbl[ self.selectedElement ] and tbl[ self.selectedElement ].pos) then return end

		local cur_mode = model_drag_modes[ self.selectedModelDragMode ]

		if not cur_mode then return end

		local cur_el = tbl[ self.selectedElement ]

		if input.IsMouseDown(MOUSE_RIGHT) then
			if input.IsMouseDown(MOUSE_LEFT) then
				if input.IsKeyDown( KEY_LCONTROL ) then
					if cur_mode.vs and IsValid( ent ) then
						local p_pos, p_ang = self:GetBoneOrientation( tbl, self.selectedElement, ent )

						local thirdperson_ang = self.thirdPersonAngleView * 1
						//thirdperson_ang.y = thirdperson_ang.y + 90

						local view_ang = self.useThirdPerson and thirdperson_ang or LocalPlayer():EyeAngles()

						local offset_pos = p_pos - view_ang:Forward() * diffy * self.selectedModelDragPrecision

						offset_pos = WorldToLocal( offset_pos, view_ang, p_pos, p_ang )
						offset_pos.y = offset_pos.y * -1

						cur_el.pos = cur_el.pos + offset_pos
					else
						cur_el.pos[ cur_mode[ 3 ] ] = cur_el.pos[ cur_mode[ 3 ] ] - diffy * self.selectedModelDragPrecision
					end
				else
					if not tbl[ self.selectedElement ].angle then return end

					local y_value = self.ModelDragAngleSnap > 0 and math.Round( ( diffy * self.ModelDragAngleSnap * self.selectedModelDragPrecision * 30 ) / self.ModelDragAngleSnap ) * self.ModelDragAngleSnap or diffy * self.selectedModelDragPrecision * 10

					if cur_mode.vs and IsValid( ent ) then
						local p_pos, p_ang = self:GetBoneOrientation( tbl, self.selectedElement, ent )
						local el_pos = p_pos + p_ang:Forward() * cur_el.pos.x + p_ang:Right() * cur_el.pos.y + p_ang:Up() * cur_el.pos.z

						local thirdperson_ang = self.thirdPersonAngleView * 1
						local view_ang = self.useThirdPerson and thirdperson_ang or LocalPlayer():EyeAngles()

						local offset_ang = p_ang * 1
						offset_ang:RotateAroundAxis( view_ang:Forward(), y_value )

						local _, offset_ang = WorldToLocal( el_pos, offset_ang, p_pos, p_ang )
						offset_ang.p = offset_ang.p * -1

						cur_el.angle = cur_el.angle + offset_ang

						cur_el.angle.p = math.NormalizeAngle( cur_el.angle.p )
						cur_el.angle.y = math.NormalizeAngle( cur_el.angle.y )
						cur_el.angle.r = math.NormalizeAngle( cur_el.angle.r )

					else
						cur_el.angle[ cur_mode[ 6 ] ] = math.NormalizeAngle( cur_el.angle[ cur_mode[ 6 ] ] - y_value )
					end
				end
			else
				if input.IsKeyDown( KEY_LCONTROL ) then
					// AAAAAAAAAaaaaaaaaaaaaaaaa
					if cur_mode.vs and IsValid( ent ) then
						local p_pos, p_ang = self:GetBoneOrientation( tbl, self.selectedElement, ent )

						if not p_pos then return end

						local thirdperson_ang = self.thirdPersonAngleView * 1

						local view_ang = self.useThirdPerson and thirdperson_ang or LocalPlayer():EyeAngles()

						local offset_pos = p_pos + view_ang:Right() * diffx * self.selectedModelDragPrecision - view_ang:Up() * diffy * self.selectedModelDragPrecision

						offset_pos = WorldToLocal( offset_pos, view_ang, p_pos, p_ang )
						offset_pos.y = offset_pos.y * -1

						cur_el.pos = cur_el.pos + offset_pos
					else
						cur_el.pos[ cur_mode[ 1 ] ] = cur_el.pos[ cur_mode[ 1 ] ] - diffx * self.selectedModelDragPrecision
						cur_el.pos[ cur_mode[ 2 ] ] = cur_el.pos[ cur_mode[ 2 ] ] + diffy * self.selectedModelDragPrecision
					end
				else
					if tbl[ self.selectedElement ].angle then

						local x_value = self.ModelDragAngleSnap > 0 and math.Round( ( diffx * self.ModelDragAngleSnap * self.selectedModelDragPrecision * 30 ) / self.ModelDragAngleSnap ) * self.ModelDragAngleSnap or diffx * self.selectedModelDragPrecision * 10
						local y_value = self.ModelDragAngleSnap > 0 and math.Round( ( diffy * self.ModelDragAngleSnap * self.selectedModelDragPrecision * 30 ) / self.ModelDragAngleSnap ) * self.ModelDragAngleSnap or diffy * self.selectedModelDragPrecision * 10

						if cur_mode.vs and IsValid( ent ) then
							local p_pos, p_ang = self:GetBoneOrientation( tbl, self.selectedElement, ent )
							local el_pos = p_pos + p_ang:Forward() * cur_el.pos.x + p_ang:Right() * cur_el.pos.y + p_ang:Up() * cur_el.pos.z

							local thirdperson_ang = self.thirdPersonAngleView * 1
							local view_ang = self.useThirdPerson and thirdperson_ang or LocalPlayer():EyeAngles()

							local offset_ang = p_ang * 1
							offset_ang:RotateAroundAxis( view_ang:Up(), x_value )
							offset_ang:RotateAroundAxis( view_ang:Right(), y_value )

							local _, offset_ang = WorldToLocal( el_pos, offset_ang, p_pos, p_ang )
							offset_ang.p = offset_ang.p * -1

							cur_el.angle = cur_el.angle + offset_ang

							cur_el.angle.p = math.NormalizeAngle( cur_el.angle.p )
							cur_el.angle.y = math.NormalizeAngle( cur_el.angle.y )
							cur_el.angle.r = math.NormalizeAngle( cur_el.angle.r )

						else
							cur_el.angle[ cur_mode[ 4 ] ] = math.NormalizeAngle( cur_el.angle[ cur_mode[ 4 ] ] - x_value )
							cur_el.angle[ cur_mode[ 5 ] ] = math.NormalizeAngle( cur_el.angle[ cur_mode[ 5 ] ] + y_value )
						end
					end
				end
			end

		end

		if input.WasMousePressed( MOUSE_WHEEL_UP ) then
			self.selectedModelDragPrecision = math.Clamp( self.selectedModelDragPrecision + 0.001, 0.005, 0.3 )
		end

		if input.WasMousePressed( MOUSE_WHEEL_DOWN ) then
			self.selectedModelDragPrecision = math.Clamp( self.selectedModelDragPrecision - 0.001, 0.001, 0.3 )
		end

	else
		// normal ironsights and stuff
		if (input.IsMouseDown(MOUSE_RIGHT) and !(diffx > 40 or diffy > 40) and self.Frame and self.Frame:IsVisible()) then -- right mouse press without sudden jumps

			if (self.useThirdPerson) then

				if (input.IsKeyDown(KEY_E)) then
					self.thirdPersonDis = math.Clamp( self.thirdPersonDis + diffy, 10, 500 )
				else
					local invx = GetConVar("swepck_thirdperson_invx"):GetInt() ~= 0 and -1 or 1
					local invy = GetConVar("swepck_thirdperson_invy"):GetInt() ~= 0 and -1 or 1
					self.thirdPersonAngle = self.thirdPersonAngle + Angle( diffy/2 * invy, diffx/2 * invx, 0 )
				end

			else
				-- ironsight adjustment
				for k, v in pairs( self.ir_drag ) do
					if (v[1]) then
						local temp = GetConVar( "_sp_ironsight_"..k ):GetFloat()
						if (v[2] == "x") then
							local add = -(diffx/v[3])
							if (self.ViewModelFlip) then add = add*-1 end
							RunConsoleCommand( "_sp_ironsight_"..k, temp + add )
						elseif (v[2] == "-x") then
							local add = diffx/v[3]
							if (self.ViewModelFlip) then add = add*-1 end
							RunConsoleCommand( "_sp_ironsight_"..k, temp + add )
						elseif (v[2] == "y") then
							RunConsoleCommand( "_sp_ironsight_"..k, temp - diffy/v[3] )
						end
					end
				end

			end

		end
	end

	self.mlast_x, self.mlast_y = mx, my
end

function SWEP:RemoveModels()
	SCKDebug("Removing models")

	for k, v in pairs( self.v_models ) do
		if (IsValid( v.modelEnt )) then v.modelEnt:Remove() end
	end
	for k, v in pairs( self.w_models ) do
		if (IsValid( v.modelEnt )) then v.modelEnt:Remove() end
	end
	self.v_models = {}
	self.w_models = {}

	if (IsValid(self.world_model)) then
		self.world_model:Remove()
		self.world_model = nil
		self.cur_wmodel = nil
	end
end

function SWEP:GetBoneOrientation( basetab, name, ent, bone_override, buildup )
	local bone, pos, ang
	local tab = basetab[name]
	if tab.rel and tab.rel ~= "" and basetab[tab.rel] then
		local v = basetab[tab.rel]

		if (!v) then return end

		if (!buildup) then
			buildup = {}
		end

		table.insert(buildup, name)
		if (table.HasValue(buildup, tab.rel)) then return end

		-- Technically, if there exists an element with the same name as a bone
		-- you can get in an infinite loop. Let's just hope nobody's that stupid.
		pos, ang = self:GetBoneOrientation( basetab, tab.rel, ent, nil, buildup )

		if (!pos) then return end

		pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
		if (v.angle) then
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)
		end
	else
		bone = ent:LookupBone(bone_override or tab.bone)
		if (!bone) then return end

		pos, ang = Vector(0,0,0), Angle(0,0,0)
		local m = ent:GetBoneMatrix(bone)
		if (m) then
			pos, ang = m:GetTranslation(), m:GetAngles()
		end

		if (IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() and
			ent == self:GetOwner():GetViewModel() and self.ViewModelFlip) then
			ang.r = -ang.r -- Fixes mirrored models
		end
	end

	return pos, ang
end

-- same as above, except it should return the bone name that started it all (but not the root bone)
function SWEP:GetElementRootBonename( basetab, name, ent, buildup )
	local bonename
	local tab = basetab[name]

	if (tab.rel and tab.rel ~= "") then
		local v = basetab[tab.rel]
		if (!v) then return end

		if (!buildup) then
			buildup = {}
		end

		table.insert(buildup, name)
		if (table.HasValue(buildup, tab.rel)) then return end

		bonename = self:GetElementRootBonename( basetab, tab.rel, ent, buildup )
	else
		bonename = tab.bone
	end

	return bonename or "none"
end


local allbones
local hasGarryFixedBoneScalingYet = true

function SWEP:UpdateBonePositions(vm)
	if self.v_bonemods then
		if (!vm:GetBoneCount()) then return end

		-- !! WORKAROUND !! --
		-- We need to check all model names :/
		local loopthrough = self.v_bonemods
		if (!hasGarryFixedBoneScalingYet) then
			allbones = {}
			for i=0, vm:GetBoneCount() do
				local bonename = vm:GetBoneName(i)
				if (self.v_bonemods[bonename]) then
					allbones[bonename] = self.v_bonemods[bonename]
				else
					allbones[bonename] = {
						scale = Vector(1,1,1),
						pos = Vector(0,0,0),
						angle = Angle(0,0,0)
					}
				end
			end

			loopthrough = allbones
		end
		-- !! ----------- !! --

		for k, v in pairs( loopthrough ) do
			local bone = vm:LookupBone(k)
			if (!bone) then continue end

			-- !! WORKAROUND !! --
			local s = Vector(v.scale.x,v.scale.y,v.scale.z)
			local p = Vector(v.pos.x,v.pos.y,v.pos.z)
			local ms = Vector(1,1,1)
			if (!hasGarryFixedBoneScalingYet) then
				local cur = vm:GetBoneParent(bone)
				while(cur >= 0) do
					local pscale = loopthrough[vm:GetBoneName(cur)].scale
					ms = ms * pscale
					cur = vm:GetBoneParent(cur)
				end
			end

			--local bpos = vm:GetBonePosition(bone)
			--local par = vm:GetBoneParent(bone)
			s = s * ms

			--SCKDebug("Bone ("..bone..") "..vm:GetBoneName(bone).." rel to p ("..par.."): "..tostring(bpos - (vm:GetBonePosition(vm:GetBoneParent(bone)) or bpos)))
			--local relp = bpos - (vm:GetBonePosition(vm:GetBoneParent(bone)) or bpos)
			--p = relp * ms - relp
			--SCKDebug("Bone ("..bone..") scale = "..tostring(ms).." | newpos = "..tostring(p))

			-- !! ----------- !! --

			if vm:GetManipulateBoneScale(bone) ~= s then
				vm:ManipulateBoneScale( bone, s )
			end
			if vm:GetManipulateBoneAngles(bone) ~= v.angle then
				vm:ManipulateBoneAngles( bone, v.angle )
			end
			if vm:GetManipulateBonePosition(bone) ~= p then
				vm:ManipulateBonePosition( bone, p )
			end
		end
	else
		self:ResetBonePositions(vm)
	end
end

function SWEP:ResetBonePositions(vm)
	if (!vm:GetBoneCount()) then return end

	for i=0, vm:GetBoneCount() do
		vm:ManipulateBoneScale( i, Vector(1, 1, 1) )
		vm:ManipulateBoneAngles( i, Angle(0, 0, 0) )
		vm:ManipulateBonePosition( i, Vector(0, 0, 0) )
	end
end

local helper_text_pos = nil
local matDisc = Material( "widgets/disc.png", "nocull alphatest smooth mips" )

function SWEP:ShowElementHelpers( pos, ang, v )
	local helper_pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
	local helper_ang = ang * 1

	if v.angle then
		helper_ang:RotateAroundAxis(helper_ang:Up(), v.angle.y)
		helper_ang:RotateAroundAxis(helper_ang:Right(), v.angle.p)
		helper_ang:RotateAroundAxis(helper_ang:Forward(), v.angle.r)
	end

	helper_text_pos = helper_pos * 1

	if input.IsKeyDown( KEY_LSHIFT ) then
		if model_drag_modes[ self.selectedModelDragMode ].vs then
			helper_ang = self.useThirdPerson and self.thirdPersonAngleView or LocalPlayer():EyeAngles()
		end

		render.SetMaterial( matDisc )

		render.DrawQuadEasy( helper_pos, helper_ang:Forward(), 10, 10, Color( 255, 55, 55, 50 ), 0 )
		render.DrawQuadEasy( helper_pos, helper_ang:Right(), 10, 10, Color( 55, 255, 55, 50 ), 0 )
		render.DrawQuadEasy( helper_pos, helper_ang:Up(), 10, 10, Color( 55, 55, 255, 50 ), 0 )

	else
		if model_drag_modes[ self.selectedModelDragMode ].vs then
			ang = self.useThirdPerson and self.thirdPersonAngleView or LocalPlayer():EyeAngles()
		end

		render.DrawLine( helper_pos, helper_pos + ang:Forward() * 10, Color( 255, 55, 55 ), true )
		render.DrawLine( helper_pos, helper_pos + ang:Right() * 10, Color( 55, 255, 55 ), true )
		render.DrawLine( helper_pos, helper_pos + ang:Up() * 10, Color( 55, 55, 255 ), true )

	end
end

function SWEP:ShowBoneHelper( vm )

	if !IsValid( self.ShouldShowBones ) then return end

	local ent = vm
	if !IsValid(ent) then
		ent = self:GetOwner()
	end

	local ratio = 0.25

	cam.IgnoreZ( true )
	for i = 0, ent:GetBoneCount() - 1 do

		local parent = ent:GetBoneParent( i )
		local m = ent:GetBoneMatrix( i )
		local m_p = ent:GetBoneMatrix( parent )

		if m and m_p then

			local pos = m:GetTranslation()
			local p_pos = m_p:GetTranslation()

			local len = (pos - p_pos):Length()

			local ang = (p_pos - pos):GetNormal():Angle()

			local selected = false

			if self.ShowCurrentBone and ent:GetBoneName( i ) == self.ShowCurrentBone then
				selected = true
			end

			local selected_parent = false

			if self.ShowCurrentBone and ent:GetBoneName( parent ) == self.ShowCurrentBone then
				selected_parent = true
			end

			render.DrawWireframeSphere( pos, 0.1, 15, 6, selected and Color ( 0, 255, 0, 255 ) or Color( 255, 255, 255, 100 ), true )
			if selected_parent then
				render.DrawWireframeBox( pos, ang, Vector( 0, -1 * ( ratio * len / 2 ), -1 * ( ratio * len / 2 ) ), Vector( len, ratio * len / 2,  ratio * len / 2 ), selected_parent and Color ( 0, 255, 0, 255 ) or Color( 255, 255, 255, 100 ), true )
			else
				render.DrawLine( pos, p_pos, selected_parent and Color ( 0, 255, 0, 255 ) or Color( 255, 255, 255, 100 ), true )
			end

			if #ent:GetChildBones( i ) < 1 then
				local ang2 = m:GetAngles()
				len = math.min( math.max( ent:BoneLength(i), 3 ), len * 0.2 )
				if selected then
					render.DrawWireframeBox( pos, ang2, Vector( 0, -1 * ( ratio * len / 2 ), -1 * ( ratio * len / 2 ) ), Vector( len, ratio * len / 2,  ratio * len / 2 ), selected and Color ( 0, 255, 0, 255 ) or Color( 255, 255, 255, 100 ), true )
				else
					render.DrawLine( pos, pos + ang2:Forward() * len, selected and Color ( 0, 255, 0, 255 ) or Color( 255, 255, 255, 100 ), true )
				end
			end


		end

	end
	cam.IgnoreZ( false )


end

--[[*******************************
	All viewmodel drawing magic
********************************]]
SWEP.vRenderOrder = nil
local clip_mat = Material( "vgui/white" )
function SWEP:ViewModelDrawn()
	--SCKDebugRepeat( "SWEP:VMD", "Drawing viewmodel!" )

	local vm = self:GetOwner():GetViewModel()
	if !IsValid(vm) then return end

	self:UpdateBonePositions(vm)
	--[[if vm.BuildBonePositions ~= self.BuildViewModelBones then
		vm.BuildBonePositions = self.BuildViewModelBones
	end]]

	if (!self.vRenderOrder) then
		-- we build a render order because sprites need to be drawn after models
		self.vRenderOrder = {}

		-- clean up cached clip planes
		for k, v in pairs( self.v_models ) do
			if v.type == "Model" then
				v.clipplanes = nil
				v.clipcount = nil
			end
		end

		for k, v in pairs( self.v_models ) do
			if (v.type == "Model") then
				if v.highrender then
					table.insert(self.vRenderOrder, k)
				else
					table.insert(self.vRenderOrder, 1, k)
				end
			elseif (v.type == "Sprite" or v.type == "Quad") then
				table.insert(self.vRenderOrder, k)
			elseif (v.type == "ClipPlane") then
				if v.rel == "" or v.rel == nil then continue end

				if self.v_models[ v.rel ] and self.v_models[ v.rel ].type == "Model" then

					self.v_models[ v.rel ].clipplanes = self.v_models[ v.rel ].clipplanes or {}
					self.v_models[ v.rel ].clipcount = self.v_models[ v.rel ].clipcount or 0

					table.insert(self.v_models[ v.rel ].clipplanes, k)

					self.v_models[ v.rel ].clipcount = self.v_models[ v.rel ].clipcount + 1

					table.insert(self.vRenderOrder, k)
				end
			end
		end
	end

	local show_helpers = ( input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_LSHIFT ) ) and self.Frame and self.Frame:IsVisible()

	for k, name in ipairs( self.vRenderOrder ) do
		local v = self.v_models[name]
		if (!v) then self.vRenderOrder = nil break end

		local model = v.modelEnt
		local sprite = v.spriteMaterial

		if (!v.bone) then continue end

		local pos, ang = self:GetBoneOrientation( self.v_models, name, vm )

		if (!pos) then continue end

		if show_helpers then
			if name == self.selectedElement then
				self:ShowElementHelpers( pos, ang, v )
			end
		else
			if helper_text_pos then helper_text_pos = nil end
		end

		if (v.type == "Model" and IsValid(model)) then

			model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			model:SetAngles(ang)
			--model:SetModelScale(v.size)
			local matrix = Matrix()
			matrix:Scale(v.size)
			model:EnableMatrix( "RenderMultiply", matrix )

			if model.ModelMatrixScale ~= v.size then
				model.ModelMatrixScale = v.size
			end

			if v.size.x < 0 and not v.inversed then
				v.inversed = true
			end

			-- reset back just in case
			if v.inversed and v.size.x > 0 then
				v.inversed = nil
			end

			if v.bonemerge then
				if !model:IsEffectActive( EF_BONEMERGE ) then
					model:SetParent( vm )
					model:AddEffects( EF_BONEMERGE )
				end
			else
				if model:IsEffectActive( EF_BONEMERGE ) then
					model:SetParent( self )
					model:RemoveEffects( EF_BONEMERGE )
				end
			end

			if (v.material == "") then
				model:SetMaterial("")
			elseif model:GetMaterial() ~= v.material or model:GetMaterial() ~= SCKMaterials[v.material] then
				local mat = ConvertSCKMaterial(v.material) -- check it first
				model:SetMaterial( mat )
			end

			if (v.skin ~= model:GetSkin()) then
				model:SetSkin(v.skin)
			end

			for slot, bg in pairs( v.bodygroup ) do
				if (model:GetBodygroup(slot) ~= bg) then
					model:SetBodygroup(slot, bg)
				end
			end

			if (v.surpresslightning) then
				render.SuppressEngineLighting(true)
			end

			render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
			render.SetBlend(v.color.a/255)
			if v.inversed then render.CullMode(MATERIAL_CULLMODE_CW) end

			local real_clip_count = 0

			if v.clipplanes and v.clipcount then
				render.EnableClipping( true )

				local mpos = model:GetPos()

				for i = 1, math.min( v.clipcount, 2 ) do
					local plane = v.clipplanes[ i ]

					if plane and self.v_models[ plane ] then

						local clip_data = self.v_models[ plane ]

						local clip_ang = ang * 1
						local clip_pos = mpos + clip_ang:Forward() * clip_data.pos.x + clip_ang:Right() * clip_data.pos.y + clip_ang:Up() * clip_data.pos.z

						clip_ang:RotateAroundAxis(clip_ang:Up(), clip_data.angle.y)
						clip_ang:RotateAroundAxis(clip_ang:Right(), clip_data.angle.p)
						clip_ang:RotateAroundAxis(clip_ang:Forward(), clip_data.angle.r)

						render.PushCustomClipPlane( clip_ang:Up(), clip_ang:Up():Dot( clip_pos ) )
						real_clip_count = real_clip_count + 1
					end
				end
			end

			model:DrawModel()

			if real_clip_count > 0 and v.nocull then
				render.CullMode(v.inversed and MATERIAL_CULLMODE_CCW or MATERIAL_CULLMODE_CW)
				model:DrawModel()
				render.CullMode(v.inversed and MATERIAL_CULLMODE_CW or MATERIAL_CULLMODE_CCW)
			end

			if real_clip_count > 0 then
				for i = 1, real_clip_count do
					render.PopCustomClipPlane()
				end
				render.EnableClipping( false )
			end

			if v.inversed then render.CullMode(MATERIAL_CULLMODE_CCW) end
			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)

			if (v.surpresslightning) then
				render.SuppressEngineLighting(false)
			end

		elseif (v.type == "Sprite" and sprite) then

			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			render.SetMaterial(sprite)
			render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)

		elseif (v.type == "Quad") then

			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			cam.Start3D2D(drawpos, ang, v.size)
				draw.RoundedBox( 0, -20, -20, 40, 40, Color(200,0,0,100) )
				surface.SetDrawColor( 255, 255, 255, 100 )
				surface.DrawOutlinedRect( -20, -20, 40, 40 )
				draw.SimpleTextOutlined("12pt arial","12ptFont",0, -12, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0,0,0,255))
				draw.SimpleTextOutlined("40x40 box","12ptFont",0, 2, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0,0,0,255))
				surface.SetDrawColor( 0, 255, 0, 230 )
				surface.DrawLine( 0, 0, 0, 8 )
				surface.DrawLine( 0, 0, 8, 0 )
			cam.End3D2D()
		elseif (v.type == "ClipPlane") then

			if name == self.selectedElement then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				render.SetMaterial( clip_mat )

				render.OverrideDepthEnable( true, false )
				render.DrawQuad( drawpos + ang:Right() * 40, drawpos + ang:Forward() * 40, drawpos - ang:Right() * 40, drawpos - ang:Forward() * 40, Color( 255, 0, 0, 50 ) )
				render.DrawQuad( drawpos - ang:Right() * 40, drawpos + ang:Forward() * 40, drawpos + ang:Right() * 40, drawpos - ang:Forward() * 40, Color( 0, 255, 0, 50) )
				render.OverrideDepthEnable( false, false )
			end

		end
	end
end

--[[*******************************
	All worldmodel drawing science
********************************]]
SWEP.wRenderOrder = nil
function SWEP:DrawWorldModel()
	--SCKDebugRepeat( "SWEP:WMD", "Drawing worldmodel!" )

	local wm = self.world_model
	if !IsValid(wm) then return end

	self:ShowBoneHelper()

	if (!self.wRenderOrder) then

		self.wRenderOrder = {}

		-- clean up cached clip planes
		for k, v in pairs( self.w_models ) do
			if v.type == "Model" then
				v.clipplanes = nil
				v.clipcount = nil
			end
		end

		for k, v in pairs( self.w_models ) do
			if (v.type == "Model") then
				if v.highrender then
					table.insert(self.wRenderOrder, k)
				else
					table.insert(self.wRenderOrder, 1, k)
				end
			elseif (v.type == "Sprite" or v.type == "Quad") then
				table.insert(self.wRenderOrder, k)
			elseif (v.type == "ClipPlane") then
				if v.rel == "" or v.rel == nil then continue end

				if self.w_models[ v.rel ] and self.w_models[ v.rel ].type == "Model" then

					self.w_models[ v.rel ].clipplanes = self.w_models[ v.rel ].clipplanes or {}
					self.w_models[ v.rel ].clipcount = self.w_models[ v.rel ].clipcount or 0

					table.insert(self.w_models[ v.rel ].clipplanes, k)

					self.w_models[ v.rel ].clipcount = self.w_models[ v.rel ].clipcount + 1

					table.insert(self.wRenderOrder, k)
				end
			end
		end
	end

	local bone_ent

	if IsValid( self:GetOwner() ) then
		self:SetRenderMode(  RENDERMODE_NORMAL  )
		wm:SetNoDraw( true )
		wm:DrawShadow( true )
		self:DrawShadow( true )
		if (self:GetOwner():IsPlayer() and self:GetOwner():GetActiveWeapon() ~= self.Weapon) then return end
		wm:SetParent(self:GetOwner())
		if not self:GetOwner():IsPlayer() then
			wm:SetRenderBounds( self:GetOwner():OBBMins()*2, self:GetOwner():OBBMaxs()*2 )
			self:SetRenderBounds( self:GetOwner():OBBMins()*2, self:GetOwner():OBBMaxs()*2 )
		end
		if self.ShowWorldModel and self:GetOwner():IsPlayer() then
			wm:DrawModel()
		end
		bone_ent = self:GetOwner()
	else
		-- this only happens if the weapon is dropped, which shouldn't happen normally.
		self:SetRenderMode( RENDERMODE_NONE )
		wm:SetNoDraw( true )
		wm:SetParent( self )
		wm:DrawShadow( false )
		self:DrawShadow( false )

		render.SetBlend(self.ShowWorldModel and 1 or 0)
			wm:DrawModel()
		render.SetBlend(1)

		-- the reason that we don't always use this bone is because it lags 1 frame behind the player's right hand bone when held
		bone_ent = wm
	end

	--[[ BASE CODE FOR NEW SWEPS ]]
	--[[self:DrawModel()
	if (IsValid(self:GetOwner())) then
		bone_ent = self:GetOwner()
	else
		-- when the weapon is dropped
		bone_ent = self
	end]]

	local show_helpers = ( input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_LSHIFT ) ) and self.Frame and self.Frame:IsVisible()
	for k, name in pairs( self.wRenderOrder ) do
		local v = self.w_models[name]
		if (!v) then self.wRenderOrder = nil break end

		local pos, ang

		if (v.bone) then
			pos, ang = self:GetBoneOrientation( self.w_models, name, bone_ent )
		else
			pos, ang = self:GetBoneOrientation( self.w_models, name, bone_ent, "ValveBiped.Bip01_R_Hand" )
		end

		if (!pos) then continue end

		if show_helpers then
			if name == self.selectedElement then
				self:ShowElementHelpers( pos, ang, v )
			end
		else
			if helper_text_pos then helper_text_pos = nil end
		end

		local model = v.modelEnt
		local sprite = v.spriteMaterial

		if (v.type == "Model" and IsValid(model)) then

			model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z )
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			model:SetAngles(ang)
			--model:SetModelScale(v.size)
			local matrix = Matrix()
			matrix:Scale(v.size)
			model:EnableMatrix( "RenderMultiply", matrix )

			if model.ModelMatrixScale ~= v.size then
				model.ModelMatrixScale = v.size
			end

			if v.bonemerge then
				if !model:IsEffectActive( EF_BONEMERGE ) then
					model:SetParent( self:GetOwner() )
					model:AddEffects( EF_BONEMERGE )
				end
			else
				if model:IsEffectActive( EF_BONEMERGE ) then
					model:SetParent( self )
					model:RemoveEffects( EF_BONEMERGE )
				end
			end

			if (v.material == "") then
				model:SetMaterial("")
			elseif model:GetMaterial() ~= (SCKMaterials[v.material] or v.material) then
				local mat = ConvertSCKMaterial(v.material) -- check it first
				model:SetMaterial( mat )
			end

			if (v.skin ~= model:GetSkin()) then
				model:SetSkin(v.skin)
			end

			for slot, bg in pairs( v.bodygroup ) do
				if (model:GetBodygroup(slot) ~= bg) then
					model:SetBodygroup(slot, bg)
				end
			end

			if (v.surpresslightning) then
				render.SuppressEngineLighting(true)
			end

			render.SetColorModulation(v.color.r/255, v.color.g/255, v.color.b/255)
			render.SetBlend(v.color.a/255)

			local real_clip_count = 0

			if v.clipplanes and v.clipcount then
				render.EnableClipping( true )

				local mpos = model:GetPos()

				for i = 1, math.min( v.clipcount, 2 ) do
					local plane = v.clipplanes[ i ]

					if plane and self.w_models[ plane ] then

						local clip_data = self.w_models[ plane ]

						local clip_ang = ang * 1
						local clip_pos = mpos + clip_ang:Forward() * clip_data.pos.x + clip_ang:Right() * clip_data.pos.y + clip_ang:Up() * clip_data.pos.z

						clip_ang:RotateAroundAxis(clip_ang:Up(), clip_data.angle.y)
						clip_ang:RotateAroundAxis(clip_ang:Right(), clip_data.angle.p)
						clip_ang:RotateAroundAxis(clip_ang:Forward(), clip_data.angle.r)

						render.PushCustomClipPlane( clip_ang:Up(), clip_ang:Up():Dot( clip_pos ) )
						real_clip_count = real_clip_count + 1
					end
				end
			end

			model:DrawModel()

			if real_clip_count > 0 and v.nocull then
				render.CullMode(MATERIAL_CULLMODE_CW)
				model:DrawModel()
				render.CullMode(MATERIAL_CULLMODE_CCW)
			end

			if real_clip_count > 0 then
				for i = 1, real_clip_count do
					render.PopCustomClipPlane()
				end
				render.EnableClipping( false )
			end

			render.SetBlend(1)
			render.SetColorModulation(1, 1, 1)

			if (v.surpresslightning) then
				render.SuppressEngineLighting(false)
			end

		elseif (v.type == "Sprite" and sprite) then

			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			render.SetMaterial(sprite)
			render.DrawSprite(drawpos, v.size.x, v.size.y, v.color)

		elseif (v.type == "Quad") then

			local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)

			cam.Start3D2D(drawpos, ang, v.size)
				draw.RoundedBox( 0, -20, -20, 40, 40, Color(200,0,0,100) )
				surface.SetDrawColor( 255, 255, 255, 100 )
				surface.DrawOutlinedRect( -20, -20, 40, 40 )
				draw.SimpleTextOutlined("12pt arial","12ptFont",0, -12, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0,0,0,255))
				draw.SimpleTextOutlined("40x40 box","12ptFont",0, 2, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0,0,0,255))
				surface.SetDrawColor( 0, 255, 0, 230 )
				surface.DrawLine( 0, 0, 0, 8 )
				surface.DrawLine( 0, 0, 8, 0 )
			cam.End3D2D()
		elseif (v.type == "ClipPlane") then

			if name == self.selectedElement then
				local drawpos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)

				render.SetMaterial( clip_mat )

				render.OverrideDepthEnable( true, false )
				render.DrawQuad( drawpos + ang:Right() * 40, drawpos + ang:Forward() * 40, drawpos - ang:Right() * 40, drawpos - ang:Forward() * 40, Color( 255, 0, 0, 50 ) )
				render.DrawQuad( drawpos - ang:Right() * 40, drawpos + ang:Forward() * 40, drawpos + ang:Right() * 40, drawpos - ang:Forward() * 40, Color( 0, 255, 0, 50) )
				render.OverrideDepthEnable( false, false )
			end

		end
	end
end

function SWEP:Holster()
	self.useThirdPerson = false

	local vm = self:GetOwner():GetViewModel()
	if IsValid(vm) then
		self:ResetBonePositions(vm)
	end

	return true
end

local function DrawDot( x, y )
	surface.SetDrawColor(100, 100, 100, 255)
	surface.DrawRect(x - 2, y - 2, 4, 4)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawRect(x - 1, y - 1, 2, 2)
end

SWEP.FirstTimeOpen = true

local scale = ScrH() / 1080
local function drawtext(txt, color, offset)
	draw.SimpleTextOutlined(txt, "24ptFont", ScrW() - 100 * scale, offset, color or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 2, color_black)
end

local function drawcontrols(self)
	local sckmenu = self.Frame
	if not IsValid(sckmenu) then return end
	if not sckmenu:IsVisible() then return end

	local propsheet = sckmenu.PropertySheet
	if not IsValid(propsheet) then return end

	surface.SetFont("24ptFont")
	local _, h = surface.GetTextSize("W")
	local offset = 64 * scale
	drawtext("[CONTROLS]", color_white, offset)
	offset = offset + h

	drawtext("Press CTRL+Z to undo angle/position/size changes", color_white, offset)
	offset = offset + h

	drawtext("Press CTRL+Y to redo angle/position/size changes", color_white, offset)
	offset = offset + h

	local curtab = propsheet:GetActiveTab():GetText()
	if curtab ~= "View Models" and curtab ~= "World Models" then return end
	if not (self.selectedElement and #self.selectedElement > 0) then return end

	drawtext("Hold LSHIFT for angle mouse move", color_white, offset)
	offset = offset + h

	if input.IsKeyDown(KEY_LSHIFT) then
		drawtext("-Hold and drag RMB to rotate along X Y axis", color_white, offset)
		offset = offset + h
		drawtext("-Hold and drag LMB+RMB to rotate along Z axis", color_white, offset)
		offset = offset + h
	end

	offset = offset + h

	drawtext("Hold LCTRL for position mouse move", color_white, offset)
	offset = offset + h

	if input.IsKeyDown(KEY_LCONTROL) then
		drawtext("-Hold and drag RMB to move along X Y axis", color_white, offset)
		offset = offset + h
		drawtext("-Hold and drag LMB+RMB to move along Z axis", color_white, offset)
		offset = offset + h
	end
end

function SWEP:DrawHUD()
	if helper_text_pos then
		local pos = helper_text_pos:ToScreen()

		draw.SimpleTextOutlined("Drag Precision: "..self.selectedModelDragPrecision,"12ptFont",pos.x, pos.y, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1, Color(0,0,0,255))
	end

	drawcontrols(self)
end

--Separated since they're very different

function SWEP:OpenMaterialBrowser(current, callback)
	local wep = self
	wep.browser_callback = callback
	wep.Frame:SetVisible( false )

	local container = vgui.Create("DFrame")
	container:SetSize( 480, ScrH()*0.8 )
	container:SetPos( 50, 50 )
	container:SetDraggable( true )
	container:ShowCloseButton( false )
	container:SetSizable( true )
	--container:SetDeleteOnClose( false )
	container:InvalidateLayout(true)

	container:MakePopup()
	container:SetTitle( "Material browser" )

	local prop = vgui.Create("DPropertySheet", container)
	prop:Dock(FILL)
	prop:InvalidateLayout(true)

	local browser = vgui.Create("Panel")
	browser:SetSize( container:GetSize())
	browser:InvalidateLayout(true)

	wep.matbrowser = container

	local tree = vgui.Create( "DTree", browser )
	--tree:SetPos( 5, 30 )
	--tree:SetSize( browser:GetWide() - 10, browser:GetTall()-355 )
		tree:SetTall(300)
	tree:DockPadding(5,5,5,5)
	tree:Dock(TOP)

	local nodelist = {}
	local filecache = {}
	local checked = {}

	local matcontainer = vgui.Create("DScrollPanel", browser)
	matcontainer:Dock(FILL)
	matcontainer:InvalidateLayout(true)

	local matlist = vgui.Create("DGrid", matcontainer)
	matlist:SetSize(matcontainer:GetSize())
	matlist:SetCols(4)
	matlist:InvalidateLayout(true)
	matlist:SetColWide(480 / 4)
	matlist:SetRowHeight(480 / 4)

	local selected = current
	local curfav = SCKMaterialFavs[selected]
	local selectbutton = function( self )
		local path = self.MaterialPath

		if (path:sub( 1, 10 ) == "materials/") then
			path = path:sub( 11 ) -- removes the "materials/" part
		end
		path = path:gsub( "%.vmt", "" )

		selected = path

		curfav = SCKMaterialFavs[selected]

		if IsValid(container.favbtn) then
			local btn = container.favbtn
			btn:SetText(curfav and "UNFAVORITE MATERIAL" or "FAVORITE MATERIAL")
		end
	end

	local function addimg(matname, pnl)
		local btn = vgui.Create("DImageButton")
		btn:SetImage(matname)
		btn:SetSize(480 / 4, 480 / 4)
		btn.MaterialPath = matname
		btn.DoClick = selectbutton
		btn.DoRightClick = function(s) SetClipboardText(s.MaterialPath) end
		btn:SetTooltip(matname)
		local mat = btn.m_Image:GetMaterial()
		local shader = string.lower(mat:GetShader())
		if shader == "lightmappedgeneric" or shader == "worldtwotextureblend" or string.StartWith(shader, "worldvertextransition") then
			--we have to fix this
			local basetex = mat:GetString("$basetexture")
			local newmat = CreateMaterial("patch_"..basetex, "UnlitGeneric", {
				["$basetexture"] = basetex,
			})

			btn:SetMaterial(newmat)
		end

		btn.matname = matname

		local p = pnl or matlist
		p:AddItem(btn)

		return btn
	end

	local bpanel = vgui.Create("DPanel", container)
	bpanel:SetTall(200)
	bpanel:SetPaintBackground(false)
	bpanel:DockMargin(5,5,5,5)
	bpanel:Dock(BOTTOM)

	local modview = vgui.Create("DImage", bpanel)
	modview:SetSize(200, 200)
	modview:Dock(LEFT)

	local rpanel = vgui.Create("DPanel", bpanel)
	rpanel:SetPaintBackground(false)
	rpanel:DockPadding(5,0,0,0)
	rpanel:Dock(FILL)

	local mdlabel = vgui.Create("DLabel", rpanel)
	mdlabel:SetText( current )
	mdlabel:SizeToContents()
	mdlabel:Dock(TOP)

	-- set the default


	local cancelbtn = vgui.Create("DButton", rpanel)
		cancelbtn:SetTall(20)
		cancelbtn:SetText("cancel")
		cancelbtn.DoClick = function()
			if (wep.Frame) then
				wep.Frame:SetVisible(true)
			end
			container:Close()
		end
	cancelbtn:Dock(BOTTOM)

	local choosebtn = vgui.Create("DButton", rpanel)
		choosebtn:SetTall(20)
			choosebtn:SetText("DO WANT THIS MATERIAL")

		choosebtn.DoClick = function()
			if (wep.browser_callback) then
				wep.browser_callback(selected)
			end
			if (wep.Frame) then
				wep.Frame:SetVisible(true)
			end
			container:Close()
		end
	choosebtn:DockMargin(0,0,0,5)
	choosebtn:Dock(BOTTOM)

	container.favbtn = vgui.Create("DButton", rpanel)
	local favbtn = container.favbtn
	favbtn:SetTall(20)
	favbtn:SetText(curfav and "UNFAVORITE MATERIAL" or "FAVORITE MATERIAL")

	favbtn.DoClick = function()
		if curfav then
			RemoveMaterialFavorite(selected)
			curfav = false
		else
			AddMaterialFavorite(selected)
			curfav = true
		end

		container.favmatlist:Rebuild()

		favbtn:SetText(curfav and "UNFAVORITE MATERIAL" or "FAVORITE MATERIAL")
	end
	favbtn:DockMargin(0,0,0,5)
	favbtn:Dock(TOP)


	local LoadDirectories
	local AddNode = function( base, dir, tree_override )

		local newpath = base.."/"..dir
		local basenode = nodelist[base]

		if (tree_override) then
			newpath = dir
			basenode = tree_override
		end

		if (!basenode) then
			print("No base node for \""..tostring(base).."\", \""..tostring(dir).."\", "..tostring(tree_override))
		end

		nodelist[newpath] = basenode:AddNode( dir )
		nodelist[newpath].DoClick = function()
			LoadDirectories( newpath )
			for k, v in pairs(matlist:GetChildren()) do
				matlist:RemoveItem(v)
			end

			if (filecache[newpath]) then
				for k, f in pairs(filecache[newpath]) do
					addimg(f:sub(11))
				end
			else
				filecache[newpath] = {}
				local files = file.Find(newpath.."/*.vmt", "GAME")

				table.sort(files)
				for k, f in pairs(files) do
					local newfilepath = newpath.."/"..f
					addimg(newfilepath:sub(11))

					table.insert(filecache[newpath], newfilepath)
				end
			end
		end

	end

	AddNode( "", "materials", tree )

	LoadDirectories = function( v )

		if (table.HasValue(checked,v)) then return end
		local _, newdirs = file.Find(v.."/*", "GAME")
		table.insert(checked, v)

		table.sort(newdirs)

		for _, dir in pairs(newdirs) do
			AddNode( v, dir )
		end
	end
	LoadDirectories( "materials" )

	prop:AddSheet("Materials", browser)

	local favmats = vgui.Create("DScrollPanel", prop)
	favmats:Dock(FILL)
	favmats:InvalidateLayout(true)

	local favmatlist = vgui.Create("DGrid", favmats)
	favmatlist:SetSize(matcontainer:GetSize())
	favmatlist:SetCols(4)
	favmatlist:InvalidateLayout(true)
	favmatlist:SetColWide(480 / 4)
	favmatlist:SetRowHeight(480 / 4)
	favmatlist:SortByMember("matname")
	container.favmatlist = favmatlist

	favmatlist.Rebuild = function(self)
		for k, v in pairs(self:GetChildren()) do
			self:RemoveItem(v)
		end

		for k, v in SortedPairs(SCKMaterialFavs) do
			if v then
				addimg(k, favmatlist)
			end
		end
		self:InvalidateLayout(true)
	end


	favmatlist:Rebuild()

	prop:AddSheet("Favorite Materials", favmats)
end

function SWEP:OpenModelBrowser(current, callback)
	local wep = self
	wep.browser_callback = callback
	wep.Frame:SetVisible( false )

	if wep.modelbrowser then
		wep.modelbrowser:SetVisible(true)
		wep.modelbrowser:MakePopup()
		wep.modelbrowser_list.OnRowSelected(nil,nil,current)
		return

	end

	local browser = vgui.Create("DFrame")
	browser:SetSize( 480, ScrH()*0.8 )
	browser:SetPos( 50, 50 )
	browser:SetDraggable( true )
	browser:ShowCloseButton( false )
	browser:SetSizable( true )
	browser:SetDeleteOnClose( false )
	browser:SetTitle( "Model browser" )
	wep.modelbrowser = browser

	local tree = vgui.Create( "DTree", browser )
	tree:SetTall(300)
	tree:DockPadding(5,5,5,5)
	tree:Dock(TOP)

	local nodelist = {}
	local filecache = {}
	local checked = {}

	local modlist = vgui.Create("DListView", browser)
	modlist:SetMultiSelect(false)
	modlist:SetDrawBackground(true)
	modlist:AddColumn("Model")
	modlist:DockPadding(5,5,5,0)
	modlist:Dock(FILL)

	local bpanel = vgui.Create("DPanel", browser)
	bpanel:SetTall(200)
	bpanel:SetDrawBackground(false)
	bpanel:DockMargin(5,5,5,5)
	bpanel:Dock(BOTTOM)

	local modzoom = 30
	local modview

	modview = vgui.Create("DModelPanel", bpanel)
	modview:SetModel("")
	modview:SetCamPos( Vector(modzoom,modzoom,modzoom/2) )
	modview:SetLookAt( Vector( 0, 0, 0 ) )

	modview:SetSize(200, 200)
	modview:Dock(LEFT)

	local rpanel = vgui.Create("DPanel", bpanel)
		rpanel:SetDrawBackground(false)
	rpanel:DockPadding(5,0,0,0)
	rpanel:Dock(FILL)

	local mdlabel = vgui.Create("DLabel", rpanel)
		mdlabel:SetText( current )
		mdlabel:SizeToContents()
	mdlabel:Dock(TOP)

	local zoomslider = vgui.Create( "DNumSlider", rpanel)
		zoomslider:SetText( "Zoom" )
		zoomslider:SetMin( 8 )
		zoomslider:SetMax( 256 )
		zoomslider:SetDecimals( 0 )
		zoomslider:SetValue( modzoom )
		zoomslider.Wang.ConVarChanged = function( panel, value )
			local modzoom = tonumber(value)
			modview:SetCamPos( Vector(modzoom,modzoom,modzoom/2) )
			modview:SetLookAt( Vector( 0, 0, 0 ) )
		end
	zoomslider:Dock(FILL)

	local selected = ""

	modlist.OnRowSelected = function( panel, line, override )
		if (type(override) != "string") then override = nil end -- for some reason the list itself throws a panel at it in the callback
		local path = override or modlist:GetLine(line):GetValue(1)

		modview:SetModel(path)

		mdlabel:SetText(path)
		selected = path
	end

	-- set the default
	modlist.OnRowSelected(nil,nil,current)
	wep.modelbrowser_list = modlist

	local cancelbtn = vgui.Create("DButton", rpanel)
		cancelbtn:SetTall(20)
		cancelbtn:SetText("cancel")
		cancelbtn.DoClick = function()
			if (wep.Frame) then
				wep.Frame:SetVisible(true)
			end
			browser:Close()
		end
	cancelbtn:Dock(BOTTOM)

	local choosebtn = vgui.Create("DButton", rpanel)
		choosebtn:SetTall(20)
		choosebtn:SetText("DO WANT THIS MODEL")

		choosebtn.DoClick = function()
			if (wep.browser_callback) then
				pcall(wep.browser_callback, selected)
			end
			if (wep.Frame) then
				wep.Frame:SetVisible(true)
			end
			browser:Close()
		end
	choosebtn:DockMargin(0,0,0,5)
	choosebtn:Dock(BOTTOM)

	local LoadDirectories
	local AddNode = function( base, dir, tree_override )
		local newpath = base.."/"..dir
		local basenode = nodelist[base]

		if (tree_override) then
			newpath = dir
			basenode = tree_override
		end

		if (!basenode) then
			print("No base node for \""..tostring(base).."\", \""..tostring(dir).."\", "..tostring(tree_override))
		end

		nodelist[newpath] = basenode:AddNode( dir )
		nodelist[newpath].DoClick = function()
			LoadDirectories( newpath )
			modlist:Clear()
			modlist:SetVisible(true)

			if (filecache[newpath]) then
				for k, f in pairs(filecache[newpath]) do
					modlist:AddLine(f)
				end
			else
				filecache[newpath] = {}
				local files, folders = file.Find(newpath.."/*.mdl", "GAME")
				table.sort(files)
				for k, f in pairs(files) do
					local newfilepath = newpath.."/"..f
					modlist:AddLine(newfilepath)
					table.insert(filecache[newpath], newfilepath)
				end
			end
		end

	end
	AddNode( "", "models", tree )

	LoadDirectories = function( v )

		if (table.HasValue(checked,v)) then return end
		local _, newdirs = file.Find(v.."/*", "GAME")
		table.insert(checked, v)

		table.sort(newdirs)

		for _, dir in pairs(newdirs) do
			AddNode( v, dir )
		end

	end
	LoadDirectories( "models" )

	browser:SetVisible( true )
	browser:MakePopup()
end

--[[**************************
			Menu
**************************]]
local function CreateMenu( preset )
	local wep = GetSCKSWEP( LocalPlayer() )
	if !IsValid(wep) then return nil end

	wep.save_data = table.Copy(save_data_template)

	if (preset) then
		-- use the preset
		for k, v in pairs( preset ) do
			wep.save_data[k] = v
		end

		--clean up materials now!!
		for k, v in pairs(wep.save_data.v_models) do
			if SCKMaterialCompat[v.material] then
				v.material = SCKMaterialCompat[v.material]
			end
		end

		for k, v in pairs(wep.save_data.w_models) do
			if SCKMaterialCompat[v.material] then
				v.material = SCKMaterialCompat[v.material]
			end
		end
	end

	-- Now for the actual menu:
	local f = vgui.Create("DFrame")
	f:SetSize( 480, ScrH()*0.8 )
	f:SetPos( 50, 50 )
	f:SetTitle( "SWEP Construction Kit" )
	f:SetDraggable( true )
	f:ShowCloseButton( true )
	f:SetSizable( true )
	f:SetDeleteOnClose( false )
	-- this will stay here until I'll get a better idea (walks away with a crucible)
	--[[
	f.Think = function( self )
		self.BaseClass.Think( self )

		local mx, my = gui.MouseX(), gui.MouseY()
		local w, h = self:GetWide(), self:GetTall()
		local x, y = self:GetPos()

		local inside = mx > x and mx < ( x + w ) and my > y and my < ( y + h ) and !( input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_LSHIFT ) )

		//self:SetKeyboardInputEnabled( inside )
		//self:SetMouseInputEnabled( inside )
	end
	--]]

	local mpanel = vgui.Create( "DPanel", f )
		mpanel:SetPaintBackground(false)
		mpanel:SetTooltip("Hold CTRL to enter elements drag mode.\nHold SHIFT to enter element rotation mode.\n\n  - Hold RMB for 2D axis mode.\n  - Hold LMB and RMB for 1D axis mode.\n  - Use SCROLL WHEEL to adjust drag sensitivity.")
		mpanel:SetTall(20)
	mpanel:DockMargin(0,0,0,5)
	mpanel:Dock(TOP)

	local mlabel = vgui.Create( "DLabel", mpanel )
		mlabel:SetText( "Elements drag mode:" )
		mlabel:SetTooltip("Hold CTRL to enter elements drag mode.\nHold SHIFT to enter element rotation mode.\n\n  - Hold RMB for 2D axis mode.\n  - Hold LMB and RMB for 1D axis mode.\n  - Use SCROLL WHEEL to adjust drag sensitivity.")
		mlabel:SizeToContents()
		mlabel:SetTall(20)
	mlabel:DockMargin(5,0,0,0)
	mlabel:Dock(LEFT)

	local msnap = vgui.Create( "DNumberWang", mpanel )
		msnap:SetTooltip("Angle snap value\n\nExtremely janky! Use at your own risk!")
		msnap:SizeToContents()
		msnap:SetTall(20)
		msnap:SetMin(0)
		msnap:SetMax(90)
		msnap:SetValue( wep.ModelDragAngleSnap )
		msnap.OnValueChanged = function( p )
			wep.ModelDragAngleSnap = p:GetValue()
		end
	msnap:DockMargin(5,0,0,0)
	msnap:Dock(RIGHT)

	local mlabel2 = vgui.Create( "DLabel", mpanel )
		mlabel2:SetText( "Angle snap" )
		mlabel2:SizeToContents()
		mlabel2:SetTall(20)
	mlabel2:DockMargin(5,0,0,0)
	mlabel2:Dock(RIGHT)

	local mdraglist = vgui.Create( "DComboBox", mpanel )
		mdraglist:SetWide(150)
		mdraglist:SetTooltip("Hold CTRL to enter elements drag mode.\nHold SHIFT to enter element rotation mode.\n\n  - Hold RMB for 2D axis mode.\n  - Hold LMB and RMB for 1D axis mode.\n  - Use SCROLL WHEEL to adjust drag sensitivity.")
		mdraglist.OnSelect = function( p, index, value )
			wep.selectedModelDragMode = value
		end
		mdraglist:SetText( wep.selectedModelDragMode )
	mdraglist:DockMargin(5,0,0,0)
	mdraglist:Dock(FILL)

	for k, v in pairs( model_drag_modes ) do
		mdraglist:AddChoice(k)
	end

	local tpanel= vgui.Create( "DPanel", f )
		tpanel:SetPaintBackground(false)
		tpanel:SetTall(20)
	tpanel:DockMargin(0,0,0,5)
	tpanel:Dock(TOP)

	local tpsbonelist = vgui.Create( "DComboBox", tpanel )
		tpsbonelist:SetWide(150)
		tpsbonelist:SetTooltip("Bone to focus third person view on")
		tpsbonelist.OnSelect = function( p, index, value )
			wep.tpsfocusbone = value
		end
	tpsbonelist:DockMargin(5,0,0,0)
	tpsbonelist:Dock(RIGHT)

	wep.bonelist = tpsbonelist

	local tlabel = vgui.Create( "DLabel", tpanel )
		tlabel:SetText( "Focus:" )
		tlabel:SizeToContents()
		tlabel:SetTall(20)
	tlabel:DockMargin(10,0,0,0)
	tlabel:Dock(RIGHT)

	PopulateBoneList( tpsbonelist, LocalPlayer() )
	timer.Simple( 1, function()
		if tpsbonelist and wep.tpsfocusbone then
			for i=1, #tpsbonelist.Choices do
				if wep.tpsfocusbone == tpsbonelist.Choices[i] then
					tpsbonelist:ChooseOptionID(i)
					break
				end
			end
			--tpsbonelist:SetText( wep.tpsfocusbone )
		end
	end)

	tpsbonelist.OnMenuOpened = function( self, menu )
		if IsValid( menu ) then
			wep.ShouldShowBones = menu
			for k, v in pairs( menu:GetCanvas():GetChildren() ) do
				local oldOnCursorEntered = v.OnCursorEntered
				v.OnCursorEntered = function( s )
					oldOnCursorEntered( s )
					wep.ShowCurrentBone = s:GetText()
				end
				v.OnCursorExited = function( s )
					wep.ShowCurrentBone = nil
				end
			end
		end
	end

	local yinvcheck = vgui.Create("DCheckBoxLabel", tpanel)
	yinvcheck:SetText("Invert Y")
	yinvcheck:SetConVar("swepck_thirdperson_invy")
	yinvcheck:DockMargin(10,0,0,5)
	yinvcheck:Dock(RIGHT)

	local xinvcheck = vgui.Create("DCheckBoxLabel", tpanel)
	xinvcheck:SetText("Invert X")
	xinvcheck:SetConVar("swepck_thirdperson_invx")
	xinvcheck:DockMargin(0,0,0,5)
	xinvcheck:Dock(RIGHT)

	local tbtn = vgui.Create( "DButton", tpanel )
		tbtn:SetText( "Toggle thirdperson" )
		tbtn.DoClick = function()
			RunConsoleCommand("swepck_togglethirdperson")
		end

	tbtn:Dock(FILL)

	local lock = vgui.Create( "DCheckBoxLabel", f )
	lock:SetTall( 20 )
	lock:SetText( "Lock viewmodel in world space" )
	lock.OnChange = function(self)
		wep.LockViewmodel = self:GetChecked()
	end
	lock:SetValue(0)
	lock:DockMargin(0,0,0,5)
	lock:Dock(TOP)

	local tab = vgui.Create( "DPropertySheet", f )
		f.PropertySheet = tab

		wep.ptool = vgui.Create("DScrollPanel", tab)
		wep.ptool.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.ptool:GetWide(),wep.ptool:GetTall()) end
		wep.pweapon = vgui.Create("DScrollPanel", tab)
		wep.pweapon.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.pweapon:GetWide(),wep.pweapon:GetTall()) end
		wep.pironsight = vgui.Create("DScrollPanel", tab)
		wep.pironsight.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.pironsight:GetWide(),wep.pironsight:GetTall()) end
		wep.pmodels = vgui.Create("DScrollPanel", tab)
		wep.pmodels.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.pmodels:GetWide(),wep.pmodels:GetTall()) end
		wep.pwmodels = vgui.Create("DScrollPanel", tab)
		wep.pwmodels.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.pwmodels:GetWide(),wep.pwmodels:GetTall()) end
		wep.pplayer = vgui.Create("DScrollPanel", tab)
		wep.pplayer.Paint = function() surface.SetDrawColor(70,70,70,255) surface.DrawRect(0,0,wep.pplayer:GetWide(),wep.pplayer:GetTall()) end

		tab:AddSheet( "Tool", wep.ptool, nil, false, false, "Modify tool settings" )
		tab:AddSheet( "Weapon", wep.pweapon, nil, false, false, "Modify weapon settings" )
		tab:AddSheet( "Ironsights", wep.pironsight, nil, false, false, "Modify ironsights" )
		tab:AddSheet( "View Models", wep.pmodels, nil, false, false, "Modify view models" )
		tab:AddSheet( "World Models", wep.pwmodels, nil, false, false, "Modify world models" )
		tab:AddSheet( "Player", wep.pplayer, nil, false, false, "For debug purposes ONLY. These settings are NOT saved in the file" )

		wep.ptool:DockPadding(5, 5, 5, 5)
		wep.pweapon:DockPadding(5, 5, 5, 5)
		wep.pironsight:DockPadding(5, 5, 5, 5)
		wep.pmodels:DockPadding(5, 5, 5, 5)
		wep.pwmodels:DockPadding(5, 5, 5, 5)
		wep.pplayer:DockPadding(5, 5, 5, 5)

	tab:Dock(FILL)

	--[[****************
		Tool page
	****************]]
	include("weapons/"..wep:GetClass().."/menu/tool.lua")

	--[[****************
		Weapon page
	****************]]
	include("weapons/"..wep:GetClass().."/menu/weapon.lua")

	--[[********************
		Ironsights page
	********************]]
	include("weapons/"..wep:GetClass().."/menu/ironsights.lua")

	--[[***************************************
		View models and World models page
	***************************************]]
	include("weapons/"..wep:GetClass().."/menu/models.lua")

	--[[***************************************
		Player helper page
	***************************************]]
	include("weapons/"..wep:GetClass().."/menu/player.lua")

	-- finally, return the frame!
	return f
end

function SWEP:OpenMenu( preset )
	if (!self.Frame) then
		self.Frame = CreateMenu( preset )
	end

	if (IsValid(self.Frame)) then
		self.Frame:SetVisible(true)
		self.Frame:MakePopup()
	else
		self.Frame = nil
	end

end

local cvAutosave = GetConVar("sck_autosave")
local function doautosave(wep)
	if not IsValid(LocalPlayer()) then return end
	if cvAutosave:GetInt() <= 0 then return end

	SaveAsSCKFile("autosaves/autosave_"..os.date("%m_%d_%y-%H_%M_%S"), wep)
end

local delay = math.max(60, cvAutosave:GetInt())

timer.Create("sck_autosave_timer", delay, 0, function()
	doautosave(GetSCKSWEP(LocalPlayer()))
end)

cvars.AddChangeCallback("sck_autosave", function(old, new)
	local newdelay = math.max(60, tonumber(new) or 0)

	timer.Adjust("sck_autosave_timer", newdelay)
end)

function SWEP:OnRemove()
	doautosave(self)

	self:CleanMenu()

	if IsValid( self:GetOwner() ) then
		local vm = self:GetOwner():GetViewModel()
		if IsValid(vm) then
			self:ResetBonePositions(vm)
		end
	end
end

function SWEP:OnDropWeapon()
	self.useThirdPerson = false
	self.LastOwner = nil
	if (!self.Frame) then return end
	self.Frame:Close()
end

function SWEP:CleanMenu()
	self:RemoveModels()

	hook.Remove( "CalcMainActivity", "SCKOverrideActivity" )

	RunConsoleCommand("swepck_playermodelscale", "1")

	if (!self.Frame) then return end

	self.v_modelListing = nil
	self.w_modelListing = nil
	self.v_panelCache = {}
	self.w_panelCache = {}
	self.Frame:Remove()
	self.Frame = nil
end

function SWEP:HUDShouldDraw( el )
	return el != "CHudAmmo" and el != "CHudSecondaryAmmo"
end

--[[**************************
	Third person view
**************************]]
function TPCalcView(pl, pos, angles, fov)

	local wep = pl:GetActiveWeapon()
	if (!IsValid(wep) or !wep.IsSCK or !wep.useThirdPerson) then
		wep.useThirdPerson = false
		return
	end

	local look_pos = pos
	local rhand_bone = pl:LookupBone(wep.tpsfocusbone)
	if (rhand_bone) then
		look_pos = pl:GetBonePosition( rhand_bone )
	end

	local view = {}
	view.origin = look_pos + ((pl:GetAngles()+wep.thirdPersonAngle):Forward()*wep.thirdPersonDis)
	view.angles = (look_pos - view.origin):Angle()
	view.fov = fov

	wep.thirdPersonAngleView = view.angles * 1

	return view
end

oldCVHooks = {}
hooksCleared = false
local function CVHookReset()
	hook.Remove( "CalcView", "TPCalcView" )
	for k, v in pairs( oldCVHooks ) do
		hook.Add("CalcView", k, v)
	end
	oldCVHooks = {}
	hooksCleared = false

end

function SWEP:CalcViewHookManagement()

	if (!hooksCleared) then

		local CVHooks = hook.GetTable()["CalcView"]
		if CVHooks then

			for k, v in pairs( CVHooks ) do
				oldCVHooks[k] = v
				hook.Remove( "CalcView", k )
			end

		end

		hook.Add("CalcView", "TPCalcView", TPCalcView)
		hooksCleared = true
	else
		timer.Create("CVHookReset", 2, 1, CVHookReset)
	end

end

hook.Add("ShouldDrawLocalPlayer", "ThirdPerson", function(pl)
	local wep = pl:GetActiveWeapon()
	if (wep.useThirdPerson) then
		return true
	end
end)

local undo_color = false
local undo_material = false

hook.Add("PrePlayerDraw", "SCKPrePlayerDraw", function( pl, flags )
	local wep = pl:GetActiveWeapon()

	if wep.PlayerColor and bit.band( flags, STUDIO_RENDER ) ~= 0 then
		render.SetColorModulation( wep.PlayerColor.r / 255, wep.PlayerColor.g / 255, wep.PlayerColor.b / 255 )
		render.SetBlend( wep.PlayerColor.a / 255 )
		undo_color = true
	end

	if wep.PlayerMaterial and wep.PlayerMaterialName then
		render.ModelMaterialOverride( wep.PlayerMaterial )
		undo_material = true
	end
end)

hook.Add("PostPlayerDraw", "SCKPostPlayerDraw", function( pl )
	if undo_color then
		render.SetColorModulation( 1, 1, 1 )
		render.SetBlend( 1 )
		undo_color = false
	end

	if undo_material then
		render.ModelMaterialOverride( )
		undo_material = false
	end
end)

CreateClientConVar("swepck_thirdperson_invx", 0, true, false, "Inverts X axis movement in third person.", 0, 1)
CreateClientConVar("swepck_thirdperson_invy", 0, true, false, "Inverts Y axis movement in third person.", 0, 1)
