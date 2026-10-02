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

    // Which card a sub-surface request asked for ("power", "wifi"). Applied on
    // open and then cleared, so it does not keep overriding the user's own
    // expand and collapse afterwards.
    property string requestedCard: ""

    // Cards default to open: the design shows the whole panel at once, and these
    // bodies are sized to fit. Assignment rather than binding, because Card
    // owns its own expanded state.
    function applyRequestedCard(): void {
        if (requestedCard === "")
            return;

        if (requestedCard === "notifications")      cardNotifications.expanded = true;
        else if (requestedCard === "wifi")         cardConnectivity.expanded = true;
        else if (requestedCard === "bluetooth")    cardBluetooth.expanded = true;
        else if (requestedCard === "audio")        cardAudio.expanded = true;
        else if (requestedCard === "power")        cardPower.expanded = true;
        else if (requestedCard === "calendar")     cardCalendar.expanded = true;

        requestedCard = "";
    }

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
            root.applyRequestedCard();

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
                    title: NotificationService.history.count > 0
                        ? qsTr("Notifications (%1)").arg(NotificationService.history.count)
                        : qsTr("Notifications")
                    icon: "bell"
                    accent: Theme.accentBlue
                    collapsible: true

                    action: Component {
                        ToggleSwitch {
                            checked: !NotificationService.doNotDisturb
                            onToggled: NotificationService.toggleDnd()
                        }
                    }

                    contentComponent: Component {
                        Item {
                            id: notifBodyRoot
                            width: parent ? parent.width : undefined

                            // Stated explicitly rather than read back from the
                            // Column below.
                            //
                            // Deriving this from notifColumn.implicitHeight
                            // evaluates once, while the Column's children are
                            // still being constructed, and then sticks at 0 --
                            // the card silently renders with no body at all.
                            // For a fixed set of three known children, summing
                            // their heights here is both reliable and clearer
                            // than asking a positioner to measure itself.
                            readonly property bool hasAny:
                                NotificationService.history.count > 0

                            implicitHeight: (hasAny
                                    ? Math.min(208, notifList.contentHeight)
                                    : 0)
                                + (hasAny ? 22 : 0)          // clear-all row
                                + (hasAny ? 0 : 52)          // empty state
                                + Theme.spacingSmall * 2
                            height: implicitHeight

                            Column {
                                id: notifColumn
                                width: parent.width
                                spacing: Theme.spacingSmall

                                // Capped so a burst of notifications cannot
                                // push the other cards off the panel. The list
                                // scrolls past the cap on its own.
                                ListView {
                                    id: notifList
                                    width: parent.width
                                    // Column measures its children's
                                    // implicitHeight, not their height, so the
                                    // list has to declare both or the card
                                    // measures as empty.
                                    implicitHeight: Math.min(contentHeight, 208)
                                    height: implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: Theme.spacingSmall
                                    model: NotificationService.history
                                    visible: count > 0

                                    delegate: Rectangle {
                                        id: notifRow
                                        required property int index
                                        required property string appName
                                        required property string summary
                                        required property string body
                                        required property int urgency
                                        required property string timestamp

                                        width: notifList.width
                                        height: notifBody.implicitHeight + Theme.spacingMedium * 2
                                        radius: Theme.radiusMedium
                                        color: notifHover.containsMouse ? Theme.surfaceHover : Theme.surfaceElevated
                                        border.width: Theme.borderWidth
                                        border.color: Theme.border

                                        Behavior on color {
                                            ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
                                        }

                                        // Critical is red, normal is structural blue,
                                        // low is dim. The previous mapping used
                                        // acidGreen for normal, which is a magenta
                                        // alias and made every routine
                                        // notification look like an alert.
                                        readonly property color urgencyColor:
                                            urgency === 2 ? Theme.destructive
                                            : urgency === 0 ? Theme.textDisabled
                                            : Theme.accentBlue

                                        MouseArea {
                                            id: notifHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }

                                        // Urgency stripe down the leading edge.
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 2
                                            height: parent.height - Theme.spacingMedium
                                            radius: 1
                                            color: notifRow.urgencyColor
                                        }

                                        // App badge. Reference shows a per-app
                                        // mark; we have no app icon pipeline here,
                                        // so the initial stands in.
                                        Rectangle {
                                            id: notifBadge
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingMedium
                                            anchors.top: parent.top
                                            anchors.topMargin: Theme.spacingMedium
                                            width: 18
                                            height: 18
                                            radius: Theme.radiusSmall
                                            color: notifRow.urgencyColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: notifRow.appName.length > 0
                                                    ? notifRow.appName.charAt(0).toUpperCase() : "?"
                                                color: Theme.navyDeep
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeCaption
                                                font.weight: Theme.fontWeightBold
                                            }
                                        }

                                        Column {
                                            id: notifBody
                                            anchors.left: notifBadge.right
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.right: dismissButton.left
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.top: parent.top
                                            anchors.topMargin: Theme.spacingSmall
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: notifRow.summary
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Theme.fontWeightDemiBold
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: notifRow.appName + "  " + notifRow.timestamp
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamilyMonospace
                                                font.pixelSize: Theme.fontSizeCaption
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                visible: notifRow.body.length > 0
                                                text: notifRow.body
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeSmall
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        Text {
                                            id: dismissButton
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.top: parent.top
                                            anchors.topMargin: Theme.spacingSmall
                                            width: 16
                                            height: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: "\u2715"
                                            color: notifHover.containsMouse ? Theme.textPrimary : Theme.textDisabled
                                            font.pixelSize: Theme.fontSizeSmall

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotificationService.dismissHistoryItem(notifRow.index)
                                            }
                                        }
                                    }
                                }

                                // Empty state.
                                Item {
                                    width: parent.width
                                    implicitHeight: visible ? 52 : 0
                                    height: implicitHeight
                                    visible: NotificationService.history.count === 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: NotificationService.doNotDisturb
                                            ? qsTr("Do not disturb is on")
                                            : qsTr("Nothing new")
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }

                                // Clear all, only when there is something to
                                // clear -- an always-present button on an empty
                                // list is a control that can do nothing.
                                Item {
                                    width: parent.width
                                    implicitHeight: visible ? 22 : 0
                                    height: implicitHeight
                                    visible: NotificationService.history.count > 0

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Clear all")
                                        color: clearHover.containsMouse ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Theme.fontWeightDemiBold

                                        MouseArea {
                                            id: clearHover
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NotificationService.clearAll()
                                        }
                                    }
                                }
                            }
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
                    subtitle: PowerService.isBatteryPresent
                        ? Math.round(PowerService.percentage) + "%  "
                          + (PowerService.isCharging ? qsTr("Charging") : PowerService.stateText)
                        : ""
                    icon: "power"
                    accent: Theme.accentMagenta
                    collapsible: true

                    // Lock runs immediately -- it is reversible. The other three
                    // end the session, so they ask first.
                    readonly property var actions: [
                        { key: "lock",      label: qsTr("Lock"),      glyph: "lock",   danger: false },
                        { key: "logout",    label: qsTr("Logout"),    glyph: "logout", danger: false },
                        { key: "reboot",    label: qsTr("Reboot"),    glyph: "reboot", danger: false },
                        { key: "poweroff",  label: qsTr("Poweroff"),  glyph: "power",  danger: true }
                    ]

                    property string pendingAction: ""

                    readonly property bool isConfirming: pendingAction !== ""

                    function requestAction(key: string): void {
                        if (key === "lock") {
                            SessionService.executeAction(key);
                        } else {
                            root.pendingAction = key;
                        }
                    }

                    // Label for the pending action, for the confirmation
                    // prompt.
                    //
                    // Written as a lookup rather than inline
                    // `actions.filter(...)[0]?.label`: QML's JavaScript engine
                    // does not support optional chaining, and the failure is
                    // silent -- the binding just evaluates to nothing and the
                    // prompt renders with no question in it.
                    function actionLabel(key: string): string {
                        for (let i = 0; i < cardPower.actions.length; ++i) {
                            if (cardPower.actions[i].key === key)
                                return cardPower.actions[i].label;
                        }
                        return key;
                    }

                    function cancelConfirmation(): void {
                        root.pendingAction = "";
                    }

                    function confirmAction(): void {
                        const action = root.pendingAction;
                        root.pendingAction = "";
                        if (action !== "")
                            SessionService.executeAction(action);
                    }

                    Keys.onEscapePressed: function (event) {
                        if (cardPower.isConfirming) {
                            event.accepted = true;
                            cardPower.cancelConfirmation();
                        }
                    }

                    contentComponent: Component {
                        Item {
                            width: parent ? parent.width : undefined
                            implicitHeight: 76
                            height: 76

                            // Confirmation replaces the tiles rather than
                            // stacking below them, so asking to power off does not
                            // push the layout around underneath the question.
                            Row {
                                id: tileRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: Theme.spacingSmall
                                visible: !cardPower.isConfirming

                                Repeater {
                                    model: cardPower.actions
                                    delegate: Rectangle {
                                        id: tile
                                        required property var modelData
                                        width: (tileRow.width - Theme.spacingSmall * 3) / 4
                                        height: 64
                                        radius: Theme.radiusMedium

                                        readonly property color tileColor:
                                            modelData.danger ? Theme.destructive : Theme.surfaceElevated

                                        color: modelData.danger
                                            ? tileColor
                                            : (tileHover.containsMouse ? Theme.surfaceHover : tileColor)
                                        border.width: Theme.borderWidth
                                        border.color: modelData.danger
                                            ? tileColor
                                            : (tileHover.containsMouse ? Theme.borderHover : Theme.border)

                                        Behavior on color {
                                            ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
                                        }

                                        // Busy state: whichever action is running
                                        // shows as disabled rather than allowing a
                                        // second session command to be queued.
                                        readonly property bool busy:
                                            (modelData.key === "lock"      && SessionService.isLocking)
                                         || (modelData.key === "logout"    && SessionService.isLoggingOut)
                                         || (modelData.key === "reboot"    && SessionService.isRebooting)
                                         || (modelData.key === "poweroff"  && SessionService.isPoweringOff)

                                        opacity: tile.busy ? 0.5 : 1.0

                                        GlyphIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            anchors.topMargin: Theme.spacingMedium
                                            width: 20
                                            height: 20
                                            glyph: tile.modelData.glyph
                                            color: tile.modelData.danger
                                                ? Theme.textPrimary
                                                : (tileHover.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Theme.spacingSmall
                                            text: tile.modelData.label
                                            color: tile.modelData.danger
                                                ? Theme.textPrimary
                                                : (tileHover.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightDemiBold
                                        }

                                        MouseArea {
                                            id: tileHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !tile.busy
                                            onClicked: cardPower.requestAction(tile.modelData.key)
                                        }
                                    }
                                }
                            }

                            // Confirmation row. The question is anchored left
                            // and the buttons right, rather than sharing a Row,
                            // so the label can take whatever width is left over
                            // instead of guessing the buttons' width.
                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 64
                                visible: cardPower.isConfirming

                                Text {
                                    id: confirmLabel
                                    anchors.left: parent.left
                                    anchors.right: confirmButtons.left
                                    anchors.rightMargin: Theme.spacingMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: cardPower.actionLabel(cardPower.pendingAction) + "?"
                                    color: Theme.destructive
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSizeBody
                                    font.weight: Theme.fontWeightDemiBold
                                    elide: Text.ElideRight
                                }

                                Row {
                                    id: confirmButtons
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingSmall

                                    Rectangle {
                                        width: 84
                                        height: 40
                                        radius: Theme.radiusMedium
                                        color: cancelHover.containsMouse ? Theme.surfaceHover : "transparent"
                                        border.width: Theme.borderWidth
                                        border.color: Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Cancel")
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeSmall
                                        }

                                        MouseArea {
                                            id: cancelHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardPower.cancelConfirmation()
                                        }
                                    }

                                    Rectangle {
                                        width: 84
                                        height: 40
                                        radius: Theme.radiusMedium
                                        color: confirmHover.containsMouse
                                               ? Qt.lighter(Theme.destructive, 1.15)
                                               : Theme.destructive
                                        border.width: Theme.borderWidth
                                        border.color: Theme.destructive

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Confirm")
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Theme.fontWeightDemiBold
                                        }

                                        MouseArea {
                                            id: confirmHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardPower.confirmAction()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Card {
                    id: cardCalendar
                    width: parent.width
                    title: qsTr("Calendar & Events")
                    icon: "calendar"
                    accent: Theme.accentBlue
                    collapsible: true
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