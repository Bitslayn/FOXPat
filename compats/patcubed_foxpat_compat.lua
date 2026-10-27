-- This script allows you as a patcubed user to pat foxpat users
-- Download this script and move it to your patcubed/compat folder

return function(CONFIG)
	local isHost = host:isHost()

	---@param block BlockState
	---@return string
	local function get_skull_uuid(block)
		local nbt = block:getEntityData()
		return nbt and nbt.SkullOwner and nbt.SkullOwner.Id and client.intUUIDToString(table.unpack(nbt.SkullOwner.Id)) or ""
	end

	---@param target BlockState|Entity
	local function try_patting(target)
		local my_uuid = avatar:getUUID()
		
		local pat_success
		if type(target) == "PlayerAPI" then ---@cast target Player
			local target_uuid = target:getUUID()

			local target_vars = world.avatarVars()[target_uuid]
			if not (target_vars and target_vars.FOXPat) then return end

			local ok, res = pcall(target_vars.FOXPat.entity_pat, my_uuid)
			pat_success = ok and res
			
			pings.foxpat_entity(client.uuidToIntArray(target_uuid))
		elseif type(target) == "BlockState" then
			local target_uuid = get_skull_uuid(target)
			
			local target_vars = world.avatarVars()[target_uuid]
			if not (target_vars and target_vars.FOXPat) then return end

			local ok, res = pcall(target_vars.FOXPat.skull_pat, my_uuid, target:getPos():unpack())
			pat_success = ok and res

			pings.foxpat_skull(target:getPos():unpack())
		else
			return
		end

		if pat_success then
			host:swingArm()
		end
	end

	---@param ... integer
	function pings.foxpat_entity(...)
		if isHost then return end
		local entity = world.getEntity(client.intUUIDToString(...))
		if not entity then return end
		try_patting(entity)
	end

	---@param x integer
	---@param y integer
	---@param z integer
	function pings.foxpat_skull(x, y, z)
		if isHost then return end
		try_patting(world.getBlockState(x, y, z))
	end

	table.insert(CONFIG.callbacks.compat.patOther, function(useBlock, uuid, block)
		try_patting(useBlock and block or world.getEntity(uuid))
	end)
end
