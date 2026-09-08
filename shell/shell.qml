import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

import "desktop/adapters/hyprland"
import "desktop/core"
import "desktop/services"
import "desktop/surfaces"
import "desktop/surfaces/widgets"

Scope {
    id: root

    IpcHandler {
        target: "ctos"

        function toggleCommandDeck(): void {
            OverlayController.toggleCommandDeck();
        }

        function toggleSystemRail(): void {
            OverlayController.toggle(OverlayController.Surface.SystemRail);
        }

        function closeOverlay(): void {
            OverlayController.close();
        }
    }

    function resolveTargetScreen(): var {
        const screenList = Quickshell.screens;
        if (!screenList || screenList.length === 0) {
            return null;
        }

        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            const focusedName = Hyprland.focusedMonitor.name;
            for (let i = 0; i < screenList.length; ++i) {
                const s = screenList[i];
                if (s && s.name === focusedName) {
                    return s;
                }
            }
        }

        for (let i = 0; i < screenList.length; ++i) {
            if (screenList[i]) {
                return screenList[i];
            }
        }
        return null;
    }

    Variants {
        id: cpuHexGridVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: cpuHexGridWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetCpuHexGridVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    top: true
                    right: true
                }
                margins {
                    top: Theme.barHeight + Theme.spacingXl
                    right: Theme.spacing2Xl
                }

                implicitWidth: cpuHexGrid.implicitWidth
                implicitHeight: cpuHexGrid.implicitHeight

                CpuHexGrid {
                    id: cpuHexGrid
                    anchors.fill: parent
                }
            }
        }
    }

    Variants {
        id: ramBlockBarVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: ramBlockBarWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetRamBlockBarVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    top: true
                    right: true
                }
                margins {
                    top: Settings.widgetCpuHexGridVisible
                        ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl)
                        : (Theme.barHeight + Theme.spacingXl)
                    right: Theme.spacing2Xl
                }

                implicitWidth: ramBlockBar.implicitWidth
                implicitHeight: ramBlockBar.implicitHeight

                RamBlockBar {
                    id: ramBlockBar
                    anchors.fill: parent
                }
            }
        }
    }

    Variants {
        id: networkFlowVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: networkFlowWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetNetworkFlowVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    bottom: true
                    right: true
                }
                margins {
                    bottom: Theme.spacing2Xl
                    right: Theme.spacing2Xl
                }

                implicitWidth: networkFlowMatrix.implicitWidth
                implicitHeight: networkFlowMatrix.implicitHeight

                NetworkFlowMatrix {
                    id: networkFlowMatrix
                    anchors.fill: parent
                }
            }
        }
    }

    Variants {
        id: barVariants

        model: Quickshell.screens

        delegate: Component {
            AmbientBar {
                required property var modelData

                screen: modelData
            }
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (OverlayController.isOverlayActive) {
                const currentScreen = overlayHost.screen;
                if (!currentScreen) {
                    OverlayController.close();
                    return;
                }

                const screenList = Quickshell.screens;
                let isScreenAlive = false;
                for (let i = 0; i < screenList.length; ++i) {
                    if (screenList[i] && screenList[i].name === currentScreen.name) {
                        isScreenAlive = true;
                        break;
                    }
                }

                if (!isScreenAlive) {
                    OverlayController.close();
                }
            }
        }
    }

    Connections {
        target: OverlayController

        function onOverlayOpened(activeSurface: int): void {
            overlayHost.screen = root.resolveTargetScreen();
            overlayHost.forceActiveFocus();
        }

        function onOverlayClosed(previousSurface: int): void {
            overlayHost.screen = null;
        }
    }

    PanelWindow {
        id: overlayHost

        anchors {
            bottom: true
            left: true
            right: true
            top: true
        }

        color: "transparent"
        visible: OverlayController.isOverlayActive && overlayHost.screen !== null

        WlrLayershell.keyboardFocus: OverlayController.isOverlayActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ctos-overlay"

        Shortcut {
            enabled: OverlayController.isOverlayActive
            sequence: "Escape"

            onActivated: OverlayController.close()
        }

        Rectangle {
            id: scrimVisual

            anchors.fill: parent
            color: Qt.rgba(8 / 255, 8 / 255, 8 / 255, 0.75)
        }

        MouseArea {
            id: scrimBackdrop

            anchors.fill: parent

            onClicked: OverlayController.close()
        }

        Item {
            id: surfaceContainer

            anchors.fill: parent

            Loader {
                id: commandDeckLoader

                anchors.centerIn: parent
                asynchronous: false
                active: true
                visible: OverlayController.activeSurface === OverlayController.Surface.CommandDeck
                source: "desktop/surfaces/CommandDeck.qml"
            }

            Loader {
                id: systemRailLoader

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                asynchronous: false
                active: true
                visible: OverlayController.activeSurface === OverlayController.Surface.SystemRail
                source: "desktop/surfaces/SystemRail.qml"
            }


            Loader {
                id: eventLogLoader

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                asynchronous: false
                source: "desktop/surfaces/PlaceholderSurface.qml"
                visible: OverlayController.activeSurface === OverlayController.Surface.EventLog
            }
        }
    }
}
