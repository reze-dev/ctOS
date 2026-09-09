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
                    top: Settings.getWidgetAnchor("cpuHexGrid", "top", true)
                    bottom: Settings.getWidgetAnchor("cpuHexGrid", "bottom", false)
                    left: Settings.getWidgetAnchor("cpuHexGrid", "left", false)
                    right: Settings.getWidgetAnchor("cpuHexGrid", "right", true)
                }
                margins {
                    top: Settings.getWidgetMargin("cpuHexGrid", "top", Theme.barHeight + Theme.spacingXl)
                    bottom: Settings.getWidgetMargin("cpuHexGrid", "bottom", 0)
                    left: Settings.getWidgetMargin("cpuHexGrid", "left", 0)
                    right: Settings.getWidgetMargin("cpuHexGrid", "right", Theme.spacing2Xl)
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
                    top: Settings.getWidgetAnchor("ramBlockBar", "top", true)
                    bottom: Settings.getWidgetAnchor("ramBlockBar", "bottom", false)
                    left: Settings.getWidgetAnchor("ramBlockBar", "left", false)
                    right: Settings.getWidgetAnchor("ramBlockBar", "right", true)
                }
                margins {
                    // Default fallback: top: Settings.widgetCpuHexGridVisible ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl)
                    top: Settings.hasWidgetMargin("ramBlockBar", "top") ? Settings.getWidgetMargin("ramBlockBar", "top", 0) : (Settings.widgetCpuHexGridVisible ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl))
                    bottom: Settings.getWidgetMargin("ramBlockBar", "bottom", 0)
                    left: Settings.getWidgetMargin("ramBlockBar", "left", 0)
                    right: Settings.getWidgetMargin("ramBlockBar", "right", Theme.spacing2Xl)
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

                // Default anchor fallback: anchors { bottom: true right: true }
                anchors {
                    top: Settings.getWidgetAnchor("networkFlow", "top", false)
                    bottom: Settings.getWidgetAnchor("networkFlow", "bottom", true)
                    left: Settings.getWidgetAnchor("networkFlow", "left", false)
                    right: Settings.getWidgetAnchor("networkFlow", "right", true)
                }
                margins {
                    top: Settings.getWidgetMargin("networkFlow", "top", 0)
                    bottom: Settings.getWidgetMargin("networkFlow", "bottom", Theme.spacing2Xl)
                    left: Settings.getWidgetMargin("networkFlow", "left", 0)
                    right: Settings.getWidgetMargin("networkFlow", "right", Theme.spacing2Xl)
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
        id: targetProfilerVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: targetProfilerWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetTargetProfilerVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    top: Settings.getWidgetAnchor("targetProfiler", "top", true)
                    bottom: Settings.getWidgetAnchor("targetProfiler", "bottom", false)
                    left: Settings.getWidgetAnchor("targetProfiler", "left", true)
                    right: Settings.getWidgetAnchor("targetProfiler", "right", false)
                }
                margins {
                    top: Settings.getWidgetMargin("targetProfiler", "top", Theme.barHeight + Theme.spacingXl)
                    bottom: Settings.getWidgetMargin("targetProfiler", "bottom", 0)
                    left: Settings.getWidgetMargin("targetProfiler", "left", Theme.spacing2Xl)
                    right: Settings.getWidgetMargin("targetProfiler", "right", 0)
                }

                implicitWidth: targetProfilerWidget.implicitWidth
                implicitHeight: targetProfilerWidget.implicitHeight

                TargetProfilerWidget {
                    id: targetProfilerWidget
                    anchors.fill: parent
                }
            }
        }
    }

    Variants {
        id: networkTracerVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: networkTracerWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetNetworkTracerVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    top: Settings.getWidgetAnchor("networkTracer", "top", true)
                    bottom: Settings.getWidgetAnchor("networkTracer", "bottom", false)
                    left: Settings.getWidgetAnchor("networkTracer", "left", true)
                    right: Settings.getWidgetAnchor("networkTracer", "right", false)
                }
                margins {
                    top: Settings.getWidgetMargin("networkTracer", "top", Theme.barHeight + Theme.spacingXl + 230 + Theme.spacingXl)
                    bottom: Settings.getWidgetMargin("networkTracer", "bottom", 0)
                    left: Settings.getWidgetMargin("networkTracer", "left", Theme.spacing2Xl)
                    right: Settings.getWidgetMargin("networkTracer", "right", 0)
                }

                implicitWidth: networkTracerWidget.implicitWidth
                implicitHeight: networkTracerWidget.implicitHeight

                NetworkTracerWidget {
                    id: networkTracerWidget
                    anchors.fill: parent
                }
            }
        }
    }

    Variants {
        id: audioSurveillanceVariants

        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: audioSurveillanceWindow

                required property var modelData

                screen: modelData
                color: "transparent"
                visible: Settings.widgetAudioSurveillanceVisible
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "ctos-widgets"

                anchors {
                    top: Settings.getWidgetAnchor("audioSurveillance", "top", false)
                    bottom: Settings.getWidgetAnchor("audioSurveillance", "bottom", true)
                    left: Settings.getWidgetAnchor("audioSurveillance", "left", true)
                    right: Settings.getWidgetAnchor("audioSurveillance", "right", false)
                }
                margins {
                    top: Settings.getWidgetMargin("audioSurveillance", "top", 0)
                    bottom: Settings.getWidgetMargin("audioSurveillance", "bottom", Theme.spacing2Xl)
                    left: Settings.getWidgetMargin("audioSurveillance", "left", Theme.spacing2Xl)
                    right: Settings.getWidgetMargin("audioSurveillance", "right", 0)
                }

                implicitWidth: audioSurveillanceWidget.implicitWidth
                implicitHeight: audioSurveillanceWidget.implicitHeight

                AudioSurveillanceWidget {
                    id: audioSurveillanceWidget
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
