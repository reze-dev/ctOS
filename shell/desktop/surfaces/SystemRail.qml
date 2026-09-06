import QtQuick
import QtQuick.Layouts
import Quickshell
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
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (action === "poweroff") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        } else if (action === "logout") {
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        }
    }

    // Keyboard navigation focus & Escape trapping
    Keys.onEscapePressed: function (event) {
        if (root.isConfirming) {
            root.cancelConfirmation();
            event.accepted = true;
        } else {
            OverlayController.close();
            event.accepted = true;
        }
    }

    // Synchronize pending session action from OverlayController
    Connections {
        target: OverlayController

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
                if (OverlayController.pendingSessionAction && OverlayController.pendingSessionAction !== "") {
                    root.confirmationAction = OverlayController.pendingSessionAction;
                    OverlayController.pendingSessionAction = "";
                }
            }
        }

        function onOverlayClosed(surface: int): void {
            if (surface === OverlayController.Surface.SystemRail) {
                root.confirmationAction = "";
            }
        }
    }

    Component.onCompleted: {
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
        visible: !root.isConfirming

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

        // Section: Wi-Fi Controls (Feature 10)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                CtosIcon {
                    active: NetworkService.wifiEnabled && NetworkService.networkName !== "--N/A--"
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
                    text: NetworkService.wifiEnabled ? (NetworkService.networkName !== "" ? NetworkService.networkName : "STANDBY") : "DISABLED"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                border.color: wifiToggleArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: wifiToggleArea.containsMouse ? Theme.surfaceHover : Theme.surface
                radius: Theme.radiusSmall

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMedium

                    Text {
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        text: NetworkService.wifiEnabled ? "WI-FI ADAPTER ENABLED" : "WI-FI ADAPTER DISABLED"
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 64
                        border.color: NetworkService.wifiEnabled ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        color: NetworkService.wifiEnabled ? Theme.surfaceSelected : Theme.surfaceActive
                        radius: Theme.radiusSmall

                        Text {
                            anchors.centerIn: parent
                            color: NetworkService.wifiEnabled ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: NetworkService.wifiEnabled ? "DISABLE" : "ENABLE"
                        }
                    }
                }

                MouseArea {
                    id: wifiToggleArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: NetworkService.toggleWifi()
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
                        Quickshell.execDetached(["loginctl", "lock-session"]);
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
