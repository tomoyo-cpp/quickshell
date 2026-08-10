import QtQuick
import "root:/"

// Turns a Qt key event into the combo string niri writes in config.kdl.
//
// niri uses xkb keysym names, which mostly match Qt's key names but not
// always — the exceptions are listed below. Modifiers come out in niri's own
// order (Mod, Ctrl, Alt, Shift) so a rewritten line reads like a hand-written
// one.
QtObject {
    id: root

    // Qt.Key_* values whose xkb name differs from the obvious.
    readonly property var named: ({
            [Qt.Key_Return]: "Return",
            [Qt.Key_Enter]: "Return",
            [Qt.Key_Space]: "Space",
            [Qt.Key_Tab]: "Tab",
            [Qt.Key_Backspace]: "BackSpace",
            [Qt.Key_Delete]: "Delete",
            [Qt.Key_Insert]: "Insert",
            [Qt.Key_Home]: "Home",
            [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Page_Up",
            [Qt.Key_PageDown]: "Page_Down",
            [Qt.Key_Left]: "Left",
            [Qt.Key_Right]: "Right",
            [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down",
            [Qt.Key_Print]: "Print",
            [Qt.Key_Escape]: "Escape",
            [Qt.Key_Minus]: "Minus",
            [Qt.Key_Equal]: "Equal",
            [Qt.Key_Slash]: "Slash",
            [Qt.Key_Backslash]: "Backslash",
            [Qt.Key_Comma]: "Comma",
            [Qt.Key_Period]: "Period",
            [Qt.Key_Semicolon]: "Semicolon",
            [Qt.Key_Apostrophe]: "Apostrophe",
            [Qt.Key_BracketLeft]: "BracketLeft",
            [Qt.Key_BracketRight]: "BracketRight",
            [Qt.Key_QuoteLeft]: "Grave",
            [Qt.Key_Plus]: "Plus"
        })

    // Keys that only make sense as part of a combo, never alone.
    function isModifier(k) {
        return k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_AltGr;
    }

    function keyName(event) {
        const k = event.key;

        if (root.named[k] !== undefined)
            return root.named[k];

        if (k >= Qt.Key_F1 && k <= Qt.Key_F35)
            return "F" + (k - Qt.Key_F1 + 1);

        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String(k - Qt.Key_0);

        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k);

        // Anything else: fall back to the text the key produced, which covers
        // most remaining printable keys on non-US layouts.
        const t = (event.text ?? "").trim();
        return t.length === 1 ? t.toUpperCase() : "";
    }

    // As combo(), but unions the held modifiers with ones chosen elsewhere in
    // the UI. Lets a bind be built without physically holding a combination
    // the compositor would swallow first.
    function comboWith(event, wantSuper, wantCtrl, wantAlt, wantShift) {
        if (root.isModifier(event.key))
            return "";

        const name = root.keyName(event);
        if (name === "")
            return "";

        const parts = [];
        if (wantSuper || (event.modifiers & Qt.MetaModifier))
            parts.push("Mod");
        if (wantCtrl || (event.modifiers & Qt.ControlModifier))
            parts.push("Ctrl");
        if (wantAlt || (event.modifiers & Qt.AltModifier))
            parts.push("Alt");
        if (wantShift || (event.modifiers & Qt.ShiftModifier))
            parts.push("Shift");

        parts.push(name);
        return parts.join("+");
    }

    // "" when the event carries no usable key, so callers can ignore it and
    // keep waiting for a real press.
    function combo(event) {
        if (root.isModifier(event.key))
            return "";

        const name = root.keyName(event);
        if (name === "")
            return "";

        const parts = [];
        // niri calls the super key "Mod" by default.
        if (event.modifiers & Qt.MetaModifier)
            parts.push("Mod");
        if (event.modifiers & Qt.ControlModifier)
            parts.push("Ctrl");
        if (event.modifiers & Qt.AltModifier)
            parts.push("Alt");
        if (event.modifiers & Qt.ShiftModifier)
            parts.push("Shift");

        parts.push(name);
        return parts.join("+");
    }
}
