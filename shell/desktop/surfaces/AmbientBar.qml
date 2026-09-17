import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "./components"

PanelWindow {
    id: root

    signal toggleCalendar
    signal toggleBluetooth
    signal toggleNetwork

    color: "transparent"
    focusable: true
    implicitHeight: Theme.barHeight

    anchors {
        left: true
        right: true
        top: true
    }

    margins {
        top: 3
    }

    // =========================================================================
    // Left Sections: Logo, Workspaces, Window Title
    // =========================================================================

    RowLayout {
        id: leftSections

        anchors.left: parent.left
        anchors.leftMargin: Theme.barPaddingHorizontal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingMedium

        // Section 1: Blume Logo
        Rectangle {
            id: logoSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: height
            height: Theme.barHeight - 6
            width: height
            implicitHeight: height
            implicitWidth: width

            color: logoMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: logoMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            Image {
                id: logoIcon

                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                height: 22
                source: "components/os-icon.svg"
                sourceSize.height: 22
                sourceSize.width: 22
                width: 22
            }

            MouseArea {
                id: logoMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: OverlayController.openCommandDeck()
            }
        }

        // Section 2: Workspaces
        Rectangle {
            id: workspacesSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: workspacesWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: workspacesWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: Theme.background
            radius: Theme.radiusMedium
            border.color: Theme.borderMuted
            border.width: Theme.borderWidth

            WorkspacesWidget {
                id: workspacesWidget

                anchors.centerIn: parent
                monitorName: (root.screen && root.screen.name) ? root.screen.name : ""
            }
        }

        // Section 3: Window Title
        Rectangle {
            id: windowTitleSection

            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 380
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: Math.min(windowTitleWidget.implicitWidth + Theme.paddingMedium * 2, 380)
            height: Theme.barHeight - 6
            width: Math.min(windowTitleWidget.implicitWidth + Theme.paddingMedium * 2, 380)
            implicitHeight: height
            implicitWidth: width

            color: windowTitleMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: windowTitleMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            WindowTitleWidget {
                id: windowTitleWidget

                anchors.centerIn: parent
                width: parent.width - Theme.paddingMedium * 2
            }

            MouseArea {
                id: windowTitleMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
            }
        }
    }

    // =========================================================================
    // Center Section: Dynamic Island
    // =========================================================================

    DynamicIsland {
        id: centerSection

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    // =========================================================================
    // Right Sections: Network, Volume, Battery, Bluetooth, Clock, System Rail
    // =========================================================================

    RowLayout {
        id: rightSections

        anchors.right: parent.right
        anchors.rightMargin: Theme.barPaddingHorizontal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingMedium

        // Section 4: Network
        Rectangle {
            id: networkSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: networkWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: networkWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: networkMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: networkMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            NetworkWidget {
                id: networkWidget

                anchors.centerIn: parent
                isHovered: networkMouseArea.containsMouse
            }

            MouseArea {
                id: networkMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse && mouse.button === Qt.RightButton) {
                        NetworkService.toggleWifi();
                    } else {
                        root.toggleNetwork();
                    }
                }
            }
            // Decoupled from SystemRail: Formerly: OverlayController.openWifiSubmenu()
        }

        // Section 5: Volume
        Rectangle {
            id: volumeSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: volumeWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: volumeWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: volumeMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: volumeMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            VolumeWidget {
                id: volumeWidget

                anchors.centerIn: parent
                isHovered: volumeMouseArea.containsMouse
            }

            MouseArea {
                id: volumeMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: AudioService.toggleMute()

                onWheel: (wheel) => {
                    const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    AudioService.stepVolume(delta);
                }
            }
        }

        // Section 6: Battery
        Rectangle {
            id: batterySection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: batteryWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: batteryWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: batteryMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: batteryMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth
            visible: batteryWidget.visible

            BatteryWidget {
                id: batteryWidget

                anchors.centerIn: parent
                isHovered: batteryMouseArea.containsMouse
            }

            MouseArea {
                id: batteryMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: OverlayController.toggleSystemRail()
            }
        }

        // Section 7: Bluetooth
        Rectangle {
            id: bluetoothSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: bluetoothWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: bluetoothWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: bluetoothMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: bluetoothMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth
            visible: BluetoothService.available

            BluetoothWidget {
                id: bluetoothWidget

                anchors.centerIn: parent
                isHovered: bluetoothMouseArea.containsMouse
            }

            MouseArea {
                id: bluetoothMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse && mouse.button === Qt.RightButton) {
                        BluetoothService.togglePower();
                    } else {
                        root.toggleBluetooth();
                    }
                }
            }
        }

        // Section 8: Clock / Calendar Trigger
        Rectangle {
            id: clockSection

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: clockWidget.implicitWidth + Theme.paddingMedium * 2
            height: Theme.barHeight - 6
            width: clockWidget.implicitWidth + Theme.paddingMedium * 2
            implicitHeight: height
            implicitWidth: width

            color: clockMouseArea.containsMouse ? Theme.surfaceHover : Theme.background
            radius: Theme.radiusMedium
            border.color: clockMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            ClockWidget {
                id: clockWidget

                anchors.centerIn: parent

                onToggleCalendar: root.toggleCalendar()
            }

            MouseArea {
                id: clockMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.toggleCalendar()
            }
        }

        // Section 9: System Rail Toggle Button
        Rectangle {
            id: railSection

            readonly property bool isRailOpen: OverlayController.activeSurface === OverlayController.Surface.SystemRail

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.barHeight - 6
            Layout.preferredWidth: height
            height: Theme.barHeight - 6
            width: height
            implicitHeight: height
            implicitWidth: width

            color: isRailOpen ? Theme.surfaceSelected : (railMouseArea.containsMouse ? Theme.surfaceHover : Theme.background)
            radius: Theme.radiusMedium
            border.color: (isRailOpen || railMouseArea.containsMouse) ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth

            Text {
                anchors.centerIn: parent
                color: (railSection.isRailOpen || railMouseArea.containsMouse) ? Theme.accent : Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                text: "="
            }

            MouseArea {
                id: railMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: OverlayController.toggleSystemRail()
            }
        }
    }
}
