# h / l = previous / next image, added alongside eog's existing shortcuts (arrows etc.).
# eog 42 binds keys with GTK application accels, not ~/.config/eog/accels, so this sets them here.
# Enable: gsettings set org.gnome.eog.plugins active-plugins "['fullscreen', 'vimnav']"
from gi.repository import GObject, Eog

EXTRA = {'win.go-previous': ['h'], 'win.go-next': ['l']}


class VimNav(GObject.Object, Eog.ApplicationActivatable):
    app = GObject.Property(type=Eog.Application)

    def do_activate(self):
        for action, keys in EXTRA.items():
            cur = list(self.app.get_accels_for_action(action))
            self.app.set_accels_for_action(action, cur + [k for k in keys if k not in cur])

    def do_deactivate(self):
        for action, keys in EXTRA.items():
            cur = self.app.get_accels_for_action(action)
            self.app.set_accels_for_action(action, [k for k in cur if k not in keys])
