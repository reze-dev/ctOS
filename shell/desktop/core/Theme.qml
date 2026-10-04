pragma Singleton

import QtQuick
import Quickshell
import "./palettes/PinePalette.js" as PinePalette
import "./palettes/AcidPalette.js" as AcidPalette

// Design tokens for the Living Notch / command centre.
//
// The rule this file exists to enforce: colour is referenced by role, never
// inlined. There are three layers, and only the bottom one holds values:
//
//   palettes/*.js   22 named slots per palette. The only place a hex lives.
//   pal* below      one token per slot, wrapped in Qt.color.
//   everything else aliases those, so the ~90 call-facing tokens are a naming
//                   layer and never a source of colour.
//
// Two palettes ship: ctos-pine, the default, and ctos-dark, the acid one. Both
// are dark; see AcidPalette.js on why "dark" names the acid one.
//
// Role assignments, and why they are not simply "the nearest colour":
//
//   The accent slot is active, selected, focused.
//   The love slot is health-failing: destructive, error, danger.
//   The status slot is health: connected, charging, positive.
//   The cool slot is the cool secondary: informational, hover borders.
//   The warning slot is the warm notice: warnings and amber states.
//
// These are different intentions and must not be interchanged. Note that
// ctos-dark sets both `accent` and `status` to #1BFD9C, which collapses that
// distinction for that palette only -- the slots stay separate so that setting
// them apart later is a one-value change.
Singleton {
    id: root

    // =========================================================================
    // Palette selection
    //
    // Read once from Settings and validated, rather than assumed. Every token
    // below resolves through root.palette, so switching Settings.theme at
    // runtime repaints the shell without a restart -- which is what the radial's
    // appearance picker writes.
    // =========================================================================

    // Where an unusable configuration lands. Pine, not acid: it is the default
    // the shell ships as, so falling back to it is invisible, and it is the
    // palette every token was designed against.
    readonly property string _fallbackTheme: "ctos-pine"

    readonly property var _registry: ({
        "ctos-pine": PinePalette.slots(),
        "ctos-dark": AcidPalette.slots()
    })

    // The 22 slots a palette must define.
    //
    // Checked rather than assumed because a missing slot does not fail. It
    // resolves to undefined, Qt.color(undefined) is transparent black, and the
    // result is an invisible border or unreadable text with nothing in the log.
    // That is precisely how the Canvas widgets stayed green-on-grey through the
    // last rebrand: they read hex strings that nothing validated.
    readonly property var _requiredSlots: [
        "bg", "surface", "raised", "hover", "active", "selected",
        "border", "borderMuted", "divider",
        "text", "textDim", "textMuted", "textDisabled", "textInverse",
        "accent", "status", "destructive", "warning", "cool", "love",
        "destructiveDim", "radialBackdrop"
    ]

    readonly property string themeName: {
        const requested = Settings.theme;

        if (typeof requested !== "string" || requested.length === 0) {
            console.warn("Theme: no theme set in Settings; using " + root._fallbackTheme + ".");
            return root._fallbackTheme;
        }

        if (!root._registry.hasOwnProperty(requested)) {
            console.error("Theme: theme '" + requested + "' is not a known palette (have: "
                + Object.keys(root._registry).join(", ") + "); falling back to " + root._fallbackTheme + ".");
            return root._fallbackTheme;
        }

        const missing = [];
        for (let i = 0; i < root._requiredSlots.length; ++i) {
            const slot = root._requiredSlots[i];
            const v = root._registry[requested][slot];
            if (typeof v !== "string" || v.length === 0) {
                missing.push(slot);
            }
        }
        if (missing.length > 0) {
            console.error("Theme: palette '" + requested + "' is missing " + missing.length
                + " required slot(s) [" + missing.join(", ") + "]; falling back to " + root._fallbackTheme + ".");
            return root._fallbackTheme;
        }

        return requested;
    }

    readonly property var palette: root._registry[root.themeName]

    // =========================================================================
    // Palette roots -- one token per slot, and the only colours defined here
    // =========================================================================

    readonly property color palBase: Qt.color(root.palette.bg)
    readonly property color palSurface: Qt.color(root.palette.surface)
    readonly property color palOverlay: Qt.color(root.palette.raised)
    readonly property color palMuted: Qt.color(root.palette.borderMuted)
    readonly property color palSubtle: Qt.color(root.palette.textMuted)
    readonly property color palText: Qt.color(root.palette.text)
    readonly property color palLove: Qt.color(root.palette.love)
    readonly property color palDestructive: Qt.color(root.palette.destructive)
    readonly property color palGold: Qt.color(root.palette.warning)
    readonly property color palPine: Qt.color(root.palette.status)
    readonly property color palFoam: Qt.color(root.palette.cool)
    readonly property color palIris: Qt.color(root.palette.accent)
    readonly property color palHighlightLow: Qt.color(root.palette.hover)
    readonly property color palHighlightMed: Qt.color(root.palette.active)
    readonly property color palSelected: Qt.color(root.palette.selected)
    readonly property color palRadialBackdrop: Qt.color(root.palette.radialBackdrop)

    // Retired, and deliberately not re-added as slots: palRose (#EBBCBA) and
    // palHighlightHigh (#5D5B68) had no call sites anywhere in the tree. Two
    // fewer slots to keep honest.

    // Legacy raw names, kept because the role tokens below are defined in terms
    // of them and because a handful of call sites outside this file still reach
    // for navyDeep, navyBorder and textDim directly. New code should use a
    // semantic token.
    readonly property color blue: root.palFoam
    readonly property color violet: root.palIris
    readonly property color magenta: root.palIris
    readonly property color green: root.palPine

    // The destructive slot, not the love one.
    //
    // These two are the same colour in ctos-pine (#EB6F92) and different in
    // ctos-dark (#FC3E38 against #1BFD9C), which is what makes this worth being
    // explicit about. Aliasing `red` to the love root -- as it was -- left
    // destructive, error, danger and warningRed rendering accent green under
    // acid, which is precisely the failure the palette split was supposed to
    // rule out. `love` below reads the love slot directly instead.
    readonly property color red: root.palDestructive

    // Surface ramp, darkest to lightest.
    readonly property color navyDeep: root.palBase
    readonly property color navySurface: root.palSurface
    readonly property color navyCard: root.palSurface
    readonly property color navyBorder: root.palHighlightMed
    readonly property color navyElevated: root.palOverlay
    readonly property color navyHover: root.palHighlightLow
    readonly property color navyActive: root.palHighlightMed
    readonly property color navySelected: root.palSelected
    readonly property color textCool: root.palText

    // Named textDim, but it is the *border*-muted slot, not the text-muted one.
    //
    // The slots distinguish borderMuted (#6E6A86 in pine) from textMuted
    // (#908CAA). Before the split, Theme.textDim and Theme.textMuted were both
    // #6E6A86 -- the tree conflated the two roles. Mapping these tokens to the
    // same-named slots would have quietly lightened every muted label in pine,
    // so they keep the value they have always rendered with and the slots stay
    // honest about which role they carry. Concretely, under ctos-pine:
    //
    //   Theme.textDim        -> palette.borderMuted  (#6E6A86)
    //   Theme.textMuted      -> palette.borderMuted  (#6E6A86)
    //   Theme.textPrimaryDim -> palette.textDim      (#C8C5DC)
    //   Theme.textPrimaryDimmer -> palette.textMuted (#908CAA)
    //
    // The naming is a wart and the obvious fix is to rename the slots to match
    // the tokens rather than the reverse. That is a breaking change for
    // Settings-adjacent config and was not done as part of the extraction.
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
    readonly property color love: root.palLove

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
    readonly property color surfaceScrim: Qt.rgba(root.navySurface.r, root.navySurface.g, root.navySurface.b, 0.85)

    // String forms, for Canvas.
    //
    // Canvas drawing APIs (ctx.fillStyle / strokeStyle) take CSS colour strings,
    // not QML colours, so these cannot be the colour tokens above. Each is a
    // direct read of the slot its colour-token namesake resolves to -- they are
    // the same value by construction, not by convention.
    //
    // CpuHexGrid and NetworkFlowMatrix are the reason this block exists at all.
    // They draw with Canvas and used to hardcode the palette inline, which is
    // why they stayed green-on-grey through the last rebrand while everything
    // around them changed: nothing outside those two files referenced Theme.
    readonly property string accentMagentaHex: root.palette.accent
    readonly property string statusGreenHex: root.palette.status
    readonly property string dangerHex: root.palette.destructive
    readonly property string dangerDimHex: root.palette.destructiveDim
    readonly property string textDimHex: root.palette.borderMuted
    readonly property string gray300Hex: root.palette.textMuted
    readonly property string gray700Hex: root.palette.hover

    // A CSS rgba() string for a colour at a given alpha.
    //
    // Canvas cannot be handed a QML colour, so every translucent draw has to
    // become a string. These call sites used to spell the rgba() out by hand,
    // which is how six of them ended up still carrying the pre-rebrand acid
    // green: a hand-written rgba(27, 253, 156, ...) is invisible to grep for
    // palette drift, because it never mentions a token at all. Routing them
    // through here means an alpha draw follows the palette like any other.
    function withAlpha(c, a) {
        return "rgba(" + Math.round(c.r * 255) + ", "
            + Math.round(c.g * 255) + ", "
            + Math.round(c.b * 255) + ", " + a + ")";
    }

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

    // Borders and dividers.
    //
    // `border` and `divider` are separate slots that currently hold the same
    // value in both palettes. They are kept apart because they mean different
    // things -- a divider is a separator between rows, a border is the edge of a
    // control -- and because the acid palette is where they would diverge if
    // they were going to.
    readonly property color border: Qt.color(root.palette.border)
    readonly property color hairline: Qt.color(root.palette.border)
    readonly property color divider: Qt.color(root.palette.divider)
    readonly property color ctosGray: Qt.color(root.palette.border)
    readonly property color borderMuted: Qt.color(root.palette.borderMuted)

    // =========================================================================
    // Typography
    // =========================================================================

    readonly property color textPrimary: root.textCool
    // Neither palette has a second and third text step of its own, so these are
    // text stepped toward muted rather than invented hues. See the note on
    // root.textDim for why the two muted slots resolve as they do.
    readonly property color textPrimaryDim: Qt.color(root.palette.textDim)
    readonly property color textPrimaryDimmer: root.palSubtle
    readonly property color textSecondary: root.textDim
    readonly property color textMuted: root.textDim
    readonly property color textDisabled: Qt.color(root.palette.textDisabled)
    readonly property color textInverse: Qt.color(root.palette.textInverse)
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
    // Neutral ramp
    //
    // An alias layer, not a palette root. These are the most widely used tokens
    // in the tree and the worst-named: gray700 is a hover surface, gray900 is
    // the page background, gray600 is a border, and only gray50/100/200 are
    // actually text steps. They survive because call sites are everywhere, but
    // each resolves to the slot that means the same thing -- which is what lets
    // the neutral ladder follow the active palette instead of pinning it.
    // =========================================================================

    readonly property color gray50: root.palText
    readonly property color gray100: Qt.color(root.palette.textDim)
    readonly property color gray200: root.textCool
    readonly property color gray300: root.palSubtle
    readonly property color gray400: root.palMuted
    readonly property color gray500: root.textDim
    readonly property color gray600: root.navyBorder
    readonly property color gray700: root.navyHover
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
    //
    // Raised from 620 to give the left column room to breathe. It had almost no
    // slack left: adding a top gap to card content pushed the column past this
    // cap and sliced System Status in half, and the only ways to avoid that were
    // to give the space back or take it from somewhere else. At 700 the panel
    // still clears the bottom of a 900px-tall screen by a wide margin, with the
    // notch above it -- this is a fixed constant rather than a fraction of the
    // screen, so a much shorter display would want it derived instead.
    readonly property int commandCenterMaxHeight: 700

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
