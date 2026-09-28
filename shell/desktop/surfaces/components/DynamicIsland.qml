pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../services"
import "../widgets"

Rectangle {
    id: root

    // =========================================================================
    // Dynamic Island State & Dimensions
    // =========================================================================

    readonly property real compactWidth: 120
    readonly property real expandedWidth: 300
    readonly property real eventLogWidth: 360
    readonly property real eventLogHeight: 500

    // Three-state property: "compact", "notification", "eventLog"
    property string state: "compact"

    // Writable isExpanded for backward compatibility with tests.
    // Tests directly set isExpanded = true/false, so we keep it writable
    // and sync it with the state property.
    property bool isExpanded: false

    property string latestAppName: ""
    property string latestSummary: ""
    property int latestUrgency: 1
    readonly property bool isEventLogOpen: OverlayController.activeSurface === OverlayController.Surface.EventLog

    // Sync isExpanded writes → state
    onIsExpandedChanged: {
        if (root.isExpanded && root.state === "compact") {
            root.state = "notification";
        } else if (!root.isExpanded && root.state === "notification") {
            root.state = "compact";
        }
    }

    // Sync state → isExpanded (for notification state changes from showNotification)
    onStateChanged: {
        if (root.state === "notification" && !root.isExpanded) {
            root.isExpanded = true;
        } else if (root.state === "compact" && root.isExpanded) {
            root.isExpanded = false;
        }
    }

    // Centralized layout function per dynamic-radial-geometry skill:
    // Synchronously compute width/height based on state to avoid desync.
    function _computeLayout(): var {
        if (root.state === "eventLog") {
            return { w: root.eventLogWidth, h: root.eventLogHeight };
        } else if (root.state === "notification") {
            return { w: root.expandedWidth, h: Theme.barHeight - 6 };
        } else {
            return { w: root.compactWidth, h: Theme.barHeight - 6 };
        }
    }

    property var _layout: _computeLayout()

    width: _layout.w
    implicitWidth: width
    height: _layout.h
    implicitHeight: height

    color: Theme.background
    radius: Theme.radiusMedium
    border.color: mouseArea.containsMouse && root.state !== "eventLog" ? Theme.accent : Theme.borderMuted
    border.width: Theme.borderWidth
    clip: true

    // =========================================================================
    // Expansion / Collapse Animation
    // =========================================================================

    Behavior on width {
        NumberAnimation {
            duration: Settings.reducedMotion ? 0 : Theme.durationSlow
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Settings.reducedMotion ? 0 : Theme.durationSlow
            easing.type: Easing.InOutQuad
        }
    }

    // Auto-collapse after 4 seconds (only for notification state)
    Timer {
        id: collapseTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root.isExpanded = false;
        }
    }

    // Public method to trigger notification expansion
    function showNotification(appName: string, summary: string, urgency: int): void {
        root.latestAppName = appName || "System";
        root.latestSummary = summary || "";
        root.latestUrgency = (urgency !== undefined) ? urgency : 1;
        root.isExpanded = true;
        collapseTimer.restart();
    }

    // =========================================================================
    // NotificationService Connection
    // =========================================================================

    Connections {
        target: NotificationService

        // Handles explicit signal if present
        function onNotificationReceived(notification): void {
            if (!NotificationService.doNotDisturb && notification) {
                root.showNotification(notification.appName, notification.summary, notification.urgency);
            }
        }
    }

    // Fallback: watch history insertions in case notificationReceived signal isn't emitted
    Connections {
        target: NotificationService.history

        function onRowsInserted(parentIndex, first, last): void {
            if (!root.isExpanded && !NotificationService.doNotDisturb && first === 0 && NotificationService.history.count > 0) {
                const item = NotificationService.history.get(0);
                if (item) {
                    root.showNotification(item.appName, item.summary, item.urgency);
                }
            }
        }
    }

    // =========================================================================
    // OverlayController Connection — react to external close
    // =========================================================================

    Connections {
        target: OverlayController

        function onOverlayClosed(previousSurface: int): void {
            if (previousSurface === OverlayController.Surface.EventLog && root.state === "eventLog") {
                root.state = "compact";
            }
        }

        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.EventLog && root.state === "eventLog") {
                root.forceActiveFocus();
            }
        }
    }

    // =========================================================================
    // Keyboard Handling (Escape to close eventLog)
    // =========================================================================

    Keys.onEscapePressed: function (event) {
        if (root.state === "eventLog") {
            OverlayController.close();
            if (event) {
                event.accepted = true;
            }
        }
    }

    // =========================================================================
    // Compact View
    // =========================================================================

    RowLayout {
        id: compactContent
        anchors.centerIn: parent
        opacity: root.state === "compact" ? 1.0 : 0.0
        visible: opacity > 0.0
        spacing: Theme.spacingSmall

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        // State 1: DND active
        Text {
            id: dndIndicator
            visible: NotificationService.doNotDisturb
            text: "[DND]"
            color: Theme.warningRed
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
        }

        // State 2: Active unread notifications (when not DND)
        Rectangle {
            id: unreadDot
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount > 0
            width: 6
            height: 6
            radius: 3
            color: Theme.acidGreen
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: unreadText
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount > 0
            text: NotificationService.unreadCount + " NOTIF"
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
        }

        // State 3: Idle standby (no notifications and not DND)
        Rectangle {
            id: idleDot
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount === 0
            width: 6
            height: 6
            radius: 3
            color: Theme.acidGreen
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: idleText
            visible: !NotificationService.doNotDisturb && NotificationService.unreadCount === 0
            text: "// IDLE"
            color: Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
        }
    }

    // =========================================================================
    // Expanded View (Active Notification Banner)
    // =========================================================================

    RowLayout {
        id: expandedContent
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        opacity: root.state === "notification" ? 1.0 : 0.0
        visible: opacity > 0.0
        spacing: Theme.spacingSmall

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 6
            height: 6
            radius: 3
            color: root.latestUrgency === 2 ? Theme.warningRed : Theme.acidGreen
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.latestAppName
            color: Theme.textSecondary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "»"
            color: Theme.textMuted
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: root.latestSummary
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Theme.fontWeightNormal
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    // =========================================================================
    // Event Log View (Embedded — morphs from DynamicIsland)
    // =========================================================================

    property int eventLogCurrentTab: 0

    // Corner Brackets decoration (cyber aesthetic) — visible only in eventLog state
    CornerBrackets {
        id: cornerBrackets
        bracketColor: Theme.acidGreen
        margin: Theme.cornerBracketMargin
        armLength: Theme.cornerBracketArmLength
        thickness: Theme.cornerBracketThickness
        z: 10
        opacity: root.state === "eventLog" ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }
    }

    // Event Log Content
    Item {
        id: eventLogContent
        anchors.fill: parent
        opacity: root.state === "eventLog" ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationFast
            }
        }

        // Inside Click Consumer — prevent clicks from falling through
        MouseArea {
            id: eventLogInsideClickConsumer
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        // Main Content Column
        ColumnLayout {
            id: eventLogMainLayout
            anchors.fill: parent
            anchors.margins: Theme.paddingXl
            spacing: Theme.spacingMedium

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Rectangle {
                    Layout.preferredHeight: 8
                    Layout.preferredWidth: 8
                    color: Theme.accent
                    radius: 4
                }

                Text {
                    Layout.fillWidth: true
                    color: Theme.accent
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSegment
                    font.weight: Theme.fontWeightBold
                    text: "// EVENT LOG"
                }

                // DND Toggle Button
                Rectangle {
                    id: eventLogDndButton
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: eventLogDndLabel.implicitWidth + Theme.paddingMedium * 2
                    border.color: NotificationService.doNotDisturb ? Theme.warningRed : (eventLogDndMouseArea.containsMouse ? Theme.accent : Theme.borderMuted)
                    border.width: Theme.borderWidth
                    color: NotificationService.doNotDisturb ? Theme.surfaceSelected : (eventLogDndMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                    radius: Theme.radiusSmall

                    Text {
                        id: eventLogDndLabel
                        anchors.centerIn: parent
                        color: NotificationService.doNotDisturb ? Theme.warningRed : (eventLogDndMouseArea.containsMouse ? Theme.accent : Theme.textSecondary)
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: NotificationService.doNotDisturb ? "[DND]" : "[DND OFF]"
                    }

                    MouseArea {
                        id: eventLogDndMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                // Close Button
                Rectangle {
                    id: eventLogCloseButton
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: 24
                    border.color: eventLogCloseMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                    border.width: Theme.borderWidth
                    color: eventLogCloseMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                    radius: Theme.radiusSmall

                    Text {
                        anchors.centerIn: parent
                        color: eventLogCloseMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: "x"
                    }

                    MouseArea {
                        id: eventLogCloseMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: OverlayController.close()
                    }
                }
            }

            // Header Divider & Tabs
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    Rectangle {
                        id: eventLogTab0
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: eventLogTab0Text.implicitWidth + Theme.paddingMedium * 2
                        color: root.eventLogCurrentTab === 0 ? Theme.surfaceSelected : (eventLogTab0MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.eventLogCurrentTab === 0 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: eventLogTab0Text
                            anchors.centerIn: parent
                            color: root.eventLogCurrentTab === 0 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "NOTIFICATIONS"
                        }

                        MouseArea {
                            id: eventLogTab0MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.eventLogCurrentTab = 0
                        }
                    }

                    Rectangle {
                        id: eventLogTab1
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: eventLogTab1Text.implicitWidth + Theme.paddingMedium * 2
                        color: root.eventLogCurrentTab === 1 ? Theme.surfaceSelected : (eventLogTab1MouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                        border.color: root.eventLogCurrentTab === 1 ? Theme.accent : Theme.borderMuted
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        Text {
                            id: eventLogTab1Text
                            anchors.centerIn: parent
                            color: root.eventLogCurrentTab === 1 ? Theme.accent : Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            text: "SYSTEM LOGS"
                        }

                        MouseArea {
                            id: eventLogTab1MouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.eventLogCurrentTab = 1
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: Theme.spacingMedium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.borderWidth
                    color: Theme.borderMuted
                }
            }

            // Body Content Area (ListView or Empty State)
            Item {
                id: eventLogContentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.eventLogCurrentTab === 0

                // Notification History ListView
                ListView {
                    id: eventLogHistoryListView
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: Theme.spacingSmall
                    model: NotificationService.history
                    visible: NotificationService.history.count > 0

                    delegate: Rectangle {
                        id: eventLogCardItem
                        required property int index
                        required property var notifId
                        required property string appName
                        required property string summary
                        required property string body
                        required property int urgency
                        required property string timestamp

                        width: eventLogHistoryListView.width
                        implicitHeight: eventLogCardLayout.implicitHeight + Theme.paddingMedium * 2
                        color: Theme.gray800
                        border.color: Theme.gray700
                        border.width: Theme.borderWidth
                        radius: Theme.radiusSmall

                        readonly property color urgencyColor: {
                            if (eventLogCardItem.urgency === 2) {
                                return Theme.warningRed;
                            }
                            if (eventLogCardItem.urgency === 0) {
                                return Theme.textMuted;
                            }
                            return Theme.acidGreen;
                        }

                        // Urgency accent stripe on left edge
                        Rectangle {
                            id: eventLogUrgencyStripe
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: eventLogCardItem.urgencyColor
                            radius: Theme.radiusSmall
                            width: 3
                        }

                        ColumnLayout {
                            id: eventLogCardLayout
                            anchors.left: eventLogUrgencyStripe.right
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.paddingMedium
                            spacing: Theme.spacingSmall

                            // Header line: Urgency Dot, App Name (left), Timestamp (right)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall

                                Rectangle {
                                    Layout.preferredHeight: 6
                                    Layout.preferredWidth: 6
                                    color: eventLogCardItem.urgencyColor
                                    radius: 3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightMedium
                                    text: eventLogCardItem.appName.toUpperCase()
                                }

                                Text {
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    text: eventLogCardItem.timestamp
                                }
                            }

                            // Summary text
                            Text {
                                Layout.fillWidth: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                text: eventLogCardItem.summary
                            }

                            // Body text (word wrap, max 3 lines, elide)
                            Text {
                                Layout.fillWidth: true
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                maximumLineCount: 3
                                text: eventLogCardItem.body
                                visible: eventLogCardItem.body !== ""
                                wrapMode: Text.WordWrap
                            }

                            // Dismiss action button
                            RowLayout {
                                Layout.fillWidth: true

                                Item {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    id: eventLogDismissBtn
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: eventLogDismissText.implicitWidth + Theme.paddingSmall * 2
                                    border.color: eventLogDismissMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                    border.width: Theme.borderWidth
                                    color: eventLogDismissMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
                                    radius: Theme.radiusSmall

                                    Text {
                                        id: eventLogDismissText
                                        anchors.centerIn: parent
                                        color: eventLogDismissMouseArea.containsMouse ? Theme.accent : Theme.textSecondary
                                        font.family: Theme.fontFamilyMonospace
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Theme.fontWeightMedium
                                        text: "[DISMISS]"
                                    }

                                    MouseArea {
                                        id: eventLogDismissMouseArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: NotificationService.dismissHistoryItem(eventLogCardItem.index)
                                    }
                                }
                            }
                        }
                    }
                }

                // Scrollbar track & thumb
                Rectangle {
                    id: eventLogScrollTrack
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: Theme.gray800
                    radius: 2
                    visible: eventLogHistoryListView.visible && (eventLogHistoryListView.height < eventLogHistoryListView.contentHeight)
                    width: 4

                    Rectangle {
                        id: eventLogScrollThumb
                        color: Theme.acidGreen
                        height: Math.max(16, eventLogHistoryListView.visibleArea.heightRatio * eventLogHistoryListView.height)
                        radius: 2
                        width: 4
                        y: eventLogHistoryListView.visibleArea.yPosition * eventLogHistoryListView.height
                    }
                }

                // Empty state container
                Item {
                    id: eventLogEmptyState
                    anchors.fill: parent
                    visible: NotificationService.history.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingMedium

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 8
                            Layout.preferredWidth: 8
                            color: Theme.textMuted
                            radius: 4
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightMedium
                            text: "NO NOTIFICATIONS // STANDBY"
                        }
                    }
                }
            }

            // System Logs Content Area
            Item {
                id: eventLogSystemLogsContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.eventLogCurrentTab === 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingMedium

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 8
                        Layout.preferredWidth: 8
                        color: Theme.textMuted
                        radius: 4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: Theme.textMuted
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        text: "SYSTEM LOGS // UNAVAILABLE"
                    }
                }
            }

            // Footer Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.borderWidth
                color: Theme.borderMuted
                visible: root.eventLogCurrentTab === 0
            }

            // Footer Action Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                visible: root.eventLogCurrentTab === 0

                Text {
                    Layout.fillWidth: true
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    text: NotificationService.history.count > 0
                          ? NotificationService.history.count + " LOGGED"
                          : "0 LOGGED"
                }

                Rectangle {
                    id: eventLogClearAllBtn
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: eventLogClearAllText.implicitWidth + Theme.paddingMedium * 2
                    border.color: NotificationService.history.count === 0
                                  ? Theme.borderMuted
                                  : (eventLogClearMouseArea.containsMouse ? Theme.destructive : Theme.borderMuted)
                    border.width: Theme.borderWidth
                    color: NotificationService.history.count === 0
                           ? "transparent"
                           : (eventLogClearMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                    opacity: NotificationService.history.count === 0 ? 0.4 : 1.0
                    radius: Theme.radiusSmall

                    Text {
                        id: eventLogClearAllText
                        anchors.centerIn: parent
                        color: NotificationService.history.count === 0
                               ? Theme.textMuted
                               : (eventLogClearMouseArea.containsMouse ? Theme.destructive : Theme.textPrimary)
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        text: "[CLEAR ALL]"
                    }

                    MouseArea {
                        id: eventLogClearMouseArea
                        anchors.fill: parent
                        cursorShape: NotificationService.history.count > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: NotificationService.history.count > 0
                        hoverEnabled: NotificationService.history.count > 0
                        onClicked: NotificationService.clearAll()
                    }
                }
            }
        }
    }

    // =========================================================================
    // Mouse Interaction
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Only handle clicks in compact/notification states.
        // In eventLog state, eventLogInsideClickConsumer takes precedence
        // except for this top-level area which we still need for right-click DND.
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                NotificationService.toggleDnd();
            } else {
                if (root.state === "eventLog") {
                    // Toggle off: close the event log
                    OverlayController.close();
                } else if (root.state === "notification") {
                    // Collapse notification banner and open event log
                    collapseTimer.stop();
                    root.isExpanded = false;
                    root.state = "eventLog";
                    OverlayController.openEventLog();
                } else {
                    // Compact state: toggle event log
                    if (root.isEventLogOpen) {
                        OverlayController.close();
                    } else {
                        root.state = "eventLog";
                        OverlayController.openEventLog();
                    }
                }
            }
        }
    }
}
