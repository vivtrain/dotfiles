#!/usr/bin/env -S python3 -I -S
"""pin — session-local bookmarks for Claude Code sessions: links you keep coming back to.

Store: ~/.cache/claude-pins/<session-id>.tsv, one pin per line, `target<TAB>label`, in pin order.
A target is a URL as Claude writes links: file:///path, file:///copy/<cmd>, file:///tmux/<pane>,
https://... An empty label is derived from the target (󰍽 path, 󰆏 command), as the chat shows it.

Which session: --session ID, else $CLAUDE_PINS_SESSION, else the Claude session last started in
the tmux pane (--pane, else $TMUX_PANE), as recorded by the SessionStart hook.

  pin add <target> [label...]     pin it (a path is turned into file://); already pinned: no-op
  pin add --copy <text...>        pin a click-to-copy command
  pin ls                          numbered list
  pin rm <n>                      unpin #n
  pin mv <n> <m>                  move #n to position m
  pin count | file                number of pins | path of the store
  pin popup <pane> <client>       open the popup (tmux binding); pin tui is what runs in it:
  pin tui [--pane %N]             the popup: j/k g/G move, enter opens, J/K reorder, x or dd
                                  cuts, p/P pastes below/above, u undoes, q/esc/ctrl+c closes;
                                  clicks act as kitty's link clicks do
  pin hook-session-start          SessionStart hook: map $TMUX_PANE to this session
"""
import os
import select
import sys
import termios
import tty

# json, subprocess and urllib.parse are imported where used: they are the slow imports, and the
# popup's first frame needs none of them.

sys.dont_write_bytecode = True  # no __pycache__ in ~/.local/scripts (a dotfiles dir)
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))  # floatlist, beside this file
import floatlist  # noqa: E402
from floatlist import CLOSE, Row  # noqa: E402

HOME = os.path.expanduser("~")
STORE = os.path.join(HOME, ".cache", "claude-pins")
BY_PANE = os.path.join(STORE, "by-pane")
COPY, TMUX = "file:///copy/", "file:///tmux/"
GLYPH_LINK, GLYPH_COPY, GLYPH_PIN = "\U000f037d", "\U000f018f", "\U000f0403"
GLYPH_WEB = "\U000f01e7"  # md-earth, for http(s) links
FOOTER = "  enter open · J/K move · x cut · p paste · u undo · q quit"  # 1-column margin, as the rows have
EMPTY = "  nothing pinned"


def die(msg):
    sys.exit(f"pin: {msg}")


# ---------- store ----------

def pane_session(pane):
    try:
        with open(os.path.join(BY_PANE, pane.lstrip("%"))) as f:
            return f.read().strip() or None
    except OSError:
        return None


def resolve_session(session=None, pane=None):
    session = session or os.environ.get("CLAUDE_PINS_SESSION")
    if session:
        return session
    pane = pane or os.environ.get("TMUX_PANE")
    return pane_session(pane) if pane else None


def store_file(session):
    return os.path.join(STORE, f"{session}.tsv")


def load(session):
    try:
        with open(store_file(session)) as f:
            rows = [line.rstrip("\n").split("\t", 1) for line in f if line.strip()]
    except OSError:
        return []
    return [(r[0], r[1] if len(r) > 1 else "") for r in rows]


def save(session, pins):
    os.makedirs(STORE, exist_ok=True)
    path = store_file(session)
    tmp = f"{path}.tmp{os.getpid()}"
    with open(tmp, "w") as f:
        for target, label in pins:
            f.write(f"{target}\t{label}\n" if label else f"{target}\n")
    os.replace(tmp, path)


def normalize(target):
    from urllib.parse import quote
    if "://" in target:
        return target
    path = os.path.abspath(os.path.expanduser(target))
    return "file://" + quote(path)


def label_of(target, label=""):
    from urllib.parse import unquote, urlparse
    if label:
        return label
    if target.startswith(COPY):
        return f"{GLYPH_COPY} {unquote(target[len(COPY):])}"
    if target.startswith(TMUX):
        return f"{GLYPH_LINK} tmux {unquote(target[len(TMUX):])}"
    if target.startswith("file://"):
        path = unquote(urlparse(target).path)
        if path == HOME or path.startswith(HOME + "/"):
            path = "~" + path[len(HOME):]
        return f"{GLYPH_LINK} {path}"
    if target.startswith(("http://", "https://")):
        return f"{GLYPH_WEB} {target}"
    return f"{GLYPH_LINK} {target}"


def index(pins, n):
    try:
        i = int(n) - 1
    except ValueError:
        die(f"not a pin number: {n}")
    if not 0 <= i < len(pins):
        die(f"no pin #{n} (have {len(pins)})")
    return i


def open_target(target):
    """The default action, as kitty's open-actions.conf does for a click."""
    import subprocess
    from urllib.parse import unquote, urlparse
    if target.startswith(COPY):
        cmd = [os.path.join(HOME, ".config/kitty/copy-text.sh"), target]
    elif target.startswith(TMUX):
        cmd = [os.path.join(HOME, ".claude/skills/relay/goto-pane.sh"), target]
    elif target.startswith("file://"):
        cmd = ["xdg-open", unquote(urlparse(target).path)]
    else:
        cmd = ["xdg-open", target]
    subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


# ---------- popup ----------

class PinKeys:
    """The pins popup's keys on top of floatlist's: x / dd cut into a register (vim's unnamed
    one), p / P paste below / above, u undoes (cuts, pastes, moves), J / K move, enter opens.
    Register and history live as long as the popup."""

    def __init__(self, session):
        self.session, self.reg, self.history = session, None, []

    def rows(self):
        return [Row(label_of(t, l), href=t, id=t) for t, l in load(self.session)]

    def keys(self):
        return {"enter": self.enter, "J": lambda ui: self.move(ui, 1), "K": lambda ui: self.move(ui, -1),
                "x": self.cut, "dd": self.cut, "p": lambda ui: self.paste(ui, True),
                "P": lambda ui: self.paste(ui, False), "u": self.undo}

    def change(self, pins):
        self.history.append(list(pins))

    def enter(self, ui):
        pins = load(self.session)
        if pins:
            open_target(pins[ui.sel][0])
            return CLOSE

    def move(self, ui, delta):
        pins, i = load(self.session), ui.sel
        if 0 <= i + delta < len(pins):
            self.change(pins)
            pins[i], pins[i + delta] = pins[i + delta], pins[i]
            save(self.session, pins)
            ui.select(pins[i + delta][0])

    def cut(self, ui):
        pins = load(self.session)
        if pins:
            self.change(pins)
            self.reg = pins.pop(ui.sel)
            save(self.session, pins)

    def paste(self, ui, below):
        pins = load(self.session)
        # A pin is in the list once: pasting one that's already there does nothing.
        if self.reg is None or self.reg[0] in (t for t, _ in pins):
            return
        self.change(pins)
        pins.insert(ui.sel + 1 if below and pins else ui.sel, self.reg)
        save(self.session, pins)
        ui.select(self.reg[0])

    def undo(self, ui):
        if self.history:
            save(self.session, self.history.pop())


def popup(pane, client):
    """Open the pins popup over `pane` on `client`, sized to fit its pins.

    Called from the tmux binding through run-shell, whose command tmux expands as a format,
    so pane and client arrive filled in (a display-popup command's own text may not be)."""
    session = resolve_session(pane=pane)
    rows = PinKeys(session).rows() if session else []
    floatlist.open_popup(client, os.path.realpath(__file__) + f" --pane {pane} tui", rows, FOOTER,
                         f"{GLYPH_PIN} Pins", pane=pane, empty=EMPTY)


def tui(pane):
    session = resolve_session(pane=pane)
    if not session:
        print(f"pin: no Claude session recorded for tmux pane {pane or '?'} (it registers on Claude's next start).\r\nAny key closes.")
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setcbreak(fd)
            select.select([fd], [], [], 30)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        return
    k = PinKeys(session)
    # alt+shift+p / alt+p: the popup key toggles
    floatlist.FloatList(k.rows, k.keys(), FOOTER, EMPTY, close_keys=("\033P", "\033p")).run()


# ---------- cli ----------

def main():
    args = sys.argv[1:]
    session = pane = None
    while args and args[0] in ("--session", "--pane"):
        if len(args) < 2:
            die(f"{args[0]} needs a value")
        session, pane = (args[1], pane) if args[0] == "--session" else (session, args[1])
        args = args[2:]
    cmd, rest = (args[0], args[1:]) if args else ("ls", [])
    if cmd in ("-h", "--help", "help"):
        print(__doc__.strip())
        return
    if cmd == "hook-session-start":
        import json
        sid = json.load(sys.stdin).get("session_id")
        tpane = os.environ.get("TMUX_PANE")
        if sid and tpane:
            os.makedirs(BY_PANE, exist_ok=True)
            with open(os.path.join(BY_PANE, tpane.lstrip("%")), "w") as f:
                f.write(sid + "\n")
        return
    if cmd == "tui":
        return tui(pane or os.environ.get("TMUX_PANE"))
    if cmd == "popup":
        if len(rest) != 2:
            die("popup takes <pane> <client> (the tmux binding passes them)")
        return popup(*rest)

    sid = resolve_session(session, pane)
    if not sid:
        die("no session: pass --session, set CLAUDE_PINS_SESSION, or run inside a Claude tmux pane")
    pins = load(sid)
    if cmd == "add":
        if not rest:
            die("add needs a target")
        if rest[0] == "--copy":
            from urllib.parse import quote
            if len(rest) < 2:
                die("add --copy needs text")
            target, label = COPY + quote(" ".join(rest[1:]), safe=""), ""
        else:
            target, label = normalize(rest[0]), " ".join(rest[1:])
        if any(t == target for t, _ in pins):
            print(f"already pinned: {label_of(target, label)}")
            return
        pins.append((target, label.replace("\t", " ")))
        save(sid, pins)
        print(f"pinned #{len(pins)}: {label_of(target, label)}")
    elif cmd == "ls":
        dim, off = ("\033[2m", "\033[0m") if sys.stdout.isatty() else ("", "")
        for i, (target, label) in enumerate(pins, 1):
            print(f"{i:>3}  {label_of(target, label)}  {dim}{target}{off}")
    elif cmd == "rm":
        if len(rest) != 1:
            die("rm takes one pin number")
        target, label = pins.pop(index(pins, rest[0]))
        save(sid, pins)
        print(f"unpinned: {label_of(target, label)}")
    elif cmd == "mv":
        if len(rest) != 2:
            die("mv takes <n> <m>")
        i = index(pins, rest[0])
        j = max(0, min(int(rest[1]) - 1, len(pins) - 1))
        pins.insert(j, pins.pop(i))
        save(sid, pins)
    elif cmd == "count":
        print(len(pins))
    elif cmd == "file":
        print(store_file(sid))
    else:
        die(f"unknown command: {cmd} (pin --help)")


if __name__ == "__main__":
    main()
