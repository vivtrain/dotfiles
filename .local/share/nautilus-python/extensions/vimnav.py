# Vim keys in Nautilus 42's list view: j/k = down/up, h = parent folder, l = open (like Enter).
# Nautilus has no keybinding config, so this hooks each window's key presses (needs python3-nautilus).
# Text fields (rename, path bar, search) and modified keys (Ctrl/Alt/Super) pass through untouched;
# other letters still start type-to-search. Reload: nautilus -q
import weakref

import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('Nautilus', '3.0')
from gi.repository import GObject, Gdk, Gtk, Nautilus

_MODS = (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK |
         Gdk.ModifierType.MOD1_MASK | Gdk.ModifierType.SUPER_MASK)
_hooked = weakref.WeakSet()


def _on_key(window, event):
    if event.state & _MODS:
        return False
    key = Gdk.keyval_name(event.keyval)
    if key not in ('h', 'j', 'k', 'l'):
        return False
    focus = window.get_focus()
    if not isinstance(focus, Gtk.TreeView):  # sidebar, text fields, grid view: leave keys alone
        return False

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
