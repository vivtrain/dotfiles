#!/usr/bin/env -S python3 -I -S
"""links — pick a link off the screen of the current tmux pane, in a floatlist popup.

Scans the pane for OSC 8 hyperlinks (what Claude Code, the status line and the
popups draw: file:///path, file:///copy/<cmd>, file:///tmux/<pane>, https://...) and bare
http(s) URLs. An alternate-screen pane (Claude, vim) gives its visible screen; others also give
their recent scrollback. Links are in screen order, top to bottom, and each target is listed
once, where it first appears.

  links popup <pane> <client>   open the popup (tmux binding, alt+shift+u)
  links tui --pane %N           what runs in it: enter or 1-9 opens (as a kitty click does),
                                y copies the target, p pins it to that pane's Claude session,
                                j/k g/G move, q/esc/alt+shift+u close
  links ls [--pane %N]          list what the popup would show (target, then label)
"""
import os
import re
import sys

sys.dont_write_bytecode = True  # no __pycache__ in ~/.local/scripts (a dotfiles dir)
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))  # floatlist and pin, beside this file
import floatlist  # noqa: E402
from floatlist import CLOSE, Row  # noqa: E402

GLYPH_LINKS = "\U000f0339"  # md-link_variant
FOOTER = "  enter/1-9 open · y copy · p pin · q quit"
EMPTY = "  no links in this pane"
SCROLLBACK = 300  # lines of history per non-alternate-screen pane

# OSC 8: ESC ] 8 ; params ; URI ST ... ESC ] 8 ; ; ST, with ST = ESC \ or BEL.
OSC8 = re.compile(r"\x1b\]8;([^;\x07\x1b]*);([^\x07\x1b]*)(?:\x1b\\|\x07)")
ESCAPES = re.compile(r"\x1b\][^\x07\x1b]*(?:\x1b\\|\x07)|\x1b\[[0-9;:?<=>]*[ -/]*[@-~]|\x1b[@-Z\\-_]")
BARE_URL = re.compile(r"https?://[^\s<>\"'`│\\]+")


def tmux(*args):
    import subprocess
    return subprocess.run(["tmux", *args], capture_output=True, text=True).stdout


def plain(text):
    return ESCAPES.sub("", text)


def scan_text(text):
    """-> [(target, label, id)] in screen order. Consecutive pieces of one link (a label the
    terminal wrapped, re-opened on the next row with the same id) are joined."""
    out = []  # [target, label, id]

    def bare(chunk):
        for u in BARE_URL.finditer(plain(chunk)):
            out.append([u.group(0).rstrip(".,;:!?)]}"), "", ""])

    pos, cur = 0, None  # cur: (id, uri) of the link open at pos, if any
    for m in OSC8.finditer(text):
        chunk = text[pos:m.start()]
        if cur:
            lid, uri = cur
            if out and lid and out[-1][0] == uri and out[-1][2] == lid:
                out[-1][1] += " " + plain(chunk)
            else:
                out.append([uri, plain(chunk), lid])
        else:
            bare(chunk)
        params, uri = m.group(1), m.group(2)
        if cur and not uri and plain(text[m.end():m.end() + 64])[:1].isalnum():
            # Closed mid-word: tmux ends a link where the terminal wrapped it and returns the rest
            # of the label as plain text, so the label is cut short. Say so rather than guess.
            out[-1][1] = out[-1][1].rstrip() + "…"
        lid = next((p[3:] for p in params.split(":") if p.startswith("id=")), "")
        cur = (lid, uri) if uri else None
        pos = m.end()
    bare(text[pos:])
    return [(t, " ".join(label.split()), lid) for t, label, lid in out]


def collect(pane):
    """-> [(target, label, pane)] for `pane`, in screen order, top to bottom, one per target."""
    from pin import label_of
    alt = tmux("display-message", "-p", "-t", pane, "#{alternate_on}").strip() == "1"
    args = ["capture-pane", "-p", "-e", "-J", "-t", pane] + ([] if alt else ["-S", f"-{SCROLLBACK}"])
    seen, out = set(), []
    for target, label, _ in scan_text(tmux(*args)):
        if not target or target in seen:
            continue
        seen.add(target)
        bare = not label or len(label) <= 2  # empty, or just a glyph
        out.append((target, label_of(target) if bare else label, pane))
    return out


def copy_text(target):
    """What y copies: the command of a copy link, the path of a file link, else the URL."""
    from urllib.parse import unquote, urlparse
    from pin import COPY, TMUX
    if target.startswith(COPY):
        return unquote(target[len(COPY):])
    if target.startswith("file://") and not target.startswith(TMUX):
        return unquote(urlparse(target).path)
    return target


class LinkKeys:
    def __init__(self, pane):
        self.pane = pane
        self.items = collect(pane)  # a snapshot: the screen moves on while the popup is open

    def rows(self):
        return [Row(label, href=target, id=target) for target, label, _ in self.items]

    def keys(self):
        k = {"enter": self.open, "y": self.copy, "p": self.pin}
        for n in range(1, 10):
            k[str(n)] = (lambda n: lambda ui: self.open(ui, n - 1))(n)
        return k

    def open(self, ui, i=None):
        from pin import open_target
        i = ui.sel if i is None else i
        if 0 <= i < len(self.items):
            open_target(self.items[i][0])
            return CLOSE

    def copy(self, ui):
        import subprocess
        if self.items:
            text = copy_text(self.items[ui.sel][0])
            subprocess.run(["xclip", "-selection", "clipboard"], input=text, text=True)
            ui.flash(f"  copied {text}")

    def pin(self, ui):
        import subprocess
        if not self.items:
            return
        target, label, _ = self.items[ui.sel]
        # pin's pane -> session map outlives panes and pane ids get reused, so only trust it for a
        # pane that is running Claude now.
        if tmux("display-message", "-p", "-t", self.pane, "#{pane_current_command}").strip() == "claude":
            r = subprocess.run([os.path.join(os.path.dirname(os.path.realpath(__file__)), "pin.py"),
                                "--pane", self.pane, "add", target, label], capture_output=True, text=True)
            if r.returncode == 0:
                ui.flash("  " + r.stdout.strip())
                return
        ui.flash("  no Claude session in this pane to pin to")


def popup(pane, client):
    k = LinkKeys(pane)
    floatlist.open_popup(client, os.path.realpath(__file__) + f" --pane {pane} tui", k.rows(), FOOTER,
                         f"{GLYPH_LINKS} Links", pane=pane, empty=EMPTY)


def tui(pane):
    k = LinkKeys(pane)
    floatlist.FloatList(k.rows, k.keys(), FOOTER, EMPTY, close_keys=("\033U",)).run()


def main():
    args = sys.argv[1:]
    pane = os.environ.get("TMUX_PANE")
    if args[:1] == ["--pane"] and len(args) >= 2:
        pane, args = args[1], args[2:]
    cmd, rest = (args[0], args[1:]) if args else ("ls", [])
    if cmd in ("-h", "--help", "help"):
        print(__doc__.strip())
    elif cmd == "popup" and len(rest) == 2:
        popup(*rest)
    elif cmd == "tui":
        tui(pane)
    elif cmd == "ls":
        if rest[:1] == ["--pane"] and len(rest) == 2:
            pane = rest[1]
        for target, label, p in collect(pane):
            print(f"{p}\t{target}\t{label}")
    else:
        sys.exit("links: usage: links popup <pane> <client> | links tui --pane %N | links ls [--pane %N]")


if __name__ == "__main__":
    main()
