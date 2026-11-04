# Pin the link under the mouse (OSC 8 target or detected URL) to the Claude session of the tmux
# pane that was clicked, via ~/.local/bin/pin. Same trick as copy_link.py: run kitty's normal
# link click with the window's open_url_handler hook swapped for a pinner.
#
# The pane: the tmux client is the process on this kitty window's tty (client name = that tty);
# the clicked cell is mapped onto that client's window's panes. If the mouse cell can't be read,
# the client's active pane is used. Each click logs to ~/.cache/claude-pins/kitten.log.
import os
import subprocess
import time

from kittens.tui.handler import result_handler

LOG = os.path.expanduser('~/.cache/claude-pins/kitten.log')
PIN = os.path.expanduser('~/.local/bin/pin')


def main(args):
    pass


def log(msg):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, 'a') as f:
            f.write(f'{time.strftime("%F %T")} {msg}\n')
    except OSError:
        pass


def tmux(*args):
    return subprocess.run(['tmux', *args], capture_output=True, text=True).stdout.strip()


def window_tty(w):
    try:
        return os.readlink(f'/proc/{w.child.pid}/fd/0')
    except (OSError, AttributeError):
        return None


def mouse_cell(w):
    mp = w.current_mouse_position()
    log(f'mouse position: {mp!r}')
    if mp is None:
        return None
    get = mp.get if isinstance(mp, dict) else (lambda k, d=None: getattr(mp, k, d))
    x, y = get('cell_x'), get('cell_y')
    return (x, y) if isinstance(x, int) and isinstance(y, int) else None


def clicked_pane(w, client):
    cell = mouse_cell(w)
    if cell:
        x, y = cell
        win = tmux('display-message', '-p', '-c', client, '#{window_id}')
        for line in tmux('list-panes', '-t', win, '-F',
                         '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}').splitlines():
            pid, left, top, width, height = line.split()
            if int(left) <= x < int(left) + int(width) and int(top) <= y < int(top) + int(height):
                return pid
        log(f'cell {cell} is on no pane (border or status line)')
    return tmux('display-message', '-p', '-c', client, '#{pane_id}') or None


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    def pin(boss, window, url, hyperlink_id, cwd):
        client = window_tty(w)
        pane = clicked_pane(w, client) if client else None
        log(f'url={url} client={client} pane={pane}')
        if not pane:
            return True  # handled (nothing to pin to); don't open it either
        r = subprocess.run([PIN, '--pane', pane, 'add', url], capture_output=True, text=True)
        msg = (r.stdout or r.stderr).strip().removeprefix('pin: ')
        log(f'pin: {msg}')
        tmux('display-message', '-c', client, '-d', '2000', f'󰐃 {msg}')
        return True

    prev = getattr(w, 'open_url_handler', None)
    w.open_url_handler = pin
    try:
        w.mouse_handle_click('link')
    finally:
        w.open_url_handler = prev
