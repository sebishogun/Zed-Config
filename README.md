# editor-dotfiles

One repo, one command — consistent nvim-style keybindings and settings
across **Neovim, Zed, JetBrains (IntelliJ IDEA / GoLand / …) and the
VSCode family (VS Code, Cursor, Windsurf, Antigravity, VSCodium)**, with a
cross-platform idempotent Go installer.

Repo: `github.com/sebishogun/Zed-Config`

## Quick start

```sh
git clone https://github.com/sebishogun/Zed-Config.git
cd Zed-Config
make install        # set up every editor, install missing ones, idempotent
```

Subsets / preview:

```sh
make zed            # or: jetbrains | vscode | nvim
make dry            # show actions, change nothing
make help           # all targets
```

## Layout

```
zed/config/         settings.json, keymap.json   -> ~/.config/zed/
zed/docs/           Zed 1.2.5 keymap guide
jetbrains/.ideavimrc                              -> ~/.ideavimrc   (all JetBrains IDEs)
vscode/             settings.json, keybindings.json -> each installed fork's User/
nvim/               full Neovim (LazyVim) config  -> ~/.config/nvim
installer/          single Go binary, all targets
Makefile
```

## How it works

`make install` runs the Go installer which, per target:

- **Detects the OS/distro** and package manager (pacman/apt/dnf/zypper/apk
  · brew · winget).
- **Installs the editor if missing** (Zed, Neovim). JetBrains IDEs and
  VSCode forks are not auto-installed — config is linked for whichever are
  present.
- **Symlinks configs from this repo** into each editor's real config
  location, so edits here are live everywhere and `git pull` updates all
  machines.

### Idempotent & safe

Re-running is safe:

- Config already symlinked to this repo → skipped.
- A real (non-symlink) file/dir at the target → moved to
  `*.bak-<timestamp>` before the symlink is made. Nothing is overwritten.

## Keybindings (shared scheme, leader = `space`)

| Intent | nvim / Zed / JetBrains / VSCode |
|--------|--------------------------------|
| Find files (name) | `space ff` / `space space` |
| Search text in current file | `space /` |
| Search text across project (IDEA "Search Everywhere" / Find-in-Path) | `space sg` |
| Replace: file / project | `space sr` / `space sR` |
| File tree | `space e` |
| Git panel | `space gg` |
| Terminal | `ctrl-/` |
| Buffers | `S-h` / `S-l`, close `space bd` |
| LSP | `gd` `gr` `gI` `K`, `space ca/cr/cf` |
| Diagnostics | `]d` / `[d`, `space xx` |
| Debugger | `space db/dc/ds/do/di/dO/dt/du` |
| Pane focus | `ctrl-h/j/k/l` |
| Dock resize | `ctrl-alt-arrows` |

Per-editor specifics (Zed contexts, IdeaVim `:action` names, VSCodeVim
command IDs) live in each editor's files; the Zed model is documented in
`zed/docs/zed-1.2.5-keymap-guide.md`.

## Platform support

| OS | Editor install | Config path |
|----|----------------|-------------|
| Linux (arch/debian/fedora/suse/alpine) | distro pkg mgr | `~/.config/...`, `~/.ideavimrc` |
| macOS | Homebrew | `~/.config/zed`, `~/Library/Application Support/<fork>/User`, `~/.ideavimrc` |
| Windows | winget | `%APPDATA%`, `%LOCALAPPDATA%\nvim`, `~/.ideavimrc` |
