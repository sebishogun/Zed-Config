# Zed 1.2.5 Keymap & Panel-Toggle Guide

Authoritative reference for how keybindings, contexts, and panel/dock
toggling are *supposed* to work in **Zed 1.2.5**, and the design this repo's
`config/keymap.json` follows. Sourced from the official Zed docs
(`zed.dev/docs/key-bindings`, `zed.dev/docs/vim`), not guesswork.

---

## 1. The context tree

> "Zed's contexts make up a tree, with the root being `Workspace`.
> Workspaces contain Panes and Panels, and Panes contain Editors."

```
Workspace                      (root — least specific)
├── Panel  → matches context: Dock          (project tree, git, agent, terminal…)
│            ProjectPanel / Terminal also exist for those two specifically
└── Pane
    └── Editor                 (deepest — most specific)
                               + vim_mode is set HERE only
```

Two facts that decide everything:

1. **Each panel has its own real context.** Verified by extracting Zed
   1.2.5's own default keymap (from the `zed-industries/zed` repo at the
   `v1.2.5` tag, cross-checked against the installed binary's embedded
   assets): `ProjectPanel`, `GitPanel`, `AgentPanel`, `Terminal` all
   exist. The docs *website* only lists `ProjectPanel`/`Terminal`/`Dock`,
   but `GitPanel`/`AgentPanel` are real (22 string hits each in the
   binary; full binding blocks present in the repo keymap). The generic
   `Dock` context also exists but the specific ones are preferred.
2. **`vim_mode` only exists at the `Editor` level.** `"Workspace &&
   vim_mode == normal"` can never match. Leader binds that need vim mode
   must use an `Editor` context.

---

## 2. Resolution algorithm (why a key does what it does)

When several bindings match the same keystroke, Zed picks the winner in
this exact order:

1. **Context specificity — lower node in the tree wins.**
   > "Bindings that match on lower nodes in the context tree win… a binding
   > with a context of `Editor` takes precedence over a binding with a
   > context of `Workspace`. Bindings with no context match at the lowest
   > level."

   So: `Editor` > `Dock`/`Pane` > `Workspace` > (no context).
   `ProjectPanel` is more specific than `Dock`.

2. **File order — last wins, but only at the *same* level.**
   > "If there are multiple bindings that match at the same level… the
   > binding defined later takes precedence. As user keybindings are loaded
   > after system keybindings, this allows user bindings to take precedence."

3. **Prefix wait.** If `ctrl-w` and `ctrl-w left` both exist, Zed waits 1s
   after `ctrl-w` for a possible `left`.

Consequence for us: a **close** bind in `Dock` automatically beats an
**open** bind in `Workspace` — no need to reorder blocks. Ordering only
matters between blocks at the *same* tree level.

---

## 3. keymap.json structure

```json
[
  { "bindings": { "ctrl-x": "action::Name" } },          // always active
  {
    "context": "ProjectPanel && not_editing",             // conditional
    "bindings": { "q": "workspace::ToggleLeftDock" }
  }
]
```

### Context predicate syntax

| Operator | Meaning |
|---|---|
| `X && Y`, `X \|\| Y` | logical and / or |
| `!X` | negation |
| `(X)` | grouping |
| `X > Y` | an ancestor matches `X` **and** this node matches `Y` |
| `attr == val` | attribute equality (`vim_mode == normal`, `os == macos`, `mode == full`) |

Attributes are **only readable on the node where they are set** (e.g.
`vim_mode` on `Editor`). Matching is one level at a time.

### Action argument syntax

| Form | Example |
|---|---|
| no args (string) | `"language_selector::Toggle"` |
| one positional arg | `["workspace::ActivatePane", 0]` |
| object args | `["workspace::IncreaseActiveDockSize", { "px": 0 }]` |

`IncreaseActiveDockSize` / `DecreaseActiveDockSize` **require** the
`{ "px": 0 }` object (0 = Zed's default font-scaled step). Bound as a bare
string they are a no-op.

---

## 4. Panel & dock action reference (1.2.5)

| Action | Effect |
|---|---|
| `project_panel::ToggleFocus` | open + focus project tree if closed/unfocused; on second press returns focus to editor — **does NOT close the dock** |
| `git_panel::ToggleFocus` | same pattern for the git panel |
| `agent::ToggleFocus` | same pattern for the agent panel |
| `workspace::CloseActiveDock` | **close the currently focused dock/panel — side-agnostic. THIS is the correct close action.** Zed binds it to `ctrl-w`/`ctrl-f4` by default |
| `workspace::ToggleLeftDock` | show/hide the **left** dock (whatever panel is active there) — avoid for "close focused panel" on shared docks |
| `workspace::ToggleRightDock` | show/hide the **right** dock |
| `workspace::ToggleBottomDock` | show/hide the **bottom** dock |
| `terminal_panel::Toggle` | show/hide the terminal (already a true toggle) |
| `workspace::IncreaseActiveDockSize` `{px:0}` | grow the focused dock along its axis |
| `workspace::DecreaseActiveDockSize` `{px:0}` | shrink it |
| `workspace::ResetActiveDockSize` | reset focused dock size |

Key point: **no single action both toggles a specific panel's visibility
and focuses it.** `*::ToggleFocus` focuses but never closes. The correct
close is **`workspace::CloseActiveDock`** — it closes the focused dock
regardless of side, so it works even when project + git share the left
dock. `Toggle*Dock` (side-specific) is the wrong tool for this.

---

## 5. The "same key opens+focuses / closes" pattern

One key, **two** bindings at different tree levels:

```jsonc
// OPEN + FOCUS — editor (or empty workspace) focused.
{ "context": "Editor && (vim_mode == normal || vim_mode == visual)",
  "bindings": { "space g g": "git_panel::ToggleFocus" } }
{ "context": "Workspace && !Editor",
  "bindings": { "space g g": "git_panel::ToggleFocus" } }

// CLOSE — fires when the panel itself is focused. The panel context is
// more specific than Workspace, so this wins automatically.
{ "context": "GitPanel && !CommitEditor",
  "bindings": { "escape": "workspace::CloseActiveDock",
                "q": "workspace::CloseActiveDock" } }
```

Two close strategies, picked per panel:

**A. Aligned-action toggle (agent).** Bind the key to the *exact action
the panel's button dispatches*. The agent button dispatches
`workspace::ToggleRightDock` (its old default key was `ctrl-alt-b` — that
is what the tooltip showed). Agent is the **sole right-dock panel**, so
`alt-l → workspace::ToggleRightDock` opens *and* closes it with one key,
and because it is the button's own action the tooltip now reads `alt-l`
(after nulling `ctrl-alt-b`). This is the cleanest pattern and is only
possible when a panel owns its dock side.

**B. CloseActiveDock at the exact default context (git, project tree).**
For shared docks, close with `workspace::CloseActiveDock` (focused dock,
side-agnostic). Critical: bind it in the **same context string Zed's
default uses**, so the user keymap wins the same-level tie. Git's list
context is exactly `GitPanel && ChangesList && !GitBranchSelector` and its
default `escape` = `git_panel::ToggleFocus` (only unfocuses) — a 2-term
context like `GitPanel && !CommitEditor` is *less specific* and loses to
it, which is why earlier git-close attempts failed.

| Panel | Context | Close keys | Action |
|---|---|---|---|
| project tree | `ProjectPanel && not_editing` | `space e`, `q`, `escape` | `workspace::CloseActiveDock` |
| git | `GitPanel && ChangesList && !GitBranchSelector` **and** `GitPanel && !CommitEditor` | `escape`, `q` | `workspace::ToggleLeftDock` |
| agent | `Workspace` + all agent contexts | `alt-l`, `escape` | `workspace::ToggleRightDock` |
| terminal | `Terminal` | `ctrl-/` | `workspace::CloseActiveDock` |

Each panel's close action = **the exact action its own collapse button
dispatches** (proven by the button tooltip): git button → `ToggleLeftDock`
(tooltip was `ctrl-b`); agent button → `ToggleRightDock` (tooltip was
`ctrl-alt-b`). Bind your key to that action across every context the panel
can be focused in, and `null` the stale default key so the tooltip
updates. Git needs two context blocks because focus opens in the **commit
editor**, not the changes list — a single changes-list binding never
fires; `git::ToggleFocus`/`git::Cancel` defaults run instead and only
unfocus, never close.

Both actions are Zed-sanctioned: `CloseActiveDock` defaults to `ctrl-w`/
`ctrl-f4`; `ToggleRightDock` defaults to `ctrl-alt-b` — all in `Workspace`.

### Tooltips

A panel button's tooltip shows the key bound to *that button's action* in
the button's context. To make it show our key: bind our key to that exact
action **and** `null` the competing default. We null `ctrl-alt-b`
(→ agent tooltip = `alt-l`), `ctrl-shift-g` and `ctrl-shift-e` (→ git /
project tooltips fall back to our `space g g` / `space e`).

---

## 6. Why the earlier attempts failed (root-cause log)

| Symptom | Real cause |
|---|---|
| Only project tree closed; git/agent just changed focus | (1) default `AgentPanel` binds `alt-l → agent::CycleFavoriteModels` and `AgentPanel` is deeper than our `Workspace` bind → default ate `alt-l`. (2) git: default `escape` lives in the 3-term `GitPanel && ChangesList && !GitBranchSelector`; our 2-term `GitPanel && !CommitEditor` was *less specific* and lost. Fix: align agent to its button action (`ToggleRightDock`) + override git at Zed's **exact** context string |
| Agent tooltip showed `ctrl-alt-b` | that is `workspace::ToggleRightDock`'s default key — the agent button's action. Binding `alt-l` to the same action + nulling `ctrl-alt-b` makes the tooltip read `alt-l` |
| Earlier "GitPanel/AgentPanel undocumented, use Dock" claim | wrong — those contexts are real (verified in binary + repo). The docs *website* is just incomplete. Always confirm against `zed: open default keymap` or the repo at the version tag |
| `space g g` won't close from a git file row | `GitPanel && ChangesList` binds `space → git::ToggleStaged`; Zed reserves it. Use `escape`/`q` to close git |
| Resize did nothing | `IncreaseActiveDockSize` needs `{px:0}`; bare string is a no-op. Lives in `Workspace` (no `Dock` context needed) |
| Tooltips showed `ctrl-shift-*` / "super" | tooltips render the binding resolved in the button's context (fixed via `Workspace && !Editor` mirror); "super" came from `cmd-*` binds on Linux — all `cmd`/`super` bindings removed |

Lesson: trust the documented context list. `ProjectPanel`, `Terminal`,
`Dock`, `Editor`, `Pane`, `Workspace`, plus attributes `vim_mode`,
`not_editing`, `mode == full`, `os == macos`. Treat anything else as
unverified until confirmed via `zed: open default keymap`.

---

## 7. This repo's binding map (target design)

Leader = `space`. Vim mode on.

| Keys | Action | Notes |
|---|---|---|
| `space space`, `space f f` | file finder | centered palette |
| `space ;` | command palette | |
| `space s s` / `space s S` | file outline / project symbols | palettes |
| `space ,` | tab switcher | |
| `space f p` | recent projects | |
| `space e` | project tree open+focus / close | `ProjectPanel && not_editing` for close + `q` |
| `space g g` | git panel open+focus / close | close via `Dock` |
| `alt-l` / `cmd-l` | agent panel open+focus / close | close via `Dock` → `ToggleRightDock` |
| `ctrl-/`, `ctrl-\``, `cmd-/` | terminal toggle | already a true toggle |
| `space g B` | git branches | centered palette |
| `space g b` / `space g d` | git blame / hunk diff | editor |
| `] h` / `[ h` | next / prev hunk | |
| `space d b/c/s/o/i/O/p/t/r` | debugger (LazyVim-style) | |
| `f5/f9/f10/f11` (+shift/ctrl) | debugger F-keys | |
| `shift-h` / `shift-l` | prev / next tab | |
| `ctrl-h/j/k/l` | pane navigation | nvim-style |
| `ctrl-alt-arrows` | resize focused dock | needs `{px:0}` |
| `ctrl-alt-0`, `space w =` | reset dock size | |
| `space /` / `space s g` | buffer search / project search | top bar / pane (no centered palette in Zed) |
| `space x x` | diagnostics | opens as an editor tab |

---

## 8. Troubleshooting

- **See the real defaults for *your* build:** command palette →
  `zed: open default keymap`. This is the only 100%-accurate action/context
  list for the installed version.
- **Edit live:** `zed: open keymap` (or `ctrl-k ctrl-s`).
- **Reload:** keymap hot-reloads on save; force with `zed: reload keymap`.
- **Logs:** `~/.local/share/zed/logs/Zed.log`. Keymap parse/context errors
  appear here; an invalid context can make Zed reject changed bindings.
- **Verify a binding resolved:** hover the relevant UI button — the tooltip
  shows the keystroke Zed resolved for that action *in that context*.

---

## 9. OS awareness & the no-cmd/super policy

Zed loads **one** user `keymap.json` — there is no per-OS keymap file.
Cross-OS differences are expressed *inside* that file with the `os ==`
context attribute (`os == macos`, `os == linux`, `os == windows`),
optionally combined: `"os == macos > Editor"`.

**Policy for this repo: never bind `cmd` (or `super`).** On Linux the
`cmd` modifier renders and binds as the **Super** key, which is reserved
for the Omarchy / Hyprland window manager — binding it both steals WM
shortcuts and shows "super" in Zed tooltips. We bind `ctrl`-based keys
only. If macOS support is ever needed, add a separate block guarded by
`"context": "... && os == macos"` with `cmd-*` keys there — never in the
shared/default blocks. Today there are zero `cmd`/`super` bindings.

---

## 10. References

- Zed Key Bindings — <https://zed.dev/docs/key-bindings>
- Zed Vim Mode — <https://zed.dev/docs/vim>
- Default keymap (ground truth) — `zed-industries/zed` repo,
  `assets/keymaps/default-linux.json` at the `v1.2.5` tag; or
  `zed: open default keymap` in the app
- Installed version: `zed --version` → Zed 1.2.5 (Arch pkg `zed 1.2.5-2`)
