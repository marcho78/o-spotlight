// Files.js - files and folders: finding them, their kind and their icon.
//
// Names are searched live with fd (every folder under your home, skipping
// hidden and git-ignored files, like Spotlight skips system files), and
// contents with LocalSearch, GNOME's file indexer, when it's running. Both
// are started with an argument list, never through a shell.
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

.import "Match.js" as Match

// Folders nobody means when they search, on top of what fd already skips.
var DEFAULT_EXCLUDES = ["node_modules", "__pycache__", "site-packages", "Trash"]

// The words of the query that go to fd and LocalSearch: at most six, none
// empty, without characters that are special to either.
function searchTerms(query) {
  return String(query || "").trim().split(/\s+/).filter(function(t) {
    return t.length > 0 && t.length <= 64
  }).slice(0, 6)
}

// fd: every name containing all the words, under `root`.
//   options: { root, excludes: ["node_modules", "/Work/private"], limit }
function fdArgs(query, options) {
  options = options || {}
  var terms = searchTerms(query)
  if (terms.length === 0 || !options.root) return null
  // Files and folders only: no links, pipes, sockets or devices.
  var argv = ["/usr/bin/fd", "--absolute-path", "--color=never", "--print0", "--ignore-case",
              "--fixed-strings", "--type=f", "--type=d",
              "--max-results=" + Math.max(1, Math.min(2000, options.limit || 300))]
  var excludes = DEFAULT_EXCLUDES.concat(options.excludes || [])
  for (var i = 0; i < excludes.length; i++) {
    var glob = excludes[i]
    if (typeof glob === "string" && glob.length > 0 && glob.length < 512 && glob.indexOf("\n") < 0)
      argv.push("--exclude=" + glob)
  }
  for (var j = 1; j < terms.length; j++) argv.push("--and=" + terms[j])
  argv.push("--", terms[0], options.root)
  return argv
}

// LocalSearch: files whose name or contents match.
function localSearchArgs(query, limit) {
  var terms = searchTerms(query)
  if (terms.length === 0) return null
  return ["/usr/bin/localsearch", "search", "--limit=" + Math.max(1, Math.min(500, limit || 60)), "--"].concat(terms)
}

// "/home/u/Docs/a b.txt" → a file:// URI with every special character escaped,
// safe inside quotes in a GVariant or shell string.
function fileUri(path) {
  return "file://" + String(path).split("/").map(function(part) {
    return encodeURIComponent(part).replace(/[!'()*]/g, function(c) {
      return "%" + c.charCodeAt(0).toString(16).toUpperCase()
    })
  }).join("/")
}

// The URI GLib writes for a path (g_filename_to_uri), which is what the
// freedesktop thumbnail cache is keyed by: md5 of this string.
function thumbnailUri(path) {
  var bytes = unescape(encodeURIComponent(String(path || "")))
  var out = ""
  for (var i = 0; i < bytes.length; i++) {
    var c = bytes.charAt(i)
    var code = bytes.charCodeAt(i)
    if (/[A-Za-z0-9]/.test(c) || "!$&'()*+,-./:=@_~".indexOf(c) >= 0) out += c
    else out += "%" + ("0" + code.toString(16).toUpperCase()).slice(-2)
  }
  return "file://" + out
}

function pathFromUri(uri) {
  var text = String(uri || "").trim()
  if (text.indexOf("file://") !== 0) return ""
  try {
    var path = decodeURIComponent(text.slice(7))
    return path.charAt(0) === "/" ? path : ""
  } catch (e) {
    return ""
  }
}

// A path is usable if it's absolute and has no control characters.
function goodPath(path) {
  return typeof path === "string" && /^\/[^\u0000-\u001f\u007f]{0,4095}$/.test(path)
}

function isExcluded(path, excludes) {
  var list = excludes || []
  for (var i = 0; i < list.length; i++) {
    var prefix = String(list[i] || "").replace(/\/+$/, "")
    if (prefix.charAt(0) === "/" && (path === prefix || path.indexOf(prefix + "/") === 0)) return true
  }
  return false
}

// fd's output: NUL-separated paths, folders ending in "/".
function parseFd(output, excludes, home) {
  var out = []
  var seen = {}
  var parts = String(output || "").split("\u0000")
  for (var i = 0; i < parts.length; i++) {
    var raw = parts[i]
    if (!raw) continue
    var isDir = raw.length > 1 && raw.charAt(raw.length - 1) === "/"
    var path = isDir ? raw.replace(/\/+$/, "") : raw
    if (!goodPath(path) || seen[path] || isExcluded(path, excludes)) continue
    seen[path] = true
    out.push(describe(path, isDir, home))
  }
  return out
}

// LocalSearch's output: one file:// URI per line.
function parseLocalSearch(output, excludes, home) {
  var out = []
  var seen = {}
  var lines = String(output || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var path = pathFromUri(lines[i])
    if (!goodPath(path) || seen[path] || isExcluded(path, excludes)) continue
    // Hidden folders are private to their apps, as they are for fd.
    if (/\/\./.test(path)) continue
    seen[path] = true
    var file = describe(path, false, home)
    file.fromContents = true
    out.push(file)
  }
  return out
}

// Recently used files (~/.local/share/recently-used.xbel), newest first. One
// pass over the file: each <bookmark ...> tag is cut at its own ">" before
// its attributes are looked at, so no tag can make the search run long.
var HREF = /\shref="([^"]*)"/
var MODIFIED = /\smodified="([^"]*)"/

function xmlText(value) {
  return value.replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
}

function parseRecent(xml, limit) {
  var out = []
  var seen = {}
  var parts = String(xml || "").split("<bookmark")
  for (var i = 1; i < parts.length; i++) {
    var part = parts[i]
    // <bookmark:applications> and the like aren't bookmarks.
    if (!/^\s/.test(part)) continue
    var end = part.indexOf(">")
    var tag = end >= 0 ? part.slice(0, end) : part
    var href = HREF.exec(tag)
    var modified = MODIFIED.exec(tag)
    if (!href || !modified) continue
    var path = pathFromUri(xmlText(href[1]))
    if (!goodPath(path) || seen[path] || /\/\./.test(path)) continue
    seen[path] = true
    var when = Date.parse(xmlText(modified[1]))
    out.push({ path: path, time: isFinite(when) ? when : 0 })
  }
  out.sort(function(a, b) { return b.time - a.time })
  return out.slice(0, limit || 30)
}

// What `stat -c STAT_FORMAT -- paths...` says about each path:
// { path: { time, size, isDir, regular } }. The kind comes from the raw mode
// (%f), which reads the same in every language; `stat` describes a link
// itself, never what it points to. Paths that no longer exist are simply
// missing from it.
var STAT_FORMAT = "%Y\t%s\t%f\t%n"

function parseStat(output) {
  var out = {}
  var lines = String(output || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^(\d+)\t(\d+)\t([0-9a-f]{1,8})\t(\/.*)$/)
    if (!m || !goodPath(m[4])) continue
    var type = parseInt(m[3], 16) & 0xf000
    out[m[4]] = { time: Number(m[1]) * 1000, size: Number(m[2]), isDir: type === 0x4000, regular: type === 0x8000 }
  }
  return out
}

// A picture Qt may open: what `stat` said is a regular file no bigger than
// `cap`. Anything else (a link, a pipe, a device), and anything not looked
// at yet, isn't: opening a pipe would stall the shell's picture loading.
function pictureOk(info, cap) {
  return !!(info && info.regular && info.size <= cap)
}

// ---- kinds and icons ---------------------------------------------------------------------
//
// Groups are Spotlight's sections for files, in their order.

var GROUPS = [
  { id: "folders", title: "Folders" },
  { id: "documents", title: "Documents" },
  { id: "pdf", title: "PDF Documents" },
  { id: "spreadsheets", title: "Spreadsheets" },
  { id: "presentations", title: "Presentations" },
  { id: "images", title: "Images" },
  { id: "movies", title: "Movies" },
  { id: "music", title: "Music" },
  { id: "developer", title: "Developer" },
  { id: "archives", title: "Archives" },
  { id: "other", title: "Other" }
]

// extension → [group, kind, icon names to try (most specific first)]
var TYPES = {}

function type(exts, group, kind, icons) {
  exts.split(" ").forEach(function(ext) {
    TYPES[ext] = [group, typeof kind === "function" ? kind(ext) : kind, icons]
  })
}

function upper(ext) { return ext.toUpperCase() }

type("pdf", "pdf", "PDF document", ["application-pdf", "x-office-document"])
type("doc docx", "documents", "Word document", ["x-office-document", "text-x-generic"])
type("odt", "documents", "OpenDocument text", ["x-office-document", "text-x-generic"])
type("rtf", "documents", "Rich text document", ["x-office-document", "text-x-generic"])
type("pages", "documents", "Pages document", ["x-office-document", "text-x-generic"])
type("txt text log", "documents", "Plain text document", ["text-x-generic"])
type("md markdown", "documents", "Markdown document", ["text-markdown", "text-x-generic"])
type("org rst adoc tex", "documents", function(e) { return upper(e) + " document" }, ["text-x-generic"])
type("epub", "documents", "EPUB book", ["application-epub+zip", "x-office-document"])
type("xls xlsx", "spreadsheets", "Excel spreadsheet", ["x-office-spreadsheet"])
type("ods", "spreadsheets", "OpenDocument spreadsheet", ["x-office-spreadsheet"])
type("csv tsv", "spreadsheets", function(e) { return upper(e) + " document" }, ["text-csv", "x-office-spreadsheet"])
type("numbers", "spreadsheets", "Numbers spreadsheet", ["x-office-spreadsheet"])
type("ppt pptx", "presentations", "PowerPoint presentation", ["x-office-presentation"])
type("odp", "presentations", "OpenDocument presentation", ["x-office-presentation"])
type("key", "presentations", "Keynote presentation", ["x-office-presentation"])
type("png jpg jpeg gif webp heic heif avif bmp tif tiff ico jxl", "images",
     function(e) { return (e === "jpg" ? "JPEG" : upper(e)) + " image" }, ["image-x-generic"])
type("svg", "images", "SVG image", ["image-svg+xml", "image-x-generic"])
type("psd xcf kra", "images", function(e) { return upper(e) + " image" }, ["image-x-generic"])
type("mp4 m4v mkv mov webm avi wmv flv", "movies", function(e) { return upper(e) + " movie" }, ["video-x-generic"])
type("mp3 flac ogg oga opus m4a wav aac aiff wma", "music", function(e) { return upper(e) + " audio" }, ["audio-x-generic"])
type("zip tar gz tgz xz zst bz2 7z rar lz4", "archives", function(e) { return upper(e) + " archive" }, ["package-x-generic"])
type("iso img dmg", "other", "Disk image", ["media-optical", "drive-harddisk"])
type("ttf otf woff woff2", "other", "Font", ["font-x-generic"])
type("deb rpm appimage flatpakref", "other", "Package", ["package-x-generic"])
type("desktop", "other", "Desktop entry", ["application-x-executable"])
type("js mjs cjs ts tsx jsx", "developer", function(e) { return ({ js: "JavaScript", mjs: "JavaScript", cjs: "JavaScript", jsx: "JSX", ts: "TypeScript", tsx: "TSX" })[e] + " source" }, ["text-x-script", "text-x-generic"])
type("py rb go rs c h cc cpp hpp cs java kt swift lua pl php r jl dart ex exs zig nim scala hs ml clj",
     "developer", function(e) { return ({ py: "Python", rb: "Ruby", go: "Go", rs: "Rust", c: "C", h: "C Header", cc: "C++", cpp: "C++", hpp: "C++ Header", cs: "C#", java: "Java", kt: "Kotlin", swift: "Swift", lua: "Lua", pl: "Perl", php: "PHP", r: "R", jl: "Julia", dart: "Dart", ex: "Elixir", exs: "Elixir", zig: "Zig", nim: "Nim", scala: "Scala", hs: "Haskell", ml: "OCaml", clj: "Clojure" })[e] + " source" },
     ["text-x-script", "text-x-generic"])
type("sh bash zsh fish", "developer", "Shell script", ["text-x-script", "application-x-shellscript"])
type("qml", "developer", "QML source", ["text-x-script", "text-x-generic"])
type("html htm", "developer", "HTML document", ["text-html", "text-x-generic"])
type("css scss sass less", "developer", function(e) { return upper(e) + " stylesheet" }, ["text-css", "text-x-generic"])
type("json jsonc yaml yml toml ini conf cfg xml", "developer", function(e) { return upper(e) + " file" }, ["text-x-generic"])
type("sql", "developer", "SQL file", ["text-x-sql", "text-x-generic"])
type("ipynb", "developer", "Jupyter notebook", ["text-x-script", "text-x-generic"])

// The special folders of your home, with their own icons.
var SPECIAL_FOLDERS = {
  "Desktop": "user-desktop",
  "Documents": "folder-documents",
  "Downloads": "folder-download",
  "Music": "folder-music",
  "Pictures": "folder-pictures",
  "Videos": "folder-videos",
  "Public": "folder-publicshare",
  "Templates": "folder-templates"
}

function own(table, key) {
  return Object.prototype.hasOwnProperty.call(table, key) ? table[key] : null
}

function extensionOf(name) {
  var lower = String(name || "").toLowerCase()
  if (/\.pkg\.tar\.(zst|xz|gz)$/.test(lower)) return "deb"
  var dot = lower.lastIndexOf(".")
  return dot > 0 ? lower.slice(dot + 1) : ""
}

function groupTitle(id) {
  for (var i = 0; i < GROUPS.length; i++) if (GROUPS[i].id === id) return GROUPS[i].title
  return "Other"
}

// Everything the results need to know about a path.
function describe(path, isDir, home) {
  var clean = String(path).replace(/\/+$/, "") || "/"
  var slash = clean.lastIndexOf("/")
  var name = clean.slice(slash + 1) || clean
  var parent = slash > 0 ? clean.slice(0, slash) : "/"
  if (isDir) {
    var special = home && parent === home ? own(SPECIAL_FOLDERS, name) : ""
    return {
      path: clean, name: name, parent: parent, isDir: true, group: "folders",
      kind: "Folder", icons: [special || "folder", "folder"], ext: ""
    }
  }
  var ext = extensionOf(name)
  var known = own(TYPES, ext)
  var stem = ext && name.toLowerCase().slice(-ext.length - 1) === "." + ext ? name.slice(0, name.length - ext.length - 1) : name
  return {
    path: clean, name: name, stem: stem, parent: parent, isDir: false,
    group: known ? known[0] : "other",
    kind: known ? known[1] : (ext ? ext.toUpperCase() + " file" : "Document"),
    icons: (known ? known[2] : []).concat(["text-x-generic", "application-octet-stream"]),
    ext: ext
  }
}

// "/home/u/Documents/Taxes" → "~/Documents/Taxes"
function displayPath(path, home) {
  var text = String(path || "")
  if (home && (text === home || text.indexOf(home + "/") === 0)) return "~" + text.slice(home.length)
  return text
}

function isImage(file) {
  return file && !file.isDir && ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "jxl", "tif", "tiff", "ico"].indexOf(file.ext) >= 0
}

// ---- ranking files ---------------------------------------------------------------------------

// How well a file matches, before Rank.js adds what you've opened before.
// A file LocalSearch found by its contents, not its name, still counts, a
// little less than a name match, but only for the query LocalSearch answered
// (`contentsCurrent`), never for the next one you type.
function score(query, file, home, contentsCurrent) {
  // Names match from the start of a word, as in Spotlight: "the" finds
  // "Theming.md", not "aether.jpg".
  var fields = [{ text: file.name, weight: 1, min: 620 }]
  if (file.stem && file.stem !== file.name) fields.push({ text: file.stem, weight: 1, min: 620 })
  fields.push({ text: displayPath(file.parent, home), weight: 0.35, loose: false })
  var value = Match.best(query, fields)
  if (value === 0 && file.fromContents && contentsCurrent !== false) value = 430
  if (value === 0) return 0
  // Closer to home reads as more yours; deep inside projects less so.
  var rel = displayPath(file.path, home)
  var depth = rel.charAt(0) === "~" ? rel.split("/").length - 2 : 8
  value -= Math.min(60, Math.max(0, depth - 1) * 8)
  if (/^~\/(Desktop|Documents|Downloads|Pictures|Music|Videos)(\/|$)/.test(rel)) value += 25
  if (file.isDir) value += 10
  return value
}
