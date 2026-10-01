// Palette.js - the colors of O-Spotlight's styles (all but Tahoe, which has
// its own glass): from your Omarchy theme, or from colors you pick.
//
// The designs name five roles: background, surface, text, muted and accent.
// Following the theme, background, text and accent are the theme's own and
// the rest are mixed from them, so any theme, dark or light, keeps the
// relationships the designs were drawn with (in Tokyo Night). With custom
// colors, all five are yours and only the in-between shades are mixed.
//
// Colors are "#rrggbb" strings; a(color, alpha) gives QML's "#aarrggbb".
//
// Plain JavaScript shared by the QML and tests/*.test.cjs.

var FALLBACK = { bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", muted: "#7a82a6", accent: "#7aa2f7" }

function parse(color) {
  var m = /^#?([0-9a-fA-F]{6})$/.exec(String(color || "").trim())
  if (!m) {
    // QML colors print as "#aarrggbb" when they aren't opaque.
    m = /^#?[0-9a-fA-F]{2}([0-9a-fA-F]{6})$/.exec(String(color || "").trim())
    if (!m) return null
  }
  var n = parseInt(m[1], 16)
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}

function hex2(v) {
  var s = Math.max(0, Math.min(255, Math.round(v))).toString(16)
  return s.length < 2 ? "0" + s : s
}

function hex(c) {
  return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b)
}

function valid(color) {
  return /^#[0-9a-fA-F]{6}$/.test(String(color || ""))
}

// `a` moved toward `b` by t (0: a, 1: b).
function mix(a, b, t) {
  var x = parse(a) || parse(FALLBACK.bg)
  var y = parse(b) || parse(FALLBACK.fg)
  return hex({ r: x.r + (y.r - x.r) * t, g: x.g + (y.g - x.g) * t, b: x.b + (y.b - x.b) * t })
}

// The color with an alpha, as QML reads it: "#aarrggbb".
function a(color, alpha) {
  var c = parse(color) || parse(FALLBACK.fg)
  return "#" + hex2(Math.max(0, Math.min(1, alpha)) * 255) + hex(c).slice(1)
}

// WCAG relative luminance, 0 (black) to 1 (white).
function luminance(color) {
  var c = parse(color)
  if (!c) return 0
  function lin(v) {
    v /= 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}

function contrast(x, y) {
  var l1 = luminance(x), l2 = luminance(y)
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
}

// The same color with its hue turned by `degrees`.
function rotate(color, degrees) {
  var c = parse(color)
  if (!c) return color
  var r = c.r / 255, g = c.g / 255, b = c.b / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b)
  var l = (max + min) / 2
  var d = max - min
  var h = 0, s = 0
  if (d > 0) {
    s = d / (1 - Math.abs(2 * l - 1))
    if (max === r) h = ((g - b) / d) % 6
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h *= 60
  }
  h = ((h + degrees) % 360 + 360) % 360
  var ch = (1 - Math.abs(2 * l - 1)) * s
  var x = ch * (1 - Math.abs((h / 60) % 2 - 1))
  var m = l - ch / 2
  var rgb = h < 60 ? [ch, x, 0] : h < 120 ? [x, ch, 0] : h < 180 ? [0, ch, x]
    : h < 240 ? [0, x, ch] : h < 300 ? [x, 0, ch] : [ch, 0, x]
  return hex({ r: (rgb[0] + m) * 255, g: (rgb[1] + m) * 255, b: (rgb[2] + m) * 255 })
}

// Every color a style uses, from { bg, fg, accent } and, optionally,
// { surface, muted } (custom colors give all five).
function build(input) {
  input = input || {}
  var bg = valid(input.bg) ? input.bg.toLowerCase() : FALLBACK.bg
  var fg = valid(input.fg) ? input.fg.toLowerCase() : FALLBACK.fg
  var accent = valid(input.accent) ? input.accent.toLowerCase() : FALLBACK.accent
  var dark = luminance(bg) < 0.2
  var muted = valid(input.muted) ? input.muted.toLowerCase() : mix(fg, bg, 0.42)
  var surface = valid(input.surface) ? input.surface.toLowerCase() : mix(bg, fg, 0.07)
  var black = "#000000", white = "#ffffff"

  var p = {
    dark: dark,
    bg: bg,
    // The top bar's shade in the designs: a step darker than the panel.
    bgDeep: dark ? mix(bg, black, 0.17) : mix(bg, fg, 0.05),
    // Behind a lit rim (Glow edge) and under the Bento glass.
    bgInner: dark ? mix(bg, black, 0.27) : mix(bg, white, 0.5),
    surface: surface,
    surfaceLow: mix(bg, surface, 0.5),
    border: mix(bg, fg, 0.11),
    borderStrong: mix(bg, fg, 0.19),
    text: fg,
    textDim: mix(fg, bg, 0.13),
    textSoft: mix(fg, bg, 0.22),
    textBright: dark ? mix(fg, white, 0.6) : mix(fg, black, 0.3),
    textStrong: dark ? mix(fg, white, 0.85) : mix(fg, black, 0.6),
    muted: muted,
    faint: mix(muted, bg, 0.38),
    accent: accent,
    accentDeep: dark ? mix(accent, black, 0.2) : mix(accent, black, 0.12),
    // A second accent a little round the color wheel (the designs' purple
    // beside their blue), for a prompt and the far end of a lit rim.
    accent2: mix(rotate(accent, 45), fg, 0.25),
    // The designs' light sheet on dark (Layered), dark on light.
    inverse: dark ? mix(fg, white, 0.55) : mix(fg, black, 0.25),
    onInverse: dark ? mix(bg, black, 0.27) : mix(bg, white, 0.6)
  }
  // Text on the accent: the panel's own dark or light, whichever reads.
  var darkest = luminance(bg) < luminance(fg) ? bg : fg
  var lightest = darkest === bg ? p.textStrong : p.bgInner
  p.onAccent = contrast(accent, darkest) >= contrast(accent, lightest) ? darkest : lightest
  return p
}
