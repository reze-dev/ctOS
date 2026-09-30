pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "./components"
import "./widgets"

FocusScope {
    id: root

    implicitWidth: 360
    width: 360
    focus: true

    implicitHeight: panelContainer.implicitHeight
    height: panelContainer.height

    readonly property bool isOpen: OverlayController.activeSurface === OverlayController.Surface.CommandCenter

    Keys.onEscapePressed: function (event) {
        if (root.confirmingForgetSsid !== "") {
            root.confirmingForgetSsid = "";
        } else if (root.isConfirming) {
            root.cancelConfirmation();
        } else if (root.selectedSsid !== "") {
            root.selectedSsid = "";
        } else {
            OverlayController.close();
        }
        if (event) {
            event.accepted = true;
        }
    }

    Connections {
        target: OverlayController
        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.CommandCenter) {
                root.forceActiveFocus();
                if (OverlayController.pendingSessionAction !== "") {
                    root.confirmationAction = OverlayController.pendingSessionAction;
                    OverlayController.pendingSessionAction = "";
                    panelContainer.activeAccordion = "power";
                } else if (OverlayController.pendingRailView !== "") {
                    panelContainer.activeAccordion = OverlayController.pendingRailView;
                    OverlayController.pendingRailView = "";
                } else if (panelContainer.activeAccordion === "") {
                    panelContainer.activeAccordion = "notifications";
                }
            }
        }
        function onOverlayClosed(surface: int): void {
            if (surface === OverlayController.Surface.CommandCenter) {
                root.confirmationAction = "";
                root.selectedSsid = "";
                root.confirmingForgetSsid = "";
            }
        }
    }

    Component.onCompleted: {
        if (OverlayController.activeSurface === OverlayController.Surface.CommandCenter) {
            root.forceActiveFocus();
            if (panelContainer.activeAccordion === "") {
                panelContainer.activeAccordion = "notifications";
            }
        }
    }

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
        running: root.isOpen && panelContainer.expandedAccordion === "audio" && root.isPlaying && !Settings.reducedMotion
    }

    Process {
        id: lockProcess
        command: ["loginctl", "lock-session"]
        running: false
    }

    Process {
        id: logoutProcess
        command: ["hyprctl", "dispatch", "exit"]
        running: false
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
        running: false
    }

    Process {
        id: poweroffProcess
        command: ["systemctl", "poweroff"]
        running: false
    }


    property string confirmationAction: ""
    readonly property bool isConfirming: confirmationAction !== ""

    function triggerConfirmation(action: string): void {
        confirmationAction = action;
        root.forceActiveFocus();
    }

    function cancelConfirmation(): void {
        confirmationAction = "";
    }

    function executeConfirmation(): void {
        const action = confirmationAction;
        confirmationAction = "";

        if (action === "reboot") {
            SessionService.reboot();
        } else if (action === "poweroff") {
            SessionService.poweroff();
        } else if (action === "logout") {
            SessionService.logout();
        }
    }

    property string selectedSsid: ""
    property string confirmingForgetSsid: ""

    MouseArea {
        id: canvasDismissArea
        anchors.fill: parent
        onClicked: OverlayController.close()
    }

    Rectangle {
        id: panelContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        implicitHeight: height
        radius: root.isOpen ? Theme.radiusMedium : 17
        color: Theme.background
        border.color: root.isConfirming ? Theme.destructive : (root.isOpen ? Theme.accent : "black")
        border.width: Theme.borderWidth
        clip: true

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges {
                    target: panelContainer
                    width: 360
                    height: mainLayout.implicitHeight + Theme.paddingXl * 2
                }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges {
                    target: panelContainer
                    width: 120
                    height: 34
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { properties: "width,height"; duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { properties: "width,height"; duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.InOutQuad }
            }
        ]

        Behavior on radius {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        MouseArea {
            id: insideClickConsumer
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        CornerBrackets {
            id: cornerBrackets
            bracketColor: root.isConfirming ? Theme.destructive : Theme.acidGreen
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

        property string activeAccordion: ""
        readonly property alias expandedAccordion: panelContainer.activeAccordion

        function toggleAccordion(id: string): void {
            activeAccordion = (activeAccordion === id ? "" : id);
        }

        Component {
            id: dndHeaderAction

            Rectangle {
                id: dndButton
                width: dndLabel.implicitWidth + Theme.paddingMedium * 2
                height: 24
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
                    preventStealing: true
                    onClicked: function (mouse) {
                        mouse.accepted = true;
                        NotificationService.toggleDnd();
                    }
                }
            }
        }

        Component {
            id: wifiHeaderAction

            Rectangle {
                id: wifiToggleBtn
                width: 60
                height: 24
                color: NetworkService.wifiEnabled ? Theme.surfaceSelected : (wifiToggleMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: NetworkService.wifiEnabled ? Theme.acidGreen : Theme.borderMuted
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: NetworkService.wifiEnabled ? "ON" : "OFF"
                    color: NetworkService.wifiEnabled ? Theme.acidGreen : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                }

                MouseArea {
                    id: wifiToggleMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    preventStealing: true
                    onClicked: function (mouse) {
                        mouse.accepted = true;
                        NetworkService.toggleWifi();
                    }
                }
            }
        }

        Component {
            id: btHeaderAction

            Rectangle {
                id: btToggleBtn
                width: 60
                height: 24
                color: BluetoothService.powered ? Theme.surfaceSelected : (btToggleMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: BluetoothService.powered ? Theme.acidGreen : Theme.borderMuted
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: BluetoothService.powered ? "ON" : "OFF"
                    color: BluetoothService.powered ? Theme.acidGreen : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                }

                MouseArea {
                    id: btToggleMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    preventStealing: true
                    onClicked: function (mouse) {
                        mouse.accepted = true;
                        BluetoothService.togglePower();
                    }
                }
            }
        }

        Component {
            id: audioHeaderAction

            Rectangle {
                id: audioToggleBtn
                width: 70
                height: 24
                color: AudioService.muted ? Theme.surfaceSelected : (audioToggleMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: AudioService.muted ? Theme.warningRed : Theme.acidGreen
                border.width: Theme.borderWidth
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    text: AudioService.muted ? "MUTED" : "UNMUTE"
                    color: AudioService.muted ? Theme.destructive : Theme.acidGreen
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                }

                MouseArea {
                    id: audioToggleMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    preventStealing: true
                    onClicked: function (mouse) {
                        mouse.accepted = true;
                        AudioService.toggleMute();
                    }
                }
            }
        }

        Column {
            id: mainLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
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

            // 1. Calendar Accordion
            AccordionSection {
                id: secCalendar
                width: parent ? parent.width : undefined
                title: "// CALENDAR"
                icon: "timer"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "calendar"
                onHeaderClicked: panelContainer.toggleAccordion("calendar")

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: calPopup.implicitHeight
                        height: calPopup.implicitHeight

                        CalendarPopup {
                            id: calPopup
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent ? Math.min(300, parent.width) : 300
                            onCloseRequested: panelContainer.toggleAccordion("calendar")
                        }
                    }
                }
            }

            // 2. Notifications Accordion
            AccordionSection {
                id: secNotifications
                width: parent ? parent.width : undefined
                title: "// EVENT LOG"
                icon: "warning"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "notifications"
                onHeaderClicked: panelContainer.toggleAccordion("notifications")
                headerAction: dndHeaderAction

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: 320
                        height: 320

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingSmall

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

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
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.borderWidth
                color: Theme.borderMuted
            }

            // Footer Action Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

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
                }
            }

            // 3. Wi-Fi Accordion
            AccordionSection {
                id: secWifi
                width: parent ? parent.width : undefined
                title: "// WI-FI"
                icon: "wifi"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "wifi"
                onHeaderClicked: panelContainer.toggleAccordion("wifi")
                headerAction: wifiHeaderAction

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: 350
                        height: 350

                        ColumnLayout {
                            anchors.fill: parent

                                // Status Subheader
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
                text: NetworkService.wifiEnabled ? "// AVAILABLE NETWORKS" : "// WI-FI ADAPTER OFF"
            }

            Text {
                color: NetworkService.isConnecting ? Theme.accent : Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: NetworkService.isConnecting ? Theme.fontWeightBold : Theme.fontWeightNormal
                text: {
                    if (!NetworkService.wifiEnabled) return "STANDBY";
                    if (NetworkService.isConnecting) return "CONNECTING...";
                    return NetworkService.availableNetworks ? NetworkService.availableNetworks.length + " FOUND" : "SCANNING...";
                }
            }
        }

        // Active Connection Status Banner (Tier 2 Dedicated Banner)
        Rectangle {
            id: connectingBanner
            visible: NetworkService.isConnecting
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Theme.surfaceSelected
            border.color: Theme.accent
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium
                spacing: Theme.spacingSmall

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
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: "CONNECTING TO " + (NetworkService.connectingSsid !== "" ? NetworkService.connectingSsid.toUpperCase() : "NETWORK") + "..."
                    elide: Text.ElideRight
                }
            }
        }

        // Connection Error Notice Banner
        Rectangle {
            id: connectionErrorBanner
            visible: !NetworkService.isConnecting && NetworkService.lastError !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Theme.surface
            border.color: Theme.warningRed
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium
                spacing: Theme.spacingSmall

                CtosIcon {
                    name: "warning"
                    size: 14
                    color: Theme.warningRed
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.warningRed
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "FAILED: " + NetworkService.lastError.toUpperCase()
                    elide: Text.ElideRight
                }
            }
        }

        // Scrollable List of Available SSIDs
        Rectangle {
            id: networkListContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.gray800 // Near-black
            border.color: Theme.borderMuted
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall
            clip: true

            // Placeholder when disabled or empty
            Text {
                anchors.centerIn: parent
                visible: !NetworkService.wifiEnabled || !NetworkService.availableNetworks || NetworkService.availableNetworks.length === 0
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                text: !NetworkService.wifiEnabled ? "WI-FI IS DISABLED\nUSE [ENABLE WI-FI] ABOVE" : "SCANNING NETWORKS..."
            }

            ListView {
                id: networkListView
                anchors.fill: parent
                anchors.margins: Theme.paddingSmall
                spacing: Theme.spacingSmall
                clip: true
                model: NetworkService.wifiEnabled ? NetworkService.availableNetworks : []

                delegate: ColumnLayout {
                    id: networkItemDelegate
                    required property var modelData
                    width: networkListView.width
                    spacing: 2

                    readonly property var netData: modelData
                    readonly property string itemSsid: (netData && netData.ssid) ? netData.ssid : ""
                    readonly property real itemStrength: (netData && typeof netData.signalStrength === "number") ? netData.signalStrength : 0.0
                    readonly property bool itemIsKnown: Boolean(netData && (netData.known || netData.isKnown || netData.saved))
                    readonly property bool itemIsConnected: Boolean(netData && (netData.connected || netData.isConnected)) || (NetworkService.networkName === itemSsid && NetworkService.networkName !== "--N/A--" && NetworkService.networkName !== "")
                    readonly property bool itemIsConnecting: Boolean(NetworkService.connectingSsid !== "" && (NetworkService.connectingSsid === itemSsid || (netData && NetworkService.connectingSsid === netData.rawSsid)))
                    readonly property bool isSelected: root.selectedSsid === itemSsid
                    readonly property bool showPasswordPrompt: isSelected && !itemIsKnown && !itemIsConnected
                    readonly property bool showConnectedActions: isSelected && itemIsConnected
                    readonly property bool showKnownActions: isSelected && itemIsKnown && !itemIsConnected
                    readonly property bool isConfirmingForget: root.confirmingForgetSsid === itemSsid
                    readonly property bool isExpanded: showPasswordPrompt

                    // Main Network Entry Tile
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        border.color: itemIsConnected ? Theme.acidGreen : (itemIsConnecting ? Theme.accent : (itemMouseArea.containsMouse ? Theme.accent : Theme.borderMuted))
                        border.width: Theme.borderWidth
                        color: itemIsConnected ? Theme.surfaceSelected : (itemIsConnecting ? Theme.surfaceSelected : (itemMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface))
                        radius: Theme.radiusSmall

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.paddingSmall
                            spacing: Theme.spacingSmall

                            CtosIcon {
                                active: itemIsConnected || itemIsConnecting
                                name: "wifi"
                                size: 14
                                color: (itemIsConnected || itemIsConnecting) ? Theme.acidGreen : (itemMouseArea.containsMouse ? Theme.accent : Theme.textSecondary)
                            }

                            Text {
                                Layout.fillWidth: true
                                color: (itemIsConnected || itemIsConnecting) ? Theme.acidGreen : Theme.textPrimary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: (itemIsConnected || itemIsConnecting) ? Theme.fontWeightBold : Theme.fontWeightNormal
                                text: itemSsid !== "" ? itemSsid : "[HIDDEN NETWORK]"
                            }

                            // Saved Badge
                            Rectangle {
                                visible: itemIsKnown && !itemIsConnected && !itemIsConnecting
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: 46
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: 1
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.accent
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "SAVED"
                                }
                            }

                            // Connecting Badge (Tier 3)
                            Rectangle {
                                visible: itemIsConnecting
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: 88
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: 1
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.accent
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "[CONNECTING...]"
                                }
                            }

                            // Signal Strength Percentage
                            Text {
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                text: Math.round(itemStrength <= 1.0 ? itemStrength * 100 : itemStrength) + "%"
                            }

                            // Connected Badge
                            Text {
                                visible: itemIsConnected
                                color: Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: "[CONNECTED]"
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                if (root.selectedSsid === itemSsid) {
                                    root.selectedSsid = "";
                                    root.confirmingForgetSsid = "";
                                } else {
                                    root.selectedSsid = itemSsid;
                                    root.confirmingForgetSsid = "";
                                }
                            }
                        }
                    }

                    // Connected Network Action Drawer
                    Rectangle {
                        id: connectedActionsBox
                        visible: showConnectedActions
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: Theme.gray900
                        border.color: Theme.warningRed
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.rightMargin: Theme.paddingMedium
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                text: "// ACTIVE CONNECTION"
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 84
                                border.color: Theme.warningRed
                                border.width: Theme.borderWidth
                                color: disconnectMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.warningRed
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "DISCONNECT"
                                }

                                MouseArea {
                                    id: disconnectMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        NetworkService.disconnectCurrentNetwork();
                                        root.selectedSsid = "";
                                    }
                                }
                            }
                        }
                    }

                    // Saved/Known Network Management Drawer
                    Rectangle {
                        id: knownActionsBox
                        visible: showKnownActions
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: Theme.gray900
                        border.color: isConfirmingForget ? Theme.warningRed : Theme.accent
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        // Normal Actions: [CONNECT] and [FORGET]
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.rightMargin: Theme.paddingMedium
                            spacing: Theme.spacingSmall
                            visible: !isConfirmingForget

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                text: "// SAVED PROFILE"
                            }

                            // Connect Button
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: itemIsConnecting ? 92 : 68
                                border.color: itemIsConnecting ? Theme.accent : Theme.acidGreen
                                border.width: Theme.borderWidth
                                color: itemIsConnecting ? Theme.surfaceSelected : (knownConnectMouseArea.containsMouse ? Theme.surfaceSelected : "transparent")
                                radius: Theme.radiusSmall
                                opacity: (NetworkService.isConnecting && !itemIsConnecting) ? 0.5 : 1.0

                                Text {
                                    anchors.centerIn: parent
                                    color: itemIsConnecting ? Theme.accent : Theme.acidGreen
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: itemIsConnecting ? "CONNECTING..." : "CONNECT"
                                }

                                MouseArea {
                                    id: knownConnectMouseArea
                                    anchors.fill: parent
                                    cursorShape: itemIsConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    hoverEnabled: !itemIsConnecting
                                    enabled: !NetworkService.isConnecting
                                    onClicked: {
                                        NetworkService.connectToNetwork(itemSsid);
                                        root.selectedSsid = "";
                                    }
                                }
                            }

                            // Forget Button
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 62
                                border.color: Theme.warningRed
                                border.width: Theme.borderWidth
                                color: forgetMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.warningRed
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "FORGET"
                                }

                                MouseArea {
                                    id: forgetMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        root.confirmingForgetSsid = itemSsid;
                                    }
                                }
                            }
                        }

                        // Inline Confirmation Prompt: "FORGET <SSID>? [YES] [NO]"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingMedium
                            anchors.rightMargin: Theme.paddingMedium
                            spacing: Theme.spacingSmall
                            visible: isConfirmingForget

                            Text {
                                Layout.fillWidth: true
                                color: Theme.warningRed
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: 9
                                font.weight: Theme.fontWeightBold
                                text: "FORGET " + itemSsid + "?"
                            }

                            // YES Button
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 42
                                border.color: Theme.warningRed
                                border.width: Theme.borderWidth
                                color: forgetYesMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.warningRed
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "YES"
                                }

                                MouseArea {
                                    id: forgetYesMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        NetworkService.forgetNetwork(itemSsid);
                                        root.confirmingForgetSsid = "";
                                        root.selectedSsid = "";
                                    }
                                }
                            }

                            // NO Button
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 42
                                border.color: Theme.borderMuted
                                border.width: Theme.borderWidth
                                color: forgetNoMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                radius: Theme.radiusSmall

                                Text {
                                    anchors.centerIn: parent
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    font.weight: Theme.fontWeightBold
                                    text: "NO"
                                }

                                MouseArea {
                                    id: forgetNoMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        root.confirmingForgetSsid = "";
                                    }
                                }
                            }
                        }
                    }

                    // Inline Password Prompt (Terminal Prompt directly in the Rail)
                    Rectangle {
                        id: passwordPromptBox
                        visible: isExpanded
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: Theme.gray900
                        border.color: Theme.acidGreen
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.paddingSmall
                            spacing: Theme.spacingSmall

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall

                                Text {
                                    color: Theme.acidGreen
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                    text: "PASSWORD >_"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    color: Theme.gray800
                                    border.color: pwInput.activeFocus ? Theme.acidGreen : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    radius: Theme.radiusSmall

                                    TextInput {
                                        id: pwInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Theme.textPrimary
                                        echoMode: TextInput.Password
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        focus: isExpanded
                                        selectByMouse: true

                                        onAccepted: {
                                            if (pwInput.text.trim() === "" || pwInput.text.length === 0) {
                                                return;
                                            }
                                            NetworkService.connectToNetwork(itemSsid, pwInput.text);
                                            root.selectedSsid = "";
                                            pwInput.text = "";
                                        }

                                        Keys.onEscapePressed: function (event) {
                                            root.selectedSsid = "";
                                            pwInput.text = "";
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 9
                                    text: "[ENTER] Connect  [ESC] Cancel"
                                }

                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: itemIsConnecting ? 92 : 62
                                    border.color: itemIsConnecting ? Theme.accent : Theme.acidGreen
                                    border.width: Theme.borderWidth
                                    color: itemIsConnecting ? Theme.surfaceSelected : (pwConnectArea.containsMouse ? Theme.surfaceSelected : "transparent")
                                    radius: Theme.radiusSmall
                                    opacity: (NetworkService.isConnecting && !itemIsConnecting) ? 0.5 : 1.0

                                    Text {
                                        anchors.centerIn: parent
                                        color: itemIsConnecting ? Theme.accent : Theme.acidGreen
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: 9
                                        font.weight: Theme.fontWeightBold
                                        text: itemIsConnecting ? "CONNECTING..." : "CONNECT"
                                    }

                                    MouseArea {
                                        id: pwConnectArea
                                        anchors.fill: parent
                                        cursorShape: itemIsConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        hoverEnabled: !itemIsConnecting
                                        enabled: !NetworkService.isConnecting
                                        onClicked: {
                                            if (pwInput.text.trim() === "" || pwInput.text.length === 0) {
                                                return;
                                            }
                                            NetworkService.connectToNetwork(itemSsid, pwInput.text);
                                            root.selectedSsid = "";
                                            pwInput.text = "";
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

                        }
                    }
                }
            }

            // 4. Bluetooth Accordion
            AccordionSection {
                id: secBluetooth
                width: parent ? parent.width : undefined
                title: "// BLUETOOTH"
                icon: "bluetooth"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "bluetooth"
                onHeaderClicked: panelContainer.toggleAccordion("bluetooth")
                headerAction: btHeaderAction

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: 320
                        height: 320

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingSmall

                        // Status Subheader with Scan Button
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: !BluetoothService.powered
                                      ? "// BLUETOOTH ADAPTER OFF"
                                      : (BluetoothService.isScanning ? "// SCANNING FOR DEVICES..." : "// BLUETOOTH DEVICES")
                            }

                            Rectangle {
                                id: btScanBtn
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: btScanLabel.implicitWidth + Theme.paddingSmall * 2
                                border.color: !BluetoothService.powered ? Theme.borderMuted : (BluetoothService.isScanning ? Theme.accent : (btScanMouse.containsMouse ? Theme.accent : Theme.borderMuted))
                                border.width: Theme.borderWidth
                                color: BluetoothService.isScanning ? Theme.surfaceSelected : (btScanMouse.containsMouse ? Theme.surfaceHover : "transparent")
                                radius: Theme.radiusSmall
                                opacity: BluetoothService.powered ? 1.0 : 0.4

                                Text {
                                    id: btScanLabel
                                    anchors.centerIn: parent
                                    color: !BluetoothService.powered ? Theme.textMuted : (BluetoothService.isScanning ? Theme.accent : (btScanMouse.containsMouse ? Theme.accent : Theme.textSecondary))
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: 10
                                    font.weight: Theme.fontWeightBold
                                    text: BluetoothService.isScanning ? "[SCANNING]" : "[SCAN]"
                                }

                                MouseArea {
                                    id: btScanMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    enabled: BluetoothService.powered
                                    onClicked: BluetoothService.toggleScan()
                                }
                            }
                        }

                        // Scrollable Device List Container
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Theme.gray800
                            border.color: Theme.borderMuted
                            border.width: Theme.borderWidth
                            radius: Theme.radiusSmall
                            clip: true

                            // Empty State: Powered Off
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingSmall
                                visible: !BluetoothService.powered

                                CtosIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    size: 24
                                    name: "bluetooth-slash"
                                    color: Theme.textMuted
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "// BLUETOOTH RADIO OFF\nUSE [ON] TOGGLE ABOVE"
                                }
                            }

                            // Empty State: Powered On, No Devices
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingSmall
                                visible: {
                                    const devCount = BluetoothService.devices ? (BluetoothService.devices.count || BluetoothService.devices.length || 0) : 0;
                                    return BluetoothService.powered && devCount === 0;
                                }

                                CtosIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    size: 24
                                    name: "bluetooth"
                                    color: BluetoothService.isScanning ? Theme.acidGreen : Theme.textMuted
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    color: BluetoothService.isScanning ? Theme.acidGreen : Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    horizontalAlignment: Text.AlignHCenter
                                    text: BluetoothService.isScanning ? "// SCANNING FOR NEARBY DEVICES..." : "// NO DEVICES FOUND\nCLICK [SCAN] TO DISCOVER"
                                }
                            }

                            // Scrollable list when devices present
                            Flickable {
                                anchors.fill: parent
                                anchors.margins: Theme.paddingSmall
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                contentHeight: btDeviceListColumn.implicitHeight
                                contentWidth: width
                                visible: {
                                    const devCount = BluetoothService.devices ? (BluetoothService.devices.count || BluetoothService.devices.length || 0) : 0;
                                    return BluetoothService.powered && devCount > 0;
                                }

                                ColumnLayout {
                                    id: btDeviceListColumn
                                    width: parent.width
                                    spacing: Theme.spacingSmall

                                    // Paired Devices
                                    Repeater {
                                        model: BluetoothService.pairedDevices

                                        delegate: Rectangle {
                                            id: btPairedTile
                                            required property var modelData

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 38
                                            color: btPairedMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                            border.color: Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            radius: Theme.radiusSmall

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.paddingSmall
                                                spacing: Theme.spacingSmall

                                                CtosIcon {
                                                    size: 14
                                                    name: "bluetooth"
                                                    color: btPairedTile.modelData.connected ? Theme.acidGreen : Theme.textSecondary
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: btPairedTile.modelData.connected ? Theme.acidGreen : Theme.textPrimary
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: Theme.fontSizeCaption
                                                        font.weight: Theme.fontWeightBold
                                                        text: btPairedTile.modelData.name || "Device"
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: Theme.textMuted
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: 9
                                                        text: btPairedTile.modelData.mac + (btPairedTile.modelData.connected ? " // CONNECTED" : " // PAIRED")
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: 20
                                                    Layout.preferredWidth: btActionText.implicitWidth + Theme.paddingSmall * 2
                                                    border.color: Theme.borderMuted
                                                    border.width: Theme.borderWidth
                                                    color: btActionMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                                    radius: Theme.radiusSmall

                                                    Text {
                                                        id: btActionText
                                                        anchors.centerIn: parent
                                                        color: btActionMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: 9
                                                        font.weight: Theme.fontWeightBold
                                                        text: btPairedTile.modelData.connected ? "[DISCONNECT]" : "[CONNECT]"
                                                    }

                                                    MouseArea {
                                                        id: btActionMouse
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            if (btPairedTile.modelData.connected) {
                                                                BluetoothService.disconnectDevice(btPairedTile.modelData.mac);
                                                            } else {
                                                                BluetoothService.connectDevice(btPairedTile.modelData.mac);
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: btPairedMouse
                                                anchors.fill: parent
                                                z: -1
                                                hoverEnabled: true
                                            }
                                        }
                                    }

                                    // Available Devices
                                    Repeater {
                                        model: BluetoothService.availableDevices

                                        delegate: Rectangle {
                                            id: btAvailTile
                                            required property var modelData

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 38
                                            color: btAvailMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                            border.color: Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            radius: Theme.radiusSmall

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.paddingSmall
                                                spacing: Theme.spacingSmall

                                                CtosIcon {
                                                    size: 14
                                                    name: "bluetooth"
                                                    color: Theme.textSecondary
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: Theme.textPrimary
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: Theme.fontSizeCaption
                                                        font.weight: Theme.fontWeightBold
                                                        text: btAvailTile.modelData.name || "Device"
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: Theme.textMuted
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: 9
                                                        text: btAvailTile.modelData.mac
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: 20
                                                    Layout.preferredWidth: btPairText.implicitWidth + Theme.paddingSmall * 2
                                                    border.color: Theme.borderMuted
                                                    border.width: Theme.borderWidth
                                                    color: btPairMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                                    radius: Theme.radiusSmall

                                                    Text {
                                                        id: btPairText
                                                        anchors.centerIn: parent
                                                        color: btPairMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                        font.family: Theme.fontFamilyMonospace
                                                        font.pixelSize: 9
                                                        font.weight: Theme.fontWeightBold
                                                        text: "[PAIR]"
                                                    }

                                                    MouseArea {
                                                        id: btPairMouse
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        hoverEnabled: true
                                                        onClicked: BluetoothService.pairDevice(btAvailTile.modelData.mac)
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: btAvailMouse
                                                anchors.fill: parent
                                                z: -1
                                                hoverEnabled: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }
                    }
                }
            }

            // 5. Audio Accordion
            AccordionSection {
                id: secAudio
                width: parent ? parent.width : undefined
                title: "// AUDIO & MEDIA"
                icon: "volume"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "audio"
                onHeaderClicked: panelContainer.toggleAccordion("audio")
                headerAction: audioHeaderAction

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: 360
                        height: 360

                        Flickable {
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentHeight: audioColumn.implicitHeight
                            contentWidth: width

                            ColumnLayout {
                                id: audioColumn
                                width: parent.width
                                spacing: Theme.spacingMedium

                                ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                CtosIcon {
                    active: !AudioService.muted && AudioService.available
                    destructive: AudioService.muted
                    name: AudioService.muted ? "volume-mute" : "volume"
                    size: 16
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    text: "OUTPUT AUDIO"
                }

                Text {
                    color: AudioService.muted ? Theme.destructive : (AudioService.available ? Theme.accent : Theme.unavailable)
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: !AudioService.available ? "--N/A--" : (AudioService.muted ? "[MUTED]" : Math.round(AudioService.volume * 100) + "%")
                }
            }

            // Output Volume Slider & Mute Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Rectangle {
                    id: volumeTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    border.color: Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: Theme.gray700
                    radius: Theme.radiusSmall

                    Rectangle {
                        id: volumeFill
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        color: AudioService.muted ? Theme.destructive : Theme.acidGreen
                        radius: Theme.radiusSmall
                        width: Math.max(0, Math.min(parent.width, parent.width * AudioService.volume))
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        function updateFromMouse(mouseX) {
                            const ratio = mouseX / volumeTrack.width;
                            AudioService.setVolume(ratio);
                        }

                        onPressed: function (mouse) {
                            updateFromMouse(mouse.x);
                        }
                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                updateFromMouse(mouse.x);
                            }
                        }
                        onWheel: function (wheel) {
                            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            AudioService.stepVolume(delta);
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 60
                    border.color: volMuteArea.containsMouse ? Theme.accent : Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: AudioService.muted ? Theme.surfaceSelected : (volMuteArea.containsMouse ? Theme.surfaceHover : "transparent")
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        color: AudioService.muted ? Theme.destructive : Theme.textPrimary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightMedium
                        text: AudioService.muted ? "UNMUTE" : "MUTE"
                    }

                    MouseArea {
                        id: volMuteArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: AudioService.toggleMute()
                    }
                }
            }
        }

        // Section: Hardware Microphone (Feature 9)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                CtosIcon {
                    active: !AudioService.micMuted && AudioService.micAvailable
                    destructive: AudioService.micMuted
                    name: AudioService.micMuted ? "microphone-slash" : "microphone"
                    size: 16
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    text: "MICROPHONE"
                }

                Text {
                    color: AudioService.micMuted ? Theme.destructive : (AudioService.micAvailable ? Theme.accent : Theme.unavailable)
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: !AudioService.micAvailable ? "--N/A--" : (AudioService.micMuted ? "[MUTED]" : Math.round(AudioService.micVolume * 100) + "%")
                }
            }

            // Mic Slider & Mute Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Rectangle {
                    id: micTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    border.color: Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: Theme.gray700
                    radius: Theme.radiusSmall

                    Rectangle {
                        id: micFill
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        color: AudioService.micMuted ? Theme.destructive : Theme.acidGreen
                        radius: Theme.radiusSmall
                        width: Math.max(0, Math.min(parent.width, parent.width * AudioService.micVolume))
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        function updateFromMouse(mouseX) {
                            const ratio = mouseX / micTrack.width;
                            AudioService.setMicVolume(ratio);
                        }

                        onPressed: function (mouse) {
                            updateFromMouse(mouse.x);
                        }
                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                updateFromMouse(mouse.x);
                            }
                        }
                        onWheel: function (wheel) {
                            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            AudioService.stepMicVolume(delta);
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 60
                    border.color: micMuteArea.containsMouse ? Theme.accent : Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: AudioService.micMuted ? Theme.surfaceSelected : (micMuteArea.containsMouse ? Theme.surfaceHover : "transparent")
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        color: AudioService.micMuted ? Theme.destructive : Theme.textPrimary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightMedium
                        text: AudioService.micMuted ? "UNMUTE" : "MUTE"
                    }

                    MouseArea {
                        id: micMuteArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: AudioService.toggleMicMute()
                    }
                }
            }
        }
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

                            }
                        }
                    }
                }
            }

            // 6. Power Accordion
            AccordionSection {
                id: secPower
                width: parent ? parent.width : undefined
                title: "// POWER & SESSION"
                icon: "power"
                autoToggle: false
                isExpanded: panelContainer.activeAccordion === "power"
                onHeaderClicked: panelContainer.toggleAccordion("power")

                contentComponent: Component {
                    Item {
                        width: parent ? parent.width : undefined
                        implicitHeight: root.isConfirming ? 250 : 210
                        height: root.isConfirming ? 250 : 210

                        Behavior on height {
                            NumberAnimation {
                                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                                easing.type: Easing.InOutQuad
                            }
                        }

                        // Normal state: Session Actions + Battery
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingSmall
                            visible: !root.isConfirming

                            // Battery status (visible when battery present)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall
                                visible: PowerService.available && PowerService.isBatteryPresent

                                RowLayout {
                                    Layout.fillWidth: true

                                    CtosIcon {
                                        active: PowerService.isCharging
                                        destructive: !PowerService.isCharging && PowerService.percentage <= 20
                                        name: PowerService.isCharging ? "battery-charging" : (PowerService.percentage <= 20 ? "battery-low" : "battery")
                                        size: 16
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                        text: "POWER STATUS"
                                    }

                                    Text {
                                        color: PowerService.percentage <= 20 ? Theme.destructive : (PowerService.isCharging ? Theme.accent : Theme.textPrimary)
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightBold
                                        text: Math.round(PowerService.percentage) + "% // " + PowerService.stateText
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    border.color: Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: Theme.gray700
                                    radius: Theme.radiusSmall

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        color: PowerService.percentage <= 20 ? Theme.destructive : Theme.acidGreen
                                        radius: Theme.radiusSmall
                                        width: Math.max(0, Math.min(parent.width, parent.width * (PowerService.percentage / 100.0)))
                                    }
                                }
                            }

                            Text {
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: "// SESSION ACTIONS"
                            }

                            // Immediate Lock Session Action
                            Rectangle {
                                id: btnLockSession
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                border.color: lockMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                color: lockMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                radius: Theme.radiusSmall

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXs

                                    CtosIcon {
                                        name: "lock"
                                        size: 14
                                    }

                                    Text {
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Theme.fontWeightMedium
                                        text: "LOCK SESSION"
                                    }
                                }

                                MouseArea {
                                    id: lockMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: lockProcess.running = true
                                }
                            }

                            // Destructive Session Actions Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall

                                // Logout
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    border.color: logoutMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: logoutMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                    radius: Theme.radiusSmall

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXs

                                        CtosIcon {
                                            name: "logout"
                                            size: 14
                                        }

                                        Text {
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightMedium
                                            text: "LOGOUT"
                                        }
                                    }

                                    MouseArea {
                                        id: logoutMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.triggerConfirmation("logout")
                                    }
                                }

                                // Reboot
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    border.color: rebootMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: rebootMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                    radius: Theme.radiusSmall

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXs

                                        CtosIcon {
                                            name: "reboot"
                                            size: 14
                                        }

                                        Text {
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightMedium
                                            text: "REBOOT"
                                        }
                                    }

                                    MouseArea {
                                        id: rebootMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.triggerConfirmation("reboot")
                                    }
                                }

                                // Power Off
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    border.color: powerMouseArea.containsMouse ? Theme.destructive : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: powerMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                    radius: Theme.radiusSmall

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXs

                                        CtosIcon {
                                            destructive: powerMouseArea.containsMouse
                                            name: "power"
                                            size: 14
                                        }

                                        Text {
                                            color: powerMouseArea.containsMouse ? Theme.destructive : Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightMedium
                                            text: "POWER"
                                        }
                                    }

                                    MouseArea {
                                        id: powerMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.triggerConfirmation("poweroff")
                                    }
                                }
                            }

                            // Floating Radial Settings Node Access
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: radialMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                border.color: radialMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingSmall

                                    CtosIcon {
                                        name: "settings"
                                        size: 14
                                        color: Theme.textSecondary
                                    }

                                    Text {
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightBold
                                        text: "OPEN RADIAL SETTINGS // TELEMETRY"
                                    }
                                }

                                MouseArea {
                                    id: radialMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        OverlayController.openRadialSettings();
                                    }
                                }
                            }
                        }

                        // Confirmation state
                        ColumnLayout {
                            id: confirmationLayout
                            anchors.fill: parent
                            anchors.margins: Theme.paddingLarge
                            spacing: Theme.spacingMedium
                            visible: root.isConfirming

                            CtosIcon {
                                Layout.alignment: Qt.AlignHCenter
                                destructive: true
                                name: "warning"
                                size: 32
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.destructive
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Theme.fontWeightBold
                                horizontalAlignment: Text.AlignHCenter
                                text: "CRITICAL // CONFIRM " + root.confirmationAction.toUpperCase()
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                horizontalAlignment: Text.AlignHCenter
                                text: "WARNING: SYSTEM WILL TERMINATE ALL ACTIVE PROCESSES. ANY UNSAVED DATA WILL BE LOST."
                                wrapMode: Text.WordWrap
                            }

                            // Explicit Action Buttons
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingMedium

                                // Cancel Button
                                Rectangle {
                                    id: btnCancel
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    border.color: cancelMouseArea.containsMouse ? Theme.textPrimary : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: cancelMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                    radius: Theme.radiusSmall

                                    Text {
                                        anchors.centerIn: parent
                                        color: Theme.textPrimary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightBold
                                        text: "[ ESC ] CANCEL"
                                    }

                                    MouseArea {
                                        id: cancelMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.cancelConfirmation()
                                    }
                                }

                                // Confirm Button
                                Rectangle {
                                    id: btnConfirm
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: confirmMouseArea.containsMouse ? Theme.surfaceHover : Theme.destructive
                                    radius: Theme.radiusSmall

                                    Text {
                                        anchors.centerIn: parent
                                        color: Theme.gray900
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightBold
                                        text: "CONFIRM // EXECUTE"
                                    }

                                    MouseArea {
                                        id: confirmMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: root.executeConfirmation()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
