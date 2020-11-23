--[[*************************
	Global utility code
*************************]]

-- Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
-- Does not copy entities of course, only copies their reference.
-- WARNING: do not use on tables that contain themselves somewhere down the line or you'll get an infinite loop
function table.FullCopy( tab )

	if (!tab) then return nil end

	local res = {}
	for k, v in pairs( tab ) do
		if (type(v) == "table") then
			res[k] = table.FullCopy(v) -- recursion ho!
		elseif (type(v) == "Vector") then
			res[k] = Vector(v.x, v.y, v.z)
		elseif (type(v) == "Angle") then
			res[k] = Angle(v.p, v.y, v.r)
		else
			res[k] = v
		end
	end

	return res

end