--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Patpat v2.0-dev

Github: https://github.com/Bitslayn/FOXPat
]]

--==============================================================================================================================
--#REGION ˚♡ Config ♡˚
--==============================================================================================================================

---@class FOXPat
local lib = {}

---@class FOXPat.Config
lib.config = {
	---List of names or uuids that are allowed to pat you
	---@type table<string, boolean>
	whitelist = {
		Steve = true,
		["8667ba71-b85a-4004-af54-457a9734eed7"] = true,
	},
	---Whether the whitelists table acts as a blacklist
	is_blacklist = false,

	---Your patting reach in blocks
	pat_distance = 4.5,
	---Whether you need to be crouching to pat
	crouch_pat = true,
	---Whether you need an empty hand to pat
	empty_hand = true,

	---How often pats should be sent in ticks
	pat_cooldown = 3,
	---Amount of ticks to wait before expiring a pat
	expire_time = 15,
}

---@class FOXPat.Events
lib.events = {}

---@class FOXPat.Events.Entity
---@field on_pat fun()[] This event gets called *once* when anyone starts patting.
---@field on_unpat fun()[] This event gets called *once* when your last patter stops patting.
---@field while_pat fun()[] This event gets called every tick while being patted.
---@field each_pat fun(patter: Player)[] This event gets called for every individual pat received.
lib.events.entity = {
	on_pat = {},
	on_unpat = {},
	while_pat = {},
	each_pat = {},
}

---@class FOXPat.Events.Skull
---@field on_pat fun()[] This event gets called *once* when anyone starts patting.
---@field on_unpat fun()[] This event gets called *once* when your last patter stops patting.
---@field while_pat fun()[] This event gets called every tick while being patted.
---@field each_pat fun(patter: Player, pos: Vector3)[] This event gets called for every individual pat received.
lib.events.skull = {
	on_pat = {},
	on_unpat = {},
	while_pat = {},
	each_pat = {},
}

---@class FOXPat.Action
lib.action = {}

---Swings your arm when you're patting something
---@param pos Vector3
function lib.action.swing_arm(pos)
	host:swingArm()
end

---Creates a single heart particle around the position within the bounding box size.
---@param pos Vector3
---@param size Vector3
function lib.action.create_particle(pos, size)
	local offset = vec(math.random(), math.random(), math.random()) - vec(0.5, 0, 0.5)
	particles:newParticle("heart", offset * size + pos)
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Incoming Library ♡˚
--==============================================================================================================================

---@type {[1]: function[], [integer]: unknown}[]
local queued_events = {}

---Registers events that get called while ticking patters.
---@param list function[]
---@param ... unknown
local function queue_events(list, ...)
	queued_events[#queued_events + 1] = { list, ... }
end

---Calls all functions in the table.
---@param list function[]
---@param ... unknown
local function call_events(list, ...)
	for i = 1, #list do
		list[i](...)
	end
end

---Registers a process which counts down all patter timers and calls the appropriate events.
---
---This function should only be ran once for the first patter. The process gets unregistered once the last patter stops patting.
---@param group FOXPat.Group
local function tick_patters(group)
	local ticks = 0
	local function clock()
		ticks = ticks + 1
	end

	local function tick()
		-- Call all queued events
		for i = 1, #queued_events do
			call_events(table.unpack(queued_events[i]))
		end
		queued_events = {}

		-- Process all ticks elapsed
		for _ = 1, ticks do
			call_events(group.events.while_pat)

			-- Tick timers
			for uuid, time in pairs(group.timers) do
				time = time - 1
				group.timers[uuid] = time

				if time == 0 then
					group.timers[uuid] = nil
					group.counter = group.counter - 1
				end
			end

			-- Stop patting
			if group.counter == 0 then
				call_events(group.events.on_unpat)

				events.world_tick:remove(clock)
				group.event:remove(tick)
				break
			end
		end
		ticks = 0
	end

	events.world_tick:register(clock)
	group.event:register(tick)
end

---Initializes patting and queues events
---@param group FOXPat.Group
---@param uuid string
---@param ... any
local function accept_patter(group, uuid, ...)
	if not group.timers[uuid] then
		if group.counter == 0 then
			queue_events(group.events.on_pat)
			tick_patters(group)
		end

		group.counter = group.counter + 1
	end

	group.timers[uuid] = lib.config.expire_time
	queue_events(group.events.each_pat, world.getEntity(uuid), ...)
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Outgoing Library ♡˚
--==============================================================================================================================

---@alias FOXPat.Mode "entity"|"player"|"skull"

---@type {id: string, func: fun(target_uuid: string, target_vars: table, x: integer, y: integer, z: integer, mode: FOXPat.Mode)}[]
local handlers = {
	{
		id = "FOXPat",
		func = function(_, target_vars, x, y, z, mode)
			local uuid = avatar:getUUID()
			if mode == "player" then
				assert(target_vars.FOXPat.entity_pat(uuid))
			elseif mode == "skull" then
				assert(target_vars.FOXPat.skull_pat(uuid, x, y, z))
			end
		end,
	},
	{
		id = "catpat",
		func = function(target_uuid, target_vars, x, y, z, mode)
			avatar:store("catpat", {
				confirm = function()
					return target_uuid
				end,
			})

			local mode_enum = { player = 1, skull = 2 }
			local accepted = target_vars.catpat.pat(avatar:getUUID(), mode_enum[mode], x, y, z)
			avatar:store("catpat")
			assert(accepted)
		end,
	},
	{
		id = "PatCubed",
		func = function(_, target_vars, x, y, z, mode)
			local api
			avatar:store("PatCubed", {
				acceptor = function(_api)
					api = _api
				end,
			})

			target_vars.PatCubed.prompter(avatar:getUUID())

			local accepted = api[mode](lib.config.expire_time, x, y, z)
			avatar:store("PatCubed")
			assert(accepted)
		end,
	},
	{
		id = "petpet",
		func = function(target_uuid, target_vars, x, y, z, mode)
			assert(not target_vars.noPats)

			local mode_keys = { player = "petpet", skull = "petpet.playerHead" }
			local noPats, noHearts = target_vars[mode_keys[mode]](avatar:getUUID(), lib.config.expire_time, x, y, z)
			assert(not noPats)

			if noHearts then return end
			local pos = vec(x, y, z)
			if mode == "player" then
				local entity = world.getEntity(target_uuid)
				lib.action.create_particle(pos, entity:getBoundingBox())
			elseif mode == "skull" then
				lib.action.create_particle(pos + vec(0.5, 0, 0.5), vec(0.5, 0.5, 0.5))
			end
		end,
	},
}

---Grabs the uuid from this skull's nbt
---
---Always returns a string to avoid unintentionally erroring when indexing avatar vars
---@param block BlockState
---@return string
local function get_skull_uuid(block)
	local nbt = block:getEntityData()
	return nbt and nbt.SkullOwner and nbt.SkullOwner.Id and client.intUUIDToString(table.unpack(nbt.SkullOwner.Id)) or ""
end

---Calls the function safely avoiding stack overflow errors
---
---Squashed based on auria's version
---@param func function
local function safe_call(func)
	local vec = vec(1, 2)
	pcall(vec.applyFunc, vec, function(i)
		---@diagnostic disable-next-line: return-type-mismatch
		return i == 1 and func()
	end)
end

---Pats the target if they allow pats from you
---@param target BlockState|Entity
local function try_patting(target)
	local target_uuid, mode
	if type(target) == "LivingEntityAPI" then ---@cast target LivingEntity
		target_uuid = target:getUUID()

		local pos = target:getPos(client.getFrameTime())
		lib.action.create_particle(pos, target:getBoundingBox())
		lib.action.swing_arm(pos)

		pings.foxpat_entity(target_uuid)
		return
	elseif type(target) == "PlayerAPI" then ---@cast target Player
		target_uuid = target:getUUID()
		mode = "player"

		pings.foxpat_entity(target_uuid)
	elseif type(target) == "BlockState" then
		target_uuid = get_skull_uuid(target)
		mode = "skull"

		pings.foxpat_skull(target:getPos():unpack())
	else
		return
	end

	local pos = target:getPos()
	local x, y, z = pos:unpack()

	local target_vars = world.avatarVars()[target_uuid]
	if not target_vars then return end

	for i = 1, #handlers do
		if target_vars[handlers[i].id] then
			safe_call(function()
				handlers[i].func(target_uuid, target_vars, x, y, z, mode)
				lib.action.swing_arm(pos)
			end)
		end
	end
end

local isHost = host:isHost()

---@param uuid string
function pings.foxpat_entity(uuid)
	if isHost then return end
	local entity = world.getEntity(uuid)
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

lib.pat = try_patting

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Avatar Vars ♡˚
--==============================================================================================================================

local session_id = client.getSystemTime()
local vars = { session_id = session_id }
avatar:store("FOXPat", vars)

---@alias FOXPat.Group {events: table<string, function[]>, event: Event.Generic, timers: table<string, integer>, counter: integer }
local entity_group = { events = lib.events.entity, event = events.render, timers = {}, counter = 0 }
local skull_group = { events = lib.events.skull, event = events.skull_render, timers = {}, counter = 0 }

---Validates the uuid and pat functions
---
---Throws if the uuid or session is invalid
---@param uuid string
---@return boolean
local function validate(uuid)
	assert(world.avatarVars()[avatar:getUUID()].FOXPat.session_id == session_id)
	return (lib.config.whitelist[uuid] or lib.config.whitelist[world.getEntity(uuid):getName()]) and not lib.config.is_blacklist
end

---Pats this avatar's entity
---@param uuid string
---@return boolean accepted
function vars.entity_pat(uuid)
	if not validate(uuid) then return false end
	accept_patter(entity_group, uuid)
	lib.action.create_particle(player:getPos(client.getFrameTime()), player:getBoundingBox())
	return true
end

---Pats one of this avatar's skulls
---@param uuid string
---@param x number
---@param y number
---@param z number
---@return boolean accepted
function vars.skull_pat(uuid, x, y, z)
	if not validate(uuid) then return false end
	local pos = vec(x, y, z):floor()
	accept_patter(skull_group, uuid, pos)
	lib.action.create_particle(pos + vec(0.5, 0, 0.5), vec(0.5, 0, 0.5))
	return true
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Keybind ♡˚
--==============================================================================================================================

local pat_cooldown = 0

---Pats the closest pattable thing in your line of sight
local function pat_targeted()
	pat_cooldown = pat_cooldown % lib.config.pat_cooldown + 1
	if pat_cooldown ~= 1 then return end

	local point_a = player:getPos():add(0, player:getEyeHeight()):add(renderer:getEyeOffset())
	local point_b = point_a + player:getLookDir() * lib.config.pat_distance

	local block, block_hit = raycast:block(point_a, point_b)
	local entity, entity_hit = raycast:entity(point_a, point_b, function(entity)
		return entity ~= player
	end)

	if entity and (point_a - block_hit):length() > (point_a - entity_hit):length() then
		block = nil
	end

	---@diagnostic disable-next-line: param-type-mismatch
	try_patting(block or entity)
end

local pat_keybind = keybinds:fromVanilla("key.use")
local crouch_keybind = keybinds:fromVanilla("key.sneak")

pat_keybind:onPress(function()
	if action_wheel:isEnabled() or host:isCursorUnlocked() then return end
	if lib.config.crouch_pat and not crouch_keybind:isPressed() then return end
	if lib.config.empty_hand and player:getHeldItem().id ~= "minecraft:air" then return end
	events.tick:register(pat_targeted)
end)

pat_keybind:onRelease(function()
	pat_cooldown = 0
	events.tick:remove(pat_targeted)
end)

--#ENDREGION

return lib
