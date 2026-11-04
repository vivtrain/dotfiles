#!/usr/bin/env -S python3 -I -S
"""tmux-sessions — the session switcher popup, in the pins popup's style (floatlist.py).

Sessions are listed in ~/.tmux/session-order.sh order (the M-!..M-* numbering), the current one
marked and preselected, each with its window count, other attached clients and last activity.

  tmux-sessions popup <client>          open it centred on the window (alt+s, status click)
  tmux-sessions tui <client>            what runs in the popup:
      j/k g/G move   enter switch   1-9 switch to that number   J/K reorder (@order)
      r rename   n new session   x kill (asks y/n)   q/esc/ctrl+c/alt+s close
"""
import os
import sys
import time

sys.dont_write_bytecode = True  # no __pycache__ in ~/.local/scripts (a dotfiles dir)
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))  # floatlist, beside this file
import floatlist  # noqa: E402
from floatlist import CLOSE, Row  # noqa: E402

ORDER = os.path.expanduser("~/.tmux/session-order.sh")
GLYPH_CURRENT = "\U000f018d"  # md-console, the current session (green)
GLYPH_WINDOWS = "\U000f0379"  # md-monitor, before the window count
TITLE = "\uebc8 Sessions"  # cod-terminal_tmux
FOOTER = "  enter switch · 1-9 jump · J/K move · r rename · n new · x kill · q quit"
EMPTY = "  no sessions"


def run(*args, **kw):
    import subprocess  # lazily: it's the slowest import, and the first frame doesn't need it
    return subprocess.run(*args, **kw)


def tmux(*args):
    r = run(["tmux", *args], capture_output=True, text=True)
    return r.stdout.strip(), r.returncode, r.stderr.strip()


def age(ts):
    s = max(int(time.time()) - ts, 0)
    for unit, n in (("d", 86400), ("h", 3600), ("m", 60)):
        if s >= n:
            return f"{s // n}{unit}"
    return "now"


class Sessions:
    def __init__(self, client):
        self.client = client

    def current(self):
        return tmux("display-message", "-p", "-c", self.client, "#{session_id}")[0]

    def list(self):
        """[(id, name, windows, attached, activity)] in session-order.sh order."""
        order = run([ORDER, "list"], capture_output=True, text=True).stdout.splitlines()
        info = {}
        out = tmux("list-sessions", "-F",
                   "#{session_id}\t#{session_windows}\t#{session_attached}\t#{session_activity}")[0]
        for line in out.splitlines():
            sid, windows, attached, activity = line.split("\t")
            info[sid] = (int(windows), int(attached), int(activity or 0))
        result = []
        for line in order:
            num, _, name = line.partition(" ")
            sid = "$" + num
            if sid in info:
                result.append((sid, name, *info[sid]))
        return result

    def rows(self):
        cur = self.current()
        rows = []
        for sid, name, windows, attached, activity in self.list():
            others = attached - (sid == cur)
            extra = " · ".join([f"{GLYPH_WINDOWS} {windows}"] + ([f"{others} attached"] if others > 0 else []) + [age(activity)])
            rows.append(Row(name, extra=extra, id=sid,
                            mark=GLYPH_CURRENT if sid == cur else "", mark_color="32"))
        return rows

    # ---- keys ----
    def keys(self):
        keys = {"enter": self.enter, "J": lambda ui: self.move(ui, +1), "K": lambda ui: self.move(ui, -1),
                "r": self.rename, "n": self.new, "x": self.kill}
        for n in range(1, 10):
            keys[str(n)] = lambda ui, n=n: self.jump(ui, n)
        return keys

    def switch(self, ui, sid):
        _, rc, err = tmux("switch-client", "-c", self.client, "-t", sid)
        if rc:
            ui.flash(f"  {err}")
            return None
        return CLOSE

    def enter(self, ui):
        return self.switch(ui, ui.rows[ui.sel].id) if ui.rows else None

    def jump(self, ui, n):
        if n > len(ui.rows):
            ui.flash(f"  no session {n}")
            return None
        return self.switch(ui, ui.rows[n - 1].id)

    def move(self, ui, delta):
        if ui.rows:
            sid = ui.rows[ui.sel].id
            run([ORDER, "move", f"{delta:+d}", sid], capture_output=True,
                           env=dict(os.environ, SESSION_ORDER_QUIET="1"))
            ui.select(sid)

    def rename(self, ui):
        if not ui.rows:
            return
        row = ui.rows[ui.sel]
        name = ui.prompt("rename", row.text)
        if name and name != row.text:
            _, rc, err = tmux("rename-session", "-t", row.id, name)
            if rc:
                ui.flash(f"  {err}")

    def new(self, ui):
        name = ui.prompt("new session")
        if name is None:
            return
        args = ["new-session", "-d", "-P", "-F", "#{session_id}"] + (["-s", name] if name else [])
        sid, rc, err = tmux(*args)
        if rc:
            ui.flash(f"  {err}")
            return None
        return self.switch(ui, sid)

    def kill(self, ui):
        if not ui.rows:
            return
        row = ui.rows[ui.sel]
        if len(ui.rows) == 1:
            ui.flash("  can't kill the last session")
            return
        if not ui.confirm(f"kill session {row.text}?"):
            return
        if row.id == self.current():
            # detach-on-destroy is off, but move this client first so it lands on a neighbour
            # in our order rather than wherever tmux picks
            ids = [r.id for r in ui.rows]
            i = ids.index(row.id)
            tmux("switch-client", "-c", self.client, "-t", ids[i + 1] if i + 1 < len(ids) else ids[i - 1])
        _, rc, err = tmux("kill-session", "-t", row.id)
        if rc:
            ui.flash(f"  {err}")


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "popup":
        client = args[1]
        s = Sessions(client)
        floatlist.open_popup(client, f"{os.path.realpath(__file__)} tui {client}", s.rows(),
                             FOOTER, TITLE, anchor="window", theme=floatlist.GREEN, select_id=s.current(), empty=EMPTY)
    elif len(args) == 2 and args[0] == "tui":
        s = Sessions(args[1])
        # FLOATLIST_SELECT (from the launcher) saves asking tmux for the current session
        select = os.environ.get("FLOATLIST_SELECT") or s.current()
        floatlist.FloatList(s.rows, s.keys(), FOOTER, EMPTY, refresh_s=1,
                            select_id=select, close_keys=("\033s",), theme=floatlist.GREEN).run()
    else:
        sys.exit(__doc__.strip())


if __name__ == "__main__":
    main()
