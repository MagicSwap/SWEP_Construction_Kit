local wep = GetSCKSWEP( LocalPlayer() )
local pplayer = wep.pplayer

local hpbox = vgui.Create( "DCheckBoxLabel", pplayer )
	hpbox:SetTall( 20 )
	hpbox:SetText( "Show player" )
	hpbox.OnChange = function()
		local show_player = hpbox:GetChecked()
		if show_player then
			RunConsoleCommand( "swepck_hideplayer", "0" )
		else
			RunConsoleCommand( "swepck_hideplayer", "1" )
		end
	end
hpbox:SetValue(1)
hpbox:DockMargin(0,0,0,5)
hpbox:Dock(TOP)

local next_p_model = ""

-- Override player model
local pplayer_model = SimplePanel( pplayer )

	local label = vgui.Create( "DLabel", pplayer_model )
		label:SetTall( 20 )
		label:SetWide( 120 )
		label:SetText( "Override player model:" )
	label:Dock(LEFT)

	local text = vgui.Create( "DTextEntry", pplayer_model)
		text:SetTall( 20 )
		text:SetMultiline(false)
		text.OnTextChanged = function()
			local newmod = string.gsub(text:GetValue(), ".mdl", "")
			RunConsoleCommand("swepck_playermodel", newmod)
		end
		text:SetText( LocalPlayer():GetModel() )
		text:OnTextChanged()
	text:Dock(FILL)

	local btn = vgui.Create( "DButton", pplayer_model )
		btn:SetSize( 25, 20 )
		btn:SetText("...")
		btn.DoClick = function()
			wep:OpenModelBrowser( LocalPlayer():GetModel(), function( val ) text:SetText(val) text:OnTextChanged() end )
		end
	btn:Dock(RIGHT)

pplayer_model:DockMargin(0,0,0,5)
pplayer_model:Dock(TOP)

local panim = SimplePanel(pplayer)

local alabel = vgui.Create( "DLabel", panim )
		alabel:SetTall( 18 )
		alabel:SetText( "Override player animation, right click to disable the override:" )
	alabel:Dock( TOP )
	
local agrid = vgui.Create( "DListView", panim )
		agrid:AddColumn("Sequence")
		agrid:AddColumn("Seq ID")
		agrid:AddColumn("ACT Enum")
		agrid:SetMultiSelect( false )
		agrid:SetTall(340)

		function agrid:OnRowSelected(idx, pnl)
			pnl:PlaySequence()
		end
		
		function agrid:OnRowRightClick(idx, pnl)
			self:ClearSelection()
			hook.Remove( "CalcMainActivity", "SCKOverrideActivity" ) 
		end

		agrid.UpdateList = function( self )

			local pl = wep:GetOwner()

			for k, seq in SortedPairs( pl:GetSequenceList() ) do

				local abtn = self:AddLine(seq, k, pl:GetSequenceActivityName(k))
				abtn.PlaySequence = function()
					
					hook.Remove( "CalcMainActivity", "SCKOverrideActivity" ) 
					
					hook.Add("CalcMainActivity","SCKOverrideActivity",function(p,v)
						return -1, p:LookupSequence( seq )
					end)

				end
			end

			self:SetTall(240)
		end
	agrid:DockMargin(0,5,0,0)
	agrid:Dock(TOP)

	agrid.Think = function( self )
	if wep:GetOwner() and pplayer.LastPlayerModel ~= wep:GetOwner():GetModel() and agrid then

		local skip = pplayer.LastPlayerModel == nil
	
		pplayer.LastPlayerModel = wep:GetOwner():GetModel()

		self:Clear()

		self:UpdateList()
		
		if wep.bonelist and not skip then
			timer.Simple(0.1, function()
				if IsValid( wep:GetOwner() ) and wep.bonelist then
				
					local option = PopulateBoneList( wep.bonelist, wep:GetOwner() )
					
					for i=1, #wep.bonelist.Choices do
						if wep.tpsfocusbone == wep.bonelist.Choices[i] then
							wep.bonelist:ChooseOptionID(i)
							option = nil
							break
						end
					end
					
					if option then
						wep.bonelist:ChooseOptionID(1)
					end
					
				end
			end)
		end
		
		if wep.w_panelCache then
			for _, element_list in pairs( wep.w_panelCache ) do
				for k, v in pairs( element_list:GetItems() ) do
					if IsValid( v ) and IsValid( v.bonebox ) then
						timer.Simple(0.1, function()
							if IsValid( v.bonebox ) then
								local option = PopulateBoneList( v.bonebox, wep:GetOwner() )
								if v.data and v.data.bone then
									
									local force_override_bone = true
									
									for i=1, #v.bonebox.Choices do
										if v.data.bone == v.bonebox.Choices[i] then
											v.bonebox:ChooseOptionID(i)
											force_override_bone = false
											break
										end
									end
									
									if force_override_bone and option then
										v.bonebox:ChooseOptionID(1)
									end
								end
							end
						end)
					end
				end
			end
		end
		
		panim:SizeToChildren(false, true)
	end
end
	
panim:SizeToChildren(false, true)
panim:DockPadding(0,5,0,5)
panim:Dock( TOP )
panim.PerformLayout = function(s) s:SizeToChildren(false, true) end

local scslider = vgui.Create( "DNumSlider", pplayer )
	scslider:SetText( "Player model scale:" )
	scslider:SetMinMax( 0.1, 10 )
	scslider:SetDecimals( 1 )
	scslider:SetValue( 1 )
	scslider.Wang.ConVarChanged = function( p, value )
		RunConsoleCommand("swepck_playermodelscale", value)
	end
	scslider.Wang:ConVarChanged(1)
scslider:DockMargin(0,0,0,10)
scslider:Dock(TOP)

local pcolor = SimplePanel(pplayer)
pcolor:SetTall(32*5)

local collabel = vgui.Create( "DLabel", pcolor )
		collabel:SetText( "Player color:" )
		collabel:SizeToContents()
		collabel:SetWide(85)
	collabel:Dock(LEFT)

	local colpicker = vgui.Create("DColorMixer", pcolor )
	colpicker:Dock(FILL)

	colpicker.ValueChanged = function(self, tcol)
		if wep.PlayerColor == nil then wep.PlayerColor = Color( 255, 255, 255, 255 ) end
		
		wep.PlayerColor.r = tcol.r
		wep.PlayerColor.g = tcol.g
		wep.PlayerColor.b = tcol.b
		wep.PlayerColor.a = tcol.a or 255

	end

	local loadcol = wep.PlayerColor or Color( 255, 255, 255, 255 )
	colpicker:SetColor(loadcol)

	pcolor.PerformLayout = function()

	end

pcolor:DockMargin(0,0,0,5)
pcolor:Dock(TOP)

local pmat = SimplePanel(pplayer)
pmat:SetTall(20)

	local matlabel = vgui.Create( "DLabel", pmat )
		matlabel:SetText( "Player material:" )
		matlabel:SetWide(75)
		matlabel:SizeToContentsY()
	matlabel:Dock(LEFT)

	local wtbtn = vgui.Create( "DButton", pmat )
		wtbtn:SetSize( 25, 20 )
		wtbtn:SetText("...")
	wtbtn:Dock(RIGHT)

	local mattext = vgui.Create("DTextEntry", pmat )
		mattext:SetMultiline(false)
		mattext:SetTooltip("Path to the material file")
		mattext.OnTextChanged = function()
			local newmat = mattext:GetValue()
			local newmatmat = Material(newmat)
			if file.Exists("materials/"..newmat..".vmt", "GAME") or newmatmat and not newmatmat:IsError() then
				wep.PlayerMaterial = newmatmat
				wep.PlayerMaterialName = newmat
			else
				wep.PlayerMaterial = nil
				wep.PlayerMaterialName = ""
			end
		end
		mattext:SetText( wep.PlayerMaterialName or "" )
	mattext:DockMargin(10,0,0,0)
	mattext:Dock(FILL)

	wtbtn.DoClick = function()
		wep:OpenMaterialBrowser( wep.PlayerMaterialName or "", function( val ) mattext:SetText(val) mattext:OnTextChanged() end )
	end
	
pmat:DockMargin(0,0,0,5)
pmat:Dock(TOP)
