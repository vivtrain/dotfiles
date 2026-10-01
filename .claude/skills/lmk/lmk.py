#!/usr/bin/env python3
"""Critical desktop notification that jumps to the calling tmux pane when clicked.

Usage: lmk.py "<question>"
Run detached (setsid ... &): it stays alive until the notification is clicked or dismissed.
"""
import os
import subprocess
import sys

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


def main():
    question = " ".join(sys.argv[1:]) or "Claude needs your input"
    if PANE and already_visible():
        return
    Notify.init("claude-alert")
    loop = GLib.MainLoop()
    n = Notify.Notification.new(f"{location()}: {question}", None, "dialog-question")
    n.set_urgency(Notify.Urgency.CRITICAL)
    if PANE:
        n.add_action("default", "Go to pane", lambda *_: (focus_pane(), loop.quit()))
    n.connect("closed", lambda *_: loop.quit())
    n.show()
    if PANE:
        loop.run()


if __name__ == "__main__":
    main()
