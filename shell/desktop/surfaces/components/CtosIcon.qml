import QtQuick
import Quickshell
import QtQuick.Effects
import "../../core"
import "./shapes"

// Tier 3 ColorOverlay / MultiEffect unified cybernetic icon router
Item {
    id: root

    property string name: ""
    property real size: 24
    property color color: Theme.textPrimary
    property bool active: false
    property bool destructive: false
    property string fallbackIcon: "application-x-executable"
    property bool animate: !Settings.reducedMotion

    implicitWidth: Math.max(0, root.size)
    implicitHeight: Math.max(0, root.size)
    width: Math.max(0, root.size)
    height: Math.max(0, root.size)

    readonly property color effectiveColor: root.destructive ? Theme.destructive : (root.active ? Theme.acidGreen : root.color)
    readonly property string normalizedName: (!name || name === "") ? "" : _normalize(root.name)

    readonly property string systemIconName: _resolveSystemIcon(root.normalizedName)
    readonly property bool isSystemIcon: systemIconName !== ""

    readonly property bool isCuratedApp: !isSystemIcon && (_resolveCuratedApp(root.normalizedName) !== "")
    readonly property bool isShaderFallback: !isSystemIcon && !isCuratedApp

    function _normalize(raw) {
        if (!raw || !name || name === "" || typeof raw !== "string" || raw.trim() === "") {
            return "";
        }
        var s = raw.trim().toLowerCase();
        if (s.endsWith(".desktop")) {
            s = s.replace(".desktop", "");
        }
        s = s.replace(/^(org\.kde\.|com\.mitchellh\.|dev\.zed\.|io\.mpv\.|md\.obsidian\.|org\.gnu\.)/, "");
        if (s.indexOf("/") !== -1) {
            var parts = s.split("/");
            s = parts[parts.length - 1];
        }
        if (s.indexOf(".") !== -1) {
            var segments = s.split(".");
            s = segments[segments.length - 1];
        }
        s = s.replace(/(-preview|-client|\s*\(client\))$/, "");
        return s;
    }

    function _resolveSystemIcon(norm) {
        if (!norm || norm === "") return "";
        var direct = [
            "battery", "battery-charging", "battery-low",
            "wifi", "wifi-slash",
            "volume", "volume-mute", "volume-slash",
            "microphone", "microphone-slash",
            "lock", "reboot", "power", "logout",
            "brightness", "gear", "warning", "close", "check"
        ];
        if (direct.indexOf(norm) !== -1) {
            if (norm === "volume-slash") return "volume-mute";
            return norm;
        }

        var aliases = {
            "system-lock-screen": "lock",
            "preferences-system": "gear",
            "preferences-desktop-notification-bell": "warning",
            "system-log-out": "logout",
            "system-reboot": "reboot",
            "system-shutdown": "power",
            "network": "wifi",
            "network-wireless": "wifi",
            "network-wireless-signal-excellent": "wifi",
            "network-wireless-disconnected": "wifi-slash",
            "network-wireless-offline": "wifi-slash",
            "audio-volume-high": "volume",
            "audio-volume-medium": "volume",
            "audio-volume-low": "volume",
            "audio-volume-muted": "volume-mute",
            "audio-input-microphone": "microphone",
            "audio-input-microphone-muted": "microphone-slash",
            "battery-full": "battery",
            "battery-good": "battery",
            "battery-caution": "battery-low",
            "battery-empty": "battery-low",
            "view-refresh": "reboot",
            "window-close": "close",
            "dialog-warning": "warning"
        };
        return aliases[norm] || "";
    }

    function _resolveCuratedApp(norm) {
        if (!norm || norm === "") return "";
        var curated = [
            "dolphin", "emacs", "ghostty", "kitty", "mpv",
            "obsidian", "nvidia-settings", "okular", "zed"
        ];
        if (curated.indexOf(norm) !== -1) return norm;
        if (norm.indexOf("nvidia") !== -1 && (norm.indexOf("settings") !== -1 || norm === "nvidia")) {
            return "nvidia-settings";
        }
        for (var i = 0; i < curated.length; ++i) {
            if (norm.indexOf(curated[i]) !== -1) {
                return curated[i];
            }
        }
        return "";
    }

    // TIER 1: Phosphor System SVGs (Dynamic Recoloring)
    Item {
        id: tier1Container
        anchors.fill: parent
        visible: root.isSystemIcon

        Image {
            id: systemSvg
            anchors.fill: parent
            source: root.isSystemIcon ? Qt.resolvedUrl("../../assets/icons/" + root.systemIconName + ".svg") : ""
            sourceSize: Qt.size(Math.max(1, root.size), Math.max(1, root.size))
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
        }

        MultiEffect {
            id: systemEffect
            anchors.fill: systemSvg
            source: systemSvg
            colorization: 1.0
            colorizationColor: root.effectiveColor
            visible: root.isSystemIcon && (systemSvg.status !== Image.Error && systemSvg.status !== Image.Null)
        }
    }

    // TIER 2: Curated Application Shapes (9 Custom Cybernetic Vector Shapes)
    CuratedAppShape {
        id: curatedShapeItem
        anchors.centerIn: parent
        size: root.size
        color: root.effectiveColor
        appId: root.normalizedName
        active: root.active
        destructive: root.destructive
        animate: root.animate
        visible: root.isCuratedApp
    }

    // TIER 3: Shader Fallback (Uncurated Applications ColorOverlay Tinting)
    Item {
        id: tier3Container
        anchors.fill: parent
        visible: root.isShaderFallback

        Image {
            id: fallbackRawImage
            anchors.fill: parent
            source: root.isShaderFallback ? Quickshell.iconPath(root.name, root.fallbackIcon) : ""
            sourceSize: Qt.size(Math.max(1, root.size), Math.max(1, root.size))
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: false
        }

        MultiEffect {
            id: fallbackEffect
            anchors.fill: fallbackRawImage
            source: fallbackRawImage
            colorization: 1.0
            colorizationColor: root.effectiveColor
            visible: root.isShaderFallback
        }
    }
}
