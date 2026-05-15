# zed-config

Portable [Zed](https://zed.dev) config mirroring my LazyVim keybindings, plus a
cross-platform idempotent installer.

## Layout

```
config/
  settings.json   # editor settings (vim mode, JetBrains base keymap, theme)
  keymap.json      # leader bindings: search, panels, git, debugger, LSP
installer/
  main.go          # platform detection + idempotent install/link (stdlib only)
Makefile           # quick commands
```

## Quick start

```sh
make install      # install Zed if missing, symlink config (safe to re-run)
make dry          # preview actions, change nothing
make link         # only relink config
make help         # list all targets
```

## Idempotency

Re-running `make install` is safe:

- Zed already on `PATH` (`zed` or `zeditor`) → install skipped.
- Config file already symlinked here → left untouched.
- A real (non-symlink) `settings.json`/`keymap.json` → moved to
  `*.bak-<timestamp>` before the symlink is created. Nothing is overwritten.

## Platform support

| OS | Mechanism |
|----|-----------|
| Arch | `pacman -S --needed zed` |
| Debian/Ubuntu | `apt-get install zed` |
| Fedora | `dnf install zed` |
| openSUSE | `zypper install zed` |
| Alpine | `apk add zed` |
| macOS | `brew install --cask zed` |
| Windows | `winget` → `scoop` → `choco` |
| unknown Linux | `curl https://zed.dev/install.sh \| sh` |

Distro chosen from `/etc/os-release` (`ID`, then `ID_LIKE`), falling back to
whichever package-manager binary is on `PATH`.

## Keybindings

Leader = `space` (matches LazyVim). Highlights:

| Keys | Action |
|------|--------|
| `space space` / `space f f` | file finder |
| `space /` | project search |
| `space e` | project panel |
| `space ,` | buffer/tab switcher |
| `space g g` | git panel |
| `space g b` / `space g d` | git blame / hunk diff |
| `space d b` / `f9` | toggle breakpoint |
| `f5` / `f10` / `f11` | debug continue / step over / step into |
| `alt-l` | agent panel |
| `ctrl-/` | terminal |
| `shift-h` / `shift-l` | prev / next tab |

Debugger and agent action names shift between Zed versions. If a binding
errors, run `zed: open default keymap` from the command palette and copy the
current action name.

## Not ported

LazyVim Harpoon (`<leader>a`, `<leader>1..0`) has no native Zed equivalent.
Use the tab switcher (`space ,`) instead.
