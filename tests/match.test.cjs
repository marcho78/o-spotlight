// Checks how names are scored against what you type.
// Usage (from the plugin directory): node tests/match.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Match = load("Match.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("folding", () => {
  assert.equal(Match.fold("Café Crème"), "cafe creme");
  assert.equal(Match.fold(null), "");
  assert.deepEqual(plain(Match.terms("  Visual  studio ")), ["visual", "studio"]);
  assert.deepEqual(plain(Match.terms("   ")), []);
});

check("word starts", () => {
  assert.deepEqual(plain(Match.wordStarts("LibreOffice Writer")), [0, 5, 12]);
  assert.deepEqual(plain(Match.wordStarts("gnome-calculator")), [0, 6]);
  assert.deepEqual(plain(Match.wordStarts("mp3 player")), [0, 2, 4]);
  assert.deepEqual(plain(Match.wordStarts("x11vnc")), [0, 1, 3]);
});

check("tiers", () => {
  assert.equal(Match.score("firefox", "Firefox"), 1000);
  assert.ok(Match.score("fire", "Firefox") >= 850);
  assert.ok(Match.score("writer", "LibreOffice Writer") >= 740);
  assert.ok(Match.score("office", "LibreOffice Writer") >= 740, "camelCase hump");
  assert.ok(Match.score("lib wri", "LibreOffice Writer") >= 700);
  assert.ok(Match.score("vsc", "Visual Studio Code") >= 640);
  assert.ok(Match.score("lowr", "LibreOffice Writer") >= 640, "starts of words");
  assert.ok(Match.score("vscode", "Visual Studio Code") >= 640, "pieces of words");
  const mid = Match.score("efo", "Firefox");
  assert.ok(mid >= 540 && mid < 640, "inside a word: " + mid);
  assert.equal(Match.score("frfx", "Firefox"), 0, "scattered letters aren't a match");
  assert.equal(Match.score("fire", "Firmware"), 0, "nor is a prefix that wanders off");
});

check("ordering within and across tiers", () => {
  // Prefix beats word prefix beats initials beats substring beats fuzzy.
  const s = (q, t) => Match.score(q, t);
  assert.ok(s("term", "Terminal") > s("term", "Alacritty Terminal"));
  assert.ok(s("code", "Code") > s("code", "Visual Studio Code"));
  assert.ok(s("vsc", "Visual Studio Code") > s("vsc", "Obvious Scanner"));
  // Shorter names win within a tier.
  assert.ok(s("cal", "Calendar") > s("cal", "Calculator Scientific Edition"));
});

check("non-matches", () => {
  assert.equal(Match.score("zzz", "Firefox"), 0);
  assert.equal(Match.score("", "Firefox"), 0);
  // One letter means the start of a word, never the middle of one.
  assert.equal(Match.score("f", "Spotify"), 0);
  assert.ok(Match.score("f", "Font Viewer") > 0);
  assert.ok(Match.score("v", "Font Viewer") > 0);
  // Two letters don't match scattered.
  assert.equal(Match.score("nv", "Neovim"), 0);
  // Two stray letters in the middle of words aren't a match.
  assert.equal(Match.score("ie", "Firefox"), 0);
  // Letters out of order.
  assert.equal(Match.score("xof", "Firefox"), 0);
});

check("accents and case", () => {
  assert.equal(Match.score("cafe", "Café"), 1000);
  assert.equal(Match.score("CAFÉ", "cafe"), 1000);
});

check("best of several fields", () => {
  const fields = [
    { text: "Chromium", weight: 1 },
    { text: "Web Browser", weight: 0.8 },
    { text: "Access the Internet and browse the web", weight: 0.5, loose: false },
  ];
  assert.ok(Match.best("chrom", fields) >= 850);
  const browser = Match.best("browser", fields);
  assert.ok(browser >= 600 && browser < 800, "generic name counts less: " + browser);
  assert.ok(Match.best("internet", fields) > 0, "a whole word in the description");
  assert.equal(Match.best("nter", fields), 0, "no mid-word hits in a description");
  assert.equal(Match.best("romi", [{ text: "Chromium", weight: 1, min: 620 }]), 0, "min 620: no mid-word hits");
  assert.ok(Match.best("chro", [{ text: "Chromium", weight: 1, min: 620 }]) > 0);
});

check("highlight", () => {
  assert.deepEqual(plain(Match.highlight("fire", "Firefox")), [0, 4]);
  assert.deepEqual(plain(Match.highlight("wri", "LibreOffice Writer")), [12, 3]);
  assert.equal(Match.highlight("efo", "Firefox"), null);
});

console.log(`match: ${passed} checks passed`);
