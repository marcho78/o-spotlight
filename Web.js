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
  return ENGINES[id] || ENGINES.google
}

function searchUrl(engineId, query) {
  return engine(engineId).url + encodeURIComponent(String(query || "").trim())
}

var TLDS = "com|org|net|io|dev|app|ai|co|me|info|biz|edu|gov|xyz|sh|gg|tv|fm|us|uk|de|fr|nl|se|no|dk|fi|es|it|pt|pl|cz|ch|at|be|ca|au|nz|jp|kr|cn|in|br|mx|ru|ua|eu|so|to|ly|is|im|page|site|online|tech|blog|news|shop|cloud|design|studio|wiki"

// An address you typed, as a URL to open, or "" when it isn't one:
// "github.com/basecamp" → "https://github.com/basecamp", "localhost:3000" → "http://localhost:3000".
function addressUrl(query) {
  var text = String(query || "").trim()
  if (!text || text.length > 2000 || /\s/.test(text)) return ""
  if (/^https?:\/\/[^\s\/$.?#][^\s]*$/i.test(text)) return text
  if (/^(localhost|127\.0\.0\.1|\[::1\])(:\d{1,5})?(\/\S*)?$/i.test(text)) return "http://" + text
  if (/^(\d{1,3}\.){3}\d{1,3}(:\d{1,5})?(\/\S*)?$/.test(text)) return "http://" + text
  var re = new RegExp("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+(" + TLDS + ")(:\\d{1,5})?(/\\S*)?$", "i")
  return re.test(text) ? "https://" + text : ""
}
