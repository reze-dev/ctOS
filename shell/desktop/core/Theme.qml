pragma Singleton

import QtQuick
import Quickshell

// Design tokens for the Living Notch / command centre.
//
// Palette provenance: a Rosé Pine derivative taken from the nvchad/base46 theme
// (M.base_30 and M.base_16), not the official Rosé Pine release. It reads deeper
// and more muted than official Main -- its base is #13111e against Main's
// #191724 -- which is the "darker" look this was after.
//
// Note the official variants, for reference: Main is the darkest of the three
// (base relative luminance 0.0095, versus Moon's 0.0171). Moon is lighter, not
// darker. So this palette is not "Rosé Pine Moon"; it is a third, darker thing,
// and the values below come from base46.
//
// The rule this file exists to enforce: colour is referenced by role, never
// inlined. Semantic aliases sit on top of a raw palette so a future theme swap is
// a change to the block below and nothing else.
//
// Role assignments, and why they are not simply "the nearest colour":
//
//   Iris is the accent: active, selected, focused, today. Rosé Pine's `love` is
//   its red, so spending it on the accent would leave destructive actions with
//   nothing to distinguish them -- the Poweroff button and the focus ring would
//   be the same colour.
//   Love is health-failing: destructive, error, danger.
//   Pine is health: connected, charging, positive.
//   Foam is the cool secondary: informational, hover borders.
//   Gold is the warm notice: warnings and amber states.
//
// These are different intentions and must not be interchanged.
Singleton {
    id: root

    // =========================================================================
    // Palette — raw values
    // =========================================================================

    // Surfaces, deepest to lightest. base46 has a much tighter, darker ladder
    // than Rosé Pine's: darker_black for the page, black for cards, one_bg for
    // anything raised, line for hover, grey/light_grey for borders.
    readonly property color palBase: "#13111e"           // base46 darker_black
    readonly property color palSurface: "#191724"        // base46 black / base00
    readonly property color palOverlay: "#262431"         // base46 one_bg
    readonly property color palMuted: "#6E6A86"           // base03
    readonly property color palSubtle: "#908CAA"          // base04
    readonly property color palText: "#E0DEF4"            // base46 white / base05
    readonly property color palLove: "#EB6F92"            // base46 red / base08
    readonly property color palGold: "#F6C177"            // base46 yellow / base09
    readonly property color palRose: "#EBBCBA"            // base0A
    readonly property color palPine: "#31748F"            // base0B
    readonly property color palFoam: "#8BBEC7"            // base46 blue
    readonly property color palIris: "#C4A7E7"            // base46 purple / base0D
    readonly property color palHighlightLow: "#2E2C39"    // base46 line
    readonly property color palHighlightMed: "#3F3D4A"    // base46 grey
    readonly property color palHighlightHigh: "#5D5B68"   // base46 light_grey

    // Deliberately not used from base46's base_30: green (#ABE9B3) and
    // vibrant_green (#b5f3bd). Those are nvim-tree highlight colours; at 95%-in-a-
    // ring sizes they are far too bright for a status readout, so palPine stays
    // on base0B. Also unused: baby_pink, pink, sun, teal, cyan, nord_blue,
    // statusline_bg, one_bg2, one_bg3, grey_fg, grey_fg2, pmenu_bg, folder_bg.
    // Several exist only to serve neovim's own UI.

    // Legacy raw names, kept because the role tokens below are defined in terms
    // of them and because a handful of call sites outside this file still reach
    // for navyDeep, navyBorder and textDim directly. New code should use a
    // semantic token.
    readonly property color blue: root.palFoam
    readonly property color violet: root.palIris
    readonly property color magenta: root.palIris
    readonly property color green: root.palPine
    readonly property color red: root.palLove

    // Surface ramp, darkest to lightest.
    readonly property color navyDeep: root.palBase
    readonly property color navySurface: root.palSurface
    readonly property color navyCard: root.palSurface
    readonly property color navyBorder: root.palHighlightMed
    readonly property color navyElevated: root.palOverlay
    readonly property color navyHover: root.palHighlightLow
    readonly property color navyActive: root.palHighlightMed
    readonly property color navySelected: root.palOverlay
    readonly property color textCool: root.palText
    readonly property color textDim: root.palMuted

    // =========================================================================
    // Accent and status roles
    //
    // Iris is the accent: active, selected, focused, today.
    // Love is the red: destructive, error, danger.
    // Pine is health: connected, charging, positive.
    // Foam is the cool informational secondary.
    // =========================================================================

    readonly property color accentMagenta: root.magenta
    readonly property color accentBlue: root.blue
    readonly property color accentViolet: root.violet
    readonly property color statusGreen: root.green

    readonly property color accent: root.accentMagenta
    readonly property color active: root.accentMagenta
    readonly property color textAccent: root.accentMagenta
    readonly property color borderActive: root.accentMagenta

    // Retained name. Historically "acid green", but at every call site in the
    // desktop tree it carried the generic accent meaning rather than a status
    // one, so it resolves to the accent. Genuine status call sites use
    // statusGreen instead.
    readonly property color acidGreen: root.accentMagenta
    readonly property color accentGreen: root.accentMagenta

    readonly property color connected: root.statusGreen
    readonly property color success: root.statusGreen
    readonly property color available: root.statusGreen

    readonly property color destructive: root.red
    readonly property color error: root.red
    readonly property color danger: root.red
    readonly property color warningRed: root.red

    // Warm notice, distinct from the red above. Rosé Pine has both, and using
    // love for warnings as well would collapse caution and failure into one
    // signal.
    readonly property color warning: root.palGold

    // The identity dot inside the notch's hexagon. Same colour as destructive,
    // deliberately: the palette's love is its warm pink, and spending it on the
    // shell's mark rather than reusing a token whose meaning is "this failed"
    // keeps the file's role vocabulary honest.
    readonly property color love: root.red

    // Workspace selection, in pine.
    //
    // Deliberately not statusGreen even though both resolve to the same value.
    // statusGreen means connected/charging/positive, and a selected workspace
    // means none of those; reusing it would blur exactly the distinction this
    // file exists to keep.
    readonly property color workspaceActive: root.green


    readonly property color accentRed: root.red
    readonly property color pastelBlue: root.palFoam
    readonly property color pastelOrange: root.palGold

    // =========================================================================
    // Surfaces
    // =========================================================================

    readonly property color pageBackground: root.navyDeep
    readonly property color surfaceDeep: root.navyCard
    readonly property color borderSubtle: root.navyBorder

    // Translucent panel surfaces. The desktop telemetry widgets float over the
    // wallpaper, so their background is a scrim rather than an opaque fill.
    // This was a hardcoded #0E0E0E at 0.85 in eight files, which is why they
    // stayed neutral grey through the palette change.
    // Canvas drawing APIs (ctx.fillStyle / strokeStyle) take CSS colour
    // strings, not QML colours, so a handful of tokens exist in string form.
    // CpuHexGrid and NetworkFlowMatrix draw with Canvas and previously
    // hardcoded the old palette, which is why they stayed green-on-grey
    // through the rebrand.
    readonly property string accentMagentaHex: "#C4A7E7"
    readonly property string statusGreenHex: "#31748F"
    readonly property string dangerHex: "#EB6F92"
    // Love dimmed toward base, for the muted half of a destructive pair.
    readonly property string dangerDimHex: "#5E3246"
    readonly property string textDimHex: "#6E6A86"
    readonly property string gray300Hex: "#908CAA"
    readonly property string gray700Hex: "#2E2C39"

    readonly property color surfaceScrim: Qt.rgba(root.navySurface.r, root.navySurface.g, root.navySurface.b, 0.85)

    // The notch body. Slightly translucent so the wallpaper reads through.
    readonly property color notchSurface: Qt.rgba(root.navyDeep.r, root.navyDeep.g, root.navyDeep.b, 0.94)

    readonly property color background: root.navyDeep
    readonly property color backgroundBase: root.navyDeep
    readonly property color backgroundDark: root.navyDeep
    readonly property color backgroundBright: root.navySurface
    readonly property color backgroundElevated: root.navyElevated

    readonly property color surface: root.navySurface
    readonly property color surfaceElevated: root.navyElevated
    readonly property color surfaceHover: root.navyHover
    readonly property color surfaceActive: root.navyActive
    readonly property color surfaceSelected: root.navySelected

    // Borders and dividers. These are dark blue, not the old light grey:
    // inheriting them from gray200/gray500 put a pale line on a dark surface.
    readonly property color border: root.navyBorder
    readonly property color hairline: root.navyBorder
    readonly property color divider: root.navyBorder
    readonly property color ctosGray: root.navyBorder
    readonly property color borderMuted: root.textDim

    // =========================================================================
    // Typography
    // =========================================================================

    readonly property color textPrimary: root.textCool
    // Rosé Pine has no second and third text steps, so these are text stepped
    // toward muted rather than invented hues.
    readonly property color textPrimaryDim: "#C8C5DC"
    readonly property color textPrimaryDimmer: root.palSubtle
    readonly property color textSecondary: root.textDim
    readonly property color textMuted: root.textDim
    readonly property color textDisabled: root.palHighlightMed
    readonly property color textInverse: root.navyDeep
    readonly property color unavailable: root.textDim

    readonly property var fontFamilies: ["Maple Mono", "JetBrainsMono Nerd Font", "JetBrains Mono", "Monaspace Neon", "CaskaydiaCove Nerd Font", "monospace"]
    readonly property string fontFamily: "Maple Mono"
    readonly property string fontFamilyFallback: "monospace"
    readonly property string fontFamilyMonospace: "Maple Mono"

    // UI text is set in a proportional sans; the mono face is for data only
    // (clocks, counters, throughput, timestamps).
    //
    // The design uses a proportional face for anything a person reads as a
    // label and reserves the mono face for numbers that must line up in a
    // column. Setting labels in mono is legible but reads as a terminal, which
    // is the difference between the panel looking finished and looking like
    // diagnostics output.
    readonly property string fontFamilySans: "Inter"

    // Monospaced digits, so a percentage ticking from 9% to 10% does not shift
    // the ring's label sideways every second.
    readonly property string fontFamilyMonoNumeric: "Maple Mono"

    // Material Symbols, Outlined. Supersedes the classic Material Icons face,
    // which had no hexagon to replace the shell's identity mark with.
    //
    // Outlined because the glyphs sit on a dark translucent panel at 16-20px,
    // where the filled faces read as solid blocks. The Outlined, Rounded and
    // Sharp faces are separate families, so the shape has to be named.
    //
    // This is a variable font (FILL, GRAD, opsz, wght). The defaults -- FILL 0,
    // GRAD 0, wght 400 -- are what Outlined means, so no variation settings are
    // needed to get the intended weight.
    readonly property string fontFamilyMaterialIcons: "Material Symbols Outlined"

    readonly property int fontSizeBody: 14
    readonly property int fontSizeCaption: 11
    readonly property int fontSizeMicro: 9
    readonly property int fontSizeDisplay: 36
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeQuery: 48
    readonly property int fontSizeSegment: 16
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeTitle: 22

    readonly property int fontWeightBold: 700
    readonly property int fontWeightDemiBold: 600
    readonly property int fontWeightLight: 300
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightNormal: 400

    // =========================================================================
    // Neutral ramp — Rosé Pine's neutral ladder, not grey
    // =========================================================================

    readonly property color gray50: root.palText
    readonly property color gray100: "#C8C5DC"
    readonly property color gray200: root.textCool
    readonly property color gray300: root.palSubtle
    readonly property color gray400: root.palMuted
    readonly property color gray500: root.textDim
    readonly property color gray600: root.palHighlightMed
    readonly property color gray700: root.palHighlightLow
    readonly property color gray800: root.navySurface
    readonly property color gray900: root.navyDeep

    // =========================================================================
    // Spacing
    // =========================================================================

    readonly property int spacingNone: 0
    readonly property int spacingXs: 2
    readonly property int spacingSmall: 4
    readonly property int spacingMedium: 8
    readonly property int spacingLarge: 12
    readonly property int spacingXl: 16
    readonly property int spacing2Xl: 24

    readonly property int paddingXs: 2
    readonly property int paddingSmall: 4
    readonly property int paddingMedium: 8
    readonly property int paddingLarge: 12
    readonly property int paddingXl: 16
    readonly property int padding2Xl: 24

    // =========================================================================
    // Radii, borders, corners
    // =========================================================================

    readonly property int radiusNone: 0
    readonly property int radiusSmall: 2
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12
    readonly property int radiusPill: 9999

    readonly property int borderWidth: 1
    readonly property int borderWidthAccent: 2

    readonly property int cornerBracketArmLength: 7
    readonly property int cornerBracketMargin: 4
    readonly property int cornerBracketThickness: 1

    readonly property int dividerWidth: 1
    readonly property int dividerTopMargin: 1
    readonly property int dividerBottomMargin: 1

    // =========================================================================
    // Notch geometry support
    // =========================================================================

    // Vertical breathing room around the notch inside its host window. The host
    // window is anchored with a top margin, so this padding is what separates
    // the notch's bottom edge from any surface positioned below it.
    readonly property int notchHostPadding: 6

    // The notch's resting height is a design decision, not a user setting, so it
    // lives here rather than in Settings. It used to read Settings.barHeight,
    // which coupled the pill's proportions to a slider in the radial settings
    // (range 28-48) and to whatever barHeight the user's config last persisted.
    // Settings.barHeight still governs the flat bar and the desktop widgets; the
    // notch no longer follows it.
    //
    // This is only a floor, not the resting width. The pill measures itself from
    // its content now that the clock is centred on it -- see LivingNotch's
    // compactWidth, which sizes to the wider of the two side groups plus the
    // clock band. The fixed 360 this replaces left dead space at both ends once
    // the clock moved out of the row's flow. The floor stops the pill collapsing
    // to nothing when a session has very few workspaces or a very short battery
    // string, which would otherwise make the notch visibly twitch as that content
    // changed.
    readonly property int notchWidthCompactMin: 260

    // Heights and widths are set as a pair against the target's proportions:
    // 8.5:1 idle and 6.6:1 expanded. At the old 470x30 and 620x60 the pill was
    // 15.7:1 and 10.3:1, a letterbox rather than a capsule.
    readonly property int notchHeightCompact: 42
    readonly property int notchHeightExpanded: 72

    // CCC accordion header height. Deliberately independent of the notch
    // height: an accordion header is not a bar.
    readonly property int accordionHeaderHeight: 36

    // CCC body. Width is clamped per-output at runtime.
    readonly property int commandCenterWidth: 680

    // Below this the two columns stop being readable, so the clamp in
    // AmbientBar floors here rather than letting the gutter eat the content.
    readonly property int commandCenterMinWidth: 420

    // The CCC is a dropdown off the notch, so it cannot run to the bottom of
    // the screen. Content past this scrolls instead.
    readonly property int commandCenterMaxHeight: 620

    readonly property int commandCenterColumnGutter: 12

    // Card chrome. The section radius was defined here from the start and then
    // never applied -- the CCC was still drawing its cards at radiusSmall.
    readonly property int commandCenterSectionRadius: 12
    readonly property int cardPadding: 12
    readonly property int cardIconTile: 24
    readonly property int cardGap: 10

    // Hovered card border. Cards lift by their border rather than by their fill,
    // so the hover reads without the tile shifting colour under the text.
    readonly property color borderHover: root.accentBlue

    readonly property int calendarWidth: 1080
    readonly property int calendarHeight: 600

    readonly property int barPaddingHorizontal: 8
    readonly property int barPaddingVertical: 0

    // =========================================================================
    // Motion
    // =========================================================================

    readonly property int durationDismiss: 0
    readonly property int durationFast: 50
    readonly property int durationNormal: 150
    readonly property int durationScan: 100
    readonly property int durationSlow: 300

    readonly property real springStiffness: 4.0
    readonly property real springDamping: 0.3
    readonly property real springMass: 0.8

    readonly property color secondary: root.gray500
}
