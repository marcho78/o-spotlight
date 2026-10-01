import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Defaults.js" as Defaults
import "Settings.js" as Settings
import "Files.js" as Files
import "Web.js" as Web
import "Palette.js" as Palette
import "Styles.js" as Styles

// O-Spotlight: search everything on Omarchy, like Spotlight on a Mac.
//
// This service is the engine room. It keeps O-Spotlight's shortcut registered
// with Hyprland (hypr/o-spotlight.lua, run with `hyprctl eval`), runs the
// search engine (Engine.qml), carries out what you pick, and holds the
// settings. Spotlight.qml draws the search window; BarWidget.qml is the icon
// in the top bar; SettingsWindow.qml is the settings window.
//
//   omarchy-shell o-spotlight toggle
//   omarchy-shell o-spotlight search "some text"
//   omarchy-shell o-spotlight settings
Item {
  id: root

  // ---- host injection ------------------------------------------------------------

  property var shell: null
  property var manifest: null

  // The development harness turns Hyprland registration off.
  property bool hyprIntegration: true

  readonly property string pluginId: "marcho78.o-spotlight"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string home: Quickshell.env("HOME")

  // ---- settings ----------------------------------------------------------------------
  //
  // Kept inline on O-Spotlight's own shell.json entry (only what differs from
  // Defaults.js): the shell writes the entry (updateEntryInline) and hands
  // plugins a copy of the bar configuration it lives in (barConfig).

  readonly property var defaults: Defaults.DEFAULTS
  readonly property var schema: Defaults.SCHEMA
  property var user: ({})
  readonly property var settings: Settings.merge(defaults, user, schema)
  readonly property color highlight: Settings.highlightColor(settings, String(Color.accent))

  // The look (Styles.js), and the colors of every look but Tahoe's glass
  // (Palette.js): your Omarchy theme's, or the ones you picked.
  readonly property var styleInfo: Styles.info(settings.style)
  readonly property var themePalette: Palette.build({ bg: String(Color.background), fg: String(Color.foreground), accent: String(Color.accent) })
  readonly property var stylePalette: settings.colors === "custom"
    ? Palette.build({ bg: settings.customBackground, surface: settings.customSurface, fg: settings.customText, muted: settings.customMuted, accent: settings.customAccent })
    : themePalette

  // Light or dark glass: the theme's, unless the settings pick one.
  readonly property bool dark: settings.appearance === "dark" ? true
    : settings.appearance === "light" ? false
    : (0.2126 * Color.background.r + 0.7152 * Color.background.g + 0.0722 * Color.background.b) < 0.5

  // The macOS system font when it's installed, else the closest there is:
  // Inter, or Adwaita Sans (GNOME's Inter-based UI font).
  readonly property string uiFont: {
    var families = Qt.fontFamilies()
    var wanted = ["SF Pro Display", "SF Pro Text", "SF Pro", "Inter Display", "Inter", "Adwaita Sans", "Cantarell", "Noto Sans", "Liberation Sans"]
    for (var i = 0; i < wanted.length; i++) {
      if (families.indexOf(wanted[i]) >= 0) return wanted[i]
    }
    return "sans-serif"
  }

  // While the shell saves an entry it hands plugins a copy of its
  // configuration from just before the save; a copy that still shows the entry
  // as it was must not undo O-Spotlight's own save.
  property bool saving: false
  property string entryBeforeSave: ""

  function loadEntry() {
    if (saving || persistTimer.running) return
    var entry = Settings.entryInBar(shell ? shell.barConfig : null, pluginId)
    if (entryBeforeSave !== "" && JSON.stringify(entry) === entryBeforeSave) return
    entryBeforeSave = ""
    user = entry
  }

  onShellChanged: loadEntry()

  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onBarConfigChanged() { root.loadEntry() }
  }

  function setSetting(key, value) {
    if (!defaults || defaults[key] === undefined) return
    var next = Settings.clone(user)
    next[key] = value
    user = Settings.overrides(defaults, Settings.merge(defaults, next, schema))
    persistTimer.restart()
  }

  function resetSettings() {
    user = ({})
    persistTimer.restart()
  }

  Timer {
    id: persistTimer
    interval: 300
    onTriggered: {
      if (!root.shell || typeof root.shell.updateEntryInline !== "function") return
      root.entryBeforeSave = JSON.stringify(Settings.entryInBar(root.shell.barConfig, root.pluginId))
      root.saving = true
      try {
        root.shell.updateEntryInline(root.pluginId, Settings.clone(root.user))
      } finally {
        root.saving = false
      }
    }
  }

  // ---- Hyprland registration ----------------------------------------------------------
  //
  // The shortcut is registered at runtime; your Hyprland config is never
  // edited. A config reload clears it, so it's registered again on every
  // `configreloaded` event. A shortcut some other binding already uses is left
  // alone, and the settings window says which.

  property string hyprStatus: ""
  property var takenBinds: []
  property bool registering: false
  property bool registerAgain: false
  property int bindReadRetries: 0

  readonly property string registrationKey: JSON.stringify([settings.shortcut])
  onRegistrationKeyChanged: scheduleRegister()

  function scheduleRegister() {
    bindReadRetries = 0
    if (hyprIntegration) registerTimer.restart()
  }

  Timer {
    id: registerTimer
    // Long enough for a hot-reloaded predecessor's cleanup to land first.
    interval: 350
    onTriggered: root.register()
  }

  Timer {
    id: bindRetryTimer
    interval: 3000
    onTriggered: root.register()
  }

  function register() {
    if (registering) {
      registerAgain = true
      return
    }
    registering = true
    bindsRun.start(["/usr/bin/hyprctl", "-j", "binds"])
  }

  Run {
    id: bindsRun
    maxBytes: 512 * 1024
    timeoutMs: 4000
    onFinished: function(ok, output) {
      var existing = null
      if (ok) {
        try { existing = JSON.parse(output) } catch (e) { existing = null }
      }
      if (Array.isArray(existing)) root.bindReadRetries = 0
      else if (root.bindReadRetries < 3) {
        root.bindReadRetries++
        bindRetryTimer.restart()
      }
      var checked = Settings.checkBinds(Settings.wantedBinds(root.settings), existing)
      root.takenBinds = checked.taken
      registerRun.start(["/usr/bin/hyprctl", "eval",
        Settings.hyprRegistration(root.pluginDir + "/hypr/o-spotlight.lua", Settings.hyprOptions(checked.free))])
    }
  }

  Run {
    id: registerRun
    maxBytes: 16 * 1024
    timeoutMs: 4000
    onFinished: function(ok, output) {
      // hypr/o-spotlight.lua raises what didn't register; hyprctl prints it as "error: …".
      var text = String(output || "").trim().replace(/^error:\s*/i, "")
      root.hyprStatus = ok && (text === "" || text === "ok") ? "ok" : (text.slice(0, 600) || "Hyprland didn't answer")
      if (root.hyprStatus !== "ok") console.warn("O-Spotlight: registering with Hyprland:", root.hyprStatus)
      root.registering = false
      if (root.registerAgain) {
        root.registerAgain = false
        root.register()
      }
    }
  }

  // Take the shortcut and rules back out of Hyprland when the plugin is
  // disabled or reloaded. A reloaded copy registers again right after.
  Component.onDestruction: {
    if (hyprIntegration)
      Quickshell.execDetached(["/usr/bin/hyprctl", "eval",
        Settings.hyprRegistration(pluginDir + "/hypr/o-spotlight.lua", { remove: true })])
  }

  Connections {
    target: Hyprland
    enabled: root.hyprIntegration
    function onRawEvent(event) {
      var name = event.name
      if (name === "custom") {
        var parsed = Settings.parseEvent(event.data)
        if (parsed && parsed.command === "toggle") root.toggle({})
      } else if (name === "configreloaded") {
        root.scheduleRegister()
      } else if (root.windowOpen && (name === "workspacev2" || name === "focusedmonv2")) {
        // Moving to another desktop or display leaves the search, as on a Mac.
        root.hide()
      }
    }
  }

  // ---- the window --------------------------------------------------------------------------
  //
  // Opening and closing go through the Omarchy shell (summon/hide/toggle), so
  // `omarchy-shell shell toggle marcho78.o-spotlight` and the shortcut agree.

  property var ui: null
  readonly property bool windowOpen: !!ui && ui.opened === true

  function attachUi(item) { ui = item }
  function detachUi(item) { if (ui === item) ui = null }

  function toggle(payload) {
    if (shell && typeof shell.toggle === "function") shell.toggle(pluginId, JSON.stringify(payload || {}))
    else if (ui) ui.opened ? ui.close() : ui.open(JSON.stringify(payload || {}))
  }

  function show(payload) {
    if (shell && typeof shell.summon === "function") shell.summon(pluginId, JSON.stringify(payload || {}))
    else if (ui) ui.open(JSON.stringify(payload || {}))
  }

  function hide() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else if (ui) ui.close()
  }

  // ---- search ---------------------------------------------------------------------------------

  Engine {
    id: engineItem
    barConfig: root.shell ? root.shell.barConfig : null
    settings: root.settings
    home: root.home
    active: root.windowOpen
    grouped: root.styleInfo.grouped === true
  }

  property alias engine: engineItem

  // ---- picking a result ------------------------------------------------------------------------
  //
  // how: "open" (Return or a click), "reveal" (Ctrl+Return: show in Files),
  // "copy" (Ctrl+C). Returns what the window should do: "close", "stay" or
  // "" when the result can't do that.

  function activate(key, how) {
    var c = engine.candidates[key]
    if (!c) return ""
    // Browse views show a result twice at most (most used, and A–Z); both
    // count as the same thing for what O-Spotlight learns.
    key = c.key || key
    how = how || "open"

    if (c.source === "answer") {
      copyText(c.answer.copy)
      if (how === "copy") return "stay"
      osd("󰅍", "Copied " + c.answer.text)
      return "close"
    }
    if (c.source === "web") {
      if (how !== "open" || !/^https?:\/\//.test(c.url)) return ""
      launch(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", c.url])
      return "close"
    }
    if (c.source === "file") {
      var path = c.file.path
      if (!Files.goodPath(path)) return ""
      if (how === "copy") {
        copyText(path)
        return "stay"
      }
      engine.remember(key)
      if (how === "reveal") reveal(path)
      else launch(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", path])
      return "close"
    }
    if (how === "copy" && c.source !== "clipboard") {
      copyText(c.title)
      return "stay"
    }
    if (how === "reveal") return ""

    if (c.source === "app") {
      if (!/^[^\u0000-\u001f\/]{1,250}$/.test(c.appId)) return ""
      engine.remember(key)
      launchApp(c.appId, c.title)
      return "close"
    }
    if (c.source === "omarchy") {
      if (!/^[A-Za-z0-9._-]{1,200}$/.test(c.route)) return ""
      engine.remember(key)
      // The Omarchy menu opens the submenu, or runs the action, itself.
      later(["/usr/bin/omarchy", "menu", "summon", c.route])
      return "close"
    }
    if (c.source === "panel") {
      if (!/^omarchy\.[a-z-]{1,40}$/.test(c.plugin)) return ""
      engine.remember(key)
      later(["/usr/bin/omarchy-shell", "shell", "summon", c.plugin, "{}"])
      return "close"
    }
    if (c.source === "theme") {
      if (!/^[A-Za-z0-9._ -]{1,64}$/.test(c.name)) return ""
      engine.remember(key)
      launch(["/usr/bin/omarchy", "theme", "set", c.name])
      return "close"
    }
    if (c.source === "clipboard") {
      var clip = c.clip
      // An image goes by its file. Pasted into the window you came from, once
      // the search is out of the way.
      if (clip.type === "image") {
        if (how === "copy") {
          Quickshell.execDetached(["/usr/bin/omarchy-clipboard-paste-file", "--copy-only", clip.mime, clip.path])
          engine.clipboardCopied()
          return "stay"
        }
        later(["/usr/bin/omarchy-clipboard-paste-file", clip.mime, clip.path])
        return "close"
      }
      // Text goes by its place in the history, which every copy since the
      // view was read has moved: read the history afresh and find the item
      // in it, right before Omarchy's paste reads it too. (For a paste, that's
      // once the search has let go of the keyboard.)
      var withIndex = function(run) {
        engine.withFreshClipboard(function(ok) {
          var index = ok ? engine.clipboardIndex(clip) : -1
          if (index < 0) root.osd("󰅍", "No longer in your clipboard history")
          else run(String(index))
        })
      }
      if (how === "copy") {
        withIndex(function(index) {
          Quickshell.execDetached(["/usr/bin/omarchy-clipboard-paste-text", "--copy-only", "--history-index", index])
          engine.clipboardCopied()
        })
        return "stay"
      }
      later(function() {
        withIndex(function(index) {
          Quickshell.execDetached(["/usr/bin/omarchy-clipboard-paste-text", "--shift-insert", "--history-index", index])
        })
      })
      return "close"
    }
    return ""
  }

  // Ctrl+B: the query, straight to the web.
  function searchWeb(text) {
    var q = String(text || "").trim()
    if (!q) return false
    launch(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", Web.searchUrl(settings.webEngine, q)])
    engine.rememberQuery(q)
    return true
  }

  // Like the Omarchy launcher: in its own scope under app-graphical.slice
  // (uwsm-app), resolved by gtk-launch, with "Launching…" on screen if no
  // window has appeared after two seconds.
  function launchApp(appId, name) {
    launchFeedback.begin(name)
    Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/gtk-launch", appId + ".desktop"])
  }

  LaunchFeedback { id: launchFeedback }

  function launch(argv) {
    Quickshell.execDetached(argv)
  }

  // After the window has let go of the keyboard, so what runs lands in the
  // window underneath (a paste) or opens on top (the Omarchy menu). `what`
  // is a command (an argument list) or a function.
  property var laterQueue: []

  function later(what) {
    laterQueue = laterQueue.concat([what])
    laterTimer.restart()
  }

  Timer {
    id: laterTimer
    interval: 160
    onTriggered: {
      var queue = root.laterQueue
      root.laterQueue = []
      queue.forEach(function(what) {
        if (typeof what === "function") what()
        else Quickshell.execDetached(what)
      })
    }
  }

  // On wl-copy's stdin, as Omarchy's own clipboard does it: as an argument,
  // the text would sit in wl-copy's command line, where any account on the
  // computer can read it, for as long as it holds the clipboard.
  function copyText(text) {
    var value = String(text || "")
    if (!value || value.length > 100000) return
    if (!copyRun.start(["/usr/bin/wl-copy"], value)) copyRun.next = value
  }

  Run {
    id: copyRun
    // Copied while the last copy was still being handed over: goes next.
    property string next: ""
    timeoutMs: 3000
    maxBytes: 16 * 1024
    onFinished: function(ok, output) {
      if (!ok) console.warn("O-Spotlight: copying:", output)
      var value = copyRun.next
      copyRun.next = ""
      if (value) Qt.callLater(function() { root.copyText(value) })
    }
  }

  function reveal(path) {
    Quickshell.execDetached(["/usr/bin/gdbus", "call", "--session",
      "--dest", "org.freedesktop.FileManager1",
      "--object-path", "/org/freedesktop/FileManager1",
      "--method", "org.freedesktop.FileManager1.ShowItems",
      "['" + Files.fileUri(path) + "']", ""])
  }

  function osd(icon, message) {
    Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "show",
      JSON.stringify({ icon: icon, message: String(message).slice(0, 120), duration: 1400 })])
  }

  // ---- wallpaper (for the settings window's preview) ------------------------------------------

  property string wallpaper: ""
  // Shown once checked like every other picture (Engine.qml, Pictures).
  readonly property string wallpaperUrl: wallpaper ? engineItem.pictureUrl(wallpaper, engineItem.pictureCap) : ""

  Run {
    id: wallpaperRun
    maxBytes: 8 * 1024
    timeoutMs: 2000
    splitMarker: "\n"
    onFinished: function(ok, output) {
      var path = String(output || "").trim()
      if (ok && /^\/[^\u0000-\u001f\u007f]{1,4000}$/.test(path)) {
        root.wallpaper = path
        engineItem.askPictures([path])
      }
    }
  }

  function refreshWallpaper() {
    wallpaperRun.start(["/usr/bin/readlink", "-f", "--", home + "/.local/state/omarchy/current/background"])
  }

  // ---- settings window -------------------------------------------------------------------------

  property string settingsPage: ""

  Loader {
    id: settingsLoader
    active: false
    source: "SettingsWindow.qml"
    onLoaded: {
      item.service = root
      item.page = root.settingsPage || "general"
      item.visible = true
    }
  }

  function openSettings(page) {
    refreshWallpaper()
    settingsPage = page || ""
    if (windowOpen) hide()
    if (settingsLoader.item) {
      if (page) settingsLoader.item.page = page
      settingsLoader.item.visible = true
      Quickshell.execDetached(["/usr/bin/hyprctl", "dispatch", 'hl.dsp.focus({ window = "title:^O-Spotlight Settings$" })'])
    } else {
      settingsLoader.active = true
    }
  }

  function settingsClosed() {
    settingsLoader.active = false
  }

  // ---- IPC --------------------------------------------------------------------------------------

  IpcHandler {
    target: "o-spotlight"

    function toggle(): void { root.toggle({}) }
    function show(): void { if (!root.windowOpen) root.show({}) }
    function hide(): void { root.hide() }
    function search(text: string): void { root.show({ query: String(text || "").slice(0, 500) }) }
    function browse(view: string): void { root.show({ mode: String(view || "all").slice(0, 32) }) }
    function settings(): void { root.openSettings("") }
    // omarchy-shell o-spotlight set glass frosted   (values are checked like the settings window's)
    function set(key: string, value: string): string {
      key = String(key || "")
      value = String(value || "")
      if (!root.defaults || !Object.prototype.hasOwnProperty.call(root.defaults, key)) return "unknown setting"
      if (value.length > 64 * 1024) return "too long"
      var parsed = value
      if (value === "true" || value === "false") parsed = value === "true"
      else if (/^-?\d{1,6}$/.test(value)) parsed = Number(value)
      else if (/^\[.*\]$/.test(value)) { try { parsed = JSON.parse(value) } catch (e) { return "bad list" } }
      root.setSetting(key, parsed)
      return JSON.stringify(root.settings[key])
    }
    function reset(): void { root.resetSettings() }
    function status(): string {
      return JSON.stringify({
        open: root.windowOpen,
        hyprland: root.hyprStatus,
        takenShortcuts: root.takenBinds,
        apps: root.engine.apps.length,
        connected: !!root.shell,
        mode: root.engine.mode,
        typing: !!root.ui && root.ui.typing,
        selected: root.ui ? root.ui.selectedIndex : -1,
        rows: root.engine.rows.length,
        omarchy: root.engine.menuEntries.length,
        themes: root.engine.themeEntries.length,
        contentSearch: root.engine.localSearchAvailable,
        style: root.styleInfo.id
      })
    }
  }

  Component.onCompleted: scheduleRegister()
}
