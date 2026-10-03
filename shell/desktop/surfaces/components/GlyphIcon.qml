pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Functional glyphs, set in Google's Material Icons (Outlined).
//
// Why this exists rather than reusing CtosIcon: CtosIcon answers "which app is
// this?", mapping application names onto brand marks (kitty, zed, obsidian). The
// CCC was passing it category words -- "timer", "power", "volume", "bluetooth" --
// for which it has no entries, which is why those header icons were blank or
// resolved to whatever matched first. An icon slot wants functional glyphs.
//
// These were hand-drawn on a 24x24 grid until the set grew past what is worth
// drawing by hand. Material Icons is Apache-2.0, ships a coherent family, and
// recolours and rescales like any Text, so a 539-line file of Shape paths
// collapses to one Text and a lookup.
//
// Codepoints are Google's own, taken from font/MaterialIcons-Regular.codepoints
// in the material-design-icons repository, not from memory: the pixel-matching
// route that got us here picked the wrong neighbour for lock, expand_more,
// chevron_right and calendar_today, all of which have near-identical siblings in
// the font. Every codepoint below was checked to exist in the Outlined face's
// cmap -- logout, for one, is absent there, so "logout" maps to exit_to_app
// (U+E879), which is in the Outlined face and means the same thing to a user.
//
// Positioning is by TextMetrics rather than by anchors. The Material fonts set a
// tall line box and hang the icon high on it, so a centred Text sits visibly
// below centre and a padded anchor.fill pads it asymmetrically. Measuring the
// ink box once and centring that puts the glyph on the item's centre line at any
// size, and it is the ink rather than the metrics that determines whether a row
// of icons looks level.

Item {
    id: root

    // Semantic name -> Material Icons codepoint. The names are the shell's own
    // vocabulary rather than Google's, because these are referenced from cards
    // that also choose behaviour by name.
    //
    // Named `glyph` rather than `name`: a property called `name` on a reusable
    // component invites collision with the ambient identifiers every QML caller
    // has in scope, and assigning it from the outside had no effect.
    property string glyph: ""

    property color color: Theme.textPrimary

    implicitWidth: 20
    implicitHeight: implicitWidth

    readonly property string _codepoint: {
        switch (root.glyph) {
        case "bell": return "\uE7F4";        // notifications
        case "wifi": return "\uE63E";        // wifi
        case "bluetooth": return "\uE1A7";   // bluetooth
        case "speaker": return "\uE050";     // volume_up
        case "calendar": return "\uE878";    // event
        case "sliders": return "\uE429";     // tune
        case "power": return "\uE8AC";       // power_settings_new
        case "lock": return "\uE897";        // lock
        case "logout": return "\uE879";      // exit_to_app
        case "reboot": return "\uE863";      // autorenew
        // battery is battery_std (U+E1A5) rather than battery_full (U+E1A4). The
        // filled face is solid inside its outline, so at 16-20px it reads as a
        // featureless block, and it asserts "full" at every charge level -- a
        // second answer next to the percentage readout, contradicting it. The
        // hollow one still reads as a battery at 14px and claims nothing.
        case "battery": return "\uE1A5";     // battery_std, not battery_full
        case "chevron": return "\uE5CF";     // expand_more
        case "play": return "\uE037";        // play_arrow
        case "pause": return "\uE034";       // pause
        case "skipPrevious": return "\uE045"; // skip_previous
        case "skipNext": return "\uE044";     // skip_next
        }
        return "";
    }

    // Everything hangs off the ink box, so an icon at 16px is centred on the same
    // line as one at 20px regardless of how the font rounds its metrics.
    TextMetrics {
        id: metrics
        font: label.font
        text: label.text
    }

    Text {
        id: label

        visible: root._codepoint !== ""
        text: root._codepoint
        color: root.color

        // Material's 24dp grid maps to the pixel size directly; the small
        // overshoot compensates for the ink sitting inside a larger em box.
        font.family: Theme.fontFamilyMaterialIcons
        font.pixelSize: Math.round(root.height * 1.18)

        // Text's own box is much taller than the glyph. Place the ink, not the
        // line: x centres the advance width, y subtracts the ink's offset from
        // its own top.
        x: Math.round((root.width - metrics.width) / 2)
        y: Math.round((root.height - metrics.height) / 2 - metrics.y)

        // The font engine's hinting, not Qt Quick's distance-field path, which
        // is tuned for body text and blurs small glyphs.
        renderType: Text.NativeRendering
    }
}