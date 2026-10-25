-- Adds support for patting players using Auria's catpat

local mode_enum = { player = 1, skull = 2 }

return {
	id = "catpat",
	---@param target_uuid string
	---@param target_vars table
	---@param x integer
	---@param y integer
	---@param z integer
	---@param mode FOXPat.Mode
	func = function(target_uuid, target_vars, x, y, z, mode)
		avatar:store("catpat", {
			confirm = function()
				return target_uuid
			end,
		})

		local accepted = target_vars.catpat.pat(avatar:getUUID(), mode_enum[mode], x, y, z)
		avatar:store("catpat")
		assert(accepted)
	end,
}
