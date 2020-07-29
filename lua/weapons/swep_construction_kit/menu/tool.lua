
local tutorialURL = "http://www.facepunch.com/threads/1032378-SWEP-Construction-Kit-developer-tool-for-modifying-viewmodels-ironsights/"
local wep = GetSCKSWEP( LocalPlayer() )
local ptool = wep.ptool

local panim = SimplePanel(ptool)
	-- ***** Animations *****

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
		aplayback:SetMinMax( 0, 5 )
		aplayback:SetDecimals( 1 )
		aplayback.Wang.ConVarChanged = function( p, value ) ptool.AnimationPlaybackRate = tonumber(value) end
		aplayback:SetValue( 1 )
		aplayback:SetTall( 25 )
	aplayback:Dock( TOP )

	
panim:SetTall(alabel:GetTall() + agrid:GetTall() + aplayback:GetTall() + 5)
panim:DockPadding(0,5,0,5)
panim:Dock( TOP )

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
		panim:SetTall(alabel:GetTall() + agrid:GetTall() + aplayback:GetTall() + 5)

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

	local psave = SimplePanel(psettings)

		local satext = vgui.Create( "DTextEntry", psave )
			satext:SetTall( 20 )
			satext:SetMultiline(false)
			if (wep.save_data._savename) then
				satext:SetText( wep.save_data._savename )
			else
				satext:SetText( "save1" )
			end
		satext:DockMargin(5,0,0,0)
		satext:Dock(FILL)

		local sabtn = vgui.Create( "DButton", psave )
			sabtn:SetTall( 16 )
			sabtn:SetText( "Save as:" )
			sabtn.DoClick = function()

				if !IsValid(wep) then return end

				local text = string.Trim(satext:GetValue())
				if (text == "") then return end

				local save_data = wep.save_data

				-- collect all save data
				save_data.v_models = table.Copy(wep.v_models)
				save_data.w_models = table.Copy(wep.w_models)
				save_data.v_bonemods = table.Copy(wep.v_bonemods)
				-- remove caches
				for k, v in pairs(save_data.v_models) do
					v.createdModel = nil
					v.createdSprite = nil
				end
				for k, v in pairs(save_data.w_models) do
					v.createdModel = nil
					v.createdSprite = nil
				end
				save_data.ViewModelFlip = wep.ViewModelFlip
				save_data.ViewModel = wep.ViewModel
				save_data.CurWorldModel = wep.CurWorldModel
				save_data.ViewModelFOV = wep.ViewModelFOV
				save_data.HoldType = wep.HoldType
				save_data.IronSightsEnabled = wep:GetIronSights()
				save_data.IronSightsPos, save_data.IronSightsAng = wep:GetIronSightCoordination()
				save_data.ShowViewModel = wep.ShowViewModel
				save_data.ShowWorldModel = wep.ShowWorldModel

				local filename = "swep_construction_kit/"..text..".txt"

				local succ, val = pcall(glon.encode, save_data)
				if (!succ || !val) then LocalPlayer():ChatPrint("Failed to encode settings!") return end

				file.Write(filename, val)
				LocalPlayer():ChatPrint("Saved file \""..text.."\"!")
			end

		sabtn:Dock(LEFT)

	psave:DockMargin(0,5,0,5)
	psave:Dock(TOP)

	local pload = SimplePanel(psettings)

		local lftext = vgui.Create( "DTextEntry", pload )
			lftext:SetTall( 20 )
			lftext:SetMultiline(false)
			lftext:SetText( "save1" )

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
