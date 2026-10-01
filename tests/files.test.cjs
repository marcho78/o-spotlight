// Checks file search arguments, output parsing, kinds and ranking.
// Usage (from the plugin directory): node tests/files.test.cjs

const assert = require("node:assert/strict");
const { execFileSync, spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { load, plain } = require("./load.cjs");

const Files = load("Files.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const HOME = "/home/u";

check("fd arguments", () => {
  const argv = plain(Files.fdArgs("tax  2024 ", { root: HOME, excludes: ["/Work/secret"], limit: 50 }));
  assert.equal(argv[0], "/usr/bin/fd");
  assert.ok(argv.includes("--fixed-strings") && argv.includes("--print0") && argv.includes("--max-results=50"));
  assert.ok(argv.includes("--type=f") && argv.includes("--type=d"), "files and folders only");
  assert.ok(argv.includes("--exclude=node_modules") && argv.includes("--exclude=/Work/secret"));
  assert.ok(argv.includes("--and=2024"));
  assert.deepEqual(argv.slice(-3), ["--", "tax", HOME], "the pattern after --, so -x can't be an option");
  assert.equal(Files.fdArgs("   ", { root: HOME }), null);
  assert.equal(Files.fdArgs("x", {}), null);
  const dash = plain(Files.fdArgs("-rf", { root: HOME }));
  assert.deepEqual(dash.slice(-3), ["--", "-rf", HOME]);
});

check("localsearch arguments", () => {
  assert.deepEqual(plain(Files.localSearchArgs("invoice march", 20)), ["/usr/bin/localsearch", "search", "--limit=20", "--", "invoice", "march"]);
  assert.equal(Files.localSearchArgs("", 20), null);
});

check("uris", () => {
  assert.equal(Files.fileUri("/home/u/a b/it's (1).txt"), "file:///home/u/a%20b/it%27s%20%281%29.txt");
  assert.equal(Files.pathFromUri("file:///home/u/a%20b.txt"), "/home/u/a b.txt");
  assert.equal(Files.pathFromUri("https://x"), "");
  assert.equal(Files.pathFromUri("file://%E0%A4%A"), "", "bad escapes");
});

check("thumbnail uris match GLib", () => {
  assert.equal(Files.thumbnailUri("/home/u/Pasted image.png"), "file:///home/u/Pasted%20image.png");
  assert.equal(Files.thumbnailUri("/home/u/it's (1)!.jpg"), "file:///home/u/it's%20(1)!.jpg");
  assert.equal(Files.thumbnailUri("/home/u/ümlaut#?.png"), "file:///home/u/%C3%BCmlaut%23%3F.png");
});

check("parse fd", () => {
  const out = "/home/u/Documents/\0/home/u/Documents/tax.pdf\0/home/u/bad\nname\0/home/u/Work/secret/x.txt\0/home/u/Documents/tax.pdf\0";
  const files = plain(Files.parseFd(out, ["/home/u/Work/secret"], HOME));
  assert.deepEqual(files.map((f) => f.path), ["/home/u/Documents", "/home/u/Documents/tax.pdf"]);
  assert.equal(files[0].isDir, true);
  assert.deepEqual(files[0].icons, ["folder-documents", "folder"], "special folder icon");
  assert.equal(files[1].group, "pdf");
  assert.equal(files[1].kind, "PDF document");
});

check("parse localsearch", () => {
  const out = "file:///home/u/Downloads/Report%202024.docx\nfile:///home/u/.cache/x.txt\nnot a uri\n";
  const files = plain(Files.parseLocalSearch(out, [], HOME));
  assert.equal(files.length, 1);
  assert.equal(files[0].name, "Report 2024.docx");
  assert.equal(files[0].kind, "Word document");
  assert.equal(files[0].fromContents, true);
});

check("recent files and stat", () => {
  const xml = `<xbel><bookmark href="file:///home/u/a.txt" added="x" modified="2026-09-28T01:00:00Z" visited="x"></bookmark>
    <bookmark href="file:///home/u/b%20c.png" modified="2026-09-29T01:00:00Z"></bookmark>
    <bookmark href="file:///home/u/.hidden/s" modified="2026-09-30T01:00:00Z"></bookmark>
    <bookmark href="https://example.com" modified="2026-09-30T01:00:00Z"></bookmark>
    <bookmark href="file:///home/u/Tom&amp;Jerry.txt" modified="2026-09-27T01:00:00Z"></bookmark></xbel>`;
  const recent = plain(Files.parseRecent(xml, 10));
  assert.deepEqual(recent.map((r) => r.path), ["/home/u/b c.png", "/home/u/a.txt", "/home/u/Tom&Jerry.txt"]);
  const stat = plain(Files.parseStat("1789506874\t9\t81a4\t/etc/hostname\n1790702080\t720\t41ed\t/home/u/Downloads\n1\t2\ta1ff\t/home/u/link.png\n1\t0\t11a4\t/home/u/pipe.jpg\ngarbage\n"));
  assert.equal(stat["/etc/hostname"].time, 1789506874000);
  assert.equal(stat["/etc/hostname"].regular, true);
  assert.equal(stat["/home/u/Downloads"].isDir, true);
  assert.equal(stat["/home/u/Downloads"].regular, false);
  assert.equal(stat["/home/u/link.png"].regular, false, "a link is described, not followed");
  assert.equal(stat["/home/u/pipe.jpg"].regular, false);
});

check("recent files: other tags, attribute order, entities", () => {
  const xml = `<xbel><bookmark:applications><bookmark:application name="x"/></bookmark:applications>
    <bookmark modified="2026-09-28T01:00:00Z" href="file:///home/u/first.txt"></bookmark>
    <bookmark href="file:///home/u/a&amp;lt;b.txt" modified="2026-09-29T01:00:00Z"></bookmark>
    <bookmark href="file:///home/u/no-date.txt"></bookmark>
    <bookmarks href="file:///home/u/not-a-bookmark.txt" modified="2026-09-30T01:00:00Z"></bookmarks></xbel>`;
  assert.deepEqual(plain(Files.parseRecent(xml, 10)).map((r) => r.path), ["/home/u/a&lt;b.txt", "/home/u/first.txt"]);
});

check("recent files are read in one pass, however the file is made", () => {
  // A tag that never closes, over and over: the old pattern took seconds on
  // a fraction of the 4 MiB cap.
  const evil = ("<bookmark " + "x".repeat(20) + " href=\"file:///a\" ").repeat(200000);
  let started = Date.now();
  Files.parseRecent(evil, 30);
  assert.ok(Date.now() - started < 1500, `took ${Date.now() - started}ms`);
  const many = Array.from({ length: 20000 }, (_, i) =>
    `<bookmark href="file:///home/u/f${i}.txt" added="x" modified="2026-09-28T01:00:${String(i % 60).padStart(2, "0")}Z" visited="x"><info/></bookmark>`).join("\n");
  started = Date.now();
  assert.equal(Files.parseRecent(`<xbel>${many}</xbel>`, 30).length, 30);
  assert.ok(Date.now() - started < 1500, `took ${Date.now() - started}ms`);
});

check("pictures: only regular files under their cap", () => {
  assert.equal(Files.pictureOk({ regular: true, size: 10 }, 100), true);
  assert.equal(Files.pictureOk({ regular: true, size: 101 }, 100), false);
  assert.equal(Files.pictureOk({ regular: false, size: 0 }, 100), false);
  assert.equal(Files.pictureOk(null, 100), false, "not looked at yet");
  assert.equal(Files.pictureOk(undefined, 100), false);
});

check("stat really runs: a pipe or a link is never a picture", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "o-spotlight-"));
  const photo = path.join(dir, "photo.png");
  fs.writeFileSync(photo, "x".repeat(100));
  const pipe = path.join(dir, "holiday.jpg");
  execFileSync("/usr/bin/mkfifo", [pipe]);
  const link = path.join(dir, "link.png");
  fs.symlinkSync(photo, link);
  // `stat` exits 1 for the missing one, as O-Spotlight expects (okCodes).
  const run = spawnSync("/usr/bin/stat", ["-c", Files.STAT_FORMAT, "--", photo, pipe, link, path.join(dir, "gone.png"), dir],
                        { encoding: "utf8", env: { LANG: "de_DE.UTF-8", PATH: "/usr/bin" } });
  assert.equal(run.status, 1);
  const out = run.stdout;
  const stats = plain(Files.parseStat(out));
  assert.equal(Files.pictureOk(stats[photo], 1000), true);
  assert.equal(Files.pictureOk(stats[photo], 50), false, "too big for the cap");
  assert.equal(Files.pictureOk(stats[pipe], 1000), false, "a pipe");
  assert.equal(Files.pictureOk(stats[link], 1000), false, "a link");
  assert.equal(stats[path.join(dir, "gone.png")], undefined);
  assert.equal(stats[dir].isDir, true, "in any language");
  fs.rmSync(dir, { recursive: true });
});

check("kinds", () => {
  const d = (p, dir) => plain(Files.describe(p, dir, HOME));
  assert.equal(d("/home/u/a/Photo.JPG").kind, "JPEG image");
  assert.equal(d("/home/u/a/Photo.JPG").group, "images");
  assert.equal(d("/home/u/a/notes.md").kind, "Markdown document");
  assert.equal(d("/home/u/a/main.rs").kind, "Rust source");
  assert.equal(d("/home/u/a/pkg.pkg.tar.zst").kind, "Package");
  assert.equal(d("/home/u/a/README").kind, "Document");
  assert.equal(d("/home/u/a/thing.xyz").kind, "XYZ file");
  assert.equal(d("/home/u/a/thing.xyz").group, "other");
  assert.equal(d("/home/u/a/report.final.pdf").stem, "report.final");
  assert.equal(d("/home/u/Projects", true).icons[0], "folder");
  assert.equal(Files.displayPath("/home/u/Documents/x", HOME), "~/Documents/x");
  assert.equal(Files.displayPath("/etc/x", HOME), "/etc/x");
  assert.equal(Files.isImage(d("/home/u/a.png")), true);
  assert.equal(Files.isImage(d("/home/u/a.pdf")), false);
});

check("names JavaScript knows are just names", () => {
  const d = (p, dir) => plain(Files.describe(p, dir, HOME));
  assert.equal(d("/home/u/a/x.constructor").kind, "CONSTRUCTOR file");
  assert.equal(d("/home/u/a/x.constructor").group, "other");
  assert.equal(d("/home/u/a/x.__proto__").group, "other");
  assert.deepEqual(d("/home/u/constructor", true).icons, ["folder", "folder"]);
  assert.deepEqual(plain(Files.parseFd("/home/u/a/x.constructor\0/home/u/constructor/\0", [], HOME)).map((f) => f.kind), ["CONSTRUCTOR file", "Folder"]);
});

check("ranking", () => {
  const f = (p, dir) => Files.describe(p, dir, HOME);
  const exact = Files.score("taxes", f("/home/u/Documents/Taxes", true), HOME);
  const deep = Files.score("taxes", f("/home/u/code/app/src/lib/fixtures/taxes", true), HOME);
  assert.ok(exact > deep, `${exact} > ${deep}`);
  const byName = Files.score("invoice", f("/home/u/Documents/invoice.pdf"), HOME);
  const content = Object.assign(f("/home/u/Documents/march.pdf"), { fromContents: true });
  const byContent = Files.score("invoice", content, HOME);
  assert.ok(byName > byContent && byContent > 0, `${byName} > ${byContent} > 0`);
  assert.equal(Files.score("notes", content, HOME, false), 0, "a contents match for an older query doesn't count");
  assert.equal(Files.score("zebra", f("/home/u/Documents/invoice.pdf"), HOME), 0);
  assert.ok(Files.score("report", f("/home/u/Documents/Report 2024.docx"), HOME) > 700);
});

check("fd really runs", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "o-spotlight-"));
  fs.mkdirSync(path.join(dir, "Tax Returns"));
  fs.writeFileSync(path.join(dir, "Tax Returns", "tax 2024.pdf"), "x");
  fs.writeFileSync(path.join(dir, "notes.txt"), "x");
  fs.mkdirSync(path.join(dir, "node_modules"));
  fs.writeFileSync(path.join(dir, "node_modules", "tax.js"), "x");
  // Pipes and links aren't files or folders.
  execFileSync("/usr/bin/mkfifo", [path.join(dir, "tax-pipe.jpg")]);
  fs.symlinkSync(path.join(dir, "notes.txt"), path.join(dir, "tax-link.txt"));
  const argv = plain(Files.fdArgs("tax", { root: dir, limit: 50 }));
  const out = execFileSync(argv[0], argv.slice(1), { encoding: "utf8" });
  const found = plain(Files.parseFd(out, [], dir)).map((f) => path.relative(dir, f.path) + (f.isDir ? "/" : "")).sort();
  assert.deepEqual(found, ["Tax Returns/", "Tax Returns/tax 2024.pdf"]);
  const two = plain(Files.fdArgs("tax 2024", { root: dir }));
  const out2 = execFileSync(two[0], two.slice(1), { encoding: "utf8" });
  assert.deepEqual(plain(Files.parseFd(out2, [], dir)).map((f) => f.name), ["tax 2024.pdf"]);
  fs.rmSync(dir, { recursive: true });
});

console.log(`files: ${passed} checks passed`);
