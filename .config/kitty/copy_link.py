# Copy the link under the mouse (OSC 8 hyperlink target or detected URL) instead of opening it.
# Runs kitty's normal link click with the window's open_url_handler hook swapped for a copier.
import subprocess

from kittens.tui.handler import result_handler
from kitty.clipboard import set_clipboard_string, set_primary_selection


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    def copy(boss, window, url, hyperlink_id, cwd):
        set_clipboard_string(url)
        set_primary_selection(url)
        # Middle-click inside tmux pastes tmux's buffer, not the X primary selection.
        subprocess.run(['tmux', 'set-buffer', '--', url], stderr=subprocess.DEVNULL, check=False)
        return True

    prev = getattr(w, 'open_url_handler', None)
    w.open_url_handler = copy
    try:
        w.mouse_handle_click('link')
    finally:
        w.open_url_handler = prev
