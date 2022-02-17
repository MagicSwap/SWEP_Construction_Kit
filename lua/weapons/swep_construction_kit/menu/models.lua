local icon_model = "icon16/brick.png"
local icon_sprite = "icon16/asterisk_yellow.png"
local icon_quad = "icon16/picture_empty.png"

-- Some hacky shit to keep the relative DComboBoxes updated
local boxes_to_update = {}
local function RegisterRelBox( elementname, box, w_or_v, preset_choice )
	table.insert(boxes_to_update, { box, w_or_v, elementname, preset_choice })
end

local wep = GetSCKSWEP( LocalPlayer() )
local pmodels = wep.pmodels
local pwmodels = wep.pwmodels
local lastVisible = ""

local mlabel = vgui.Create( "DPanel", pmodels )
	mlabel:SetTall( 24 )
	mlabel.Paint = function() end
mlabel:Dock(TOP)

local mlock = vgui.Create( "DButton", mlabel )
	mlock:SetSize( 24, 24 )
	mlock:SetIsToggle( true )
	mlock:SetText("")
	mlock:SetIcon( wep.lockRelativePositions and "icon16/lock.png" or "icon16/lock_open.png" )
	mlock:SetToggle( wep.lockRelativePositions )
	mlock:SetTooltip( "Elements will retain their position when their bone or relative are changed" )
	mlock.Think = function( self )
		self:SetToggle( wep.lockRelativePositions )
		self:SetIcon( wep.lockRelativePositions and "icon16/lock.png" or "icon16/lock_open.png" )
	end
	mlock.OnToggled = function( self, toggleState )
		wep.lockRelativePositions = toggleState
	end

mlock:Dock( RIGHT )

local mlabeltext = vgui.Create( "DLabel", mlabel )
	mlabeltext:SetText( "New viewmodel element:" )
mlabeltext:Dock(FILL)

local function CreateNote( text )
	local templabel = vgui.Create( "DLabel" )
		templabel:SetText( text )
		templabel:SizeToContents()

	local x, y = mlabel:GetPos()
	local notif = vgui.Create( "DNotify" , pmodels )
		notif:SetPos( x + 160, y )
		notif:SetSize( templabel:GetWide(), 20 )
		notif:SetLife( 5 )
		notif:AddItem(templabel)
end

local pnewelement = SimplePanel( pmodels )
pnewelement:SetTall(20)

	local mntext = vgui.Create("DTextEntry", pnewelement )
		mntext:SetTall( 20 )
		mntext:SetMultiline(false)
		mntext:SetText( "element_name" )
	mntext:Dock(FILL)

	local mnbtn = vgui.Create( "DButton", pnewelement )
		mnbtn:SetSize( 50, 20 )
		mnbtn:SetText( "Add" )
	mnbtn:DockMargin(5,0,0,0)
	mnbtn:Dock(RIGHT)

	local tpbox = vgui.Create( "DComboBox", pnewelement )
		tpbox:SetSize( 100, 20 )
		tpbox:SetText( "Model" )
		tpbox:AddChoice( "Model" )
		tpbox:AddChoice( "Sprite" )
		tpbox:AddChoice( "Quad" )
		local boxselected = "Model"
		tpbox.OnSelect = function( p, index, value )
			boxselected = value
		end
	tpbox:DockMargin(5,0,0,0)
	tpbox:Dock(RIGHT)

pnewelement:DockMargin(0,5,0,5)
pnewelement:Dock(TOP)

local function MaintainRelativePosition( name, new_parent_name, v_or_w, overridebone )
	if !wep.lockRelativePositions then return end

	local tbl = v_or_w == "w" and wep.w_models or wep.v_models
	local ent = v_or_w == "w" and LocalPlayer() or LocalPlayer():GetViewModel()

	if !IsValid( ent ) then return end

	if name and tbl[ name ] then

		local el = tbl[ name ]
		local to_bone

		local goal_pos, goal_ang

		if new_parent_name and tbl[ new_parent_name ] then
			local new_el = tbl[ new_parent_name ]
			goal_pos, goal_ang = wep:GetBoneOrientation( tbl, new_parent_name, ent )
			goal_pos = goal_pos + goal_ang:Forward() * new_el.pos.x + goal_ang:Right() * new_el.pos.y + goal_ang:Up() * new_el.pos.z
			if new_el.angle then
				goal_ang:RotateAroundAxis(goal_ang:Up(), new_el.angle.y)
				goal_ang:RotateAroundAxis(goal_ang:Right(), new_el.angle.p)
				goal_ang:RotateAroundAxis(goal_ang:Forward(), new_el.angle.r)
			end
		end

		if new_parent_name == "" then
			to_bone = el.bone
		end

		if overridebone then
			to_bone = overridebone
		end

		if to_bone then
			local bone = ent:LookupBone( to_bone )
			if bone then
				local m = ent:GetBoneMatrix( bone )
				if m then
					goal_pos, goal_ang = m:GetTranslation(), m:GetAngles()
				end
			end
		end

		local el_pos, el_ang = wep:GetBoneOrientation( tbl, name, ent )

		if not el_pos or not el_ang then
			return
		end

		el_pos = el_pos + el_ang:Forward() * el.pos.x + el_ang:Right() * el.pos.y + el_ang:Up() * el.pos.z
		if el.angle then
			el_ang:RotateAroundAxis(el_ang:Up(), el.angle.y)
			el_ang:RotateAroundAxis(el_ang:Right(), el.angle.p)
			el_ang:RotateAroundAxis(el_ang:Forward(), el.angle.r)
		end


		if el_pos and el_ang and goal_pos and goal_ang then
			local save_pos, save_ang = WorldToLocal( el_pos, el_ang, goal_pos, goal_ang )

			-- shakes fist at Clavus
			save_pos.y = save_pos.y * -1
			save_ang.p = save_ang.p * -1

			el.pos = save_pos * 1
			el.angle = save_ang * 1
		end
	end
end

local function SetRelativeForNode( pnl, new_parent, v_or_w )
	local name = pnl:GetText()
	local new_rel = ""

	if not new_parent:IsRootNode() then
		new_rel = new_parent:GetText()
	end

	local data = wep.v_models[name]

	if v_or_w == "w" then
		data = wep.w_models[name]
	end

	if data and new_rel then
		-- make sure it is before we set our relative
		MaintainRelativePosition( name, new_rel, v_or_w )
		data.rel = new_rel
	end
end

local mtree = vgui.Create( "DTree", pmodels)
	mtree:SetTall( 160 )
	wep.v_modelListing = mtree
	mtree:Root():SetDraggableName( "Viewmodel" )

	mtree:Root().OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			v._ParentNode = self
			SetRelativeForNode( v, self, "v" )
		end
	end

	mtree.OnNodeSelected = function( panel )
		local name = mtree:GetSelectedItem():GetText()

		if (wep.v_panelCache[lastVisible]) then
			wep.v_panelCache[lastVisible]:SetVisible(false)
		end
		wep.v_panelCache[name]:SetVisible(true)

		lastVisible = name
		wep.selectedElement = lastVisible
	end

mtree:Dock(TOP)

local pbuttons = SimplePanel( pmodels )

	local rmbtn = vgui.Create( "DButton", pbuttons )
		rmbtn:SetSize( 160, 25 )
		rmbtn:SetText( "Remove selected" )
	rmbtn:Dock(LEFT)

	local copybtn = vgui.Create( "DButton", pbuttons )
		copybtn:SetSize( 160, 25 )
		copybtn:SetText( "Copy selected" )
	copybtn:Dock(RIGHT)

	local importbtn = vgui.Create( "DButton", pbuttons )
		importbtn:SetTall( 25 )
		importbtn:SetText( "Import worldmodels" )
	importbtn:Dock(FILL)

pbuttons:DockMargin(0,5,0,5)
pbuttons:Dock(TOP)

local pCol = 0
local function PanelBackgroundReset()
	pCol = 0
end

local function PanelApplyBackground(panel)
	if (pCol == 1) then
		panel:SetPaintBackground(true)
		panel.Paint = function() surface.SetDrawColor( 85, 85, 85, 255 ) surface.DrawRect( 0, 0, panel:GetWide(), panel:GetTall() ) end
	end

	pCol = (pCol + 1) % 2
end

--track position, angle, and size changes as mouse is down
local ctrlzhistory = {}
local currentzindex = 0

local prevchange
local prevname
local wasmousepressed = false
local wasmousereleased = false
local mousepressed = false

local nextregister = 0
local function handle_undo()
	if #ctrlzhistory == 0 then return end
	if currentzindex == 0 then return end

	local snapshot = ctrlzhistory[currentzindex-1]
	if not snapshot then return end

	local name = snapshot.name
	local data = wep.v_models[name]
	if not data then return end

	for k, v in pairs(snapshot) do
		if k == "name" then continue end

		data[k] = v
	end

	currentzindex = currentzindex - 1

	return true
end

local function handle_redo()
	if #ctrlzhistory == 0 then return end
	if currentzindex == #ctrlzhistory then return end

	local snapshot = table.FullCopy(ctrlzhistory[currentzindex+1])
	if not snapshot then return end

	local name = snapshot.name
	local data = wep.v_models[name]
	if not data then return end

	for k, v in pairs(snapshot) do
		if k == "name" then continue end

		data[k] = v
	end

	currentzindex = currentzindex + 1

	return true
end

local function undoredolisten()
	if nextregister < CurTime() and input.IsKeyDown(KEY_LCONTROL) then
		if input.WasKeyPressed(KEY_Z) then
			handle_undo()

			nextregister = CurTime() + 0.1
			return
		elseif input.WasKeyPressed(KEY_Y) then
			handle_redo()

			nextregister = CurTime() + 0.1
			return
		end
	end
end

local function copy(var)
	if isvector(var) then
		return Vector(var)
	elseif isangle(var) then
		return Angle(var)
	end
end

--we check for mouse press and release since sliders can update continuously
--this means we only save the snapshots when the user releases a mouse button from moving and element
--alternatively, we could start a timer and save snapshots after set intervals if this appears to be too jank in practice
hook.Add("CreateMove", "TrackMouseCTRLZ", function()
	if not IsFirstTimePredicted() and not game.SinglePlayer() then return end
	if not IsValid(wep) then return end
	if LocalPlayer():GetActiveWeapon() ~= wep then return end

	--when testing, the Pressed called more than once, so this is done to filter out the extra calls (IFTP didn't seem to work)
	if (input.WasMousePressed(MOUSE_LEFT) or input.WasMousePressed(MOUSE_RIGHT)) and not wasmousepressed then
		wasmousepressed = true
		wasmousereleased = false
	elseif (input.WasMouseReleased(MOUSE_LEFT) or input.WasMouseReleased(MOUSE_RIGHT)) and not wasmousereleased then
		wasmousepressed = false
		wasmousereleased = true
	end

	undoredolisten()

	if mousepressed ~= wasmousepressed then
		mousepressed = wasmousepressed
		local data = wep.v_models[lastVisible]
		if not data then return end

		if wasmousepressed then
			prevchange = table.FullCopy(data)
			prevname = lastVisible
		elseif prevchange then
			if lastVisible ~= prevname then return end --if we click off of an element, we shouldn't misinterpret that as the angle/pos changing!

			local snapshot = {}
			local snapshotold = {}
			for k, v in pairs(prevchange) do
				if not (k == "pos" or k == "angle" or k == "size") then continue end

				local old = v
				local new = data[k]
				if old == new then continue end

				snapshot[k] = copy(new) --since they're objects, we'll need to copy it or they'll change when the user changes them
				snapshotold[k] = copy(old)
			end

			if table.Count(snapshot) == 0 then return end
			snapshot.name = lastVisible
			snapshotold.name = lastVisible

			--clear our forward history if we make a change (really only matters if we add redo)
			if #ctrlzhistory > currentzindex then
				for i = currentzindex+1, #ctrlzhistory do
					ctrlzhistory[i] = nil
				end
			end

			local key = table.insert(ctrlzhistory, snapshot)
			if key == 1 then
				table.insert(ctrlzhistory, 1, snapshotold)
			end
			currentzindex = #ctrlzhistory
		end
	end
end)

local function CreatePositionModifiers( data, panel )
	panel:SetTall(32*3)
	PanelApplyBackground(panel)

	local trlabel = vgui.Create( "DLabel", panel )
		trlabel:SetText( "Position:" )
		trlabel:SizeToContents()
		trlabel:SetWide(45)
	trlabel:Dock(LEFT)

	local mxwang = vgui.Create( "DNumSlider", panel )
		mxwang:SetText("x")
		mxwang:SetMinMax( -80, 80 )
		mxwang:SetDecimals( 3 )
		mxwang.Wang.ConVarChanged = function( p, value ) data.pos.x = tonumber(value) end
		mxwang:SetValue( data.pos.x )
		mxwang.Think = function( self )
			if data and data.pos and data.pos.x and data.pos.x ~= self:GetValue() then
				self:SetValue( data.pos.x )
			end
		end
	mxwang:DockMargin(10,0,0,0)

	local mywang = vgui.Create( "DNumSlider", panel )
		mywang:SetText("y")
		mywang:SetMinMax( -80, 80 )
		mywang:SetDecimals( 3 )
		mywang.Wang.ConVarChanged = function( p, value ) data.pos.y = tonumber(value) end
		mywang:SetValue( data.pos.y )
		mywang.Think = function( self )
			if data and data.pos and data.pos.y and data.pos.y ~= self:GetValue() then
				self:SetValue( data.pos.y )
			end
		end
	mywang:DockMargin(10,0,0,0)

	local mzwang = vgui.Create( "DNumSlider", panel )
		mzwang:SetText("z")
		mzwang:SetMinMax( -80, 80 )
		mzwang:SetDecimals( 3 )
		mzwang.Wang.ConVarChanged = function( p, value ) data.pos.z = tonumber(value) end
		mzwang:SetValue( data.pos.z )
		mzwang.Think = function( self )
			if data and data.pos and data.pos.z and data.pos.z ~= self:GetValue() then
				self:SetValue( data.pos.z )
			end
		end
	mzwang:DockMargin(10,0,0,0)

	panel.PerformLayout = function()
		mxwang:SetWide(panel:GetWide()*4/15)
		mywang:SetWide(panel:GetWide()*4/15)
		mzwang:SetWide(panel:GetWide()*4/15)
	end

	mxwang:Dock(TOP)
	mywang:Dock(TOP)
	mzwang:Dock(TOP)

	return panel
end

local function CreateAngleModifiers( data, panel )
	panel:SetTall(32*3)
	PanelApplyBackground(panel)

	local anlabel = vgui.Create( "DLabel", panel )
		anlabel:SetText( "Angle:" )
		anlabel:SizeToContents()
		anlabel:SetWide(45)
	anlabel:Dock(LEFT)

	local mpitchwang = vgui.Create( "DNumSlider", panel )
		mpitchwang:SetText("pitch")
		mpitchwang:SetMinMax( -180, 180 )
		mpitchwang:SetDecimals( 3 )
		mpitchwang.Wang.ConVarChanged = function( p, value ) data.angle.p = tonumber(value) end
		mpitchwang:SetValue( data.angle.p )
		mpitchwang.Think = function( self )
			if data and data.angle and data.angle.p and data.angle.p ~= self:GetValue() then
				self:SetValue( data.angle.p )
			end
		end
	mpitchwang:DockMargin(10,0,0,0)

	local myawwang = vgui.Create( "DNumSlider", panel )
		myawwang:SetText("yaw")
		myawwang:SetMinMax( -180, 180 )
		myawwang:SetDecimals( 3 )
		myawwang.Wang.ConVarChanged = function( p, value ) data.angle.y = tonumber(value) end
		myawwang:SetValue( data.angle.y )
		myawwang.Think = function( self )
			if data and data.angle and data.angle.y and data.angle.y ~= self:GetValue() then
				self:SetValue( data.angle.y )
			end
		end
	myawwang:DockMargin(10,0,0,0)

	local mrollwang = vgui.Create( "DNumSlider", panel )
		mrollwang:SetText("roll")
		mrollwang:SetMinMax( -180, 180 )
		mrollwang:SetDecimals( 3 )
		mrollwang.Wang.ConVarChanged = function( p, value ) data.angle.r = tonumber(value) end
		mrollwang:SetValue( data.angle.r )
		mrollwang.Think = function( self )
			if data and data.angle and data.angle.r and data.angle.r ~= self:GetValue() then
				self:SetValue( data.angle.r )
			end
		end
	mrollwang:DockMargin(10,0,0,0)

	panel.PerformLayout = function()
		mrollwang:SetWide(panel:GetWide()*4/15)
		myawwang:SetWide(panel:GetWide()*4/15)
		mpitchwang:SetWide(panel:GetWide()*4/15)
	end

	mpitchwang:Dock(TOP)
	myawwang:Dock(TOP)
	mrollwang:Dock(TOP)

	return panel
end

local function CreateSizeModifiers( data, panel, dimensions )
	panel:SetTall(32*( dimensions + 1 ))
	PanelApplyBackground(panel)

	local sizelabel = vgui.Create( "DLabel", panel )
		sizelabel:SetText( "Size:" )
		sizelabel:SizeToContents()
		sizelabel:SetWide(45)
	sizelabel:Dock(LEFT)

	local msx2wang, msywang, mszwang

	local msxwang = vgui.Create( "DNumSlider", panel )
		msxwang:SetMinMax( -1, 50 )//0.01, 1000
		msxwang:SetDecimals( 3 )

	if (dimensions > 1 ) then

		msx2wang = vgui.Create( "DNumSlider", panel )
			msx2wang:SetText("x")
			msx2wang:SetMinMax( -1, 50 )
			msx2wang:SetDecimals( 3 )
			msx2wang.Wang.ConVarChanged = function( p, value ) data.size.x = tonumber(value) end
		msx2wang:DockMargin(10,0,0,0)
		msx2wang:Dock(TOP)

		msywang = vgui.Create( "DNumSlider", panel )
			msywang:SetText("y")
			msywang:SetMinMax( -1, 50 )
			msywang:SetDecimals( 3 )
			msywang.Wang.ConVarChanged = function( p, value ) data.size.y = tonumber(value) end
		msywang:DockMargin(10,0,0,0)
		msywang:Dock(TOP)

		if (dimensions > 2) then
			mszwang = vgui.Create( "DNumSlider", panel )
				mszwang:SetText("z")
				mszwang:SetMinMax( -1, 50 )
				mszwang:SetDecimals( 3 )
				mszwang.Wang.ConVarChanged = function( p, value ) data.size.z = tonumber(value) end
			mszwang:DockMargin(10,0,0,0)
			mszwang:Dock(TOP)
		end

	end

	-- make the x numberwang set the total size
	msxwang.Wang.ConVarChanged = function( p, value )
		if (mszwang) then
			mszwang:SetValue( value )
		end
		if (msywang) then
			msywang:SetValue( value )
		end
		if (msx2wang) then
			msx2wang:SetValue( value )
		end

		if dimensions <= 1 then
			data.size = tonumber(value)
		end
	end

	msxwang:DockMargin(10,0,0,0)
	msxwang:Dock(TOP)

	if dimensions == 1 then
		msxwang:SetText("factor")
		msxwang:SetValue( data.size )
	else
		local new_y = data.size.y
		local new_z = data.size.z

		msxwang:SetText("x / y")
		msxwang:SetValue( data.size.x )
		msywang:SetValue( new_y )

		if mszwang then
			msxwang:SetText("x / y / z")
			mszwang:SetValue( new_z )
		end
	end

	return panel
end

local function CreateColorModifiers( data, panel )
	panel:SetTall(32*5)
	panel.data = data
	PanelApplyBackground(panel)

	local collabel = vgui.Create( "DLabel", panel )
		collabel:SetText( "Color:" )
		collabel:SizeToContents()
		collabel:SetWide(45)
	collabel:Dock(LEFT)

	local colpicker = vgui.Create("DColorMixer", panel)
	colpicker:Dock(FILL)

	colpicker.ValueChanged = function(self, tcol)
		panel.data.color.r = tcol.r
		panel.data.color.g = tcol.g
		panel.data.color.b = tcol.b
		panel.data.color.a = tcol.a or 255
	end

	local loadcol = Color(data.color.r or 255, data.color.g or 255, data.color.b or 255, data.color.a or 255)
	colpicker:SetColor(loadcol)

	panel.PerformLayout = function()

	end

	return panel
end

local function CreateModelModifier( data, panel )
	panel:SetTall(20)

	local pmolabel = vgui.Create( "DLabel", panel )
		pmolabel:SetText( "Model:" )
		pmolabel:SetWide(60)
		pmolabel:SizeToContentsY()
	pmolabel:Dock(LEFT)

	local wtbtn = vgui.Create( "DButton", panel )
		wtbtn:SetSize( 25, 20 )
		wtbtn:SetText("...")
	wtbtn:Dock(RIGHT)

	local pmmtext = vgui.Create( "DTextEntry", panel )
		pmmtext:SetMultiline(false)
		pmmtext:SetTooltip("Path to the model file")
		pmmtext.OnTextChanged = function()
			local newmod = pmmtext:GetValue()
			if file.Exists(newmod, "GAME") then
				util.PrecacheModel(newmod)
				data.model = newmod
			end
		end
		pmmtext:SetText( data.model )
		pmmtext.OnTextChanged()
	pmmtext:DockMargin(10,0,0,0)
	pmmtext:Dock(FILL)

	wtbtn.DoClick = function()
		wep:OpenModelBrowser( data.model, function( val ) pmmtext:SetText(val) pmmtext:OnTextChanged() end )
	end

	return panel
end

local function CreateSpriteModifier( data, panel )
	panel:SetTall(20)

	local pmolabel = vgui.Create( "DLabel", panel )
		pmolabel:SetText( "Sprite:" )
		pmolabel:SetWide(60)
		pmolabel:SizeToContentsY()
	pmolabel:Dock(LEFT)

	local wtbtn = vgui.Create( "DButton", panel )
		wtbtn:SetSize( 25, 20 )
		wtbtn:SetText("...")
	wtbtn:Dock(RIGHT)

	local pmmtext = vgui.Create( "DTextEntry", panel )
		pmmtext:SetMultiline(false)
		pmmtext:SetTooltip("Path to the sprite material")
		pmmtext.OnTextChanged = function()
			local newsprite = pmmtext:GetValue()
			if file.Exists("materials/"..newsprite..".vmt", "GAME") then
				data.sprite = newsprite
			end
		end
		pmmtext:SetText( data.sprite )
		pmmtext.OnTextChanged()
	pmmtext:DockMargin(10,0,0,0)
	pmmtext:Dock(FILL)

	wtbtn.DoClick = function()
		wep:OpenMaterialBrowser(data.sprite, function( val ) pmmtext:SetText(val) pmmtext:OnTextChanged() end )
	end

	return panel
end

local function renamev(old, new, panel)
	local wep = GetSCKSWEP( LocalPlayer() )
	if wep.v_panelCache[old] and not wep.v_panelCache[new] then
		wep.v_panelCache[new] = wep.v_panelCache[old]
		wep.v_panelCache[old] = nil
		wep.v_models[new] = table.Copy(wep.v_models[old])
		wep.v_models[old] = nil

		-- update da reference for our color panel
		for k, v in pairs( wep.v_panelCache[new]:GetItems() ) do
			if IsValid( v ) and v.data then
				v.data = wep.v_models[new]
			end
		end

		panel.m_PrevName = new

		local listing = wep.v_modelListing

		local item = listing:GetSelectedItem()
		if IsValid(item) and item:GetText() == old then
			item:SetText(new)

			if lastVisible == old then
				lastVisible = new
			end

			for k, v in pairs( item:GetChildNodes() ) do
				SetRelativeForNode( v, item, "v" )
			end
		end
	end
end

local function renamew(old, new, panel)
	local wep = GetSCKSWEP(LocalPlayer())
	if wep.w_panelCache[old] and not wep.w_panelCache[new] then
		wep.w_panelCache[new] = wep.w_panelCache[old]
		wep.w_panelCache[old] = nil
		wep.w_models[new] = table.Copy(wep.w_models[old])
		wep.w_models[old] = nil

		-- update da reference for our color panel
		for k, v in pairs( wep.w_panelCache[new]:GetItems() ) do
			if IsValid( v ) and v.data then
				v.data = wep.w_models[new]
			end
		end

		panel.m_PrevName = new

		local listing = wep.w_modelListing
		local item = listing:GetSelectedItem()
		if IsValid(item) and item:GetText() == old then
			item:SetText(new)

			if lastVisible == old then
				lastVisible = new
			end

			for k, v in pairs( item:GetChildNodes() ) do
				SetRelativeForNode( v, item, "w" )
			end
		end
	end
end

local function CreateNameLabel(name, panel, world)
	panel:SetTall(20)

	local pnmlabel = vgui.Create( "DLabel", panel )
	pnmlabel:SetText("Name: ")
	pnmlabel:SizeToContents()
	pnmlabel:Dock(LEFT)

	local nametxt = vgui.Create("DTextEntry", panel)
	nametxt:SetText(name)
	nametxt:MoveRightOf(pnmlabel)
	nametxt:Dock(FILL)

	panel.m_PrevName = name

	local rename = world and renamew or renamev
	nametxt.OnValueChange = function(s, txt)
		rename(panel.m_PrevName, txt, panel)
	end

	nametxt.OnLoseFocus = function()
		rename(panel.m_PrevName, nametxt:GetValue(), panel)
	end

	return panel
end

local function CreateParamModifiers( data, panel )
	panel:SetTall(45)

	local strip1 = SimplePanel( panel )
	strip1:SetTall(20)

		local ncchbox = vgui.Create( "DCheckBoxLabel", strip1 )
			ncchbox:SetText("$nocull")
			ncchbox:SizeToContents()
			ncchbox:SetValue( 0 )
			ncchbox.OnChange = function()
				data.nocull = ncchbox:GetChecked()
				data.spriteMaterial = nil -- dump old material
			end
			if (data.nocull) then ncchbox:SetValue( 1 ) end
		ncchbox:DockMargin(0,0,10,0)
		ncchbox:Dock(LEFT)

		local adchbox = vgui.Create( "DCheckBoxLabel", strip1 )
			adchbox:SetText("$additive")
			adchbox:SizeToContents()
			adchbox:SetValue( 0 )
			adchbox.OnChange = function()
				data.additive = adchbox:GetChecked()
				data.spriteMaterial = nil -- dump old material
			end
			if (data.additive) then adchbox:SetValue( 1 ) end
		adchbox:DockMargin(0,0,10,0)
		adchbox:Dock(LEFT)

		local vtachbox = vgui.Create( "DCheckBoxLabel", strip1 )
			vtachbox:SetText("$vertexalpha")
			vtachbox:SizeToContents()
			vtachbox:SetValue( 0 )
			vtachbox.OnChange = function()
				data.vertexalpha = vtachbox:GetChecked()
				data.spriteMaterial = nil -- dump old material
			end
			if (data.vertexalpha) then vtachbox:SetValue( 1 ) end
		vtachbox:DockMargin(0,0,10,0)
		vtachbox:Dock(LEFT)

	strip1:DockMargin(0,0,0,5)
	strip1:Dock(TOP)

	local strip2 = SimplePanel( panel )
	strip2:SetTall(20)

		local vtcchbox = vgui.Create( "DCheckBoxLabel", strip2 )
			vtcchbox:SetText("$vertexcolor")
			vtcchbox:SizeToContents()
			vtcchbox:SetValue( 0 )
			vtcchbox.OnChange = function()
				data.vertexcolor = vtcchbox:GetChecked()
				data.spriteMaterial = nil -- dump old material
			end
			if (data.vertexcolor) then vtcchbox:SetValue( 1 ) end
		vtcchbox:DockMargin(0,0,10,0)
		vtcchbox:Dock(LEFT)

		local izchbox = vgui.Create( "DCheckBoxLabel", strip2 )
			izchbox:SetText("$ignorez")
			izchbox:SizeToContents()
			izchbox:SetValue( 0 )
			izchbox.OnChange = function()
				data.ignorez = izchbox:GetChecked()
				data.spriteMaterial = nil -- dump old material
			end
			if (data.ignorez) then izchbox:SetValue( 1 ) end
		izchbox:DockMargin(0,0,10,0)
		izchbox:Dock(LEFT)

	strip2:Dock(TOP)

	return panel
end

local function CreateMaterialModifier( data, panel )
	panel:SetTall(20)

	local matlabel = vgui.Create( "DLabel", panel )
		matlabel:SetText( "Material:" )
		matlabel:SetWide(60)
		matlabel:SizeToContentsY()
	matlabel:Dock(LEFT)

	local wtbtn = vgui.Create( "DButton", panel )
		wtbtn:SetSize( 25, 20 )
		wtbtn:SetText("...")
	wtbtn:Dock(RIGHT)

	local mattext = vgui.Create("DTextEntry", panel )
		mattext:SetMultiline(false)
		mattext:SetTooltip("Path to the material file")
		mattext.OnTextChanged = function()
			local newmat = mattext:GetValue()
			local newmatmat = Material(newmat)
			if file.Exists("materials/"..newmat..".vmt", "GAME") or newmatmat and not newmatmat:IsError() then
				data.material = newmat
			else
				data.material = ""
			end
		end
		mattext:SetText( data.material )
	mattext:DockMargin(10,0,0,0)
	mattext:Dock(FILL)

	wtbtn.DoClick = function()
		wep:OpenMaterialBrowser( data.material, function( val ) mattext:SetText(val) mattext:OnTextChanged() end )
	end

	return panel
end

local function CreateSLightningModifier( data, panel )
	local lschbox = vgui.Create( "DCheckBoxLabel", panel )
		lschbox:SetText("Surpress engine lightning")
		lschbox:SizeToContents()
		lschbox.OnChange = function()
			data.surpresslightning = lschbox:GetChecked()
		end
		if (data.surpresslightning) then
			lschbox:SetValue( 1 )
		else
			lschbox:SetValue( 0 )
		end
	lschbox:Dock(LEFT)

	return panel
end

local function CreateBoneModifier( data, panel, ent, name )
	local pbonelabel = vgui.Create( "DLabel", panel )
		pbonelabel:SetText( "Bone:" )
		pbonelabel:SetWide(60)
		pbonelabel:SizeToContentsY()
	pbonelabel:Dock(LEFT)

	local bonebox = vgui.Create( "DComboBox", panel )
		bonebox:SetTooltip("Bone to parent the selected element to. Is ignored if the 'Relative' field is not empty")
		bonebox.OnSelect = function( p, index, value )
			-- dont mess shit up if there is a relative already
			if data.rel == "" then
				MaintainRelativePosition( name, nil, ent:IsPlayer() and "w" or "v", value )
			end

			data.bone = value
		end
		bonebox:SetValue( data.bone )
	bonebox:DockMargin(10,0,0,0)
	bonebox:Dock(FILL)

	local delay = 0
	-- we have to call it later when loading settings because the viewmodel needs to be changed first
	if (data.bone != "") then delay = 2 end

	timer.Simple(delay, function()
		if not IsValid(bonebox) then return end
		local option = PopulateBoneList( bonebox, ent )
		if (option and data.bone == "") then
			bonebox:ChooseOptionID(1)
		else
			bonebox:SetValue( data.bone )
		end
	end)

	if !ent:IsPlayer() then
		panel.bonebox = bonebox
	end

	return panel
end

local function CreateVRelativeModifier( name, data, panel )
	local prellabel = vgui.Create( "DLabel", panel )
		prellabel:SetText( "Relative:" )
		prellabel:SetWide(60)
		prellabel:SizeToContentsY()
	prellabel:Dock(LEFT)

	local relbox = vgui.Create( "DComboBox", panel )
		relbox:SetTooltip("Element you want to parent this element to (position and angle become relative). Overrides parenting to a bone if not blank.")
		relbox.OnSelect = function( p, index, value )
			data.rel = value
		end
	relbox:DockMargin(10,0,0,0)
	relbox:Dock(FILL)

	RegisterRelBox(name, relbox, "v", data.rel)

	return panel
end

local function CreateWRelativeModifier( name, data, panel )
	local prellabel = vgui.Create( "DLabel", panel )
		prellabel:SetText( "Relative:" )
		prellabel:SetWide(60)
		prellabel:SizeToContentsY()
	prellabel:Dock(LEFT)

	local relbox = vgui.Create( "DComboBox", panel )
		relbox:SetTooltip("Element you want to parent this element to (position and angle become relative). Overrides parenting to a bone if not blank.")
		relbox.OnSelect = function( p, index, value )
			data.rel = value
		end
	relbox:DockMargin(10,0,0,0)
	relbox:Dock(FILL)

	RegisterRelBox(name, relbox, "w", data.rel)

	return panel
end

local function CreateBodygroupSkinModifier( data, panel )
	local bdlabel = vgui.Create( "DLabel", panel )
		bdlabel:SetText( "Bodygroup:" )
		bdlabel:SizeToContents()
	bdlabel:Dock(LEFT)

	local bdwang = vgui.Create( "DNumberWang", panel )
		bdwang:SetSize( 30, 20 )
		bdwang:SetMinMax( 1, 9 )
		bdwang:SetDecimals( 0 )
		bdwang:SetTooltip("Bodygroup number")
	bdwang:DockMargin(10,0,0,0)
	bdwang:Dock(LEFT)

	local islabel = vgui.Create( "DLabel", panel )
		islabel:SetSize( 10, 20 )
		islabel:SetText( "=" )
	islabel:DockMargin(1,0,1,0)
	islabel:Dock(LEFT)

	local bdvwang = vgui.Create( "DNumberWang", panel )
		bdvwang:SetSize( 30, 20 )
		bdvwang:SetMinMax( 0, 9 )
		bdvwang:SetDecimals( 0 )
		bdvwang:SetTooltip("State number")
	bdvwang:Dock(LEFT)

	bdvwang.ConVarChanged = function( p, value )
		local group = tonumber(bdwang:GetValue())
		local val = tonumber(value)
		data.bodygroup[group] = val
	end
	bdvwang:SetValue(0)

	bdwang.ConVarChanged = function( p, value )
		local group = tonumber(value)
		if (group < 1) then return end
		local setval = data.bodygroup[group] or 0
		bdvwang:SetValue(setval)
	end
	bdwang:SetValue(1)

	local sklabel = vgui.Create( "DLabel", panel )
		sklabel:SetText( "Skin:" )
		sklabel:SizeToContents()
	sklabel:DockMargin(50,0,0,0)
	sklabel:Dock(LEFT)

	local skwang = vgui.Create( "DNumberWang", panel )
		skwang:SetSize( 30, 20 )
		skwang:SetMin( 0 )
		skwang:SetMax( 9 )
		skwang:SetDecimals( 0 )
		skwang.ConVarChanged = function( p, value ) data.skin = tonumber(value) end
		skwang:SetValue(data.skin)
	skwang:DockMargin(10,0,0,0)
	skwang:Dock(LEFT)

	return panel
end

--[[** Model panel for adjusting models ***
Name:
Model:
Bone name:
Translation x / y / z
Rotation pitch / yaw / role
Model size x / y / z
Material
Color modulation
]]
local function CreateModelPanel( name, preset_data )
	local data = wep.v_models[name]
	if (!preset_data) then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Model"
	data.model = preset_data.model or ""
	data.bone = preset_data.bone or ""
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.angle = preset_data.angle or Angle(0,0,0)
	data.size = preset_data.size or Vector(0.5,0.5,0.5)
	data.color = preset_data.color and Color( preset_data.color.r, preset_data.color.g, preset_data.color.b, preset_data.color.a ) or Color(255,255,255,255)
	data.surpresslightning = preset_data.surpresslightning or false
	data.material = preset_data.material or ""
	data.bodygroup = preset_data.bodygroup or {}
	data.skin = preset_data.skin or 0

	wep.vRenderOrder = nil -- force viewmodel render order to recache

	local panellist = vgui.Create("DPanelList", pmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name, SimplePanel(panellist) ))
	panellist:AddItem(CreateModelModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer():GetViewModel(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateAngleModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 3 ))
	panellist:AddItem(CreateColorModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSLightningModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateMaterialModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBodygroupSkinModifier( data, SimplePanel(panellist) ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist

end

--[[** Sprite panel for adjusting sprites ***
Name:
Sprite:
Bone name:
Translation x / y / z
Sprite x / y size
Color
]]
local function CreateSpritePanel( name, preset_data )
	local data = wep.v_models[name]
	if (!preset_data) then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Sprite"
	data.sprite = preset_data.sprite or ""
	data.bone = preset_data.bone or ""
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.size = preset_data.size or { x = 1, y = 1 }
	data.color = preset_data.color and Color( preset_data.color.r, preset_data.color.g, preset_data.color.b, preset_data.color.a ) or Color(255,255,255,255)
	data.nocull = preset_data.nocull or true
	data.additive = preset_data.additive or true
	data.vertexalpha = preset_data.vertexalpha or true
	data.vertexcolor = preset_data.vertexcolor or true
	data.ignorez = preset_data.ignorez or false

	wep.vRenderOrder = nil

	local panellist = vgui.Create("DPanelList", pmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name,SimplePanel(panellist) ))
	panellist:AddItem(CreateSpriteModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer():GetViewModel(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 2 ))
	panellist:AddItem(CreateColorModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateParamModifiers( data, SimplePanel(panellist) ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist
end

--[[** Model panel for adjusting models ***
Name:
Model:
Bone name:
Translation x / y / z
Rotation pitch / yaw / role
Size
]]
local function CreateQuadPanel( name, preset_data )
	local data = wep.v_models[name]
	if (!preset_data) then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Quad"
	data.model = preset_data.model or ""
	data.bone = preset_data.bone or ""
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.angle = preset_data.angle or Angle(0,0,0)
	data.size = preset_data.size or 0.05

	wep.vRenderOrder = nil -- force viewmodel render order to recache

	local panellist = vgui.Create("DPanelList", pmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name, SimplePanel(panellist) ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer():GetViewModel(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateAngleModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 1 ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist
end

-- dark magic, do not touch
local function FixInsertNode( self, pNode )
	self:CreateChildNodes()
	pNode:SetRoot( self:GetRoot() )
	self:InstallDraggable( pNode )
	self.ChildNodes:Add( pNode )
	pNode._ParentNode = self
	self:InvalidateLayout()

	return pNode
end

-- adding button DoClick
mnbtn.DoClick = function()
	local new = string.Trim( mntext:GetValue() )
	if not new then return end

	if new == "" then CreateNote("Empty name field!") return end
	if wep.v_models[new] != nil then CreateNote("Name already exists!") return end
	wep.v_models[new] = {}

	local icon = "icon16/exclamation.png"

	if not wep.v_panelCache[new] then
		if boxselected == "Model" then
			wep.v_panelCache[new] = CreateModelPanel( new )
			icon = icon_model
		elseif boxselected == "Sprite" then
			wep.v_panelCache[new] = CreateSpritePanel( new )
			icon = icon_sprite
		elseif boxselected == "Quad" then
			wep.v_panelCache[new] = CreateQuadPanel( new )
			icon = icon_quad
		else
			Error("Invalid type selected")
		end
	end

	wep.v_panelCache[new]:SetVisible(false)

	local node = mtree:AddNode( new, icon )
	node.Type = boxselected
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "v" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "v" )
		end
	end
end

local temp_v_nodes = {}
for k, v in SortedPairs(wep.save_data.v_models) do
	wep.v_models[k] = {}

	local icon = "icon16/exclamation.png"

	if (v.type == "Model") then
		wep.v_panelCache[k] = CreateModelPanel( k, v )
		icon = icon_model
	elseif (v.type == "Sprite") then
		wep.v_panelCache[k] = CreateSpritePanel( k, v )
		icon = icon_sprite
	elseif (v.type == "Quad") then
		wep.v_panelCache[k] = CreateQuadPanel( k, v )
		icon = icon_quad
	end

	if !IsValid(wep.v_panelCache[k]) then continue end

	wep.v_panelCache[k]:SetVisible(false)

	local node = mtree:AddNode( k, icon )
	node.Type = v.type
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "v" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "v" )
		end
	end

	temp_v_nodes[k] = node
end

for k, v in SortedPairs( wep.v_models ) do
	if v.rel and v.rel ~= "" and temp_v_nodes[v.rel] and temp_v_nodes[k] and wep.v_models[v.rel] then
		temp_v_nodes[v.rel]:InsertNode( temp_v_nodes[k] )
	end
end

-- remove a line
rmbtn.DoClick = function()
	local line = mtree:GetSelectedItem()

	if not IsValid(line) then return end

	local name = line:GetText()

	for k,v in pairs( line:GetChildNodes() ) do
		mtree:Root():InsertNode( v )
		SetRelativeForNode( v, mtree:Root(), "v" )
	end

	wep.v_models[name] = nil
	-- clear from panel cache
	if wep.v_panelCache[name] then
		wep.v_panelCache[name]:Remove()
		wep.v_panelCache[name] = nil
	end

	line:Remove()
end

-- duplicate line
copybtn.DoClick = function()
	local line = mtree:GetSelectedItem()
	if not IsValid(line) then return end

	local name = line:GetText()
	local to_copy = wep.v_models[name]
	local new_preset = table.Copy(to_copy)

	-- quickly generate a new unique name
	while(wep.v_models[name]) do
		name = name.."+"
	end

	-- have to fix every sub-table as well because table.Copy copies references
	new_preset.pos = Vector(to_copy.pos.x, to_copy.pos.y, to_copy.pos.z)
	if (to_copy.angle) then
		new_preset.angle = Angle(to_copy.angle.p, to_copy.angle.y, to_copy.angle.r)
	end
	if (to_copy.color) then
		new_preset.color = Color(to_copy.color.r,to_copy.color.g,to_copy.color.b,to_copy.color.a)
	end
	if (type(to_copy.size) == "table") then
		new_preset.size = table.Copy(to_copy.size)
	elseif (type(to_copy.size) == "Vector") then
		new_preset.size = Vector(to_copy.size.x, to_copy.size.y, to_copy.size.z)
	end
	if (to_copy.bodygroup) then
		new_preset.bodygroup = table.Copy(to_copy.bodygroup)
	end

	wep.v_models[name] = {}

	local icon = "icon16/exclamation.png"

	if (new_preset.type == "Model") then
		wep.v_panelCache[name] = CreateModelPanel( name, new_preset )
		icon = icon_model
	elseif (new_preset.type == "Sprite") then
		wep.v_panelCache[name] = CreateSpritePanel( name, new_preset )
		icon = icon_sprite
	elseif (new_preset.type == "Quad") then
		wep.v_panelCache[name] = CreateQuadPanel( name, new_preset )
		icon = icon_quad
	end

	wep.v_panelCache[name]:SetVisible(false)

	local node = mtree:AddNode( name, icon )
	node.Type = new_preset.type
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "v" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "v" )
		end
	end

	local parent = IsValid(line._ParentNode) and line._ParentNode or line:GetParentNode()
	if IsValid( parent ) and !parent:IsRootNode() then
		parent:InsertNode( node )
	end
end

-- import worldmodels
importbtn.DoClick = function()
	local temp_v_nodes = {}

	local num = 0
	for k, v in pairs( wep.w_models ) do

		if not v.type then continue end

		local name = k
		local i = 1
		while(wep.v_models[name] != nil) do
			name = k..""..i
			i = i + 1

			-- changing names might mess up the relative transitions of some stuff
			-- but whatever.
		end

		local new_preset = table.Copy(v)
		new_preset.bone = "ValveBiped.Bip01_R_Hand" -- switch to hand bone by default

		new_preset.pos = Vector(v.pos.x, v.pos.y, v.pos.z)
		if (v.angle) then
			new_preset.angle = Angle(v.angle.p, v.angle.y, v.angle.r)
		end

		if (v.color) then
			new_preset.color = Color(v.color.r,v.color.g,v.color.b,v.color.a)
		end
		if (type(v.size) == "table") then
			new_preset.size = table.Copy(v.size)
		elseif (type(v.size) == "Vector") then
			new_preset.size = Vector(v.size.x, v.size.y, v.size.z)
		end
		if (v.bodygroup) then
			new_preset.bodygroup = table.Copy(v.bodygroup)
		end

		wep.v_models[name] = {}

		local icon = "icon16/exclamation.png"

		if (v.type == "Model") then
			wep.v_panelCache[name] = CreateModelPanel( name, new_preset )
			icon = icon_model
		elseif (v.type == "Sprite") then
			wep.v_panelCache[name] = CreateSpritePanel( name, new_preset )
			icon = icon_sprite
		elseif (v.type == "Quad") then
			wep.v_panelCache[name] = CreateQuadPanel( name, new_preset )
			icon = icon_quad
		end
		wep.v_panelCache[name]:SetVisible(false)

		local node = mtree:AddNode( name, icon )
		node.Type = v.type
		node.InsertNode = FixInsertNode
		node._ParentNode = node:GetParentNode()

		local old_DroppedOn = node.DroppedOn
		node.DroppedOn = function( self, pnl )
			old_DroppedOn( self, pnl )
			SetRelativeForNode( pnl, self, "v" )
		end

		node.OnModified = function( self )
			for k, v in pairs( self:GetChildNodes() ) do
				SetRelativeForNode( v, self, "v" )
			end
		end

		temp_v_nodes[k] = node

		num = num + 1
	end

	for k, v in SortedPairs(wep.v_models) do
		if v.rel and v.rel ~= "" and temp_v_nodes[v.rel] and temp_v_nodes[k] and wep.v_models[v.rel] then
			temp_v_nodes[v.rel]:InsertNode( temp_v_nodes[k] )
		end
	end
end

--[[--------------------------------------------------------------

					World Models

------------------------------------------------------------/]]
local lastVisible = ""

local mlabel = vgui.Create( "DPanel", pwmodels )
	mlabel:SetTall( 24 )
	mlabel.Paint = function() end
mlabel:Dock(TOP)

local mlock = vgui.Create( "DButton", mlabel )
	mlock:SetSize( 24, 24 )
	mlock:SetIsToggle( true )
	mlock:SetText("")
	mlock:SetIcon( wep.lockRelativePositions and "icon16/lock.png" or "icon16/lock_open.png" )
	mlock:SetToggle( wep.lockRelativePositions )
	mlock:SetTooltip( "Elements will retain their position when their bone or relative are changed" )
	mlock.Think = function( self )
		self:SetToggle( wep.lockRelativePositions )
		self:SetIcon( wep.lockRelativePositions and "icon16/lock.png" or "icon16/lock_open.png" )
	end
	mlock.OnToggled = function( self, toggleState )
		wep.lockRelativePositions = toggleState
	end

mlock:Dock( RIGHT )

local mlabeltext = vgui.Create( "DLabel", mlabel )
	mlabeltext:SetText( "New worldmodel element:" )
mlabeltext:Dock(FILL)

local function CreateWNote( text )
	local templabel = vgui.Create( "DLabel" )
		templabel:SetText( text )
		templabel:SizeToContents()

	local x, y = mlabel:GetPos()
	local notif = vgui.Create( "DNotify" , pwmodels )
		notif:SetPos( x + 160, y )
		notif:SetSize( templabel:GetWide(), 20 )
		notif:SetLife( 5 )
		notif:AddItem(templabel)
end

local pnewelement = SimplePanel( pwmodels )
pnewelement:SetTall(20)

	local mnwtext = vgui.Create("DTextEntry", pnewelement )
		mnwtext:SetTall( 20 )
		mnwtext:SetMultiline(false)
		mnwtext:SetText( "element_name" )
	mnwtext:Dock(FILL)

	local mnwbtn = vgui.Create( "DButton", pnewelement )
		mnwbtn:SetSize( 50, 20 )
		mnwbtn:SetText( "Add" )
	mnwbtn:DockMargin(5,0,0,0)
	mnwbtn:Dock(RIGHT)

	local tpbox = vgui.Create( "DComboBox", pnewelement )
		tpbox:SetSize( 100, 20 )
		tpbox:SetText( "Model" )
		tpbox:AddChoice( "Model" )
		tpbox:AddChoice( "Sprite" )
		tpbox:AddChoice( "Quad" )
		local wboxselected = "Model"
		tpbox.OnSelect = function( p, index, value )
			wboxselected = value
		end
	tpbox:DockMargin(5,0,0,0)
	tpbox:Dock(RIGHT)

pnewelement:DockMargin(0,5,0,5)
pnewelement:Dock(TOP)

local mwtree = vgui.Create( "DTree", pwmodels)
	mwtree:SetTall( 160 )
	wep.w_modelListing = mwtree
	mwtree:Root():SetDraggableName( "Worldmodel" )

	mwtree:Root().OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "w" )
		end
	end

	mwtree.OnNodeSelected = function( panel )
		local name = mwtree:GetSelectedItem():GetText()

		if (wep.w_panelCache[lastVisible]) then
			wep.w_panelCache[lastVisible]:SetVisible(false)
		end
		wep.w_panelCache[name]:SetVisible(true)

		lastVisible = name
		wep.selectedElement = lastVisible
	end

mwtree:Dock(TOP)

local pwbuttons = SimplePanel( pwmodels )

	local rmbtn = vgui.Create( "DButton", pwbuttons )
		rmbtn:SetSize( 140, 25 )
		rmbtn:SetText( "Remove selected" )
	rmbtn:Dock(LEFT)

	local copybtn = vgui.Create( "DButton", pwbuttons )
		copybtn:SetSize( 140, 25 )
		copybtn:SetText( "Copy selected" )
	copybtn:Dock(RIGHT)

	local importbtn = vgui.Create( "DButton", pwbuttons )
		importbtn:SetTall( 25 )
		importbtn:SetText( "Import viewmodels" )
	importbtn:Dock(FILL)

pwbuttons:DockMargin(0,5,0,5)
pwbuttons:Dock(TOP)

--[[** Model panel for adjusting models ***
Name:
Model:
Translation x / y / z
Rotation pitch / yaw / role
Model size x / y / z
Material
Color modulation
]]
local function CreateWorldModelPanel( name, preset_data )
	local data = wep.w_models[name]
	if not preset_data then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Model"
	data.model = preset_data.model or ""
	data.bone = preset_data.bone or "ValveBiped.Bip01_R_Hand"
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.angle = preset_data.angle or Angle(0,0,0)
	data.size = preset_data.size or Vector(0.5,0.5,0.5)
	data.color = preset_data.color and Color( preset_data.color.r, preset_data.color.g, preset_data.color.b, preset_data.color.a ) or Color(255,255,255,255)
	data.surpresslightning = preset_data.surpresslightning or false
	data.material = preset_data.material or ""
	data.bodygroup = preset_data.bodygroup or {}
	data.skin = preset_data.skin or 0

	wep.wRenderOrder = nil

	local panellist = vgui.Create("DPanelList", pwmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name, SimplePanel(panellist), true ))
	panellist:AddItem(CreateModelModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateAngleModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 3 ))
	panellist:AddItem(CreateColorModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSLightningModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateMaterialModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBodygroupSkinModifier( data, SimplePanel(panellist) ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist
end

--[[** Sprite panel for adjusting sprites ***
Name:
Sprite:
Translation x / y / z
Sprite x / y size
Color
]]
local function CreateWorldSpritePanel( name, preset_data )
	local data = wep.w_models[name]
	if not preset_data then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Sprite"
	data.sprite = preset_data.sprite or ""
	data.bone = preset_data.bone or "ValveBiped.Bip01_R_Hand"
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.size = preset_data.size or { x = 1, y = 1 }
	data.color = preset_data.color and Color( preset_data.color.r, preset_data.color.g, preset_data.color.b, preset_data.color.a ) or Color(255,255,255,255)
	data.nocull = preset_data.nocull or true
	data.additive = preset_data.additive or true
	data.vertexalpha = preset_data.vertexalpha or true
	data.vertexcolor = preset_data.vertexcolor or true
	data.ignorez = preset_data.ignorez or false

	wep.wRenderOrder = nil

	local panellist = vgui.Create("DPanelList", pwmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name, SimplePanel(panellist), true ))
	panellist:AddItem(CreateSpriteModifier( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 2 ))
	panellist:AddItem(CreateColorModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateParamModifiers( data, SimplePanel(panellist) ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist
end

--[[** Model panel for adjusting models ***
Name:
Model:
Bone name:
Translation x / y / z
Rotation pitch / yaw / role
Size
]]
local function CreateWorldQuadPanel( name, preset_data )
	local data = wep.w_models[name]
	if not preset_data then preset_data = {} end

	-- default data
	data.type = preset_data.type or "Quad"
	data.model = preset_data.model or ""
	data.bone = preset_data.bone or "ValveBiped.Bip01_R_Hand"
	data.rel = preset_data.rel or ""
	data.pos = preset_data.pos or Vector(0,0,0)
	data.angle = preset_data.angle or Angle(0,0,0)
	data.size = preset_data.size or 0.05

	wep.vRenderOrder = nil -- force viewmodel render order to recache

	local panellist = vgui.Create("DPanelList", pwmodels )
	panellist:SetPaintBackground( true )
		panellist.Paint = function() surface.SetDrawColor( 90, 90, 90, 255 ) surface.DrawRect( 0, 0, panellist:GetWide(), panellist:GetTall() ) end
		panellist:EnableVerticalScrollbar( true )
		panellist:SetSpacing(5)
		panellist:SetPadding(5)
	panellist:DockMargin(0,0,0,5)
	panellist:Dock(TOP)

	PanelBackgroundReset()

	panellist:AddItem(CreateNameLabel( name, SimplePanel(panellist), true ))
	panellist:AddItem(CreateBoneModifier( data, SimplePanel(panellist), LocalPlayer(), name ))
	panellist:AddItem(CreatePositionModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateAngleModifiers( data, SimplePanel(panellist) ))
	panellist:AddItem(CreateSizeModifiers( data, SimplePanel(panellist), 1 ))

	panellist:InvalidateLayout( true )
	panellist:SizeToChildren( false, true )

	return panellist
end

-- adding button DoClick
mnwbtn.DoClick = function()
	local new = string.Trim( mnwtext:GetValue() )
	if not new then return end

	if new == "" then CreateWNote("Empty name field!") return end
	if wep.w_models[new] ~= nil then CreateWNote("Name already exists!") return end
	wep.w_models[new] = {}

	local icon = "icon16/exclamation.png"

	if not wep.w_panelCache[new] then
		if (wboxselected == "Model") then
			wep.w_panelCache[new] = CreateWorldModelPanel( new )
			icon = icon_model
		elseif (wboxselected == "Sprite") then
			wep.w_panelCache[new] = CreateWorldSpritePanel( new )
			icon = icon_sprite
		elseif (wboxselected == "Quad") then
			wep.w_panelCache[new] = CreateWorldQuadPanel( new )
			icon = icon_quad
		else
			Error("Invalid type selected")
		end
	end

	wep.w_panelCache[new]:SetVisible(false)

	local node = mwtree:AddNode( new, icon )
	node.Type = boxselected
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "w" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "w" )
		end
	end
end

local temp_w_nodes = {}
for k, v in SortedPairs( wep.save_data.w_models ) do
	wep.w_models[k] = {}

	-- backwards compatability
	if not v.bone or v.bone == "" then
		v.bone = "ValveBiped.Bip01_R_Hand"
	end

	local icon = "icon16/exclamation.png"

	if (v.type == "Model") then
		wep.w_panelCache[k] = CreateWorldModelPanel( k, v )
		icon = icon_model
	elseif (v.type == "Sprite") then
		wep.w_panelCache[k] = CreateWorldSpritePanel( k, v )
		icon = icon_sprite
	elseif (v.type == "Quad") then
		wep.w_panelCache[k] = CreateWorldQuadPanel( k, v )
		icon = icon_quad
	end

	if not IsValid(wep.w_panelCache[k]) then continue end

	wep.w_panelCache[k]:SetVisible(false)

	local node = mwtree:AddNode( k, icon )
	node.Type = v.type
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "w" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "w" )
		end
	end

	temp_w_nodes[k] = node
end

for k, v in SortedPairs( wep.w_models ) do
	if v.rel and v.rel ~= "" and temp_w_nodes[v.rel] and temp_w_nodes[k] and wep.w_models[v.rel] then
		temp_w_nodes[v.rel]:InsertNode( temp_w_nodes[k] )
	end
end

-- import viewmodels
importbtn.DoClick = function()
	local num = 0
	for k, v in SortedPairs(wep.v_models) do

		if not v.type then continue end

		local name = k
		local i = 1
		while wep.w_models[name] ~= nil do
			name = k..""..i
			i = i + 1

			-- changing names might mess up the relative transitions of some stuff
			-- but whatever.
		end

		local new_preset = table.Copy(v)
		new_preset.bone = "ValveBiped.Bip01_R_Hand" -- switch to hand bone by default

		new_preset.pos = Vector(v.pos.x, v.pos.y, v.pos.z)
		if v.angle then
			new_preset.angle = Angle(v.angle.p, v.angle.y, v.angle.r)
		end

		if v.color then
			new_preset.color = Color(v.color.r,v.color.g,v.color.b,v.color.a)
		end
		if type(v.size) == "table" then
			new_preset.size = table.Copy(v.size)
		elseif type(v.size) == "Vector" then
			new_preset.size = Vector(v.size.x, v.size.y, v.size.z)
		end

		if v.bodygroup then
			new_preset.bodygroup = table.Copy(v.bodygroup)
		end

		wep.w_models[name] = {}

		local icon = "icon16/exclamation.png"

		if v.type == "Model" then
			wep.w_panelCache[name] = CreateWorldModelPanel( name, new_preset )
			icon = icon_model
		elseif v.type == "Sprite" then
			wep.w_panelCache[name] = CreateWorldSpritePanel( name, new_preset )
			icon = icon_sprite
		elseif v.type == "Quad" then
			wep.w_panelCache[name] = CreateWorldQuadPanel( name, new_preset )
			icon = icon_quad
		end
		wep.w_panelCache[name]:SetVisible(false)

		local node = mwtree:AddNode( name, icon )
		node.Type = v.type
		node.InsertNode = FixInsertNode
		node._ParentNode = node:GetParentNode()

		local old_DroppedOn = node.DroppedOn
		node.DroppedOn = function( self, pnl )
			old_DroppedOn( self, pnl )
			SetRelativeForNode( pnl, self, "w" )
		end

		node.OnModified = function( self )
			for k, v in pairs( self:GetChildNodes() ) do
				SetRelativeForNode( v, self, "w" )
			end
		end

		temp_w_nodes[k] = node

		num = num + 1
	end

	for k, v in SortedPairs( wep.w_models ) do
		if v.rel and v.rel ~= "" and temp_w_nodes[v.rel] and temp_w_nodes[k] and wep.w_models[v.rel] then
			temp_w_nodes[v.rel]:InsertNode( temp_w_nodes[k] )
		end
	end
end

-- remove a line
rmbtn.DoClick = function()
	local line = mwtree:GetSelectedItem()
	if not IsValid(line) then return end

	local name = line:GetText()
	for k,v in pairs(line:GetChildNodes()) do
		mwtree:Root():InsertNode(v)
		SetRelativeForNode(v, mwtree:Root(), "w")
	end

	wep.w_models[name] = nil
	-- clear from panel cache
	if wep.w_panelCache[name] then
		wep.w_panelCache[name]:Remove()
		wep.w_panelCache[name] = nil
	end

	line:Remove()
end

-- duplicate line
copybtn.DoClick = function()
	local line = mwtree:GetSelectedItem()
	if not IsValid(line) then return end

	local name = line:GetText()
	local to_copy = wep.w_models[name]
	local new_preset = table.Copy(to_copy)

	-- quickly generate a new unique name
	while wep.w_models[name] do
		name = name.."+"
	end

	-- have to fix every sub-table as well because table.Copy copies references
	new_preset.pos = Vector(to_copy.pos.x, to_copy.pos.y, to_copy.pos.z)
	if (to_copy.angle) then
		new_preset.angle = Angle(to_copy.angle.p, to_copy.angle.y, to_copy.angle.r)
	end
	if (to_copy.color) then
		new_preset.color = Color(to_copy.color.r,to_copy.color.g,to_copy.color.b,to_copy.color.a)
	end
	if (type(to_copy.size) == "table") then
		new_preset.size = table.Copy(to_copy.size)
	elseif (type(to_copy.size) == "Vector") then
		new_preset.size = Vector(to_copy.size.x, to_copy.size.y, to_copy.size.z)
	end
	if (to_copy.bodygroup) then
		new_preset.bodygroup = table.Copy(to_copy.bodygroup)
	end

	wep.w_models[name] = {}

	local icon = "icon16/exclamation.png"

	if (new_preset.type == "Model") then
		wep.w_panelCache[name] = CreateWorldModelPanel( name, new_preset )
		icon = icon_model
	elseif (new_preset.type == "Sprite") then
		wep.w_panelCache[name] = CreateWorldSpritePanel( name, new_preset )
		icon = icon_sprite
	elseif (new_preset.type == "Quad") then
		wep.w_panelCache[name] = CreateWorldQuadPanel( name, new_preset )
		icon = icon_quad
	end

	wep.w_panelCache[name]:SetVisible(false)

	local node = mwtree:AddNode( name, icon )
	node.Type = new_preset.type
	node.InsertNode = FixInsertNode
	node._ParentNode = node:GetParentNode()

	local old_DroppedOn = node.DroppedOn
	node.DroppedOn = function( self, pnl )
		old_DroppedOn( self, pnl )
		SetRelativeForNode( pnl, self, "w" )
	end

	node.OnModified = function( self )
		for k, v in pairs( self:GetChildNodes() ) do
			SetRelativeForNode( v, self, "w" )
		end
	end

	local parent = IsValid(line._ParentNode) and line._ParentNode or line:GetParentNode()

	if IsValid(parent) and not parent:IsRootNode() then
		parent:InsertNode(node)
	end
end
