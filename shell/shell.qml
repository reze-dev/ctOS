pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

import "desktop/adapters/hyprland"
import "desktop/core"
import "desktop/services"
import "desktop/surfaces"
import "desktop/surfaces/components"
import "desktop/surfaces/widgets"

Scope {
    id: root

    property bool calendarVisible: false
    property var calendarScreen: null

    property bool bluetoothVisible: false
    property var bluetoothScreen: null

    property bool networkVisible: false
    property var networkScreen: null

    function toggleCalendar(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : root.resolveTargetScreen();

        if (root.calendarVisible) {
            if (targetScreen === null || targetScreen === undefined || root.calendarScreen === resolved) {
                root.calendarVisible = false;
                root.calendarScreen = null;
            } else {
                root.calendarScreen = resolved;
            }
        } else {
            root.closeBluetooth();
            root.closeNetwork();
            root.calendarScreen = resolved;
            root.calendarVisible = true;
        }
    }

    function closeCalendar(): void {
        root.calendarVisible = false;
        root.calendarScreen = null;
    }

    function toggleBluetooth(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : root.resolveTargetScreen();

        if (root.bluetoothVisible) {
            if (targetScreen === null || targetScreen === undefined || root.bluetoothScreen === resolved) {
                root.bluetoothVisible = false;
                root.bluetoothScreen = null;
            } else {
                root.bluetoothScreen = resolved;
            }
        } else {
            root.closeCalendar();
            root.closeNetwork();
            root.bluetoothScreen = resolved;
            root.bluetoothVisible = true;
        }
    }

    function closeBluetooth(): void {
        root.bluetoothVisible = false;
        root.bluetoothScreen = null;
    }

    function toggleNetwork(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : root.resolveTargetScreen();

        if (root.networkVisible) {
            if (targetScreen === null || targetScreen === undefined || root.networkScreen === resolved) {
                root.networkVisible = false;
                root.networkScreen = null;
            } else {
                root.networkScreen = resolved;
            }
        } else {
            root.closeCalendar();
            root.closeBluetooth();
            root.networkScreen = resolved;
            root.networkVisible = true;
        }
    }

    function closeNetwork(): void {
        root.networkVisible = false;
        root.networkScreen = null;
    }

    function closeAllPopups(): void {
        root.closeCalendar();
        root.closeBluetooth();
        root.closeNetwork();
    }

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

        function toggleEventLog(): void {
            OverlayController.toggleEventLog();
        }

        function toggleCalendar(): void {
            root.toggleCalendar(null);
        }

        function toggleBluetooth(): void {
            root.toggleBluetooth(null);
        }

        function toggleNetwork(): void {
            root.toggleNetwork(null);
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
                    // Default fallback: top: Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl)
                    top: Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl))
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
                    top: Settings.getWidgetAnchor("audioSurveillance", "top", true)
                    bottom: Settings.getWidgetAnchor("audioSurveillance", "bottom", false)
                    left: Settings.getWidgetAnchor("audioSurveillance", "left", false)
                    right: Settings.getWidgetAnchor("audioSurveillance", "right", true)
                }
                margins {
                    top: Settings.hasWidgetMargin("audioSurveillance", "top") ? Settings.getWidgetMargin("audioSurveillance", "top", 0) : (Theme.barHeight + Theme.spacingXl + (Settings.widgetCpuHexGridVisible ? 200 + Theme.spacingXl : 0) + (Settings.widgetRamBlockBarVisible ? 110 + Theme.spacingXl : 0))
                    bottom: Settings.getWidgetMargin("audioSurveillance", "bottom", 0)
                    left: Settings.getWidgetMargin("audioSurveillance", "left", 0)
                    right: Settings.getWidgetMargin("audioSurveillance", "right", Theme.spacing2Xl)
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

                onToggleCalendar: root.toggleCalendar(modelData)
                onToggleBluetooth: root.toggleBluetooth(modelData)
                onToggleNetwork: root.toggleNetwork(modelData)
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

            if (root.calendarVisible) {
                const currentCalScreen = root.calendarScreen;
                if (!currentCalScreen) {
                    root.closeCalendar();
                    return;
                }

                const screenList = Quickshell.screens;
                let isCalAlive = false;
                for (let i = 0; i < screenList.length; ++i) {
                    if (screenList[i] && screenList[i].name === currentCalScreen.name) {
                        isCalAlive = true;
                        break;
                    }
                }

                if (!isCalAlive) {
                    root.closeCalendar();
                }
            }

            if (root.bluetoothVisible) {
                const currentBtScreen = root.bluetoothScreen;
                if (!currentBtScreen) {
                    root.closeBluetooth();
                    return;
                }

                const screenList = Quickshell.screens;
                let isBtAlive = false;
                for (let i = 0; i < screenList.length; ++i) {
                    if (screenList[i] && screenList[i].name === currentBtScreen.name) {
                        isBtAlive = true;
                        break;
                    }
                }

                if (!isBtAlive) {
                    root.closeBluetooth();
                }
            }

            if (root.networkVisible) {
                const currentNetScreen = root.networkScreen;
                if (!currentNetScreen) {
                    root.closeNetwork();
                    return;
                }

                const screenList = Quickshell.screens;
                let isNetAlive = false;
                for (let i = 0; i < screenList.length; ++i) {
                    if (screenList[i] && screenList[i].name === currentNetScreen.name) {
                        isNetAlive = true;
                        break;
                    }
                }

                if (!isNetAlive) {
                    root.closeNetwork();
                }
            }
        }
    }

    Connections {
        target: OverlayController

        function onOverlayOpened(activeSurface: int): void {
            root.closeCalendar();
            root.closeBluetooth();
            root.closeNetwork();
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
                source: "desktop/surfaces/EventLog.qml"
                visible: OverlayController.activeSurface === OverlayController.Surface.EventLog
            }
        }
    }

    PanelWindow {
        id: notificationToastHost
        screen: root.resolveTargetScreen()
        color: "transparent"
        visible: NotificationService.activeToasts.count > 0
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-notifications"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Settings.barHeight + Theme.spacingMedium
            right: Theme.spacingMedium
        }

        implicitWidth: 360
        implicitHeight: toastStack.implicitHeight

        NotificationToasts {
            id: toastStack
            width: 340
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    PanelWindow {
        id: calendarBackdropHost

        screen: root.calendarScreen
        color: "transparent"
        visible: root.calendarVisible && root.calendarScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-calendar-backdrop"

        anchors {
            bottom: true
            left: true
            right: true
            top: true
        }

        MouseArea {
            id: calendarBackdropMouseArea

            anchors.fill: parent

            onClicked: root.closeCalendar()
        }
    }

    PanelWindow {
        id: calendarPopupHost

        screen: root.calendarScreen
        color: "transparent"
        visible: root.calendarVisible && root.calendarScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-calendar-popup"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Settings.barHeight + Theme.spacingMedium
            right: Theme.barPaddingHorizontal
        }

        implicitWidth: calendarPopup.implicitWidth
        implicitHeight: calendarPopup.implicitHeight

        CalendarPopup {
            id: calendarPopup

            onCloseRequested: root.closeCalendar()
        }
    }

    PanelWindow {
        id: bluetoothBackdropHost

        screen: root.bluetoothScreen
        color: "transparent"
        visible: root.bluetoothVisible && root.bluetoothScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-bluetooth-backdrop"

        anchors {
            bottom: true
            left: true
            right: true
            top: true
        }

        MouseArea {
            id: bluetoothBackdropMouseArea

            anchors.fill: parent

            onClicked: root.closeBluetooth()
        }
    }

    PanelWindow {
        id: bluetoothPopupHost

        screen: root.bluetoothScreen
        color: "transparent"
        visible: root.bluetoothVisible && root.bluetoothScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-bluetooth-popup"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Settings.barHeight + Theme.spacingMedium
            right: Theme.barPaddingHorizontal + 60
        }

        implicitWidth: bluetoothPopup.implicitWidth
        implicitHeight: bluetoothPopup.implicitHeight

        BluetoothPopup {
            id: bluetoothPopup

            onCloseRequested: root.closeBluetooth()
        }
    }

    PanelWindow {
        id: networkBackdropHost

        screen: root.networkScreen
        color: "transparent"
        visible: root.networkVisible && root.networkScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-network-backdrop"

        anchors {
            bottom: true
            left: true
            right: true
            top: true
        }

        MouseArea {
            id: networkBackdropMouseArea

            anchors.fill: parent

            onClicked: root.closeNetwork()
        }
    }

    PanelWindow {
        id: networkPopupHost

        screen: root.networkScreen
        color: "transparent"
        visible: root.networkVisible && root.networkScreen !== null
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-network-popup"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Settings.barHeight + Theme.spacingMedium
            right: Theme.barPaddingHorizontal + 160
        }

        implicitWidth: networkPopup.implicitWidth
        implicitHeight: networkPopup.implicitHeight

        NetworkPopup {
            id: networkPopup

            onCloseRequested: root.closeNetwork()
        }
    }

    PanelWindow {
        id: packetAnalyzerHost
        
        screen: root.resolveTargetScreen()
        color: "transparent"
        visible: Settings.widgetPacketAnalyzerVisible
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ctos-packet-analyzer"

        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: Theme.spacingMedium
            left: Theme.spacingMedium
        }

        implicitWidth: packetAnalyzerWidget.implicitWidth
        implicitHeight: packetAnalyzerWidget.implicitHeight

        PacketAnalyzerWidget {
            id: packetAnalyzerWidget
        }
    }
}
