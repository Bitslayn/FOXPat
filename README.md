# FOXPat

FOXPat is a simple modern pat protocol with a whitelist.

Configurable:

- Whitelist
- Events
- Particles
- Pat animation

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