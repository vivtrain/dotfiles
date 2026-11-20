/* Keybindings to click / dismiss the notification that just popped up.
 * Targets the banner on screen; if none is showing, the newest one in the tray. */
const { Meta, Shell } = imports.gi;
const Main = imports.ui.main;
const ExtensionUtils = imports.misc.extensionUtils;

function latestNotification() {
    const tray = Main.messageTray;
    if (tray._notification)
        return tray._notification;
    let newest = null;
    for (const source of tray.getSources()) {
        for (const n of source.notifications) {
            if (!newest || n.datetime.compare(newest.datetime) > 0)
                newest = n;
        }
    }
    return newest;
}

class Extension {
    enable() {
        this._settings = ExtensionUtils.getSettings();
        const add = (name, fn) => Main.wm.addKeybinding(name, this._settings,
            Meta.KeyBindingFlags.NONE, Shell.ActionMode.ALL, fn);
        add('activate-notification', () => {
            const n = latestNotification();
            if (!n) return;
            n.activate();
            Main.panel.closeCalendar();
        });
        add('dismiss-notification', () => {
            latestNotification()?.destroy();
        });
    }

    disable() {
        Main.wm.removeKeybinding('activate-notification');
        Main.wm.removeKeybinding('dismiss-notification');
        this._settings = null;
    }
}

function init() {
    return new Extension();
}
