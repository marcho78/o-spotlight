// Checks the styles: that every one has its file and its settings choice,
// and that their colors, from a theme or chosen, keep the designs'
// relationships (and stay readable) in dark and light.
// Usage (from the plugin directory): node tests/styles.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { load, plain, root } = require("./load.cjs");

const Styles = load("Styles.js");
const Palette = load("Palette.js");
const Defaults = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

// How far apart two colors are, 0..441.
function distance(a, b) {
  const x = Palette.parse(a), y = Palette.parse(b);
  return Math.hypot(x.r - y.r, x.g - y.g, x.b - y.b);
}

check("every style has its file and is a settings choice", () => {
  const ids = plain(Styles.ids());
  assert.equal(new Set(ids).size, ids.length, "unique ids");
  assert.equal(ids[0], "tahoe");
  assert.deepEqual(plain(Defaults.SCHEMA.choices.style), ids);
  for (const style of plain(Styles.STYLES)) {
    assert.ok(style.name && style.note, style.id);
    assert.ok(["center", "top", "left", "island"].includes(style.dock), style.id);
    if (style.id === "tahoe") continue;
    assert.ok(fs.existsSync(path.join(root, "styles", style.file)), style.file);
  }
  assert.equal(Styles.info("nope").id, "tahoe", "anything else is Tahoe");
  assert.equal(Styles.valid("drawer"), true);
  assert.equal(Styles.valid("__proto__"), false);
});

check("color helpers", () => {
  assert.equal(Palette.mix("#000000", "#ffffff", 0.5), "#808080");
  assert.equal(Palette.mix("#102030", "#102030", 0.7), "#102030");
  assert.equal(Palette.a("#7aa2f7", 0.5), "#807aa2f7");
  assert.equal(Palette.a("#7aa2f7", 2), "#ff7aa2f7", "alpha clamps");
  assert.deepEqual(plain(Palette.parse("#ff7aa2f7")), { r: 0x7a, g: 0xa2, b: 0xf7 }, "QML's #aarrggbb");
  assert.equal(Palette.parse("red"), null);
  assert.equal(Palette.rotate("#ff0000", 120), "#00ff00");
  assert.equal(Palette.rotate("#808080", 90), "#808080", "grey has no hue");
  assert.ok(Math.abs(Palette.contrast("#000000", "#ffffff") - 21) < 0.01);
});

check("from a dark theme, close to the designs' own colors", () => {
  // The designs were drawn in Tokyo Night: background, text and accent in,
  // everything else mixed.
  const p = plain(Palette.build({ bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7" }));
  assert.equal(p.dark, true);
  const design = { bgDeep: "#16161e", bgInner: "#13141c", surface: "#24283b", surfaceLow: "#1f2335", border: "#292e42",
    borderStrong: "#3b4261", textDim: "#a9b1d6", textSoft: "#9aa5ce", textBright: "#e6eaff", muted: "#7a82a6",
    faint: "#565f89", accent2: "#bb9af7", onAccent: "#1a1b26", inverse: "#e6e9f5", onInverse: "#13141c" };
  for (const [role, color] of Object.entries(design)) assert.ok(distance(p[role], color) < 42, `${role}: ${p[role]} vs ${color}`);
});

check("from a light theme: the same order of shades, turned around", () => {
  const p = plain(Palette.build({ bg: "#faf4ed", fg: "#575279", accent: "#907aa9" }));
  assert.equal(p.dark, false);
  const lum = (c) => Palette.luminance(c);
  assert.ok(lum(p.surface) < lum(p.bg), "a surface is a step toward the text");
  assert.ok(lum(p.inverse) < lum(p.bg), "the inverse sheet is dark on light");
  assert.ok(Palette.contrast(p.inverse, p.onInverse) > 7);
});

check("text stays readable, whatever the theme", () => {
  const themes = [
    { bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7" },
    { bg: "#0b0c16", fg: "#ddf7ff", accent: "#82fb9c" },
    { bg: "#faf4ed", fg: "#575279", accent: "#907aa9" },
    { bg: "#ffffff", fg: "#000000", accent: "#ffd60a" },
    { bg: "#000000", fg: "#ffffff", accent: "#0000ff" }
  ];
  for (const theme of themes) {
    const p = plain(Palette.build(theme));
    assert.ok(Palette.contrast(p.accent, p.onAccent) >= 3, `on the accent: ${JSON.stringify(theme)}`);
    assert.ok(Palette.contrast(p.bg, p.text) >= 4.5, `text: ${JSON.stringify(theme)}`);
    assert.ok(Palette.contrast(p.bg, p.muted) >= 2.2, `secondary text: ${JSON.stringify(theme)}`);
    for (const role of Object.keys(p)) if (role !== "dark") assert.ok(Palette.valid(p[role]), `${role}: ${p[role]}`);
  }
});

check("custom colors are used as given; bad ones fall back", () => {
  const mine = { bg: "#101010", surface: "#202020", fg: "#eeeeee", muted: "#999999", accent: "#ff8800" };
  const p = plain(Palette.build(mine));
  assert.equal(p.bg, "#101010");
  assert.equal(p.surface, "#202020");
  assert.equal(p.text, "#eeeeee");
  assert.equal(p.muted, "#999999");
  assert.equal(p.accent, "#ff8800");
  const fallback = plain(Palette.build({ bg: "nope", fg: 12, accent: "#12" }));
  assert.equal(fallback.bg, Palette.FALLBACK.bg);
  assert.equal(fallback.text, Palette.FALLBACK.fg);
  assert.equal(fallback.accent, Palette.FALLBACK.accent);
  assert.deepEqual(plain(Palette.build()), plain(Palette.build({})));
});

console.log(`styles: ${passed} checks passed`);
