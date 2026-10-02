import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "./components"

PanelWindow {
    id: root

    signal toggleCalendar
    signal toggleBluetooth
    signal toggleNetwork

    property bool _closingFromShell: false

    function closeCalendar(): void {
        root._closingFromShell = true;
        if (livingNotch && typeof livingNotch.closeCalendar === "function") {
            livingNotch.closeCalendar();
        }
        root._closingFromShell = false;
    }

    color: "transparent"

    property bool toggleMask: false

    Component {
        id: maskComponent
        Region {
            Region {
                x: livingNotch.x
                y: livingNotch.y
                width: livingNotch.width
                height: livingNotch.height
            }
        }
    }

    property var maskA: maskComponent.createObject(root)
    property var maskB: maskComponent.createObject(root)

    mask: toggleMask ? maskA : maskB

    function flushWaylandMask() {
        toggleMask = !toggleMask;
    }

    Connections {
        target: livingNotch
        function onWidthChanged() { root.flushWaylandMask(); }
        function onHeightChanged() { root.flushWaylandMask(); }
        function onXChanged() { root.flushWaylandMask(); }
        function onYChanged() { root.flushWaylandMask(); }
    }

    Component.onCompleted: {
        root.flushWaylandMask();
    }

    WlrLayershell.namespace: "ctos-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitHeight: Math.max(Settings.barHeight, livingNotch.currentHeight) + Theme.notchHostPadding

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        top: true
    }

    margins {
        top: 3
    }

    // =========================================================================
    // Active Living Notch Component
    // =========================================================================

    LivingNotch {
        id: livingNotch

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        monitorName: (root.screen && root.screen.name) ? root.screen.name : ""

        onOpenCommandDeckRequested: OverlayController.openCommandDeck()
        onToggleCommandCenterRequested: OverlayController.toggleCommandCenter()
        onToggleNetworkRequested: root.toggleNetwork()
        onToggleBluetoothRequested: root.toggleBluetooth()
        onCalendarToggled: (isOpen) => {
            if (!root._closingFromShell) {
                root.toggleCalendar();
            }
        }
    }

}
