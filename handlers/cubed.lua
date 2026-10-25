-- Adds support for patting players using Solina's PatCubed

return {
	id = "PatCubed",
	---@param target_uuid string
	---@param target_vars table
	---@param x integer
	---@param y integer
	---@param z integer
	---@param mode FOXPat.Mode
	func = function(target_uuid, target_vars, x, y, z, mode)
		local api
		avatar:store("PatCubed", {
			acceptor = function(_api)
				api = _api
			end,
		})

		target_vars.PatCubed.prompter(avatar:getUUID())

		local accepted = api[mode](15, x, y, z)
		avatar:store("PatCubed")
		assert(accepted)
	end,
}
