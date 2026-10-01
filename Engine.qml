import QtQuick
import Quickshell
import Quickshell.Io
import "Match.js" as Match
import "Calc.js" as Calc
import "MenuIndex.js" as MenuIndex
import "Files.js" as Files
import "Rank.js" as Rank
import "Frecency.js" as Frecency
import "Web.js" as Web
import "Settings.js" as Settings

// The search engine behind the window.
//
// Everything that can be answered from memory is, on every keystroke: apps
// (the Omarchy shell's own application library), the Omarchy menu, bar
// panels, themes and the calculator. Files are searched with fd and
// LocalSearch a moment after you stop typing, and merged in below what's
// already on screen: the Top Hit you're looking at stays put.
//
// `rows` is what the window shows, flat and made of plain values so the
// window's model can follow it row by row.
Item {
  id: engine

  // ---- inputs ----------------------------------------------------------------------

  property var barConfig: null
  property var settings: ({})
  property string home: Quickshell.env("HOME")
  // Omarchy's own files, where its package puts them: never taken from the
  // environment, since they decide what runs.
  readonly property string omarchyDir: "/usr/share/omarchy"
  // True while the window is open: that's when live sources get refreshed.
  property bool active: false

  // Where what O-Spotlight learns is kept (the development harness uses its own).
  property string stateDir: home + "/.local/state/marcho78.o-spotlight"
  onStateDirChanged: readHistory()

  // Every file O-Spotlight reads or writes goes through bin/o-spotlight-files,
  // which reaches it without following links, checks who owns it and caps its
  // size (see the helper). The development harness points this elsewhere.
  property string filesHelper: decodeURIComponent(Qt.resolvedUrl("bin/o-spotlight-files").toString().replace(/^file:\/\//, ""))
  function filesCommand(args) {
    return ["/usr/bin/python3", "-I", "-S", filesHelper].concat(args)
  }

  // For the two scripts O-Spotlight runs through bash (Omarchy's own: see
  // hiddenRun and guardRun): Omarchy's commands from /usr/bin only, and no
  // startup file of yours.
  readonly property var shellEnvironment: ({ PATH: "/usr/bin", BASH_ENV: null, ENV: null })

  // ---- what you typed, and what it found ---------------------------------------------

  property string query: ""
  // "all", or a browse view: "apps", "files", "actions", "clipboard".
  property string mode: "all"
  // One kind of result only (a filter chip): "images", "apps"...
  property string scope: ""
  // The Applications view's category chip.
  property string appCategory: ""
  property var rows: []
  property string topKey: ""
  property var kinds: []
  property bool searchingFiles: false
  property int rowsVersion: 0
  // Results in sections by kind (Rank.grouped), for a style that shows them so.
  property bool grouped: false
  onGroupedChanged: rebuild(false)

  property var candidates: ({})        // key -> candidate, for what's on screen

  readonly property var modes: ["all", "apps", "files", "actions", "clipboard"]

  function setQuery(text) {
    var next = String(text || "")
    if (next === query) return
    var widened = query.length > 0 && next.indexOf(query) !== 0
    query = next
    rebuild(false)
    scheduleFiles(widened)
  }

  function setMode(next) {
    if (modes.indexOf(next) < 0) next = "all"
    if (next === mode) return
    mode = next
    scope = ""
    scopeTitle = ""
    appCategory = ""
    if (mode === "files") refreshRecent()
    if (mode === "clipboard") readClipboard()
    rebuild(false)
    scheduleFiles(true)
  }

  // The chip's name, kept while the scope is on (its kind may find nothing
  // as you type on).
  property string scopeTitle: ""

  function setScope(next) {
    scope = next || ""
    scopeTitle = scope ? Rank.sectionTitle(scope) : ""
    rebuild(false)
  }

  function setAppCategory(next) {
    appCategory = appCategory === next ? "" : (next || "")
    rebuild(false)
  }

  function reset() {
    fileRun.cancel()
    contentRun.cancel()
    fileDebounce.stop()
    searchingFiles = false
    query = ""
    mode = "all"
    scope = ""
    scopeTitle = ""
    appCategory = ""
    fileResults = []
    contentResults = []
    fileQuery = ""
    contentQuery = ""
    rebuild(false)
  }

  // Called when the window opens: anything that may have changed since.
  function refresh() {
    scanHiddenApps()
    readLauncherHides()
    readMenus()
    refreshThemes()
    readClipboard()
  }

  // ---- apps ----------------------------------------------------------------------------

  property var apps: []
  property var appCategories: []

  // App Store-like categories from the freedesktop ones in each app's entry.
  readonly property var categoryNames: [
    { id: "productivity", title: "Productivity", from: ["Office", "Calendar", "ContactManagement", "Email", "Finance", "Presentation", "Spreadsheet", "WordProcessor"] },
    { id: "internet", title: "Internet", from: ["Network", "WebBrowser", "Chat", "InstantMessaging", "IRCClient", "FileTransfer", "News", "P2P", "RemoteAccess"] },
    { id: "creativity", title: "Creativity", from: ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography", "AudioVideoEditing", "Recorder", "Publishing"] },
    { id: "entertainment", title: "Entertainment", from: ["Game", "AudioVideo", "Audio", "Video", "Player", "Music", "TV"] },
    { id: "developer", title: "Developer Tools", from: ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "Building", "TerminalEmulator"] },
    { id: "learning", title: "Learning", from: ["Education", "Science", "Math", "Dictionary", "Documentation", "Literature"] },
    { id: "utilities", title: "Utilities", from: ["Utility", "System", "Settings", "Accessibility", "Archiving", "Monitor", "Security", "FileManager", "FileTools", "Filesystem", "HardwareSettings", "PackageManager"] }
  ]

  function categoryOf(entry) {
    var list = []
    try { list = entry.categories ? Array.prototype.slice.call(entry.categories) : [] } catch (e) { list = [] }
    // Specific categories win over broad ones: a video editor is Creativity,
    // not Entertainment, even though it also says AudioVideo.
    for (var pass = 0; pass < 2; pass++) {
      for (var c = 0; c < categoryNames.length; c++) {
        var from = categoryNames[c].from
        for (var i = 0; i < list.length; i++) {
          var broad = ["AudioVideo", "Utility", "Network", "Office", "Graphics", "Development", "System"].indexOf(list[i]) >= 0
          if (pass === 0 && broad) continue
          if (from.indexOf(String(list[i])) >= 0) return categoryNames[c].id
        }
      }
    }
    return "other"
  }

  // The same apps as the Omarchy launcher: every desktop entry, less the ones
  // it hides (Omarchy's launcher.hides list, and entries marked Hidden,
  // NoDisplay or for other desktops, found by Omarchy's own scanner).
  property var hiddenApps: Object.create(null)
  property var launcherHides: Object.create(null)

  function normalizeDesktopId(id) {
    var value = String(id || "").trim()
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
    return value
  }

  function idSet(raw) {
    var out = Object.create(null)
    String(raw || "").split("\n").forEach(function(line) {
      var id = engine.normalizeDesktopId(line)
      if (id && id.length < 256) out[id] = true
    })
    return out
  }

  function readLauncherHides() {
    hidesRun.start(filesCommand(["read", "launcher-hides"]))
  }

  Run {
    id: hidesRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 68 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight:", output)
      engine.launcherHides = ok ? engine.idSet(output) : Object.create(null)
      appsDebounce.restart()
    }
  }

  function scanHiddenApps() {
    var desktop = [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")]
      .filter(function(v) { return /^[A-Za-z0-9_:-]{1,64}$/.test(String(v || "")) }).join(":")
    hiddenRun.start(["/usr/bin/bash", "--noprofile", "--norc", omarchyDir + "/shell/services/hidden-entries.sh", desktop])
  }

  Run {
    id: hiddenRun
    timeoutMs: 8000
    maxBytes: 256 * 1024
    environment: engine.shellEnvironment
    onFinished: function(ok, output) {
      if (!ok) return
      engine.hiddenApps = engine.idSet(output)
      appsDebounce.restart()
    }
  }

  function appIcon(icon) {
    var value = String(icon || "")
    if (value.charAt(0) === "/") return fileUrl(value)
    if (value.indexOf("file://") === 0) return value
    var themed = value ? Quickshell.iconPath(value, true) : ""
    return themed || Quickshell.iconPath("application-x-executable", true)
  }

  function rebuildApps() {
    var values = DesktopEntries.applications.values || []
    var out = []
    var used = {}
    var seen = Object.create(null)
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || !entry.id || entry.noDisplay) continue
      var id = normalizeDesktopId(entry.id)
      if (seen[id] || hiddenApps[id] || launcherHides[id]) continue
      seen[id] = true
      var name = String(entry.name || "")
      if (!name) continue
      var generic = String(entry.genericName || "")
      // The name, then what kind of app it is and its keywords; never the
      // comment, whose everyday words ("the", "and") would match anything.
      var fields = [{ text: name, weight: 1 }]
      if (generic && generic !== name) fields.push({ text: generic, weight: 0.8, min: 620 })
      var keywords = []
      try { keywords = entry.keywords ? Array.prototype.slice.call(entry.keywords) : [] } catch (e) { keywords = [] }
      for (var k = 0; k < keywords.length && k < 24; k++) fields.push({ text: String(keywords[k]), weight: 0.75, min: 620 })
      fields.push({ text: id.split(".").pop(), weight: 0.6, min: 620 })
      var category = categoryOf(entry)
      used[category] = true
      out.push({
        key: "app:" + id,
        source: "app",
        appId: id,
        title: name,
        subtitle: generic,
        icon: String(entry.icon || ""),
        category: category,
        fields: fields
      })
    }
    out.sort(function(a, b) { return a.title.toLowerCase().localeCompare(b.title.toLowerCase()) })
    apps = out
    appCategories = categoryNames.filter(function(c) { return used[c.id] })
      .concat(used.other ? [{ id: "other", title: "Other" }] : [])
    if (active) rebuild(true)
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      engine.scanHiddenApps()
      appsDebounce.restart()
    }
  }

  Timer {
    id: appsDebounce
    interval: 300
    onTriggered: engine.rebuildApps()
  }

  // ---- the Omarchy menu --------------------------------------------------------------------

  property var menuDefault: []
  property var menuUser: []
  property var menuMerged: ({ items: {}, order: [] })
  property var menuGuards: ({ when: {}, checked: {} })
  property var menuEntries: []

  function rebuildMenu() {
    menuMerged = MenuIndex.merge(menuDefault, menuUser)
    menuEntries = MenuIndex.entries(menuMerged, menuGuards)
    evaluateGuards()
    if (active) rebuild(true)
  }

  // Omarchy's menu (root's, from its package) and your additions to it.
  function readMenus() {
    menuRun.start(filesCommand(["read", "menu"]))
    userMenuRun.start(filesCommand(["read", "user-menu"]))
  }

  Run {
    id: menuRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 1028 * 1024
    onFinished: function(ok, output) {
      if (!ok) {
        console.warn("O-Spotlight:", output)
        return
      }
      engine.menuDefault = MenuIndex.parse(output)
      menuDebounce.restart()
    }
  }

  Run {
    id: userMenuRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 1028 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight:", output)
      engine.menuUser = ok ? MenuIndex.parse(output) : []
      menuDebounce.restart()
    }
  }

  // Both menus read, then one rebuild (and one run of the checks).
  Timer {
    id: menuDebounce
    interval: 40
    onTriggered: engine.rebuildMenu()
  }

  // The same `when:`/`checked:` checks the Omarchy menu runs (its own
  // MenuModel.guardScript, as MenuIndex.guardScript), so both show the same
  // rows. They're the menu's tests, from its files; none of O-Spotlight's own
  // data reaches them. Two batches:
  //   - Omarchy's rows (root's menu file): no startup files, and Omarchy's
  //     commands from /usr/bin only.
  //   - Rows from your own menu file: as the Omarchy menu runs them, a login
  //     shell with your PATH, since they call your own tools.
  property var ownGuards: null
  property var userGuards: null
  property bool ownGuardsAgain: false
  property bool userGuardsAgain: false
  readonly property var userMenuIds: MenuIndex.idsOf(menuUser)

  function evaluateGuards() {
    evaluateOwnGuards()
    evaluateUserGuards()
  }

  function evaluateOwnGuards() {
    var script = MenuIndex.guardScript(menuMerged.items, function(id) { return !engine.userMenuIds[id] })
    if (!script) {
      setGuards(null, userGuards)
      return
    }
    if (guardRun.running) {
      ownGuardsAgain = true
      return
    }
    guardRun.start(["/usr/bin/bash", "--noprofile", "--norc", "-c", script])
  }

  function evaluateUserGuards() {
    var script = MenuIndex.guardScript(menuMerged.items, function(id) { return !!engine.userMenuIds[id] })
    if (!script) {
      setGuards(ownGuards, null)
      return
    }
    if (userGuardRun.running) {
      userGuardsAgain = true
      return
    }
    userGuardRun.start(["/usr/bin/bash", "-lc", script])
  }

  function setGuards(own, user) {
    ownGuards = own
    userGuards = user
    menuGuards = MenuIndex.combineGuards(own, user)
    menuEntries = MenuIndex.entries(menuMerged, menuGuards)
    if (active) rebuild(true)
  }

  Run {
    id: guardRun
    timeoutMs: 8000
    maxBytes: 256 * 1024
    environment: engine.shellEnvironment
    onFinished: function(ok, output) {
      if (ok) engine.setGuards(MenuIndex.parseGuards(output), engine.userGuards)
      if (engine.ownGuardsAgain) {
        engine.ownGuardsAgain = false
        Qt.callLater(engine.evaluateOwnGuards)
      }
    }
  }

  Run {
    id: userGuardRun
    timeoutMs: 8000
    maxBytes: 64 * 1024
    onFinished: function(ok, output) {
      if (ok) engine.setGuards(engine.ownGuards, MenuIndex.parseGuards(output))
      if (engine.userGuardsAgain) {
        engine.userGuardsAgain = false
        Qt.callLater(engine.evaluateUserGuards)
      }
    }
  }

  readonly property var panelEntries: MenuIndex.panelEntries(barConfig)

  // ---- themes ------------------------------------------------------------------------------

  property var themeEntries: []
  property string currentTheme: ""

  function refreshThemes() {
    themeNameRun.start(filesCommand(["read", "theme-name"]))
    themeRun.start(["/usr/bin/find", "-L", omarchyDir + "/themes", home + "/.config/omarchy/themes",
                    "-mindepth", "1", "-maxdepth", "1", "-type", "d"])
  }

  Run {
    id: themeNameRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 8 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight:", output)
      engine.currentTheme = ok ? String(output).trim().slice(0, 64) : ""
    }
  }

  Run {
    id: themeRun
    okCodes: [0, 1]
    timeoutMs: 3000
    maxBytes: 64 * 1024
    onFinished: function(ok, output) {
      if (!ok) return
      engine.themeEntries = MenuIndex.themeEntries(output, engine.currentTheme)
      if (engine.active) engine.rebuild(true)
    }
  }

  // ---- files ---------------------------------------------------------------------------------

  property var fileResults: []
  property var contentResults: []
  property string fileQuery: ""
  // The query LocalSearch's results answer: a file found by its contents
  // only counts for that query, never for the next one you type.
  property string contentQuery: ""
  property string pendingFileQuery: ""
  // Size and modification time by path, filled in after each search.
  property var fileMeta: ({})
  readonly property bool filesWanted: settings.files !== false && (mode === "all" || mode === "files")
  readonly property var excluded: settings.excluded || []

  // A moment after you stop typing. Widening the query (deleting) searches
  // again at once, since what's on screen may be missing matches.
  function scheduleFiles(now) {
    var q = query.trim()
    // "/pdf" picks a kind; it isn't something to look for.
    if (!filesWanted || q.length < 2 || (mode === "all" && !scope && q.charAt(0) === "/")) {
      fileDebounce.stop()
      fileRun.cancel()
      contentRun.cancel()
      searchingFiles = false
      if (q.length < 2) {
        fileResults = []
        contentResults = []
        fileQuery = ""
        contentQuery = ""
      }
      return
    }
    searchingFiles = true
    fileDebounce.interval = now ? 30 : 110
    fileDebounce.restart()
  }

  Timer {
    id: fileDebounce
    onTriggered: engine.searchFiles()
  }

  function searchFiles() {
    var q = query.trim()
    pendingFileQuery = q
    var fd = Files.fdArgs(q, { root: home, excludes: excluded.map(function(p) {
      // fd's excludes are relative to where it searches.
      return p.indexOf(engine.home + "/") === 0 ? p.slice(engine.home.length) : p
    }), limit: 400 })
    if (fd) fileRun.replace(fd)
    if (settings.contents !== false && localSearchAvailable) {
      var ls = Files.localSearchArgs(q, 80)
      if (ls) contentRun.replace(ls)
    }
  }

  Run {
    id: fileRun
    timeoutMs: 2500
    maxBytes: 2 * 1024 * 1024
    onFinished: function(ok, output) {
      engine.fileResults = ok ? Files.parseFd(output, engine.excluded, engine.home) : []
      engine.fileQuery = engine.pendingFileQuery
      engine.searchingFiles = contentRun.running
      engine.rebuild(true)
      engine.describeFiles()
    }
  }

  // LocalSearch answers only when its indexer is running; if it isn't, it's
  // simply not asked again until the shell restarts.
  property bool localSearchAvailable: true

  Run {
    id: contentRun
    timeoutMs: 2500
    maxBytes: 512 * 1024
    onFinished: function(ok, output) {
      if (!ok && /not running|could not|no such file|failed to|not found/i.test(output)) engine.localSearchAvailable = false
      engine.contentResults = ok ? Files.parseLocalSearch(output, engine.excluded, engine.home) : []
      engine.contentQuery = engine.pendingFileQuery
      engine.searchingFiles = fileRun.running
      engine.rebuild(true)
      engine.describeFiles()
    }
  }

  // Sizes, dates, and which thumbnails Files already made, for the files on
  // screen, in one `stat`. Thumbnails are asked about once per file.
  readonly property string thumbDir: home + "/.cache/thumbnails/"
  readonly property var thumbSizes: ["x-large", "large", "normal"]
  property var thumbnailIndex: Object.create(null)
  property var thumbChecked: Object.create(null)

  function previewable(file) {
    return Files.isImage(file) || ["pdf", "mp4", "mkv", "mov", "webm", "m4v", "avi", "epub", "odt", "ods", "odp", "docx", "xlsx", "pptx"].indexOf(file.ext) >= 0
  }

  function describeFiles(files) {
    var list = files
    if (!list) {
      list = []
      for (var k in candidates) {
        var c = candidates[k]
        if (c && c.source === "file") list.push(c.file)
      }
    }
    var wanted = []
    var hashes = []
    for (var i = 0; i < list.length && wanted.length < 300; i++) {
      var file = list[i]
      if (!fileMeta[file.path]) wanted.push(file.path)
      if (!file.isDir && previewable(file)) {
        var hash = Qt.md5(Files.thumbnailUri(file.path))
        if (thumbChecked[hash] || hashes.indexOf(hash) >= 0) continue
        hashes.push(hash)
        for (var t = 0; t < thumbSizes.length; t++) wanted.push(thumbDir + thumbSizes[t] + "/" + hash + ".png")
      }
    }
    if (wanted.length === 0) return
    metaRun.hashes = hashes
    metaRun.replace(["/usr/bin/stat", "-c", "%Y\t%s\t%F\t%n", "--"].concat(wanted))
  }

  Run {
    id: metaRun
    property var hashes: []
    okCodes: [0, 1]
    timeoutMs: 2000
    maxBytes: 512 * 1024
    onFinished: function(ok, output) {
      var stats = Files.parseStat(output)
      var meta = {}
      for (var k in engine.fileMeta) meta[k] = engine.fileMeta[k]
      var index = Object.create(null)
      for (var t in engine.thumbnailIndex) index[t] = true
      var checked = Object.create(null)
      for (var h in engine.thumbChecked) checked[h] = true
      for (var p in stats) {
        if (p.indexOf(engine.thumbDir) === 0) {
          var m = p.slice(engine.thumbDir.length).match(/^(x-large|large|normal)\/([0-9a-f]{32})\.png$/)
          if (m) index[m[1] + "/" + m[2]] = true
        } else {
          meta[p] = stats[p]
        }
      }
      // Asked about, whether there was one or not (unless `stat` itself
      // failed, when they're asked about again next time).
      if (ok) metaRun.hashes.forEach(function(hash) { checked[hash] = true })
      // Keep the caches from growing without end.
      if (Object.keys(meta).length > 3000) meta = {}
      if (Object.keys(checked).length > 5000) {
        checked = Object.create(null)
        index = Object.create(null)
      }
      engine.fileMeta = meta
      engine.thumbnailIndex = index
      engine.thumbChecked = checked
      engine.rebuild(true)
    }
  }

  // Recently used files, for the Files view.
  property var recentFiles: []

  function refreshRecent() {
    recentRun.start(filesCommand(["read", "recent"]))
  }

  Run {
    id: recentRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 4100 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight:", output)
      var recent = ok ? Files.parseRecent(output, 40) : []
      if (recent.length === 0) {
        engine.recentFiles = []
        return
      }
      statRun.start(["/usr/bin/stat", "-c", "%Y\t%s\t%F\t%n", "--"].concat(recent.map(function(r) { return r.path })))
    }
  }

  Run {
    id: statRun
    okCodes: [0, 1]
    timeoutMs: 2000
    maxBytes: 256 * 1024
    onFinished: function(ok, output) {
      var stats = Files.parseStat(output)
      var out = []
      Object.keys(stats).forEach(function(path) {
        if (Files.isExcluded(path, engine.excluded)) return
        var file = Files.describe(path, stats[path].isDir, engine.home)
        file.time = stats[path].time
        out.push(file)
      })
      out.sort(function(a, b) { return b.time - a.time })
      var meta = {}
      for (var k in engine.fileMeta) meta[k] = engine.fileMeta[k]
      Object.keys(stats).forEach(function(path) { meta[path] = stats[path] })
      engine.fileMeta = meta
      engine.recentFiles = out.slice(0, 30)
      if (engine.active && engine.mode === "files") engine.rebuild(true)
      engine.describeFiles(engine.recentFiles)
    }
  }

  function fileCandidate(file) {
    return {
      key: "file:" + file.path,
      source: "file",
      group: file.group,
      title: file.name,
      subtitle: Files.displayPath(file.parent, home),
      file: file
    }
  }

  // Files for this query: fd's names first, then LocalSearch's contents. While
  // a new search runs, the last results are narrowed to the new query, so
  // typing on never empties the list.
  function fileCandidates(q) {
    var out = []
    var seen = {}
    var now = Date.now()
    var lists = [fileResults, contentResults]
    for (var l = 0; l < lists.length; l++) {
      for (var i = 0; i < lists[l].length; i++) {
        var file = lists[l][i]
        if (seen[file.path]) continue
        seen[file.path] = true
        var meta = fileMeta[file.path]
        // LocalSearch finds folders too; `stat` says which they are.
        if (meta && meta.isDir && !file.isDir) {
          var folder = Files.describe(file.path, true, home)
          folder.fromContents = file.fromContents
          file = folder
        }
        var c = fileCandidate(file)
        // A match on what's inside only counts for the query it answered.
        c.score = Files.score(q, file, home, l === 1 && contentQuery === q)
        if (c.score <= 0) continue
        // Recently changed files are more likely what you're after.
        if (meta && meta.time) {
          var days = (now - meta.time) / 86400000
          if (days < 2) c.score += 25
          else if (days < 14) c.score += 12
        }
        out.push(c)
      }
    }
    return out
  }

  // ---- clipboard ------------------------------------------------------------------------------
  //
  // The Omarchy clipboard's own history (it skips anything a password manager
  // marks as secret). Shown only in the Clipboard view, never mixed into
  // search results.

  property var clipboardItems: []

  function readClipboard() {
    clipboardRun.start(filesCommand(["read", "clipboard"]))
  }

  Run {
    id: clipboardRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 8196 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight:", output)
      engine.loadClipboard(ok ? output : "[]")
    }
  }

  function loadClipboard(raw) {
    var parsed = []
    try { parsed = JSON.parse(String(raw || "[]")) } catch (e) { parsed = [] }
    var out = []
    for (var i = 0; Array.isArray(parsed) && i < parsed.length && out.length < 200; i++) {
      var item = parsed[i]
      if (!item || typeof item !== "object") continue
      if (item.type === "text" && typeof item.text === "string" && item.text.trim()) {
        out.push({ index: i, type: "text", text: item.text.slice(0, 4000) })
      } else if (item.type === "image" && typeof item.path === "string" && Files.goodPath(item.path)) {
        out.push({ index: i, type: "image", path: item.path, mime: String(item.mime || "image/png").slice(0, 64), when: String(item.capturedAt || "").slice(0, 40) })
      }
    }
    clipboardItems = out
    if (active && mode === "clipboard") rebuild(true)
  }

  // ---- what you've opened, and what you've searched -------------------------------------------

  property var history: Frecency.empty()
  // Your last searches, newest first, for ↑ in an empty field. Only while the
  // shell runs; nothing is written for them.
  property var pastQueries: []

  function rememberQuery(text) {
    var q = String(text || "").trim()
    if (!q || q.length > 200) return
    pastQueries = [q].concat(pastQueries.filter(function(p) { return p !== q })).slice(0, 30)
  }

  // Read once (and again if the folder changes); written a moment after
  // each change, one write at a time, by the helper: atomically, into a
  // folder only you can write to.
  function readHistory() {
    historyReadRun.replace(filesCommand(["history-read", stateDir]))
  }

  Run {
    id: historyReadRun
    okCodes: [0, 3]
    timeoutMs: 3000
    maxBytes: 4100 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight: history:", output)
      engine.history = ok ? Frecency.parse(output) : Frecency.empty()
      engine.historyLoaded = true
    }
  }

  property bool saveAgain: false

  function saveHistory() {
    historySave.restart()
  }

  function writeHistory() {
    if (historyWriteRun.running) {
      saveAgain = true
      return
    }
    historyWriteRun.start(filesCommand(["history-write", stateDir]), JSON.stringify(engine.history) + "\n")
  }

  Run {
    id: historyWriteRun
    timeoutMs: 5000
    maxBytes: 16 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight: saving history:", output)
      if (engine.saveAgain) {
        engine.saveAgain = false
        Qt.callLater(engine.writeHistory)
      }
    }
  }

  function remember(key) {
    rememberQuery(query)
    if (settings.learn === false || !key) return
    history = Frecency.record(history, key, query, Date.now())
    saveHistory()
  }

  // When a result was last opened (ms since 1970), or 0: for a style that
  // shows it (Split preview). By the result's own key, as activate() records it.
  function lastOpened(rowKey) {
    var c = candidates[rowKey]
    var key = c && c.key ? c.key : rowKey
    var items = history.items || {}
    return Object.prototype.hasOwnProperty.call(items, key) ? items[key].t : 0
  }

  function clearHistory() {
    var onboarded = history.flags && history.flags.onboarded
    history = Frecency.withFlag(Frecency.empty(), "onboarded", !!onboarded)
    pastQueries = []
    saveHistory()
  }

  // The welcome panel shows until you've seen it once.
  readonly property bool onboarded: !!(history.flags && history.flags.onboarded)
  property bool historyLoaded: false

  function finishOnboarding() {
    if (onboarded) return
    history = Frecency.withFlag(history, "onboarded", true)
    saveHistory()
  }

  Timer {
    id: historySave
    interval: 400
    onTriggered: engine.writeHistory()
  }

  // ---- building what the window shows -----------------------------------------------------------

  function searchCandidates(q) {
    var out = []
    function add(c, score) {
      var copy = {}
      for (var k in c) copy[k] = c[k]
      copy.score = score
      out.push(copy)
    }
    function scoreAll(list) {
      for (var i = 0; i < list.length; i++) {
        var c = list[i]
        var s = Match.best(q, c.fields)
        if (s > 0) add(c, Math.max(1, s - (c.penalty || 0)))
      }
    }
    if (mode === "all" || mode === "apps") scoreAll(appCategory ? apps.filter(function(a) { return a.category === appCategory }) : apps)
    if (mode === "all" || mode === "actions") {
      scoreAll(menuEntries)
      scoreAll(panelEntries)
      // "theme" lists every theme (yours first); "theme nord" finds Nord.
      var themeQuery = q.replace(/^themes?\s+/i, "")
      var allThemes = /^themes?$/i.test(q)
      for (var t = 0; t < themeEntries.length; t++) {
        var theme = themeEntries[t]
        var ts = allThemes ? (theme.checked ? 560 : 540) : Match.best(themeQuery, theme.fields)
        if (ts > 0) add(theme, ts)
      }
    }
    if (filesWanted) out = out.concat(fileCandidates(q))
    return out
  }

  function row(candidate, section, title) {
    return { key: candidate.key, section: section, sectionTitle: title || "", kind: "item", candidate: candidate }
  }

  // The keys you opened most recently, as candidates, from `lists`.
  function recentPicks(prefixes, lists, limit) {
    var byKey = Object.create(null)
    lists.forEach(function(list) { list.forEach(function(c) { byKey[c.key] = c }) })
    var keys = Object.keys(history.items || {}).filter(function(k) {
      return prefixes.some(function(p) { return k.indexOf(p) === 0 }) && byKey[k]
    })
    keys.sort(function(a, b) {
      var ia = history.items[a], ib = history.items[b]
      return (ib.n * 2 + ib.t / 8.64e7 * 0.2) - (ia.n * 2 + ia.t / 8.64e7 * 0.2)
    })
    return keys.slice(0, limit).map(function(k) { return byKey[k] })
  }

  // Browse views with nothing typed.
  function browseRows() {
    var rows = []
    if (mode === "apps") {
      // Your most used apps across the top, then all of them A–Z (or one
      // category's).
      var sorted = apps.slice().sort(function(a, b) {
        return a.title.toLowerCase().localeCompare(b.title.toLowerCase())
      })
      if (appCategory) {
        sorted.filter(function(c) { return c.category === appCategory }).forEach(function(c) { rows.push(row(c, "all")) })
      } else {
        recentPicks(["app:"], [apps], 5).forEach(function(c) { rows.push(row(c, "frequent")) })
        sorted.forEach(function(c) { rows.push({ key: "all:" + c.key, section: "all", sectionTitle: "", kind: "item", candidate: c }) })
      }
    } else if (mode === "files") {
      var recentKeys = {}
      recentPicks(["file:"], [recentFiles.map(fileCandidate)], 5).forEach(function(c) {
        recentKeys[c.key] = true
        rows.push(row(c, "suggestions", "Suggestions"))
      })
      recentFiles.forEach(function(file) {
        var c = fileCandidate(file)
        rows.push({ key: "recent:" + c.key, section: "recents", sectionTitle: "Recents", kind: "item", candidate: c })
      })
    } else if (mode === "actions") {
      var menuish = menuEntries.concat(panelEntries, themeEntries)
      recentPicks(["omarchy:", "panel:", "theme:"], [menuish], 5).forEach(function(c) {
        rows.push({ key: "suggested:" + c.key, section: "suggestions", sectionTitle: "Suggestions", kind: "item", candidate: c })
      })
      panelEntries.forEach(function(c) { rows.push(row(c, "panels", "Top Bar")) })
      // Grouped by the menu they're in (Style, Setup, Install...), in the
      // Omarchy menu's own order; actions on the menu's first level go first.
      var groups = []
      var byTop = Object.create(null)
      menuEntries.forEach(function(c) {
        var top = c.subtitle ? c.subtitle.split(" › ")[0] : ""
        if (!top && c.submenu) return
        var id = top || "Omarchy"
        if (!byTop[id]) {
          byTop[id] = []
          if (top) groups.push(id)
          else groups.unshift(id)
        }
        byTop[id].push(c)
      })
      groups.forEach(function(id) {
        byTop[id].forEach(function(c) { rows.push(row(c, "menu:" + id, id)) })
      })
    }
    return rows
  }

  // An item's identity, whatever its place in the history.
  function clipId(item) {
    return Qt.md5(item.type + "\n" + (item.type === "text" ? item.text : item.path))
  }

  // Where the item is in the history now: a copy made while the Clipboard
  // view was open moves everything down one.
  function clipboardIndex(item) {
    var id = clipId(item)
    for (var i = 0; i < clipboardItems.length; i++) {
      if (clipId(clipboardItems[i]) === id) return clipboardItems[i].index
    }
    return -1
  }

  function clipboardRows(q) {
    var rows = []
    var keys = {}
    var needle = Match.fold(q).trim()
    for (var i = 0; i < clipboardItems.length; i++) {
      var item = clipboardItems[i]
      var text = item.type === "text" ? item.text : ""
      if (needle && (item.type !== "text" || Match.fold(text).indexOf(needle) < 0)) continue
      var isUrl = item.type === "text" && /^https?:\/\/\S+$/.test(text.trim())
      var id = clipId(item)
      if (keys[id]) continue
      keys[id] = true
      var c = {
        key: "clip:" + id,
        source: "clipboard",
        clip: item,
        url: isUrl,
        title: item.type === "text" ? text.replace(/\s+/g, " ").trim().slice(0, 300) : "Image",
        subtitle: item.type === "image" ? "Image" + (item.when ? " · Copied " + item.when : "")
          : isUrl ? "URL · " + text.trim().replace(/^https?:\/\//, "").split("/")[0]
          : "Text · " + text.length + (text.length === 1 ? " character" : " characters")
      }
      rows.push(row(c, "clipboard"))
    }
    return rows
  }

  // `keepTop`: slower results for the same query arrived; don't move the Top Hit.
  function rebuild(keepTop) {
    var q = query.trim()
    var built = null
    if (mode === "clipboard") {
      built = { rows: settings.clipboard === false ? [] : clipboardRows(q), top: "", kinds: [] }
    } else if (!q && mode !== "all") {
      built = { rows: browseRows(), top: "", kinds: [] }
    } else if (!q) {
      built = { rows: [], top: "", kinds: [] }
    } else if (mode === "all" && !scope && q.charAt(0) === "/") {
      // "/pdf": pick a kind to search, from the chips (Return takes the first).
      built = { rows: [], top: "", kinds: Rank.kindsFor(q.slice(1)).filter(function(k) {
        return Settings.enabledSections(settings)[k.id] !== false
      }) }
    } else {
      var answer = mode === "all" && !scope && settings.calculator !== false ? Calc.answer(q) : null
      built = (grouped ? Rank.grouped : Rank.flat)({
        query: q,
        candidates: searchCandidates(q),
        answer: answer,
        web: mode === "all" && settings.web !== false,
        history: history,
        now: Date.now(),
        learn: settings.learn !== false,
        pinnedTop: keepTop ? topKey : "",
        enabled: Settings.enabledSections(settings),
        scope: scope,
        perKind: mode === "all" ? 6 : 60
      })
    }
    var byKey = {}
    var display = []
    for (var i = 0; i < built.rows.length; i++) {
      var r = built.rows[i]
      if (r.candidate) byKey[r.key] = r.candidate
      else if (r.kind === "answer") byKey[r.key] = { source: "answer", answer: r.answer, title: r.answer.text }
      else if (r.kind === "web") byKey[r.key] = webCandidate(q)
      display.push(displayRow(r, byKey[r.key], i === 0 && built.top === r.key))
    }
    candidates = byKey
    topKey = built.top
    kinds = built.kinds || []
    rows = display
    rowsVersion++
  }

  function webCandidate(q) {
    var address = Web.addressUrl(q)
    var engineId = settings.webEngine || "google"
    return {
      source: "web",
      url: address || Web.searchUrl(engineId, q),
      address: !!address,
      title: address ? "Open “" + q + "”" : "Search the Web for “" + q + "”",
      subtitle: address ? "Website" : Web.engine(engineId).name
    }
  }

  // ---- rows for the window --------------------------------------------------------------------------

  function iconPath(names) {
    for (var i = 0; i < names.length; i++) {
      var found = Quickshell.iconPath(names[i], true)
      if (found) return found
    }
    return ""
  }

  function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
  }

  // "21.7 MB", like Finder (1 KB = 1000 bytes).
  function sizeText(bytes) {
    if (!(bytes >= 0)) return ""
    if (bytes < 1000) return bytes + (bytes === 1 ? " byte" : " bytes")
    var units = ["KB", "MB", "GB", "TB"]
    var value = bytes
    var unit = -1
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000
      unit++
    }
    return (value >= 100 ? Math.round(value) : Math.round(value * 10) / 10) + " " + units[unit]
  }

  // Times read like the clock in your top bar: 24-hour if it is.
  readonly property bool clock24: {
    var localeDefault = !/a/i.test(Qt.locale().timeFormat(Locale.ShortFormat))
    var layout = barConfig && barConfig.layout ? barConfig.layout : {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (!entry || entry.id !== "omarchy.clock" || typeof entry.format !== "string") continue
        if (/H/.test(entry.format)) return true
        if (/h/.test(entry.format)) return false
      }
    }
    return localeDefault
  }

  // "Today, 9:32", "Yesterday, 19:21", "Tuesday, 14:05", "Sep 12", "Sep 12, 2024".
  function whenText(ms) {
    if (!ms) return ""
    var date = new Date(ms)
    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    var time = Qt.formatTime(date, clock24 ? "HH:mm" : "h:mm AP")
    if (ms >= today) return "Today, " + time
    if (ms >= today - 86400000) return "Yesterday, " + time
    if (ms >= today - 6 * 86400000) return Qt.locale().dayName(date.getDay(), Locale.LongFormat) + ", " + time
    if (date.getFullYear() === now.getFullYear()) return Qt.formatDate(date, "MMM d")
    return Qt.formatDate(date, "MMM d, yyyy")
  }

  // "~/projects/omarchy" → "~ › projects › omarchy", shown while Ctrl is held.
  function pathText(path) {
    return Files.displayPath(path, home).split("/").filter(function(p) { return p }).join(" › ") || "/"
  }

  function displayRow(r, c, isTop) {
    var row = {
      key: r.key, section: r.section, sectionTitle: r.sectionTitle || "", kind: r.kind,
      source: c ? String(c.source || "") : "",
      title: "", subtitle: "", folder: "", path: "", detail: "",
      iconType: "badge", iconSource: "", glyph: "", glyphFont: "", badge: "#8e8e93", symbol: "",
      thumbs: "", checked: false, isTop: !!isTop, action: "Open", copyable: false
    }
    if (!c) return row
    row.title = String(c.title || "")
    if (c.source === "answer") {
      var convert = c.answer.kind === "convert"
      row.symbol = convert ? "convert" : "calculator"
      row.badge = convert ? "#5e5ce6" : "#ff9f0a"
      row.title = c.answer.text
      row.subtitle = convert ? c.answer.expression + " =" : c.answer.expression + " ="
      row.detail = convert ? c.answer.dimension : "Calculator"
      row.action = "Copy"
      row.copyable = true
    } else if (c.source === "web") {
      row.symbol = c.address ? "compass" : "globe"
      row.badge = "#0a84ff"
      row.subtitle = c.subtitle
      row.action = c.address ? "Open" : "Search"
    } else if (c.source === "app") {
      row.iconType = "image"
      row.iconSource = appIcon(c.icon)
    } else if (c.source === "omarchy") {
      row.glyph = c.icon || ""
      row.glyphFont = c.iconFont || ""
      row.badge = c.color
      row.checked = !!c.checked
      row.subtitle = "Omarchy" + (c.subtitle ? " · " + c.subtitle : "")
      row.action = c.submenu ? "Open" : "Run"
    } else if (c.source === "panel") {
      row.symbol = c.glyph
      row.badge = c.color
      row.subtitle = "Omarchy · Top bar"
    } else if (c.source === "theme") {
      row.iconType = "thumb"
      row.iconSource = fileUrl(c.preview)
      row.checked = !!c.checked
      row.subtitle = c.checked ? "Omarchy theme · Current" : "Omarchy theme"
      row.action = "Apply"
    } else if (c.source === "file") {
      var file = c.file
      var meta = fileMeta[file.path]
      row.iconType = "file"
      row.iconSource = iconPath(file.icons)
      row.thumbs = thumbnailUrls(file).join("|")
      var parts = [file.kind]
      if (meta && !file.isDir) parts.push(sizeText(meta.size))
      if (meta) parts.push(whenText(meta.time))
      row.subtitle = parts.filter(function(p) { return p }).join(" · ")
      row.folder = file.parent === home ? "Home" : file.parent.split("/").pop()
      row.path = pathText(file.parent)
    } else if (c.source === "clipboard") {
      if (c.clip.type === "image") {
        row.iconType = "thumb"
        row.iconSource = fileUrl(c.clip.path)
      } else {
        row.symbol = c.url ? "globe" : "text"
        row.badge = c.url ? "#0a84ff" : "#8e8e93"
      }
      row.subtitle = c.subtitle
      row.action = "Paste"
      row.copyable = true
    }
    return row
  }

  // Pictures to try for a file, in order: thumbnails Files already made (the
  // freedesktop thumbnail cache), then, for an image, the image itself. The
  // window shows the first that loads, else the file's icon.
  function thumbnailUrls(file) {
    if (file.isDir || !previewable(file)) return []
    var hash = Qt.md5(Files.thumbnailUri(file.path))
    var out = []
    for (var i = 0; i < thumbSizes.length; i++) {
      if (thumbnailIndex[thumbSizes[i] + "/" + hash]) out.push(fileUrl(thumbDir + thumbSizes[i] + "/" + hash + ".png"))
    }
    if (Files.isImage(file) && file.ext !== "svg") out.push(fileUrl(file.path))
    return out
  }

  Component.onCompleted: {
    scanHiddenApps()
    readLauncherHides()
    readMenus()
    rebuildApps()
    refreshThemes()
    // After whoever made the engine has set its state folder (the harness).
    Qt.callLater(engine.readHistory)
  }
}
