// Web.js - searching the web, and opening addresses you type.
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

var ENGINES = {
  google: { name: "Google", url: "https://www.google.com/search?q=" },
  duckduckgo: { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
  bing: { name: "Bing", url: "https://www.bing.com/search?q=" },
  brave: { name: "Brave Search", url: "https://search.brave.com/search?q=" },
  kagi: { name: "Kagi", url: "https://kagi.com/search?q=" },
  startpage: { name: "Startpage", url: "https://www.startpage.com/do/search?q=" },
  ecosia: { name: "Ecosia", url: "https://www.ecosia.org/search?q=" }
}

function engine(id) {
  return Object.prototype.hasOwnProperty.call(ENGINES, id) ? ENGINES[id] : ENGINES.google
}

// Match a provider prefix at the start of a query, for example
// "@Bing weather" -> { id: "bing", query: "weather" }.
// Provider names are the same ids used by the Web Engine setting.
function parseProviderQuery(query) {
  var match = String(query || "").match(/^@([a-z0-9-]+)(?:\s+|$)([\s\S]*)$/i)
  if (!match) return null
  var id = match[1].toLowerCase()
  if (!Object.prototype.hasOwnProperty.call(ENGINES, id)) return null
  return { id: id, name: ENGINES[id].name, query: String(match[2] || "").trim() }
}

function providerChoices(query) {
  var match = String(query || "").trim().match(/^@([a-z0-9-]*)$/i)
  if (!match) return []
  var prefix = match[1].toLowerCase()
  return Object.keys(ENGINES).filter(function(id) {
    return id.indexOf(prefix) === 0 || ENGINES[id].name.toLowerCase().indexOf(prefix) === 0
  }).map(function(id) { return { id: id, name: ENGINES[id].name } })
}

function isProviderCommand(query) {
  return /^\s*@/.test(String(query || ""))
}

// Rich text used only to paint the recognized provider token. All user text
// is escaped before it is inserted into markup.
function providerMarkup(text, accent) {
  var value = String(text || "")
  var escape = function(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;").replace(/'/g, "&#39;")
  }
  var match = value.match(/^(@[a-z0-9-]+)(?=\s|$)/i)
  if (!match || !parseProviderQuery(match[1])) return escape(value)
  return '<font color="' + escape(String(accent || "#0a84ff")) + '">' + escape(match[1]) + '</font>' + escape(value.slice(match[1].length))
}

function searchUrl(engineId, query) {
  return engine(engineId).url + encodeURIComponent(String(query || "").trim())
}

var TLDS = "com|org|net|io|dev|app|ai|co|me|info|biz|edu|gov|xyz|sh|gg|tv|fm|us|uk|de|fr|nl|se|no|dk|fi|es|it|pt|pl|cz|ch|at|be|ca|au|nz|jp|kr|cn|in|br|mx|ru|ua|eu|so|to|ly|is|im|page|site|online|tech|blog|news|shop|cloud|design|studio|wiki"

// An address you typed, as a URL to open, or "" when it isn't one:
// "github.com/basecamp" → "https://github.com/basecamp", "localhost:3000" → "http://localhost:3000".
// Control characters never make an address; the scheme comes out lowercase.
function addressUrl(query) {
  var text = String(query || "").trim()
  if (!text || text.length > 2000 || /[\s\u0000-\u001f\u007f-\u009f]/.test(text)) return ""
  if (/^https?:\/\/[^\s\/$.?#][^\s]*$/i.test(text)) return text.replace(/^https?/i, function(scheme) { return scheme.toLowerCase() })
  if (/^(localhost|127\.0\.0\.1|\[::1\])(:\d{1,5})?(\/\S*)?$/i.test(text)) return "http://" + text
  if (/^(\d{1,3}\.){3}\d{1,3}(:\d{1,5})?(\/\S*)?$/.test(text)) return "http://" + text
  var re = new RegExp("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+(" + TLDS + ")(:\\d{1,5})?(/\\S*)?$", "i")
  return re.test(text) ? "https://" + text : ""
}
