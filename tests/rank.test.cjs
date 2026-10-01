// Checks learning from what you open, and how results become the list.
// Usage (from the plugin directory): node tests/rank.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Frecency = load("Frecency.js");
const Rank = load("Rank.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const DAY = 86400000;
const NOW = Date.UTC(2026, 8, 29);

check("recording and parsing", () => {
  let store = Frecency.empty();
  store = Frecency.record(store, "app:kitty", "t", NOW);
  store = Frecency.record(store, "app:kitty", "T ", NOW + 1);
  assert.equal(store.items["app:kitty"].n, 2);
  assert.equal(store.queries["q:t"]["app:kitty"].n, 2);
  const back = plain(Frecency.parse(JSON.stringify(store)));
  assert.deepEqual(back, plain(store));
  // Damaged or foreign data comes back empty or cleaned.
  assert.deepEqual(plain(Frecency.parse("nope")), plain(Frecency.empty()));
  assert.deepEqual(plain(Frecency.parse('{"version":2}')), plain(Frecency.empty()));
  const bad = plain(Frecency.parse(JSON.stringify({ version: 1, items: { "app:a": { n: "x", t: 1 }, "app:b": { n: 1, t: 1 }, "noprefix": { n: 1, t: 1 } }, queries: { "q:q": { "app:a": { n: -1, t: 1 } }, "raw": { "app:b": { n: 1, t: 1 } } } })));
  assert.deepEqual(Object.keys(bad.items), ["app:b"]);
  assert.deepEqual(bad.queries, {});
});

check("flags", () => {
  let store = Frecency.withFlag(Frecency.empty(), "onboarded", true);
  const back = plain(Frecency.parse(JSON.stringify(store)));
  assert.equal(back.flags.onboarded, true);
  const bad = plain(Frecency.parse(JSON.stringify({ version: 1, items: {}, queries: {}, flags: { ok: true, "Bad Key": true, str: "yes" } })));
  assert.deepEqual(bad.flags, { ok: true });
  assert.equal(Frecency.record(store, "app:k", "q", NOW).flags.onboarded, true, "kept when learning");
  assert.equal(Frecency.forget(store, "app:k").flags.onboarded, true, "kept when forgetting");
});

check("limits", () => {
  let store = Frecency.empty();
  for (let i = 0; i < 450; i++) store = Frecency.record(store, "file:/x/" + i, "q" + (i % 320), NOW + i);
  assert.equal(Object.keys(store.items).length, 400);
  assert.ok(store.items["file:/x/449"], "newest kept");
  assert.ok(!store.items["file:/x/0"], "oldest dropped");
  assert.ok(Object.keys(store.queries).length <= 300);
  for (let i = 0; i < 10; i++) store = Frecency.record(store, "app:k" + i, "same", NOW + 1000 + i);
  assert.equal(Object.keys(store.queries["q:same"]).length, 6);
});

check("JavaScript's own names are just text", () => {
  let store = Frecency.empty();
  for (const q of ["__proto__", "constructor", "toString", "hasOwnProperty"]) {
    store = Frecency.record(store, "app:kitty", q, NOW);
    store = Frecency.record(store, "file:/h/" + q, q, NOW);
  }
  // Nothing leaked onto every object.
  assert.equal(({}).n, undefined);
  assert.equal(Object.keys({}).length, 0);
  assert.equal(typeof Object.prototype["app:kitty"], "undefined");
  const back = plain(Frecency.parse(JSON.stringify(store)));
  assert.equal(back.queries["q:__proto__"]["app:kitty"].n, 1);
  assert.equal(back.queries["q:constructor"]["file:/h/constructor"].n, 1);
  assert.ok(Frecency.boost(store, "app:kitty", "constructor", NOW) > 0);
  assert.equal(Frecency.boost(store, "app:other", "__proto__", NOW), 0);
  // Keys without a prefix are refused outright.
  assert.deepEqual(plain(Frecency.record(Frecency.empty(), "__proto__", "x", NOW).items), {});
  const hostile = plain(Frecency.parse('{"version":1,"items":{"__proto__":{"n":1,"t":1}},"queries":{"__proto__":{"app:a":{"n":1,"t":1}}}}'));
  assert.deepEqual(hostile.items, {});
  assert.deepEqual(hostile.queries, {});
});

check("boosts", () => {
  let store = Frecency.empty();
  store = Frecency.record(store, "app:kitty", "t", NOW);
  store = Frecency.record(store, "app:kitty", "t", NOW);
  const exact = Frecency.boost(store, "app:kitty", "t", NOW);
  const longer = Frecency.boost(store, "app:kitty", "te", NOW);
  const none = Frecency.boost(store, "app:other", "t", NOW);
  assert.ok(exact > longer && longer > 0, `${exact} > ${longer} > 0`);
  assert.equal(none, 0);
  const old = Frecency.boost(store, "app:kitty", "t", NOW + 60 * DAY);
  assert.ok(old < exact / 2, "fades with time");
  const forgotten = Frecency.forget(store, "app:kitty");
  assert.equal(Frecency.boost(forgotten, "app:kitty", "t", NOW), 0);
  assert.deepEqual(plain(Frecency.recent(store, "app:", 5)), ["app:kitty"]);
});

const apps = [
  { key: "app:kitty", source: "app", title: "kitty", score: 900 },
  { key: "app:terminal", source: "app", title: "Terminal", score: 880 },
];
const menu = [{ key: "omarchy:setup.terminal", source: "omarchy", title: "Terminal", score: 880 }];
const files = [
  { key: "file:/h/Documents/terms.pdf", source: "file", group: "pdf", title: "terms.pdf", score: 860 },
  { key: "file:/h/t", source: "file", group: "folders", title: "t", score: 800 },
];

check("top hit and sections", () => {
  const list = plain(Rank.build({ query: "t", candidates: apps.concat(menu, files), history: Frecency.empty(), now: NOW, web: true }));
  const keys = list.rows.map((r) => r.key);
  assert.equal(list.top, "app:kitty");
  assert.equal(list.rows[0].sectionTitle, "Top Hit");
  assert.deepEqual(list.rows.map((r) => r.section), ["top", "apps", "omarchy", "folders", "pdf", "web"]);
  assert.equal(keys.filter((k) => k === "app:kitty").length, 1, "the top hit isn't repeated");
  assert.equal(list.rows[list.rows.length - 1].kind, "web");
});

check("learning changes the top hit", () => {
  let store = Frecency.empty();
  store = Frecency.record(store, "app:terminal", "t", NOW);
  store = Frecency.record(store, "app:terminal", "t", NOW);
  const list = Rank.build({ query: "t", candidates: apps, history: store, now: NOW });
  assert.equal(list.top, "app:terminal");
  const off = Rank.build({ query: "t", candidates: apps, history: store, now: NOW, learn: false });
  assert.equal(off.top, "app:kitty", "not when learning is off");
});

check("pinned top hit survives later results", () => {
  const first = Rank.build({ query: "t", candidates: apps, history: Frecency.empty(), now: NOW });
  const later = [{ key: "file:/h/t.txt", source: "file", group: "documents", title: "t.txt", score: 1050 }];
  const again = Rank.build({ query: "t", candidates: apps.concat(later), history: Frecency.empty(), now: NOW, pinnedTop: first.top });
  assert.equal(again.top, first.top);
  const unpinned = Rank.build({ query: "t", candidates: apps.concat(later), history: Frecency.empty(), now: NOW });
  assert.equal(unpinned.top, "file:/h/t.txt");
});

check("answers, limits, disabled sections", () => {
  const withAnswer = plain(Rank.build({ query: "2+2", candidates: apps, answer: { kind: "calc", text: "4" }, history: null, now: NOW }));
  assert.equal(withAnswer.rows[0].kind, "answer");
  assert.equal(withAnswer.top, "calc:2+2");
  const many = [];
  for (let i = 0; i < 9; i++) many.push({ key: "app:" + i, source: "app", title: "App " + i, score: 800 - i });
  const limited = plain(Rank.build({ query: "app", candidates: many, history: null, now: NOW }));
  assert.equal(limited.rows.filter((r) => r.section === "apps").length, 5);
  assert.equal(limited.more.apps, 3);
  const expanded = plain(Rank.build({ query: "app", candidates: many, history: null, now: NOW, expanded: { apps: true } }));
  assert.equal(expanded.rows.filter((r) => r.section === "apps").length, 8);
  const noFiles = plain(Rank.build({ query: "t", candidates: files.concat(apps), history: null, now: NOW, enabled: { pdf: false, folders: false } }));
  assert.ok(noFiles.rows.every((r) => r.section !== "pdf" && r.section !== "folders"));
  assert.equal(Rank.sectionOf({ source: "panel" }), "omarchy");
  const empty = plain(Rank.build({ query: "", candidates: [], history: null, now: NOW, web: true }));
  assert.deepEqual(empty.rows, []);
});

check("the flat Tahoe list", () => {
  const many = [];
  for (let i = 0; i < 12; i++) many.push({ key: "file:/h/src/t" + i + ".ts", source: "file", group: "developer", title: "t" + i + ".ts", score: 890 - i });
  const list = plain(Rank.flat({ query: "t", candidates: apps.concat(menu, files, many), history: Frecency.empty(), now: NOW, web: true }));
  assert.equal(list.top, list.rows[0].key);
  assert.equal(list.rows[0].key, "app:kitty");
  assert.ok(list.rows.every((r) => r.sectionTitle === ""), "no headers");
  assert.equal(list.rows.filter((r) => r.section === "developer").length, 6, "at most six of a kind");
  assert.equal(list.rows[list.rows.length - 1].kind, "web");
  assert.deepEqual(list.kinds.map((k) => k.id), ["apps", "omarchy", "developer", "pdf", "folders"], "best first");
  assert.equal(list.kinds.find((k) => k.id === "developer").count, 12, "chips count everything found");
  const scoped = plain(Rank.flat({ query: "t", candidates: apps.concat(many), history: Frecency.empty(), now: NOW, web: true, scope: "developer" }));
  assert.equal(scoped.rows.length, 12, "a scope shows all of its kind, and no web row");
  const answer = plain(Rank.flat({ query: "2+2", candidates: apps, answer: { text: "4" }, history: null, now: NOW }));
  assert.equal(answer.rows[0].kind, "answer");
  const pinned = plain(Rank.flat({ query: "t", candidates: apps, history: null, now: NOW, pinnedTop: "app:terminal" }));
  assert.equal(pinned.rows[0].key, "app:terminal", "a pinned top hit stays first");
});

check("grouped by kind (the Drawer)", () => {
  const many = [];
  for (let i = 0; i < 12; i++) many.push({ key: "file:/h/src/t" + i + ".ts", source: "file", group: "developer", title: "t" + i + ".ts", score: 890 - i });
  const input = { query: "t", candidates: apps.concat(menu, files, many), history: Frecency.empty(), now: NOW, web: true };
  const flat = plain(Rank.flat(input));
  const grouped = plain(Rank.grouped(input));
  assert.deepEqual(grouped.rows.map((r) => r.key).sort(), flat.rows.map((r) => r.key).sort(), "the same rows as the flat list");
  assert.equal(grouped.top, flat.top);
  assert.equal(grouped.rows[0].key, flat.top, "the Top Hit first");
  assert.equal(grouped.rows[0].sectionTitle, "Top Hit");
  assert.equal(grouped.rows[grouped.rows.length - 1].kind, "web");
  assert.equal(grouped.rows[grouped.rows.length - 1].sectionTitle, "Web");
  // Then one section per kind, in the fixed order, never interleaved.
  const titles = grouped.rows.slice(1, -1).map((r) => r.sectionTitle);
  const order = Rank.SECTIONS.map((s) => s.title);
  for (let i = 1; i < titles.length; i++) assert.ok(order.indexOf(titles[i - 1]) <= order.indexOf(titles[i]), titles.join(", "));
  assert.deepEqual(grouped.kinds, flat.kinds, "the same kinds for the filters");
  const answer = plain(Rank.grouped({ query: "2+2", candidates: apps, answer: { text: "4" }, history: null, now: NOW }));
  assert.equal(answer.rows[0].kind, "answer");
  assert.equal(answer.rows[0].sectionTitle, "Top Hit", "an answer is the Top Hit");
  assert.deepEqual(plain(Rank.grouped({ query: "zzz", candidates: [], history: null, now: NOW })).rows, []);
});

check("/kind filters", () => {
  assert.deepEqual(plain(Rank.kindsFor("pdf")).map((k) => k.id), ["pdf"]);
  assert.equal(plain(Rank.kindsFor("pic"))[0].id, "images");
  assert.equal(plain(Rank.kindsFor("apps"))[0].id, "apps");
  assert.equal(plain(Rank.kindsFor("")).length, Rank.SECTIONS.length);
  assert.deepEqual(plain(Rank.kindsFor("zzz")), []);
});

console.log(`rank: ${passed} checks passed`);
