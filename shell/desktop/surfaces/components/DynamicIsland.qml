pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../services"

Rectangle {
    id: root

    // =========================================================================
    // Dynamic Island State & Dimensions
    // =========================================================================

    readonly property real compactWidth: 120
    readonly property real expandedWidth: 300

    property bool isExpanded: false
    property string latestAppName: ""
    property string latestSummary: ""
    property int latestUrgency: 1
    readonly property bool isEventLogOpen: OverlayController.activeSurface === OverlayController.Surface.EventLog

    width: isEventLogOpen ? 360 : (isExpanded ? expandedWidth : compactWidth)
    implicitWidth: width
    height: isEventLogOpen ? 500 : (Theme.barHeight - 6)
    implicitHeight: height

    color: Theme.background
    radius: Theme.radiusMedium
    border.color: mouseArea.containsMouse ? Theme.accent : Theme.borderMuted
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

    // Auto-collapse after 4 seconds
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
    // Compact View
    // =========================================================================

    RowLayout {
        id: compactContent
        anchors.centerIn: parent
        opacity: (root.isExpanded || root.isEventLogOpen) ? 0.0 : 1.0
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
        opacity: (root.isExpanded && !root.isEventLogOpen) ? 1.0 : 0.0
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
    // Mouse Interaction
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !root.isEventLogOpen // Disable click to toggle when event log is fully open, as it handles its own input.

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                NotificationService.toggleDnd();
            } else {
                if (root.isExpanded) {
                    root.isExpanded = false;
                    collapseTimer.stop();
                    OverlayController.openEventLog();
                } else {
                    OverlayController.toggleEventLog();
                }
            }
        }
    }

    // =========================================================================
    // Event Log Container
    // =========================================================================

    Loader {
        id: eventLogEmbeddedLoader
        anchors.fill: parent
        active: root.isEventLogOpen || opacity > 0
        opacity: root.isEventLogOpen ? 1.0 : 0.0
        visible: opacity > 0.0
        source: "../EventLog.qml"

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
            }
        }
    }
}
