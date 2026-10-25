-- Adds support for patting players using the classic petpet

---Creates a single heart particle around the position within the bounding box size.
---@param pos Vector3
---@param size Vector3
local function create_particle(pos, size)
	local offset = vec(math.random(), math.random(), math.random()) - vec(0.5, 0, 0.5)
	particles:newParticle("heart", offset * size + pos)
end

return {
	id = "petpet",
	---@param target_uuid string
	---@param target_vars table
	---@param x integer
	---@param y integer
	---@param z integer
	---@param mode FOXPat.Mode
	func = function(target_uuid, target_vars, x, y, z, mode)
		assert(not target_vars.noPats)

		local mode_keys = { player = "petpet", skull = "petpet.playerHead" }

		local noPats, noHearts = target_vars[mode_keys[mode]](avatar:getUUID(), 15, x, y, z)

		assert(not noPats)
		if noHearts then return end

		local pos = vec(x, y, z)
		if mode == "player" then
			local entity = world.getEntity(target_uuid)
			create_particle(pos, entity:getBoundingBox())
		elseif mode == "skull" then
			create_particle(pos + vec(0.5, 0, 0.5), vec(0.5, 0.5, 0.5))
		end
	end,
}
