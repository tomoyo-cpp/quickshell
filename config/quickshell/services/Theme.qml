pragma Singleton

import QtQuick
import Quickshell
import "root:/"

// Catppuccin — https://github.com/catppuccin/catppuccin
//
// All four flavours are carried here and selected at runtime by
// Settings.flavour; every colour below is read out of `palette`, so nothing
// downstream needs to know which flavour is active.
Singleton {
    id: root

    readonly property var flavours: ({
            mocha: {
                rosewater: "#f5e0dc",
                flamingo: "#f2cdcd",
                pink: "#f5c2e7",
                mauve: "#cba6f7",
                red: "#f38ba8",
                maroon: "#eba0ac",
                peach: "#fab387",
                yellow: "#f9e2af",
                green: "#a6e3a1",
                teal: "#94e2d5",
                sky: "#89dceb",
                sapphire: "#74c7ec",
                blue: "#89b4fa",
                lavender: "#b4befe",
                text: "#cdd6f4",
                subtext1: "#bac2de",
                subtext0: "#a6adc8",
                overlay2: "#9399b2",
                overlay1: "#7f849c",
                overlay0: "#6c7086",
                surface2: "#585b70",
                surface1: "#45475a",
                surface0: "#313244",
                base: "#1e1e2e",
                mantle: "#181825",
                crust: "#11111b"
            },
            macchiato: {
                rosewater: "#f4dbd6",
                flamingo: "#f0c6c6",
                pink: "#f5bde6",
                mauve: "#c6a0f6",
                red: "#ed8796",
                maroon: "#ee99a0",
                peach: "#f5a97f",
                yellow: "#eed49f",
                green: "#a6da95",
                teal: "#8bd5ca",
                sky: "#91d7e3",
                sapphire: "#7dc4e4",
                blue: "#8aadf4",
                lavender: "#b7bdf8",
                text: "#cad3f5",
                subtext1: "#b8c0e0",
                subtext0: "#a5adcb",
                overlay2: "#939ab7",
                overlay1: "#8087a2",
                overlay0: "#6e738d",
                surface2: "#5b6078",
                surface1: "#494d64",
                surface0: "#363a4f",
                base: "#24273a",
                mantle: "#1e2030",
                crust: "#181926"
            },
            frappe: {
                rosewater: "#f2d5cf",
                flamingo: "#eebebe",
                pink: "#f4b8e4",
                mauve: "#ca9ee6",
                red: "#e78284",
                maroon: "#ea999c",
                peach: "#ef9f76",
                yellow: "#e5c890",
                green: "#a6d189",
                teal: "#81c8be",
                sky: "#99d1db",
                sapphire: "#85c1dc",
                blue: "#8caaee",
                lavender: "#babbf1",
                text: "#c6d0f5",
                subtext1: "#b5bfe2",
                subtext0: "#a5adce",
                overlay2: "#949cbb",
                overlay1: "#838ba7",
                overlay0: "#737994",
                surface2: "#626880",
                surface1: "#51576d",
                surface0: "#414559",
                base: "#303446",
                mantle: "#292c3c",
                crust: "#232634"
            },
            latte: {
                rosewater: "#dc8a78",
                flamingo: "#dd7878",
                pink: "#ea76cb",
                mauve: "#8839ef",
                red: "#d20f39",
                maroon: "#e64553",
                peach: "#fe640b",
                yellow: "#df8e1d",
                green: "#40a02b",
                teal: "#179299",
                sky: "#04a5e5",
                sapphire: "#209fb5",
                blue: "#1e66f5",
                lavender: "#7287fd",
                text: "#4c4f69",
                subtext1: "#5c5f77",
                subtext0: "#6c6f85",
                overlay2: "#7c7f93",
                overlay1: "#8c8fa1",
                overlay0: "#9ca0b0",
                surface2: "#acb0be",
                surface1: "#bcc0cc",
                surface0: "#ccd0da",
                base: "#eff1f5",
                mantle: "#e6e9ef",
                crust: "#dce0e8"
            }
        })

    readonly property var palette: root.flavours[Settings.flavour] ?? root.flavours.mocha

    // ── Palette ──────────────────────────────────────────────────────────
    readonly property color rosewater: root.palette.rosewater
    readonly property color flamingo: root.palette.flamingo
    readonly property color pink: root.palette.pink
    readonly property color mauve: root.palette.mauve
    readonly property color red: root.palette.red
    readonly property color maroon: root.palette.maroon
    readonly property color peach: root.palette.peach
    readonly property color yellow: root.palette.yellow
    readonly property color green: root.palette.green
    readonly property color teal: root.palette.teal
    readonly property color sky: root.palette.sky
    readonly property color sapphire: root.palette.sapphire
    readonly property color blue: root.palette.blue
    readonly property color lavender: root.palette.lavender

    readonly property color text: root.palette.text
    readonly property color subtext1: root.palette.subtext1
    readonly property color subtext0: root.palette.subtext0
    readonly property color overlay2: root.palette.overlay2
    readonly property color overlay1: root.palette.overlay1
    readonly property color overlay0: root.palette.overlay0
    readonly property color surface2: root.palette.surface2
    readonly property color surface1: root.palette.surface1
    readonly property color surface0: root.palette.surface0
    readonly property color base: root.palette.base
    readonly property color mantle: root.palette.mantle
    readonly property color crust: root.palette.crust

    // Accents that are not palette entries. "text" is the original all-white
    // bar; "black" is here because it is asked for, though on a dark bar it
    // renders icons nearly invisible — it belongs with the Latte flavour.
    readonly property var extraAccents: ({
            text: "#ffffff",
            black: "#000000"
        })

    function accentFor(key) {
        return root.extraAccents[key] ?? root.palette[key] ?? "#ffffff";
    }

    // Colours worth offering as an accent, in the order the picker shows them.
    readonly property var accentKeys: ["text", "black", "blue", "mauve", "lavender", "sapphire", "sky", "teal", "green", "yellow", "peach", "maroon", "red", "pink", "flamingo", "rosewater"]

    // ── Metrics ──────────────────────────────────────────────────────────
    // Nesting, outermost first: backdrop > container > pill / workspace.
    // Each sits inset inside the one above so the layer below shows as a rim.
    readonly property int barHeight: Settings.barHeight
    readonly property int barMargin: Settings.barMargin
    readonly property int barSideMargin: Settings.barSideMargin
    // Falls back to the left value while the two are linked, which is the
    // default — most layouts want one number.
    readonly property int barSideMarginRight: Settings.linkSideMargins ? Settings.barSideMargin : Settings.barSideMarginRight
    readonly property int barRadius: Settings.barRadius

    // Space reserved from tiled windows. Deliberately independent of
    // barMargin: raising the top margin should float the bar further down the
    // gap, not shove every window on the screen down with it.
    readonly property int reservedMargin: Settings.reservedMargin
    readonly property int reservedSpace: barHeight + reservedMargin

    // Room reserved around the bar strip for its drop shadow.
    readonly property int shadowPad: 12

    readonly property bool atBottom: Settings.barPosition === "bottom"

    readonly property int containerInset: Settings.containerInset
    readonly property int containerHeight: barHeight - containerInset * 2
    readonly property int containerRadius: Settings.containerRadius

    readonly property int pillHeight: containerHeight - 6
    readonly property int pillRadius: pillHeight / 2
    readonly property int pillPadding: Settings.pillPadding

    readonly property int workspaceHeight: containerHeight - 4
    // Fully rounded — half the height gives a stadium capsule at any width.
    readonly property int workspaceRadius: workspaceHeight / 2
    readonly property int workspaceIconSize: Settings.workspaceIconSize

    readonly property int gap: Settings.gap

    // Corner radius for everything that hangs off the bar. The dropdown
    // outlines round their bottom corners with this; toasts and the preview
    // stop card use it on all four.
    readonly property int popupRadius: Settings.panelRadius
    readonly property int popupPadding: 14
    readonly property int popupBorder: 1

    // Scales a base duration by the user's multiplier, and collapses to 0 when
    // animations are switched off. Called from `duration:` bindings, which
    // re-evaluate because the Settings reads happen inside the call.
    //
    // Deliberately not applied to continuous motion — the audio visualiser and
    // the volume wave — where a zero duration freezes the thing mid-frame and
    // reads as a bug rather than as "animations off".
    // animSpeed is a speed factor, not a duration multiplier: 2x is twice as
    // fast, so it divides. Floored well above zero because this is a divisor.
    function dur(ms) {
        if (!Settings.animationsEnabled)
            return 0;
        return Math.max(0, Math.round(ms / Math.max(0.1, Settings.animSpeed)));
    }

    // The default transition length, for the many Behaviors that just want
    // "the usual".
    readonly property int anim: root.dur(180)

    // ── Typography ───────────────────────────────────────────────────────
    readonly property string font: "JetBrainsMono Nerd Font"
    // The Mono variant squeezes each icon into one cell and centres it in
    // that cell. The default variant left-aligns them in a wider cell, which
    // makes glyphs sit off-centre inside round containers.
    readonly property string iconFont: "JetBrainsMono Nerd Font Mono"
    readonly property int fontSize: Settings.fontSize
    readonly property int iconSize: Settings.iconSize

    // ── Semantic ─────────────────────────────────────────────────────────
    // The accent drives icons and active states. "text" reproduces the
    // original all-white bar.
    readonly property color accent: root.accentFor(Settings.accent)
    readonly property color icon: root.accent

    // The surface ladder: each tier is lighter than the one it sits on.
    readonly property color barBg: Qt.rgba(crust.r, crust.g, crust.b, Settings.barOpacity)

    // Same tier as the bar, on its own opacity. Everything that hangs off the
    // bar used barBg directly and Settings.panelOpacity was read by nothing, so
    // the Appearance slider moved a value no one consumed.
    //
    // Worth knowing when setting it: the dropdown outlines flow out of the bar
    // through a concave fillet, so the two meet along a visible edge. Matching
    // this to barOpacity keeps that join seamless; parting them draws a seam.
    readonly property color panelBg: Qt.rgba(crust.r, crust.g, crust.b, Settings.panelOpacity)
    readonly property color containerBg: Qt.rgba(surface0.r, surface0.g, surface0.b, Settings.containerOpacity)
    readonly property color pillBgHover: Qt.rgba(surface1.r, surface1.g, surface1.b, 0.85)

    readonly property color borderColor: Qt.rgba(surface0.r, surface0.g, surface0.b, 0.9)

    // Alpha helper — Theme.alpha(Theme.blue, 0.2)
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
