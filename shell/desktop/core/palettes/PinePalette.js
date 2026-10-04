.pragma library

// =============================================================================
// ctos-pine -- the default palette.
//
// Provenance: a Rosé Pine derivative taken from the nvchad/base46 theme
// (M.base_30 and M.base_16), not the official Rosé Pine release. It reads deeper
// and more muted than official Main -- its base is #13111e against Main's
// #191724 -- which is the "darker" look this was after.
//
// Note the official variants, for reference: Main is the darkest of the three
// (base relative luminance 0.0095, versus Moon's 0.0171). Moon is lighter, not
// darker. So this palette is not "Rosé Pine Moon"; it is a third, darker thing,
// and the values come from base46.
//
// Every value here is verbatim from the single hardcoded palette this file
// replaces, so selecting ctos-pine must render pixel-identically to the build
// before Theme gained a palette. That constraint is why several Theme tokens
// resolve to a slot whose name does not match theirs -- see the note on
// Theme.textMuted.
// =============================================================================

// The 21 slots. Values are strings, not colours: Theme.qml wraps them in
// Qt.color, and Canvas drawing APIs need the string form anyway.
//
// Two pairs are deliberately equal rather than accidentally so. `active` and
// `raised` are both #262431 here but differ in acid (#333333 each, but selected
// is #1A2E24); `border`, `divider` and `textDisabled` are all #3F3D4A in both
// palettes. They are separate slots because they are separate roles that
// happened to agree, and the acid palette is where they start to diverge.
function slots() {
    return {
        // Surfaces, deepest to lightest.
        "bg": "#13111E",
        "surface": "#191724",
        "raised": "#262431",
        "hover": "#2E2C39",
        "active": "#3F3D4A",
        "selected": "#262431",

        // Lines.
        "border": "#3F3D4A",
        "borderMuted": "#6E6A86",
        "divider": "#3F3D4A",

        // Text. textDim/textMuted are stepped toward muted rather than invented
        // hues: Rosé Pine has no second and third text steps.
        "text": "#E0DEF4",
        "textDim": "#C8C5DC",
        "textMuted": "#908CAA",
        "textDisabled": "#3F3D4A",
        "textInverse": "#13111E",

        // Accent and status.
        //
        // Iris is the accent: active, selected, focused. Spending the palette's
        // `love` on the accent would leave destructive actions with nothing to
        // distinguish them -- the Poweroff button and the focus ring would be
        // the same colour. Love is health-failing instead, Pine is health, Foam
        // is the cool informational secondary, Gold is the warm notice. These
        // are different intentions and must not be interchanged.
        "accent": "#C4A7E7",
        "status": "#31748F",
        "destructive": "#EB6F92",
        "warning": "#F6C177",
        "cool": "#8BBEC7",
        "love": "#EB6F92",

        // Love dimmed toward base, for the muted half of a destructive pair.
        "destructiveDim": "#5E3246",

        // The radial settings surface's own backdrop, which is not the page
        // background: the radial covers the screen while it is open and reads as
        // its own place, so it gets a palette-specific floor rather than sharing
        // `bg` with the desktop underneath.
        //
        // A deep bronze, not literal #F6C177. The panel and all its text sit on
        // this, and the grid is drawn over it, so the value has to stay dark
        // enough for light text -- roughly 12:1 against `text`.
        "radialBackdrop": "#2A2313"
    };
}

// Provenance for slots that are not a flat reading of base46, kept here so the
// reasoning travels with the value.
function notes() {
    return {
        "surface": "base46 black / base00",
        "raised": "base46 one_bg",
        "hover": "base46 line",
        "active": "base46 grey",
        "borderMuted": "base03",
        "textMuted": "base04",
        "text": "base46 white / base05",
        "destructive": "base46 red / base08",
        "warning": "base46 yellow / base09",
        "status": "base0B",
        "cool": "base46 blue",
        "accent": "base46 purple / base0D",

        // Deliberately not from base46's base_30: green (#ABE9B3) and
        // vibrant_green (#b5f3bd). Those are nvim-tree highlight colours; at
        // 95%-in-a-ring sizes they are far too bright for a status readout, so
        // status stays on base0B. Also unused: baby_pink, pink, sun, teal, cyan,
        // nord_blue, statusline_bg, one_bg2, one_bg3, grey_fg, grey_fg2,
        // pmenu_bg, folder_bg -- several exist only to serve neovim's own UI.
    };
}
