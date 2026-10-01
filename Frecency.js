// Frecency.js - what you open, remembered, so O-Spotlight learns.
//
// Two things are kept, like Spotlight does: how often and how recently each
// result was opened, and which result you opened for what you typed. After
// picking Terminal for "t" a couple of times, "t" puts Terminal first.
//
// The store lives in ~/.local/state/marcho78.o-spotlight/history.json. It's
// parsed defensively (types, sizes and counts are checked), so a damaged or
// hand-edited file can't feed bad data onwards. Every key in it has a prefix
// ("app:…", "q:…"), so nothing you type or open can be mistaken for one of
// JavaScript's own names ("__proto__", "constructor").
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

var VERSION = 1
var MAX_ITEMS = 400
var MAX_QUERIES = 300
var MAX_PER_QUERY = 6
var MAX_KEY = 1100
var MAX_QUERY = 40
var DAY = 86400000

function empty() {
  return { version: VERSION, items: {}, queries: {}, flags: {} }
}

function own(object, key) {
  return !!object && Object.prototype.hasOwnProperty.call(object, key)
}

// A result's key: "app:firefox", "file:/home/…", "omarchy:style.theme".
function goodKey(key) {
  return typeof key === "string" && key.length <= MAX_KEY && /^[a-z]+:/.test(key)
}

// What you typed, as the store keeps it: "q:" + lowercase, no accents.
function queryKey(query) {
  var text = String(query || "").toLowerCase().trim().replace(/\s+/g, " ")
  if (typeof text.normalize === "function") text = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  text = text.slice(0, MAX_QUERY)
  return text ? "q:" + text : ""
}

function goodCount(n) {
  return typeof n === "number" && isFinite(n) && n >= 0 && n < 1e9
}

// Milliseconds since 1970, up to the year 5000.
function goodTime(t) {
  return typeof t === "number" && isFinite(t) && t >= 0 && t < 1e14
}

function goodEntry(entry) {
  return !!entry && typeof entry === "object" && goodCount(entry.n) && goodTime(entry.t)
}

function parse(text) {
  var store = empty()
  var raw
  try {
    raw = JSON.parse(String(text || ""))
  } catch (e) {
    return store
  }
  if (!raw || typeof raw !== "object" || raw.version !== VERSION) return store
  var items = raw.items && typeof raw.items === "object" ? raw.items : {}
  var keys = Object.keys(items)
  for (var i = 0; i < keys.length && i < MAX_ITEMS * 2; i++) {
    if (!goodKey(keys[i]) || !goodEntry(items[keys[i]])) continue
    store.items[keys[i]] = { n: Math.floor(items[keys[i]].n), t: items[keys[i]].t }
  }
  var queries = raw.queries && typeof raw.queries === "object" ? raw.queries : {}
  var qs = Object.keys(queries)
  for (var j = 0; j < qs.length && j < MAX_QUERIES * 2; j++) {
    var picks = queries[qs[j]]
    if (!/^q:/.test(qs[j]) || qs[j].length > MAX_QUERY + 2 || !picks || typeof picks !== "object") continue
    var clean = {}
    var count = 0
    var pickKeys = Object.keys(picks)
    for (var k = 0; k < pickKeys.length && count < MAX_PER_QUERY; k++) {
      if (!goodKey(pickKeys[k]) || !goodEntry(picks[pickKeys[k]])) continue
      clean[pickKeys[k]] = { n: Math.floor(picks[pickKeys[k]].n), t: picks[pickKeys[k]].t }
      count++
    }
    if (count > 0) store.queries[qs[j]] = clean
  }
  // Small yes/no facts, like having seen the welcome panel.
  var flags = raw.flags && typeof raw.flags === "object" ? raw.flags : {}
  Object.keys(flags).slice(0, 16).forEach(function(k) {
    if (/^[a-z][a-zA-Z]{0,31}$/.test(k) && typeof flags[k] === "boolean") store.flags[k] = flags[k]
  })
  return prune(store)
}

function withFlag(store, name, value) {
  var next = copy(store)
  next.flags = next.flags || {}
  if (/^[a-z][a-zA-Z]{0,31}$/.test(name)) next.flags[name] = !!value
  return next
}

// Keeps the most recently used entries within the limits.
function prune(store) {
  var itemKeys = Object.keys(store.items)
  if (itemKeys.length > MAX_ITEMS) {
    itemKeys.sort(function(a, b) { return store.items[b].t - store.items[a].t })
    var items = {}
    itemKeys.slice(0, MAX_ITEMS).forEach(function(k) { items[k] = store.items[k] })
    store.items = items
  }
  var queryKeys = Object.keys(store.queries)
  if (queryKeys.length > MAX_QUERIES) {
    var newest = function(q) {
      var picks = store.queries[q]
      return Math.max.apply(null, Object.keys(picks).map(function(k) { return picks[k].t }))
    }
    queryKeys.sort(function(a, b) { return newest(b) - newest(a) })
    var queries = {}
    queryKeys.slice(0, MAX_QUERIES).forEach(function(q) { queries[q] = store.queries[q] })
    store.queries = queries
  }
  return store
}

function copy(store) {
  return JSON.parse(JSON.stringify(store || empty()))
}

// A new store with `key` opened now, for `query`.
function record(store, key, query, now) {
  var next = copy(store)
  key = String(key || "")
  if (!goodKey(key)) return next
  var old = own(next.items, key) ? next.items[key] : null
  next.items[key] = { n: (old ? old.n : 0) + 1, t: now }
  var q = queryKey(query)
  if (q) {
    var picks = own(next.queries, q) ? next.queries[q] : {}
    var pick = own(picks, key) ? picks[key] : null
    picks[key] = { n: (pick ? pick.n : 0) + 1, t: now }
    var pickKeys = Object.keys(picks)
    if (pickKeys.length > MAX_PER_QUERY) {
      pickKeys.sort(function(a, b) { return picks[b].t - picks[a].t })
      var kept = {}
      pickKeys.slice(0, MAX_PER_QUERY).forEach(function(k) { kept[k] = picks[k] })
      picks = kept
    }
    next.queries[q] = picks
  }
  return prune(next)
}

function forget(store, key) {
  var next = copy(store)
  if (!goodKey(key)) return next
  delete next.items[key]
  Object.keys(next.queries).forEach(function(q) {
    delete next.queries[q][key]
    if (Object.keys(next.queries[q]).length === 0) delete next.queries[q]
  })
  return next
}

function recency(t, now) {
  var days = Math.max(0, (now - t) / DAY)
  return 1 / (1 + days / 14)
}

// How often and how lately `key` was opened, whatever you typed: up to 240.
function itemBoost(store, key, now) {
  var item = store && own(store.items, key) ? store.items[key] : null
  if (!item) return 0
  return Math.min(240, 60 * Math.log(1 + item.n) / Math.LN2) * recency(item.t, now)
}

// What you picked for this query, worked out once per search: key → extra
// score. Picked for exactly this query counts most, then for a shorter query
// you typed on the way here ("te" → Terminal, now "ter"), then for a longer
// one ("terminal").
function affinity(store, query, now) {
  var out = {}
  var q = queryKey(query)
  if (!store || !q) return out
  var queries = store.queries || {}
  function take(key, value) {
    if (!own(out, key) || out[key] < value) out[key] = value
  }
  for (var len = q.length; len > 2; len--) {
    var prefix = q.slice(0, len)
    if (!own(queries, prefix)) continue
    var picks = queries[prefix]
    var weight = len === q.length ? 400 : 250
    Object.keys(picks).forEach(function(key) {
      take(key, weight * Math.min(1, picks[key].n / 2) * recency(picks[key].t, now))
    })
  }
  var longer = []
  Object.keys(queries).forEach(function(stored) {
    if (stored.length > q.length && stored.indexOf(q) === 0) longer.push(stored)
  })
  longer.forEach(function(stored) {
    var picks = queries[stored]
    Object.keys(picks).forEach(function(key) {
      if (!own(out, key)) take(key, 150 * recency(picks[key].t, now))
    })
  })
  return out
}

// Extra score for `key` when you've typed `query`: up to about 640. For one
// key at a time; Rank.js works out `affinity` once for the whole list.
function boost(store, key, query, now) {
  if (!store || !key) return 0
  var map = affinity(store, query, now)
  return Math.round(itemBoost(store, key, now) + (own(map, key) ? map[key] : 0))
}

// Keys opened most recently, newest first (for an empty query).
function recent(store, prefix, limit) {
  var keys = Object.keys((store && store.items) || {}).filter(function(k) {
    return !prefix || k.indexOf(prefix) === 0
  })
  keys.sort(function(a, b) { return store.items[b].t - store.items[a].t })
  return keys.slice(0, limit || 10)
}
