--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Patpat v2.0-dev

TODO Reset whitelists before releasing
TODO Cleanup configs and script tbh

Github: https://github.com/Bitslayn/TODO
]]

--==============================================================================================================================
--#REGION ˚♡ Config ♡˚
--==============================================================================================================================

---@class FOXPat
local lib = {}

---@class FOXPat.Config
---@field whitelist table<string, boolean> List of names or uuids that are allowed to pat you.
---@field isBlacklist boolean Whether the whitelist table acts as a blacklist.
---@field expire_time integer Amount of ticks to wait before calling onUnpat.
---@field pat_keybind Minecraft.keyCode The key you need to press to pat players.
---@field crouch_keybind Minecraft.keyCode? The key you need to have held along with the pat keybind to start patting. Setting this key to nil will disable the bind.
---@field pat_cooldown integer
lib.config = {
	whitelist = {
		Simon255 = true,
		Bitslayn = true,
		purpledeni = true,
	},
	isBlacklist = false,

	-- TODO clean up configs

	expire_time = 15,
	crouch_pat = true,
	pat_cooldown = 3,
	pat_distance = 4.5,
}

---@class FOXPat.Events
lib.events = {}

---@class FOXPat.Events.Entity
---@field onPat fun()[] This event gets called *once* when anyone starts patting.
---@field onUnpat fun()[] This event gets called *once* when your last patter stops patting.
---@field whilePat fun()[] This event gets called every tick while being patted.
---@field eachPat fun(patter: Player)[] This event gets called for every individual pat received.
lib.events.entity = {
	onPat = {},
	onUnpat = {},
	whilePat = {},
	eachPat = {},
}

---@class FOXPat.Events.Skull
---@field onPat fun()[] This event gets called *once* when anyone starts patting.
---@field onUnpat fun()[] This event gets called *once* when your last patter stops patting.
---@field whilePat fun()[] This event gets called every tick while being patted.
---@field eachPat fun(patter: Player, pos: Vector3)[] This event gets called for every individual pat received.
lib.events.skull = {
	onPat = {},
	onUnpat = {},
	whilePat = {},
	eachPat = {},
}

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Helpers ♡˚
--==============================================================================================================================

---Creates a single heart particle around the position within the bounding box size.
---@param pos Vector3
---@param size Vector3
local function create_particle(pos, size)
	local offset = vec(math.random(), math.random(), math.random()) - vec(0.5, 0, 0.5)
	particles:newParticle("heart", offset * size + pos)
end

---Grabs the uuid from this skull's nbt
---@param block BlockState
---@return string?
local function get_skull_uuid(block)
	local nbt = block:getEntityData()
	return nbt and nbt.SkullOwner and nbt.SkullOwner.Id and client.intUUIDToString(table.unpack(nbt.SkullOwner.Id))
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
		for i = 1, #queued_events do
			call_events(table.unpack(queued_events[i]))
		end
		queued_events = {}

		for _ = 1, ticks do
			call_events(group.events.whilePat)

			for uuid, time in pairs(group.timers) do
				-- Count down timer
				time = time - 1
				if time > 0 then
					group.timers[uuid] = time
					goto continue
				end

				-- Timer expired, decrease number of patters
				group.counter = group.counter - 1
				if group.counter > 0 then
					group.timers[uuid] = nil
					goto continue
				end

				-- No more patters
				call_events(group.events.onUnpat)
				events.world_tick:remove(clock)
				group.event:remove(tick)
				do return end

				::continue::
			end
		end
		ticks = 0
	end

	events.world_tick:register(clock)
	group.event:register(tick)
end

---Call this function to initialize patting.
---
---Takes the patting group, the patter uuid, and optional callbacks passed into the eachPat event.
---@param group FOXPat.Group
---@param uuid string
---@param ... any
local function accept_patter(group, uuid, ...)
	if not group.timers[uuid] then
		if group.counter == 0 then
			queue_events(group, group.events.onPat)
			tick_patters(group)
		end

		group.counter = group.counter + 1
	end

	group.timers[uuid] = lib.config.expire_time
	queue_events(group, group.events.eachPat, world.getEntity(uuid), ...)
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
}

local list = listFiles("./handlers")
for i = 1, #list do
	handlers[i + 1] = require(list[i])
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
---@param uuid string?
---@param target BlockState|Entity?
---@param mode FOXPat.Mode?
local function try_patting(uuid, target, mode)
	if not (uuid and target and mode) then return end

	local x, y, z = target:getPos():unpack()

	if mode == "entity" then ---@cast target Entity
		create_particle(target:getPos(client.getFrameTime()), target:getBoundingBox())
		host:swingArm()
		pings.foxpat_entity(uuid)
	elseif mode == "player" then
		pings.foxpat_player(uuid)
	elseif mode == "skull" then
		pings.foxpat_skull(x, y, z)
	end

	local vars = world.avatarVars()[uuid]
	if not vars then return end

	for i = 1, #handlers do
		if vars[handlers[i].id] then
			safe_call(function()
				handlers[i].func(uuid, vars, x, y, z, mode)
				host:swingArm()
			end)
		end
	end
end

local isHost = host:isHost()

---@param uuid string
function pings.foxpat_entity(uuid)
	if isHost then return end
	local entity = world.getEntity(uuid)
	if not entity or entity:isPlayer() then return end
	create_particle(entity:getPos(client.getFrameTime()), entity:getBoundingBox())
end

---@param uuid string
function pings.foxpat_player(uuid)
	if isHost then return end
	local entity = world.getEntity(uuid)
	if not entity then return end
	try_patting(uuid, entity, "player")
end

---@param x integer
---@param y integer
---@param z integer
function pings.foxpat_skull(x, y, z)
	if isHost then return end
	local block = world.getBlockState(x, y, z)
	try_patting(get_skull_uuid(block), world.getBlockState(x, y, z), "skull")
end

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
	return (lib.config.whitelist[uuid] or lib.config.whitelist[world.getEntity(uuid):getName()]) and not lib.config.isBlacklist
end

---Pats this avatar's entity
---@param uuid string
---@return boolean accepted
function vars.entity_pat(uuid)
	if not validate(uuid) then return false end
	accept_patter(entity_group, uuid)
	create_particle(player:getPos(client.getFrameTime()), player:getBoundingBox())
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
	create_particle(pos + vec(0.5, 0, 0.5), vec(0.5, 0, 0.5))
	return true
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Keybind ♡˚
--==============================================================================================================================

local pat_cooldown = 0

---Ran while holding the pat keybind
---
---Sorts and attempts to pat what the player is looking at
local function pat_loop()
	pat_cooldown = pat_cooldown % lib.config.pat_cooldown + 1
	if pat_cooldown ~= 1 then return end
	
	local point_a = player:getPos():add(0, player:getEyeHeight()):add(renderer:getEyeOffset())
	local point_b = point_a + player:getLookDir() * lib.config.pat_distance

	local block, block_hit = raycast:block(point_a, point_b, "VISUAL")
	local entity, entity_hit = raycast:entity(point_a, point_b, function(entity)
		return entity ~= player
	end)

	if entity and (point_a - block_hit):length() > (point_a - entity_hit):length() then
		block = nil
	end

	if block then
		try_patting(get_skull_uuid(block), block, "skull")
	elseif entity then
		try_patting(entity:getUUID(), entity, entity:isPlayer() and "player" or "entity")
	end
end

local pat_keybind = keybinds:fromVanilla("key.use")
local crouch_keybind = keybinds:fromVanilla("key.sneak")

pat_keybind:onPress(function()
	if host:getScreen() or action_wheel:isEnabled() or host:isCursorUnlocked() then return end
	if lib.config.crouch_pat and not crouch_keybind:isPressed() then return end
	events.tick:register(pat_loop)
end)

pat_keybind:onRelease(function()
	events.tick:remove(pat_loop)
	pat_cooldown = 0
end)

--#ENDREGION

return lib
