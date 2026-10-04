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

        // Four sub-regions covering everything outside the panel, so a click there
        // reaches us and can dismiss. While the CCC is open the window covers the
        // screen, so these have room to exist; while it is closed they are all
        // zero-sized and only the notch and CCC regions remain.
        //
        // Without any region out here the compositor has nothing to deliver an
        // outside click to, so it goes to whatever is underneath and there is no
        // way for us to see it.
        Region {
            x: 0
            y: 0
            width: root.dismissing ? root.dismissLeft : 0
            height: root.dismissing ? root.height : 0
        }
        Region {
            x: root.dismissRight
            y: 0
            width: root.dismissing ? Math.max(0, root.width - root.dismissRight) : 0
            height: root.dismissing ? root.height : 0
        }
        Region {
            x: root.dismissLeft
            y: 0
            width: root.dismissing ? Math.max(0, root.dismissRight - root.dismissLeft) : 0
            height: root.dismissing ? root.dismissTop : 0
        }
        Region {
            x: root.dismissLeft
            y: root.dismissBottom
            width: root.dismissing ? Math.max(0, root.dismissRight - root.dismissLeft) : 0
            height: root.dismissing ? Math.max(0, root.height - root.dismissBottom) : 0
        }

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
    // Height of the bar on its own: the notch, its padding, and the CCC when
    // joined underneath it.
    readonly property real collapsedHeight:
        Math.max(Settings.barHeight, livingNotch.currentHeight)
        + Theme.notchHostPadding
        + (root.isCommandCenterHost ? commandCenterHost.height - root.cccJoinOverlap : 0)

    // While the CCC is open the surface covers the screen instead, so that the
    // backdrop region above has somewhere to live and outside clicks are ours to
    // receive. Anchored to the top with left/right/top set, so this is the full
    // screen minus the 3px top margin.
    implicitHeight: root.isCommandCenterHost && root.screen !== null
        ? root.screen.height
        : root.collapsedHeight

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

    // The notch and the CCC together occupy one axis-aligned box. The dismiss
    // target is everything outside it, so the catcher never overlaps a control.
    //
    // A single full-screen MouseArea with z: -1 was tried first and does not
    // work: the catcher stayed the topmost item under the cursor even at z: -1,
    // so every toggle, list row and power button in the panel was swallowed and
    // the click just closed the panel. z is not a reliable way to put a
    // screen-sized item behind a subtree here, so the geometry is used instead --
    // the catcher simply does not cover the panel.
    readonly property real dismissLeft:
        Math.max(0, Math.min(livingNotch.x, commandCenterHost.x))
    readonly property real dismissRight:
        Math.min(root.width, Math.max(livingNotch.x + livingNotch.width,
                                      commandCenterHost.x + commandCenterHost.width))
    readonly property real dismissTop:
        Math.max(0, Math.min(livingNotch.y, commandCenterHost.y))
    readonly property real dismissBottom:
        Math.min(root.height, Math.max(livingNotch.y + livingNotch.height,
                                       commandCenterHost.y + commandCenterHost.height))

    readonly property bool dismissing: root.isCommandCenterHost

    component DismissArea: MouseArea {
        visible: root.dismissing
        onClicked: OverlayController.handleBackdropClick()
    }

    // Left, right, above and below the panel. Zero-sized while closed, so the
    // desktop is clickable exactly as before.
    DismissArea {
        x: 0
        y: 0
        width: root.dismissLeft
        height: root.height
    }
    DismissArea {
        x: root.dismissRight
        y: 0
        width: Math.max(0, root.width - root.dismissRight)
        height: root.height
    }
    DismissArea {
        x: root.dismissLeft
        y: 0
        width: Math.max(0, root.dismissRight - root.dismissLeft)
        height: root.dismissTop
    }
    DismissArea {
        x: root.dismissLeft
        y: root.dismissBottom
        width: Math.max(0, root.dismissRight - root.dismissLeft)
        height: Math.max(0, root.height - root.dismissBottom)
    }

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

    // How far the panel tucks up under the notch.
    //
    // The design draws the CCC as the notch unfolding: one continuous rounded
    // shape with a divider between the header row and the content, not a pill
    // sitting on a separate panel. Drawn as two shapes they read as two objects,
    // with the notch's rounded bottom corners pinching against the panel's
    // rounded top ones.
    //
    // Overlapping by the notch's own radius hides those corners behind the
    // panel, which is opaque and sits after the notch in stacking order. The
    // two fills are the same navy -- the notch's at 94% alpha, the panel's
    // opaque -- so the covered corners do not show.
    readonly property real cccJoinOverlap: root.isCommandCenterHost ? livingNotch.targetRadius : 0

    Item {
        id: commandCenterHost

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: livingNotch.bottom
        anchors.topMargin: -root.cccJoinOverlap
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

        // The header/content divider from the design. It sits at the notch's
        // lower edge, which after the overlap is this far down the panel.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cccJoinOverlap
            width: parent.width - Theme.paddingXl * 2
            height: Theme.borderWidth
            color: Theme.border
            visible: root.cccJoinOverlap > 0
        }
    }

}
