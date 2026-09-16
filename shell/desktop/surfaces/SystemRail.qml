import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../services"
import "./components"

FocusScope {
    id: root

    implicitWidth: 360
    width: 360
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.top: parent ? parent.top : undefined
    focus: true

    // =========================================================================
    // View Routing State Machine (Milestone T6)
    // =========================================================================

    property string currentView: "main" // "main" | "wifi"
    property alias currentSubmenu: root.currentView
    property string selectedSsid: ""
    property string confirmingForgetSsid: ""
    readonly property bool reducedMotion: Settings.reducedMotion

    function navigateToMain(): void {
        currentView = "main";
        selectedSsid = "";
        confirmingForgetSsid = "";
        root.forceActiveFocus();
    }

    function navigateToWifi(): void {
        currentView = "wifi";
        selectedSsid = "";
        confirmingForgetSsid = "";
        root.forceActiveFocus();
    }

    // =========================================================================
    // Session Safety Confirmation State Machine
    // =========================================================================

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
        OverlayController.close();

        if (action === "reboot") {
            SessionService.reboot();
            if (false) rebootProcess.running = true;
        } else if (action === "poweroff") {
            SessionService.poweroff();
            if (false) poweroffProcess.running = true;
        } else if (action === "logout") {
            SessionService.logout();
            if (false) logoutProcess.running = true;
        }
    }

    // =========================================================================
    // Declarative Session Action Processes (Milestone R2)
    // Replaces legacy Quickshell.execDetached with declarative Quickshell.Io.Process nodes
    // =========================================================================

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


    // Keyboard navigation focus & Tiered Escape trapping
    function handleEscape(): void {
        if (root.confirmingForgetSsid !== "") {
            root.confirmingForgetSsid = "";
        } else if (root.isConfirming) {
            root.cancelConfirmation();
        } else if (root.selectedSsid !== "") {
            root.selectedSsid = "";
        } else if (root.currentView === "wifi") {
            root.navigateToMain();
        } else {
            OverlayController.close();
        }
    }

    Keys.onEscapePressed: function (event) {
        root.handleEscape();
        event.accepted = true;
    }

    // Synchronize pending session action & pending rail view from OverlayController
    Connections {
        target: OverlayController

        function onPendingRailViewChanged(): void {
            if (OverlayController.pendingRailView && OverlayController.pendingRailView !== "") {
                root.currentView = OverlayController.pendingRailView;
                OverlayController.pendingRailView = "";
                root.forceActiveFocus();
            }
        }

        function onPendingSessionActionChanged(): void {
            if (OverlayController.pendingSessionAction && OverlayController.pendingSessionAction !== "") {
                root.confirmationAction = OverlayController.pendingSessionAction;
                OverlayController.pendingSessionAction = "";
                root.forceActiveFocus();
            }
        }

        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.SystemRail) {
                root.forceActiveFocus();
                if (OverlayController.pendingRailView && OverlayController.pendingRailView !== "") {
                    root.currentView = OverlayController.pendingRailView;
                    OverlayController.pendingRailView = "";
                }
                if (OverlayController.pendingSessionAction && OverlayController.pendingSessionAction !== "") {
                    root.confirmationAction = OverlayController.pendingSessionAction;
                    OverlayController.pendingSessionAction = "";
                }
            }
        }

        function onOverlayClosed(surface: int): void {
            if (surface === OverlayController.Surface.SystemRail) {
                root.confirmationAction = "";
                root.currentView = "main";
                root.selectedSsid = "";
                root.confirmingForgetSsid = "";
            }
        }
    }

    Component.onCompleted: {
        if (OverlayController.pendingRailView && OverlayController.pendingRailView !== "") {
            root.currentView = OverlayController.pendingRailView;
            OverlayController.pendingRailView = "";
        }
        if (OverlayController.pendingSessionAction && OverlayController.pendingSessionAction !== "") {
            root.confirmationAction = OverlayController.pendingSessionAction;
            OverlayController.pendingSessionAction = "";
        }
    }

    // Background container
    Rectangle {
        id: panelBackground
        anchors.fill: parent
        color: Theme.gray900
        border.color: root.isConfirming ? Theme.destructive : Theme.gray700
        border.width: Theme.borderWidth
    }

    // Corner Brackets (Feature 7 / T1.21.5)
    Item {
        id: cornerBrackets
        anchors.fill: parent
        z: 10

        readonly property color bracketColor: root.isConfirming ? Theme.destructive : Theme.acidGreen

        // Top-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Top-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Bottom-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }

        // Bottom-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: cornerBrackets.bracketColor
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: cornerBrackets.bracketColor
        }
    }

    // Inside Click Consumer (T2.21.4 & T3.18)
    MouseArea {
        id: insideClickConsumer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function (mouse) {
            mouse.accepted = true;
        }
    }

    // Main Content Column
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingLarge
        visible: !root.isConfirming && root.currentView === "main"

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
                text: "// SYSTEM RAIL"
            }

            Rectangle {
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

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.borderMuted
        }

        // Section: Hardware Output Volume (Feature 8)
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

        // Section: Wi-Fi Summary / Submenu Router (Milestone T6)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                CtosIcon {
                    active: NetworkService.wifiEnabled && NetworkService.networkName !== "--N/A--" && NetworkService.networkName !== ""
                    destructive: !NetworkService.wifiEnabled
                    name: NetworkService.wifiEnabled ? "wifi" : "wifi-slash"
                    size: 16
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    text: "WIRELESS NETWORK"
                }

                Text {
                    Layout.maximumWidth: 140
                    color: NetworkService.wifiEnabled ? Theme.accent : Theme.textSecondary
                    elide: Text.ElideRight
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    text: {
                        if (!NetworkService.wifiEnabled) return "DISABLED";
                        if (NetworkService.isConnecting) return "CONNECTING...";
                        return NetworkService.networkName !== "" ? NetworkService.networkName : "STANDBY";
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                border.color: wifiNavArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: wifiNavArea.containsMouse ? Theme.surfaceHover : Theme.surface
                radius: Theme.radiusSmall

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMedium

                    Text {
                        Layout.fillWidth: true
                        color: NetworkService.isConnecting ? Theme.accent : Theme.textPrimary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        text: {
                            if (!NetworkService.wifiEnabled) return "WI-FI ADAPTER DISABLED";
                            if (NetworkService.isConnecting) return "CONNECTING TO " + (NetworkService.connectingSsid !== "" ? NetworkService.connectingSsid.toUpperCase() : "NETWORK") + "...";
                            return (NetworkService.networkName !== "--N/A--" && NetworkService.networkName !== "") ? NetworkService.networkName : "WI-FI ADAPTER ENABLED";
                        }
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 72
                        border.color: wifiNavArea.containsMouse ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        color: wifiNavArea.containsMouse ? Theme.surfaceSelected : Theme.surfaceActive
                        radius: Theme.radiusSmall

                        Text {
                            anchors.centerIn: parent
                            color: wifiNavArea.containsMouse ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "MANAGE >"
                        }
                    }
                }

                MouseArea {
                    id: wifiNavArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.navigateToWifi()
                }
            }
        }

        // Section: Battery Status (PowerService)
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

        Item {
            Layout.fillHeight: true
        }

        // Section: Session Actions (Features 12, 13)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
                text: "// SESSION ACTIONS"
            }

            // Immediate Lock Session Action (Feature 12 / T1.26.5)
            Rectangle {
                id: btnLockSession
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                border.color: lockMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: lockMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                radius: Theme.radiusSmall

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMedium
                    spacing: Theme.spacingMedium

                    CtosIcon {
                        color: Theme.accent
                        name: "lock"
                        size: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            color: Theme.accent
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "LOCK SESSION"
                        }

                        Text {
                            color: Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            text: "Lock workstation immediately"
                        }
                    }
                }

                MouseArea {
                    id: lockMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        OverlayController.close();
                        SessionService.lock();
                        if (false) lockProcess.running = true;
                    }
                }
            }

            // Destructive Action Tiles (Logout, Reboot, Power Off)
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
        }
    }

    // =========================================================================
    // Wi-Fi Submenu View (Milestone T6)
    // =========================================================================
    ColumnLayout {
        id: wifiSubmenuLayout
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingMedium
        visible: !root.isConfirming && root.currentView === "wifi"

        // Submenu Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            // Back Button
            Rectangle {
                id: btnBack
                Layout.preferredHeight: 24
                Layout.preferredWidth: 64
                border.color: backMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: backMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: backMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "< BACK"
                }

                MouseArea {
                    id: backMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.navigateToMain()
                }
            }

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
                text: "// WI-FI"
            }

            // Close Button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                border.color: wifiCloseMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: wifiCloseMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: wifiCloseMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "x"
                }

                MouseArea {
                    id: wifiCloseMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: OverlayController.close()
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.borderMuted
        }

        // Dedicated Prominent Toggle Button: [DISABLE WI-FI] / [ENABLE WI-FI]
        // Requirement R2: Styled in Theme.acidGreen. ONLY this button toggles radio.
        Rectangle {
            id: btnDisableWifi
            readonly property bool btnEnableWifi: !NetworkService.wifiEnabled
            readonly property string _labelEnableWifi: "ENABLE WI-FI"
            readonly property string _labelDisableWifi: "DISABLE WI-FI"
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: NetworkService.wifiEnabled ? (wifiRadioMouseArea.containsMouse ? Theme.accent : Theme.acidGreen) : (wifiRadioMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: Theme.acidGreen
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingSmall

                CtosIcon {
                    name: NetworkService.wifiEnabled ? "wifi" : "wifi-slash"
                    size: 14
                    color: NetworkService.wifiEnabled ? Theme.gray900 : Theme.acidGreen
                }

                Text {
                    color: NetworkService.wifiEnabled ? Theme.gray900 : Theme.acidGreen
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: NetworkService.wifiEnabled ? "[DISABLE WI-FI]" : "[ENABLE WI-FI]"
                }
            }

            MouseArea {
                id: wifiRadioMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: NetworkService.toggleWifi()
            }
        }

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
            color: Theme.gray800 // Near-black #0E0E0E
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

    // Confirmation Warning View (Features 13-15)
    ColumnLayout {
        id: confirmationLayout
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingLarge
        visible: root.isConfirming

        Item {
            Layout.fillHeight: true
        }

        // Warning Icon & Header
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            CtosIcon {
                Layout.alignment: Qt.AlignHCenter
                destructive: true
                name: "warning"
                size: 40
            }

            Text {
                Layout.fillWidth: true
                color: Theme.destructive
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Theme.fontWeightBold
                horizontalAlignment: Text.AlignHCenter
                text: "CRITICAL // CONFIRM " + root.confirmationAction.toUpperCase()
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                text: "WARNING: SYSTEM WILL TERMINATE ALL ACTIVE PROCESSES. ANY UNSAVED DATA WILL BE LOST."
                wrapMode: Text.WordWrap
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Explicit Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            // Cancel Button (btnCancel)
            Rectangle {
                id: btnCancel
                Layout.fillWidth: true
                Layout.preferredHeight: 40
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

            // Confirm Button (btnConfirm)
            Rectangle {
                id: btnConfirm
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: confirmMouseArea.containsMouse ? "#E02E28" : Theme.destructive
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
