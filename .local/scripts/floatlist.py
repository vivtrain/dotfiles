"""floatlist — the list popup behind `pin` (session pins) and `tmux-sessions` (session switcher).

A frontend hands FloatList a function returning its rows and a dict of key handlers; FloatList
draws them (selection as a muted-blue pill, links as OSC 8 so kitty's link clicks work), runs
the navigation keys, and guarantees a way out: q, esc, ctrl+c, ctrl+d, any close key, and an
idle timeout. `open_popup` sizes a tmux popup to the rows and centres it on a pane.

Frontends import it after putting their own (resolved) folder on sys.path: `python3 -I`
leaves the script's folder off it.
"""
import os
import select
import sys
import termios
import time
import tty

class Theme:
    """sel_rgb: the selection pill ("r;g;b", white text on it); text: SGR colour of row text;
    accent: tmux colour of the popup border and title pill."""

    def __init__(self, sel_rgb, text, accent):
        self.sel = f"\033[48;2;{sel_rgb};97m"
        self.cap_l, self.cap_r = f"\033[38;2;{sel_rgb}m\ue0b6", f"\033[0;38;2;{sel_rgb}m\ue0b4\033[0m"
        self.text, self.accent = text, accent


# Pins: the tmux session menu's muted green (#1e4d2b) turned blue at the same lightness and
# saturation; blue text and border. Sessions: the session menu's own green and cyan.
BLUE = Theme("30;46;77", "34", "blue")   # #1e2e4d
GREEN = Theme("30;77;43", "0", "cyan")   # #1e4d2b, default text
ROW_PAD = 8  # " " margin, cap or space, "NN", " ", mark, " " before the text; one space after
CLOSE = "close"
IDLE_TIMEOUT_S = 600  # failsafe: never hold the popup forever


def osc8(href, text):
    return f"\033]8;;{href}\033\\{text}\033]8;;\033\\" if href else text


def clip(text, width):
    return text if len(text) <= width else text[: max(width - 1, 0)] + "…"


class Row:
    """One line: `text` (drawn blue; a link when `href`), `extra` (dim, after it), `mark`
    (one glyph before it, in SGR colour `mark_color`), `id` (keeps the selection on this row
    when the list changes; defaults to the text)."""

    def __init__(self, text, href=None, extra="", mark="", mark_color="39", id=None):
        self.text, self.href, self.extra = text, href, extra
        self.mark, self.mark_color = mark, mark_color
        self.id = text if id is None else id

    def width(self):
        return ROW_PAD + len(self.text) + (len(self.extra) + 2 if self.extra else 0)


# The launcher already has the rows (it sized the popup by them): it hands them to the popup in
# FLOATLIST_ROWS so the first frame draws at once, without the frontend's queries. Plain separators,
# not JSON: importing json costs more than the whole first frame.
_FS, _RS = "\x1f", "\x1e"
_FIELDS = ("text", "href", "extra", "mark", "mark_color", "id")


def rows_to_env(rows):
    return _RS.join(_FS.join("" if getattr(r, f) is None else str(getattr(r, f)) for f in _FIELDS) for r in rows)


def rows_from_env():
    raw = os.environ.get("FLOATLIST_ROWS")
    if raw is None:
        return None
    rows = []
    for rec in raw.split(_RS) if raw else []:
        text, href, extra, mark, mark_color, rid = (rec.split(_FS) + [""] * 6)[:6]
        rows.append(Row(text, href=href or None, extra=extra, mark=mark, mark_color=mark_color or "39", id=rid))
    return rows


def render(rows, sel, top, line, empty, t, cols, lines):
    """One whole frame as a string: the list from row `top` with `sel` as a pill, `line` at the
    bottom. Shared by the popup and the launcher's pre-rendered first frame (open_popup)."""
    body = max(lines - 3, 1)
    out = ["\033[H\033[2J\r\n"]
    if not rows:
        out.append(f"\033[2m{clip(empty, cols)}\033[0m\r\n")
    for i in range(top, min(top + body, len(rows))):
        r = rows[i]
        room = cols - ROW_PAD - (len(r.extra) + 2 if r.extra else 0)
        text = clip(r.text, max(room, 8))
        mark = f"\033[{r.mark_color}m{r.mark or ' '}"
        if i == sel:  # a pill around number, mark, text and extra
            extra = f"  \033[2m{r.extra}\033[22m" if r.extra else ""
            # t.sel again after the mark: its colour must not end the pill's background
            out.append(f" {t.cap_l}{t.sel}{i + 1:>2} {mark}{t.sel} {osc8(r.href, text)}{extra} {t.cap_r}\r\n")
        else:
            extra = f"  \033[2m{r.extra}\033[0m" if r.extra else ""
            out.append(f"  \033[2m{i + 1:>2}\033[0m {mark}\033[0m \033[{t.text}m{osc8(r.href, text)}\033[0m{extra}\r\n")
    out.append(f"\033[{lines};1H\033[2K\033[2m{clip(line, cols)}\033[0m")
    return "".join(out)


def _printf_format(text):
    """`text` as a single-quoted shell printf format: escapes for control chars, %% for %."""
    text = text.replace("\\", "\\\\").replace("%", "%%")
    text = text.replace("\033", "\\033").replace("\r", "\\r").replace("\n", "\\n")
    return "'" + text.replace("'", "'\\''") + "'"


class FloatList:
    """keys: {"x": fn, "dd": fn, ...}, each fn(ui) acting on ui.sel / ui.rows; returning CLOSE
    closes the popup. A name longer than one key is a sequence ("dd"). Unbound j/k/g/G and the
    arrows move; q, esc, ctrl+c, ctrl+d and `close_keys` (e.g. "\\033s" for alt+s) close."""

    NAV = {"j": 1, "k": -1}

    def __init__(self, rows, keys, footer, empty="  nothing here", refresh_s=None,
                 select_id=None, close_keys=(), theme=BLUE):
        self.rows_fn, self.keys, self.footer, self.empty, self.t = rows, keys, footer, empty, theme
        self.refresh_s, self.close_keys = refresh_s, set(close_keys)
        self.rows, self.sel, self.top, self.pending, self.status = [], 0, 0, "", ""
        self.fd = sys.stdin.fileno()
        first = rows_from_env()
        if first is None:
            self.reload(select_id)
        else:  # draw what the launcher saw; the loop's next reload brings the frontend's own
            self.rows = first
            ids = [r.id for r in first]
            want = os.environ.get("FLOATLIST_SELECT") or select_id
            self.sel = ids.index(want) if want in ids else 0
        for var in ("FLOATLIST_ROWS", "FLOATLIST_SELECT"):  # not for whatever the popup launches
            os.environ.pop(var, None)

    # ---- state ----
    def reload(self, select_id=None):
        keep = select_id if select_id is not None else (self.rows[self.sel].id if self.rows else None)
        self.rows = self.rows_fn()
        ids = [r.id for r in self.rows]
        if keep in ids:
            self.sel = ids.index(keep)
        self.sel = min(self.sel, max(len(self.rows) - 1, 0))

    def select(self, row_id):
        """Put the selection on the row with this id (after the next reload)."""
        self.reload(row_id)

    def flash(self, msg):
        """Show msg in place of the footer until the next key."""
        self.status = msg

    # ---- drawing ----
    def size(self):
        try:
            cols, lines = os.get_terminal_size(self.fd)
        except OSError:
            cols, lines = 0, 0
        return (cols if cols >= 20 else 80), (lines if lines >= 4 else 24)  # a pty can report 0x0

    def draw(self, bottom=None):
        cols, lines = self.size()
        body = max(lines - 3, 1)  # blank rows above the list and before the footer
        if self.sel < self.top:
            self.top = self.sel
        elif self.sel >= self.top + body:
            self.top = self.sel - body + 1
        line = bottom if bottom is not None else (self.status or self.footer)
        sys.stdout.write(render(self.rows, self.sel, self.top, line, self.empty, self.t, cols, lines))
        sys.stdout.flush()

    # ---- input ----
    def key(self, timeout):
        """One key, normalized: j/k/g/G for arrows and home/end, "enter", "quit" for
        esc/ctrl+c/ctrl+d, "timeout" when nothing came in `timeout` seconds; else the text."""
        ready, _, _ = select.select([self.fd], [], [], timeout)
        if not ready:
            return "timeout"
        data = os.read(self.fd, 32)
        while data == b"\033" or (data.startswith(b"\033[") and not data[-1:].isalpha() and data[-1:] != b"~"):
            if not select.select([self.fd], [], [], 0.005)[0]:  # tmux sends a sequence in one go
                break
            data += os.read(self.fd, 32)
        return {b"\033[A": "k", b"\033[B": "j", b"\033OA": "k", b"\033OB": "j",
                b"\033[H": "g", b"\033[F": "G", b"\r": "enter", b"\n": "enter",
                b"\033": "quit", b"\x03": "quit", b"\x04": "quit"}.get(data, data.decode(errors="replace"))

    def prompt(self, label, initial=""):
        """Read a line on the footer row. Enter returns it; esc / ctrl+c returns None."""
        text = initial
        while True:
            self.draw(bottom=f"  {label}: {text}█")
            k = self.key(IDLE_TIMEOUT_S)
            if k in ("quit", "timeout"):
                return None
            if k == "enter":
                return text
            if k in ("\x7f", "\x08"):
                text = text[:-1]
            elif k == "\x15":  # ctrl+u
                text = ""
            elif k.isprintable():
                text += k

    def confirm(self, question):
        self.draw(bottom=f"  {question} (y/n)")
        return self.key(IDLE_TIMEOUT_S) in ("y", "Y")

    # ---- loop ----
    def run(self):
        """Never returns: closing exits the process at once (os._exit), which makes tmux close the
        popup; children meant to outlive it are started detached by the frontends."""
        old = termios.tcgetattr(self.fd)
        sys.stdout.write("\033[?25l")
        idle_since = time.monotonic()
        warmed = False
        try:
            tty.setraw(self.fd)
            while True:
                self.draw()
                if not warmed:  # after the first frame, while the person reads it: the actions'
                    import subprocess  # noqa: F401  slowest import, so enter etc. don't pay it
                    warmed = True
                k = self.key(self.refresh_s or IDLE_TIMEOUT_S)
                if k == "timeout":
                    if time.monotonic() - idle_since >= IDLE_TIMEOUT_S:
                        return
                    self.reload()
                    continue
                idle_since, self.status = time.monotonic(), ""
                if k == "quit" or k in self.close_keys or (k == "q" and "q" not in self.keys):
                    return
                seq, self.pending = self.pending + k, ""
                if seq in self.keys:
                    if self.keys[seq](self) == CLOSE:
                        return
                elif any(name.startswith(seq) and name != seq for name in self.keys):
                    self.pending = seq
                elif k in self.NAV:
                    self.sel = max(0, min(self.sel + self.NAV[k], len(self.rows) - 1))
                elif k == "g":
                    self.sel = 0
                elif k == "G":
                    self.sel = max(len(self.rows) - 1, 0)
                self.reload()
        finally:
            # No clearing or cursor restore: the popup is about to vanish, and a cleared screen is a
            # blank frame. Put the tty back without waiting for output to drain, and go.
            termios.tcsetattr(self.fd, termios.TCSANOW, old)
            sys.stdout.flush()
            os._exit(0)


def open_popup(client, command, rows, footer, title, pane=None, anchor="pane", theme=BLUE,
               select_id=None, empty="  nothing here"):
    """Open `command` in a tmux popup on `client`, sized to `rows` (Row list) and the footer.
    anchor "pane": centred on `pane`; "window": centred on the client's window."""
    import subprocess  # here, not at the top: the popup itself never needs it before drawing

    def tmux(*a):
        return subprocess.run(["tmux", *a], capture_output=True, text=True).stdout.strip()
    widest = max([r.width() for r in rows] + [len(footer) + 1, 20])
    try:
        if anchor == "pane":
            pl, pt, pw, ph = (int(x) for x in tmux("display-message", "-p", "-t", pane,
                              "#{pane_left} #{pane_top} #{pane_width} #{pane_height}").split())
        else:
            pw, ph = (int(x) for x in tmux("display-message", "-p", "-c", client,
                      "#{window_width} #{window_height}").split())
            pl = pt = 0
    except ValueError:
        pl, pt, pw, ph = 0, 0, 120, 40
    # + 2 border columns and 2 spare; blank + rows + blank + footer + 2 border rows. At most the
    # pane less a margin, never below 40 x 7.
    w = min(widest + 4, max(pw - 4, 40))
    h = min(max(len(rows), 1) + 3 + 2, max(ph - 2, 7))
    if anchor == "pane":
        # Centred. tmux takes -y as the popup's bottom row (as P, "bottom left of the pane"
        # shows), so add h to the top row.
        pos = ["-x", str(pl + max((pw - w) // 2, 0)), "-y", str(pt + max((ph - h) // 2, 0) + h)]
    else:
        pos = ["-x", "C", "-y", "C"]
    a = theme.accent
    pill = (f"#[fg={a}]\ue0b6#[bg={a},fg=#000000,bold] {title} "
            f"#[bg=default,fg={a},nobold]\ue0b4")
    env = ["-e", f"FLOATLIST_ROWS={rows_to_env(rows)}"] + (["-e", f"FLOATLIST_SELECT={select_id}"] if select_id else [])
    # The first frame, pre-rendered at the popup's inner size (border excluded) and printed by the
    # shell before Python starts: the popup never shows an empty screen or a bare cursor.
    ids = [r.id for r in rows]
    sel = ids.index(select_id) if select_id in ids else 0
    cols, lines = w - 2, h - 2
    top = max(sel - max(lines - 3, 1) + 1, 0)
    frame = "\033[?25l" + render(rows, sel, top, footer, empty, theme, cols, lines)
    subprocess.run(["tmux", "display-popup", "-c", client, "-E", "-w", str(w), "-h", str(h), *pos, *env,
                    "-b", "rounded", "-S", f"fg={a}", "-T", pill, f"printf {_printf_format(frame)}; exec {command}"])
