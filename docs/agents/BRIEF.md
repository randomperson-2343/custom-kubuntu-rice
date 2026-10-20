# Shared brief for helper agents (Matrix 95 rice)

Project: a "Matrix" desktop rice for Kubuntu 26.04 (KDE Plasma 6.6, Qt 6,
KDE Frameworks 6, Wayland session). Owner's laptop: Lenovo LOQ. Three color
variants: green, cyan, amber. New layer being added: **"Matrix 95"**, a
Windows 95 look (chunky 3D bevels, solid title bars, Start button, taskbar)
recolored with the Matrix palettes (near-black faces, glowing ink edges).
It must read instantly as Windows 95 to anyone who used it, while looking like
it belongs in the Matrix. Do not copy Microsoft logos or artwork; homage only.

Repo: /home/user/custom-kubuntu-rice (read docs/superpowers/specs/2026-10-20-matrix-rice-design.md first).

## Palettes and templates

- `palettes/{green,cyan,amber}.sh` define colors. Templates use `{{KEY}}`
  placeholders filled by `render` in `lib/common.sh`. Unknown placeholders
  make render fail.
- Placeholders: `{{ID}}` (green), `{{NAME}}` (Green), `{{CMATRIX}}`, and for each
  key below: `{{KEY}}` = `#RRGGBB`, `{{KEY_RGB}}` = `r,g,b`, `{{KEY_SGR}}`.
  Also `{{C0}}`..`{{C15}}` (+ `_RGB`) terminal colors.
- Roles:
  - BG: desktop/window background (near black). SURFACE: panels, inputs.
  - FG: main ink (e.g. #00FF41). HEAD: brightest near-white ink. DIM: secondary
    text. FAINT: borders, disabled. ALERT: errors.
  - Windows 95 bevel set: FACE = "button face" (the classic #C0C0C0 role),
    HILITE = outer top-left highlight edge (classic white), LIGHT = inner
    top-left edge (classic #DFDFDF), SHADOW = inner bottom-right (classic
    #808080), DKSHADOW = outer bottom-right (classic #000000).
  - TITLE = active title bar fill (classic navy #000080), title text = HEAD.
    TITLE_INACTIVE + TITLE_INACTIVE_TEXT = inactive title bar.
- Render example (bash):
  `cd /home/user/custom-kubuntu-rice && MR_SRC=$PWD && . lib/common.sh && load_palette green && render templates/foo/bar.svg /tmp/x/bar.svg`

## Rules

- Only create/edit files inside the directories your task assigns you.
  Never edit lib/, palettes/, bin/, install.sh, uninstall.sh, rain/ or other
  agents' directories. If you need a change there, say so in your report.
- Do NOT git commit or push. The lead integrates and commits.
- Verify file formats against KDE's real source, not memory. invent.kde.org
  is NOT reachable; use the GitHub mirrors, e.g.
  `curl -sSfL https://raw.githubusercontent.com/KDE/<repo>/<branch>/<path>`
  (branches like `Plasma/6.6` for plasma repos, `master` otherwise) and the
  GitHub API for directory listings:
  `curl -sSfL https://api.github.com/repos/KDE/<repo>/contents/<path>?ref=<branch>`.
- You are root in an Ubuntu 24.04 container (no KDE desktop). `apt-get install -y`
  is allowed for test tools (e.g. librsvg2-bin, qt5-style-kvantum, python3-pyqt5).
  Qt 6.4 QML runner: `/usr/lib/qt6/bin/qml`, run with
  `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`. Python Pillow is installed.
  See tests/preview.qml and tests/sddm-preview.qml for offscreen render examples.
- Scratch files go in /tmp/claude-0/-home-user-custom-kubuntu-rice/0bbcca32-1dd4-5e60-ba76-c0d76a991f6d/scratchpad/<your-task>/.
- Render real previews and LOOK at them (the Read tool shows PNGs). Iterate
  until it genuinely looks like Windows 95 in Matrix colors. Save final previews
  for all three variants to docs/screenshots/<piece>-<variant>.png (keep each under ~300 KB).
- Write NOTES.md in your directory: every rendered file's install destination,
  exact config keys / commands to activate it, how to revert, and anything
  untested. Keep it short and exact; the lead turns it into installer code.
- Final report to the lead: files created, activation steps, test evidence,
  and known risks. Tag claims [Certain] / [Likely] / [Guessing].
