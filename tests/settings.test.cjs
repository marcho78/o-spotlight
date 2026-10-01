// Checks settings validation, the shortcut and its conflicts, the path to
// hypr/o-spotlight.lua and back, and web addresses.
// Usage (from the plugin directory): node tests/settings.test.cjs

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const path = require("node:path");
const { load, plain, root } = require("./load.cjs");

const Settings = load("Settings.js");
const Defaults = load("Defaults.js");
const Web = load("Web.js");
const defaults = plain(Defaults.DEFAULTS);
const schema = plain(Defaults.SCHEMA);
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("defaults are valid and complete", () => {
  assert.deepEqual(plain(Settings.merge(defaults, defaults, schema)), defaults);
  assert.deepEqual(Object.keys(schema.types).sort(), Object.keys(defaults).sort());
});

check("merging validates", () => {
  const merged = plain(Settings.merge(defaults, {
    glass: "frosted", highlight: "#AABBCC", apps: "yes", webEngine: "altavista", shortcut: "super + space",
    excluded: ["/home/u/secret/", "relative", "/home/u/../etc", "/home/u/secret", 42, "/bad\npath"], unknown: 1
  }, schema));
  assert.equal(merged.glass, "frosted");
  assert.equal(merged.highlight, "#aabbcc");
  assert.equal(merged.apps, true, "not a boolean");
  assert.equal(merged.webEngine, "google", "not a choice");
  assert.equal(merged.shortcut, "SUPER + SPACE");
  assert.deepEqual(merged.excluded, ["/home/u/secret"]);
  assert.equal(merged.unknown, undefined);
  assert.deepEqual(plain(Settings.overrides(defaults, merged)), { glass: "frosted", highlight: "#aabbcc", shortcut: "SUPER + SPACE", excluded: ["/home/u/secret"] });
});

check("style and colors", () => {
  const merged = plain(Settings.merge(defaults, {
    style: "island", colors: "custom", customBackground: "#0A0B0C", customSurface: "0a0b0c", customText: "#fff",
    customMuted: "red", customAccent: "#12345678"
  }, schema));
  assert.equal(merged.style, "island");
  assert.equal(merged.colors, "custom");
  assert.equal(merged.customBackground, "#0a0b0c", "lowercased");
  assert.equal(merged.customSurface, defaults.customSurface, "needs the #");
  assert.equal(merged.customText, defaults.customText, "six digits only");
  assert.equal(merged.customMuted, defaults.customMuted, "no color names");
  assert.equal(merged.customAccent, defaults.customAccent, "no alpha");
  assert.equal(plain(Settings.merge(defaults, { style: "Island" }, schema)).style, "tahoe", "not a style");
  assert.equal(plain(Settings.merge(defaults, { colors: "wallpaper" }, schema)).colors, "theme");
  assert.equal(defaults.style, "tahoe", "Tahoe stays the default");
});

check("shortcuts", () => {
  assert.equal(Settings.parseShortcut("alt + space").text, "ALT + SPACE");
  assert.equal(Settings.parseShortcut("alt + space").modmask, 8);
  assert.equal(Settings.parseShortcut("Cmd + Space").text, "SUPER + SPACE");
  assert.equal(Settings.parseShortcut("").empty, true);
  for (const bad of ["ALT +", "+ SPACE", "ALT + ALT + A", "HYPER + A", "ALT + A; rm", 42, null]) {
    assert.equal(Settings.parseShortcut(bad), null, String(bad));
  }
  assert.equal(Settings.shortcutLabel("ALT + SPACE"), "Alt + Space");
  // A bare key would be taken from every app.
  assert.notEqual(Settings.shortcutProblem("SPACE"), "");
  assert.notEqual(Settings.shortcutProblem("a"), "");
  assert.equal(Settings.shortcutProblem("F13"), "");
  assert.equal(Settings.shortcutProblem("XF86Search"), "");
  assert.equal(Settings.shortcutProblem("ALT + SPACE"), "");
  assert.equal(Settings.shortcutProblem(""), "");
  const merged = plain(Settings.merge(defaults, { shortcut: "SPACE" }, schema));
  assert.equal(merged.shortcut, "ALT + SPACE", "refused, the default stays");
  assert.equal(Settings.shortcutLabel("SUPER + CTRL + K"), "Super + Ctrl + K");
});

check("conflicts", () => {
  const wanted = plain(Settings.wantedBinds({ shortcut: "ALT + SPACE" }));
  assert.equal(wanted.length, 1);
  const free = plain(Settings.checkBinds(wanted, [{ modmask: 64, key: "SPACE", description: "Omarchy menu" }]));
  assert.equal(free.free.length, 1);
  const taken = plain(Settings.checkBinds(wanted, [{ modmask: 8, key: "space", description: "Something" }]));
  assert.equal(taken.taken[0].usedBy, "Something");
  const ours = plain(Settings.checkBinds(wanted, [{ modmask: 8, key: "SPACE", description: "Search with O-Spotlight (O-Spotlight)" }]));
  assert.equal(ours.free.length, 1, "our own earlier bind isn't a conflict");
  const unknown = plain(Settings.checkBinds(wanted, null));
  assert.equal(unknown.taken[0].unknown, true, "unreadable binds: bind nothing");
  assert.deepEqual(plain(Settings.wantedBinds({ shortcut: "" })), []);
});

check("the whole path through hypr/o-spotlight.lua", () => {
  const wanted = plain(Settings.wantedBinds({ shortcut: "ALT + SPACE" }));
  const options = Settings.hyprOptions(Settings.checkBinds(wanted, []).free);
  const registration = Settings.hyprRegistration(path.join(root, "hypr/o-spotlight.lua"), options);
  const script = `
    package.path = "./tests/?.lua;" .. package.path
    local fake = require("fake_hl")
    local status = (function() ${registration} end)()
    print("status " .. status)
    for _, b in ipairs(fake.active_binds()) do
      print("bind " .. b.keys .. " => " .. b.dispatcher.message .. " (" .. b.options.description .. ")")
      hl.dispatch(b.dispatcher)
    end
    for _, e in ipairs(fake.events) do print("event " .. e) end
  `;
  const out = execFileSync("lua", ["-e", script], { cwd: root, encoding: "utf8" }).trim().split("\n");
  assert.equal(out[0], "status ok");
  assert.equal(out[1], "bind ALT + SPACE => marcho78.o-spotlight|toggle (Search with O-Spotlight (O-Spotlight))");
  assert.deepEqual(plain(Settings.parseEvent(out[2].slice(6))), { type: "command", command: "toggle" });
  assert.equal(Settings.parseEvent("marcho78.o-spotlight|rm -rf"), null);
  assert.equal(Settings.parseEvent("other|toggle"), null);
});

check("lua literals", () => {
  const tricky = { path: "/home/me/\"quoted\"\\dir/ümlaut\n", list: [1, true, "x"], "bad key": 1 };
  const out = execFileSync("lua", ["-e", `local t = ${Settings.luaLiteral(tricky)}; io.write(t.path, "|", #t.list, "|", tostring(t["bad key"]))`], { encoding: "utf8" });
  assert.equal(out, "/home/me/\"quoted\"\\dir/ümlaut\n|3|nil");
});

check("entry in the bar", () => {
  const bar = { layout: { right: [{ id: "x" }, { id: "marcho78.o-spotlight", glass: "solid" }] } };
  assert.deepEqual(plain(Settings.entryInBar(bar, "marcho78.o-spotlight")), { glass: "solid" });
  assert.deepEqual(plain(Settings.entryInBar(null, "marcho78.o-spotlight")), {});
  const sections = plain(Settings.enabledSections({ files: false, apps: true }));
  assert.equal(sections.pdf, false);
  assert.equal(sections.apps, true);
  assert.equal(Settings.highlightColor({ highlight: "accent" }, "#123456"), "#123456");
  assert.equal(Settings.highlightColor({ highlight: "green" }, "#123456"), "#32d74b");
});

check("web", () => {
  assert.equal(Web.searchUrl("duckduckgo", " a&b c "), "https://duckduckgo.com/?q=a%26b%20c");
  assert.equal(Web.searchUrl("nope", "x"), "https://www.google.com/search?q=x");
  assert.equal(Web.addressUrl("github.com/basecamp/omarchy"), "https://github.com/basecamp/omarchy");
  assert.equal(Web.addressUrl("https://omarchy.org"), "https://omarchy.org");
  assert.equal(Web.addressUrl("localhost:3000"), "http://localhost:3000");
  assert.equal(Web.addressUrl("192.168.1.1"), "http://192.168.1.1");
  for (const not of ["firefox", "notes.txt", "report.pdf", "hello world.com", "", "file.md", "a.b"]) {
    assert.equal(Web.addressUrl(not), "", not);
  }
});

console.log(`settings: ${passed} checks passed`);
