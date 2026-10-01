// Styles.js - the looks O-Spotlight can take (Appearance › Style).
//
// Tahoe is the Liquid Glass search it has always had. The others come from
// the "Omarchy spotlight app variations" designs: six layouts, each with the
// empty-bar treatment drawn for it, and five finishes. Each lives in
// styles/<file>; they share Spotlight.qml's search, keyboard and results,
// and take their colors from Palette.js.
//
//   grid:     Applications and Files can show as a grid (else a list)
//   heroGrid: search results are a grid too, with the Top Hit as a card
//   dock:     "center" (draggable, opens where you left it), "top" (under the
//             top bar, full width), "left" (full height), "island" (out of
//             the top bar)
//   grouped:  results come in sections by kind, like classic Spotlight
//   blur:     draws a blurred picture of the screen behind it
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

var STYLES = [
  { id: "tahoe", name: "Tahoe", file: "", note: "Liquid Glass that grows from a capsule into the results, like macOS Tahoe.",
    grid: true, dock: "center" },
  { id: "terminal", name: "Terminal", file: "Terminal.qml", note: "fzf in a box-drawn frame, all monospace, with the views as bracketed keys.",
    grid: false, dock: "center" },
  { id: "strip", name: "Command strip", file: "Strip.qml", note: "Docked under the top bar, results scrolling sideways as cards, the views fused to the bar's end.",
    grid: true, dock: "top" },
  { id: "split", name: "Split preview", file: "Split.qml", note: "Results on the left, details and actions on the right, the views as folder tabs.",
    grid: false, dock: "center" },
  { id: "tiles", name: "Tiles", file: "Tiles.qml", note: "The Top Hit as a card beside a grid of tiles, the views as big tiles until you type.",
    grid: true, heroGrid: true, dock: "center" },
  { id: "float", name: "Float", file: "Float.qml", note: "No panel: every result floats on its own and fades, the views as keys in the pill.",
    grid: true, dock: "center" },
  { id: "drawer", name: "Drawer", file: "Drawer.qml", note: "Full height at the left, grouped by kind, large type on a rule.",
    grid: true, dock: "left", grouped: true },
  { id: "frosted", name: "Frosted", file: "Frosted.qml", note: "Heavy blur tinted with your colors, an inner highlight and a soft glow on the selection.",
    grid: true, dock: "center", blur: true },
  { id: "island", name: "Island", file: "Island.qml", note: "A black pill that grows out of the top bar.",
    grid: true, dock: "island" },
  { id: "glow", name: "Glow edge", file: "Glow.qml", note: "An accent-lit rim; the selected row lifts with a bar of light.",
    grid: true, dock: "center" },
  { id: "layered", name: "Layered", file: "Layered.qml", note: "The field and the results float as separate sheets.",
    grid: true, dock: "center", blur: true },
  { id: "bento", name: "Bento", file: "Bento.qml", note: "An oversized query, and the Top Hit as a hero card with the rest beside it.",
    grid: true, dock: "center", blur: true }
]

function ids() {
  return STYLES.map(function(s) { return s.id })
}

function valid(id) {
  return ids().indexOf(id) >= 0
}

function info(id) {
  for (var i = 0; i < STYLES.length; i++) if (STYLES[i].id === id) return STYLES[i]
  return STYLES[0]
}
