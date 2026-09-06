import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "desktop/adapters/hyprland"
import "desktop/core"
import "desktop/services"
import "desktop/surfaces"

Scope {
    id: root

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
                active: OverlayController.activeSurface === OverlayController.Surface.CommandDeck
                visible: active
                source: "desktop/surfaces/CommandDeck.qml"
            }

            Loader {
                id: systemRailLoader

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                asynchronous: false
                active: OverlayController.activeSurface === OverlayController.Surface.SystemRail
                visible: active
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
