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

1. **A focused panel/dock matches the context `Dock`.** Only the project
   panel and the terminal additionally have their own documented contexts
   (`ProjectPanel`, `Terminal`). **`GitPanel` and `AgentPanel` are NOT
   documented Zed 1.2.5 contexts** — do not rely on them. The git and agent
   panels are reached via the generic `Dock` context.
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
| `workspace::ToggleLeftDock` | show/hide the **left** dock (whatever panel is active there) |
| `workspace::ToggleRightDock` | show/hide the **right** dock |
| `workspace::ToggleBottomDock` | show/hide the **bottom** dock |
| `terminal_panel::Toggle` | show/hide the terminal (already a true toggle) |
| `workspace::IncreaseActiveDockSize` `{px:0}` | grow the focused dock along its axis |
| `workspace::DecreaseActiveDockSize` `{px:0}` | shrink it |
| `workspace::ResetActiveDockSize` | reset focused dock size |

Key point: **no single action both toggles a specific panel's visibility
and focuses it.** `*::ToggleFocus` focuses but never closes;
`Toggle*Dock` shows/hides a dock side but does not target a specific panel
or guarantee focus. This is a Zed 1.2.5 limitation, not a config bug.

---

## 5. The "same key opens+focuses / closes" pattern

Because of §4, one key needs **two** bindings at different tree levels:

```jsonc
// OPEN + FOCUS — fires when the editor (or empty workspace) is focused.
{ "context": "Editor && (vim_mode == normal || vim_mode == visual)",
  "bindings": { "space g g": "git_panel::ToggleFocus" } }
{ "context": "Workspace && !Editor",
  "bindings": { "space g g": "git_panel::ToggleFocus" } }

// CLOSE — fires when a panel/dock is focused. `Dock` is deeper than
// `Workspace`, so this WINS automatically when the git panel has focus.
{ "context": "Dock",
  "bindings": { "space g g": "workspace::ToggleLeftDock" } }
```

Behaviour produced:

- Editor focused, panel closed → `space g g` opens **and focuses** git.
- Editor focused, panel open but editor focused → `space g g` focuses git
  (1st press), `space g g` again now in `Dock` → **closes** (2nd press).
- Panel focused → `space g g` closes immediately (1 press).

This is the project-tree behaviour the user confirmed working; the same
shape applied via `Dock` makes git/agent/terminal behave identically.
The project tree keeps its own more-specific `ProjectPanel && not_editing`
block (so `q` to close works without clobbering inline-rename typing).

### Which dock-close action per panel (from this repo's `settings.json`)

| Panel | Dock side | Close action |
|---|---|---|
| project tree | left | `workspace::ToggleLeftDock` |
| git | left | `workspace::ToggleLeftDock` |
| agent | right | `workspace::ToggleRightDock` |
| terminal | bottom | `terminal_panel::Toggle` |

Note: project, git, outline and collaboration panels are all docked
**left** in `settings.json`. `ToggleLeftDock` hides whatever is the active
left panel — fine for "close what I'm looking at", but you cannot have the
git panel and project tree both left-docked and visible *and* independently
toggled by side-dock actions. If that matters, move git to a different dock
in `settings.json`.

---

## 6. Why the earlier attempts failed (root-cause log)

| Symptom | Real cause |
|---|---|
| Only project tree closed; git/agent just changed focus | close bound to **undocumented** `GitPanel` / `AgentPanel` contexts that don't match in 1.2.5; should be `Dock` |
| Resize did nothing | (a) bound in a `Dock` block I had **deleted** on bad info; (b) `IncreaseActiveDockSize` bound as bare string, missing required `{px:0}` arg |
| `space g g` / `alt-l` "just focus, never close" | close blocks placed before `Workspace` open block; but the deeper fix is **context level** (`Dock` > `Workspace`), not file order |
| Tooltips showed `ctrl-shift-*` | tooltips render the binding resolved **in the button's context**; our keys were editor-only so the button couldn't see them — fixed with a `Workspace && !Editor` mirror |

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

## 9. References

- Zed Key Bindings — <https://zed.dev/docs/key-bindings>
- Zed Vim Mode — <https://zed.dev/docs/vim>
- Installed version: `zed --version` → Zed 1.2.5 (Arch pkg `zed 1.2.5-2`)
