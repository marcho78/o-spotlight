import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Commons
import "Styles.js" as Styles
import "Palette.js" as Palette
// Unused here: the styles are loaded by file below, but Quickshell only
// indexes a folder of QML that some file imports.
import "styles" as Looks

// The search window, the way Spotlight looks in macOS Tahoe: a Liquid Glass
// capsule high on the focused display that grows downward into the results as
// you type, one piece of glass. With nothing typed, four round buttons can
// spring out of it: Applications, Files, Actions and Clipboard.
//
// It's a full-screen layer, clear except for the glass, so a click anywhere
// else closes it. The Omarchy shell loads this once and keeps it
// (keepLoaded), opens it with open(), closes it with close(), and reads
// `opened` to know which. Everything it shows comes from the service's
// search engine (Engine.qml).
//
// That's the Tahoe style, drawn here. The other styles (Styles.js) are files
// in styles/ that draw this same search their own way: the field, the rows,
// the keyboard and opening results all stay here.
Item {
  id: root

  // ---- host injection ------------------------------------------------------------

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var service: null

  readonly property string pluginId: "marcho78.o-spotlight"

  // The development harness: the window sits under your windows, takes no
  // input and refracts the wallpaper instead of a picture of the screen.
  property bool testMode: false
  property string testBackdrop: ""
  // The harness shows the wallpaper behind the window, for screenshots.
  property bool showTestBackdrop: false
  // The search as it's drawn, whichever the style.
  readonly property Item card: !tahoe && skin && skin.card ? skin.card : group
  readonly property alias stageItem: stage
  readonly property string fieldText: field.text
  // The search field has the keyboard (for `status`).
  readonly property bool typing: field.activeFocus

  // ---- state -------------------------------------------------------------------------

  property bool opened: false
  property bool closing: false
  property bool revealed: false
  property int selectedIndex: -1
  // Ctrl held: rows show where files are instead of what they are.
  property bool showPaths: false
  // The browse buttons: out when the pointer moves, after a pause with
  // nothing typed, or right away when opened from the top bar.
  property bool buttonsWanted: false
  property string hoveredMode: ""
  property bool resetSelection: true
  property var topInfo: null
  property int historyIndex: -1
  property string lastQuery: ""
  property real lastClosedAt: 0

  readonly property var engine: service ? service.engine : null
  readonly property var settings: service ? service.settings : ({})
  readonly property bool dark: service ? service.dark : true
  readonly property color highlight: service ? service.highlight : "#0a84ff"
  readonly property string uiFont: service ? service.uiFont : "sans-serif"
  readonly property string glyphFont: Style.font.menuFamily
  readonly property string glassStyle: settings.glass || "liquid"
  readonly property bool reduceMotion: settings.reduceMotion === true
  readonly property string mode: engine ? engine.mode : "all"
  readonly property string scope: engine ? engine.scope : ""
  readonly property string query: engine ? engine.query : ""
  // The look (Styles.js). Tahoe is drawn below; another style is loaded
  // from styles/, in the colors of Palette.js (your theme's, or yours).
  readonly property var styleInfo: Styles.info(settings.style)
  readonly property string styleId: styleInfo.id
  readonly property bool tahoe: styleId === "tahoe"
  readonly property Item skin: skinLoader.item as Item
  readonly property var pal: service ? service.stylePalette : Palette.build({})
  readonly property string monoFont: Style.font.family
  // The search field of the style showing.
  readonly property Item field: !tahoe && skin && skin.field ? skin.field : tahoeField
  readonly property alias resultsModel: rowsModel
  // The blurred picture of the screen, for the styles that show it through.
  readonly property Item backdrop: glassSource
  // A popup that's open ("view": grid or list; "scope": a style's own menu);
  // Esc closes it first.
  property string popup: ""
  // A picture of the screen behind the search: for glass, and the styles
  // that blur.
  readonly property bool needsBackdrop: tahoe ? glassStyle !== "solid" : styleInfo.blur === true

  readonly property bool gridView: (tahoe || styleInfo.grid === true) && (
    (mode === "apps" && settings.appsView !== "list")
    || (mode === "files" && query.trim() === "" && settings.filesView !== "list")
    // Tiles: search results as a grid, the Top Hit as a card.
    || (styleInfo.heroGrid === true && mode === "all" && query.trim() !== ""))

  // ---- colors ------------------------------------------------------------------------

  readonly property color textPrimary: dark ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0, 0, 0, 0.85)
  readonly property color textSecondary: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.46)
  readonly property color textTertiary: dark ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(0, 0, 0, 0.30)
  readonly property color hairline: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
  readonly property color controlFill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
  readonly property color controlHover: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.11)
  readonly property color chipFill: dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.78)
  readonly property color chipHover: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.95)
  readonly property color pillFill: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.72)

  // The selection is a neutral tint, as in Tahoe; the accent color if the
  // settings ask for the older look, with text that stays readable on it.
  readonly property bool accentSelection: settings.selection === "accent"
  readonly property color selectionColor: accentSelection ? highlight : (dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10))
  readonly property real highlightLuma: 0.2126 * highlight.r + 0.7152 * highlight.g + 0.0722 * highlight.b

  function rowText(selected) {
    if (selected && accentSelection) return highlightLuma > 0.6 ? Qt.rgba(0, 0, 0, 0.88) : "white"
    return textPrimary
  }

  function rowSubtext(selected) {
    if (selected && accentSelection) return highlightLuma > 0.6 ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.78)
    return textSecondary
  }

  // ---- geometry (Tahoe's, in logical pixels) --------------------------------------------

  readonly property int fullWidth: 640
  readonly property int barHeight: 56
  readonly property int buttonSize: 54
  readonly property int buttonGap: 10
  readonly property bool collapsedMain: mode === "all" && query === "" && scope === ""
  // The first time it opens, a short welcome under the field (as in Tahoe).
  readonly property bool showOnboarding: opened && !!engine && engine.historyLoaded && !engine.onboarded && collapsedMain
  readonly property bool buttonsShown: opened && !closing && collapsedMain && buttonsWanted && !showOnboarding
  readonly property int barWidth: buttonsShown ? fullWidth - modes.length * (buttonSize + buttonGap) : fullWidth
  readonly property int maxHeight: mode === "all" ? 466 : 546

  readonly property var allModes: [
    { id: "apps", label: "Applications", icon: "appstore", key: "1" },
    { id: "files", label: "Files", icon: "folder", key: "2" },
    { id: "actions", label: "Actions", icon: "layers", key: "3" },
    { id: "clipboard", label: "Clipboard", icon: "copy", key: "4" }
  ]
  readonly property var modes: allModes.filter(function(m) {
    return (m.id !== "clipboard" || settings.clipboard !== false) && (m.id !== "files" || settings.files !== false)
  })

  function modeInfo(id) {
    for (var i = 0; i < allModes.length; i++) if (allModes[i].id === id) return allModes[i]
    return null
  }

  // What picking the Top Hit does, for the completion: "— Open", "— Run".
  function actionOf(row) {
    return row && row.action ? row.action : "Open"
  }

  // The Top Hit completing what you typed: "chr" then "omium — Open"; or, when
  // its name doesn't start with what you typed, "— Beach Dusk.png".
  readonly property bool completionShown: !!topInfo && field.text !== "" && topInfo.kind !== "answer"
    && field.cursorPosition === field.text.length && field.selectedText === "" && mode === "all"
  readonly property bool completionPrefix: !!topInfo && field.text !== ""
    && topInfo.title.toLowerCase().indexOf(field.text.toLowerCase()) === 0
  readonly property string completionRemainder: completionPrefix ? topInfo.title.slice(field.text.length) : ""
  readonly property string completionSuffix: completionPrefix ? " — " + actionOf(topInfo) : "— " + (topInfo ? topInfo.title : "")

  // What the empty field says: the view you're in, the button under the
  // pointer, or the style's own words.
  function placeholderText(idle) {
    var info = modeInfo(hoveredMode || mode)
    if (info) return info.label
    return scope !== "" ? "" : idle
  }

  // Filter chips: the kinds of results found (or, in Applications, the
  // categories); "/kind" lists the kinds to pick from.
  readonly property var chipItems: {
    if (mode === "apps" && engine) return engine.appCategories.map(function(c) { return { id: c.id, title: c.title } })
    if (mode === "all" && scope === "" && engine && query.trim().charAt(0) === "/")
      return engine.kinds.map(function(k) { return { id: k.id, title: k.title } })
    if (mode === "all" && scope === "" && engine && engine.kinds.length > 1 && query.trim() !== "")
      return engine.kinds.slice(0, 6).map(function(k) { return { id: k.id, title: k.title } })
    return []
  }
  readonly property bool slashFilter: chipItems.length > 0 && mode === "all" && query.trim().charAt(0) === "/"

  function pickChip(id) {
    if (mode === "apps") engine.setAppCategory(engine.appCategory === id ? "" : id)
    else pickScope(id)
    field.forceActiveFocus()
  }

  // Nothing to show, and what to say about it.
  readonly property bool emptyShown: !hasRows && !!engine
    && (mode !== "all" || (query.trim() !== "" && !engine.searchingFiles && settings.web === false))
  readonly property string emptyText: mode === "clipboard" && query.trim() === ""
    ? (settings.clipboard === false ? "The Clipboard view is off in O-Spotlight's settings." : "Nothing copied yet.")
    : mode === "files" && query.trim() === "" ? "No recent files."
    : "No results found."

  // For the styles that count: results on screen (not the web row), and
  // everything there is to search besides files.
  property int resultCount: 0
  readonly property int indexedCount: engine ? engine.apps.length + engine.menuEntries.length + engine.panelEntries.length + engine.themeEntries.length : 0

  // Room the top bar keeps on this screen, [left, top, right, bottom], for
  // the styles that dock to it.
  readonly property var reserved: {
    var monitor = win.screen ? Hyprland.monitorFor(win.screen) : null
    var r = monitor && monitor.lastIpcObject ? monitor.lastIpcObject.reserved : null
    return Array.isArray(r) && r.length === 4 ? r : [0, Style.bar.sizeHorizontal, 0, 0]
  }

  // Typing, from the field of whichever style shows.
  function fieldEdited(text) {
    popup = ""
    // Rows move under a resting pointer as you type; that isn't a choice.
    pointerArmed = false
    if (!engine) return
    if (text !== "") engine.finishOnboarding()
    resetSelection = true
    engine.setQuery(text)
    if (text !== "") idleTimer.stop()
    else if (opened) idleTimer.restart()
  }

  // Scripts and the harness type this way.
  function typeText(text) {
    field.text = String(text || "").slice(0, 500)
    field.cursorPosition = field.text.length
  }

  function flashCopied() {
    if (!tahoe && skin && typeof skin.flashCopied === "function") skin.flashCopied()
    else copiedFlash.restart()
  }

  function resolveService() {
    if (!service && shell && typeof shell.serviceFor === "function") service = shell.serviceFor(pluginId)
  }

  onServiceChanged: if (service) service.attachUi(root)
  onModeChanged: popup = ""
  onPopupChanged: if (popup === "" && opened) field.forceActiveFocus()
  // A style picked while the search is open takes over what you typed.
  onStyleIdChanged: {
    skinLoader.load()
    Qt.callLater(root.carryText)
  }
  function carryText() {
    if (!root.opened || !root.engine) return
    if (root.field.text !== root.engine.query) root.field.text = root.engine.query
    root.field.forceActiveFocus()
  }
  Component.onCompleted: {
    resolveService()
    skinLoader.load()
  }
  Component.onDestruction: if (service) service.detachUi(root)

  // ---- opening and closing ---------------------------------------------------------------

  // The Omarchy shell's summon. Payload: { query, mode, buttons: true }.
  function open(payloadJson) {
    resolveService()
    if (!service || !engine) return
    var payload = {}
    try { payload = JSON.parse(String(payloadJson || "{}")) || {} } catch (e) { payload = {} }

    if (opened && !closing) {
      applyPayload(payload)
      field.forceActiveFocus()
      return
    }

    var reopening = closing
    closeAnim.stop()
    closing = false
    opened = true
    popup = ""

    if (!reopening) {
      engine.reset()
      engine.refresh()
      selectedIndex = -1
      historyIndex = -1
      showPaths = false
      hoveredMode = ""
      pointerArmed = false
      lastPointer = Qt.point(-1, -1)
      buttonsWanted = payload.buttons === true
      pointerStart = Qt.point(-1, -1)
      field.text = ""
      syncRows()
      var screen = focusedScreen()
      if (screen && win.screen !== screen) win.screen = screen
      revealed = false
      progress = 0
      enter = 0
      win.visible = true
      // Where the top bar is, for the styles that dock to it.
      if (!tahoe && styleInfo.dock !== "center") Hyprland.refreshMonitors()
      // Glass needs a picture of the screen before it draws.
      if (needsBackdrop) revealTimer.restart()
      else reveal()
      // What you searched a moment ago comes back, selected, so typing
      // replaces it (as in Spotlight).
      if (!payload.query && !payload.mode && lastQuery && Date.now() - lastClosedAt < 8 * 60000) {
        field.text = lastQuery
        field.selectAll()
      }
    } else {
      openAnim.restart()
    }
    idleTimer.restart()
    applyPayload(payload)
    field.forceActiveFocus()
  }

  // The Omarchy shell's hide.
  function close() {
    if (!opened) return
    opened = false
    closing = true
    lastQuery = mode === "all" ? field.text : ""
    lastClosedAt = Date.now()
    revealTimer.stop()
    idleTimer.stop()
    openAnim.stop()
    closeAnim.restart()
  }

  // Esc, a click outside, or a result that was opened: through the shell,
  // so its idea of what's open stays right.
  function requestClose() {
    if (service) service.hide()
    else close()
  }

  function finishClose() {
    closing = false
    revealed = false
    enter = 0
    win.visible = false
    if (engine) engine.reset()
    field.text = ""
    rowsModel.clear()
    topInfo = null
  }

  function reveal() {
    if (!opened || revealed) return
    revealTimer.stop()
    revealed = true
    openAnim.restart()
  }

  function applyPayload(payload) {
    if (typeof payload.mode === "string") engine.setMode(payload.mode)
    if (payload.buttons === true) buttonsWanted = true
    if (typeof payload.query === "string") {
      field.text = payload.query.slice(0, 500)
      field.cursorPosition = field.text.length
    }
  }

  function focusedScreen() {
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  Timer {
    id: revealTimer
    // Don't wait long on a screen that won't give a picture.
    interval: 90
    onTriggered: root.reveal()
  }

  // A pause with nothing typed brings the browse buttons out.
  Timer {
    id: idleTimer
    interval: 2000
    onTriggered: if (root.opened && root.collapsedMain) root.buttonsWanted = true
  }

  // Opening "materializes", as in Tahoe: it fades in while its width settles
  // from a little wider, just past, and back. Closing fades, grows a little
  // and blurs away.
  // Moving the search: pressed, then past a few pixels, then saved where it
  // lands (it opens there next time, as on a Mac).
  property bool dragArmed: false
  property point dragPress: Qt.point(0, 0)

  function dragPressed(item, mouse) {
    dragPress = item.mapToItem(null, mouse.x, mouse.y)
    dragStartX = settings.offsetX || 0
    dragStartY = settings.offsetY || 0
    dragArmed = true
  }

  function dragMoved(item, mouse) {
    if (!dragArmed) return
    var at = item.mapToItem(null, mouse.x, mouse.y)
    var dx = at.x - dragPress.x
    var dy = at.y - dragPress.y
    if (!dragging && Math.abs(dx) + Math.abs(dy) < 6) return
    dragX = dragStartX + dx
    dragY = dragStartY + dy
    dragging = true
  }

  function dragReleased() {
    if (!dragArmed) return
    dragArmed = false
    if (!dragging) return
    // Where it actually is, kept on screen, before the drag lets go of it.
    var x = Math.round(card.placeX(dragX) - card.homeX)
    var y = Math.round(card.placeY(dragY) - card.homeY)
    if (service) {
      service.setSetting("offsetX", Math.abs(x) < 12 ? 0 : x)
      service.setSetting("offsetY", Math.abs(y) < 12 ? 0 : y)
    }
    dragX = Math.abs(x) < 12 ? 0 : x
    dragY = Math.abs(y) < 12 ? 0 : y
    dragging = false
    field.forceActiveFocus()
  }

  property real progress: 0
  property bool dragging: false
  property real dragX: 0
  property real dragY: 0
  property real dragStartX: 0
  property real dragStartY: 0
  property real widthScale: 1
  property real closeScale: 1
  property real closeBlur: 0
  // 0 to 1 as a style comes in (and back as it goes); each style shapes it.
  property real enter: 0

  ParallelAnimation {
    id: openAnim
    NumberAnimation { target: root; property: "progress"; to: 1; duration: root.reduceMotion ? 120 : 150; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "widthScale"; from: root.reduceMotion ? 1 : 1.06; to: 1; duration: root.reduceMotion ? 1 : 320; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
    NumberAnimation { target: root; property: "closeScale"; to: 1; duration: 1 }
    NumberAnimation { target: root; property: "closeBlur"; to: 0; duration: 1 }
    NumberAnimation { target: root; property: "enter"; to: 1; duration: root.reduceMotion ? 1 : 340 }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation { target: root; property: "progress"; to: 0; duration: root.reduceMotion ? 90 : 120; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "closeScale"; to: root.reduceMotion ? 1 : 1.04; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "closeBlur"; to: root.reduceMotion ? 0 : 1; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "enter"; to: 0; duration: root.reduceMotion ? 1 : 140; easing.type: Easing.InQuad }
    onFinished: if (root.closing) root.finishClose()
  }

  // ---- results --------------------------------------------------------------------------------

  ListModel { id: rowsModel }

  Connections {
    target: root.engine
    function onRowsVersionChanged() { root.syncRows() }
  }

  // Follows the engine's rows by key, so rows that stay keep their delegate
  // (and the icon it already loaded) and nothing flickers while you type.
  function syncRows() {
    var rows = engine ? engine.rows : []
    var selectedKey = selectedIndex >= 0 && selectedIndex < rowsModel.count ? rowsModel.get(selectedIndex).key : ""
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (i < rowsModel.count && rowsModel.get(i).key === r.key) {
        rowsModel.set(i, r)
        continue
      }
      var found = -1
      for (var j = i + 1; j < rowsModel.count; j++) {
        if (rowsModel.get(j).key === r.key) {
          found = j
          break
        }
      }
      if (found >= 0) {
        rowsModel.move(found, i, 1)
        rowsModel.set(i, r)
      } else {
        rowsModel.insert(i, r)
      }
    }
    if (rowsModel.count > rows.length) rowsModel.remove(rows.length, rowsModel.count - rows.length)

    // Typing puts the selection on the Top Hit; results arriving later leave
    // it where you put it. Browse views start with nothing selected.
    var next = rows.length > 0 && rows[0].isTop ? 0 : -1
    if (!resetSelection && selectedKey) {
      for (var k = 0; k < rowsModel.count; k++) {
        if (rowsModel.get(k).key === selectedKey) {
          next = k
          break
        }
      }
    }
    resetSelection = false
    selectedIndex = next
    topInfo = rows.length > 0 && rows[0].isTop ? rows[0] : null
    resultCount = rows.length > 0 && rows[rows.length - 1].kind === "web" ? rows.length - 1 : rows.length
    layoutGrid()
    if (selectedIndex >= 0) Qt.callLater(root.revealSelected)
  }

  function revealSelected() {
    if (selectedIndex < 0) return
    if (!tahoe && skin) {
      skin.reveal(selectedIndex)
      return
    }
    if (gridView) {
      var pos = tilePositions[selectedIndex]
      if (!pos) return
      var top = pos.y
      var bottom = pos.y + gridMetrics.tileHeight
      if (top < gridFlick.contentY) gridFlick.contentY = Math.max(0, top - 8)
      else if (bottom > gridFlick.contentY + gridFlick.height) gridFlick.contentY = bottom - gridFlick.height + 8
    } else {
      list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }
  }

  readonly property bool hasRows: rowsModel.count > 0

  // ---- the grid (Applications and Files) --------------------------------------------------
  //
  // Tiles are placed by hand: five across, each section on its own lines,
  // Files' sections under a header, Applications' most used row above a
  // hairline. The same positions answer the arrow keys.

  readonly property QtObject gridMetrics: QtObject {
    // A style's own grid (see styles/StyleBase.qml), or Tahoe's.
    readonly property bool styled: !root.tahoe && !!root.skin
    readonly property int columns: styled ? root.skin.gridColumns : 5
    readonly property real tileWidth: styled ? root.skin.gridTileWidth : (root.fullWidth - 28) / columns
    readonly property int tileHeight: styled ? root.skin.gridTileHeight : root.mode === "files" ? 118 : 104
    readonly property int headerHeight: styled ? root.skin.gridHeaderHeight : 34
    readonly property int separatorHeight: styled ? root.skin.gridSeparatorHeight : 17
    readonly property real originX: styled ? root.skin.gridOriginX : 14
    readonly property real gap: styled ? root.skin.gridGap : 0
    // Tiles: the Top Hit as a card this wide at the left of the results.
    readonly property real heroWidth: styled && root.styleInfo.heroGrid === true && root.mode === "all" ? root.skin.heroWidth : 0
    readonly property real heroHeight: styled ? root.skin.heroHeight : 0
  }

  property var tilePositions: []
  property var gridDecor: []
  property real gridHeight: 0

  function layoutGrid() {
    if (!gridView) {
      tilePositions = []
      gridDecor = []
      gridHeight = 0
      return
    }
    var m = gridMetrics
    var positions = []
    var decor = []
    var y = 4

    // Search results in Tiles: the Top Hit as a card, the rest in lines
    // beside it (the card is column 0 of line 0 for the arrow keys).
    if (m.heroWidth > 0) {
      var hero = rowsModel.count > 0 && rowsModel.get(0).isTop ? 1 : 0
      var left = hero ? m.originX + m.heroWidth + m.gap : m.originX
      for (var h = hero; h < rowsModel.count; h++) {
        var k = h - hero
        var c = k % m.columns
        var l = Math.floor(k / m.columns)
        positions.push({ x: left + c * (m.tileWidth + m.gap), y: y + l * (m.tileHeight + m.gap), col: c + hero, line: l })
      }
      var lines = Math.ceil((rowsModel.count - hero) / m.columns)
      var tilesHeight = lines > 0 ? lines * (m.tileHeight + m.gap) - m.gap : 0
      var heroHeight = hero ? Math.max(m.heroHeight, tilesHeight) : 0
      if (hero) positions.unshift({ x: m.originX, y: y, col: 0, line: 0, w: m.heroWidth, h: heroHeight, hero: true })
      tilePositions = positions
      gridDecor = []
      gridHeight = y + Math.max(heroHeight, tilesHeight) + 6
      return
    }

    var section = null
    var col = 0
    var line = -1
    for (var i = 0; i < rowsModel.count; i++) {
      var r = rowsModel.get(i)
      if (r.section !== section) {
        if (section !== null) {
          y += m.tileHeight + m.gap
          if (!r.sectionTitle) {
            decor.push({ kind: "separator", y: y, title: "" })
            y += m.separatorHeight
          }
        }
        if (r.sectionTitle) {
          decor.push({ kind: "header", y: y, title: r.sectionTitle })
          y += m.headerHeight
        }
        section = r.section
        col = 0
        line++
      } else if (col >= m.columns) {
        col = 0
        y += m.tileHeight + m.gap
        line++
      }
      positions.push({ x: m.originX + col * (m.tileWidth + m.gap), y: y, col: col, line: line })
      col++
    }
    if (rowsModel.count > 0) y += m.tileHeight
    tilePositions = positions
    gridDecor = decor
    gridHeight = y + 6
  }

  // The tile a line up or down, in the same column or the nearest to it.
  function gridStep(delta) {
    var here = tilePositions[selectedIndex]
    if (!here) {
      selectedIndex = rowsModel.count > 0 ? 0 : -1
      return
    }
    var target = here.line + delta
    var best = -1
    for (var i = 0; i < tilePositions.length; i++) {
      var p = tilePositions[i]
      if (p.line !== target || p.hero) continue
      if (best < 0 || Math.abs(p.col - here.col) < Math.abs(tilePositions[best].col - here.col)) best = i
    }
    // Up from the first line of tiles: the Top Hit's card.
    if (best < 0 && delta < 0 && !here.hero && tilePositions[0] && tilePositions[0].hero) best = 0
    if (best >= 0) selectedIndex = best
  }

  function select(delta) {
    if (rowsModel.count === 0) return
    pointerArmed = false
    if (selectedIndex < 0) selectedIndex = delta > 0 ? 0 : rowsModel.count - 1
    else selectedIndex = Math.max(0, Math.min(rowsModel.count - 1, selectedIndex + delta))
    revealSelected()
  }

  // A filter chip, or "/kind" + Return: that kind only. A "/word" in the
  // field was just the filter, so it goes.
  function pickScope(id) {
    if (field.text.trim().charAt(0) === "/") field.text = ""
    engine.setScope(id)
  }

  function activateSelected(how) {
    if (!service || rowsModel.count === 0) return
    if (selectedIndex < 0) selectedIndex = 0
    var result = service.activate(rowsModel.get(selectedIndex).key, how || "open")
    if (result === "close") requestClose()
    else if (result === "stay") flashCopied()
  }

  // The pointer only takes the selection once it really moves, so a list
  // that scrolls under a resting pointer doesn't steal it from the keyboard.
  property bool pointerArmed: false
  property point lastPointer: Qt.point(-1, -1)
  property point pointerStart: Qt.point(-1, -1)

  function pointerMoved(index, x, y) {
    if (lastPointer.x >= 0 && (Math.abs(x - lastPointer.x) > 1 || Math.abs(y - lastPointer.y) > 1)) pointerArmed = true
    lastPointer = Qt.point(x, y)
    if (pointerArmed) selectedIndex = index
  }

  // ---- keyboard --------------------------------------------------------------------------------

  function handleKey(event) {
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var key = event.key

    if (key === Qt.Key_Control) {
      showPaths = true
      return
    }
    if (key !== Qt.Key_Up) historyIndex = -1

    if (key === Qt.Key_Escape) {
      // Back out one layer at a time, then clear, then close.
      if (popup !== "") popup = ""
      else if (scope !== "") engine.setScope("")
      else if (mode !== "all") engine.setMode("all")
      else if (field.text !== "") field.text = ""
      else requestClose()
    } else if (gridView && (key === Qt.Key_Down || key === Qt.Key_Up)) {
      pointerArmed = false
      gridStep(key === Qt.Key_Down ? 1 : -1)
      revealSelected()
    } else if (gridView && field.text === "" && (key === Qt.Key_Right || key === Qt.Key_Left)) {
      select(key === Qt.Key_Right ? 1 : -1)
    } else if (key === Qt.Key_Up && field.text === "" && mode === "all" && engine.pastQueries.length > 0) {
      // Your last searches, newest first.
      historyIndex = Math.min(engine.pastQueries.length - 1, historyIndex + 1)
      field.text = engine.pastQueries[historyIndex]
      field.selectAll()
    } else if (key === Qt.Key_Up && historyIndex >= 0 && field.text === engine.pastQueries[historyIndex]) {
      historyIndex = Math.min(engine.pastQueries.length - 1, historyIndex + 1)
      field.text = engine.pastQueries[historyIndex]
      field.selectAll()
    } else if (key === Qt.Key_Down) select(1)
    else if (key === Qt.Key_Up) select(-1)
    else if (key === Qt.Key_PageDown) select(gridView ? gridMetrics.columns * 3 : 6)
    else if (key === Qt.Key_PageUp) select(gridView ? -gridMetrics.columns * 3 : -6)
    else if (key === Qt.Key_Tab) select(1)
    else if (key === Qt.Key_Backtab) select(-1)
    else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && showOnboarding) engine.finishOnboarding()
    else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && mode === "all" && scope === "" && field.text.trim().charAt(0) === "/") {
      if (engine.kinds.length > 0) pickScope(engine.kinds[0].id)
    }
    else if (key === Qt.Key_Return || key === Qt.Key_Enter) activateSelected(ctrl ? "reveal" : "open")
    else if (ctrl && key === Qt.Key_R) activateSelected("reveal")
    else if (ctrl && key === Qt.Key_C && field.selectedText === "") activateSelected("copy")
    else if (ctrl && key === Qt.Key_B) {
      if (service && service.searchWeb(field.text)) requestClose()
    } else if (ctrl && key >= Qt.Key_1 && key <= Qt.Key_4) {
      var wanted = allModes[key - Qt.Key_1].id
      var available = modes.some(function(m) { return m.id === wanted })
      if (available) engine.setMode(mode === wanted ? "all" : wanted)
    } else if (ctrl && key === Qt.Key_Comma) {
      if (service) service.openSettings("")
    } else if (key === Qt.Key_Backspace && field.text === "" && (scope !== "" || mode !== "all")) {
      if (scope !== "") engine.setScope("")
      else engine.setMode("all")
    } else if (key === Qt.Key_Right && field.cursorPosition === field.text.length && completionRemainder !== "") {
      field.text = field.text + completionRemainder
    } else if (skin && !tahoe && skin.horizontal && !gridView && rowsModel.count > 0
               && key === Qt.Key_Right && field.cursorPosition === field.text.length) {
      // Results side by side (Command strip): → past the end of the text.
      select(1)
    } else if (skin && !tahoe && skin.horizontal && !gridView && rowsModel.count > 0
               && key === Qt.Key_Left && field.cursorPosition === 0 && field.selectedText === "") {
      select(-1)
    } else {
      return
    }
    event.accepted = true
  }

  function handleKeyRelease(event) {
    if (event.key === Qt.Key_Control) showPaths = false
  }

  // ---- the window -------------------------------------------------------------------------------

  PanelWindow {
    id: win

    visible: false
    color: "transparent"
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: root.testMode ? "marcho78-o-spotlight-dev" : "marcho78-o-spotlight"
    WlrLayershell.layer: root.testMode ? WlrLayer.Background : WlrLayer.Overlay
    // Released the moment it starts to close, so whatever runs next (a paste,
    // the Omarchy menu) lands where it should.
    WlrLayershell.keyboardFocus: root.opened && !root.testMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: root.testMode ? noInput : null

    Region { id: noInput }

    Item {
      id: stage
      anchors.fill: parent

      // ---- the picture behind the glass ----
      //
      // One capture of the screen per opening, blurred once, which the glass
      // then shows through (and, liquid, bends at its edges). Omarchy turns
      // the compositor's blur off, so the glass does its own.
      Loader {
        id: capture
        anchors.fill: parent
        active: win.visible && root.needsBackdrop
        visible: false
        sourceComponent: Item {
          anchors.fill: parent
          property alias blurred: blur

          ScreencopyView {
            id: shot
            anchors.fill: parent
            visible: !root.testMode
            captureSource: root.testMode ? null : win.screen
            live: false
            onHasContentChanged: if (hasContent) root.reveal()
          }
          Image {
            id: testShot
            anchors.fill: parent
            visible: root.testMode
            source: root.testMode ? root.testBackdrop : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            onStatusChanged: if (status === Image.Ready) root.reveal()
          }
          MultiEffect {
            id: blur
            anchors.fill: parent
            source: root.testMode ? testShot : shot
            visible: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            saturation: 0.22
            brightness: root.dark ? -0.03 : 0.04
            autoPaddingEnabled: false
          }
        }
      }

      Image {
        anchors.fill: parent
        visible: root.testMode && root.showTestBackdrop
        source: visible ? root.testBackdrop : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      ShaderEffectSource {
        id: glassSource
        sourceItem: capture.item ? capture.item.blurred : null
        textureSize: Qt.size(Math.max(1, Math.round(stage.width / 2)), Math.max(1, Math.round(stage.height / 2)))
        live: true
        mipmap: true
        hideSource: false
        visible: false
      }

      // A click anywhere but the glass closes the search; moving the pointer
      // brings out the browse buttons.
      MouseArea {
        anchors.fill: parent
        enabled: root.opened
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: root.requestClose()
        onPositionChanged: function(mouse) {
          if (root.pointerStart.x < 0) root.pointerStart = Qt.point(mouse.x, mouse.y)
          else if (Math.abs(mouse.x - root.pointerStart.x) + Math.abs(mouse.y - root.pointerStart.y) > 6) root.buttonsWanted = true
        }
      }

      Item {
        id: group
        visible: root.tahoe
        // Where you dragged it (remembered), kept on the screen with room for
        // the tallest the results get.
        readonly property real homeX: Math.round((stage.width - width) / 2)
        readonly property real homeY: Math.round(stage.height * 0.2)
        readonly property real offsetX: root.dragging ? root.dragX : (root.settings.offsetX || 0)
        readonly property real offsetY: root.dragging ? root.dragY : (root.settings.offsetY || 0)
        function placeX(offset) { return Math.min(Math.max(8, stage.width - width - 8), Math.max(8, homeX + offset)) }
        function placeY(offset) { return Math.min(Math.max(8, stage.height - 546 - 8), Math.max(8, homeY + offset)) }
        width: root.fullWidth
        height: root.barHeight + Math.max(0, panel.height - root.barHeight)
        x: placeX(offsetX)
        y: placeY(offsetY)
        opacity: root.revealed ? root.progress : 0
        transform: Scale {
          origin.x: group.width / 2
          origin.y: root.barHeight / 2
          xScale: root.widthScale * root.closeScale
          yScale: root.closeScale
        }
        layer.enabled: root.closing && root.closeBlur > 0
        layer.effect: MultiEffect {
          blurEnabled: true
          blurMax: 16
          blur: root.closeBlur
          autoPaddingEnabled: true
        }

        // ---- the glass: a capsule that grows into the results ----
        Glass {
          id: panel

          readonly property bool expanded: root.hasRows || root.emptyShown || root.showOnboarding || root.slashFilter
          readonly property real bodyHeight: root.showOnboarding ? onboarding.implicitHeight + 8
            : root.gridView ? root.gridHeight : list.contentHeight
          readonly property real openHeight: Math.min(root.maxHeight, body.y + bodyHeight + 10)

          width: root.barWidth
          height: expanded ? Math.max(root.barHeight + 60, openHeight) : root.barHeight
          radius: 28
          style: root.glassStyle
          dark: root.dark
          backdrop: glassSource
          backdropSpace: stage
          frost: 0.7
          refraction: 11
          tintStrength: 1.1

          Behavior on width {
            enabled: root.revealed && !root.reduceMotion
            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
          }
          Behavior on height {
            enabled: root.revealed && !root.reduceMotion
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.35 }
          }

          // Clicks on the glass stay on the glass, and a drag from any empty
          // part of it moves the search.
          MouseArea {
            id: glassMouse
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) root.dragPressed(glassMouse, mouse) }
            onPositionChanged: function(mouse) { root.dragMoved(glassMouse, mouse) }
            onReleased: root.dragReleased()
            onCanceled: root.dragReleased()
          }

          ClippingRectangle {
            id: clipper
            anchors.fill: parent
            radius: 28
            color: "transparent"

            // ---- the field ----
            Item {
              id: header
              width: root.fullWidth
              height: root.barHeight

              // Around the text: a click puts the cursor in the field; a drag
              // moves the search (the text itself keeps its own selecting).
              MouseArea {
                id: headerMouse
                anchors.fill: parent
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.IBeamCursor
                onPressed: function(mouse) {
                  field.forceActiveFocus()
                  root.dragPressed(headerMouse, mouse)
                }
                onPositionChanged: function(mouse) { root.dragMoved(headerMouse, mouse) }
                onReleased: root.dragReleased()
                onCanceled: root.dragReleased()
              }

              // The magnifying glass, or the view you're in (hover it to go back).
              Item {
                id: leading
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                readonly property var info: root.modeInfo(root.mode)
                readonly property bool canGoBack: !!info && leadingMouse.containsMouse

                Rectangle {
                  anchors.fill: parent
                  radius: 10
                  color: root.controlHover
                  visible: leading.canGoBack
                }
                Icon {
                  anchors.centerIn: parent
                  width: 23
                  height: 23
                  name: leading.canGoBack ? "back" : leading.info ? leading.info.icon : "search"
                  color: leading.info ? root.textPrimary : root.textSecondary
                  weight: 1.9
                }
                MouseArea {
                  id: leadingMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: leading.info ? Qt.PointingHandCursor : Qt.IBeamCursor
                  onClicked: {
                    if (leading.info) root.engine.setMode("all")
                    field.forceActiveFocus()
                  }
                }
              }

              // A filter chip you picked, as a token before the text.
              Rectangle {
                id: token
                visible: root.scope !== ""
                x: 60
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: visible ? tokenText.implicitWidth + 20 : 0
                radius: 8
                color: root.dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.11)
                Text {
                  id: tokenText
                  anchors.centerIn: parent
                  text: root.engine ? root.engine.scopeTitle : ""
                  textFormat: Text.PlainText
                  color: root.textPrimary
                  font.family: root.uiFont
                  font.pixelSize: 19
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.engine.setScope("")
                }
              }

              TextInput {
                id: tahoeField
                x: token.visible ? token.x + token.width + 8 : 60
                anchors.verticalCenter: parent.verticalCenter
                width: accessory.x - x - 12
                focus: root.tahoe
                enabled: root.tahoe
                clip: true
                color: root.textPrimary
                selectionColor: Qt.rgba(root.highlight.r, root.highlight.g, root.highlight.b, 0.42)
                selectedTextColor: root.textPrimary
                font.family: root.uiFont
                font.pixelSize: 26
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                maximumLength: 500
                cursorDelegate: Rectangle {
                  width: 2
                  color: root.highlight
                  visible: tahoeField.activeFocus && tahoeField.cursorVisible && tahoeField.selectedText === ""
                }
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) { root.handleKey(event) }
                Keys.onReleased: function(event) { root.handleKeyRelease(event) }
                onTextChanged: if (root.tahoe) root.fieldEdited(text)

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  visible: tahoeField.text === ""
                  text: root.placeholderText("Spotlight Search")
                  textFormat: Text.PlainText
                  color: root.textTertiary
                  font: tahoeField.font
                  elide: Text.ElideRight
                }

                // The Top Hit, completed after what you typed, in a pill:
                // "chr" [omium — Open], or "beach" [— Beach Dusk.png].
                Rectangle {
                  id: completion
                  readonly property bool prefix: root.completionPrefix
                  readonly property string remainder: root.completionRemainder
                  visible: root.completionShown
                  // The rest of the name reads on from the cursor; the pill
                  // starts a little before it so its corner doesn't clip text.
                  x: prefix ? tahoeField.contentWidth - 3 : tahoeField.contentWidth + 8
                  anchors.verticalCenter: parent.verticalCenter
                  height: 34
                  width: Math.min(completionRest.implicitWidth + completionSuffix.implicitWidth + (prefix ? 14 : 18), Math.max(0, tahoeField.width - x))
                  radius: 9
                  color: root.pillFill
                  clip: true

                  Text {
                    id: completionRest
                    x: 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: completion.remainder
                    textFormat: Text.PlainText
                    color: root.textPrimary
                    font: tahoeField.font
                  }
                  Text {
                    id: completionSuffix
                    x: completion.prefix ? completionRest.x + completionRest.implicitWidth : 9
                    // On the rest's baseline, or centered in the pill.
                    y: completion.prefix ? completionRest.y + completionRest.baselineOffset - baselineOffset : (parent.height - height) / 2
                    text: root.completionSuffix
                    textFormat: Text.PlainText
                    color: root.textSecondary
                    font.family: root.uiFont
                    font.pixelSize: 19
                  }
                }
              }

              // At the right: the Top Hit's icon, the view's options (…), or
              // the shortcut of the button under the pointer.
              Item {
                id: accessory
                x: root.barWidth - width - 16
                anchors.verticalCenter: parent.verticalCenter
                width: keycaps.visible ? keycaps.implicitWidth : 32
                height: 32

                ResultIcon {
                  anchors.fill: parent
                  visible: !!root.topInfo && root.mode === "all" && tahoeField.text !== "" && root.topInfo.kind !== "web"
                  iconType: root.topInfo ? root.topInfo.iconType : ""
                  iconSource: root.topInfo ? root.topInfo.iconSource : ""
                  glyph: root.topInfo ? root.topInfo.glyph : ""
                  glyphFont: root.topInfo ? root.topInfo.glyphFont : ""
                  badge: root.topInfo ? root.topInfo.badge : "#8e8e93"
                  symbol: root.topInfo ? root.topInfo.symbol : ""
                  thumbs: root.topInfo ? root.topInfo.thumbs : ""
                  fallbackFont: root.glyphFont
                }

                Rectangle {
                  id: moreButton
                  anchors.centerIn: parent
                  visible: (root.mode === "apps" || root.mode === "files") && !keycaps.visible
                  width: 28
                  height: 28
                  radius: 14
                  color: moreMouse.containsMouse || root.popup === "view" ? root.controlHover : "transparent"
                  border.width: 1.5
                  border.color: root.textSecondary
                  Icon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    name: "more"
                    color: root.textSecondary
                    weight: 3
                  }
                  MouseArea {
                    id: moreMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.popup = root.popup === "view" ? "" : "view"
                  }
                }

                Row {
                  id: keycaps
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.hoveredMode !== ""
                  spacing: 4
                  Repeater {
                    model: root.hoveredMode ? ["Ctrl", root.modeInfo(root.hoveredMode).key] : []
                    Rectangle {
                      required property string modelData
                      width: Math.max(24, capText.implicitWidth + 12)
                      height: 24
                      radius: 6
                      color: root.controlFill
                      border.width: 1
                      border.color: root.hairline
                      Text {
                        id: capText
                        anchors.centerIn: parent
                        text: parent.modelData
                        textFormat: Text.PlainText
                        color: root.textSecondary
                        font.family: root.uiFont
                        font.pixelSize: 12
                      }
                    }
                  }
                }
              }
            }

            // ---- under the field ----
            Rectangle {
              id: separator
              x: 20
              y: root.barHeight
              width: root.fullWidth - 40
              height: 1
              color: root.hairline
              opacity: panel.expanded ? 1 : 0
            }

            // Filter chips: the kinds of results found (or, in Applications,
            // the categories). They share the row when they fit.
            Item {
              id: chips
              readonly property var items: root.chipItems
              readonly property bool shown: items.length > 0
              x: 20
              y: root.barHeight + 11
              width: root.fullWidth - 40
              height: shown ? 24 : 0
              visible: shown

              Flickable {
                anchors.fill: parent
                contentWidth: chipRow.width
                interactive: contentWidth > width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                  id: chipRow
                  spacing: 8
                  readonly property real equal: (chips.width - spacing * (chips.items.length - 1)) / Math.max(1, chips.items.length)
                  readonly property bool fits: {
                    for (var i = 0; i < chipRepeater.count; i++) {
                      var c = chipRepeater.itemAt(i)
                      if (c && c.implicitWidth > equal) return false
                    }
                    return true
                  }
                  Repeater {
                    id: chipRepeater
                    model: chips.items
                    Chip {
                      required property var modelData
                      ui: root
                      text: modelData.title
                      width: chipRow.fits ? chipRow.equal : implicitWidth
                      active: root.mode === "apps" && root.engine && root.engine.appCategory === modelData.id
                      onClicked: {
                        if (root.mode === "apps") root.engine.setAppCategory(modelData.id)
                        else root.pickScope(modelData.id)
                        tahoeField.forceActiveFocus()
                      }
                    }
                  }
                }
              }
            }

            Item {
              id: body
              y: chips.shown ? chips.y + chips.height + 11 : root.barHeight + 6
              width: root.fullWidth
              height: Math.max(0, panel.height - y - 6)
              opacity: panel.expanded ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 140 } }

              // The list: search results, Actions, Clipboard, and Files while you search.
              ListView {
                id: list
                anchors.fill: parent
                visible: !root.gridView
                clip: true
                model: rowsModel
                cacheBuffer: 2400
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                reuseItems: false

                section.property: "sectionTitle"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                  id: sectionHeader
                  required property string section
                  width: ListView.view ? ListView.view.width : 0
                  height: section === "" ? 0 : 36
                  visible: section !== ""
                  Text {
                    x: 20
                    anchors.bottom: headerRule.top
                    anchors.bottomMargin: 6
                    text: sectionHeader.section
                    textFormat: Text.PlainText
                    color: root.textPrimary
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.weight: Font.Bold
                  }
                  Rectangle {
                    id: headerRule
                    x: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: parent.width - 40
                    height: 1
                    color: root.hairline
                  }
                }

                delegate: ResultRow {
                  ui: root
                }
              }

              // The grid: Applications, and Files with nothing typed.
              Flickable {
                id: gridFlick
                anchors.fill: parent
                visible: root.gridView
                clip: true
                contentHeight: root.gridHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Repeater {
                  model: root.gridView ? root.gridDecor : []
                  Item {
                    required property var modelData
                    x: 20
                    y: modelData.y
                    width: root.fullWidth - 40
                    height: modelData.kind === "header" ? 34 : 17
                    Text {
                      visible: parent.modelData.kind === "header"
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 8
                      text: parent.modelData.title
                      textFormat: Text.PlainText
                      color: root.textPrimary
                      font.family: root.uiFont
                      font.pixelSize: 13
                      font.weight: Font.Bold
                    }
                    Rectangle {
                      anchors.verticalCenter: parent.modelData.kind === "separator" ? parent.verticalCenter : undefined
                      anchors.bottom: parent.modelData.kind === "header" ? parent.bottom : undefined
                      width: parent.width
                      height: 1
                      color: root.hairline
                    }
                  }
                }

                Repeater {
                  model: root.gridView ? rowsModel : null
                  GridTile {
                    ui: root
                    lines: root.mode === "files" ? 2 : 1
                    x: root.tilePositions[index] ? root.tilePositions[index].x : 0
                    y: root.tilePositions[index] ? root.tilePositions[index].y : 0
                    width: root.gridMetrics.tileWidth
                    height: root.gridMetrics.tileHeight
                  }
                }
              }

              // Welcome: what's where, the first time.
              Column {
                id: onboarding
                visible: root.showOnboarding
                x: 24
                y: 8
                width: root.fullWidth - 48
                spacing: 14

                Text {
                  width: parent.width
                  text: "Search everything on Omarchy"
                  textFormat: Text.PlainText
                  color: root.textPrimary
                  font.family: root.uiFont
                  font.pixelSize: 19
                  font.weight: Font.DemiBold
                }
                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  text: "Apps, Omarchy's settings and actions, themes, your files and what's in them, math and conversions. Start typing, or browse:"
                  textFormat: Text.PlainText
                  color: root.textSecondary
                  font.family: root.uiFont
                  font.pixelSize: 15
                }
                Column {
                  width: parent.width
                  spacing: 2
                  Repeater {
                    model: root.modes.map(function(m) { return { icon: m.icon, label: m.label, keys: ["Ctrl", m.key] } }).concat([
                      { icon: "back", label: "Your last searches", keys: ["↑"], turn: true },
                      { icon: "folder", label: "Where a file is: hold Ctrl", keys: ["Ctrl"] }
                    ])
                    Item {
                      required property var modelData
                      width: parent.width
                      height: 34
                      Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        name: parent.modelData.icon
                        rotation: parent.modelData.turn ? 90 : 0
                        color: root.textSecondary
                        weight: 1.9
                      }
                      Text {
                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        textFormat: Text.PlainText
                        color: root.textPrimary
                        font.family: root.uiFont
                        font.pixelSize: 15
                      }
                      Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                          model: parent.parent.modelData.keys
                          Rectangle {
                            required property string modelData
                            width: Math.max(24, keyText.implicitWidth + 12)
                            height: 24
                            radius: 6
                            color: root.controlFill
                            border.width: 1
                            border.color: root.hairline
                            Text {
                              id: keyText
                              anchors.centerIn: parent
                              text: parent.modelData
                              textFormat: Text.PlainText
                              color: root.textSecondary
                              font.family: root.uiFont
                              font.pixelSize: 12
                            }
                          }
                        }
                      }
                    }
                  }
                }
                Item {
                  width: parent.width
                  height: 34
                  Text {
                    anchors.left: parent.left
                    anchors.right: continueButton.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: "What you open is remembered only on this computer, to put it first next time."
                    textFormat: Text.PlainText
                    color: root.textTertiary
                    font.family: root.uiFont
                    font.pixelSize: 13
                  }
                  Rectangle {
                    id: continueButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: continueText.implicitWidth + 32
                    height: 32
                    radius: 16
                    color: continueMouse.containsMouse ? root.controlHover : root.controlFill
                    border.width: 1
                    border.color: root.hairline
                    Text {
                      id: continueText
                      anchors.centerIn: parent
                      text: "Continue"
                      textFormat: Text.PlainText
                      color: root.textPrimary
                      font.family: root.uiFont
                      font.pixelSize: 15
                      font.weight: Font.Medium
                    }
                    MouseArea {
                      id: continueMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.engine.finishOnboarding()
                        field.forceActiveFocus()
                      }
                    }
                  }
                }
              }

              Text {
                id: emptyNote
                anchors.centerIn: parent
                visible: root.emptyShown
                text: root.emptyText
                textFormat: Text.PlainText
                color: root.textSecondary
                font.family: root.uiFont
                font.pixelSize: 15
              }
            }
          }

          // Grid or list, for Applications and Files.
          Rectangle {
            id: viewMenu
            visible: root.popup === "view" && root.tahoe
            x: root.fullWidth - width - 14
            y: root.barHeight - 4
            z: 20
            width: 170
            height: menuColumn.implicitHeight + 12
            radius: 12
            color: root.dark ? Qt.rgba(0.16, 0.16, 0.18, 0.98) : Qt.rgba(0.98, 0.98, 0.99, 0.98)
            border.width: 1
            border.color: root.hairline

            Column {
              id: menuColumn
              x: 6
              y: 6
              width: parent.width - 12
              Text {
                x: 8
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: "View content as"
                textFormat: Text.PlainText
                color: root.textSecondary
                font.family: root.uiFont
                font.pixelSize: 12
              }
              Repeater {
                model: [{ value: "grid", label: "Grid" }, { value: "list", label: "List" }]
                Rectangle {
                  required property var modelData
                  readonly property string key: root.mode === "files" ? "filesView" : "appsView"
                  readonly property bool chosen: (root.settings[key] || "grid") === modelData.value
                  width: menuColumn.width
                  height: 28
                  radius: 7
                  color: optionMouse.containsMouse ? root.controlHover : "transparent"
                  Icon {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    visible: parent.chosen
                    name: "check"
                    color: root.textPrimary
                    weight: 2.4
                  }
                  Text {
                    x: 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    textFormat: Text.PlainText
                    color: root.textPrimary
                    font.family: root.uiFont
                    font.pixelSize: 14
                  }
                  MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.service) root.service.setSetting(parent.key, parent.modelData.value)
                      root.popup = ""
                      root.resetSelection = true
                      Qt.callLater(function() { root.engine.rebuild(false) })
                    }
                  }
                }
              }
            }
          }
        }

        // ---- the browse buttons, out beside the capsule ----
        Row {
          id: buttonRow
          x: root.fullWidth - width
          y: (root.barHeight - root.buttonSize) / 2
          spacing: root.buttonGap
          visible: opacity > 0.01
          opacity: root.buttonsShown ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 180 } }

          Repeater {
            model: root.modes
            Glass {
              id: modeButton
              required property var modelData
              required property int index
              width: root.buttonSize
              height: root.buttonSize
              radius: root.buttonSize / 2
              style: root.glassStyle
              dark: root.dark
              backdrop: glassSource
              backdropSpace: stage
              frost: 0.7
              refraction: 9
              hovered: buttonMouse.containsMouse
              // Springs out of the capsule, one after another.
              scale: root.buttonsShown ? 1 : 0.6
              transform: Translate {
                x: root.buttonsShown ? 0 : -(modeButton.index + 1) * 22
                Behavior on x {
                  enabled: !root.reduceMotion
                  NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
              }
              Behavior on scale {
                enabled: !root.reduceMotion
                SequentialAnimation {
                  PauseAnimation { duration: modeButton.index * 30 }
                  NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }
              }

              Icon {
                anchors.centerIn: parent
                width: 25
                height: 25
                name: modeButton.modelData.icon
                color: root.textSecondary
                weight: 1.8
              }

              MouseArea {
                id: buttonMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: root.hoveredMode = containsMouse ? modeButton.modelData.id : (root.hoveredMode === modeButton.modelData.id ? "" : root.hoveredMode)
                onClicked: {
                  root.hoveredMode = ""
                  root.engine.setMode(modeButton.modelData.id)
                  field.forceActiveFocus()
                }
              }
            }
          }
        }

        // "Copied", after Ctrl+C or a copy button.
        Rectangle {
          id: copied
          anchors.horizontalCenter: panel.horizontalCenter
          y: root.barHeight + 14
          width: copiedText.implicitWidth + 28
          height: 30
          radius: 15
          color: root.dark ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(1, 1, 1, 0.94)
          opacity: 0
          z: 30
          Text {
            id: copiedText
            anchors.centerIn: parent
            text: "Copied"
            textFormat: Text.PlainText
            color: root.textPrimary
            font.family: root.uiFont
            font.pixelSize: 14
            font.weight: Font.Medium
          }
          SequentialAnimation {
            id: copiedFlash
            NumberAnimation { target: copied; property: "opacity"; to: 1; duration: 90 }
            PauseAnimation { duration: 750 }
            NumberAnimation { target: copied; property: "opacity"; to: 0; duration: 220 }
          }
        }
      }

      // ---- any other style: its own file in styles/, over the same stage ----
      // Created with `ui` already set, so its bindings never see it missing.
      Loader {
        id: skinLoader
        anchors.fill: parent
        // From styleInfo itself: this runs as the style changes, before
        // bindings like `tahoe` have caught up.
        function load() {
          var file = root.styleInfo.file
          if (!file) source = ""
          else setSource(Qt.resolvedUrl("styles/" + file), { ui: root })
        }
      }
    }
  }
}
