---
name: pin
description: Manage Vivek's session pins, the per-session bookmarks (files, URLs, click-to-copy commands, tmux panes) shown as a red 󰐃 count in the status line and in the alt+shift+P tmux popup. Use when Vivek says "pin X", "pin that", "pin this file/link/command", "unpin #3", "what's pinned", "move pin 2 to the top", or otherwise refers to pins or pinning.
---

# Session pins

`pin` (on PATH, `~/.local/bin/pin`) keeps a per-session list of links. Run it from Bash. It finds this
Claude session through `$TMUX_PANE` (pin's SessionStart hook maps pane → session id), so no flags are needed.

"Pin X" means `pin add`, not pinning a dependency version or a GitHub issue, unless he's
clearly talking about one of those.

| Vivek says | Run |
| --- | --- |
| pin a file or directory | `pin add <path> [label]` (relative paths are fine; becomes `file://`) |
| pin a URL | `pin add https://example.com [label]`: give the scheme; a bare domain is taken as a path |
| pin a command to copy later | `pin add --copy '<command>'` |
| pin another agent's pane | `pin add file:///tmux/<session>:<window>.<pane> [label]` |
| "pin that" | pin the file, link or command you last showed him |
| list pins | `pin ls` |
| unpin #n | `pin rm <n>` |
| reorder | `pin mv <n> <m>` |

Labels are optional: with none, pin derives one with the same glyph a chat link uses (󰍽 path,
󰆏 command, 󰇧 web). After a change, tell him what was pinned or unpinned in one line.

If `pin` says "no session", Claude was started outside tmux or before the hook existed. Say so;
`pin --session <id> ...` works with this session's id.

He opens the list himself with alt+shift+P (enter opens, J/K reorder, x cuts, u undoes).
More detail: `pin --help`.
