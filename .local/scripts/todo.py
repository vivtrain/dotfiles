#!/usr/bin/env -S python3 -I -S
"""todo — per-session todo list for Claude Code sessions, shown in the status line.

Store: ~/.cache/claude-todos/<session-id>.txt, one item per line, `[s] text`, s one of:
  ` ` open 󰄱, `x` done 󰄵 (green), `!` failed 󰅘 (red), `~` partial/in progress 󰛲 (yellow).
  Glyphs: Nerd Font Material outline checkboxes (md-checkbox_blank_outline, _marked_outline,
  md-close_box_outline, md-minus_box_outline).
The statusline-todo plugin (~/.claude/plugins-local/statusline-todo: /todo and a tool for Claude)
edits the same file, and its statusline-segment.sh draws it under ~/.claude/statusline.sh.

Which session: --session ID, else $CLAUDE_TODO_SESSION, else the Claude session last started in
the tmux pane (--pane, else $TMUX_PANE), as pin's SessionStart hook records it.

  todo add <text...>              add an item
  todo ls                         numbered list
  todo done|fail|wip|undo <n>...  mark done 󰄵 / failed 󰅘 / partial 󰛲 / back to open 󰄱
  todo rm <n>...                  remove
  todo clear [all]                remove checked items (or everything)
  todo count | file               open items | path of the store
  todo popup <pane> <client> [n]  open the popup (tmux alt+t), row n selected; todo tui runs in it:
  todo tui [--pane %N]            v/space/enter toggle done, ! failed, ~ partial, a add, o/O add below/above, e edit, x/dd cut,
                                  p/P paste, J/K move, c clear checked, u undo, q/esc/alt+t close
"""
import os
import select
import sys
import termios
import tty

sys.dont_write_bytecode = True  # no __pycache__ in ~/.local/scripts (a dotfiles dir)
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))  # floatlist and pin, beside this file
import floatlist  # noqa: E402
from floatlist import CLOSE, Row, Theme  # noqa: E402
from pin import resolve_session as pin_resolve_session  # noqa: E402

STORE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "claude-todos")
# state char in the store -> (glyph, SGR colour)
MARKS = {" ": ("󰄱", "39"), "x": ("󰄵", "1;32"), "!": ("󰅘", "1;31"), "~": ("󰛲", "1;33")}
VERB_STATE = {"done": "x", "fail": "!", "wip": "~", "undo": " "}
GLYPH_TODO = "\U000f0c52"  # md-format_list_checks
# The pins popup's blue pill and border, but item text in the terminal's regular colour.
THEME = Theme("30;46;77", "0", "blue")
# The common keys only; the rest (space/enter, o/O, dd, p/P, J/K, q) are in the docstring above.
FOOTER = "  v/!/~ mark · x cut · a add · e edit · c clear done · u undo"
EMPTY = "  nothing to do (a adds)"


def die(msg):
    sys.exit(f"todo: {msg}")


# ---------- store ----------

def resolve_session(session=None, pane=None):
    return session or os.environ.get("CLAUDE_TODO_SESSION") or pin_resolve_session(pane=pane)


def store_file(session):
    return os.path.join(STORE, f"{session}.txt")


def parse(line):
    """-> [state, text], state one of MARKS' keys."""
    line = line.strip()
    if len(line) >= 3 and line[0] == "[" and line[2] == "]" and line[1].lower() in MARKS:
        return [line[1].lower(), line[3:].strip()]
    if line.startswith("[]"):
        return [" ", line[2:].strip()]
    return [" ", line]


def load(session):
    try:
        with open(store_file(session)) as f:
            return [parse(line) for line in f if line.strip()]
    except OSError:
        return []


def save(session, items):
    os.makedirs(STORE, exist_ok=True)
    path = store_file(session)
    tmp = f"{path}.tmp{os.getpid()}"
    with open(tmp, "w") as f:
        for state, text in items:
            f.write(f"[{state}] {text}\n")
    os.replace(tmp, path)  # atomic: the status line never reads half a file


def popup_state_file(session):
    """Undo history and cut register, handed from a popup to the bigger one that replaces it."""
    return os.path.join(STORE, f".popup-{session}.json")


def indices(items, args):
    out = []
    for a in (s for arg in args for s in arg.split(",") if s):
        try:
            i = int(a) - 1
        except ValueError:
            die(f"not an item number: {a}")
        if not 0 <= i < len(items):
            die(f"no item #{a} (have {len(items)})")
        out.append(i)
    if not out:
        die("which item? (todo ls)")
    return sorted(set(out))


def show(items):
    if not items:
        print("nothing to do")
    tty_out = sys.stdout.isatty()
    for i, (state, text) in enumerate(items, 1):
        glyph, sgr = MARKS[state]
        mark = f"\033[{sgr}m{glyph}\033[0m" if tty_out else glyph
        print(f"{i:>3}  {mark} {text}")


# ---------- popup ----------

class TodoKeys:
    """floatlist key handlers. x / dd cut into a register, p / P paste; u undoes any change."""

    def __init__(self, session, pane=None, client=None):
        self.session, self.reg, self.history = session, None, []
        self.pane, self.client = pane, client

    def restore(self):
        path = popup_state_file(self.session)
        if not os.path.exists(path):
            return
        import json
        try:
            with open(path) as f:
                state = json.load(f)
            self.history, self.reg = state.get("history", []), state.get("reg")
        except (OSError, ValueError):
            pass
        finally:
            try:
                os.remove(path)
            except OSError:
                pass

    def regrow(self, ui, sel):
        """tmux can't resize an open popup, so when the list outgrows this one, reopen it as tall as
        the list needs (up to the pane), with the same selection, undo history and register."""
        if not (self.pane and self.client):
            return None
        import json
        import subprocess
        _, lines = ui.size()
        if len(load(self.session)) <= max(lines - 3, 1):
            return None
        try:
            ph = int(subprocess.run(["tmux", "display-message", "-p", "-t", self.pane, "#{pane_height}"],
                                    capture_output=True, text=True).stdout.strip())
        except ValueError:
            return None
        if lines >= max(ph - 2, 7) - 2:  # already as tall as open_popup allows
            return None
        with open(popup_state_file(self.session), "w") as f:
            json.dump({"history": self.history, "reg": self.reg}, f)
        # One popup per client: the new one opens once this process (and so its popup) is gone.
        wait = 'while kill -0 "$1" 2>/dev/null; do sleep 0.01; done; sleep 0.03; shift; exec "$@"'
        subprocess.Popen(["sh", "-c", wait, "sh", str(os.getpid()), os.path.realpath(__file__),
                          "popup", self.pane, self.client, str(sel)],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return CLOSE

    def rows(self):
        return [Row(text, mark=MARKS[state][0], mark_color=MARKS[state][1], id=str(i))
                for i, (state, text) in enumerate(load(self.session))]

    def keys(self):
        return {" ": self.toggle, "v": self.toggle, "enter": self.toggle,
                "!": lambda ui: self.toggle(ui, "!"), "~": lambda ui: self.toggle(ui, "~"),
                "a": lambda ui: self.add(ui, None), "o": lambda ui: self.add(ui, 1), "O": lambda ui: self.add(ui, 0),
                "e": self.edit, "i": self.edit, "x": self.cut, "dd": self.cut, "D": self.cut,
                "p": lambda ui: self.paste(ui, 1), "P": lambda ui: self.paste(ui, 0),
                "J": lambda ui: self.move(ui, 1), "K": lambda ui: self.move(ui, -1),
                "c": self.clear, "u": self.undo}

    def change(self, items, new, ui=None, sel=None):
        self.history.append([list(x) for x in items])
        save(self.session, new)
        if ui is not None and sel is not None:
            ui.select(str(sel))

    def toggle(self, ui, state="x"):
        """Set the selected item to `state`, or back to open if it already is."""
        items = load(self.session)
        if items:
            new = [list(x) for x in items]
            new[ui.sel][0] = " " if new[ui.sel][0] == state else state
            self.change(items, new)

    def add(self, ui, offset):
        text = ui.prompt("add")
        if not text or not text.strip():
            return
        items = load(self.session)
        at = len(items) if offset is None or not items else ui.sel + offset
        self.change(items, items[:at] + [[" ", text.strip()]] + items[at:], ui, at)
        return self.regrow(ui, at)

    def edit(self, ui):
        items = load(self.session)
        if not items:
            return
        text = ui.prompt("edit", items[ui.sel][1])
        if text and text.strip() and text.strip() != items[ui.sel][1]:
            new = [list(x) for x in items]
            new[ui.sel][1] = text.strip()
            self.change(items, new)

    def cut(self, ui):
        items = load(self.session)
        if items:
            new = [list(x) for x in items]
            self.reg = new.pop(ui.sel)
            self.change(items, new)

    def paste(self, ui, offset):
        if self.reg is None:
            return
        items = load(self.session)
        at = ui.sel + offset if items else 0
        self.change(items, items[:at] + [list(self.reg)] + items[at:], ui, at)
        return self.regrow(ui, at)

    def move(self, ui, delta):
        items, i = load(self.session), ui.sel
        if 0 <= i + delta < len(items):
            new = [list(x) for x in items]
            new[i], new[i + delta] = new[i + delta], new[i]
            self.change(items, new, ui, i + delta)

    def clear(self, ui):
        items = load(self.session)
        if any(state == "x" for state, _ in items):
            self.change(items, [x for x in items if x[0] != "x"])
            ui.flash("  cleared checked items (u undoes)")

    def undo(self, ui):
        if self.history:
            save(self.session, self.history.pop())


def popup(pane, client, select=None):
    """Open the todo popup over `pane` on `client` (tmux binding, through run-shell), sized to the
    list; `select` is the row (0-based) to start on."""
    session = resolve_session(pane=pane)
    rows = TodoKeys(session).rows() if session else []
    floatlist.open_popup(client, os.path.realpath(__file__) + f" --pane {pane} --client {client} tui", rows,
                         FOOTER, f"{GLYPH_TODO} Todo", pane=pane, empty=EMPTY, theme=THEME, select_id=select)


def tui(pane, session=None, client=None):
    session = resolve_session(session, pane)
    if not session:
        print(f"todo: no Claude session recorded for tmux pane {pane or '?'} (it registers on Claude's next start).\r\nAny key closes.")
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setcbreak(fd)
            select.select([fd], [], [], 30)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        return
    k = TodoKeys(session, pane, client)
    k.restore()
    # refresh every 2 s, so Claude's or /todo's edits show while it is open; alt+t toggles it
    floatlist.FloatList(k.rows, k.keys(), FOOTER, EMPTY, refresh_s=2, close_keys=("\033t", "\033T"),
                        theme=THEME).run()


# ---------- cli ----------

def main():
    args = sys.argv[1:]
    opts = {"--session": None, "--pane": None, "--client": None}
    while args and args[0] in opts:
        if len(args) < 2:
            die(f"{args[0]} needs a value")
        opts[args[0]] = args[1]
        args = args[2:]
    session, pane, client = opts["--session"], opts["--pane"], opts["--client"]
    cmd, rest = (args[0], args[1:]) if args else ("ls", [])
    if cmd in ("-h", "--help", "help"):
        print(__doc__.strip())
        return
    if cmd == "tui":
        return tui(pane or os.environ.get("TMUX_PANE"), session, client)
    if cmd == "popup":
        if len(rest) not in (2, 3):
            die("popup takes <pane> <client> [row] (the tmux binding passes the first two)")
        return popup(*rest)

    sid = resolve_session(session, pane)
    if not sid:
        die("no session: pass --session, set CLAUDE_TODO_SESSION, or run inside a Claude tmux pane")
    items = load(sid)
    if cmd == "add":
        text = " ".join(rest).strip()
        if not text:
            die("add needs text")
        items.append([" ", text])
        save(sid, items)
        show(items)
    elif cmd == "ls":
        show(items)
    elif cmd in VERB_STATE:
        for i in indices(items, rest):
            items[i][0] = VERB_STATE[cmd]
        save(sid, items)
        show(items)
    elif cmd in ("rm", "remove"):
        drop = set(indices(items, rest))
        items = [x for i, x in enumerate(items) if i not in drop]
        save(sid, items)
        show(items)
    elif cmd == "clear":
        items = [] if rest[:1] == ["all"] else [x for x in items if x[0] != "x"]
        save(sid, items)
        show(items)
    elif cmd == "count":
        print(sum(state != "x" for state, _ in items))
    elif cmd == "file":
        print(store_file(sid))
    else:
        die(f"unknown command: {cmd} (todo --help)")


if __name__ == "__main__":
    main()
