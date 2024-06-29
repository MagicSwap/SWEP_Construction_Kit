
local badsymbols = {"/", "\\", "?", ":", "*", "\"", "|", "<", ">"}
local function sanitize_filename(text)
	for _, symb in ipairs(badsymbols) do
		text = string.Replace(text, symb, "_")
	end

	return text
end

function GetDesiredFilename(satext)
	if not satext then return end

	local txt = satext:GetValue()

	txt = string.Trim(txt)

	txt = sanitize_filename(txt)
	return txt
end

function SaveAsSCKFile(overridetext, wep, satext, force)
	wep = wep or GetSCKSWEP(LocalPlayer(), true)
	if not IsValid(wep) then return end

	local text = overridetext or GetDesiredFilename(satext) or ""
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
	save_data.UseHands = wep.UseHands
	save_data.ViewModel = wep.ViewModel
	save_data.CurWorldModel = wep.CurWorldModel
	save_data.ViewModelFOV = wep.ViewModelFOV
	save_data.HoldType = wep.HoldType
	save_data.IronSightsEnabled = wep:GetIronSights()
	save_data.IronSightsPos, save_data.IronSightsAng = wep:GetIronSightCoordination()
	save_data.ShowViewModel = wep.ShowViewModel
	save_data.ShowWorldModel = wep.ShowWorldModel

	local succ, val = pcall(glon.encode, save_data)

	local filename = "swep_construction_kit/"..text..".txt"

	if not force and file.Exists(filename, "DATA") then --we need to rename
		for i = 1, 9999 do
			local attempt = "swep_construction_kit/"..text..i..".txt"

			if not file.Exists(attempt, "DATA") then
				filename = attempt
				text = text..i
				break
			end
		end
	end


	if not succ then LocalPlayer():ChatPrint("Failed to encode settings!") return end

	file.Write(filename, val)
	LocalPlayer():ChatPrint("Saved file \""..text.."\"!")
end