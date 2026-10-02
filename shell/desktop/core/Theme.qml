pragma Singleton

import QtQuick
import Quickshell

// Design tokens for the neon Living Notch target.
//
// Palette and semantic mapping are specified in
// docs/target/colors.md and derived from the reference images in
// docs/target/images/.
//
// The rule this file exists to enforce: colour is referenced by role, never
// inlined. The previous identity collapsed "active", "selected", "healthy"
// and "connected" onto one green token, which is why this file distinguishes
// them. Magenta is attention; green is health.
Singleton {
    id: root

    // =========================================================================
    // Palette — raw values
    // =========================================================================

    readonly property color blue: "#4695F6"
    readonly property color violet: "#7362F5"
    readonly property color magenta: "#EB4ADF"
    readonly property color green: "#4FE7A2"
    readonly property color red: "#D1605D"

    readonly property color navyDeep: "#050E1E"
    readonly property color navySurface: "#0A192C"
    readonly property color navyCard: "#061121"
    readonly property color navyBorder: "#243D70"
    readonly property color navyElevated: "#1A2647"
    readonly property color navyHover: "#1B2B4D"
    readonly property color navyActive: "#24406B"
    readonly property color navySelected: "#3A1B47"
    readonly property color textCool: "#BACADA"
    readonly property color textDim: "#606A9B"

    // =========================================================================
    // Accent and status roles
    //
    // Magenta is the accent: active, selected, focused, today.
    // Green is health: connected, charging, positive.
    // These are different intentions and must not be interchanged.
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
    // one, so it resolves to magenta. Genuine status call sites use
    // statusGreen instead.
    readonly property color acidGreen: root.accentMagenta
    readonly property color accentGreen: root.accentMagenta

    readonly property color connected: root.statusGreen
    readonly property color success: root.statusGreen
    readonly property color available: root.statusGreen

    readonly property color destructive: root.red
    readonly property color error: root.red
    readonly property color warning: root.red
    readonly property color warningRed: root.red
    readonly property color danger: root.red

    readonly property color accentRed: root.red
    readonly property color pastelBlue: "#7FB2F5"
    readonly property color pastelOrange: "#FFB347"

    // =========================================================================
    // Surfaces
    // =========================================================================

    readonly property color pageBackground: root.navyDeep
    readonly property color surfaceDeep: root.navyCard
    readonly property color borderSubtle: root.navyBorder

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
    readonly property color textPrimaryDim: "#D6E0F5"
    readonly property color textPrimaryDimmer: "#9AA7CC"
    readonly property color textSecondary: root.textDim
    readonly property color textMuted: root.textDim
    readonly property color textDisabled: "#3D4877"
    readonly property color textInverse: root.navyDeep
    readonly property color unavailable: root.textDim

    readonly property var fontFamilies: ["Maple Mono", "JetBrainsMono Nerd Font", "JetBrains Mono", "Monaspace Neon", "CaskaydiaCove Nerd Font", "monospace"]
    readonly property string fontFamily: "Maple Mono"
    readonly property string fontFamilyFallback: "monospace"
    readonly property string fontFamilyMonospace: "Maple Mono"

    readonly property int fontSizeBody: 14
    readonly property int fontSizeCaption: 11
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
    // Neutral ramp — navy, not grey
    // =========================================================================

    readonly property color gray50: "#EDF3FF"
    readonly property color gray100: "#D6E0F5"
    readonly property color gray200: root.textCool
    readonly property color gray300: "#9AA7CC"
    readonly property color gray400: "#7A88B4"
    readonly property color gray500: root.textDim
    readonly property color gray600: "#3D4877"
    readonly property color gray700: root.navyElevated
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

    // The notch's resting height is user-configurable and lives in Settings,
    // not here. Theme holds design tokens; a value the user can change does not
    // belong in a token table. Consumers read Settings.barHeight directly.
    readonly property int notchWidthCompact: 220
    readonly property int notchHeightExpanded: 60

    // CCC accordion header height. Deliberately independent of the notch
    // height: an accordion header is not a bar.
    readonly property int accordionHeaderHeight: 36

    // CCC body. Width is clamped per-output at runtime.
    readonly property int commandCenterWidth: 760
    readonly property int commandCenterColumnGutter: 12
    readonly property int commandCenterSectionRadius: 12

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
