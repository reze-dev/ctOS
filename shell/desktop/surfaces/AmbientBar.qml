import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "./components"

PanelWindow {
    id: root

    signal toggleCalendar

    color: "transparent"
    focusable: true
    implicitHeight: Theme.barHeight
    height: Theme.barHeight

    anchors {
        left: true
        right: true
        top: true
    }

    margins {
        top: 3
    }

    // =========================================================================
    // Left Island: OS Launcher, Workspaces, Window Title
    // =========================================================================

    Rectangle {
        id: leftIsland

        anchors.left: parent.left
        anchors.leftMargin: Theme.barPaddingHorizontal
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barHeight - 6
        width: leftSection.implicitWidth + Theme.paddingLarge * 2

        color: Theme.background
        radius: Theme.radiusPill
        border.color: Theme.borderMuted
        border.width: Theme.borderWidth

        RowLayout {
            id: leftSection

            anchors.fill: parent
            anchors.leftMargin: Theme.paddingLarge
            anchors.rightMargin: Theme.paddingLarge
            spacing: Theme.spacingSmall

            // Diamond OS Icon Button (Replaces ctOS text)
            Rectangle {
                id: nodeBtn

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: 20
                border.color: nodeMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: nodeMouseArea.containsMouse ? Theme.surfaceActive : Theme.surfaceSelected
                radius: Theme.radiusSmall

                Image {
                    id: nodeIcon
                    anchors.centerIn: parent
                    source: "components/os-icon.svg"
                    width: 14
                    height: 14
                    sourceSize.width: 14
                    sourceSize.height: 14
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    id: nodeMouseArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: OverlayController.openCommandDeck()
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
            }

            WorkspacesWidget {
                id: workspacesWidget

                Layout.alignment: Qt.AlignVCenter
                monitorName: (root.screen && root.screen.name) ? root.screen.name : ""
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
            }

            WindowTitleWidget {
                id: windowTitleWidget

                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 380
            }
        }
    }

    // =========================================================================
    // Center Island: Dynamic Island
    // =========================================================================

    DynamicIsland {
        id: centerSection

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    // =========================================================================
    // Right Island: Status Indicators, Clock, System Rail Button
    // =========================================================================

    Rectangle {
        id: rightIsland

        anchors.right: parent.right
        anchors.rightMargin: Theme.barPaddingHorizontal
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barHeight - 6
        width: rightSection.implicitWidth + Theme.paddingLarge * 2

        color: Theme.background
        radius: Theme.radiusPill
        border.color: Theme.borderMuted
        border.width: Theme.borderWidth

        RowLayout {
            id: rightSection

            anchors.fill: parent
            anchors.leftMargin: Theme.paddingLarge
            anchors.rightMargin: Theme.paddingLarge
            spacing: Theme.spacingSmall

            NetworkWidget {
                id: networkWidget

                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
            }

            VolumeWidget {
                id: volumeWidget

                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: batteryDivider

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
                visible: batteryWidget.visible
            }

            BatteryWidget {
                id: batteryWidget

                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
            }

            ClockWidget {
                id: clockWidget

                Layout.alignment: Qt.AlignVCenter

                onToggleCalendar: root.toggleCalendar()
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 16
                Layout.preferredWidth: Theme.dividerWidth
                color: Theme.divider
            }

            Rectangle {
                id: railBtn

                readonly property bool isRailOpen: OverlayController.activeSurface === OverlayController.Surface.SystemRail

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: 20
                border.color: (isRailOpen || railMouseArea.containsMouse) ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: isRailOpen ? Theme.surfaceSelected : (railMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: (railBtn.isRailOpen || railMouseArea.containsMouse) ? Theme.accent : Theme.textSecondary
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
}
