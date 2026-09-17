pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../services"
import "../widgets"

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

    property string selectedSsid: ""
    property string confirmingForgetSsid: ""

    // Consume all clicks inside popup so backdrop does not dismiss
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: mouse => mouse.accepted = true
    }

    // Cyberpunk Corner Brackets
    CornerBrackets {
        id: cornerBrackets
        bracketColor: Theme.acidGreen
        z: 10
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
                border.color: !NetworkService.available ? Theme.textDisabled : (NetworkService.wifiEnabled ? Theme.accent : (powerMouse.containsMouse ? Theme.accent : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: !NetworkService.available ? "transparent" : (NetworkService.wifiEnabled ? Theme.surfaceSelected : (powerMouse.containsMouse ? Theme.surfaceHover : "transparent"))
                radius: Theme.radiusSmall

                Text {
                    id: powerLabel

                    anchors.centerIn: parent
                    color: !NetworkService.available ? Theme.textDisabled : (NetworkService.wifiEnabled ? Theme.accent : (powerMouse.containsMouse ? Theme.accent : Theme.textSecondary))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: NetworkService.wifiEnabled ? "[PWR ON]" : "[PWR OFF]"
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: NetworkService.available

                    onClicked: NetworkService.toggleWifi()
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
                text: "NETWORK // WI-FI"
                elide: Text.ElideRight
            }

            // Scan Button
            Rectangle {
                id: scanBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: scanLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: !NetworkService.wifiEnabled ? Theme.borderMuted : (NetworkService.isScanning ? Theme.accent : (scanMouse.containsMouse ? Theme.accent : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: NetworkService.isScanning ? Theme.surfaceSelected : (scanMouse.containsMouse ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall
                opacity: NetworkService.wifiEnabled ? 1.0 : 0.4

                Text {
                    id: scanLabel

                    anchors.centerIn: parent
                    color: !NetworkService.wifiEnabled ? Theme.textMuted : (NetworkService.isScanning ? Theme.accent : (scanMouse.containsMouse ? Theme.accent : Theme.textSecondary))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: NetworkService.isScanning ? "[SCANNING]" : "[SCAN]"
                }

                MouseArea {
                    id: scanMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: NetworkService.wifiEnabled

                    onClicked: NetworkService.scanNetworks()
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

        // Body Content: Empty State OR Scrollable Network List
        Item {
            id: bodyContainer

            Layout.fillWidth: true
            Layout.preferredHeight: {
                const count = NetworkService.availableNetworks ? (NetworkService.availableNetworks.count || NetworkService.availableNetworks.length || 0) : 0;
                if (!NetworkService.wifiEnabled || count === 0) {
                    return 140;
                }
                return Math.min(320, Math.max(140, networkListColumn.implicitHeight));
            }

            // Empty State: Radio Off
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingSmall
                visible: !NetworkService.wifiEnabled

                CtosIcon {
                    Layout.alignment: Qt.AlignHCenter
                    size: 24
                    name: "wifi-slash"
                    color: Theme.textMuted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.textMuted
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    horizontalAlignment: Text.AlignHCenter
                    text: "// WI-FI RADIO OFF\nUSE [PWR ON] TO ACTIVATE"
                }
            }

            // Empty State: Radio On, No Networks Found
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingSmall
                visible: {
                    const count = NetworkService.availableNetworks ? (NetworkService.availableNetworks.count || NetworkService.availableNetworks.length || 0) : 0;
                    return NetworkService.wifiEnabled && count === 0;
                }

                CtosIcon {
                    Layout.alignment: Qt.AlignHCenter
                    size: 24
                    name: "wifi"
                    color: (NetworkService.isScanning || NetworkService.isConnecting) ? Theme.acidGreen : Theme.textMuted
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: (NetworkService.isScanning || NetworkService.isConnecting) ? Theme.acidGreen : Theme.textMuted
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    horizontalAlignment: Text.AlignHCenter
                    text: (NetworkService.isScanning || NetworkService.isConnecting) ? "// SCANNING FOR NEARBY NETWORKS..." : "// NO NETWORKS FOUND\nCLICK [SCAN] TO DISCOVER"
                }
            }

            // Scrollable Network List
            Flickable {
                id: networkFlickable

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: networkListColumn.implicitHeight
                contentWidth: width
                visible: {
                    const count = NetworkService.availableNetworks ? (NetworkService.availableNetworks.count || NetworkService.availableNetworks.length || 0) : 0;
                    return NetworkService.wifiEnabled && count > 0;
                }

                ColumnLayout {
                    id: networkListColumn

                    width: networkFlickable.width
                    spacing: Theme.spacingMedium

                    // =========================================================
                    // Section 1: Connected Networks
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = NetworkService.connectedNetworks ? (NetworkService.connectedNetworks.count || NetworkService.connectedNetworks.length || 0) : 0;
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
                                    const count = NetworkService.connectedNetworks ? (NetworkService.connectedNetworks.count || NetworkService.connectedNetworks.length || 0) : 0;
                                    return "// CONNECTED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: NetworkService.connectedNetworks

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
                                            name: "wifi"
                                            color: Theme.acidGreen
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.acidGreen
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightBold
                                            text: connectedTile.modelData.ssid || "Network"
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
                                                text: "[DISCONNECT]"
                                            }

                                            MouseArea {
                                                id: disconnectMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: NetworkService.disconnectCurrentNetwork()
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
                                            text: {
                                                const strength = (typeof connectedTile.modelData.signalStrength === "number") ? Math.round(connectedTile.modelData.signalStrength * 100) : 0;
                                                return "SIGNAL: " + strength + "% // ACTIVE";
                                            }
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
                    // Section 2: Saved / Known Networks
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = NetworkService.savedNetworks ? (NetworkService.savedNetworks.count || NetworkService.savedNetworks.length || 0) : 0;
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
                                    const count = NetworkService.savedNetworks ? (NetworkService.savedNetworks.count || NetworkService.savedNetworks.length || 0) : 0;
                                    return "// SAVED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: NetworkService.savedNetworks

                            delegate: Rectangle {
                                id: savedTile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                color: savedMouseArea.containsMouse ? Theme.surfaceHover : Theme.gray800
                                border.color: savedMouseArea.containsMouse ? Theme.accent : Theme.gray700
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
                                            name: "wifi"
                                            color: Theme.textSecondary
                                        }

                                        CtosIcon {
                                            size: 12
                                            name: "lock"
                                            color: Theme.textMuted
                                            visible: Boolean(savedTile.modelData.security !== undefined && savedTile.modelData.security !== 0)
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightMedium
                                            text: savedTile.modelData.ssid || "Network"
                                            elide: Text.ElideRight
                                        }

                                        // Connect Button
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: savedConnLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: savedConnMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: savedConnMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: savedConnLabel

                                                anchors.centerIn: parent
                                                color: savedConnMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: (NetworkService.isConnecting && NetworkService.connectingSsid === savedTile.modelData.ssid) ? "[CONN...]" : "[CONNECT]"
                                            }

                                            MouseArea {
                                                id: savedConnMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                enabled: !NetworkService.isConnecting

                                                onClicked: NetworkService.connectToNetwork(savedTile.modelData.ssid, "")
                                            }
                                        }

                                        // Forget Button
                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: savedForgetLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: savedForgetMouse.containsMouse ? Theme.destructive : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: savedForgetMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: savedForgetLabel

                                                anchors.centerIn: parent
                                                color: savedForgetMouse.containsMouse ? Theme.destructive : Theme.textMuted
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: "x"
                                            }

                                            MouseArea {
                                                id: savedForgetMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: NetworkService.forgetNetwork(savedTile.modelData.ssid)
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
                                            text: {
                                                const strength = (typeof savedTile.modelData.signalStrength === "number") ? Math.round(savedTile.modelData.signalStrength * 100) : 0;
                                                return "SIGNAL: " + strength + "% // SAVED PROFILE";
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: savedMouseArea

                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                }
                            }
                        }
                    }

                    // =========================================================
                    // Section 3: Available / Discovered Networks
                    // =========================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: {
                            const count = NetworkService.discoveredNetworks ? (NetworkService.discoveredNetworks.count || NetworkService.discoveredNetworks.length || 0) : 0;
                            return count > 0;
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Rectangle {
                                Layout.preferredHeight: 6
                                Layout.preferredWidth: 6
                                color: Theme.textMuted
                                radius: 3
                            }

                            Text {
                                Layout.fillWidth: true
                                color: Theme.textMuted
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                text: {
                                    const count = NetworkService.discoveredNetworks ? (NetworkService.discoveredNetworks.count || NetworkService.discoveredNetworks.length || 0) : 0;
                                    return "// DISCOVERED (" + count + ")";
                                }
                            }
                        }

                        Repeater {
                            model: NetworkService.discoveredNetworks

                            delegate: Rectangle {
                                id: availTile

                                required property var modelData

                                readonly property bool isSelected: root.selectedSsid === availTile.modelData.ssid
                                readonly property bool isSecured: Boolean(availTile.modelData.requiresPassword || (availTile.modelData.security !== undefined && availTile.modelData.security !== 0))

                                Layout.fillWidth: true
                                Layout.preferredHeight: isSelected ? 100 : 46
                                color: isSelected ? Theme.gray900 : (availMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                                border.color: isSelected ? Theme.acidGreen : (availMouseArea.containsMouse ? Theme.accent : Theme.borderMuted)
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.paddingMedium
                                    anchors.rightMargin: Theme.paddingSmall
                                    anchors.topMargin: Theme.paddingXs
                                    anchors.bottomMargin: Theme.paddingXs
                                    spacing: Theme.spacingSmall

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        CtosIcon {
                                            size: 14
                                            name: "wifi"
                                            color: availTile.isSelected ? Theme.acidGreen : Theme.textMuted
                                        }

                                        CtosIcon {
                                            size: 12
                                            name: "lock"
                                            color: Theme.textMuted
                                            visible: availTile.isSecured
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            color: availTile.isSelected ? Theme.textPrimary : Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightMedium
                                            text: availTile.modelData.ssid || "Network"
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 18
                                            Layout.preferredWidth: availConnLabel.implicitWidth + Theme.paddingSmall * 2
                                            border.color: availConnMouse.containsMouse ? Theme.accent : Theme.borderMuted
                                            border.width: Theme.borderWidth
                                            color: availConnMouse.containsMouse ? Theme.surfaceHover : "transparent"
                                            radius: Theme.radiusSmall

                                            Text {
                                                id: availConnLabel

                                                anchors.centerIn: parent
                                                color: availConnMouse.containsMouse ? Theme.accent : Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: 10
                                                font.weight: Theme.fontWeightBold
                                                text: (NetworkService.isConnecting && NetworkService.connectingSsid === availTile.modelData.ssid) ? "[CONN...]" : (availTile.isSelected ? "[CANCEL]" : "[CONNECT]")
                                            }

                                            MouseArea {
                                                id: availConnMouse

                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: {
                                                    if (availTile.isSelected) {
                                                        root.selectedSsid = "";
                                                    } else if (availTile.isSecured) {
                                                        root.selectedSsid = availTile.modelData.ssid;
                                                    } else {
                                                        NetworkService.connectToNetwork(availTile.modelData.ssid, "");
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Secondary Info / Signal strength (when not expanded)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: !availTile.isSelected

                                        Text {
                                            Layout.fillWidth: true
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: 10
                                            text: {
                                                const strength = (typeof availTile.modelData.signalStrength === "number") ? Math.round(availTile.modelData.signalStrength * 100) : 0;
                                                const secText = availTile.isSecured ? "SECURED" : "OPEN";
                                                return "SIGNAL: " + strength + "% // " + secText;
                                            }
                                        }
                                    }

                                    // Cyberpunk Inline Password Prompt (when expanded)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        visible: availTile.isSelected

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
                                                border.color: Theme.acidGreen
                                                border.width: Theme.borderWidth
                                                radius: Theme.radiusSmall

                                                TextInput {
                                                    id: pwInput

                                                    anchors.fill: parent
                                                    anchors.leftMargin: Theme.paddingSmall
                                                    anchors.rightMargin: Theme.paddingSmall
                                                    color: Theme.textPrimary
                                                    font.family: Theme.fontFamilyMonospace
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    echoMode: TextInput.Password
                                                    focus: availTile.isSelected
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    selectByMouse: true

                                                    Keys.onReturnPressed: {
                                                        NetworkService.connectToNetwork(availTile.modelData.ssid, pwInput.text);
                                                        root.selectedSsid = "";
                                                    }

                                                    Keys.onEscapePressed: {
                                                        root.selectedSsid = "";
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: 22
                                                Layout.preferredWidth: submitLabel.implicitWidth + Theme.paddingSmall * 2
                                                border.color: submitMouse.containsMouse ? Theme.acidGreen : Theme.accent
                                                border.width: Theme.borderWidth
                                                color: submitMouse.containsMouse ? Theme.surfaceSelected : Theme.surfaceHover
                                                radius: Theme.radiusSmall

                                                Text {
                                                    id: submitLabel

                                                    anchors.centerIn: parent
                                                    color: Theme.acidGreen
                                                    font.family: Theme.fontFamilyMonospace
                                                    font.pixelSize: 10
                                                    font.weight: Theme.fontWeightBold
                                                    text: "[CONNECT]"
                                                }

                                                MouseArea {
                                                    id: submitMouse

                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true

                                                    onClicked: {
                                                        NetworkService.connectToNetwork(availTile.modelData.ssid, pwInput.text);
                                                        root.selectedSsid = "";
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: 9
                                            text: "[ENTER] Connect  [ESC] Cancel"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: availMouseArea

                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true

                                    onClicked: {
                                        if (availTile.isSecured) {
                                            root.selectedSsid = availTile.isSelected ? "" : availTile.modelData.ssid;
                                        } else {
                                            NetworkService.connectToNetwork(availTile.modelData.ssid, "");
                                        }
                                    }
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
                    if (!NetworkService.wifiEnabled) return "// STATUS: OFF";
                    if (NetworkService.isScanning) return "// STATUS: SCANNING...";
                    if (NetworkService.isConnecting) return "// STATUS: CONNECTING TO " + (NetworkService.connectingSsid ? NetworkService.connectingSsid.toUpperCase() : "...");
                    if (NetworkService.isConnected) return "// STATUS: CONNECTED (" + NetworkService.networkName + ")";
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

                    onClicked: NetworkService.refresh()
                }
            }
        }
    }
}
