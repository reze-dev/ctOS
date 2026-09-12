import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../core"

Item {
    id: root

    // =========================================================================
    // Public Dimensions & Styling Contract
    // =========================================================================

    implicitWidth: 280
    implicitHeight: 120
    width: implicitWidth
    height: implicitHeight

    property color bracketColor: root.isPlaying ? Theme.acidGreen : Theme.gray500

    // Optional direct player override for testing / dynamic injection
    property var playerOverride: null

    // =========================================================================
    // Reactive DBus MPRIS Player Resolution
    // =========================================================================

    // Reactive counter incremented when active player state changes
    property int _stateTrigger: 0

    // Connect to individual player signals to reactively re-evaluate active player
    Repeater {
        model: Mpris.players.values

        Item {
            id: playerItem
            required property var modelData

            Connections {
                target: playerItem.modelData

                function onPlaybackStateChanged(): void {
                    root._stateTrigger++;
                }
                function onTrackTitleChanged(): void {
                    root._stateTrigger++;
                }
                function onTrackArtistChanged(): void {
                    root._stateTrigger++;
                }
                function onIdentityChanged(): void {
                    root._stateTrigger++;
                }
            }
        }
    }

    // Resolve active player: Player override first, Playing first, Paused second, fallback first available
    readonly property var activePlayer: {
        if (root.playerOverride !== null && root.playerOverride !== undefined) {
            return root.playerOverride;
        }

        // Evaluate reactivity trigger
        const trigger = root._stateTrigger;
        const list = Mpris.players.values;
        if (!list || list.length === 0) return null;

        // 1. Highest priority: Currently playing player
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) {
                return p;
            }
        }

        // 2. Second priority: Paused player with active track information
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused && p.trackTitle && p.trackTitle.trim() !== "") {
                return p;
            }
        }

        // 3. Third priority: Any paused player
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused) {
                return p;
            }
        }

        // 4. Fallback: First available player
        return list[0] || null;
    }

    // Playback state evaluation
    readonly property bool hasMedia: activePlayer !== null && (
        activePlayer.playbackState === MprisPlaybackState.Playing ||
        (activePlayer.trackTitle !== undefined && activePlayer.trackTitle !== null && activePlayer.trackTitle.trim() !== "")
    )

    readonly property bool isPlaying: hasMedia && activePlayer.playbackState === MprisPlaybackState.Playing

    // Media metadata formatting
    readonly property string title: hasMedia ? ((activePlayer && activePlayer.trackTitle && activePlayer.trackTitle.trim() !== "") ? activePlayer.trackTitle.trim() : "--UNTITLED--") : "NO CARRIER"
    readonly property string artist: hasMedia ? ((activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.trim() !== "") ? activePlayer.trackArtist.trim() : "--UNKNOWN SOURCE--") : "FREQUENCY SCAN ACTIVE"
    readonly property string sourceIdentity: (activePlayer && activePlayer.identity && activePlayer.identity.trim() !== "") ? activePlayer.identity.trim() : (hasMedia ? "AUDIO COMM" : "NONE")

    // Thematic intercepted labels
    readonly property string interceptString: "[FREQ INTERCEPT] " + root.title + " - " + root.artist
    readonly property string fallbackString: "[FREQ SCAN] AWAITING TRANSMISSION..."
    readonly property string statusText: root.isPlaying ? "[LOCKED 104.2MHz]" : "[SCANNING]"

    // =========================================================================
    // Playback Control Methods (Pure DBus Actions)
    // =========================================================================

    function play(): void {
        if (root.activePlayer && typeof root.activePlayer.play === "function") {
            root.activePlayer.play();
        }
    }

    function pause(): void {
        if (root.activePlayer && typeof root.activePlayer.pause === "function") {
            root.activePlayer.pause();
        }
    }

    function togglePlaying(): void {
        if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
            root.activePlayer.togglePlaying();
        }
    }

    function next(): void {
        if (root.activePlayer && typeof root.activePlayer.next === "function") {
            root.activePlayer.next();
        }
    }

    function previous(): void {
        if (root.activePlayer && typeof root.activePlayer.previous === "function") {
            root.activePlayer.previous();
        }
    }

    // =========================================================================
    // Animated Spectrum Visualizer
    // =========================================================================

    property real visualizerPhase: 0.0

    NumberAnimation {
        id: spectrumAnim
        target: root
        property: "visualizerPhase"
        from: 0.0
        to: 6.283185307179586
        duration: 1400
        loops: Animation.Infinite
        running: root.isPlaying
    }

    // =========================================================================
    // Background Surface & Framing
    // =========================================================================

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: root.isPlaying ? Theme.acidGreen : Theme.gray700
        border.width: Theme.borderWidth
    }

    CornerBrackets {
        bracketColor: root.bracketColor
    }

    // =========================================================================
    // Surveillance Feed HUD Layout
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // Header: Frequency Intercept & Locked Carrier Status
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "AUDIO // FREQ INTERCEPT"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.statusText
                color: root.isPlaying ? Theme.acidGreen : Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Main Intercept Label
        Text {
            Layout.fillWidth: true
            text: root.hasMedia ? root.interceptString : root.fallbackString
            color: root.hasMedia ? Theme.acidGreen : Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightBold
            elide: Text.ElideRight
        }

        // Telemetry Metadata Row: Source Identity & Stream Status
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "SRC: " + root.sourceIdentity
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.isPlaying ? "STREAM: 256-BIT" : "CARRIER: IDLE"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Animated Frequency Visualizer Spectrum Bars (16 bars)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: 3

            Repeater {
                model: 16

                Rectangle {
                    id: barRect
                    required property int index

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.preferredHeight: root.isPlaying
                        ? Math.max(3, Math.round((Math.sin((barRect.index * 0.72) + root.visualizerPhase) * 0.35 + Math.cos((barRect.index * 1.25) - root.visualizerPhase * 1.3) * 0.25 + 0.5) * 16))
                        : 2
                    color: root.isPlaying ? Theme.acidGreen : Theme.gray600
                }
            }
        }
    }
}
