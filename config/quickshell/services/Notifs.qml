pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import "root:/"

// Freedesktop notification daemon + a small history buffer.
// This replaces mako — only one notification daemon may own the bus name.
Singleton {
    id: root

    property bool dnd: false
    // Live Notification objects currently shown as toasts.
    property var popups: []
    // Plain snapshots, newest first, so entries survive the object being freed.
    property var history: []

    readonly property int unread: history.filter(n => !n.seen).length

    function markAllSeen() {
        root.history = root.history.map(n => Object.assign({}, n, { seen: true }));
    }

    // Removal is deferred behind an exit animation, during which a new
    // notification can arrive and shift every index. Entries therefore carry
    // their own id and are removed by it, never by position.
    property int _seq: 0

    function removeById(uid) {
        root.history = root.history.filter(h => h.uid !== uid);
    }

    function removeAt(index) {
        if (index < 0 || index >= root.history.length)
            return;
        const next = root.history.slice();
        next.splice(index, 1);
        root.history = next;
    }

    // Toasts hold live Notification objects while history holds snapshots, so
    // the two are matched on app + summary, newest first.
    function removeMatching(n) {
        for (let i = 0; i < root.history.length; ++i) {
            const h = root.history[i];
            if (h.appName === n.appName && h.summary === n.summary) {
                root.removeAt(i);
                return;
            }
        }
    }

    function clearHistory() {
        root.history = [];
    }

    function dismissPopup(n) {
        root.popups = root.popups.filter(p => p !== n);
        if (n && n.tracked)
            n.tracked = false;
    }

    // Drop a notification whose object is going away, without touching it.
    //
    // A client can close its own notification while the toast is still on
    // screen — boot-time services do this routinely, posting a status and
    // withdrawing it moments later. The Notification was destroyed but stayed
    // in `popups`, so the card rendered blank and the binding driving its
    // expiry timer failed against the dead object: an empty toast that never
    // went away.
    function _forget(n) {
        root.popups = root.popups.filter(p => p !== n);
    }

    function dismissAllPopups() {
        for (const p of root.popups)
            if (p.tracked)
                p.tracked = false;
        root.popups = [];
    }

    // The image worth showing full-width, if any.
    //
    // niri hands the screenshot's path in the notification's app_icon field
    // rather than sending an image hint, so a file:// URL that points at an
    // image file is a genuine preview — unlike a themed app icon, which
    // belongs in the small slot.
    // Only a real file counts. A bare icon *name* — what `notify-send -i`
    // sends — is not loadable as an image source, and handing one to an Image
    // renders uninitialised memory rather than failing cleanly.
    function _looksLikeImage(s) {
        if (!s || typeof s !== "string")
            return false;
        if (!s.startsWith("file://") && !s.startsWith("/"))
            return false;
        return /\.(png|jpe?g|webp|gif|bmp)$/i.test(decodeURIComponent(s));
    }

    function previewOf(n) {
        if (!n)
            return "";
        if (root._looksLikeImage(n.image))
            return n.image;
        return root._looksLikeImage(n.appIcon) ? n.appIcon : "";
    }

    function _snapshot(n) {
        return {
            uid: ++root._seq,
            appName: n.appName,
            appIcon: n.appIcon,
            summary: n.summary,
            body: n.body,
            image: n.image,
            urgency: n.urgency,
            time: new Date(),
            seen: false
        };
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: n => {
            root.history = [root._snapshot(n)].concat(root.history).slice(0, 100);

            if (root.dnd)
                return;

            n.tracked = true;
            // Closed by the sender, or expired server-side: take it out of
            // `popups` rather than leaving a card bound to a dead object.
            n.closed.connect(() => root._forget(n));
            root.popups = root.popups.concat([n]);

            // Drop the oldest toast if they stack up.
            if (root.popups.length > 4)
                root.dismissPopup(root.popups[0]);
        }
    }
}
