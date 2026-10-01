// Rank.js - scored results into Spotlight's list: the Top Hit, then a
// section per kind (Applications, Omarchy, Documents...), then the web.
//
// Each result's score is how well it matched (Match.js, 0..1000), plus a
// weight for its source (apps first, as in Spotlight), plus what you've
// opened before (Frecency.js). The best becomes the Top Hit; the rest go to
// their sections in a fixed order, so sections never trade places while
// results stream in.
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

.import "Frecency.js" as Frecency

var SOURCE_WEIGHT = { app: 100, panel: 65, omarchy: 60, theme: 35, window: 20, file: 0 }

// In order. `limit` is how many rows show before "Show More".
var SECTIONS = [
  { id: "apps", title: "Applications", limit: 5 },
  { id: "omarchy", title: "Omarchy", limit: 5 },
  { id: "themes", title: "Themes", limit: 3 },
  { id: "folders", title: "Folders", limit: 4 },
  { id: "documents", title: "Documents", limit: 4 },
  { id: "pdf", title: "PDF Documents", limit: 4 },
  { id: "spreadsheets", title: "Spreadsheets", limit: 3 },
  { id: "presentations", title: "Presentations", limit: 3 },
  { id: "images", title: "Images", limit: 4 },
  { id: "movies", title: "Movies", limit: 3 },
  { id: "music", title: "Music", limit: 3 },
  { id: "developer", title: "Developer", limit: 4 },
  { id: "archives", title: "Archives", limit: 3 },
  { id: "other", title: "Other", limit: 3 }
]

var EXPANDED_LIMIT = 25

// Words for "/kind" filters, as in Tahoe ("/pdf", "/images").
var KIND_WORDS = {
  apps: ["app", "apps", "application", "applications"],
  omarchy: ["omarchy", "settings", "setting", "actions", "action", "menu"],
  themes: ["theme", "themes"],
  folders: ["folder", "folders", "dir", "dirs"],
  documents: ["doc", "docs", "document", "documents", "text"],
  pdf: ["pdf", "pdfs"],
  spreadsheets: ["sheet", "sheets", "spreadsheet", "spreadsheets"],
  presentations: ["slides", "presentation", "presentations"],
  images: ["image", "images", "photo", "photos", "picture", "pictures"],
  movies: ["movie", "movies", "video", "videos"],
  music: ["music", "audio", "song", "songs"],
  developer: ["code", "dev", "developer", "source"],
  archives: ["archive", "archives", "zip"],
  other: ["other"]
}

// The kinds a "/word" filter could mean, best first: "/pd" → PDF Documents.
function kindsFor(word) {
  var w = String(word || "").toLowerCase().trim()
  var out = []
  for (var s = 0; s < SECTIONS.length; s++) {
    var id = SECTIONS[s].id
    var words = KIND_WORDS[id] || [id]
    var exact = words.indexOf(w) >= 0
    var prefix = words.some(function(k) { return k.indexOf(w) === 0 })
    if (exact) out.unshift({ id: id, title: SECTIONS[s].title })
    else if (prefix || w === "") out.push({ id: id, title: SECTIONS[s].title })
  }
  return out
}

function sectionOf(candidate) {
  if (!candidate) return "other"
  if (candidate.source === "app") return "apps"
  if (candidate.source === "omarchy" || candidate.source === "panel") return "omarchy"
  if (candidate.source === "theme") return "themes"
  if (candidate.source === "file") return candidate.group || "other"
  return "other"
}

function sectionTitle(id) {
  for (var i = 0; i < SECTIONS.length; i++) if (SECTIONS[i].id === id) return SECTIONS[i].title
  return id === "top" ? "Top Hit" : "Other"
}

// Orders candidates best first. Ties go to the shorter title, then A–Z.
function score(candidates, query, history, now, learn) {
  var out = []
  var learned = learn !== false && !!history
  // What you picked for this query, worked out once for the whole list.
  var picked = learned ? Frecency.affinity(history, query, now) : {}
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i]
    if (!c || !(c.score > 0) || !c.key) continue
    var boost = learned
      ? Math.round(Frecency.itemBoost(history, c.key, now) + (Object.prototype.hasOwnProperty.call(picked, c.key) ? picked[c.key] : 0))
      : 0
    out.push({ c: c, total: c.score + (SOURCE_WEIGHT[c.source] || 0) + boost, boost: boost })
  }
  out.sort(function(a, b) {
    if (b.total !== a.total) return b.total - a.total
    var at = String(a.c.title || ""), bt = String(b.c.title || "")
    if (at.length !== bt.length) return at.length - bt.length
    return at < bt ? -1 : at > bt ? 1 : 0
  })
  return out
}

// The list the window shows.
//   input: {
//     query, candidates: [{ key, source, score, title, ... }],
//     answer: Calc.answer() or null, web: bool,
//     history, now, learn, pinnedTop: key to keep on top (see below),
//     enabled: { apps: true, ... } (a missing section is on),
//     expanded: { documents: true },
//     topHit: false for a view without a Top Hit
//   }
// Returns { rows: [{ key, section, sectionTitle, candidate, ... }], top, more: { id: count } }.
//
// `pinnedTop` keeps the Top Hit you're already looking at when slower
// results (files) arrive for the same query, as long as it's still there.
// Tahoe's list: one ranked list without headers, the Top Hit first and
// preselected, at most `perKind` rows of any one kind so a query that matches
// a hundred source files still shows the app you meant. `kinds` lists what
// was found, best first, for the filter chips; `scope` keeps one kind only.
//   input: as build(), plus { scope: "images", perKind: 6, maxRows: 60 }
// Returns { rows, top, kinds: [{ id, title, count }] }.
function flat(input) {
  var query = String(input.query || "")
  var enabled = input.enabled || {}
  var scope = input.scope || ""
  var perKind = input.perKind || 6
  var maxRows = input.maxRows || 60
  var ranked = score(input.candidates || [], query, input.history, input.now || 0, input.learn)
    .filter(function(r) { return enabled[sectionOf(r.c)] !== false })

  // Slower results for the same query keep the Top Hit you're looking at.
  if (input.pinnedTop && ranked.length > 0 && ranked[0].c.key !== input.pinnedTop) {
    for (var p = 1; p < ranked.length; p++) {
      if (ranked[p].c.key === input.pinnedTop) {
        ranked.unshift(ranked.splice(p, 1)[0])
        break
      }
    }
  }

  var rows = []
  var kinds = {}
  var order = []
  var counts = {}
  if (input.answer && !scope) rows.push({ key: "calc:" + query, section: "answer", sectionTitle: "", kind: "answer", candidate: null, answer: input.answer })
  for (var i = 0; i < ranked.length; i++) {
    var c = ranked[i].c
    var section = sectionOf(c)
    if (scope && section !== scope) continue
    if (!kinds[section]) {
      kinds[section] = { id: section, title: sectionTitle(section), count: 0 }
      order.push(section)
    }
    kinds[section].count++
    if (rows.length >= maxRows) continue
    if (!scope && (counts[section] || 0) >= perKind) continue
    counts[section] = (counts[section] || 0) + 1
    rows.push({ key: c.key, section: section, sectionTitle: "", kind: "item", candidate: c })
  }
  var top = rows.length > 0 ? rows[0].key : ""
  if (input.web && query.trim() && !scope) {
    rows.push({ key: "web:" + query.trim(), section: "web", sectionTitle: "", kind: "web", candidate: null })
  }
  return { rows: rows, top: top, kinds: order.map(function(id) { return kinds[id] }), more: {} }
}

// Classic Spotlight's list, for a style that groups results (the Drawer):
// the same rows as flat(), with the Top Hit (or the answer) first under "Top
// Hit", then a section per kind in SECTIONS order, then the web.
function grouped(input) {
  var built = flat(input)
  var head = null
  var items = []
  var web = []
  for (var i = 0; i < built.rows.length; i++) {
    var r = built.rows[i]
    if (r.kind === "web") web.push(r)
    else if (!head) head = r
    else items.push(r)
  }
  function titled(r, title) {
    return { key: r.key, section: r.section, sectionTitle: title, kind: r.kind, candidate: r.candidate, answer: r.answer }
  }
  var rows = []
  if (head) rows.push(titled(head, "Top Hit"))
  for (var s = 0; s < SECTIONS.length; s++) {
    for (var j = 0; j < items.length; j++) {
      if (items[j].section === SECTIONS[s].id) rows.push(titled(items[j], SECTIONS[s].title))
    }
  }
  web.forEach(function(r) { rows.push(titled(r, "Web")) })
  return { rows: rows, top: built.top, kinds: built.kinds, more: {} }
}

function build(input) {
  var query = String(input.query || "")
  var enabled = input.enabled || {}
  var expanded = input.expanded || {}
  var ranked = score(input.candidates || [], query, input.history, input.now || 0, input.learn)
    .filter(function(r) { return enabled[sectionOf(r.c)] !== false })
  var rows = []
  var more = {}
  var topKey = ""

  if (input.topHit === false) {
    // A browse view: sections only.
  } else if (input.answer) {
    topKey = "calc:" + query
    rows.push({ key: topKey, section: "top", sectionTitle: "Top Hit", kind: "answer", candidate: null, answer: input.answer })
  } else if (ranked.length > 0) {
    var top = ranked[0]
    if (input.pinnedTop) {
      for (var p = 0; p < ranked.length; p++) {
        if (ranked[p].c.key === input.pinnedTop) {
          top = ranked[p]
          break
        }
      }
    }
    topKey = top.c.key
    rows.push({ key: topKey, section: "top", sectionTitle: "Top Hit", kind: "item", candidate: top.c })
  }

  for (var s = 0; s < SECTIONS.length; s++) {
    var section = SECTIONS[s]
    if (enabled[section.id] === false) continue
    var limit = expanded[section.id] ? EXPANDED_LIMIT : section.limit
    var shown = 0
    var hidden = 0
    for (var i = 0; i < ranked.length; i++) {
      var c = ranked[i].c
      if (c.key === topKey || sectionOf(c) !== section.id) continue
      if (shown < limit) {
        rows.push({ key: c.key, section: section.id, sectionTitle: section.title, kind: "item", candidate: c })
        shown++
      } else {
        hidden++
      }
    }
    if (hidden > 0) more[section.id] = hidden
  }

  if (input.web && query.trim()) {
    rows.push({ key: "web:" + query.trim(), section: "web", sectionTitle: "", kind: "web", candidate: null })
  }

  return { rows: rows, top: topKey, more: more }
}
