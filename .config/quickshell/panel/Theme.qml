pragma Singleton

import Quickshell
import QtQuick

// ===========================================================================
//  Shared design tokens for the side panel.
//  These mirror ~/.config/waybar/colors.css exactly — change both together.
// ===========================================================================
Singleton {
    // -- surfaces -----------------------------------------------------------
    readonly property color bg0: "#2E3440"   // base
    readonly property color bg1: "#3B4252"   // raised card
    readonly property color bg2: "#434C5E"   // hover / meter track
    readonly property color bdr: "#4C566A"   // hairline

    // -- raised-surface set (mirrors waybar/colors.css) ---------------------
    // Chips must be LIGHTER than the bar to read as raised; they used to be
    // darker, which looked like holes punched in the slab.
    readonly property color barBase: "#242933"
    readonly property color chip: "#3B4252"
    readonly property color chipHi: "#434C5E"
    readonly property color bdrHi: "#4C566A"

    // -- text ---------------------------------------------------------------
    readonly property color fg: "#D8DEE9"
    readonly property color fgDim: "#616E88"
    readonly property color fgFaint: "#4C566A"

    // -- the one accent -----------------------------------------------------
    readonly property color acc: "#88C0D0"   // nord8 frost cyan — THE accent
    readonly property color accDim: "#5F8692"

    // -- states -------------------------------------------------------------
    readonly property color ok: "#A3BE8C"
    readonly property color warn: "#EBCB8B"
    readonly property color crit: "#BF616A"

    // -- alpha helpers ------------------------------------------------------
    function a(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    // Panel background is translucent so the Hyprland layerrule blur reads.
    readonly property color panelBg: Qt.rgba(bg0.r, bg0.g, bg0.b, 0.72)
    readonly property color cardBg: Qt.rgba(bg1.r, bg1.g, bg1.b, 0.55)

    // -- metrics ------------------------------------------------------------
    readonly property int radius: 6          // small — sharp, not bubbly
    readonly property int radiusSm: 4
    readonly property int pad: 12
    readonly property int gap: 8
    readonly property int panelWidth: 400

    // -- type ---------------------------------------------------------------
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fsXs: 10
    readonly property int fsSm: 11
    readonly property int fsMd: 12
    readonly property int fsLg: 14

    readonly property int animFast: 130
    readonly property int animSlide: 220
}
