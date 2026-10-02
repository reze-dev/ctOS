pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "./components"

// Command centre: a two-column grid of cards.
//
// Rebuilt on Card rather than on the accordion the previous version used. An
// accordion is a disclosure control -- it hides its contents behind a click --
// which is the right model for a list you might not care about and the wrong one
// for a panel whose cards are all meant to be read at once. The design shows
// every card open.
//
// Cards that hold inputs stay collapsible, because a Wi-Fi password prompt and a
// notification history list do not both belong on screen at their natural size.
// System Status is fixed open: it reports, and there is nothing to disclose.
FocusScope {
    id: root

    implicitWidth: Theme.commandCenterWidth
    width: implicitWidth

    readonly property bool isOpen:
        OverlayController.activeSurface === OverlayController.Surface.CommandCenter

    // Which card to expand when the panel opens. Empty means "whatever was
    // already open", so reopening does not reset the user's place.
    property string requestedCard: ""

    implicitHeight: Math.min(Theme.commandCenterMaxHeight,
                             Theme.paddingXl * 2 + root.gridHeight)
    height: implicitHeight

    readonly property real gridHeight: Math.max(leftColumn.implicitHeight,
                                                rightColumn.implicitHeight)

    focus: true

    Keys.onEscapePressed: function (event) {
        event.accepted = true;
        OverlayController.close();
    }

    Connections {
        target: OverlayController
        function onOverlayOpened(surface: int): void {
            if (surface !== OverlayController.Surface.CommandCenter)
                return;

            root.forceActiveFocus();

            // A sub-surface request (power menu, wifi rail) opens the panel with
            // the matching card already expanded.
            if (OverlayController.pendingSessionAction !== "") {
                root.requestedCard = "power";
                OverlayController.pendingSessionAction = "";
            } else if (OverlayController.pendingRailView !== "") {
                root.requestedCard = OverlayController.pendingRailView;
                OverlayController.pendingRailView = "";
            }
        }
    }

    // ------------------------------------------------------------------ panel

    Rectangle {
        anchors.fill: parent
        radius: Theme.commandCenterSectionRadius
        color: Theme.background
        border.width: Theme.borderWidth
        border.color: Theme.border
        clip: true
    }

    // --------------------------------------------------------------- contents

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        contentWidth: width
        contentHeight: root.gridHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: grid
            width: scroller.width
            spacing: Theme.commandCenterColumnGutter

            // ------------------------------------------------- left column

            Column {
                id: leftColumn
                width: (grid.width - Theme.commandCenterColumnGutter) / 2
                spacing: Theme.cardGap

                Card {
                    id: cardNotifications
                    width: parent.width
                    title: qsTr("Notifications")
                    icon: "bell"
                    accent: Theme.accentBlue
                    collapsible: true
                    expanded: root.requestedCard === "notifications"
                        || root.requestedCard === ""
                    onHeaderClicked: root.requestedCard =
                        root.requestedCard === "notifications" ? "" : "notifications"

                    action: Component {
                        ToggleSwitch {
                            checked: !NotificationService.doNotDisturb
                            onToggled: NotificationService.toggleDnd()
                        }
                    }
                }

                Card {
                    id: cardConnectivity
                    width: parent.width
                    title: qsTr("Wi-Fi")
                    icon: "wifi"
                    accent: Theme.accentBlue
                    collapsible: true
                    expanded: root.requestedCard === "wifi"

                    action: Component {
                        ToggleSwitch {
                            checked: NetworkService.wifiEnabled
                            onToggled: NetworkService.toggleWifi()
                        }
                    }
                }

                Card {
                    id: cardBluetooth
                    width: parent.width
                    title: qsTr("Bluetooth")
                    icon: "bluetooth"
                    accent: Theme.accentBlue
                    collapsible: true
                    expanded: root.requestedCard === "bluetooth"

                    action: Component {
                        ToggleSwitch {
                            checked: BluetoothService.powered
                            onToggled: BluetoothService.togglePower()
                        }
                    }
                }

                Card {
                    id: cardAudio
                    width: parent.width
                    title: qsTr("Audio & Media")
                    icon: "speaker"
                    accent: Theme.accentBlue
                    collapsible: true
                    expanded: root.requestedCard === "audio"
                }
            }

            // ------------------------------------------------ right column

            Column {
                id: rightColumn
                width: (grid.width - Theme.commandCenterColumnGutter) / 2
                spacing: Theme.cardGap

                Card {
                    id: cardPower
                    width: parent.width
                    title: qsTr("Power & Session")
                    icon: "power"
                    accent: Theme.accentMagenta
                    collapsible: true
                    expanded: root.requestedCard === "power"
                }

                Card {
                    id: cardCalendar
                    width: parent.width
                    title: qsTr("Calendar & Events")
                    icon: "calendar"
                    accent: Theme.accentBlue
                    collapsible: true
                    expanded: root.requestedCard === "calendar"
                }

                Card {
                    id: cardSystemStatus
                    width: parent.width
                    title: qsTr("System Status")
                    icon: "sliders"
                    accent: Theme.accentBlue
                    // Fixed open: read-only telemetry has nothing to disclose.
                    collapsible: false

                    contentComponent: Component {
                        Item {
                            width: parent ? parent.width : undefined
                            implicitHeight: 76
                            height: 76

                            Row {
                                id: metrics
                                anchors.left: parent.left
                                anchors.top: parent.top
                                spacing: Theme.spacingLarge

                                StatRing {
                                    fraction: SystemMonitorService.cpuTotal
                                    ringColor: Theme.statusGreen
                                    valueText: Math.round(SystemMonitorService.cpuTotal * 100) + "%"
                                    caption: "CPU"
                                }

                                StatRing {
                                    fraction: SystemMonitorService.memTotalBytes > 0
                                        ? SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes
                                        : 0
                                    ringColor: Theme.accentBlue
                                    valueText: SystemMonitorService.memTotalBytes > 0
                                        ? Math.round(SystemMonitorService.memUsedBytes / SystemMonitorService.memTotalBytes * 100) + "%"
                                        : "--"
                                    caption: "MEMORY"
                                }

                                StatRing {
                                    fraction: SystemMonitorService.diskFraction
                                    ringColor: Theme.accentMagenta
                                    valueText: SystemMonitorService.diskTotalBytes > 0
                                        ? Math.round(SystemMonitorService.diskFraction * 100) + "%"
                                        : "--"
                                    caption: "DISK"
                                }
                            }

                            // Throughput, right-aligned so the arrows line up on
                            // their trailing edge regardless of digit count.
                            Column {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: Theme.spacingSmall

                                Repeater {
                                    model: 2
                                    delegate: Row {
                                        required property int index
                                        spacing: Theme.spacingSmall

                                        Text {
                                            text: index === 0 ? "↑" : "↓"
                                            color: index === 0 ? Theme.accentBlue : Theme.accentMagenta
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeBody
                                        }
                                        Text {
                                            text: SystemMonitorService.formatBytes(
                                                      index === 0 ? SystemMonitorService.netRxBytesPerSec
                                                                  : SystemMonitorService.netTxBytesPerSec) + "/s"
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: "NETWORK"
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightDemiBold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}