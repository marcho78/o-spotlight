// MenuIndex.js - the Omarchy menu, its bar panels and themes as search results.
//
// The Omarchy menu is defined in JSONC: Omarchy's own file plus the user's
// ~/.config/omarchy/extensions/omarchy-menu.jsonc on top. Every submenu and
// action in it becomes a result ("Theme — Style", "Docker — Install"). Picking
// one asks the Omarchy menu to open that route (`omarchy menu summon <id>`):
// a submenu opens right there, an action runs exactly as it would from the
// menu. O-Spotlight never runs a menu action itself.
//
// The JSONC reading and the `when:`/`checked:` guard batch follow Omarchy's
// own menu (shell/plugins/menu/MenuModel.js, MIT) so both agree on what
// shows.
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

// Maps keyed by menu ids, theme names and the like have no prototype, so an id
// such as "__proto__" or "constructor" in a menu file is just an id.
function table() {
  return Object.create(null)
}

function own(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key) ? object[key] : undefined
}

// ---- reading the menu --------------------------------------------------------------

// Comment lines out, and the commas JSON doesn't allow before } or ]. Line
// by line: a pattern spanning lines can take time that grows with the square
// of a run of blank lines.
function stripJsonc(raw) {
  var lines = String(raw || "").split("\n")
  var kept = []
  for (var i = 0; i < lines.length; i++) if (!/^\s*\/\//.test(lines[i])) kept.push(lines[i])
  return kept.join("\n").replace(/,(\s*[}\]])/g, "$1")
}

function normalizeAliases(value) {
  if (Array.isArray(value)) return value.filter(function(v) { return typeof v === "string" && v })
  if (typeof value === "string" && value) return [value]
  return []
}

function text(value, limit) {
  return typeof value === "string" ? value.slice(0, limit || 200) : ""
}

// Rows read from one menu file, at most (Omarchy's has about 300).
var MAX_ITEMS = 5000

// A `when:` or `checked:` longer than this isn't run at all: cut short, it
// could be a different command. Its row doesn't show, or shows unchecked.
// (Omarchy's longest is about 110 characters.)
var MAX_GUARD = 8192

function guardText(value) {
  return typeof value === "string" && value.length <= MAX_GUARD ? value : ""
}

function tooLong(value) {
  return typeof value === "string" && value.length > MAX_GUARD
}

function normalizeItem(id, raw) {
  var value = raw || {}
  var parent = value.parent
  if (typeof parent !== "string")
    parent = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(".") : "root"
  if (id === "root") parent = ""
  return {
    id: id,
    parent: parent,
    kind: value.action ? "action" : (value.target ? "link" : "menu"),
    icon: text(value.icon, 16),
    iconFont: text(value.iconFont, 64),
    label: text(value.label, 120) || id,
    title: text(value.title, 120),
    target: text(value.target, 200),
    description: text(value.description, 300),
    provider: text(value.provider, 64),
    aliases: normalizeAliases(value.aliases).slice(0, 16),
    when: guardText(value.when),
    whenTooLong: tooLong(value.when),
    checked: guardText(value.checked)
  }
}

function parse(raw) {
  var stripped = stripJsonc(raw)
  if (!stripped.trim()) return []
  var parsed
  try {
    parsed = JSON.parse(stripped)
  } catch (e) {
    return []
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return []
  var source = parsed.items && typeof parsed.items === "object" && !Array.isArray(parsed.items) ? parsed.items : parsed
  var out = []
  for (var id in source) {
    if (out.length >= MAX_ITEMS) break
    var entry = source[id]
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue
    if (id.length > 200) continue
    out.push(normalizeItem(id, entry))
  }
  return out
}

// The user's file on top of Omarchy's. As in the Omarchy menu, a row with an
// id that's already there replaces that row (every field, named or not), so
// both show the same thing.
function merge(defaultItems, userItems) {
  var items = table()
  var order = []
  var sources = [defaultItems || [], userItems || []]
  for (var s = 0; s < sources.length; s++) {
    for (var i = 0; i < sources[s].length; i++) {
      var entry = sources[s][i]
      if (!entry || !entry.id) continue
      if (!items[entry.id]) order.push(entry.id)
      var prior = items[entry.id] || {}
      var merged = {}
      for (var k in prior) merged[k] = prior[k]
      for (var k2 in entry) merged[k2] = entry[k2]
      items[entry.id] = merged
    }
  }
  return { items: items, order: order }
}

// ---- guards -------------------------------------------------------------------------
//
// `when:` hides a row, `checked:` marks it current. Both are shell tests, run
// in one bash batch (as the Omarchy menu does) that prints `<id>:<w|c>:<0|1>`.

var GUARD_READERS = [
  "omarchy-channel-current",
  "omarchy-default-agent",
  "omarchy-default-browser",
  "omarchy-default-editor",
  "omarchy-default-terminal",
  "omarchy-dns"
]

function guardHelpers() {
  return 'declare -A __omarchy_pkgs=()\n'
    + 'mapfile -t __omarchy_pkg_names < <({ pacman -Qq; LC_ALL=C pacman -Qi'
    + " | awk '/^[A-Za-z]/ { provides = ($0 ~ /^Provides/); sub(/^[^:]*: /, \"\") }"
    + ' provides && $0 != "None" { n = split($0, p, " ");'
    + ' for (i = 1; i <= n; i++) { sub(/[<>=].*/, "", p[i]); print p[i] } }\'; } 2>/dev/null)\n'
    + 'for __omarchy_pkg in "${__omarchy_pkg_names[@]}"; do __omarchy_pkgs[$__omarchy_pkg]=1; done\n'
    + '__omarchy_pkg_has() { [[ -n ${__omarchy_pkgs[$1]-} ]] && return 0; '
    + '[[ $1 == *[\\<\\>=]* ]] && { pacman -Q "$1" &>/dev/null; return; }; return 1; }\n'
    + 'omarchy-pkg-present() { local p; for p in "$@"; do __omarchy_pkg_has "$p" || return 1; done; return 0; }\n'
    + 'omarchy-pkg-missing() { local p; for p in "$@"; do __omarchy_pkg_has "$p" || return 0; done; return 1; }\n'
    + 'omarchy-cmd-present() { local c; for c in "$@"; do command -v "$c" &>/dev/null || return 1; done; return 0; }\n'
    + 'omarchy-cmd-missing() { local c; for c in "$@"; do command -v "$c" &>/dev/null || return 0; done; return 1; }\n'
}

function guardReaderSlot(index) {
  return "${__omarchy_read_" + index + "}"
}

function substituteGuardReaders(expression) {
  for (var i = 0; i < GUARD_READERS.length; i++)
    expression = expression.split("$(" + GUARD_READERS[i] + ")").join(guardReaderSlot(i))
  return expression
}

function guardPrelude(guards) {
  var prelude = guardHelpers()
  for (var i = 0; i < GUARD_READERS.length; i++) {
    if (guards.indexOf(guardReaderSlot(i)) < 0) continue
    prelude += "__omarchy_read_" + i + "=$(" + GUARD_READERS[i] + " 2>/dev/null) || :\n"
  }
  return prelude
}

// Ids end up inside `echo`, so only plain id characters are allowed there.
function safeGuardId(id) {
  return /^[A-Za-z0-9._-]{1,200}$/.test(id)
}

function guardLine(id, tag, expression) {
  return "if { " + substituteGuardReaders(expression) + "; } >/dev/null 2>&1; then echo "
    + id + ":" + tag + ":1; else echo " + id + ":" + tag + ":0; fi\n"
}

// `include(id)`, if given, picks the rows whose checks go in this batch.
function guardScript(items, include) {
  var guards = ""
  var ids = Object.keys(items || {})
  for (var i = 0; i < ids.length; i++) {
    var entry = items[ids[i]]
    if (!entry || !safeGuardId(ids[i])) continue
    if (include && !include(ids[i])) continue
    if (entry.when) guards += guardLine(ids[i], "w", entry.when)
    if (entry.checked) guards += guardLine(ids[i], "c", entry.checked)
  }
  return guards ? guardPrelude(guards) + guards : ""
}

// The ids of parsed rows, as a set (your menu additions, to tell them apart).
function idsOf(list) {
  var out = table()
  for (var i = 0; list && i < list.length; i++) if (list[i] && list[i].id) out[list[i].id] = true
  return out
}

// Two batches' answers as one.
function combineGuards(a, b) {
  var out = { when: table(), checked: table() }
  ;[a, b].forEach(function(g) {
    if (!g) return
    Object.keys(g.when || {}).forEach(function(k) { out.when[k] = g.when[k] })
    Object.keys(g.checked || {}).forEach(function(k) { out.checked[k] = g.checked[k] })
  })
  return out
}

function parseGuards(output) {
  var when = table()
  var checked = table()
  var lines = String(output || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].trim().match(/^([A-Za-z0-9._-]+):([wc]):([01])$/)
    if (!m) continue
    if (m[2] === "w") when[m[1]] = m[3] === "1"
    else checked[m[1]] = m[3] === "1"
  }
  return { when: when, checked: checked }
}

// ---- results ------------------------------------------------------------------------

// A top-level menu's badge color, like the icons in macOS System Settings.
var TOP_COLORS = {
  learn: "#0a84ff",
  trigger: "#ff9f0a",
  style: "#bf5af2",
  setup: "#8e8e93",
  install: "#30b94d",
  remove: "#ff453a",
  update: "#32ade6",
  about: "#5e5ce6",
  system: "#636366"
}

var META_MENUS = { install: true, remove: true, update: true }

function ancestors(items, id) {
  var out = []
  var current = items[id]
  var guard = 0
  while (current && current.parent && current.parent !== "root" && guard < 32) {
    current = items[current.parent]
    if (!current) break
    out.unshift(current)
    guard++
  }
  return out
}

function hasProviderAncestor(items, id) {
  var list = ancestors(items, id)
  for (var i = 0; i < list.length; i++) if (list[i].provider) return true
  return false
}

// Visible unless its own `when:` or an ancestor's failed (or its `when:` is
// too long to run); a static submenu also needs something visible inside it.
// Worked out for the whole menu at once, each row once.
function visibility(merged, guards) {
  var items = merged.items
  var when = guards && guards.when ? guards.when : {}
  var children = table()
  for (var j = 0; j < merged.order.length; j++) {
    var child = items[merged.order[j]]
    if (!child) continue
    if (!children[child.parent]) children[child.parent] = []
    children[child.parent].push(child.id)
  }
  var known = table()
  function visible(id, depth) {
    if (known[id] !== undefined) return known[id]
    // Settled as hidden first, so a menu that contains itself ends here, as
    // does one nested deeper than any real menu.
    known[id] = false
    if (depth > 32) return false
    var entry = items[id]
    if (!entry || entry.whenTooLong || (entry.when && when[id] === false)) return false
    var list = ancestors(items, id)
    for (var i = 0; i < list.length; i++) {
      if (list[i].whenTooLong || (list[i].when && when[list[i].id] === false)) return false
    }
    var result = entry.kind !== "menu" || !!entry.provider
    var inside = children[id] || []
    for (var k = 0; !result && k < inside.length; k++) result = visible(inside[k], depth + 1)
    known[id] = result
    return result
  }
  return visible
}

// Every result the menu offers, with what search needs to find it.
function entries(merged, guards) {
  var out = []
  var items = merged.items
  var checked = guards && guards.checked ? guards.checked : {}
  var isVisible = visibility(merged, guards)
  for (var i = 0; i < merged.order.length; i++) {
    var id = merged.order[i]
    var item = items[id]
    if (!item || id === "root" || item.provider === "apps") continue
    if (hasProviderAncestor(items, id)) continue
    if (!isVisible(id, 0)) continue
    var chain = ancestors(items, id)
    var path = chain.map(function(a) { return a.title || a.label }).join(" › ")
    var top = chain.length ? chain[0].id : id
    var leaf = id.split(".").pop().replace(/[._-]+/g, " ")
    // Install, Remove and Update rows read as what they do: "Install Docker".
    var verb = own(META_MENUS, top) && chain.length > 0 ? chain[0].label : ""
    out.push({
      key: "omarchy:" + id,
      source: "omarchy",
      id: id,
      kind: item.kind,
      route: item.kind === "link" ? item.target : id,
      title: verb ? verb + " " + item.label : item.label,
      subtitle: path,
      menuTitle: item.title,
      icon: item.icon,
      iconFont: item.iconFont,
      color: own(TOP_COLORS, top) || "#5e5ce6",
      checked: !!(item.checked && checked[id]),
      submenu: item.kind !== "action",
      // Deeper rows, and the Install, Remove and Update menus (which act on
      // a thing rather than open it), give way to the setting itself:
      // "theme" → Style › Theme before Install › Style › Theme.
      penalty: chain.length * 10 + (own(META_MENUS, top) ? 30 : 0),
      fields: searchFields(item, path, leaf)
    })
  }
  return out
}

function searchFields(item, path, leaf) {
  var fields = [{ text: item.label, weight: 1 }]
  if (item.title && item.title !== item.label) fields.push({ text: item.title, weight: 0.95 })
  for (var i = 0; i < item.aliases.length; i++) fields.push({ text: item.aliases[i].replace(/[._-]+/g, " "), weight: 0.85, min: 620 })
  if (path) fields.push({ text: path.replace(/ › /g, " ") + " " + item.label, weight: 0.8, min: 620 })
  if (leaf && leaf.toLowerCase() !== item.label.toLowerCase()) fields.push({ text: leaf, weight: 0.7, min: 620 })
  if (item.description) fields.push({ text: item.description, weight: 0.5, loose: false })
  return fields
}

// ---- bar panels ------------------------------------------------------------------------
//
// The Omarchy shell's bar panels are its "System Settings": Wi-Fi, Bluetooth,
// Sound, Display... Each opens from its bar icon, so it's offered only while
// that icon is in the bar.

var PANELS = [
  { plugin: "omarchy.network", title: "Wi-Fi", color: "#0a84ff", glyph: "wifi",
    words: ["wifi", "wi-fi", "wireless", "network", "internet", "ethernet"] },
  { plugin: "omarchy.bluetooth", title: "Bluetooth", color: "#0a84ff", glyph: "bluetooth",
    words: ["bluetooth", "bt", "devices", "headphones", "pair"] },
  { plugin: "omarchy.audio", title: "Sound", color: "#ff375f", glyph: "sound",
    words: ["sound", "audio", "volume", "speakers", "output", "input", "microphone", "mixer"] },
  { plugin: "omarchy.monitor", title: "Displays", color: "#0a84ff", glyph: "display",
    words: ["display", "displays", "brightness", "screen", "monitor"] },
  { plugin: "omarchy.power", title: "Battery", color: "#30b94d", glyph: "battery",
    words: ["battery", "power", "energy", "power profile", "charge"] },
  { plugin: "omarchy.clock", title: "Calendar", color: "#ff453a", glyph: "calendar",
    words: ["calendar", "date", "clock", "time"] },
  { plugin: "omarchy.weather", title: "Weather", color: "#32ade6", glyph: "weather",
    words: ["weather", "forecast", "temperature"] },
  { plugin: "omarchy.tailscale", title: "Tailscale", color: "#636366", glyph: "vpn",
    words: ["tailscale", "vpn"] },
  { plugin: "omarchy.dropbox", title: "Dropbox", color: "#0061fe", glyph: "cloud",
    words: ["dropbox", "sync"] }
]

// Ids of the widgets in the bar, from the shell's bar configuration.
function barWidgetIds(barConfig) {
  var ids = table()
  var layout = barConfig && barConfig.layout && typeof barConfig.layout === "object" ? barConfig.layout : {}
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      var id = typeof entry === "string" ? entry : (entry && entry.id)
      if (typeof id === "string") ids[id] = true
    }
  }
  return ids
}

function panelEntries(barConfig) {
  var present = barWidgetIds(barConfig)
  var out = []
  for (var i = 0; i < PANELS.length; i++) {
    var panel = PANELS[i]
    if (!present[panel.plugin]) continue
    var fields = [{ text: panel.title, weight: 1 }]
    for (var j = 0; j < panel.words.length; j++) fields.push({ text: panel.words[j], weight: 0.9, min: 620 })
    out.push({
      key: "panel:" + panel.plugin,
      source: "panel",
      plugin: panel.plugin,
      title: panel.title,
      subtitle: "Omarchy › Top Bar",
      glyph: panel.glyph,
      color: panel.color,
      fields: fields
    })
  }
  return out
}

// ---- themes ------------------------------------------------------------------------------

// "tokyo-night" → "Tokyo Night"
function themeTitle(dirName) {
  return String(dirName || "").split(/[-_\s]+/).filter(function(w) { return w }).map(function(w) {
    return w.charAt(0).toUpperCase() + w.slice(1)
  }).join(" ")
}

// Theme folders (full paths, one per line) as results. A theme in your own
// themes folder overrides a stock one with the same name.
function themeEntries(listing, current) {
  var byName = table()
  var lines = String(listing || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var path = lines[i].trim()
    if (!/^\/[^\u0000-\u001f]{1,1000}$/.test(path)) continue
    var name = path.replace(/\/+$/, "").split("/").pop()
    if (!/^[A-Za-z0-9._ -]{1,64}$/.test(name) || name.charAt(0) === ".") continue
    byName[name] = path
  }
  var currentName = String(current || "").trim()
  return Object.keys(byName).sort().map(function(name) {
    var title = themeTitle(name)
    return {
      key: "theme:" + name,
      source: "theme",
      name: name,
      title: title,
      subtitle: name === currentName ? "Omarchy Theme · Current" : "Omarchy Theme",
      path: byName[name],
      preview: byName[name].replace(/\/+$/, "") + "/preview.png",
      checked: name === currentName,
      fields: [{ text: title, weight: 1, min: 620 }, { text: name.replace(/[-_]+/g, " "), weight: 0.9, min: 620 }]
    }
  })
}
