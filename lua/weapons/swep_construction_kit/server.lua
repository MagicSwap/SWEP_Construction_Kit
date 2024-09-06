local function CanPickup( pl, wep )
	if (wep:GetClass() == "swep_construction_kit") then
		return pl:KeyDown(IN_RELOAD) or !wep.Dropped
	end

end
hook.Add("PlayerCanPickupWeapon","SCKPickup",CanPickup)


function SWEP:Deploy()
	self.LastOwner = self:GetOwner()
end

function SWEP:Holster()
	self:SetThirdPerson( false )
	return true
end

function SWEP:OnDrop()
	self:SetThirdPerson( false )
	if (IsValid(self.LastOwner)) then
		self.LastOwner:SendLua("Entity("..self:EntIndex().."):OnDropWeapon()")
	end
	self.LastOwner = nil
end

function SWEP:ForceDesignMode( ent )
	if ent and ent:IsValid() then
		self:SetPos( ent:LocalToWorld( ent:OBBCenter() ) )
		self:SetParent( ent )
		self:SetOwner( ent )
	end
end

local function Cmd_SetHoldType( pl, cmd, args )

	local holdtype = args[1]
	local wep = GetSCKSWEP( pl )
	if (IsValid(wep) and holdtype and table.HasValue( wep:GetHoldTypes(), holdtype )) then
		wep:SetWeaponHoldType( holdtype )
		wep.HoldType = holdtype
	end

end
concommand.Add("swepck_setholdtype", Cmd_SetHoldType)

local function Cmd_ToggleThirdPerson( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		wep:ToggleThirdPerson()
	end

end
concommand.Add("swepck_togglethirdperson", Cmd_ToggleThirdPerson)

local function Cmd_PlayAnimation( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		local anim = tonumber(args[1] or 0)
		local playback = tonumber(args[2] or 1)
		--wep:ResetSequenceInfo()

		local vm = pl:GetViewModel()

		vm:ResetSequenceInfo()
		vm:SetCycle(0)
		vm:SendViewModelMatchingSequence( anim )
		vm:SetPlaybackRate(playback)
	end

end
concommand.Add("swepck_playanimation", Cmd_PlayAnimation)

local function Cmd_HidePlayer( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		local hide = tobool(args[1] or 0)

		pl:SetRenderMode( RENDERMODE_TRANSALPHA )
		pl:SetColor( hide and Color( 0, 0, 0, 0 ) or color_white )

	end

end
concommand.Add("swepck_hideplayer", Cmd_HidePlayer)

local function Cmd_ToggleSights( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		wep:ToggleIronSights()
	end

end
concommand.Add("swepck_toggleironsights", Cmd_ToggleSights)

local function Cmd_ViewModelFOV( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		wep.ViewModelFOV = tonumber(args[1] or wep.ViewModelFOV)
	end

end
concommand.Add("swepck_viewmodelfov", Cmd_ViewModelFOV)

local function Cmd_ViewModel( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (!IsValid(wep)) then return end
	local newmod = args[1] or wep.ViewModel
	newmod = newmod..".mdl"
	if !file.Exists(newmod, "GAME") then return end

	--util.PrecacheModel(newmod)
	wep.ViewModel = newmod
	pl:GetViewModel():SetWeaponModel(Model(newmod), wep)
	pl:SendLua([[LocalPlayer():GetActiveWeapon().ViewModel = "]]..newmod..[["]])
	--pl:SendLua([[LocalPlayer():GetViewModel():SetModel("]]..newmod..[[")]])
	pl:SendLua([[LocalPlayer():GetViewModel():SetWeaponModel(Model("]]..newmod..[["), Entity(]]..wep:EntIndex()..[[))]])

	local quickswitch = nil
	for k, v in pairs( pl:GetWeapons() ) do
		if (v:GetClass() != wep:GetClass()) then
			quickswitch = v:GetClass()
			break
		end
	end

	if (quickswitch) then
		pl:SelectWeapon( quickswitch )
		pl:SelectWeapon( wep:GetClass() )
	else
		pl:ChatPrint("Switch weapons to make the new viewmodel show up")
	end

	--print("Changed viewmodel to \""..wep.ViewModel.."\"")

end
concommand.Add("swepck_viewmodel", Cmd_ViewModel)

local function Cmd_WorldModel( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (!IsValid(wep)) then return end
	local newmod = args[1] or wep.CurWorldModel
	newmod = newmod..".mdl"
	if !file.Exists(newmod, "GAME") then return end

	util.PrecacheModel(newmod)
	wep.CurWorldModel = newmod
	wep:SetModel(newmod)
	pl:SendLua([[LocalPlayer():GetActiveWeapon().CurWorldModel = "]]..newmod..[["]])
	pl:SendLua([[LocalPlayer():GetActiveWeapon():CreateWeaponWorldModel()]])
	--print("Changed worldmodel to \""..wep.CurWorldModel.."\"")

end
concommand.Add("swepck_worldmodel", Cmd_WorldModel)

local function Cmd_PlayerModel( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (!IsValid(wep)) then return end
	local newmod = args[1] or pl:GetModel()
	newmod = newmod..".mdl"
	if !file.Exists(newmod, "GAME") then return end

	util.PrecacheModel(newmod)

	pl:SetModel( newmod )

end
concommand.Add("swepck_playermodel", Cmd_PlayerModel)

local function Cmd_PlayerModelScale( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (!IsValid(wep)) then return end
	local sc = tonumber(args[1] or 1)

	pl:SetModelScale( sc, 0.0001 )

end
concommand.Add("swepck_playermodelscale", Cmd_PlayerModelScale)

local function Cmd_DropWep( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	if (IsValid(wep)) then
		wep.Dropped = true
		pl:DropWeapon(wep)
	end

end
concommand.Add("swepck_dropwep", Cmd_DropWep)

local function Cmd_GiveToEnt( pl, cmd, args )

	local wep = GetSCKSWEP( pl )
	local ent = pl:GetEyeTrace().Entity
	if IsValid(wep) and IsValid( ent ) then
		wep.Dropped = true
		pl:DropWeapon(wep)

		wep:ForceDesignMode( ent )
	end

end
concommand.Add("swepck_givetoent", Cmd_GiveToEnt)