
local tutorialURL = "http://www.facepunch.com/threads/1032378-SWEP-Construction-Kit-developer-tool-for-modifying-viewmodels-ironsights/"
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

	local cols = 4
	local agrid = vgui.Create( "DGrid", panim )
		agrid:SetCols(cols)
		agrid:SetColWide( 106 )
		agrid:SetRowHeight( 24 )

		agrid.UpdateList = function( self )

			local count = 0

			local vm = wep:GetOwner():GetViewModel()

			--for some reason dgrid doesnt want to return all items, so lets use this workaround
			self.buttons = {}

			for k, seq in pairs( vm:GetSequenceList() ) do

				count = count + 1

				local abtn = vgui.Create( "DButton", self )
				abtn:SetSize( 100, 18 )
				abtn:SetText( seq )
				abtn:SetToolTip( "Sequence id: "..k )
				abtn.DoClick = function()

					local vm = wep:GetOwner():GetViewModel()

					vm:ResetSequenceInfo()
					vm:SetCycle(0)


					local s = vm:LookupSequence( seq )
					if s then
						vm:SendViewModelMatchingSequence( s )
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
				self:AddItem(abtn)
				table.insert( self.buttons, abtn )

			end

			self:SetTall( math.ceil(count / cols) * 24 )
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

		if self.buttons then
			for k, v in pairs( self.buttons ) do
				self:RemoveItem( v )
			end
			self.buttons = nil
		end

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

		local lftext = vgui.Create( "DTextEntry", pload )
			lftext:SetTall( 20 )
			lftext:SetMultiline(false)
			lftext:SetText( "loadname" )

		lftext:DockMargin(5,0,0,0)
		lftext:Dock(FILL)

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

psettings:SetTall(selabel:GetTall() + lftext:GetTall() + satext:GetTall() + 30)
psettings:DockPadding(0,5,0,5)
psettings:Dock(TOP)

-- link to FP thread
local threadbtn = vgui.Create( "DButton", ptool )
	threadbtn:SetTall( 30 )
	threadbtn:SetText( "Open Tutorial (Facepunch thread)" )
	threadbtn.DoClick = function()
		gui.OpenURL(tutorialURL) -- Removed in Gmod 13
		--SetClipboardText(tutorialURL)
	end
threadbtn:DockMargin(0,15,0,5)
threadbtn:Dock(TOP)

-- base code
local basecbtn = vgui.Create( "DButton", ptool )
	basecbtn:SetTall( 30 )
	basecbtn:SetText( "Copy SWEP base code to clipboard" )
	basecbtn.DoClick = function()
		SetClipboardText(wep.basecode)
		LocalPlayer():ChatPrint("Base code copied to clipboard!")
	end
basecbtn:DockMargin(0,5,0,0)
basecbtn:Dock(TOP)
