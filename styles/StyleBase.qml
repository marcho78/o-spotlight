import QtQuick
import "../Palette.js" as Palette

// What every style but Tahoe is: an item over the whole screen that draws
// the search its own way. Spotlight.qml creates it with `ui` (itself), which
// has everything to show (the rows, the selection, the mode, the palette)
// and does everything (typing, keys, opening results). The style fills in
// the pieces Spotlight.qml reads back: its field, its card (the search as
// it's drawn, for moving it), how its grid is laid out, and reveal() and
// flashCopied().
Item {
  id: base
  anchors.fill: parent

  property var ui: null
  readonly property var pal: ui ? ui.pal : Palette.build({})
  readonly property string sans: ui ? ui.uiFont : "sans-serif"
  readonly property string mono: ui ? ui.monoFont : "monospace"

  property Item field: null
  property Item card: null
  // Results side by side, so → and ← at the ends of the text move through them.
  property bool horizontal: false

  // The grid (Applications, Files, and Tiles' results), in the card's
  // coordinates: columns, tile size, gaps, section headers.
  property int gridColumns: 4
  property real gridTileWidth: 120
  property int gridTileHeight: 104
  property int gridHeaderHeight: 34
  property int gridSeparatorHeight: 17
  property real gridOriginX: 0
  property real gridGap: 0
  // Tiles: the Top Hit's card.
  property real heroWidth: 0
  property real heroHeight: 0

  // Scroll the selection into view; say "Copied".
  function reveal(index) {}
  function flashCopied() {}

  // Mode buttons, for the styles that show them: what's there (Clipboard and
  // Files can be off), and picking one (again: back to everything).
  readonly property var modes: ui ? ui.modes : []
  function pickMode(id) {
    if (!ui || !ui.engine) return
    ui.hoveredMode = ""
    ui.engine.setMode(ui.mode === id ? "all" : id)
    ui.field.forceActiveFocus()
  }
  function hoverMode(id, inside) {
    if (!ui) return
    if (inside) ui.hoveredMode = id
    else if (ui.hoveredMode === id) ui.hoveredMode = ""
  }
  // "Apps" where a label must be short.
  function shortLabel(id) {
    return { apps: "Apps", files: "Files", actions: "Actions", clipboard: "Clipboard" }[id] || id
  }
}
