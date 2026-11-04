#!/usr/bin/env python3
"""Critical desktop notification that jumps to the calling tmux pane when clicked.

Usage:
  lmk.py "<question>"           notify now. Run detached (setsid ... &): it stays alive until
                                the notification is clicked or dismissed.
  lmk.py --after "<question>"   queue it; the Stop hook sends it when Claude's turn ends, so
                                the reply is fully on screen by the time Vivek clicks.
  lmk.py --flush                Stop hook entry point: send this pane's queued alert, if any.

LMK_DRY_RUN=1 prints what would be sent instead of notifying (for testing).
"""
import json
import os
import subprocess
import sys
import time

import gi

gi.require_version("Notify", "0.7")
from gi.repository import GLib, Notify  # noqa: E402

PANE = os.environ.get("TMUX_PANE", "")


def tmux(*args):
    return subprocess.run(["tmux", *args], capture_output=True, text=True).stdout.strip()


def location():
    return (PANE and tmux("display-message", "-p", "-t", PANE, "#S/#I")) or "claude"


def ancestor_window(pid):
    """X window of the nearest ancestor of pid that owns one (the terminal emulator)."""
    for p in ancestors(pid):
        wins = subprocess.run(["xdotool", "search", "--pid", str(p)],
                              capture_output=True, text=True).stdout.split()
        if wins:
            return wins[-1]
    return None


def ancestors(pid):
    while pid > 1:
        yield pid
        with open(f"/proc/{pid}/stat") as f:
            pid = int(f.read().rsplit(")", 1)[1].split()[1])


def already_visible():
    """True if a client showing PANE's window sits in the focused X window."""
    active = subprocess.run(["xdotool", "getactivewindow", "getwindowpid"],
                            capture_output=True, text=True).stdout.strip()
    if not active:
        return False
    window = tmux("display-message", "-p", "-t", PANE, "#{window_id}")
    # list-clients' #{window_id} is the client's current window. `display-message -c`
    # is not: it resolves against $TMUX_PANE, i.e. our own window.
    for line in tmux("list-clients", "-F", "#{window_id} #{client_pid}").splitlines():
        client_window, pid = line.split()
        if client_window == window and int(active) in ancestors(int(pid)):
            return True
    return False


def focus_pane():
    # Most recently active client is the one Vivek is looking at.
    clients = tmux("list-clients", "-F", "#{client_activity} #{client_name} #{client_pid}").splitlines()
    if not clients:
        return
    _, name, pid = sorted(clients)[-1].split()
    tmux("switch-client", "-c", name, "-t", PANE)
    tmux("select-window", "-t", PANE)
    tmux("select-pane", "-t", PANE)
    win = ancestor_window(int(pid))
    if win:
        subprocess.run(["wmctrl", "-i", "-a", hex(int(win))])


# Claude Code crab as pixel art, squared up to fill the notification's square icon slot.
# GNOME caches icons by path: bump the filename when redrawing it.
ICON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "clawd-v5.svg")


# --after queue: one file per tmux pane (the Bash tool and the Stop hook both inherit
# claude's $TMUX_PANE). Entries older than QUEUE_TTL_S are from an interrupted turn: dropped.
QUEUE_DIR = os.path.expanduser("~/.cache/lmk")
QUEUE_TTL_S = 300


def queue_file():
    return os.path.join(QUEUE_DIR, (PANE.lstrip("%") or "notmux") + ".json")


def enqueue(question):
    os.makedirs(QUEUE_DIR, exist_ok=True)
    with open(queue_file(), "w") as f:
        json.dump({"question": question, "time": time.time()}, f)


def flush():
    """Pop this pane's queued alert and send it from a detached process, so the hook returns."""
    try:
        with open(queue_file()) as f:
            entry = json.load(f)
        os.remove(queue_file())
    except (OSError, ValueError):
        return
    if time.time() - entry.get("time", 0) > QUEUE_TTL_S:
        return
    subprocess.Popen([sys.executable, os.path.abspath(__file__), entry["question"]],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    args = sys.argv[1:]
    if args[:1] == ["--flush"]:
        return flush()
    after = args[:1] == ["--after"]
    question = " ".join(args[after:]) or "Claude needs your input"
    if after:
        return enqueue(question)
    if os.environ.get("LMK_DRY_RUN"):
        print(f"{location()}: {question}")
        return
    if PANE and already_visible():
        return
    Notify.init("claude-alert")
    loop = GLib.MainLoop()
    n = Notify.Notification.new(f"{location()}: {question}", None, ICON)
    n.set_urgency(Notify.Urgency.CRITICAL)
    if PANE:
        n.add_action("default", "Go to pane", lambda *_: (focus_pane(), loop.quit()))
    n.connect("closed", lambda *_: loop.quit())
    n.show()
    if PANE:
        loop.run()


if __name__ == "__main__":
    main()
