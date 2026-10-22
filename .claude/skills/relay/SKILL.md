---
name: relay
description: Find which Claude agent (another Claude Code session in Vivek's tmux) owns a task, and pass it a message. Use when Vivek says "relay this to the X agent", "tell the lighting claude…", "send this to robofab", "ask the lander agent…", "let the autolabel one know", or otherwise refers to another agent by its tmux session, window, repo, branch, or task rather than its peer name.
---

# Relay to another agent

Vivek runs one Claude per task, spread across tmux sessions (named after repos: `robocore`, `lander`, …), windows (sometimes named after the task: `autolabel`, `lighting`), and panes (named after the running command, so a pane name only tells you that it's `claude`). He refers to an agent by whichever handle comes to mind: the repo, the window name, the topic, or the branch. Your job is to turn that handle into a peer name and send with `SendMessage`.

Only relay when Vivek asks you to. Never message a sibling session on your own initiative, even when you think it would help: tell Vivek instead and let him decide. Replying to a message a sibling sent you is fine, and so is talking with your own subagents or parent.

## 1. Find the agent

```bash
~/.claude/skills/relay/agents.py [terms...]
```

Output, one live Claude per line:

```
robocore-3f    busy  file:///tmux/robocore:2.1  [lighting] Lighting shadows and light source nodes  — robocore @main
<peer name>  status  <pane link> [window name if hand-set] <task title>  — <dir or wt:worktree> @<branch>
```

- The **peer name** (first column) is what `SendMessage` takes as `to`.
- The **task title** is Claude's own session title, read from the pane title. It's usually the best match for "the X agent".
- `[window name]` appears only when Vivek renamed the window by hand, so it's a strong, deliberate signal. Auto-generated names (path + command) are dropped as noise.
- `wt:<name>` means the agent works in a worktree under `.claude/worktrees/`. The worktree name is the task name.
- With terms, rows are ranked by how many fields contain each term (case-insensitive). If nothing matches, all rows are printed. `--json` gives full fields (`pane_id`, `session_id`, …).
- Your own row is marked `(you)`. Never relay to yourself.

Pass a word or two from Vivek's handle as terms, e.g. "the lighting agent" → `agents.py lighting`. Use the full listing when the handle is vague.

## 2. Resolve the match

Weigh the signals in this order: hand-set window name, task title, worktree or branch, tmux session (repo), directory.

- **One clear match:** send. Don't ask.
- **Several matches:** use the content being relayed to break the tie. Example: `autolabel` matches both `robocore-0a` ("Autolabelling PR review suggestions") and `robofab-a4` ("Robocore autolabelling PR"). A note about the robocore code under review goes to `robocore-0a`; a note about vendoring it into robofab goes to `robofab-a4`. A session name alone ("the robocore agent") is ambiguous whenever that session has more than one Claude.
- **Still ambiguous, or no match:** ask Vivek, describing each candidate in plain words (see "Naming agents to Vivek" below). Use the `lmk` skill first.
- **Relay to "all" / "everyone" in a repo:** send one message to each match.

## 3. Write the message

The recipient has none of your context. Make the message standalone:

- Make the first line a standalone sentence saying who it's from and what it's about. The recipient's human sees only that line until they expand the message. Example: `From the dotfiles agent (~:1), at Vivek's request: the autolabel PR needs a rebase.`
- Include the actual content: paths, commit SHAs, numbers, error text. Don't write "see above" or "the thing we discussed".
- Quote Vivek's words verbatim when he dictated them. Summarize only when he asked you to pass along your own findings.
- Say what you want back, if anything ("reply when the PR is updated"). Asking for a reply is what permits the recipient to message you. Without that, it shouldn't send you anything.
- Paths should be absolute. For long material (logs, diffs), write a file under `/tmp/claude-<project>/` and send its path.

Then send it:

```
SendMessage({to: "<peer name>", message: "..."})
```

`SendMessage` is a deferred tool. If its schema isn't loaded, load it with `ToolSearch("select:SendMessage")`. `ListAgents` shows the same peers but without window names or task titles, so prefer the script for resolving.

A `busy` agent still receives the message. It's queued and seen at its next turn. That's fine unless Vivek wants an immediate interrupt; say it's busy when you report back.

## 4. Report back

One line: who you sent it to, e.g. `Sent to the [robocore lighting agent](file:///tmux/robocore:2.1). It's busy, so it'll pick it up after its current turn.`

## Naming agents to Vivek

Peer names like `robocore-3f` mean nothing to Vivek. They're only for `SendMessage`. Whenever you mention an agent to him, call it "the <session> <task> agent" and make the "<session> <task> agent" part a markdown link to its pane, using the `file:///tmux/...` link that `agents.py` prints. The task is the hand-set window name, the worktree name, or a short form of the title. Examples:

- the [robocore lighting agent](file:///tmux/robocore:2.1)
- the [lander yaw-plots agent](file:///tmux/lander:1.1)

Vivek sees only the blue link text. Clicking it jumps to that pane: kitty's `~/.config/kitty/open-actions.conf` sends `file:///tmux/` links to `goto-pane.sh` instead of opening a file. Always use a markdown link, never the bare URL. Percent-encode spaces in session names (`%20`). Give the peer name only if he asks for it.

## Fallback: Claude without a peer entry

If Vivek points at a pane that runs `claude` but has no row (an old version, or messaging disabled), `SendMessage` can't reach it. Tell Vivek, and offer to type the message into that pane with `tmux send-keys -t <pane_id> -l '<text>'` followed by `tmux send-keys -t <pane_id> Enter`. Don't do it without his OK, because it submits into whatever prompt is open there, permission dialogs included. Find the pane with `tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_title}'`.
