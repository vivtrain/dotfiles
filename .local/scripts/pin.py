#!/usr/bin/env -S python3 -I
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
import json
import os
import select
import shutil
import subprocess
import sys
import termios
import time
import tty
from urllib.parse import quote, unquote, urlparse

HOME = os.path.expanduser("~")
STORE = os.path.join(HOME, ".cache", "claude-pins")
BY_PANE = os.path.join(STORE, "by-pane")
COPY, TMUX = "file:///copy/", "file:///tmux/"
GLYPH_LINK, GLYPH_COPY, GLYPH_PIN = "\U000f037d", "\U000f018f", "\U000f0403"
GLYPH_WEB = "\U000f01e7"  # md-earth, for http(s) links

# Popup look, after the tmux session menu (~/.tmux/session-menu.sh): its muted green highlight
# (#1e4d2b) turned blue at the same lightness and saturation, white text on it.
SEL_RGB = "30;46;77"  # #1e2e4d
SEL = f"\033[48;2;{SEL_RGB};97m"  # the pill's body: white on the muted blue
CAP_L, CAP_R = f"\033[38;2;{SEL_RGB}m\ue0b6", f"\033[0;38;2;{SEL_RGB}m\ue0b4\033[0m"  # rounded ends
ROW_PAD = 7  # margin + " NN  " before the label, one space after
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
    if "://" in target:
        return target
    path = os.path.abspath(os.path.expanduser(target))
    return "file://" + quote(path)


def label_of(target, label=""):
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


# ---------- tui ----------

def osc8(target, text):
    return f"\033]8;;{target}\033\\{text}\033]8;;\033\\"


def clip(text, width):
    return text if len(text) <= width else text[: max(width - 1, 0)] + "…"


class Tui:
    IDLE_TIMEOUT_S = 600  # failsafe: never hold the popup forever

    def __init__(self, session):
        self.session, self.sel, self.top, self.pending_d = session, 0, 0, False
        self.reg = None    # last cut pin, vim's unnamed register: x / dd fill it, p / P paste it
        self.history = []  # (pins, sel) before each change, for u; lives as long as the popup
        self.pins, self.mtime = [], None
        self.reload()

    def reload(self):
        try:
            mtime = os.stat(store_file(self.session)).st_mtime_ns
        except OSError:
            mtime = None
        if mtime != self.mtime:
            self.mtime, self.pins = mtime, load(self.session)
        self.sel = min(self.sel, max(len(self.pins) - 1, 0))

    def write(self):
        save(self.session, self.pins)
        self.mtime = os.stat(store_file(self.session)).st_mtime_ns

    def draw(self):
        cols, lines = shutil.get_terminal_size()
        cols, lines = cols if cols >= 20 else 80, lines if lines >= 4 else 24  # a pty can report 0x0
        body = max(lines - 3, 1)  # blank rows above the list and before the footer
        if self.sel < self.top:
            self.top = self.sel
        elif self.sel >= self.top + body:
            self.top = self.sel - body + 1
        out = ["\033[H\033[2J\r\n"]
        if not self.pins:
            out.append(f"\033[2m{clip(EMPTY, cols)}\033[0m\r\n")
        for i in range(self.top, min(self.top + body, len(self.pins))):
            target, label = self.pins[i]
            text = clip(label_of(target, label), cols - ROW_PAD)
            if i == self.sel:  # a pill around number and text; its left cap takes the leading space
                out.append(f" {CAP_L}{SEL}{i + 1:>2}  {osc8(target, text)} {CAP_R}\r\n")
            else:
                out.append(f" \033[2m{i + 1:>3}\033[0m  \033[34m{osc8(target, text)}\033[0m\r\n")
        out.append(f"\033[{lines};1H\033[2m{clip(FOOTER, cols)}\033[0m")
        sys.stdout.write("".join(out))
        sys.stdout.flush()

    def key(self, fd):
        ready, _, _ = select.select([fd], [], [], self.IDLE_TIMEOUT_S)
        if not ready:
            return "timeout"
        data = os.read(fd, 32)
        while data == b"\033" or (data.startswith(b"\033[") and not data[-1:].isalpha() and data[-1:] != b"~"):
            more, _, _ = select.select([fd], [], [], 0.03)
            if not more:
                break
            data += os.read(fd, 32)
        return {b"\033[A": "k", b"\033[B": "j", b"\033OA": "k", b"\033OB": "j",
                b"\033[H": "g", b"\033[F": "G", b"\r": "enter", b"\n": "enter",
                b"\033": "quit", b"\x03": "quit", b"\x04": "quit", b"q": "quit",
                b"\033P": "quit", b"\033p": "quit",  # alt+shift+p / alt+p: the popup key toggles
                }.get(data, data.decode(errors="replace"))

    def change(self):
        """Call before mutating self.pins: remembers the state for u."""
        self.history.append((list(self.pins), self.sel))

    def move(self, delta):
        j = self.sel + delta
        if self.pins and 0 <= j < len(self.pins):
            self.change()
            self.pins[self.sel], self.pins[j] = self.pins[j], self.pins[self.sel]
            self.sel = j
            self.write()

    def cut(self):
        if self.pins:
            self.change()
            self.reg = self.pins.pop(self.sel)
            self.write()

    def paste(self, below):
        # A pin is in the list once: pasting one that's already there does nothing.
        if self.reg is None or self.reg[0] in (t for t, _ in self.pins):
            return
        self.change()
        at = self.sel + 1 if below and self.pins else self.sel
        self.pins.insert(at, self.reg)
        self.sel = at
        self.write()

    def undo(self):
        if self.history:
            self.pins, self.sel = self.history.pop()
            self.write()

    def run(self):
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        sys.stdout.write("\033[?25l")
        try:
            tty.setraw(fd)
            while True:
                self.reload()
                self.draw()
                k = self.key(fd)
                d, self.pending_d = self.pending_d, False
                if k in ("quit", "timeout"):
                    return
                elif k == "j":
                    self.sel = min(self.sel + 1, max(len(self.pins) - 1, 0))
                elif k == "k":
                    self.sel = max(self.sel - 1, 0)
                elif k == "g":
                    self.sel = 0
                elif k == "G":
                    self.sel = max(len(self.pins) - 1, 0)
                elif k == "J":
                    self.move(1)
                elif k == "K":
                    self.move(-1)
                elif k == "x" or (k == "d" and d):
                    self.cut()
                elif k == "d":
                    self.pending_d = True
                elif k in ("p", "P"):
                    self.paste(below=k == "p")
                elif k == "u":
                    self.undo()
                elif k == "enter" and self.pins:
                    open_target(self.pins[self.sel][0])
                    return
        finally:
            sys.stdout.write("\033[0m\033[?25h\033[H\033[2J")
            sys.stdout.flush()
            termios.tcsetattr(fd, termios.TCSADRAIN, old)


def popup(pane, client):
    """Open the pins popup over `pane` on `client`, sized to fit its pins.

    Called from the tmux binding through run-shell, whose command tmux expands as a format,
    so pane and client arrive filled in (a display-popup command's own text may not be)."""
    def tmux(*a):
        return subprocess.run(["tmux", *a], capture_output=True, text=True).stdout.strip()
    try:
        pl, pt, pw, ph = (int(x) for x in tmux("display-message", "-p", "-t", pane,
                          "#{pane_left} #{pane_top} #{pane_width} #{pane_height}").split())
    except ValueError:
        pl, pt, pw, ph = 0, 0, 120, 40
    session = resolve_session(pane=pane)
    pins = load(session) if session else []
    widest = max([len(label_of(t, l)) + ROW_PAD for t, l in pins] + [len(FOOTER) + 1, len(EMPTY) + 1])
    # + 2 border columns and 2 spare; blank + rows + blank + footer + 2 border rows. At most the pane,
    # less a margin, but never squeezed below 40 x 6.
    w = min(widest + 4, max(pw - 4, 40))
    h = min(max(len(pins), 1) + 3 + 2, max(ph - 2, 7))
    # Centred on the pane. tmux takes -y as the popup's bottom row (as P, "bottom left of the
    # pane", shows), so add h to the top row.
    x = pl + max((pw - w) // 2, 0)
    y = pt + max((ph - h) // 2, 0) + h
    title = (f"#[fg=blue]\ue0b6#[bg=blue,fg=#000000,bold] {GLYPH_PIN} Pins "
             f"#[bg=default,fg=blue,nobold]\ue0b4")
    subprocess.run(["tmux", "display-popup", "-c", client, "-E", "-w", str(w), "-h", str(h),
                    "-x", str(x), "-y", str(y), "-b", "rounded", "-S", "fg=blue", "-T", title,
                    os.path.abspath(__file__) + f" --pane {pane} tui"])


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
    Tui(session).run()


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
