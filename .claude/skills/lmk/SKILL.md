---
name: lmk
description: Get Vivek's attention with a critical desktop notification whenever you need to ask a question or need input, especially in auto mode. Vivek runs many tmux sessions/windows/panes at once and may not be watching this one. Use right before asking a question, requesting a decision or approval, or stopping because you are blocked. Also use when Vivek says "lmk when/if…", "let me know when/if…", "ping me", "tell me when…", or "notify me": send the alert when that thing happens.
---

# Alert before asking

Vivek usually has several tmux sessions, windows, and panes open, often with Claude running in auto mode in more than one. A question asked only in the terminal can sit unseen for a long time. So whenever you need Vivek's input, send a desktop notification that says which tmux window is waiting and what you're asking.

## How

Run this just before you ask the question (with AskUserQuestion or in your reply). The notification only points Vivek to the right window. The question itself still goes in the terminal as usual.

```bash
setsid ~/.claude/skills/lmk/lmk.py "<question>" >/dev/null 2>&1 < /dev/null &
```

- `lmk.py` (next to this file) sends a critical-urgency notification, which gets through Ubuntu's Do Not Disturb. The text is `<tmux-session-name>/<window-number>: <question>`, e.g. `robocore/2: Overwrite calib.yaml or write calib_v2.yaml?`
- The script exits silently if this tmux window is already showing in the focused terminal, so call it anyway; it decides.
- Clicking the notification switches Vivek's tmux client to *your* pane (found from `$TMUX_PANE`) and raises the terminal window.
- Keep the `setsid ... &` wrapper. The script waits until the notification is clicked or dismissed, so running it in the foreground would block you.
- Critical notifications stay on screen until dismissed, so send one per question, not repeats.
- Keep the question to one line, under roughly 100 characters. Summarize it if the full question is long.
- If you're not inside tmux, the label falls back to `claude` and clicking does nothing. Still send the notification.
- The headline message size needs to be <46 chars, since that's what is viewable without getting cutoff by ellipses.

## When

- Before any question, decision, or permission request to Vivek
- When you're blocked and stopping to wait for Vivek
- When Vivek asked to be told about something ("lmk when the build finishes", "lmk if the loss goes NaN", "ping me when it's done") and it has happened. The text is then the news itself, e.g. `robocore/2: build finished, 3 tests failed`. This applies even when no reply is needed.

Otherwise, don't send one for routine progress updates or for normal end-of-task summaries.
