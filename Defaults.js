// Defaults.js - O-Spotlight's settings: their defaults, and what each may be.
//
// Code rather than a JSON file, so O-Spotlight reads no settings file of its
// own. Settings are stored on O-Spotlight's entry in shell.json (by the
// Omarchy shell), holding only what differs from DEFAULTS; Settings.merge()
// validates them against SCHEMA before anything uses them.

var DEFAULTS = {
  barIcon: true,
  // The look (Styles.js), and where its colors come from: your Omarchy theme,
  // or these (the designs' own, Tokyo Night) once you change them.
  style: "tahoe",
  colors: "theme",
  customBackground: "#1a1b26",
  customSurface: "#24283b",
  customText: "#c0caf5",
  customMuted: "#7a82a6",
  customAccent: "#7aa2f7",
  shortcut: "ALT + SPACE",
  glass: "liquid",
  appearance: "auto",
  highlight: "accent",
  selection: "glass",
  reduceMotion: false,
  appsView: "grid",
  filesView: "grid",
  apps: true,
  omarchy: true,
  themes: true,
  calculator: true,
  files: true,
  contents: true,
  web: true,
  webEngine: "google",
  clipboard: true,
  learn: true,
  excluded: [],
  offsetX: 0,
  offsetY: 0
}

var SCHEMA = {
  types: {
    barIcon: "bool",
    style: "string",
    colors: "string",
    customBackground: "color",
    customSurface: "color",
    customText: "color",
    customMuted: "color",
    customAccent: "color",
    shortcut: "shortcut",
    glass: "string",
    appearance: "string",
    highlight: "string",
    selection: "string",
    reduceMotion: "bool",
    appsView: "string",
    filesView: "string",
    apps: "bool",
    omarchy: "bool",
    themes: "bool",
    calculator: "bool",
    files: "bool",
    contents: "bool",
    web: "bool",
    webEngine: "string",
    clipboard: "bool",
    learn: "bool",
    excluded: "paths",
    offsetX: "int",
    offsetY: "int"
  },
  choices: {
    style: ["tahoe", "terminal", "strip", "split", "tiles", "float", "drawer", "frosted", "island", "glow", "layered", "bento"],
    colors: ["theme", "custom"],
    glass: ["liquid", "frosted", "solid"],
    appearance: ["auto", "dark", "light"],
    highlight: ["accent", "blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"],
    selection: ["glass", "accent"],
    appsView: ["grid", "list"],
    filesView: ["grid", "list"],
    webEngine: ["google", "duckduckgo", "bing", "brave", "kagi", "startpage", "ecosia"]
  },
  ranges: {
    offsetX: [-4000, 4000],
    offsetY: [-4000, 4000]
  }
}
