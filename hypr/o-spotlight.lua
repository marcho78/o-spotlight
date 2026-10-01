-- O-Spotlight (marcho78.o-spotlight): the Hyprland half.
--
-- The service runs this inside Hyprland with `hyprctl eval` when the shell
-- starts, after every Hyprland config reload, and when the settings change:
--
--   return dofile("<plugin>/hypr/o-spotlight.lua")({ binds = { ... } })
--
-- It registers the keyboard shortcut, which sends a message to the service
-- over Hyprland's event socket (hl.dsp.event), a layer rule for O-Spotlight's
-- own surface and a window rule that floats its settings window. Nothing here
-- runs programs or reads or writes files. Your Hyprland config is never
-- edited: a config reload drops all of this, and the service registers again.
--
-- Anything that didn't register is raised as an error: `hyprctl eval` shows
-- only "ok" for a returned value, but prints an error and fails, so the
-- settings window can say what went wrong.

local PREFIX = "marcho78.o-spotlight|"
local EVENTS = { toggle = true }
local STATE = "__marcho78_o_spotlight"

return function(options)
  options = type(options) == "table" and options or {}

  -- What earlier runs registered in this Lua state (a config reload starts
  -- a fresh one): the shortcut is replaced every time; the two rules are made
  -- once and switched on or off after that, so they never pile up.
  local state = rawget(_G, STATE)
  if type(state) ~= "table" then
    state = { binds = {} }
    rawset(_G, STATE, state)
  end
  for _, bind in ipairs(state.binds or {}) do pcall(function() bind:remove() end) end
  state.binds = {}

  local problems = {}
  local function problem(text)
    problems[#problems + 1] = tostring(text):gsub("[\r\n|;]", " ")
  end

  if options.remove == true then
    for _, rule in ipairs(state.rules or {}) do pcall(function() rule:set_enabled(false) end) end
    return "ok"
  end

  if state.rules then
    for _, rule in ipairs(state.rules) do pcall(function() rule:set_enabled(true) end) end
  else
    state.rules = {}
    -- O-Spotlight animates its own surface, so skip Hyprland's layer fade for it.
    local ok, rule = pcall(hl.layer_rule, { match = { namespace = "^marcho78-o-spotlight$" }, no_anim = true })
    if ok and rule then state.rules[#state.rules + 1] = rule else problem("layer rule: " .. tostring(rule)) end

    -- The settings window floats in the middle of the screen, like a macOS
    -- settings window, instead of tiling.
    local placed, window_rule = pcall(hl.window_rule, {
      match = { class = "^org\\.quickshell$", title = "^O-Spotlight Settings$" },
      float = true,
      center = true,
      size = { 760, 600 },
    })
    if placed and window_rule then state.rules[#state.rules + 1] = window_rule else problem("window rule: " .. tostring(window_rule)) end
  end

  for _, bind in ipairs(type(options.binds) == "table" and options.binds or {}) do
    local keys = type(bind) == "table" and bind.keys or nil
    local event = type(bind) == "table" and bind.event or nil
    local description = type(bind) == "table" and bind.description or ""
    if type(keys) ~= "string" or #keys > 64 or not keys:match("^[%w_ %+]+$") then
      problem("skipped a shortcut with invalid keys")
    elseif not EVENTS[event] then
      problem("skipped " .. keys .. ": unknown action")
    else
      if type(description) ~= "string" or #description > 80 or not description:match("^[%w%p ]*$") then
        description = "O-Spotlight"
      end
      local done, handle = pcall(hl.bind, keys, hl.dsp.event(PREFIX .. event), { description = description })
      if done and handle then
        state.binds[#state.binds + 1] = handle
      else
        -- Hyprland turns down a key it doesn't know without an error.
        problem(keys .. ": " .. (done and "Hyprland didn't take it (is the key name right?)" or tostring(handle)))
      end
    end
  end

  if #problems == 0 then return "ok" end
  error(table.concat(problems, "; "), 0)
end
