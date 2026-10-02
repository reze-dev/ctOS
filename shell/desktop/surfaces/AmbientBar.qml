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

    // The CCC lives inside this window rather than in its own. Two
    // layer-shell surfaces cannot read as one: the compositor separates them,
    // so the notch's border and glow cannot wrap continuously across the join
    // and there is a visible seam. Sharing the window is what makes the CCC
    // look like the notch unfolding.
    //
    // Every output has its own AmbientBar, so exactly one of them claims the
    // overlay by matching the screen it was opened on.
    readonly property bool isCommandCenterHost:
        Settings.featuresCommandCenter
        && OverlayController.activeSurface === OverlayController.Surface.CommandCenter
        && OverlayController.hostScreenName !== ""
        && root.screen !== null
        && OverlayController.hostScreenName === root.screen.name

    // Input region: the pill, plus the CCC while it is open.
    //
    // WindowInterface.mask is a single Region, not a list. Multiple rectangles
    // go in as nested Regions inside it -- assigning a JS array to mask fails
    // with "Cannot assign QJSValue to PendingRegion*", because array elements
    // arrive as QJSValue rather than Region pointers.
    //
    // Two sub-regions rather than one union rectangle: a single region spanning
    // the column would make the empty gaps beside the pill and beside the CCC
    // swallow clicks meant for the desktop.
    //
    // Declared inline rather than built with Component.createObject. The
    // created-object form had no access to commandCenterHost, which is declared
    // later in the file, and it could not stay bound as the host animated.
    Region {
        id: windowRegion

        Region {
            id: notchRegion
            x: livingNotch.x
            y: livingNotch.y
            width: livingNotch.width
            height: livingNotch.height
        }

        Region {
            id: cccRegion
            x: commandCenterHost.x
            y: commandCenterHost.y
            width: commandCenterHost.width
            height: commandCenterHost.height
        }
    }

    mask: windowRegion

    Connections {
        target: livingNotch
    }

    // The CCC animating open and closed changes the input region too.
    Connections {
        target: commandCenterHost
    }


    WlrLayershell.namespace: "ctos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand only while the CCC is open. This surface otherwise takes no
    // keyboard input at all, and claiming focus unconditionally would steal
    // keystrokes from the desktop.
    WlrLayershell.keyboardFocus: root.isCommandCenterHost
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None
    implicitHeight: Math.max(Settings.barHeight, livingNotch.currentHeight)
        + Theme.notchHostPadding
        + (root.isCommandCenterHost ? commandCenterHost.height : 0)

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

    // =========================================================================
    // Adaptive Command & Control Center
    //
    // Hosted here rather than in a PanelWindow of its own. Two layer-shell
    // surfaces cannot read as one: the compositor separates them, so the
    // notch's border and glow cannot wrap continuously across the join and
    // there is a visible seam between them. Sharing this window is what makes
    // the CCC look like the notch unfolding rather than a panel appearing.
    //
    // Every output has its own AmbientBar, so exactly one of them claims the
    // overlay by matching the screen it was opened on.
    // =========================================================================

    Item {
        id: commandCenterHost

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: livingNotch.bottom
        width: Math.max(Theme.commandCenterMinWidth,
                         Math.min(Theme.commandCenterWidth, root.width - Theme.spacing2Xl * 4))
        height: root.isCommandCenterHost ? ccc.implicitHeight : 0
        visible: root.isCommandCenterHost
        clip: false

        Behavior on height {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutCubic
            }
        }

        CommandCenter {
            id: ccc
            width: parent.width
            visible: root.isCommandCenterHost
        }
    }

}
