pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../core"
import "../../services"

Item {
    id: root

    // =========================================================================
    // Dynamic Island State & Dimensions
    // =========================================================================

    readonly property real compactWidth: 120
    readonly property real mediaWidth: 240
    readonly property real expandedWidth: 300

    // States: "compact", "media", "notification"
    property string state: "compact"

    // Writable isExpanded for backward compatibility with tests.
    // Tests directly set isExpanded = true/false, so we keep it writable
    // and sync it with the state property.
    property bool isExpanded: false

    property string latestAppName: ""
    property string latestSummary: ""
    property int latestUrgency: 1
    readonly property bool isCommandCenterOpen: OverlayController.activeSurface === OverlayController.Surface.CommandCenter

    // =========================================================================
    // MPRIS Active Player Tracking & Equalizer State
    // =========================================================================

    property int _mprisTrigger: 0

    Repeater {
        model: Mpris.players.values

        Item {
            id: mprisWatcher
            required property var modelData

            Connections {
                target: mprisWatcher.modelData

                function onPlaybackStateChanged(): void {
                    root._mprisTrigger++;
                }
                function onTrackTitleChanged(): void {
                    root._mprisTrigger++;
                }
                function onTrackArtistChanged(): void {
                    root._mprisTrigger++;
                }
            }
        }
    }

    readonly property var activePlayer: {
        const trigger = root._mprisTrigger;
        const list = Mpris.players.values;
        if (!list || list.length === 0) return null;

        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) {
                return p;
            }
        }

        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused && p.trackTitle && p.trackTitle.trim() !== "") {
                return p;
            }
        }

        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused) {
                return p;
            }
        }

        return list[0] || null;
    }

    readonly property bool hasMedia: activePlayer !== null && (
        activePlayer.playbackState === MprisPlaybackState.Playing ||
        (activePlayer.trackTitle !== undefined && activePlayer.trackTitle !== null && activePlayer.trackTitle.trim() !== "")
    )
    readonly property bool isPlaying: hasMedia && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property string mediaTitle: (activePlayer && activePlayer.trackTitle && activePlayer.trackTitle.trim() !== "") ? activePlayer.trackTitle.trim() : "--UNTITLED--"
    readonly property string mediaArtist: (activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.trim() !== "") ? activePlayer.trackArtist.trim() : ""

    property real visualizerPhase: 0.0

    NumberAnimation {
        id: visualizerAnim
        target: root
        property: "visualizerPhase"
        from: 0.0
        to: 6.283185307179586
        duration: 1200
        loops: Animation.Infinite
        running: root.isPlaying && !Settings.reducedMotion
    }

    // =========================================================================
    // State Synchronization
    // =========================================================================

    // Sync isExpanded writes -> state
    onIsExpandedChanged: {
        if (root.isExpanded && root.state !== "notification") {
            root.state = "notification";
        } else if (!root.isExpanded && root.state === "notification") {
            root.state = root.hasMedia ? "media" : "compact";
        }
    }

    // Sync state -> isExpanded (for notification state changes from showNotification)
    onStateChanged: {
        if (root.state === "notification" && !root.isExpanded) {
            root.isExpanded = true;
        } else if (root.state !== "notification" && root.isExpanded) {
            root.isExpanded = false;
        }
    }

    // Sync media presence -> state (when not displaying notification)
    onHasMediaChanged: {
        if (!root.isExpanded) {
            root.state = root.hasMedia ? "media" : "compact";
        }
    }

    // Centralized layout function per dynamic-radial-geometry skill:
    // Synchronously compute width/height based on state to avoid desync.
    property real targetW: {
        const isExp = root.isExpanded || root.state === "notification";
        if (isExp) {
            return root.expandedWidth;
        } else if (root.hasMedia) {
            return root.mediaWidth;
        } else if (mouseArea.containsMouse) {
            return root.compactWidth + 12;
        }
        return root.compactWidth;
    }

    property real targetH: Theme.barHeight - 6

    // Fallback for tests: width: isExpanded ? expandedWidth : compactWidth
    width: targetW
    implicitWidth: targetW
    height: targetH
    implicitHeight: targetH

    property alias radius: visualBg.radius
    property alias color: visualBg.color

    Rectangle {
        id: visualBg
        anchors.centerIn: parent
        width: root.targetW
        height: root.targetH

        color: Theme.background
        radius: Theme.radiusPill
        border.color: (mouseArea.containsMouse || root.isExpanded) ? Theme.accent : "black"
        border.width: Theme.borderWidth
        clip: true

        opacity: root.isCommandCenterOpen ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }
    } // end visualBg

        // =========================================================================
        // Auto Collapse Timer
        // =========================================================================
        Timer {
            id: collapseTimer
            interval: 4000
            repeat: false
            onTriggered: {
                root.isExpanded = false;
            }
        }

    // Public method to trigger notification expansion
    function showNotification(appName: string, summary: string, urgency: int): void {
        root.latestAppName = appName || "System";
        root.latestSummary = summary || "";
        root.latestUrgency = (urgency !== undefined) ? urgency : 1;
        root.isExpanded = true;
        collapseTimer.restart();
    }

    // =========================================================================
    // NotificationService Connection
    // =========================================================================

    Connections {
        target: NotificationService

        function onNotificationReceived(notification): void {
            if (!NotificationService.doNotDisturb && notification) {
                root.showNotification(notification.appName, notification.summary, notification.urgency);
            }
        }
    }

    // Fallback: watch history insertions in case notificationReceived signal isn't emitted
    Connections {
        target: NotificationService.history

        function onRowsInserted(parentIndex, first, last): void {
            if (!root.isExpanded && !NotificationService.doNotDisturb && first === 0 && NotificationService.history.count > 0) {
                const item = NotificationService.history.get(0);
                if (item) {
                    root.showNotification(item.appName, item.summary, item.urgency);
                }
            }
        }
    }

    // =========================================================================
    // Compact View (Idle / DND / Unread)
    // =========================================================================

    RowLayout {
        id: compactContent
        anchors.centerIn: parent
        opacity: (!root.isExpanded && !root.hasMedia) ? 1.0 : 0.0
        visible: opacity > 0.0
        spacing: Theme.spacingSmall

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        // State 1: DND active
        Text {
            id: dndIndicator
            visible: NotificationService.doNotDisturb
            text: "[DND]"
            color: Theme.warningRed
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
        }

        // State 2: Active unread notifications (when not DND)
        Rectangle {
            id: unreadDot
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount > 0
            width: 6
            height: 6
            radius: 3
            color: Theme.acidGreen
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: unreadText
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount > 0
            text: NotificationService.unreadCount + " NOTIF"
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
        }

        // State 3: Idle standby (no notifications and not DND)
        Rectangle {
            id: idleDot
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount === 0
            width: 6
            height: 6
            radius: 3
            color: Theme.acidGreen
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: idleText
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount === 0
            text: "// IDLE"
            color: Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
        }
    }

    // =========================================================================
    // Media Pill / Live Activity View (240x34)
    // =========================================================================

    RowLayout {
        id: mediaContent
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        opacity: (!root.isExpanded && root.hasMedia) ? 1.0 : 0.0
        visible: opacity > 0.0
        spacing: Theme.spacingSmall

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.isPlaying ? "▶" : "⏸"
            color: root.isPlaying ? Theme.acidGreen : Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: root.mediaArtist !== "" ? (root.mediaTitle + " // " + root.mediaArtist) : root.mediaTitle
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // Animated Equalizer Bars
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 14
            spacing: 2

            Repeater {
                model: 4

                Rectangle {
                    id: eqBar
                    required property int index
                    Layout.alignment: Qt.AlignBottom
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: root.isPlaying
                        ? Math.max(3, Math.round((Math.sin((eqBar.index * 1.1) + root.visualizerPhase) * 0.4 + 0.5) * 14))
                        : 3
                    color: root.isPlaying ? Theme.acidGreen : Theme.gray600
                    radius: 1
                }
            }
        }
    }

    // =========================================================================
    // Expanded View (Active Notification Banner)
    // =========================================================================

    RowLayout {
        id: expandedContent
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        opacity: (root.isExpanded || root.state === "notification") ? 1.0 : 0.0
        visible: opacity > 0.0
        spacing: Theme.spacingSmall

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 6
            height: 6
            radius: 3
            color: root.latestUrgency === 2 ? Theme.warningRed : Theme.acidGreen
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.latestAppName
            color: Theme.textSecondary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "»"
            color: Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: root.latestSummary
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    // =========================================================================
    // Mouse Interaction
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                NotificationService.toggleDnd();
            } else {
                if (root.isCommandCenterOpen) {
                    OverlayController.close();
                } else {
                    collapseTimer.stop();
                    root.isExpanded = false;
                    root.state = root.hasMedia ? "media" : "compact";
                    OverlayController.openCommandCenter();
                }
            }
        }

        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            AudioService.stepVolume(delta);
        }
    }
}

