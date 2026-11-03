# "Open file location" for the link under the mouse: plain file:// links open their parent folder
# in Nautilus with the file selected. Other links (web, file:///copy/, file:///tmux/) open normally.
# Runs kitty's normal link click with the window's open_url_handler hook swapped (see copy_link.py).
import subprocess
from urllib.parse import unquote, urlparse

from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    def reveal(boss, window, url, hyperlink_id, cwd):
        if not url.startswith('file://') or url.startswith(('file:///copy/', 'file:///tmux/')):
            return False  # not handled: kitty opens it the usual way
        path = unquote(urlparse(url).path)
        subprocess.Popen(['nautilus', '--select', path],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True

    prev = getattr(w, 'open_url_handler', None)
    w.open_url_handler = reveal
    try:
        w.mouse_handle_click('link')
    finally:
        w.open_url_handler = prev
