pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // SECTION Accent & State Tokens

    readonly property color accent: root.acidGreen
    readonly property color accentGreen: root.acidGreen
    readonly property color accentRed: root.warningRed

    // SECTION Accent Primitives

    readonly property color acidGreen: "#1BFD9C"
    readonly property color active: root.acidGreen

    // SECTION Surface & Background Tokens

    readonly property color background: root.gray800
    readonly property color backgroundBase: root.gray800
    readonly property color backgroundBright: root.gray700
    readonly property color backgroundDark: root.gray900
    readonly property color backgroundElevated: root.gray700

    // SECTION Dimensions & Layout Constants

    readonly property int barHeight: 32
    readonly property int barPaddingHorizontal: 8
    readonly property int barPaddingVertical: 0
    readonly property color border: root.gray200
    readonly property color borderActive: root.acidGreen
    readonly property color borderMuted: root.gray500
    readonly property int borderWidth: 1
    readonly property color connected: root.acidGreen
    readonly property int cornerBracketArmLength: 7
    readonly property int cornerBracketMargin: 4
    readonly property int cornerBracketThickness: 1
    readonly property color ctosGray: root.gray200
    readonly property color destructive: root.warningRed
    readonly property color divider: root.gray500
    readonly property int dividerBottomMargin: 1
    readonly property int dividerTopMargin: 1
    readonly property int dividerWidth: 1
    readonly property int durationDismiss: 0
    readonly property int durationFast: 50
    readonly property int durationNormal: 150

    // Motion & Transitions (ms)
    readonly property int durationScan: 100
    readonly property int durationSlow: 300
    readonly property color error: root.warningRed
    readonly property var fontFamilies: ["JetBrainsMono Nerd Font", "JetBrains Mono", "Monaspace Neon", "CaskaydiaCove Nerd Font", "monospace"]

    // SECTION Monospace Typography

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyFallback: "monospace"
    readonly property string fontFamilyMonospace: "JetBrainsMono Nerd Font"
    readonly property int fontSizeBody: 14

    // Typography Scale (pixel sizes)
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
    readonly property color gray100: "#CACACA"
    readonly property color gray200: "#D9D9D9"
    readonly property color gray300: "#C3C3C3"
    readonly property color gray400: "#9E9E9E"

    // SECTION Color Primitives (Grayscale Spectrum)

    readonly property color gray50: "#FFFFFF"
    readonly property color gray500: "#7A7A7A"
    readonly property color gray600: "#4A4A4A"
    readonly property color gray700: "#202020"
    readonly property color gray800: "#0E0E0E"
    readonly property color gray900: "#080808"

    // SECTION Borders, Dividers & Hairlines

    readonly property color hairline: root.gray200
    readonly property int padding2Xl: 24
    readonly property int paddingLarge: 12
    readonly property int paddingMedium: 8
    readonly property int paddingSmall: 4
    readonly property int paddingXl: 16

    // Padding Scale
    readonly property int paddingXs: 2

    // Geometry
    readonly property int radiusNone: 0
    readonly property int radiusPill: 9999
    readonly property int radiusSmall: 2
    readonly property color secondary: root.gray500
    readonly property int spacing2Xl: 24
    readonly property int spacingLarge: 12
    readonly property int spacingMedium: 8

    // Spacing Scale
    readonly property int spacingNone: 0
    readonly property int spacingSmall: 4
    readonly property int spacingXl: 16
    readonly property int spacingXs: 2
    readonly property color success: root.acidGreen
    readonly property color surface: root.gray700
    readonly property color surfaceActive: "#333333"
    readonly property color surfaceElevated: root.gray700
    readonly property color surfaceHover: "#2A2A2A"
    readonly property color surfaceSelected: "#1A2E24"
    readonly property color textAccent: root.acidGreen
    readonly property color textDisabled: root.gray600
    readonly property color textInverse: root.gray800
    readonly property color textMuted: root.gray500

    // SECTION Text Tokens

    readonly property color textPrimary: root.gray50
    readonly property color textPrimaryDim: root.gray100
    readonly property color textPrimaryDimmer: root.gray300
    readonly property color textSecondary: root.gray500
    readonly property color unavailable: root.gray500
    readonly property color warning: root.warningRed
    readonly property color warningRed: "#FC3E38"
}
