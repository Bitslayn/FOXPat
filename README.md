# FOXPat

FOXPat is a simple modern pat protocol with a whitelist. FOXPat lets you configure:

- Whitelist
- Events
- Actions

# Whitelist

You can give other players consent to pat you through your whitelist. Whitelists support names or uuids, and can optionally be treated as a blacklist.

```lua
local foxpat = require("foxpat")

foxpat.config.whitelist = {
	Steve = true,
	["8667ba71-b85a-4004-af54-457a9734eed7"] = true,
}
foxpat.config.use_blacklist = false
```

# Events

You can create events that fire whenever someone pats you. Events are split into two subcategories, `entity` and `skull`. The included events are:

- `on_pat` - This event gets called *once* when anyone starts patting.
- `on_unpat` - This event gets called *once* when your last patter stops patting.
- `while_pat` - This event gets called every tick while being patted.
- `each_pat` - This event gets called for every individual pat received.

Calling `table.insert` allows you to register an event function.

```lua
local foxpat = require("foxpat")

-- From foxpat.events, index the subcategory, then the event type
table.insert(foxpat.events.entity.each_pat, function(patter)
	sounds:playSound("minecraft:entity.fox.ambient", player:getPos(), 0.5)
end)
```

# Actions

Actions are functions which let you control how your player reacts to being patted or patting something.

```lua
-- Uses a BlockBench animation for swinging instead of the vanilla swing action.
function lib.action.swing_arm()
	animations.model.pat:play()
end

-- Uses cherry leaves instead of heart particle, and inflates the area size by 0.5 blocks. Also creates 3 particles per pat instead of 1.
function foxpat.action.create_particle(pos, size)
	size = size + 0.5

	for _ = 1, 3 do
		local offset = vec(math.random(), math.random(), math.random()) - vec(0.5, 0, 0.5)
		particles:newParticle("cherry_leaves", offset * size + pos)
	end
end
```

Of course, if there are any features that FOXPat doesn't support that you need, you are free to modify FOXPat in any way you'd like. FOXPat is, by design, a simple script with only the bare minimum features required.