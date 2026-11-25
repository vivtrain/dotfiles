# Vim keys in Nautilus 42's list view: j/k = down/up, h = parent folder, l = open (like Enter),
# Esc = close the window (only from the file list, and not while a search is open: Esc ends that).
# Nautilus has no keybinding config, so this hooks each window's key presses (needs python3-nautilus).
# Text fields (rename, path bar, search), the sidebar and modified keys (Ctrl/Alt/Super) pass
# through untouched; other letters still start type-to-search. A new window (e.g. opened from a
# link) has nothing focused, so hjkl there first focuses the visible list. Reload: nautilus -q
import weakref

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('Nautilus', '3.0')
from gi.repository import GObject, Gdk, Gtk, Nautilus

_MODS = (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK |
         Gdk.ModifierType.MOD1_MASK | Gdk.ModifierType.SUPER_MASK)
_hooked = weakref.WeakSet()


def _widgets(w):
    yield w
    if isinstance(w, Gtk.Container):
        kids = []
        w.forall(kids.append)  # forall, not get_children: the list sits in internal children too
        for k in kids:
            yield from _widgets(k)


def _visible_list(window):
    """The file list of the current tab: the mapped TreeView (other tabs' lists are unmapped)."""
    for w in _widgets(window):
        if isinstance(w, Gtk.TreeView) and w.get_mapped():
            return w
    return None


def _in_sidebar(w):
    while w is not None:
        if isinstance(w, Gtk.PlacesSidebar):
            return True
        w = w.get_parent()
    return False


def _search_open(window):
    return any(isinstance(w, Gtk.SearchEntry) and w.get_mapped() for w in _widgets(window))


def _on_key(window, event):
    if event.state & _MODS:
        return False
    key = Gdk.keyval_name(event.keyval)
    if key == 'Escape':
        if isinstance(window.get_focus(), Gtk.TreeView) and not _search_open(window):
            window.close()
            return True
        return False
    if key not in ('h', 'j', 'k', 'l'):
        return False
    focus = window.get_focus()
    if not isinstance(focus, Gtk.TreeView):
        if isinstance(focus, Gtk.Editable) or _in_sidebar(focus):  # typing, or the sidebar's own keys
            return False
        focus = _visible_list(window)  # nothing (or a button) focused, e.g. a freshly opened window
        if focus is None:  # grid view has no TreeView: leave keys alone
            return False
        focus.grab_focus()

    if key in ('j', 'k'):
        focus.emit('move-cursor', Gtk.MovementStep.DISPLAY_LINES, 1 if key == 'j' else -1)
    elif key == 'h':
        action = window.lookup_action('up')
        if action is None:
            return False
        action.activate(None)
    else:
        path, column = focus.get_cursor()
        if path is None:
            return False
        focus.row_activated(path, column or focus.get_column(0))
    return True


class VimNav(GObject.GObject, Nautilus.LocationWidgetProvider):
    # Called on every location change with the window; used only to hook each window once.
    def get_widget(self, uri, window):
        if window not in _hooked:
            _hooked.add(window)
            window.connect('key-press-event', _on_key)
        return None
