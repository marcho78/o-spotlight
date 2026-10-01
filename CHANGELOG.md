# Changelog

Every notable change to O-Spotlight is listed here, newest first. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version
numbers follow [Semantic Versioning](https://semver.org/).

## 1.0.1 - 2026-10-01

Fixes from a security review before the marketplace submission.

### Fixed

- **Pictures are checked before Qt opens them.** A pipe named like an image
  (some archives unpack them) could stall the shell's picture loading. Now no
  picture is shown until `stat` has said it's a regular file no bigger than
  its cap: file results and their thumbnails, theme previews, clipboard
  images, icons apps name by path, and the wallpaper.
- **File search lists files and folders only**, not links, pipes or devices.
- **Clipboard view:** a paste or copy looks the item up in the history right
  before Omarchy's paste reads it. A copy made while the view was open could
  shift the history so the wrong item was pasted.
- **Non-ASCII text** (file names, clipboard text, menu icons) can no longer
  be garbled when a character's bytes arrive in two pieces.
- **Recent files and menu files are read in linear time**: a crafted file
  could keep the shell busy for minutes.
- **The history is never written over after a failed read**, and a stopped
  save no longer leaves its temp file behind.

### Changed

- Omarchy's own menu checks and its hidden-apps script run in a fresh
  environment: `PATH=/usr/bin` and only the variables the checks read.
- Copied text goes to `wl-copy` on its stdin, out of its command line.
- The file helper hands files over as escaped JSON text (plain ASCII); the
  history may be up to 8 MiB, above the most O-Spotlight keeps.
- A menu check longer than 8 KiB isn't run (it was cut short); a menu file is
  read up to 5,000 rows.
- The clipboard history is read for the Clipboard view only, not on every
  open.
- Output budgets count bytes. Anything still running when O-Spotlight is
  turned off is stopped.
- Typed addresses with control characters aren't opened, and `HTTPS://` works.
- The `set` and `browse` commands limit their input, and `status` no longer
  reports what's typed.

## 1.0.0 - 2026-10-01

The first version.

### Added

- **The search.** Alt+Space, or the magnifying glass in the top bar, opens a
  Liquid Glass search bar in the macOS Tahoe style. It grows from a capsule
  into the results as you type and completes the Top Hit in the field. Filter
  chips sit under it, and four browse buttons spring out of it.
- **Results** from:
  - apps: the Omarchy launcher's list, without the apps it hides
  - every submenu and action in the Omarchy menu, including your own entries
    in `omarchy-menu.jsonc`
  - the top bar's Wi-Fi, Bluetooth, Sound, Displays and Battery panels
  - themes, with their previews
  - files and folders by name (`fd`), and documents by what's in them
    (LocalSearch)
  - a web search, with seven search engines to pick from
- **Answers as you type:** math with percentages, functions and constants
  (`1200*3+15%`, `sqrt 2`, `2pi`), and conversions (`10 km to mi`, `72°F`,
  `1 gb in mib`, `255 to hex`). Return copies the answer.
- **Learning** from what you open, and from what you picked for what you
  typed. It's kept in `~/.local/state/marcho78.o-spotlight/history.json`, and
  you can turn it off or clear it.
- **Browse views:**
  - Applications: a grid by category, most-used first
  - Files: suggestions and recents
  - Actions: everything Omarchy can do, by menu
  - Clipboard: Omarchy's history; Return pastes into the window you came from
- **Keyboard:**
  - ↑ ↓, Tab and Page Up/Down to move; → accepts the completion
  - Ctrl+Return or Ctrl+R shows a file in Files; hold Ctrl to see where files
    are
  - Ctrl+C copies, Ctrl+B searches the web, Ctrl+1–4 open the views, Ctrl+,
    opens settings
  - ↑ in an empty field brings back your last searches
  - `/pdf`, `/images`, `/apps` and the other filters narrow the results
- **Twelve styles, fully customizable** (Appearance › Style, or `set style`): Tahoe, and eleven
  from the "Omarchy spotlight app variations" designs:
  - six layouts, each with the empty bar drawn for it: Terminal (fzf in a
    box-drawn frame), Command strip (docked under the top bar, results
    sideways), Split preview (results and a preview with actions), Tiles (the
    Top Hit as a card beside tiles), Float (no panel, rows that fade) and
    Drawer (full height at the left, grouped by kind)
  - five finishes: Frosted, Island, Glow edge, Layered and Bento
  - every style searches, browses (Applications, Files, Actions, Clipboard),
    answers, welcomes and takes the keyboard exactly like Tahoe
- **Colors for the styles:** they follow your Omarchy theme (dark or light),
  or colors you pick for background, surface, text, secondary text and accent,
  with a color picker that opens from each color's chip.
- **Moving it:** drag the search bar, and it opens there next time.
- **A welcome panel** the first time you open it.
- **A settings window** with General, Search Results, Appearance and Privacy
  pages. It covers:
  - the shortcut
  - what's searched, the web search engine and excluded folders
  - the style, drawn in your colors, and whether it follows your theme
  - Tahoe's glass (liquid, frosted or solid) and light or dark
  - the selection style and highlight color (any `#rrggbb` too)
  - grid or list views, reduced motion, and learning
- **Commands:** `omarchy-shell o-spotlight` with `toggle`, `show`, `hide`,
  `search`, `browse`, `settings`, `set`, `reset` or `status`.
- **Hyprland setup** through `hyprctl eval` of `hypr/o-spotlight.lua`: the
  shortcut, a layer rule and a window rule, all removed when O-Spotlight is
  disabled.
  - A shortcut another binding already uses is left alone.
  - The settings window shows anything Hyprland refuses, including a key name
    it doesn't know.
- **Careful file access:** one small helper (`bin/o-spotlight-files`) does
  every file read and write: no symbolic links followed, owner, type and size
  checked, history written atomically into a private folder. Program paths
  are fixed, never taken from the environment.
- **Tests** for matching, the calculator, the Omarchy menu, files, ranking,
  settings, the styles and their colors, the Hyprland module, and the file
  helper (`tests/run`).
