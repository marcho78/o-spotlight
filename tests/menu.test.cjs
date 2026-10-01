// Checks how the Omarchy menu, bar panels and themes become results.
// Usage (from the plugin directory): node tests/menu.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const { execFileSync } = require("node:child_process");
const { load, plain } = require("./load.cjs");

const Menu = load("MenuIndex.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const sample = `{
  // comment
  "apps": {"icon":"A","label":"Apps","provider":"apps"},
  "style": {"icon":"S","label":"Style"},
  "style.theme": {"icon":"T","label":"Theme","aliases":["themes"]},
  "style.font": {"icon":"F","label":"Font","provider":"fonts"},
  "setup": {"icon":"s","label":"Setup","aliases":["settings"]},
  "setup.default": {"label":"Defaults"},
  "setup.default.agent": {"label":"Agent","title":"Default Agent"},
  "setup.default.agent.claude": {"label":"Claude","checked":"true","action":"omarchy-default-agent claude"},
  "setup.default.agent.codex": {"label":"Codex","checked":"false","action":"omarchy-default-agent codex"},
  "install": {"label":"Install"},
  "install.docker": {"label":"Docker","when":"false","action":"omarchy-install-docker"},
  "install.gaming": {"label":"Gaming"},
  "install.gaming.steam": {"label":"Steam","when":"false","action":"x"},
  "system": {"label":"System"},
  "system.lock": {"label":"Lock","description":"Lock the screen now","action":"omarchy-system-lock"},
  "go-style": {"label":"Style it","target":"style"},
}`;

const user = `{
  "style.theme": {"label":"Themes"},
  "personal": {"label":"Personal"},
  "personal.notes": {"label":"Notes","action":"omarchy-launch-editor ~/notes"},
}`;

check("parse and merge", () => {
  const merged = Menu.merge(Menu.parse(sample), Menu.parse(user));
  assert.equal(merged.items["style.theme"].label, "Themes", "user file overrides");
  // Like the Omarchy menu itself, a row in your file replaces the whole row.
  assert.deepEqual(plain(merged.items["style.theme"].aliases), []);
  assert.equal(merged.items["style.theme"].icon, "");
  assert.equal(merged.items["personal.notes"].parent, "personal");
  assert.equal(merged.items["go-style"].kind, "link");
  assert.equal(merged.items["system.lock"].kind, "action");
  assert.equal(merged.items["style"].kind, "menu");
  assert.deepEqual(plain(Menu.parse("not json")), []);
  assert.deepEqual(plain(Menu.parse("[1,2]")), []);
});

check("guards run in bash", () => {
  const merged = Menu.merge(Menu.parse(sample), []);
  const script = Menu.guardScript(merged.items);
  const output = execFileSync("/usr/bin/bash", ["-c", script], { encoding: "utf8" });
  const guards = Menu.parseGuards(output);
  assert.equal(guards.when["install.docker"], false);
  assert.equal(guards.checked["setup.default.agent.claude"], true);
  assert.equal(guards.checked["setup.default.agent.codex"], false);
});

check("entries: visibility, paths, routes", () => {
  const merged = Menu.merge(Menu.parse(sample), Menu.parse(user));
  const guards = { when: { "install.docker": false, "install.gaming.steam": false }, checked: { "setup.default.agent.claude": true } };
  const list = plain(Menu.entries(merged, guards));
  const ids = list.map((e) => e.id);
  assert.ok(!ids.includes("apps"), "the Apps submenu is left to the app results");
  assert.ok(!ids.includes("install.docker"), "hidden by its when:");
  assert.ok(!ids.includes("install.gaming"), "a submenu with nothing visible inside");
  assert.ok(ids.includes("install") === false, "Install has nothing visible either");
  assert.ok(ids.includes("style.font"), "a provider submenu stays");
  const claude = list.find((e) => e.id === "setup.default.agent.claude");
  assert.equal(claude.subtitle, "Setup › Defaults › Default Agent", "submenu titles name the path");
  assert.equal(claude.checked, true);
  assert.equal(claude.submenu, false);
  assert.equal(claude.color, "#8e8e93");
  const link = list.find((e) => e.id === "go-style");
  assert.equal(link.route, "style");
  const menuVerbs = plain(Menu.entries(Menu.merge(Menu.parse(`{"install":{"label":"Install"},"install.docker":{"label":"Docker","action":"x"}}`), []), {}));
  assert.equal(menuVerbs.find((e) => e.id === "install.docker").title, "Install Docker", "reads as what it does");
  const notes = list.find((e) => e.id === "personal.notes");
  assert.equal(notes.subtitle, "Personal");
  assert.equal(notes.key, "omarchy:personal.notes");
});

check("the real Omarchy menu", () => {
  const path = "/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc";
  if (!fs.existsSync(path)) return;
  const merged = Menu.merge(Menu.parse(fs.readFileSync(path, "utf8")), []);
  assert.ok(Object.keys(merged.items).length > 200);
  const list = plain(Menu.entries(merged, { when: {}, checked: {} }));
  assert.ok(list.length > 150, "entries: " + list.length);
  assert.ok(list.every((e) => e.title && e.key.startsWith("omarchy:")));
  const script = Menu.guardScript(merged.items);
  assert.ok(script.includes("omarchy-pkg-present()"), "package checks answered in-process");
});

check("bar panels follow the bar", () => {
  const bar = { layout: { left: [{ id: "omarchy.menu" }], right: ["omarchy.network", { id: "omarchy.audio", x: 1 }] } };
  const panels = plain(Menu.panelEntries(bar));
  assert.deepEqual(panels.map((p) => p.plugin), ["omarchy.network", "omarchy.audio"]);
  assert.equal(panels[0].title, "Wi-Fi");
  assert.deepEqual(plain(Menu.panelEntries(null)), []);
});

check("themes", () => {
  const listing = "/usr/share/omarchy/themes/tokyo-night\n/usr/share/omarchy/themes/rose-pine\n/home/u/.config/omarchy/themes/rose-pine\n/home/u/.config/omarchy/themes/.hidden\nnot-a-path\n";
  const themes = plain(Menu.themeEntries(listing, "rose-pine"));
  assert.deepEqual(themes.map((t) => t.title), ["Rose Pine", "Tokyo Night"]);
  assert.equal(themes[0].path, "/home/u/.config/omarchy/themes/rose-pine", "your own theme wins");
  assert.equal(themes[0].checked, true);
  assert.equal(themes[0].preview, "/home/u/.config/omarchy/themes/rose-pine/preview.png");
  assert.equal(Menu.themeTitle("catppuccin-latte"), "Catppuccin Latte");
});

check("ids JavaScript knows are just ids", () => {
  const hostile = `{
    "__proto__": {"label":"Proto"},
    "__proto__.child": {"label":"Child","action":"x"},
    "constructor": {"label":"Ctor"},
    "constructor.run": {"label":"Run","action":"y"},
    "toString": {"label":"Str","action":"z"}
  }`;
  const merged = Menu.merge(Menu.parse(hostile), []);
  const list = plain(Menu.entries(merged, { when: {}, checked: {} }));
  assert.deepEqual(list.map((e) => e.id).sort(), ["__proto__", "__proto__.child", "constructor", "constructor.run", "toString"]);
  assert.equal(list.find((e) => e.id === "constructor.run").color, "#5e5ce6");
  assert.equal(list.find((e) => e.id === "__proto__.child").subtitle, "Proto");
  assert.equal(({}).label, undefined, "nothing leaked onto every object");
  const themes = plain(Menu.themeEntries("/t/__proto__\n/t/constructor\n", ""));
  assert.deepEqual(themes.map((t) => t.name).sort(), ["__proto__", "constructor"]);
});

check("guards in two batches: Omarchy's rows and yours", () => {
  const merged = Menu.merge(Menu.parse(sample), Menu.parse(user));
  const mine = Menu.idsOf(Menu.parse(user));
  const ownScript = Menu.guardScript(merged.items, (id) => !mine[id]);
  const userScript = Menu.guardScript(merged.items, (id) => !!mine[id]);
  assert.ok(ownScript.includes("install.docker:w"), "Omarchy's rows in its batch");
  for (const id of Object.keys(mine)) assert.ok(!ownScript.includes(id + ":"), id + " only in yours");
  const both = Menu.combineGuards(Menu.parseGuards("a:w:1\nb:c:0\n"), Menu.parseGuards("c:w:0\n"));
  assert.equal(both.when.a, true);
  assert.equal(both.when.c, false);
  assert.equal(both.checked.b, false);
  assert.equal(Menu.combineGuards(null, null).when.a, undefined);
  assert.equal(typeof userScript, "string");
});

check("guard ids are plain", () => {
  const items = { "ok.id": { when: "true" }, "bad;id": { when: "true" }, "x$(y)": { checked: "true" } };
  const script = Menu.guardScript(items);
  assert.ok(script.includes("ok.id:w"));
  assert.ok(!script.includes("bad;id"));
  assert.ok(!script.includes("x$(y)"));
});

console.log(`menu: ${passed} checks passed`);
