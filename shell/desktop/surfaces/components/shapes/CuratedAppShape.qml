import QtQuick
import "../../../core"

Item {
    id: root

    property string appId: ""
    property real size: 24
    property color color: Theme.acidGreen
    property real strokeWidth: 1.5
    property bool active: false
    property bool destructive: false
    property bool animate: !Settings.reducedMotion

    readonly property bool _reducedMotion: Settings.reducedMotion
    readonly property string normalizedAppId: normalizeAppId(root.appId)

    width: root.size
    height: root.size

    function normalizeAppId(rawId) {
        if (!rawId || typeof rawId !== "string") {
            return "";
        }
        var s = rawId.trim().toLowerCase();
        s = s.replace(/\.desktop$/, "");
        s = s.replace(/^(org\.kde\.|com\.mitchellh\.|dev\.zed\.|io\.mpv\.|md\.obsidian\.|org\.gnu\.)/, "");
        if (s.indexOf(".") !== -1) {
            var parts = s.split(".");
            s = parts[parts.length - 1];
        }
        s = s.replace(/(-preview|-client|\s*\(client\))$/, "");
        if (s.indexOf("nvidia") !== -1 && (s.indexOf("settings") !== -1 || s === "nvidia")) {
            return "nvidia-settings";
        }
        var valid = ["dolphin", "emacs", "ghostty", "kitty", "mpv", "obsidian", "nvidia-settings", "okular", "zed"];
        if (valid.indexOf(s) !== -1) {
            return s;
        }
        return "";
    }

    function triggerGlitch() {
        if (_reducedMotion || !root.animate) {
            return;
        }
        glitchSequence.restart();
    }

    onActiveChanged: {
        if (active) {
            triggerGlitch();
        }
    }

    on_ReducedMotionChanged: {
        if (_reducedMotion) {
            glitchSequence.stop();
            shapeContainer.x = 0;
            shapeContainer.y = 0;
            shapeContainer.opacity = 1.0;
            scanline.opacity = 0.0;
        }
    }

    Item {
        id: shapeContainer
        width: 24
        height: 24
        scale: root.size / 24.0
        transformOrigin: Item.TopLeft

        DolphinShape {
            visible: root.normalizedAppId === "dolphin"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        EmacsShape {
            visible: root.normalizedAppId === "emacs"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        GhosttyShape {
            visible: root.normalizedAppId === "ghostty"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        KittyShape {
            visible: root.normalizedAppId === "kitty"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        MpvShape {
            visible: root.normalizedAppId === "mpv"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        ObsidianShape {
            visible: root.normalizedAppId === "obsidian"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        NvidiaSettingsShape {
            visible: root.normalizedAppId === "nvidia-settings"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        OkularShape {
            visible: root.normalizedAppId === "okular"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        ZedShape {
            visible: root.normalizedAppId === "zed"
            color: root.color
            active: root.active
            strokeWidth: root.strokeWidth
            size: 24
        }

        // Cybernetic 1px Scanline Laser Shimmer
        Rectangle {
            id: scanline
            width: 24
            height: 1
            color: root.color
            opacity: 0.0
            z: 10
        }
    }

    ParallelAnimation {
        id: glitchSequence
        running: false

        // 1. Spatial Jitter Sequence
        SequentialAnimation {
            NumberAnimation { target: shapeContainer; property: "x"; to: root.animate ? -1.5 : 0; duration: 30 }
            NumberAnimation { target: shapeContainer; property: "y"; to: root.animate ? 0.5 : 0; duration: 30 }
            NumberAnimation { target: shapeContainer; property: "x"; to: root.animate ? 1.0 : 0; duration: 40 }
            NumberAnimation { target: shapeContainer; property: "y"; to: root.animate ? -0.5 : 0; duration: 40 }
            NumberAnimation { target: shapeContainer; property: "x"; to: 0; duration: 30 }
            NumberAnimation { target: shapeContainer; property: "y"; to: 0; duration: 30 }
        }

        // 2. Opacity Signal Pulse Sequence (subtle, never drops below 0.5)
        SequentialAnimation {
            NumberAnimation { target: shapeContainer; property: "opacity"; to: root.animate ? 0.75 : 1.0; duration: 35 }
            NumberAnimation { target: shapeContainer; property: "opacity"; to: root.animate ? 0.95 : 1.0; duration: 45 }
            NumberAnimation { target: shapeContainer; property: "opacity"; to: root.animate ? 0.70 : 1.0; duration: 30 }
            NumberAnimation { target: shapeContainer; property: "opacity"; to: 1.0; duration: 40 }
        }

        // 3. Scanline Sweep Sequence
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation { target: scanline; property: "y"; from: 0; to: 24; duration: 120 }
                SequentialAnimation {
                    NumberAnimation { target: scanline; property: "opacity"; from: 0; to: root.animate ? 0.8 : 0; duration: 40 }
                    NumberAnimation { target: scanline; property: "opacity"; from: root.animate ? 0.8 : 0; to: 0; duration: 80 }
                }
            }
            PropertyAction { target: scanline; property: "y"; value: 0 }
            PropertyAction { target: scanline; property: "opacity"; value: 0 }
        }
    }
}
