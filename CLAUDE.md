# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A fork of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — the "illogical-impulse" Hyprland rice. It is *configuration files plus a custom Quickshell-based graphical shell*, not a system installer. Upstream wiki: https://github.com/end-4/dots-hyprland-wiki (rendered at https://ii.clsty.link).

The repo layout:
- `dots/` — files that get copied into `$HOME` (`.config/`, `.local/share/`). This is where almost all real code lives.
- `dots-extra/` — optional add-ons (emacs, fcitx5, swaylock, via-nix) not installed by default.
- `sdata/` — data and scripts consumed by the top-level `setup` dispatcher (subcommands, lib helpers, distro-specific package lists, uv venv).
- `setup` — bash entrypoint that sources `sdata/subcmd-<name>/` for each subcommand (`install`, `uninstall`, `exp-update`, `exp-merge`, `checkdeps`, `virtmon`, `resetfirstrun`).
- `diagnose` — user-facing diagnostic collector.

## Fork conventions (important)

- **Remotes:** `upstream` = `end-4/dots-hyprland`, `origin` = `KemonoNeco/dots-hyprland`.
- **Branching:** `main` is a pristine mirror of `upstream/main` — fast-forward only, never commit to it. *All personal work lives on `KemonoNecoTweaks`*, which stays current by **merging** `main` into it (never rebasing — merges keep past conflict resolutions so each update only conflicts on genuinely new overlaps). Upstreamable fixes go on a `fix/*` branch off `main` and get PR'd from there, so `main` stays fast-forwardable. `git diff main KemonoNecoTweaks` is therefore always exactly "what this fork changes".
- **`.claude/` and `CLAUDE.md` handling:** `main` ignores both via `.gitignore` and does not track them; `KemonoNecoTweaks` tracks both. If you're reading this file, you're on `KemonoNecoTweaks` (or on a detached checkout with a stale working copy) — `CLAUDE.md` does not exist in `main`'s tree. Don't "fix" the diverging `.gitignore` by making them match, and don't port this file to `main` — the divergence is intentional so upstream-facing branches stay clean.
- **Upstream PRs:** Follow upstream's rule of one feature per PR. Don't bundle personal/default changes into fix PRs. See `.github/CONTRIBUTING.md`.

## The Quickshell configuration (the bulk of the code)

`dots/.config/quickshell/ii/` is a Quickshell (QtQuick/QML) shell. When copied to `~/.config/quickshell/ii`, it is launched with `qs -c ii`.

Top-level structure:
- `shell.qml` — `ShellRoot`. Loads one of two "panel families" via `PanelFamilyLoader`, toggled by `Config.options.panelFamily` (`"ii"` or `"waffle"`). Cycle with `qs -c ii ipc call panelFamily cycle` or `Super+Alt+W`.
- `panelFamilies/` — each family (`IllogicalImpulseFamily.qml`, `WaffleFamily.qml`) is a `Scope` that mounts every panel (bar, dock, overview, sidebars, lock, polkit, OSD, etc.) as a `PanelLoader`.
- `modules/ii/` and `modules/waffle/` — the per-family panels. Each subfolder is a panel (bar, dock, sidebarLeft, sidebarRight, overview, cheatsheet, lock, polkit, onScreenDisplay, mediaControls, …).
- `modules/common/` — cross-family building blocks:
  - `Config.qml` (Singleton) — all user-facing options, persisted as JSON to `~/.config/illogical-impulse/config.json` via `FileView` + `JsonAdapter`. Adds on-write debouncing (`readWriteDelay`). Read options as `Config.options.<group>.<key>`.
  - `Appearance.qml` (Singleton) — Material 3 color roles, animation curves, sizing; derives `backgroundTransparency`/`contentTransparency` from wallpaper vibrancy.
  - `Directories.qml` (Singleton) — canonical paths: `shellConfig`, `aiChats`, `userActions`, `userAiPrompts`, generated theme paths, temp dirs. Shell-owned `/tmp/quickshell/...` dirs are recreated in `Component.onCompleted`.
  - `widgets/` — the component library (buttons, material shapes, circular progress, dialog primitives, etc.). Reuse these; don't re-roll.
  - `widgets/shapes/` is a **git submodule** (`end-4/rounded-polygon-qmljs`) — run `git submodule update --init` after cloning.
- `modules/settings/` — the settings GUI (backed by `Config`).
- `services/` — singleton QML services (`Ai.qml`, `Audio.qml`, `Network.qml`, `Notifications.qml`, `HyprlandData.qml`, `Wallpapers.qml`, `MaterialThemeLoader.qml`, …). Panels consume these; don't spawn side processes from panels when a service already exists.
- `scripts/` — the shell out to bash/python for things QML can't do itself (`colors/` for Material generation via matugen/kde-material-you-colors, `ai/`, `images/`, `thumbnails/`, `videos/`, `kvantum/`, `musicRecognition/`).
- `translations/` + `translations/tools/` — JSON-backed i18n. Source strings are extracted from `Translation.tr("…")` calls. See the workflow below.
- `assets/`, `defaults/ai/`, `GlobalStates.qml`, `settings.qml`, `welcome.qml`, `ReloadPopup.qml`, `killDialog.qml` — global state, default prompts, and one-shot windows.

Conventions from `.github/CONTRIBUTING.md` (follow these):
- **Dynamic loading:** gate optional UI behind `Loader` — the anchor/positioning must live on the `Loader`, not the inner component. For fade-on-hide use `FadeLoader` with its `shown` prop instead of `active`/`visible`.
- **Don't over-nest.** Prefer early return (`if (!cond) return; doStuff();`) and define inline `component`s rather than spawning tiny files.
- **Keep it practical.** Fancy-but-heavy must be off by default and guarded by a config option.
- **QML formatting:** 4-space indent, `MaxColumnWidth=110`, `ObjectsSpacing=true`, `NormalizeOrder=false` (see `.qmlformat.ini`). Use `qmlformat` against that file.

## The Hyprland configuration

`dots/.config/hypr/` layout matters:
- `hyprland.conf` — entrypoint, sources everything from `hyprland/` and then `custom/`.
- `hyprland/` — the upstream-managed rice config (`keybinds.conf`, `rules.conf`, `general.conf`, `env.conf`, `execs.conf`, `colors.conf`, `variables.conf`, `scripts/`, `shellOverrides/`).
- `custom/` — **user overrides**, loaded last so user-defined binds/rules/variables win. When adding fork-specific behavior that shouldn't diverge from upstream in `hyprland/`, prefer `custom/`.
- `hyprlock.conf`, `hypridle.conf`, `monitors.conf`, `workspaces.conf` — self-explanatory.

## Commands

### Fork maintenance (`./fork`)

Fork-local helper (not upstream's). Keeps this branch current with upstream and keeps the repo and `$HOME` from silently drifting apart.

```bash
./fork status    # ahead/behind counts, deploy state, repo-vs-$HOME drift
./fork update    # fetch upstream -> ff main -> merge main into KemonoNecoTweaks
./fork capture   # $HOME -> repo, for edits made directly in ~/.config
./fork deploy    # repo -> $HOME, for the paths ./setup won't overwrite
```

`DOTS_FORK_BRANCH` overrides the tweaks branch name.

The `MINE` array in `fork` lists the paths this fork owns in `$HOME`: `.config/hypr/custom`, `.config/hypr/monitors.lua`, `.config/illogical-impulse/config.json`, `.config/quickshell/ii`. Upstream's installer deliberately refuses to overwrite most of those (`custom/` is `skip-if-exists`, `hypridle.conf`/`hyprlock.conf` are `soft-backup` and land as `*.new`), which is why `deploy` exists — in a fork the repo is the source of truth for them. Everything else under `dots/` still reaches `$HOME` via `./setup install-files`.

Both directions rsync with `--delete` and skip runtime/generated files (`*.new`, `*.old`, `.qmlls.ini`, `custom/scripts/__restore_video_wallpaper.sh`). matugen outputs (`hypr/hyprland/colors.lua`, `hyprlock/colors.conf`, `fuzzel_theme.ini`, `gtk-*/gtk.css`) are outside `MINE` on purpose — they regenerate per wallpaper and would churn on every capture. `.config/fish/conf.d` is also outside `MINE` on purpose: it holds machine-local secrets (API keys) that must not reach a public fork.

`deploy` records the deployed commit in `~/.local/state/dots-fork/deployed-sha`; `capture` refuses to run when `$HOME` is older than `HEAD` (which would revert freshly merged upstream files) unless given `--force`. `capture` requires a clean tree, so `git restore .` always undoes one.

Typical update cycle:
```bash
./fork capture && git commit -am "capture live config"   # if you edited ~/.config directly
./fork update                                            # resolve conflicts if any
./fork deploy && ./setup install-files                   # push it all back out
pkill qs; qs -c ii                                       # restart the shell
git push origin main KemonoNecoTweaks
```

### Install / update (on a real machine)
```bash
./setup install          # full install
./setup install-deps     # deps only
./setup install-setups   # systemd/permissions only
./setup install-files    # copy dotfiles only
./setup exp-update       # incremental update (experimental)
./setup exp-merge        # merge upstream via git rebase (experimental)
./setup uninstall
./setup <sub> -h         # per-subcommand help
./setup checkdeps        # (dev) verify package names exist on Arch
./setup virtmon          # (dev) create virtual monitors for multi-monitor testing
./diagnose               # collect env info for bug reports
```

### Running / iterating on the shell
```bash
pkill qs; qs -c ii              # restart the shell; QML edits auto-reload
qs -c ii ipc call panelFamily cycle   # toggle ii <-> waffle family
touch ~/.config/quickshell/ii/.qmlls.ini   # one-time qmlls LSP setup
```

### Translations (`dots/.config/quickshell/ii/translations/tools/`)
```bash
./manage-translations.sh status
./manage-translations.sh extract
./manage-translations.sh update [-l <lang>]
./manage-translations.sh clean            # prune unused keys (creates .backup)
./manage-translations.sh sync             # align keys across langs (en_US is base)
```
Only `Translation.tr("…")` / `'…'` / `` `…` `` literals are extractable. Dynamic strings must be added manually and annotated with `/*keep*/` in the value so `clean`/`sync` won't drop them.

### Python (anything under `sdata/uv/`)
Packages are installed into `$ILLOGICAL_IMPULSE_VIRTUAL_ENV` (default `~/.local/state/quickshell/.venv`), **not** system pip. To add a dep: edit `sdata/uv/requirements.in`, then in that folder run:
```bash
uv pip compile requirements.in -o requirements.txt
```
To run a python script from QML/shell, either use the venv-activating shebang trick or wrap with a small bash script that `source`s `$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate` before `exec`ing. See `sdata/uv/README.md` for the full pattern.

## Gotchas

- Editing `Config.qml` properties changes the persisted JSON shape. Missing fields get written on next run; renamed fields silently reset — migrate carefully.
- `Directories.qml`'s `Component.onCompleted` `rm -rf`s several `/tmp/quickshell/...` dirs on startup. Don't stash anything there expecting persistence.
- `modules/common/widgets/shapes` is a submodule; fresh clones without `--recurse-submodules` will have broken shape imports.
- The shell runs under plain Hyprland, not `uwsm`-managed Hyprland (per `CONTRIBUTING.md`).
- `cache/` and `diagnose.result` at repo root are gitignored build/runtime artifacts.
