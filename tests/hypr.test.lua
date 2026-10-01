-- Runs hypr/o-spotlight.lua against a fake Hyprland API.
-- Usage (from the plugin directory): lua tests/hypr.test.lua
package.path = "./tests/?.lua;" .. package.path
local fake = require("fake_hl")
local register = dofile("hypr/o-spotlight.lua")

local passed = 0
local function check(condition, message)
  if not condition then error("FAILED: " .. message, 2) end
  passed = passed + 1
end

local options = {
  binds = {
    { keys = "ALT + SPACE", event = "toggle", description = "Search with O-Spotlight (O-Spotlight)" },
  },
}

check(register(options) == "ok", "registers cleanly")
check(#fake.active_binds() == 1, "one shortcut")
check(fake.enabled_rules() == 2, "a layer rule and a window rule")
check(fake.rules[1].spec.no_anim == true, "layer rule turns off Hyprland's animation")
check(fake.rules[1].spec.match.namespace == "^marcho78-o-spotlight$", "for O-Spotlight's surface only")
check(fake.rules[2].window and fake.rules[2].spec.float == true, "settings window floats")
check(fake.rules[2].spec.match.title == "^O-Spotlight Settings$", "matched by its title")

-- Registering again replaces the shortcut and reuses the rules, so nothing piles up.
check(register(options) == "ok", "registers again")
check(#fake.active_binds() == 1, "still one shortcut")
check(#fake.rules == 2, "the same two rules, not new ones")
check(fake.enabled_rules() == 2, "both still on")

-- The shortcut sends its event.
fake.events = {}
hl.dispatch(fake.active_binds()[1].dispatcher)
check(fake.events[1] == "marcho78.o-spotlight|toggle", "ALT + SPACE toggles O-Spotlight")
check(fake.active_binds()[1].options.description == "Search with O-Spotlight (O-Spotlight)", "described in hyprctl binds")

-- Bad input is skipped, never registered, and reported as an error (the only
-- thing `hyprctl eval` passes on besides "ok").
local ok, err = pcall(register, { binds = {
  { keys = "ALT + SPACE; exec rm", event = "toggle" },
  { keys = "ALT + X", event = "exec" },
  { keys = "ALT + Y", event = "toggle", description = "bad\ndescription" },
} })
check(not ok, "problems are raised")
check(tostring(err):find("invalid keys", 1, true) and tostring(err):find("unknown action", 1, true), "and named: " .. tostring(err))
check(#fake.active_binds() == 1, "only the valid bind")
check(fake.active_binds()[1].options.description == "O-Spotlight", "a bad description is replaced")

-- A bind Hyprland refuses is reported too.
local realBind = hl.bind
hl.bind = function() error("Unknown keysym SPCE") end
local refused, message = pcall(register, { binds = { { keys = "ALT + SPCE", event = "toggle" } } })
hl.bind = realBind
check(not refused and tostring(message):find("Unknown keysym", 1, true), "refused binds are named: " .. tostring(message))

-- A key Hyprland doesn't know is turned down without an error; still reported.
hl.bind = function() return nil end
local unknown, why = pcall(register, { binds = { { keys = "ALT + SPCE", event = "toggle" } } })
hl.bind = realBind
check(not unknown and tostring(why):find("didn't take it", 1, true), "unknown keys are named: " .. tostring(why))

-- Removing takes everything back out; registering again turns the rules back on.
check(register({ remove = true }) == "ok", "removes")
check(#fake.active_binds() == 0, "no shortcuts left")
check(fake.enabled_rules() == 0, "no rules left on")
check(register(options) == "ok", "registers after removing")
check(#fake.rules == 2 and fake.enabled_rules() == 2, "the rules come back on")

print(("hypr: %d checks passed"):format(passed))
