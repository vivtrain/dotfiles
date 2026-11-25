---
name: spawn-claude
description: Open a new Claude Code instance in a new tmux window, laid out like Vivek's normal window (claude in an interactive bash on the left, plain bash split on the right). Use when Vivek says "spawn a claude", "open a new claude window", "start another agent in tmux", or when one Claude needs to hand a task to a fresh Claude in its own window.
---

# Spawn a Claude in a new tmux window

```bash
~/.claude/skills/spawn-claude/spawn-claude.sh [-s session] [-d dir] [-n name] [-1] [-f] [-- claude args...]
```

It prints the new claude pane as `session:window.pane`.

- Default: the current tmux session, `$PWD`, opened in the background, with a split.
- `-s` targets another session. If that session doesn't exist, the script creates it, so it also works from outside tmux (e.g. over ssh).
- `-d` sets the working directory for both panes. To give the new Claude its own branch, point `-d` at a worktree.
- `-1` skips the split. `-f` switches to the new window.
- Anything after `--` goes to claude. A quoted string becomes the new Claude's first prompt:
  `spawn-claude.sh -d ~/DavisMechatronics/robocore -n lighting -- "look into the LED flicker in ..."`
- Keep spawn prompts concise: state the task and point at files, PRs or branches instead of pasting their contents. If the typed command passes about 3500 bytes, the script writes it to a temp file and the pane sources that file. That is a fallback for prompts that really need the length, not the normal path.

## Why it's done this way

- **`claude` is typed into a bash, not run as the window's command.** `tmux new-window claude` runs the command via `sh -c` with the tmux server's environment. That skips `.bashrc`, so `CLAUDE_CODE_NO_FLICKER=1` is missing: there's no full-screen mode and the prompt doesn't stick to the bottom. And when claude exits, the window closes. Typing it into an interactive bash avoids both problems.
- **Long commands go through a file.** Typed keys wait in the pty's canonical line buffer, which holds 4095 bytes, until bash reads them, and the rest is dropped. A prompt cut off there loses its closing quote, so bash sits at a `>` prompt and claude never starts. Typing `. /run/user/…/spawn-claude.XXXXXX` stays short. The file deletes itself first; that's safe because bash reads a sourced file whole before running it.
- `-d` on new-window and split-window keeps Vivek's current window focused.

## After spawning

- Report the new pane as a link: the [󰍹 <session> <task> agent](file:///tmux/<session>:<window>.<pane>).
- To check that it came up, `tmux display -p -t <pane> '#{pane_current_command} #{alternate_on}'` should show `claude 1`.
- Talking to it later is a separate permission. Follow the "Other Claude agents" rules in the global CLAUDE.md (use the `relay` skill / SendMessage only when asked).
