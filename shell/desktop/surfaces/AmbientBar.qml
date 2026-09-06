import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "./components"

PanelWindow {
    id: root

    color: Theme.background
    focusable: true
    implicitHeight: Theme.barHeight
    height: Theme.barHeight

    anchors {
        left: true
        right: true
        top: true
    }

    Rectangle {
        id: bottomBorder

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        color: Theme.divider
        height: Theme.borderWidth
    }

    RowLayout {
        id: barLayout

        anchors.fill: parent
        anchors.leftMargin: Theme.barPaddingHorizontal
        anchors.rightMargin: Theme.barPaddingHorizontal
        spacing: Theme.spacingMedium

        RowLayout {
            id: leftSection

            Layout.alignment: Qt.AlignLeft
            Layout.fillHeight: true
            spacing: Theme.spacingSmall

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: nodeLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: nodeMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: nodeMouseArea.containsMouse ? Theme.surfaceActive : Theme.surfaceSelected
                radius: Theme.radiusSmall

                Text {
                    id: nodeLabel

                    anchors.centerIn: parent
                    color: Theme.accent
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    text: "ctOS"
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

        Item {
            id: centerSection

            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        RowLayout {
            id: rightSection

            Layout.alignment: Qt.AlignRight
            Layout.fillHeight: true
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
