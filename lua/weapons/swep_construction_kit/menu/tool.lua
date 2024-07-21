
local wep = GetSCKSWEP( LocalPlayer() )
local ptool = wep.ptool

local panim = SimplePanel(ptool)
	-- ***** Animations *****

	local vcount = vgui.Create("DLabel", panim)
	vcount:SetText("VElement count:")
	vcount:SizeToContents()
	vcount:Dock(TOP)

	local wcount = vgui.Create("DLabel", panim)
	wcount:SetText("WElement count:")
	wcount:SizeToContents()
	wcount:Dock(TOP)

	vcount.Think = function(s)
		local t = wep.v_models

		if not t then return end

		local num = table.Count(t)

		if num == s.Count then return end
		s.Count = num

		s:SetText("VElement Count: "..num)
		s:SizeToContents()
		panim:SizeToChildren(false, true)
	end

	wcount.Think = function(s)
		local t = wep.w_models

		if not t then return end

		local num = table.Count(t)

		if num == s.Count then return end
		s.Count = num

		s:SetText("WElement Count: "..num)
		s:SizeToContents()
		panim:SizeToChildren(false, true)
	end

	local alabel = vgui.Create( "DLabel", panim )
		alabel:SetTall( 18 )
		alabel:SetText( "Play sequence:" )
	alabel:Dock( TOP )

	local agrid = vgui.Create( "DListView", panim )
		agrid:AddColumn("Sequence")
		agrid:AddColumn("Seq ID")
		agrid:AddColumn("ACT Enum")
		agrid:SetTall(240)

		function agrid:OnRowSelected(idx, pnl)
			pnl:PlaySequence()
		end

		agrid.UpdateList = function( self )

			local vm = wep:GetOwner():GetViewModel()

			for k, seq in SortedPairs( vm:GetSequenceList() ) do

				local abtn = self:AddLine(seq, k, vm:GetSequenceActivityName(k))
				abtn.PlaySequence = function()
					local vm = wep:GetOwner():GetViewModel()

					vm:ResetSequenceInfo()
					vm:SetCycle(0)

					local s = vm:LookupSequence( seq )
					if s then
						if game.SinglePlayer() then
							vm:SendViewModelMatchingSequence( s )
						else
							RunConsoleCommand( "swepck_playanimation", s, ptool.AnimationPlaybackRate or 1 )
						end
					end

					vm:SetPlaybackRate( ptool.AnimationPlaybackRate or 1 )

					vm.PlayAnimation = CurTime() + vm:SequenceDuration()

					if string.find( seq, "fire" ) or string.find( seq, "shoot" ) or string.find( seq, "slash" ) or string.find( seq, "hit" ) or string.find( seq, "miss" ) or string.find( seq, "attack" ) or string.find( seq, "fists_" ) then
						LocalPlayer():SetAnimation( PLAYER_ATTACK1 )
					end

					if string.find( seq, "reload" ) then
						LocalPlayer():SetAnimation( PLAYER_RELOAD )
					end
				end
			end

			self:SetTall(240)
		end
	agrid:DockMargin(0,5,0,0)
	agrid:Dock(TOP)

	local aplayback = vgui.Create( "DNumSlider", panim )
		aplayback:SetText( "Sequence Playback Rate" )
		aplayback:SetMinMax( -1, 5 )
		aplayback:SetDecimals( 1 )
		aplayback.Wang.ConVarChanged = function( p, value ) ptool.AnimationPlaybackRate = tonumber(value) end
		aplayback:SetValue( 1 )
		aplayback:SetTall( 25 )
	aplayback:Dock( TOP )

panim:SizeToChildren(false, true)
panim:DockPadding(0,5,0,5)
panim:Dock( TOP )
panim.PerformLayout = function(s) s:SizeToChildren(false, true) end

agrid.Think = function( self )
	if wep:GetOwner():GetViewModel() and ptool.LastViewModel ~= wep:GetOwner():GetViewModel():GetModel() and agrid then

		ptool.LastViewModel = wep:GetOwner():GetViewModel():GetModel()

		self:Clear()

		self:UpdateList()
		panim:SizeToChildren(false, true)
	end
end

local psettings = SimplePanel(ptool)

	-- ***** Settings saving / loading *****
	local function CreateSettingsNote( text )
		local notiflabel = vgui.Create( "DLabel", psettings )
			notiflabel:SetTall( 20 )
			notiflabel:SetText( text )
			notiflabel:SizeToContentsX()

		local notif = vgui.Create( "DNotify" , psettings )
			notif:SetPos( 150, 5 ) -- just hack it in
			notif:SetSize( notiflabel:GetWide(), 20 )
			notif:SetLife( 5 )
		notif:AddItem(notiflabel)

	end
	
	local function CreateDesignBrowser( parent, field )
		
		if parent.SCKBrowser and parent.SCKBrowser:IsValid() then
			parent.SCKBrowser:Remove()
			parent.SCKBrowser = nil
			parent:SetTall( 24 )
			return
		end
		
		if !file.Exists( "swep_construction_kit", "DATA" ) then
			file.CreateDir( "swep_construction_kit" )
		end
		
		local br = vgui.Create( "DFileBrowser", parent )
			br:SetTall( 150 )
			br:Dock( BOTTOM )
			br:DockMargin(5,0,0,0)

			br:SetPath( "DATA" )
			br:SetFileTypes( "*.txt" )
			br:SetBaseFolder( "swep_construction_kit" )
			br:SetOpen( true )
			br:SetCurrentFolder( "swep_construction_kit" )

			function br:OnSelect( path, pnl )
				if field then
					local autosave = string.find( path, "autosaves/" ) and "autosaves/" or ""
					field:SetText( autosave..string.StripExtension( pnl:GetValue( 1 ) ) )
				end	
			end
			
		parent.SCKBrowser = br
		parent:SetTall( 180 )
		
	end

	local selabel = vgui.Create( "DLabel", psettings )
		selabel:SetTall( 20 )
		selabel:SetText( "Configuration:" )
	selabel:Dock(TOP)

	local badsymbols = {"/", "\\", "?", ":", "*", "\"", "|", "<", ">"}
	local function sanitize_filename(text)
		for _, symb in ipairs(badsymbols) do
			text = string.Replace(text, symb, "_")
		end

		return text
	end

	local psave = SimplePanel(psettings)
		
		psave:SetTall( 24 )

		local satext = vgui.Create( "DTextEntry", psave )
			satext:SetTall( 20 )
			satext:SetMultiline(false)
			if (wep.save_data._savename) then
				satext:SetText( wep.save_data._savename )
			else
				satext:SetText( "savename" )
			end
		satext:DockMargin(5,0,0,0)
		satext:Dock(FILL)
		
		local sbrowsebtn = vgui.Create( "DButton", psave )
			sbrowsebtn:SetTall( 16 )
			sbrowsebtn:SetText( "..." )
			
		sbrowsebtn:Dock( RIGHT )
		
		sbrowsebtn.DoClick = function()
			CreateDesignBrowser( psave, satext )
		end

		local sabtn = vgui.Create( "DButton", psave )
			sabtn:SetTall( 16 )
			sabtn:SetText( "Save as:" )

			sabtn.DoClick = function()
				local fn = GetDesiredFilename(satext)

				local filename = "swep_construction_kit/"..fn..".txt"
				if file.Exists(filename, "DATA") then
					Derma_Query("File already exists! Overwrite?", "Warning", "Yes", function() SaveAsSCKFile(nil, wep, satext, true)  end, "No", function() SaveAsSCKFile(nil, wep, satext)  end)
				else
					SaveAsSCKFile(nil, wep, satext)
				end
			end

		sabtn:Dock(LEFT)

	psave:DockMargin(0,5,0,5)
	psave:Dock(TOP)

	local pload = SimplePanel(psettings)

		pload:SetTall( 24 )
	
		local lftext = vgui.Create( "DTextEntry", pload )
			lftext:SetTall( 20 )
			lftext:SetMultiline(false)
			lftext:SetText( "loadname" )

		lftext:DockMargin(5,0,0,0)
		lftext:Dock(FILL)
		
		local browsebtn = vgui.Create( "DButton", pload )
			browsebtn:SetTall( 16 )
			browsebtn:SetText( "..." )
			
		browsebtn:Dock( RIGHT )
		
		browsebtn.DoClick = function()
			CreateDesignBrowser( pload, lftext )
		end
			

		local lfbtn = vgui.Create( "DButton", pload )
			lfbtn:SetTall( 16 )
			lfbtn:SetText( "Load file:" )
			lfbtn.DoClick = function()
			local text = string.Trim(lftext:GetValue())
			if (text == "") then return end
				local filename = "swep_construction_kit/"..text..".txt"

				if (!file.Exists(filename, "DATA")) then
					CreateSettingsNote( "No such file exists!" )
					return
				end

				local glondata = file.Read(filename)
				local succ, new_preset = pcall(glon.decode, glondata)
				if (!succ || !new_preset) then LocalPlayer():ChatPrint("Failed to load settings!") return end

				new_preset._savename = text

				wep:CleanMenu()
				wep:OpenMenu( new_preset )
				LocalPlayer():ChatPrint("Loaded file \""..text.."\"!")
			end
		lfbtn:Dock(LEFT)

	pload:Dock(TOP)

--psettings:SetTall(selabel:GetTall() + lftext:GetTall() + satext:GetTall() + pload:GetTall())
psettings:SetTall(selabel:GetTall() + psave:GetTall() + pload:GetTall() + 24)

psettings.Think = function( self )
	self.NextCheck = self.NextCheck or 0
	if self.NextCheck > CurTime() then return end
	
	if selabel and psave and pload then
		--self:SetTall(selabel:GetTall() + lftext:GetTall() + satext:GetTall() + pload:GetTall())
		self:SetTall(selabel:GetTall() + psave:GetTall() + pload:GetTall() + 24)
	end
	
	self.NextCheck = CurTime() + 0.1
end

psettings:DockPadding(0,5,0,5)
psettings:Dock(TOP)

local function GetWeaponPrintText( wep )
	str = ""
	str = str.."SWEP.HoldType = \""..wep.HoldType.."\"\n"
	str = str.."SWEP.ViewModelFOV = "..wep.ViewModelFOV.."\n"
	str = str.."SWEP.ViewModelFlip = "..tostring(wep.ViewModelFlip).."\n"
	str = str.."SWEP.ViewModel = \""..wep.ViewModel.."\"\n"
	str = str.."SWEP.WorldModel = \""..wep.CurWorldModel.."\"\n"
	str = str.."SWEP.ShowViewModel = "..tostring(wep.ShowViewModel).."\n"
	str = str.."SWEP.ShowWorldModel = "..tostring(wep.ShowWorldModel).."\n"
	str = str.."SWEP.UseHands = "..tostring(wep.UseHands).."\n"
	str = str.."SWEP.ViewModelBoneMods = {"
	local i = 0
	local num = table.Count( wep.v_bonemods )
	for k, v in SortedPairs(wep.v_bonemods) do
		if !(v.scale == Vector(1,1,1) and v.pos == Vector(0,0,0) and v.angle == Angle(0,0,0)) then
			if (i == 0) then str = str.."\n" end
			i = i + 1
			str = str.."\t[\""..k.."\"] = { scale = "..PrintVec( v.scale )..", pos = "..PrintVec( v.pos )..", angle = "..PrintAngle( v.angle ).." }"

			if (i < num) then str = str.."," end
			str = str.."\n"
		end
	end
	str = str.."}"

	str = string.Replace(str,",\n}","\n}") -- remove the last comma

	return str
end


local function GetIronSightPrintText( vec, ang )
	return "SWEP.IronSightsPos = "..PrintVec( vec ).."\nSWEP.IronSightsAng = "..PrintVec( ang )
end

local function GetVModelsText()
	local wep = GetSCKSWEP(LocalPlayer())
	if not IsValid(wep) then return "" end

	local str = "SWEP.VElements = {\n"
	local i = 0
	local num = table.Count(wep.v_models)
	for k, v in SortedPairs( wep.v_models ) do
		if (v.type == "Model") then
			str = str.."\t[\""..k.."\"] = { type = \"Model\", model = \""..v.model.."\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)
			str = str..", angle = "..PrintAngle( v.angle )..", size = "..PrintVec(v.size)..", color = "..PrintColor( v.color )
			str = str..", surpresslightning = "..tostring(v.surpresslightning)..", bonemerge = "..tostring(v.bonemerge)..", highrender = "..tostring(v.highrender)..", nocull = "..tostring(v.nocull)..", material = \""..v.material.."\", skin = "..v.skin
			str = str..", bodygroup = {"
			local i = 0
			for k, v in SortedPairs( v.bodygroup ) do
				if (v <= 0) then continue end
				if ( i != 0 ) then str = str..", " end
				i = 1
				str = str.."["..k.."] = "..v
			end
			str = str.."} }"
		elseif (v.type == "Sprite") then
			str = str.."\t[\""..k.."\"] = { type = \"Sprite\", sprite = \""..v.sprite.."\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)
			str = str..", size = { x = "..v.size.x..", y = "..v.size.y.." }, color = "..PrintColor( v.color )..", nocull = "..tostring(v.nocull)
			str = str..", additive = "..tostring(v.additive)..", vertexalpha = "..tostring(v.vertexalpha)..", vertexcolor = "..tostring(v.vertexcolor)
			str = str..", ignorez = "..tostring(v.ignorez).."}"
		elseif (v.type == "Quad") then
			str = str.."\t[\""..k.."\"] = { type = \"Quad\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)..", angle = "..PrintAngle( v.angle )
			str = str..", size = "..v.size..", draw_func = nil}"
		elseif (v.type == "ClipPlane") then
			str = str.."\t[\""..k.."\"] = { type = \"ClipPlane\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)..", angle = "..PrintAngle( v.angle )
			str = str.."}"
		end

		if (v.type) then
			i = i + 1
			if (i < num) then str = str.."," end
			str = str.."\n"
		end
	end
	str = str.."}"

	return str
end

local function GetWModelsText()
	local wep = GetSCKSWEP( LocalPlayer() )
	if not IsValid(wep) then return "" end

	local str = "SWEP.WElements = {\n"
	local i = 0
	local num = table.Count(wep.w_models)
	for k, v in SortedPairs( wep.w_models ) do
		if (v.type == "Model") then
			str = str.."\t[\""..k.."\"] = { type = \"Model\", model = \""..v.model.."\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)
			str = str..", angle = "..PrintAngle( v.angle )..", size = "..PrintVec(v.size)..", color = "..PrintColor( v.color )
			str = str..", surpresslightning = "..tostring(v.surpresslightning)..", bonemerge = "..tostring(v.bonemerge)..", highrender = "..tostring(v.highrender)..", nocull = "..tostring(v.nocull)..", material = \""..v.material.."\", skin = "..v.skin
			str = str..", bodygroup = {"
			local i = 0
			for k, v in SortedPairs( v.bodygroup ) do
				if (v <= 0) then continue end
				if ( i != 0 ) then str = str..", " end
				i = 1
				str = str.."["..k.."] = "..v
			end
			str = str.."} }"
		elseif (v.type == "Sprite") then
			str = str.."\t[\""..k.."\"] = { type = \"Sprite\", sprite = \""..v.sprite.."\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)
			str = str..", size = { x = "..v.size.x..", y = "..v.size.y.." }, color = "..PrintColor( v.color )..", nocull = "..tostring(v.nocull)
			str = str..", additive = "..tostring(v.additive)..", vertexalpha = "..tostring(v.vertexalpha)..", vertexcolor = "..tostring(v.vertexcolor)
			str = str..", ignorez = "..tostring(v.ignorez).."}"
		elseif (v.type == "Quad") then
			str = str.."\t[\""..k.."\"] = { type = \"Quad\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)..", angle = "..PrintAngle( v.angle )
			str = str..", size = "..v.size..", draw_func = nil}"
		elseif (v.type == "ClipPlane") then
			str = str.."\t[\""..k.."\"] = { type = \"ClipPlane\", bone = \""..v.bone.."\", rel = \""..v.rel.."\", pos = "..PrintVec(v.pos)..", angle = "..PrintAngle( v.angle )
			str = str.."}"
		end

		if (v.type) then
			i = i + 1
			if (i < num) then str = str.."," end
			str = str.."\n"
		end
	end
	str = str.."}"

	str = str.."\n\n"

	return str
end

local function CompileIncompatibleMaterials()
	local list = {}
	local donealready = {}

	for k, v in SortedPairs( wep.w_models ) do
		if not donealready[v.material] and SCKMaterials[v.material] then
			table.insert(list, v.material)
			donealready[v.material] = true
		end
	end

	for k, v in SortedPairs( wep.v_models ) do
		if not donealready[v.material] and SCKMaterials[v.material] then
			table.insert(list, v.material)
			donealready[v.material] = true
		end
	end

	local startstr = "SWEP.SCKMaterials = {"

	for k, v in ipairs(list) do
		startstr = startstr.."\""..v.."\""..", "
	end
	startstr = string.Trim(startstr)
	startstr = startstr.."}"

	return startstr
end

local pcbtn = vgui.Create( "DButton", ptool )
	pcbtn:SetTall( 30 )
	pcbtn:SetText( "Copy SCK to clipboard" )
	pcbtn.DoClick = function()
		local t = ""

		t = t ..GetWeaponPrintText(wep)
		t = t .. "\n\n"

		t = t .. CompileIncompatibleMaterials()
		t = t .. "\n\n"

		local vec, ang = wep:GetIronSightCoordination()
		t = t .. GetIronSightPrintText( vec, ang )

		t = t .. "\n\n"
		t = t .. GetVModelsText()
		t = t .. "\n\n"
		t = t .. GetWModelsText()

		SetClipboardText(t)

		LocalPlayer():ChatPrint("SCK copied to clipboard!")
	end
pcbtn:DockMargin(0,5,0,0)
pcbtn:Dock(TOP)

local prbtn = vgui.Create( "DButton", ptool )
	prbtn:SetTall( 30 )
	prbtn:SetText( "Print SCK to console" )
	prbtn.DoClick = function()
		MsgN("*********************************************")

		for k, v in pairs(string.Explode("\n",GetWeaponPrintText(wep))) do
			MsgN(v)
		end

		local vec, ang = wep:GetIronSightCoordination()
		MsgN(GetIronSightPrintText( vec, ang ))

		for k, v in ipairs(string.Explode("\n",GetVModelsText())) do
			MsgN(v)
		end

		MsgN(" ")

		for k, v in ipairs(string.Explode("\n",GetWModelsText())) do
			MsgN(v)
		end


		MsgN("*********************************************")

		LocalPlayer():ChatPrint("SCK printed to console!")
	end
prbtn:DockMargin(0,5,0,0)
prbtn:Dock(TOP)
