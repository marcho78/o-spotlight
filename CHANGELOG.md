# Changelog

Every notable change to O-Spotlight is listed here, newest first. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version
numbers follow [Semantic Versioning](https://semver.org/).

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
