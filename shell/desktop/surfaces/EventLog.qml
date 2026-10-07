pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "./components"
import "./widgets"

FocusScope {
    id: root

    implicitWidth: 360
    width: 360
    implicitHeight: 500
    height: 500
    focus: true

    property int currentTab: 0
    readonly property bool isOpen: OverlayController.activeSurface === OverlayController.Surface.EventLog

    // Keyboard navigation focus & Tiered Escape trapping
    Keys.onEscapePressed: function (event) {
        OverlayController.close();
        if (event) {
            event.accepted = true;
        }
    }

    // Synchronize active focus when opened by OverlayController
    Connections {
        target: OverlayController

        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.EventLog) {
                root.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        if (OverlayController.activeSurface === OverlayController.Surface.EventLog) {
            root.forceActiveFocus();
        }
    }

    // =========================================================================
    // MPRIS Active Player Tracking (Tab 2 Audio Matrix)
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

    readonly property bool isPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing

    property real visualizerPhase: 0.0

    NumberAnimation {
        id: visualizerAnim
        target: root
        property: "visualizerPhase"
        from: 0.0
        to: 6.283185307179586
        duration: 1200
        loops: Animation.Infinite
        running: root.isOpen && root.currentTab === 2 && root.isPlaying && !Settings.reducedMotion
    }

    // Rate formatting helper for telemetry
    function formatBytesRate(bytes: real): string {
        if (bytes >= 1048576) {
            return (bytes / 1048576).toFixed(1) + " MB/s";
        }
        if (bytes >= 1024) {
            return (bytes / 1024).toFixed(1) + " KB/s";
        }
        return Math.round(bytes) + " B/s";
    }

    // Dismiss area covering the outer canvas outside the animated panel
    MouseArea {
        id: canvasDismissArea
        anchors.fill: parent
        onClicked: OverlayController.close()
    }

    // Animated Visual Panel Container (morphs from Dynamic Island 120x34 to 360x500)
    Rectangle {
        id: panelContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.isOpen ? 360 : 120
        height: root.isOpen ? 500 : 34
        radius: root.isOpen ? Theme.radiusMedium : 17
        color: Theme.background
        border.color: root.isOpen ? Theme.accent : "black"
        border.width: Theme.borderWidth
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        // Inside Click Consumer
        MouseArea {
            id: insideClickConsumer
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        // Corner Brackets decoration (cyber aesthetic)
        CornerBrackets {
            id: cornerBrackets
            bracketColor: Theme.acidGreen
            margin: Theme.cornerBracketMargin
            armLength: Theme.cornerBracketArmLength
            thickness: Theme.cornerBracketThickness
            z: 10
            opacity: root.isOpen ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Main Content Column
        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: Theme.paddingXl
            spacing: Theme.spacingMedium
            opacity: root.isOpen ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Rectangle {
                    Layout.preferredHeight: 8
                    Layout.preferredWidth: 8
                    color: Theme.accent
                    radius: 4
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.accent
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSegment
                    font.weight: Theme.fontWeightBold
                    text: {
                        if (root.currentTab === 0) return "// EVENT LOG";
                        if (root.currentTab === 1) return "// QUICK SWITCHES";
                        if (root.currentTab === 2) return "// AUDIO MATRIX";
                        if (root.currentTab === 3) return "// SYSTEM TELEMETRY";
                        return "// EVENT LOG";
                    }
                }

                // DND Toggle Button
                Rectangle {
                    id: dndButton
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: dndLabel.implicitWidth + Theme.paddingMedium * 2
                    border.color: NotificationService.doNotDisturb ? Theme.warningRed : (dndMouseArea.containsMouse ? Theme.accent : Theme.borderMuted)
                    border.width: Theme.borderWidth
                    color: NotificationService.doNotDisturb ? Theme.surfaceSelected : (dndMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                    radius: Theme.radiusSmall

                    Text {
                        id: dndLabel
                        anchors.centerIn: parent
                        color: NotificationService.doNotDisturb ? Theme.warningRed : (dndMouseArea.containsMouse ? Theme.accent : Theme.textSecondary)
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: NotificationService.doNotDisturb ? "[DND]" : "[DND OFF]"
                    }

                    MouseArea {
                        id: dndMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                // Close Button
                Rectangle {
                    id: closeButton
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 24
                    border.color: closeMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: closeMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        color: closeMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: "x"
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: OverlayController.close()
                    }
                }
            }

            // Header Divider & 4 Tabs
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    // Tab 0: EVENTS
                    Rectangle {
                        id: tab0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: root.currentTab === 0 ? Theme.surfaceSelected : (tab0MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.currentTab === 0 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: tab0Text
                            anchors.centerIn: parent
                            color: root.currentTab === 0 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "EVENTS"
                        }

                        MouseArea {
                            id: tab0MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 0
                        }
                    }

                    // Tab 1: SWITCHES
                    Rectangle {
                        id: tab1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: root.currentTab === 1 ? Theme.surfaceSelected : (tab1MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.currentTab === 1 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: tab1Text
                            anchors.centerIn: parent
                            color: root.currentTab === 1 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "SWITCHES"
                        }

                        MouseArea {
                            id: tab1MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 1
                        }
                    }

                    // Tab 2: AUDIO
                    Rectangle {
                        id: tab2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: root.currentTab === 2 ? Theme.surfaceSelected : (tab2MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.currentTab === 2 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: tab2Text
                            anchors.centerIn: parent
                            color: root.currentTab === 2 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "AUDIO"
                        }

                        MouseArea {
                            id: tab2MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 2
                        }
                    }

                    // Tab 3: TELEMETRY
                    Rectangle {
                        id: tab3
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: root.currentTab === 3 ? Theme.surfaceSelected : (tab3MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.currentTab === 3 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: tab3Text
                            anchors.centerIn: parent
                            color: root.currentTab === 3 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "TELEMETRY"
                        }

                        MouseArea {
                            id: tab3MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentTab = 3
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: Theme.spacingMedium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.borderWidth
                    color: Theme.borderMuted
                }
            }

            // =================================================================
            // TAB 0: Notification History Content Area
            // =================================================================
            Item {
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTab === 0

                // Notification History ListView
                ListView {
                    id: historyListView
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: Theme.spacingSmall
                    model: NotificationService.history
                    visible: NotificationService.history.count > 0

                    delegate: Rectangle {
                        id: cardItem
                        required property int index
                        required property var notifId
                        required property string appName
                        required property string summary
                        required property string body
                        required property int urgency
                        required property string timestamp

                        width: historyListView.width
                        implicitHeight: cardLayout.implicitHeight + Theme.paddingMedium * 2
                        color: Theme.gray800
                        border.color: Theme.gray700
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        readonly property color urgencyColor: {
                            if (cardItem.urgency === 2) {
                                return Theme.warningRed;
                            }
                            if (cardItem.urgency === 0) {
                                return Theme.textMuted;
                            }
                            return Theme.acidGreen;
                        }

                        // Urgency accent stripe on left edge
                        Rectangle {
                            id: urgencyStripe
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: cardItem.urgencyColor
                            radius: Theme.radiusSmall
                            width: 3
                        }

                        ColumnLayout {
                            id: cardLayout
                            anchors.left: urgencyStripe.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.paddingMedium
                            spacing: Theme.spacingSmall

                            // Header line: Urgency Dot, App Name (left), Timestamp (right)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall

                                Rectangle {
                                    Layout.preferredHeight: 6
                                    Layout.preferredWidth: 6
                                    color: cardItem.urgencyColor
                                    radius: 3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightMedium
                                    text: cardItem.appName.toUpperCase()
                                }

                                Text {
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    text: cardItem.timestamp
                                }
                            }

                            // Summary text
                            Text {
                                Layout.fillWidth: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                text: cardItem.summary
                            }

                            // Body text (word wrap, max 3 lines, elide)
                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                maximumLineCount: 3
                                text: cardItem.body
                                visible: cardItem.body !== ""
                                wrapMode: Text.WordWrap
                            }

                            // Dismiss action button
                            RowLayout {
                                Layout.fillWidth: true

                                Item {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    id: dismissBtn
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: dismissText.implicitWidth + Theme.paddingSmall * 2
                                    border.color: dismissMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: dismissMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                    radius: Theme.radiusSmall

                                    Text {
                                        id: dismissText
                                        anchors.centerIn: parent
                                        color: dismissMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Theme.fontWeightMedium
                                        text: "[DISMISS]"
                                    }

                                    MouseArea {
                                        id: dismissMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: NotificationService.dismissHistoryItem(cardItem.index)
                                    }
                                }
                            }
                        }
                    }
                }

                // Scrollbar track & thumb
                Rectangle {
                    id: scrollTrack
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: Theme.gray800
                    radius: 2
                    visible: historyListView.visible && (historyListView.height < historyListView.contentHeight)
                    width: 4

                    Rectangle {
                        id: scrollThumb
                        color: Theme.acidGreen
                        height: Math.max(16, historyListView.visibleArea.heightRatio * historyListView.height)
                        radius: 2
                        width: 4
                        y: historyListView.visibleArea.yPosition * historyListView.height
                    }
                }

                // Empty state container
                Item {
                    id: emptyState
                    anchors.fill: parent
                    visible: NotificationService.history.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 8
                            Layout.preferredWidth: 8
                            color: Theme.textMuted
                            radius: 4
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightMedium
                            text: "NO NOTIFICATIONS // STANDBY"
                        }
                    }
                }
            }

            // =================================================================
            // TAB 1: Quick Switches Content Area
            // =================================================================
            ColumnLayout {
                id: quickSwitchesContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTab === 1
                spacing: Theme.spacingMedium

                // Switch 1: Do Not Disturb
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: NotificationService.doNotDisturb ? Theme.surfaceSelected : Theme.gray800
                    border.color: NotificationService.doNotDisturb ? Theme.warningRed : (swDndMouse.containsMouse ? Theme.accent : Theme.gray700)
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: NotificationService.doNotDisturb ? Theme.warningRed : Theme.gray600
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "DO NOT DISTURB"
                                color: NotificationService.doNotDisturb ? Theme.warningRed : Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                            }

                            Text {
                                text: NotificationService.doNotDisturb ? "ACTIVE // TOASTS SUPPRESSED" : "INACTIVE // TOASTS ALLOWED"
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 24
                            color: NotificationService.doNotDisturb ? Theme.warningRed : (swDndMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            border.color: NotificationService.doNotDisturb ? Theme.warningRed : Theme.borderMuted
                            border.width: Theme.borderWidth
                            radius: Theme.radiusSmall

                            Text {
                                anchors.centerIn: parent
                                text: NotificationService.doNotDisturb ? "MUTED" : "OFF"
                                color: NotificationService.doNotDisturb ? "black" : Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }
                    }

                    MouseArea {
                        id: swDndMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                // Switch 2: Wi-Fi Subsystem
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: NetworkService.wifiEnabled ? Theme.surfaceSelected : Theme.gray800
                    border.color: NetworkService.wifiEnabled ? Theme.acidGreen : (swWifiMouse.containsMouse ? Theme.accent : Theme.gray700)
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: NetworkService.wifiEnabled ? Theme.acidGreen : Theme.gray600
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "WI-FI SUBSYSTEM"
                                color: NetworkService.wifiEnabled ? Theme.acidGreen : Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                            }

                            Text {
                                text: NetworkService.wifiEnabled
                                    ? (NetworkService.isWifi ? ("CONNECTED: " + NetworkService.networkName) : "RADIO ON // DISCONNECTED")
                                    : "RADIO DISABLED"
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 24
                            color: NetworkService.wifiEnabled ? Theme.acidGreen : (swWifiMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            border.color: NetworkService.wifiEnabled ? Theme.acidGreen : Theme.borderMuted
                            border.width: Theme.borderWidth
                            radius: Theme.radiusSmall

                            Text {
                                anchors.centerIn: parent
                                text: NetworkService.wifiEnabled ? "ON" : "OFF"
                                color: NetworkService.wifiEnabled ? "black" : Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }
                    }

                    MouseArea {
                        id: swWifiMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: NetworkService.toggleWifi()
                    }
                }

                // Switch 3: Bluetooth Subsystem
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: BluetoothService.powered ? Theme.surfaceSelected : Theme.gray800
                    border.color: BluetoothService.powered ? Theme.acidGreen : (swBtMouse.containsMouse ? Theme.accent : Theme.gray700)
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: BluetoothService.powered ? Theme.acidGreen : Theme.gray600
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "BLUETOOTH LINK"
                                color: BluetoothService.powered ? Theme.acidGreen : Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                            }

                            Text {
                                text: BluetoothService.powered
                                    ? (BluetoothService.isConnected ? ("LINKED: " + BluetoothService.deviceName) : "ADAPTER ACTIVE // IDLE")
                                    : "ADAPTER POWERED OFF"
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 24
                            color: BluetoothService.powered ? Theme.acidGreen : (swBtMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            border.color: BluetoothService.powered ? Theme.acidGreen : Theme.borderMuted
                            border.width: Theme.borderWidth
                            radius: Theme.radiusSmall

                            Text {
                                anchors.centerIn: parent
                                text: BluetoothService.powered ? "ON" : "OFF"
                                color: BluetoothService.powered ? "black" : Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }
                    }

                    MouseArea {
                        id: swBtMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: BluetoothService.togglePower()
                    }
                }

                // Switch 4: Master Audio Mute
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: !AudioService.muted ? Theme.surfaceSelected : Theme.gray800
                    border.color: !AudioService.muted ? Theme.acidGreen : (swAudioMouse.containsMouse ? Theme.accent : Theme.gray700)
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: !AudioService.muted ? Theme.acidGreen : Theme.warningRed
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "MASTER AUDIO SINK"
                                color: !AudioService.muted ? Theme.acidGreen : Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                            }

                            Text {
                                text: AudioService.muted
                                    ? "MUTED // SILENT"
                                    : ("ACTIVE // " + Math.round(AudioService.volume * 100) + "%" + (AudioService.sinkName !== "" ? (" (" + AudioService.sinkName + ")") : ""))
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 24
                            color: AudioService.muted ? Theme.warningRed : (swAudioMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            border.color: AudioService.muted ? Theme.warningRed : Theme.acidGreen
                            border.width: Theme.borderWidth
                            radius: Theme.radiusSmall

                            Text {
                                anchors.centerIn: parent
                                text: AudioService.muted ? "MUTED" : "UNMUTED"
                                color: AudioService.muted ? "black" : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }
                    }

                    MouseArea {
                        id: swAudioMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: AudioService.toggleMute()
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // =================================================================
            // TAB 2: Audio Matrix Content Area
            // =================================================================
            ColumnLayout {
                id: audioMatrixContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTab === 2
                spacing: Theme.spacingMedium

                // Output Volume Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "MASTER OUTPUT"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: AudioService.muted
                                    ? "MUTED"
                                    : Math.round(AudioService.volume * 100) + "%"
                                color: AudioService.muted ? Theme.warningRed : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // Slider Track
                        Rectangle {
                            id: sliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            color: Theme.gray700
                            radius: 6

                            Rectangle {
                                id: sliderFill
                                width: Math.max(0, Math.min(sliderTrack.width, sliderTrack.width * AudioService.volume))
                                height: parent.height
                                radius: 6
                                color: AudioService.muted ? Theme.warningRed : Theme.acidGreen
                            }

                            // Slider thumb handle
                            Rectangle {
                                x: Math.max(0, Math.min(sliderTrack.width - width, sliderTrack.width * AudioService.volume - width / 2))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: Theme.gray50
                                border.color: AudioService.muted ? Theme.warningRed : Theme.acidGreen
                                border.width: 2
                                visible: volumeMouseArea.containsMouse || volumeMouseArea.pressed
                            }

                            MouseArea {
                                id: volumeMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                function applyVolume(mouse): void {
                                    const v = Math.max(0.0, Math.min(1.0, mouse.x / sliderTrack.width));
                                    AudioService.setVolume(v);
                                }

                                onPressed: (mouse) => applyVolume(mouse)
                                onPositionChanged: (mouse) => {
                                    if (pressed) applyVolume(mouse);
                                }
                            }
                        }

                        // Bottom row: Sink name & Mute button
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: AudioService.sinkName !== "" ? AudioService.sinkName : "DEFAULT SINK"
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: 60
                                color: AudioService.muted ? Theme.warningRed : (muteBtnMouse.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: AudioService.muted ? Theme.warningRed : Theme.borderMuted
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    text: AudioService.muted ? "UNMUTE" : "MUTE"
                                    color: AudioService.muted ? "black" : Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                    font.weight: Theme.fontWeightBold
                                }

                                MouseArea {
                                    id: muteBtnMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: AudioService.toggleMute()
                                }
                            }
                        }
                    }
                }

                // MPRIS Media Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    color: Theme.gray800
                    border.color: root.isPlaying ? Theme.acidGreen : Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "MEDIA STREAM"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.isPlaying ? "STREAMING" : (root.activePlayer ? "PAUSED" : "OFFLINE")
                                color: root.isPlaying ? Theme.acidGreen : Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // Track Title
                        Text {
                            Layout.fillWidth: true
                            text: (root.activePlayer && root.activePlayer.trackTitle && root.activePlayer.trackTitle.trim() !== "")
                                ? root.activePlayer.trackTitle.trim()
                                : "NO ACTIVE MEDIA STREAM"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightBold
                            elide: Text.ElideRight
                        }

                        // Artist & Source
                        Text {
                            Layout.fillWidth: true
                            text: {
                                const artist = (root.activePlayer && root.activePlayer.trackArtist) ? root.activePlayer.trackArtist.trim() : "";
                                const identity = (root.activePlayer && root.activePlayer.identity) ? root.activePlayer.identity.trim() : "";
                                if (artist !== "" && identity !== "") return artist + " // " + identity;
                                if (artist !== "") return artist;
                                if (identity !== "") return identity;
                                return "AWAITING MPRIS TRANSMISSION";
                            }
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            elide: Text.ElideRight
                        }

                        // Control Buttons: Prev, Play/Pause, Next
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingMedium

                            // Previous Button
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 44
                                color: prevMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                border.color: prevMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    text: "|<<"
                                    color: prevMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }

                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && typeof root.activePlayer.previous === "function") {
                                            root.activePlayer.previous();
                                        }
                                    }
                                }
                            }

                            // Play / Pause Button
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 80
                                color: root.isPlaying ? Theme.surfaceSelected : (playMouse.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: root.isPlaying ? Theme.acidGreen : (playMouse.containsMouse ? Theme.accent : Theme.borderMuted)
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    text: root.isPlaying ? "PAUSE" : "PLAY"
                                    color: root.isPlaying ? Theme.acidGreen : (playMouse.containsMouse ? Theme.accent : Theme.textSecondary)
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }

                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && typeof root.activePlayer.togglePlaying === "function") {
                                            root.activePlayer.togglePlaying();
                                        }
                                    }
                                }
                            }

                            // Next Button
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 44
                                color: nextMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                border.color: nextMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    text: ">>|"
                                    color: nextMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }

                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.activePlayer && typeof root.activePlayer.next === "function") {
                                            root.activePlayer.next();
                                        }
                                    }
                                }
                            }
                        }

                        // Equalizer bars row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            spacing: 3

                            Repeater {
                                model: 12

                                Rectangle {
                                    id: matrixEqBar
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.preferredHeight: root.isPlaying
                                        ? Math.max(3, Math.round((Math.sin((matrixEqBar.index * 0.8) + root.visualizerPhase) * 0.4 + 0.5) * 14))
                                        : 2
                                    color: root.isPlaying ? Theme.acidGreen : Theme.gray600
                                    radius: 1
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // =================================================================
            // TAB 3: System Telemetry Content Area
            // =================================================================
            ColumnLayout {
                id: telemetryContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTab === 3
                spacing: Theme.spacingMedium

                // Card 1: CPU Telemetry
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "CPU TOTAL LOAD"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(SystemMonitorService.cpuTotal * 100) + "%"
                                color: SystemMonitorService.cpuTotal > 0.85 ? Theme.warningRed : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // CPU Meter Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.gray700
                            radius: 4

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * SystemMonitorService.cpuTotal))
                                height: parent.height
                                radius: 4
                                color: SystemMonitorService.cpuTotal > 0.85 ? Theme.warningRed : Theme.acidGreen
                            }
                        }

                        Text {
                            text: SystemMonitorService.cpuThreadLoads.length > 0
                                ? (SystemMonitorService.cpuThreadLoads.length + " THREADS MONITORED // PROCFS ACTIVE")
                                : "SYSTEM CORES ONLINE"
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                        }
                    }
                }

                // Card 2: Memory Allocation
                Rectangle {
                    id: memCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    readonly property real memPercent: SystemMonitorService.memTotalBytes > 0
                        ? (SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes)
                        : 0.0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "MEMORY USAGE"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: Math.round(memCard.memPercent * 100) + "%"
                                color: memCard.memPercent > 0.9 ? Theme.warningRed : Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        // Memory Meter Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.gray700
                            radius: 4

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * memCard.memPercent))
                                height: parent.height
                                radius: 4
                                color: memCard.memPercent > 0.9 ? Theme.warningRed : Theme.acidGreen
                            }
                        }

                        Text {
                            text: (SystemMonitorService.memUsedBytes / 1073741824).toFixed(1) + " GB / " +
                                  (SystemMonitorService.memTotalBytes / 1073741824).toFixed(1) + " GB (" +
                                  (SystemMonitorService.swapUsedBytes / 1073741824).toFixed(1) + " GB SWAP)"
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                        }
                    }
                }

                // Card 3: Network Bandwidth Flow
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    color: Theme.gray800
                    border.color: Theme.gray700
                    border.width: Theme.borderWidth
                    radius: Theme.radiusSmall

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "NETWORK FLOW"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: NetworkService.connectionType.toUpperCase()
                                color: NetworkService.isConnected ? Theme.acidGreen : Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "RX FLOW"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: root.formatBytesRate(SystemMonitorService.netRxBytesPerSec)
                                    color: Theme.acidGreen
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "TX FLOW"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: root.formatBytesRate(SystemMonitorService.netTxBytesPerSec)
                                    color: Theme.pastelBlue
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                }
                            }
                        }

                        Text {
                            text: "INTERFACE: " + NetworkService.networkName
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            // Footer Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.borderWidth
                color: Theme.borderMuted
                visible: root.currentTab === 0
            }

            // Footer Action Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                visible: root.currentTab === 0

                Text {
                    Layout.fillWidth: true
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    text: NotificationService.history.count > 0
                          ? NotificationService.history.count + " LOGGED"
                          : "0 LOGGED"
                }

                Rectangle {
                    id: clearAllBtn
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: clearAllText.implicitWidth + Theme.paddingMedium * 2
                    border.color: NotificationService.history.count === 0
                                  ? Theme.borderMuted
                                  : (clearMouseArea.containsMouse ? Theme.destructive : Theme.borderMuted)
                    border.width: Theme.borderWidth
                    color: NotificationService.history.count === 0
                           ? "transparent"
                           : (clearMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                    opacity: NotificationService.history.count === 0 ? 0.4 : 1.0
                    radius: Theme.radiusSmall

                    Text {
                        id: clearAllText
                        anchors.centerIn: parent
                        color: NotificationService.history.count === 0
                               ? Theme.textMuted
                               : (clearMouseArea.containsMouse ? Theme.destructive : Theme.textPrimary)
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: "[CLEAR ALL]"
                    }

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        cursorShape: NotificationService.history.count > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: NotificationService.history.count > 0
                        hoverEnabled: NotificationService.history.count > 0
                        onClicked: NotificationService.clearAll()
                    }
                }
            }
        }
    }
}
