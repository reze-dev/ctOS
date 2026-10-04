.pragma library

// =============================================================================
// ctos-dark -- the acid palette.
//
// The wire name is "ctos-dark" and it is a historical accident: this palette
// predates the navy rebrand, when it was the only one and "dark" meant "the
// dark theme". It is not the darker of the two -- ctos-pine's base is
// #13111E against this one's #0E0E0E, which is very slightly lighter, and pine
// is the one built from a named upstream palette. Both are dark. The name is
// kept because Settings.theme and the persisted config already use it, and
// renaming it would strand every existing settings file.
//
// Accent is #1BFD9C. Note that Theme.acidGreen resolves to this palette's
// `accent` slot under both palettes, which is why that token's name is a
// misnomer in ctos-pine -- where it resolves to lavender. The token is kept
// because it has many call sites; the lie is in the name, not the value.
// =============================================================================

function slots() {
    return {
        // Surfaces, deepest to lightest. Pure neutral greys, unlike pine's
        // blue-shifted ladder.
        "bg": "#0E0E0E",
        "surface": "#202020",
        "raised": "#333333",
        "hover": "#2A2A2A",
        "active": "#333333",

        // The one slot that is not a grey: a desaturated green tint, so a
        // selected row reads as selected rather than merely brighter. Pine
        // cannot afford this because its `selected` is also its `raised`, and
        // tinting it would drag every raised surface green with it.
        "selected": "#1A2E24",

        // Lines. border and divider were the deliberate fix here: both were a
        // dark value that vanished against the old near-black surfaces, and both
        // landed on #3F3D4A.
        "border": "#3F3D4A",
        "borderMuted": "#7A7A7A",
        "divider": "#3F3D4A",

        // Text.
        "text": "#FFFFFF",
        "textDim": "#CACACA",
        "textMuted": "#9E9E9E",
        "textDisabled": "#4A4A4A",
        "textInverse": "#0E0E0E",

        // Accent and status.
        //
        // accent and status are both #1BFD9C and deliberately so: in this
        // palette the accent *is* the status colour, which is where the token
        // named acidGreen stopped meaning anything status-related.
        "accent": "#1BFD9C",
        "status": "#1BFD9C",
        "destructive": "#FC3E38",
        "warning": "#FF964F",
        "cool": "#66B2B2",
        "love": "#1BFD9C",

        // #FC3E38 mixed 40% toward bg.
        //
        // No acid-era equivalent existed for this -- destructiveDim was
        // introduced with the navy rebrand, where love already had a dimmed
        // partner. It is derived rather than picked so that it tracks
        // destructive and bg: change either and this follows by the same ratio.
        "destructiveDim": "#6D211F",

        // The radial settings surface's backdrop. Deeper and more saturated than
        // pine's bronze relative to their `bg`, because this palette's bg is
        // already near-black (#0E0E0E) and a tint that reads as bronze against
        // pine's blue-black would disappear here. Same job as the slot above:
        // dark enough for light text and for the grid to sit over.
        "radialBackdrop": "#0C2126"
    };
}

function notes() {
    return {
        "selected": "desaturated green tint, not a grey -- the only tinted surface in this palette",
        "destructiveDim": "#FC3E38 at 40% toward #0E0E0E",
    };
}
