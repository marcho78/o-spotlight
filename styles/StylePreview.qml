import QtQuick
import "../Palette.js" as Palette

// A small drawing of a style, in the colors it would use, for the settings
// window: its layout in a few shapes (panels, a field, the selected row,
// rows as lines), not a picture of it.
Item {
  id: preview

  property string styleId: "tahoe"
  property var pal: Palette.build({})
  property color highlight: pal.accent
  // Draw a desktop behind it (the style picker), or not (over a wallpaper).
  property bool backdrop: true

  // Shapes on a 100 × 64 grid: { x, y, w, h, r (radius), c (color),
  // b (border color), o (opacity), line (a horizontal line of text) }.
  readonly property var shapes: {
    var p = pal, s = []
    var white = "#ffffff"
    function box(x, y, w, h, r, c, b, o) { s.push({ x: x, y: y, w: w, h: h, r: r || 0, c: c || "transparent", b: b || "transparent", o: o === undefined ? 1 : o }) }
    function line(x, y, w, c, o, h) { box(x, y, w, h || 1.6, (h || 1.6) / 2, c, "", o) }
    function rows(x, y, n, step, w, c, icon) {
      for (var i = 0; i < n; i++) {
        if (icon) box(x, y + i * step - 0.9, 3.4, 3.4, 1, icon, "", 0.9 - i * 0.08)
        line(x + (icon ? 5 : 0), y + i * step, w - i * 3, c, 0.85 - i * 0.12)
      }
    }
    switch (preview.styleId) {
    case "terminal":
      box(16, 12, 68, 42, 0, p.bg, p.accent)
      box(19, 11.2, 11, 1.6, 0, p.bg)
      line(20, 11.3, 9, p.accent, 1, 1.4)
      line(19, 17, 3, p.accent2)
      line(24, 17, 18, p.text)
      box(43, 16.2, 1.6, 3.2, 0, p.text)
      box(16, 22, 68, 0.3, 0, p.borderStrong)
      box(16.3, 25, 67.4, 4, 0, p.surface)
      box(17, 25, 0.9, 4, 0, p.accent)
      line(20, 26.2, 5, p.accent)
      line(28, 26.2, 18, p.text)
      for (var t = 0; t < 4; t++) { line(20, 32 + t * 4.5, 5, p.faint); line(28, 32 + t * 4.5, 26 - t * 3, p.textDim, 0.8) }
      box(16, 50, 68, 0.3, 0, p.borderStrong)
      line(19, 51.6, 34, p.faint, 0.8, 1.1)
      break
    case "strip":
      box(0, 0, 100, 3, 0, p.bgDeep)
      box(0, 3, 100, 26, 0, p.bg)
      box(0, 29, 100, 0.9, 0, p.accent)
      line(4, 7.2, 1.2, p.accent)
      line(7, 7.2, 22, p.text)
      box(72, 3, 7, 8, 0, p.accent)
      for (var g = 0; g < 3; g++) box(79 + g * 7, 3, 0.3, 8, 0, p.borderStrong)
      box(0, 11, 100, 0.3, 0, p.border)
      box(4, 14, 13, 11, 1.4, p.surface, p.accent)
      for (var k = 1; k < 6; k++) box(4 + k * 15, 14, 13, 11, 1.4, p.surfaceLow)
      for (var k2 = 0; k2 < 6; k2++) { box(6 + k2 * 15, 15.8, 3.6, 3.6, 1, p.accent, "", k2 === 0 ? 1 : 0.55); line(6 + k2 * 15, 21.6, 8, p.text, 0.8, 1.2) }
      break
    case "split":
      box(18, 10, 9, 5, 1.4, p.bg)
      box(18, 10, 9, 0.6, 0.3, p.accent)
      box(28, 10.5, 9, 4.5, 1.4, p.bgDeep)
      box(38, 10.5, 9, 4.5, 1.4, p.bgDeep)
      box(14, 14, 72, 42, 1.4, p.bg, p.border)
      line(18, 17.2, 16, p.text)
      box(14, 21, 72, 0.3, 0, p.border)
      box(15.2, 23, 25, 4.4, 0.8, p.accent)
      line(20, 24.4, 12, p.onAccent)
      for (var sp = 0; sp < 5; sp++) { box(16.5, 30.2 + sp * 5, 2.8, 2.8, 0.7, p.muted, "", 0.7); line(21, 30.8 + sp * 5, 14 - sp, p.textDim, 0.8) }
      box(41.5, 21, 0.3, 35, 0, p.border)
      box(45, 25, 8, 8, 2, p.accent)
      line(56, 26.5, 18, p.text, 1, 2.2)
      line(56, 30.5, 12, p.muted, 0.8, 1.2)
      for (var d = 0; d < 3; d++) { line(45, 37 + d * 3, 7, p.faint, 0.9, 1.1); line(55, 37 + d * 3, 14, p.textDim, 0.8, 1.1) }
      for (var a = 0; a < 3; a++) box(45, 47 + a * 3, 37, 0.3, 0, p.border)
      break
    case "tiles":
      box(16, 8, 68, 50, 3, p.bg)
      box(19.5, 11.5, 61, 6.5, 1.6, p.surface)
      line(23, 14, 14, p.text)
      box(19.5, 21, 19, 27, 2, p.accent)
      box(22, 30, 7, 7, 1.6, p.bg)
      line(22, 41, 12, p.onAccent, 1, 2)
      for (var ti = 0; ti < 6; ti++) {
        var tx = 40.5 + (ti % 3) * 13.5, ty = 21 + Math.floor(ti / 3) * 13.5
        box(tx, ty, 12, 12, 1.6, p.surfaceLow)
        box(tx + 1.8, ty + 1.8, 4, 4, 1, p.accent, "", 0.6)
        line(tx + 1.8, ty + 8, 7, p.text, 0.8, 1.2)
      }
      box(19.5, 51.5, 11, 3.4, 1.7, p.text)
      box(32, 51.5, 10, 3.4, 1.7, "transparent", p.borderStrong)
      box(43.5, 51.5, 11, 3.4, 1.7, "transparent", p.borderStrong)
      break
    case "float":
      box(22, 9, 56, 8, 4, p.bg, p.accent)
      line(26, 12.2, 16, p.text)
      box(22, 20, 56, 6.4, 3.2, p.surface)
      box(23.2, 21.2, 4, 4, 2, p.accent)
      line(29, 22.4, 18, p.text)
      box(71, 21.8, 5, 2.8, 1.4, p.accent)
      for (var f = 0; f < 4; f++) {
        box(22, 28.4 + f * 7, 56, 5.8, 2.9, p.bg, "", 0.92 - f * 0.18)
        box(23.2, 29.4 + f * 7, 3.8, 3.8, 1.9, p.muted, "", 0.8 - f * 0.18)
        line(29, 30.4 + f * 7, 16 - f, p.text, 0.8 - f * 0.18)
      }
      for (var kc = 0; kc < 4; kc++) box(34 + kc * 8.5, 58.5, 7, 2.8, 0.6, "transparent", p.borderStrong)
      break
    case "drawer":
      box(0, 0, 100, 3, 0, p.bgDeep)
      box(0, 3, 38, 61, 0, p.bg)
      box(38, 3, 0.3, 61, 0, p.border)
      line(4, 8, 18, p.text, 1, 3)
      box(4, 12.5, 30, 0.7, 0, p.accent)
      line(5, 16.5, 8, p.faint, 0.9, 1)
      box(3, 18.5, 32, 5, 0.8, p.surface)
      box(3, 18.5, 0.8, 5, 0, p.accent)
      box(5, 19.6, 2.8, 2.8, 0.7, p.accent)
      line(10, 20.2, 14, p.text)
      line(5, 26.5, 8, p.faint, 0.9, 1)
      for (var dr = 0; dr < 4; dr++) { box(5, 29 + dr * 5, 2.8, 2.8, 0.7, p.muted, "", 0.7); line(10, 29.6 + dr * 5, 16 - dr, p.text, 0.75) }
      box(0, 58, 38, 0.3, 0, p.border)
      line(4, 60, 20, p.faint, 0.8, 1)
      break
    case "frosted":
      box(21, 11, 58, 42, 5, Palette.a(p.surface, 0.62), Palette.a(white, 0.12))
      box(25, 15, 3, 3, 1.5, "transparent", Palette.a(p.text, 0.6))
      line(30, 15.8, 20, p.textBright)
      box(23, 21, 54, 0.3, 0, Palette.a(white, 0.1))
      box(23, 23.5, 54, 7, 3, Palette.a(p.accent, 0.3))
      box(25, 24.8, 4.4, 4.4, 1.2, p.accent)
      line(32, 26.2, 16, p.textStrong)
      rows(25, 34, 4, 5, 22, p.textBright, Palette.a(p.text, 0.5))
      break
    case "island":
      box(29, 2, 42, 34, 6, "#000000")
      box(32.3, 5.3, 1.4, 1.4, 0.7, p.accent)
      line(36, 5.1, 16, "#ffffff")
      box(30.5, 9.5, 39, 6.4, 3.2, p.dark ? Palette.mix(p.bg, "#ffffff", 0.04) : "#1c1d26")
      box(32, 10.7, 4, 4, 2, p.accent)
      line(38, 11.9, 14, "#ffffff")
      box(64.5, 10.8, 3.8, 3.8, 1.9, "#ffffff")
      for (var il = 0; il < 3; il++) { box(32, 18.8 + il * 5.6, 3.4, 3.4, 1.7, p.muted, "", 0.8); line(38, 19.6 + il * 5.6, 12, "#d0d4e4", 0.8); line(52, 19.6 + il * 5.6, 8, "#6b7089", 0.8) }
      break
    case "glow":
      box(21, 11, 58, 42, 3, p.bgInner, p.accent)
      box(21.3, 11.3, 57.4, 8, 3, Palette.a(p.accent, 0.08))
      line(25, 14.4, 20, p.textStrong)
      box(21, 20, 58, 0.4, 0, Palette.a(p.accent, 0.5))
      box(22.5, 22.5, 55, 6.6, 1.4, Palette.mix(p.bgInner, p.accent, 0.1))
      box(22.5, 22.5, 0.6, 6.6, 0, p.accent)
      box(24.5, 24, 3.8, 3.8, 1, p.accent)
      line(30.5, 25.2, 16, p.textStrong)
      rows(24.5, 33, 4, 5, 22, p.text, p.border)
      break
    case "layered":
      box(24, 9, 52, 9, 3, p.inverse)
      line(28, 12.7, 16, p.onInverse)
      box(66, 12, 6.4, 3, 0.8, Palette.a(p.onInverse, 0.12))
      box(24, 21, 52, 33, 3, Palette.a(p.bg, 0.9), Palette.a(white, 0.08))
      box(25, 23.5, 50, 6.4, 1.8, p.inverse)
      box(26.6, 24.8, 3.8, 3.8, 1, p.accent)
      line(32.5, 26, 14, p.onInverse)
      rows(27, 34, 4, 5, 22, p.textBright, Palette.a(p.text, 0.45))
      break
    case "bento":
      box(12, 7, 76, 50, 4, Palette.a(p.bgInner, 0.9), Palette.a(white, 0.07))
      line(16, 11.5, 20, p.textStrong, 1, 5)
      line(37, 11.5, 14, p.borderStrong, 1, 5)
      box(16, 21, 23, 31, 3, p.accent)
      box(18.5, 23.5, 7, 7, 1.8, p.bgInner, "", 0.9)
      line(18.5, 42, 15, p.onAccent, 1, 2.4)
      box(18.5, 47, 8, 2.8, 1.4, p.bgInner)
      for (var b = 0; b < 5; b++) {
        box(41.5, 21 + b * 6.4, 42.5, 5.4, 1.4, Palette.a(p.text, 0.04))
        box(43, 22.1 + b * 6.4, 3.2, 3.2, 0.9, p.muted, "", 0.8)
        line(48, 22.8 + b * 6.4, 20 - b * 2, p.textBright, 0.8, 1.3)
      }
      break
    default:
      // Tahoe: one piece of glass from a capsule down into the rows.
      box(20, 11, 60, 42, 5, Palette.a(p.dark ? white : "#000000", p.dark ? 0.16 : 0.08), Palette.a(white, 0.3))
      box(24, 14.6, 3, 3, 1.5, "transparent", Palette.a(p.dark ? white : "#000000", 0.6))
      line(29, 15.3, 18, p.dark ? white : "#1c1c1e", 0.95)
      box(22, 21, 56, 0.3, 0, Palette.a(p.dark ? white : "#000000", 0.15))
      box(22, 23.5, 56, 7, 3, Palette.a(p.dark ? white : "#000000", 0.16))
      box(24, 24.8, 4.4, 4.4, 1.2, preview.highlight)
      line(31, 26.2, 16, p.dark ? white : "#1c1c1e")
      rows(24, 34, 4, 5, 22, p.dark ? Palette.a(white, 0.85) : "#3a3a3c", Palette.a(p.dark ? white : "#000000", 0.35))
    }
    return s
  }

  readonly property real unit: Math.min(width / 100, height / 64)
  readonly property real ox: (width - 100 * unit) / 2
  readonly property real oy: (height - 64 * unit) / 2

  // A desktop: dark (or light), with a glow of the accent.
  Rectangle {
    anchors.fill: parent
    visible: preview.backdrop
    radius: 8
    gradient: Gradient {
      GradientStop { position: 0; color: preview.pal.dark ? Palette.mix(preview.pal.bgDeep, preview.pal.accent, 0.18) : Palette.mix(preview.pal.bg, preview.pal.accent, 0.2) }
      GradientStop { position: 1; color: preview.pal.dark ? Palette.mix(preview.pal.bgDeep, "#000000", 0.35) : Palette.mix(preview.pal.bg, preview.pal.text, 0.08) }
    }
  }

  Item {
    anchors.fill: parent
    clip: true
    Repeater {
      model: preview.shapes
      Rectangle {
        required property var modelData
        x: preview.ox + modelData.x * preview.unit
        y: preview.oy + modelData.y * preview.unit
        width: Math.max(1, modelData.w * preview.unit)
        height: Math.max(1, modelData.h * preview.unit)
        radius: modelData.r * preview.unit
        color: modelData.c
        opacity: modelData.o
        border.width: modelData.b !== "transparent" ? Math.max(1, preview.unit * 0.35) : 0
        border.color: modelData.b
      }
    }
  }
}
