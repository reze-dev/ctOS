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
// Positioning is by alignment within the item, not by TextMetrics. These fonts
// set a tall line box and hang the glyph high on it, so the line box cannot be
// centred blindly and the ink cannot be measured reliably -- see renderType
// below. Measured against a reference box, this lands the ink within 1px of
// dead centre at 16, 18 and 20px.

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

    // Optical size correction, for glyphs whose ink fills the 24dp em.
    //
    // font.pixelSize is derived from this item's height, which sizes the em box
    // and not the drawing inside it. Most Material glyphs are inset from the em,
    // so one slot size makes them look alike -- but some are not. `wifi` fills
    // the em almost edge to edge, so at the same slot it draws about 1.27x the ink
    // of `speaker` and overruns its slot by roughly 2px a side, which is what
    // clipped its arcs against the clock.
    //
    // Correcting per glyph keeps the comparison honest. A uniform shrink would
    // have made every other icon in the tree smaller to accommodate one glyph.
    property real opticalScale: 1.0

    implicitWidth: 20
    implicitHeight: implicitWidth

    readonly property string _codepoint: {
        switch (root.glyph) {
        case "bell": return "\uE7F4";        // notifications
        case "wifi": return "\uE63E";        // wifi
        case "bluetooth": return "\uE1A7";   // bluetooth
        case "speaker": return "\uE050";     // volume_up
        case "mic": return "\uE029";        // mic
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
        // The shell's identity mark, replacing the hand-drawn HexMark.
        //
        // Material Symbols only -- the classic Material Icons Outlined face has
        // no hexagon at all, which is why the identity mark had to be drawn as
        // Shape paths until now.
        //
        // U+EB39, read out of the font's cmap rather than its glyph order. The
        // glyph-order index for "hexagon" is 0x2B9, which looks plausible and is
        // not a codepoint: U+02B9 is absent from the cmap, so Qt fell back to
        // another font and drew U+02B9 -- MODIFIER LETTER EXTRA-HIGH TONE BAR --
        // which is a stray vertical stroke where the logo should be.
        case "hexagon": return "\uEB39";     // hexagon
        }
        return "";
    }

    Text {
        id: label

        anchors.fill: parent
        visible: root._codepoint !== ""
        text: root._codepoint
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        // The 24dp design grid maps to the pixel size, so a 16px slot wants
        // pixelSize 16. The 1.18 overshoot is deliberate and measured: at 1.00
        // the icons read small next to the label beside them, and at 1.18 the
        // wifi's strokes hold together at 16px. It does mean the ink overflows
        // the slot -- the wifi is 22px wide in a 16px box -- so the glyphs need
        // the surrounding spacing to breathe, not tight neighbours.
        font.family: Theme.fontFamilyMaterialIcons
        font.pixelSize: Math.round(root.height * 1.18 * root.opticalScale)

        // The font engine's hinting, not Qt Quick's distance-field path, which
        // is tuned for body text and blurs small glyphs. QtRendering measures
        // fractionally better but adds subpixel colour fringes that show up as
        // cyan and orange edges against the dark panel.
        //
        // Also why centring is alignment and not TextMetrics: NativeRendering
        // bypasses Qt Quick's text layout when it paints, so the metrics
        // describe a box the glyph is not drawn into, and centring the ink by
        // them put every icon 1-2px below centre.
        renderType: Text.NativeRendering
    }
}