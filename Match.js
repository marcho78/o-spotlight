// Match.js - how well a name matches what you typed.
//
// Every result's name (and its keywords, aliases or folder) is scored against
// the query here; Rank.js then adds each source's weight and what you've
// picked before. Scores run from 0 (no match) to 1000 (exact):
//
//   1000  exact                 "firefox"  → Firefox
//    900  prefix                "fire"     → Firefox
//    800  word prefix           "writer"   → LibreOffice Writer
//    760  every word, in order  "lib wri"  → LibreOffice Writer
//    740  every word, any order "wri lib"  → LibreOffice Writer
//    700  starts of words       "vsc"      → Visual Studio Code
//                               "lowr"     → LibreOffice Writer
//    600  inside a word         "efo"      → Firefox (3 letters or more)
//
// Within a tier a shorter name and an earlier match rank higher. Letters
// scattered through a name ("frfx") don't count: like Spotlight, a match
// starts at the beginning of a word.
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

// Lowercase, without accents: "Café" → "cafe".
function fold(text) {
  var value = String(text === undefined || text === null ? "" : text).toLowerCase()
  if (typeof value.normalize === "function")
    value = value.normalize("NFD").replace(/[̀-ͯ]/g, "")
  return value
}

function isAlnum(c) {
  return /[0-9a-zÀ-ɏͰ-ϿЀ-ӿ]/.test(c)
}

function isUpper(c) {
  return c !== c.toLowerCase() && c === c.toUpperCase()
}

function isDigit(c) {
  return c >= "0" && c <= "9"
}

// Where words begin in `text`: after spaces and punctuation, at camelCase
// humps ("LibreOffice" → Libre|Office) and where letters meet digits.
// Indices are into fold(text), which has the same length unless the text
// carried combining accents of its own.
function wordStarts(text) {
  var original = String(text === undefined || text === null ? "" : text)
  var folded = fold(original)
  var sameShape = folded.length === original.length
  var starts = []
  for (var i = 0; i < folded.length; i++) {
    var c = folded.charAt(i)
    if (!isAlnum(c)) continue
    if (i === 0) {
      starts.push(i)
      continue
    }
    var p = folded.charAt(i - 1)
    if (!isAlnum(p)) starts.push(i)
    else if (sameShape && isUpper(original.charAt(i)) && !isUpper(original.charAt(i - 1))) starts.push(i)
    else if (isDigit(c) !== isDigit(p)) starts.push(i)
  }
  return starts
}

// The query as words: "  Visual  studio " → ["visual", "studio"].
function terms(query) {
  var out = fold(query).trim().split(/\s+/)
  return out[0] === "" ? [] : out
}

// Index of the first word in `folded` that starts with `term`, from `from` on,
// or -1.
function wordPrefixAt(folded, starts, term, from) {
  for (var i = 0; i < starts.length; i++) {
    var s = starts[i]
    if (s < (from || 0)) continue
    if (folded.substr(s, term.length) === term) return s
  }
  return -1
}

// The fewest pieces that spell `q` in order, each piece the start of a word
// in `folded`: "vsc" is 3 in "visual studio code", "lowr" 2 in "libreoffice
// writer". Infinity when it can't be done.
function chunks(q, folded, starts) {
  if (q.length > folded.length || starts.length === 0) return Infinity
  // Quick reject: every letter, in order, and the first at a word start.
  var at = -1
  for (var k = 0; k < q.length; k++) {
    at = folded.indexOf(q.charAt(k), at + 1)
    if (at < 0) return Infinity
  }
  var first = q.charAt(0)
  if (!starts.some(function(s) { return folded.charAt(s) === first })) return Infinity

  // memo[i][pos + 1]: fewest new pieces to spell q[i..] after matching q[i-1]
  // at pos, continuing that piece when the next letter follows it.
  var memo = []
  function best(i, pos) {
    if (i === q.length) return 0
    var row = memo[i] || (memo[i] = [])
    var cached = row[pos + 1]
    if (cached !== undefined) return cached
    var c = q.charAt(i)
    var result = Infinity
    if (pos >= 0 && folded.charAt(pos + 1) === c) result = best(i + 1, pos + 1)
    for (var n = 0; n < starts.length; n++) {
      var s = starts[n]
      if (s <= pos || folded.charAt(s) !== c) continue
      var r = 1 + best(i + 1, s)
      if (r < result) result = r
    }
    row[pos + 1] = result
    return result
  }
  return best(0, -1)
}

// Scores `query` against `text`, 0..1000 (see the table at the top).
function score(query, text) {
  var q = fold(query).trim().replace(/\s+/g, " ")
  if (!q) return 0
  var folded = fold(text)
  if (!folded) return 0

  // Shorter names are closer matches; capped so long names stay findable.
  var extra = Math.min(60, Math.max(0, folded.length - q.length))

  if (folded === q) return 1000
  if (folded.indexOf(q) === 0) return 900 - extra

  var starts = wordStarts(text)
  var word = wordPrefixAt(folded, starts, q, 1)
  if (word > 0) return 800 - extra - Math.min(20, word)

  // One letter only ever means the start of a word.
  if (q.length < 2) return 0

  var words = q.split(" ")
  if (words.length > 1) {
    var inOrder = true
    var all = true
    var from = 0
    for (var i = 0; i < words.length; i++) {
      var hit = wordPrefixAt(folded, starts, words[i], from)
      if (hit < 0) {
        inOrder = false
        if (wordPrefixAt(folded, starts, words[i], 0) < 0) {
          all = false
          break
        }
      } else {
        from = hit + words[i].length
      }
    }
    if (all) return (inOrder ? 760 : 740) - extra
    // Every word somewhere, even mid-word.
    var inside = words.every(function(w) { return folded.indexOf(w) >= 0 })
    if (inside) return 580 - extra
  }

  if (q.indexOf(" ") < 0) {
    var pieces = chunks(q, folded, starts)
    if (pieces !== Infinity) return Math.max(620, 700 - 12 * Math.max(0, pieces - 2)) - extra
  }

  var index = q.length >= 3 ? folded.indexOf(q) : -1
  if (index > 0) return 600 - extra - Math.min(40, index)
  return 0
}

// Scores the query against several texts, each worth part of a full match,
// and keeps the best: [{ text: "Firefox", weight: 1 }, { text: "Web Browser", weight: 0.8 }].
// A field's `min` is the weakest match it accepts: 620 allows no mid-word
// hits (file names), 740 only whole words (descriptions). `loose: false` is
// the same as min 740.
function best(query, fields) {
  var top = 0
  for (var i = 0; i < fields.length; i++) {
    var field = fields[i]
    if (!field || !field.text) continue
    var value = score(query, field.text)
    var min = field.loose === false ? 740 : (field.min || 0)
    if (value < min) value = 0
    value = Math.round(value * (field.weight === undefined ? 1 : field.weight))
    if (value > top) top = value
  }
  return top
}

// The part of `text` the query matched, for highlighting: [start, length], or
// null. Only exact, prefix and word-prefix matches are marked.
function highlight(query, text) {
  var q = fold(query).trim()
  if (!q) return null
  var folded = fold(text)
  if (folded.length !== String(text).length) return null
  if (folded.indexOf(q) === 0) return [0, q.length]
  var word = wordPrefixAt(folded, wordStarts(text), q, 1)
  return word > 0 ? [word, q.length] : null
}
