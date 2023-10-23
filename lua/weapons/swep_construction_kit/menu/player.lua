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

		pplayer.LastPlayerModel = wep:GetOwner():GetModel()

		self:Clear()

		self:UpdateList()
		
		if wep.bonelist then
			PopulateBoneList( wep.bonelist, wep:GetOwner() )
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