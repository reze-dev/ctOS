pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../services"

Rectangle {
    id: root

    // =========================================================================
    // Public Interface & Signals
    // =========================================================================

    signal closeRequested

    // =========================================================================
    // Geometry & Theme Styling
    // =========================================================================

    implicitWidth: 320
    width: 320
    implicitHeight: mainColumn.implicitHeight + Theme.paddingLarge * 2
    color: Theme.gray900
    radius: Theme.radiusSmall
    border.color: Theme.borderMuted
    border.width: Theme.borderWidth

    // Consume all clicks inside popup so backdrop does not dismiss
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: mouse => mouse.accepted = true
    }

    // Cyberpunk Corner Brackets
    Item {
        id: cornerBrackets

        anchors.fill: parent
        z: 10

        readonly property color bracketColor: Theme.acidGreen

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

    // =========================================================================
    // Content Layout
    // =========================================================================

    ColumnLayout {
        id: mainColumn

        anchors.fill: parent
        anchors.margins: Theme.paddingLarge
        spacing: Theme.spacingMedium

        // Header: [PWR] Title [SCAN] [x]
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            // Power Toggle Button
            Rectangle {
                id: powerBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: powerLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: !BluetoothService.available ? Theme.textDisabled : (BluetoothService.powered ? Theme.accent : (powerMouse.containsMouse ? Theme.accent : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: !BluetoothService.available ? "transparent" : (BluetoothService.powered ? Theme.surfaceSelected : (powerMouse.containsMouse ? Theme.surfaceHover : "transparent"))
                radius: Theme.radiusSmall

                Text {
                    id: powerLabel

                    anchors.centerIn: parent
                    color: !BluetoothService.available ? Theme.textDisabled : (BluetoothService.powered ? Theme.accent : (powerMouse.containsMouse ? Theme.accent : Theme.textSecondary))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: BluetoothService.powered ? "[PWR ON]" : "[PWR OFF]"
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: BluetoothService.available

                    onClicked: BluetoothService.togglePower()
                }
            }

            // Title
            Text {
                id: titleText

                Layout.fillWidth: true
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                horizontalAlignment: Text.AlignHCenter
                text: "BLUETOOTH // RADIO"
                elide: Text.ElideRight
            }

            // Scan Button
            Rectangle {
                id: scanBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: scanLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: !BluetoothService.powered ? Theme.borderMuted : (BluetoothService.isScanning ? Theme.accent : (scanMouse.containsMouse ? Theme.accent : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: BluetoothService.isScanning ? Theme.surfaceSelected : (scanMouse.containsMouse ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall
                opacity: BluetoothService.powered ? 1.0 : 0.4

                Text {
                    id: scanLabel

                    anchors.centerIn: parent
                    color: !BluetoothService.powered ? Theme.textMuted : (BluetoothService.isScanning ? Theme.accent : (scanMouse.containsMouse ? Theme.accent : Theme.textSecondary))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: BluetoothService.isScanning ? "[SCANNING]" : "[SCAN]"
                }

                MouseArea {
                    id: scanMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: BluetoothService.powered

                    onClicked: BluetoothService.toggleScan()
                }
            }

            // Close Button
            Rectangle {
                id: closeBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                border.color: closeMouse.containsMouse ? Theme.destructive : Theme.borderMuted
                border.width: Theme.borderWidth
                color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: closeMouse.containsMouse ? Theme.destructive : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: "x"
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.closeRequested()
                }
            }
        }

        // Header Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // Body Content: Empty State OR Scrollable Device List
        Item {
            id: bodyContainer

            Layout.fillWidth: true
            Layout.preferredHeight: {
                const devCount = BluetoothService.devices ? (BluetoothService.devices.count || BluetoothService.devices.length || 0) : 0;
                if (!BluetoothService.powered || devCount === 0) {
                    return 140;
                }
                return Math.min(320, Math.max(140, deviceListColumn.implicitHeight));
            }

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
                    text: "// BLUETOOTH RADIO OFF\nUSE [PWR ON] TO ACTIVATE"
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

            // Scrollable Device List
            Flickable {
                id: deviceFlickable

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: deviceListColumn.implicitHeight
                contentWidth: width
                visible: {
                    const devCount = BluetoothService.devices ? (BluetoothService.devices.count || BluetoothService.devices.length || 0) : 0;
                    return BluetoothService.powered && devCount > 0;
                }

                ColumnLayout {
                    id: deviceListColumn

                    width: deviceFlickable.width
                    spacing: Theme.spacingMedium

                    // =========================================================
                    // Section 1: Connected Devices
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = BluetoothService.connectedDevices ? (BluetoothService.connectedDevices.count || BluetoothService.connectedDevices.length || 0) : 0;
                            return count > 0;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                Layout.preferredHeight: 6
                                Layout.preferredWidth: 6
                                color: Theme.acidGreen
                                radius: 3
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.acidGreen
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: {
                                    const count = BluetoothService.connectedDevices ? (BluetoothService.connectedDevices.count || BluetoothService.connectedDevices.length || 0) : 0;
                                    return "// CONNECTED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: BluetoothService.connectedDevices

                            delegate: Rectangle {
                                id: connectedTile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                color: tileMouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSelected
                                border.color: Theme.acidGreen
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: Theme.acidGreen
                                    radius: Theme.radiusSmall
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.paddingMedium
                                    anchors.rightMargin: Theme.paddingSmall
                                    anchors.topMargin: Theme.paddingXs
                                    anchors.bottomMargin: Theme.paddingXs
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        CtosIcon {
                                            size: 14
                                            name: "bluetooth"
                                            color: Theme.acidGreen
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.acidGreen
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightBold
                                            text: connectedTile.modelData.name || "Device"
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: disconnectLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: disconnectMouse.containsMouse ? Theme.warningRed : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: disconnectMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: disconnectLabel

                                                anchors.centerIn: parent
                                                color: disconnectMouse.containsMouse ? Theme.warningRed : Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: (BluetoothService.isActionPending && BluetoothService.actionTargetMac === connectedTile.modelData.mac) ? "[WAIT...]" : "[DISCONNECT]"
                                            }

                                            MouseArea {
                                                id: disconnectMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                enabled: !BluetoothService.isActionPending

                                                onClicked: BluetoothService.disconnectDevice(connectedTile.modelData.mac)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: 10
                                            text: connectedTile.modelData.mac
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileMouseArea

                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                }
                            }
                        }
                    }

                    // =========================================================
                    // Section 2: Paired Devices
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = BluetoothService.pairedDevices ? (BluetoothService.pairedDevices.count || BluetoothService.pairedDevices.length || 0) : 0;
                            return count > 0;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                Layout.preferredHeight: 6
                                Layout.preferredWidth: 6
                                color: Theme.textSecondary
                                radius: 3
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: {
                                    const count = BluetoothService.pairedDevices ? (BluetoothService.pairedDevices.count || BluetoothService.pairedDevices.length || 0) : 0;
                                    return "// PAIRED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: BluetoothService.pairedDevices

                            delegate: Rectangle {
                                id: pairedTile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                color: pairedMouseArea.containsMouse ? Theme.surfaceHover : Theme.gray800
                                border.color: pairedMouseArea.containsMouse ? Theme.accent : Theme.gray700
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.paddingMedium
                                    anchors.rightMargin: Theme.paddingSmall
                                    anchors.topMargin: Theme.paddingXs
                                    anchors.bottomMargin: Theme.paddingXs
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        CtosIcon {
                                            size: 14
                                            name: "bluetooth"
                                            color: Theme.textSecondary
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightMedium
                                            text: pairedTile.modelData.name || "Device"
                                            elide: Text.ElideRight
                                        }

                                        // Connect Button
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: connLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: connMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: connMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: connLabel

                                                anchors.centerIn: parent
                                                color: connMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: (BluetoothService.isActionPending && BluetoothService.actionTargetMac === pairedTile.modelData.mac) ? (BluetoothService.actionType === "connect" ? "[CONN...]" : "[WAIT...]") : "[CONNECT]"
                                            }

                                            MouseArea {
                                                id: connMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                enabled: !BluetoothService.isActionPending

                                                onClicked: BluetoothService.connectDevice(pairedTile.modelData.mac)
                                            }
                                        }

                                        // Forget Button
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: forgetLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: forgetMouse.containsMouse ? Theme.destructive : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: forgetMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: forgetLabel

                                                anchors.centerIn: parent
                                                color: forgetMouse.containsMouse ? Theme.destructive : Theme.textMuted
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: "x"
                                            }

                                            MouseArea {
                                                id: forgetMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                enabled: !BluetoothService.isActionPending

                                                onClicked: BluetoothService.forgetDevice(pairedTile.modelData.mac)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: 10
                                            text: pairedTile.modelData.mac
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pairedMouseArea

                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                }
                            }
                        }
                    }

                    // =========================================================
                    // Section 3: Available / Discovered Devices
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = BluetoothService.availableDevices ? (BluetoothService.availableDevices.count || BluetoothService.availableDevices.length || 0) : 0;
                            return count > 0;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                Layout.preferredHeight: 6
                                Layout.preferredWidth: 6
                                color: Theme.accent
                                radius: 3
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.accent
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: {
                                    const count = BluetoothService.availableDevices ? (BluetoothService.availableDevices.count || BluetoothService.availableDevices.length || 0) : 0;
                                    return "// DISCOVERED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: BluetoothService.availableDevices

                            delegate: Rectangle {
                                id: availTile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                color: availMouseArea.containsMouse ? Theme.surfaceHover : Theme.gray800
                                border.color: availMouseArea.containsMouse ? Theme.accent : Theme.gray700
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.paddingMedium
                                    anchors.rightMargin: Theme.paddingSmall
                                    anchors.topMargin: Theme.paddingXs
                                    anchors.bottomMargin: Theme.paddingXs
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        CtosIcon {
                                            size: 14
                                            name: "bluetooth"
                                            color: Theme.textSecondary
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightMedium
                                            text: availTile.modelData.name || "Device"
                                            elide: Text.ElideRight
                                        }

                                        // Pair Button
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: pairLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: pairMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: pairMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: pairLabel

                                                anchors.centerIn: parent
                                                color: pairMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: (BluetoothService.isActionPending && BluetoothService.actionTargetMac === availTile.modelData.mac) ? (BluetoothService.actionType === "pair" ? "[PAIRING...]" : "[WAIT...]") : "[PAIR]"
                                            }

                                            MouseArea {
                                                id: pairMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                enabled: !BluetoothService.isActionPending

                                                onClicked: BluetoothService.pairDevice(availTile.modelData.mac)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: 10
                                            text: availTile.modelData.mac
                                        }
                                    }
                                }

                                MouseArea {
                                    id: availMouseArea

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

        // Footer Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // Footer Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                Layout.fillWidth: true
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                text: {
                    if (!BluetoothService.powered) return "// STATUS: OFF";
                    if (BluetoothService.isScanning) return "// STATUS: SCANNING...";
                    if (BluetoothService.isConnected) return "// STATUS: CONNECTED";
                    return "// STATUS: STANDBY";
                }
                elide: Text.ElideRight
            }

            Rectangle {
                id: refreshBtn

                Layout.preferredHeight: 18
                Layout.preferredWidth: refreshLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: refreshMouse.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: refreshMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    id: refreshLabel

                    anchors.centerIn: parent
                    color: refreshMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    text: "[REFRESH]"
                }

                MouseArea {
                    id: refreshMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: BluetoothService.refresh()
                }
            }
        }
    }
}
