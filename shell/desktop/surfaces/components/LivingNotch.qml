pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../adapters/hyprland"
import "../../core"
import "../../services"

Item {
    id: root

    // =========================================================================
    // Public Contract
    // =========================================================================
    property string monitorName: ""
    // Detail level. Idle is one line: clock, glyphs, no numbers. The design's
    // expanded state "breathes open with more details" -- a date line, seconds
    // on the clock, and a percentage under each indicator glyph. Carrying all of
    // that in the idle bar too is part of why it needed 470px to stop wrapping.
    readonly property bool showDetail:
        root.isCommandCenterOpen || root.notchState === "hover"

    readonly property bool isCommandCenterOpen: OverlayController.activeSurface === OverlayController.Surface.CommandCenter
    readonly property real currentWidth: root.width
    readonly property real currentHeight: root.height
    readonly property string notchState: root._resolvedState

    // Dynamic Island & Test Compatibility Properties
    // Test-compatibility alias. Read-only on purpose: it used to be a writable
    // binding onto _notificationActive while also being assigned alongside it,
    // which broke the binding and left two bools that had to be kept in sync by
    // hand. notificationActive is the only writable state.
    readonly property bool isExpanded: root.notificationActive
    property string state: root.notchState
    // Read-only alias for the same reason as isExpanded above.
    readonly property bool _isCalendarOpen: root.calendarOpen

    // State Tracking Flags
    property bool _isHovered: false
    property bool notificationActive: false

    property string latestAppName: "System"
    property string latestSummary: ""
    property int latestUrgency: 1

    // State Dimensions
    readonly property real compactWidth: Theme.notchWidthCompact
    // Hover adds the date line and the indicator percentages on top of the idle
    // row, so it needs more room, but not twice as much.
    readonly property real hoverWidth: 620
    readonly property real mediaWidth: 280
    readonly property real notificationWidth: 320
    readonly property real calendarWidth: 360

    readonly property real compactHeight: Settings.barHeight
    readonly property real hoverHeight: Theme.notchHeightExpanded
    readonly property real expandedHeight: Theme.notchHeightExpanded
    readonly property real calendarHeight: 250

    // Public Signals
    signal openCommandDeckRequested()
    signal toggleCommandCenterRequested()
    signal toggleNetworkRequested()
    signal toggleBluetoothRequested()
    signal calendarToggled(bool isOpen)
    signal closeCalendarRequested()

    // =========================================================================
    // MPRIS Active Player Tracking & Equalizer State
    // =========================================================================
    property int _mprisTrigger: 0

    Repeater {
        model: Mpris.players.values

        Item {
            id: mprisWatcher
            required property var modelData

            Connections {
                target: mprisWatcher.modelData

                function onPlaybackStateChanged(): void { root._mprisTrigger++; }
                function onTrackTitleChanged(): void { root._mprisTrigger++; }
                function onTrackArtistChanged(): void { root._mprisTrigger++; }
            }
        }
    }

    readonly property var activePlayer: {
        const trigger = root._mprisTrigger;
        const list = Mpris.players.values;
        if (!list || list.length === 0) return null;

        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) return p;
        }
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused && p.trackTitle && p.trackTitle.trim() !== "") return p;
        }
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused) return p;
        }
        return list[0] || null;
    }

    readonly property bool hasMedia: activePlayer !== null && (
        activePlayer.playbackState === MprisPlaybackState.Playing ||
        (activePlayer.trackTitle !== undefined && activePlayer.trackTitle !== null && activePlayer.trackTitle.trim() !== "")
    )
    readonly property bool isPlaying: hasMedia && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string mediaTitle: (activePlayer && activePlayer.trackTitle && activePlayer.trackTitle.trim() !== "") ? activePlayer.trackTitle.trim() : "--UNTITLED--"
    readonly property string mediaArtist: (activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.trim() !== "") ? activePlayer.trackArtist.trim() : ""

    property real visualizerPhase: 0.0
    NumberAnimation {
        id: visualizerAnim
        target: root
        property: "visualizerPhase"
        from: 0.0
        to: 6.283185307179586
        duration: 1200
        loops: Animation.Infinite
        running: root.isPlaying && !Settings.reducedMotion
    }

    // =========================================================================
    // Workspace Model Resolution
    // =========================================================================
    readonly property var workspaceList: {
        if (root.monitorName !== "" && typeof HyprlandAdapter !== "undefined" && HyprlandAdapter.available) {
            const monList = HyprlandAdapter.workspacesForMonitor(root.monitorName);
            if (monList && monList.length > 0) return monList;
        }
        const rawList = CompositorService.workspaces;
        if (rawList && rawList.length > 0) return rawList;
        return [
            { id: 1, name: "1", active: true, focused: true, urgent: false },
            { id: 2, name: "2", active: false, focused: false, urgent: false },
            { id: 3, name: "3", active: false, focused: false, urgent: false },
            { id: 4, name: "4", active: false, focused: false, urgent: false },
            { id: 5, name: "5", active: false, focused: false, urgent: false }
        ];
    }

    // =========================================================================
    // State Priority & Geometry Computations
    // =========================================================================
    readonly property string _resolvedState: {
        if (root.calendarOpen && !root.isCommandCenterOpen) return "calendar";
        if (root.notificationActive && !NotificationService.doNotDisturb) return "notification";
        if (root._isHovered && !root.isCommandCenterOpen) return "hover";
        if (root.hasMedia) return "media";
        return "compact";
    }

    readonly property real targetWidth: {
        // While the command centre is open, this bar is the panel's header,
        // and the design draws that header as wide as the panel. At the 220px
        // compact width there is nowhere to put the date, the indicators and
        // the collapse control.
        if (root.isCommandCenterOpen)
            return Theme.commandCenterWidth;

        switch (root.notchState) {
        case "calendar": return root.calendarWidth;
        case "hover": return root.hoverWidth;
        case "notification": return root.notificationWidth;
        case "media": return root.mediaWidth;
        case "compact":
        default: return root.compactWidth;
        }
    }

    readonly property real targetHeight: {
        switch (root.notchState) {
        case "calendar": return root.calendarHeight;
        case "hover": return root.hoverHeight;
        case "notification":
        case "media":
        case "compact":
        default: return root.compactHeight;
        }
    }

    // A two-line date and clock, plus rows of indicators, need more than the
    // 30px bar height while the panel is open.
    readonly property real currentTargetHeight:
        root.isCommandCenterOpen ? Theme.notchHeightExpanded : root.targetHeight

    // Fully rounded ends at every size, per the target design. The previous
    // version fell back to an 8px radius for the hover and calendar states,
    // which drew a rectangle where a stadium was specified.
    readonly property real targetRadius: root.height / 2

    // =========================================================================
    // Geometry & Spring Physics Animation Declarations
    // =========================================================================
    clip: false
    width: targetWidth
    height: currentTargetHeight
    implicitWidth: targetWidth
    implicitHeight: currentTargetHeight

    Behavior on width {
        enabled: !Settings.reducedMotion
        SpringAnimation {
            spring: 4.0
            damping: (root.notchState === "calendar" ? 0.6 : 0.35)
            mass: 0.8
            epsilon: 0.25
        }
    }

    Behavior on height {
        enabled: !Settings.reducedMotion
        SpringAnimation {
            spring: 4.0
            damping: (root.notchState === "calendar" ? 0.6 : 0.35)
            mass: 0.8
            epsilon: 0.25
        }
    }

    // The notch stays visible while the CCC is open.
    //
    // It used to fade to zero here, which was correct when the CCC was a
    // separate PanelWindow that *replaced* the bar. Now the CCC is a child of
    // this window unfolding downward, and the design keeps the notch header
    // pinned at the top of it -- that continuity is the whole point. Fading it
    // out left the CCC floating with nothing attached above it.
    opacity: 1.0

    // =========================================================================
    // Timers & Methods
    // =========================================================================
    Timer {
        id: collapseTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root.notificationActive = false;
        }
    }

    HoverHandler {
        id: globalHover
    }

    Timer {
        id: hoverDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (!globalHover.hovered) {
                root._isHovered = false;
            }
        }
    }

    function isInsidePill(mx: real, my: real, w: real, h: real, r: real): bool {
        if (mx < 0 || mx > w || my < 0 || my > h) return false;
        if (mx >= r && mx <= w - r) return true;
        if (my >= r && my <= h - r) return true;
        const cx = mx < r ? r : w - r;
        const cy = my < r ? r : h - r;
        const dx = mx - cx;
        const dy = my - cy;
        return (dx * dx + dy * dy) <= (r * r);
    }

    function showNotification(appName: string, summary: string, urgency: int): void {
        root.latestAppName = appName || "System";
        root.latestSummary = summary || "";
        root.latestUrgency = (urgency !== undefined) ? urgency : 1;
        root.notificationActive = true;
        collapseTimer.restart();
    }

    function toggleCalendar(): void {
        if (root.isCommandCenterOpen) {
            OverlayController.close();
        }
        root.calendarOpen = !root.calendarOpen;
        root.calendarToggled(root.calendarOpen);
    }

    function closeCalendar(): void {
        if (root.calendarOpen) {
            root.calendarOpen = false;
            root.calendarToggled(false);
            root.closeCalendarRequested();
        }
    }

    // =========================================================================
    // External Service Connections
    // =========================================================================
    Connections {
        target: NotificationService

        function onNotificationReceived(notification): void {
            if (!NotificationService.doNotDisturb && notification) {
                root.showNotification(notification.appName, notification.summary, notification.urgency);
            }
        }

        function onDoNotDisturbChanged(): void {
            if (NotificationService.doNotDisturb && root.notificationActive) {
                collapseTimer.stop();
                root.notificationActive = false;
            }
        }
    }

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

    Connections {
        target: OverlayController

        function onOverlayOpened(surface): void {
            root.closeCalendar();
        }

        function onActiveSurfaceChanged(): void {
            if (OverlayController.activeSurface !== OverlayController.Surface.None) {
                root.closeCalendar();
            }
        }
    }

    onIsCommandCenterOpenChanged: {
        if (root.isCommandCenterOpen) {
            root.closeCalendar();
        }
    }

    // =========================================================================
    // System Clock & Visual Background Pill
    // =========================================================================
    SystemClock {
        id: systemClock
        // Plural form, not Qt's documented "SecondPrecision": the documented
        // names resolve to undefined on this Qt. See CalendarPopup.qml.
        precision: SystemClock.Seconds
    }

    // -------------------------------------------------------------------------
    // Border ring and surface.
    //
    // Rectangle.border takes a flat colour, so the three-stop gradient is a
    // separate rounded rectangle sitting behind the surface, and the surface is
    // inset by the border width. That yields a uniform ring because the inner
    // radius is the outer radius minus the inset.
    // -------------------------------------------------------------------------
    readonly property color ringStart: root.latestUrgency === 2 && root.notchState === "notification"
        ? Theme.danger
        : Theme.accentBlue
    readonly property color ringMid: Theme.accentViolet
    readonly property color ringEnd: root.latestUrgency === 2 && root.notchState === "notification"
        ? Theme.danger
        : Theme.accentMagenta

    Rectangle {
        id: borderRing

        anchors.fill: parent
        radius: root.targetRadius
        antialiasing: true

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: root.ringStart }
            GradientStop { position: 0.50; color: root.ringMid }
            GradientStop { position: 1.00; color: root.ringEnd }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationNormal
                easing.type: Easing.InOutQuad
            }
        }
    }

    Rectangle {
        id: visualBg

        anchors.fill: parent
        anchors.margins: Theme.borderWidthAccent
        radius: Math.max(0, root.targetRadius - Theme.borderWidthAccent)
        antialiasing: true

        // Slightly translucent so the wallpaper reads through, per the design.
        color: Theme.notchSurface
        clip: true

        Behavior on radius {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationNormal
                easing.type: Easing.InOutQuad
            }
        }
    }

    // =========================================================================
    // View 1: Compact State (Workspaces, Monospace Clock, Net Dot, Status)
    // =========================================================================
    RowLayout {
        id: compactView
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        spacing: Theme.spacingSmall
        // Serves both the idle and the hover state.
        //
        // There was a second, separate hover view with its own copies of the
        // system bar and the system tray -- about 300 lines duplicating content
        // that had already drifted out of sync with the compact view. Hover is
        // the same row with more detail, which is what showDetail expresses, so
        // it is the same view.
        opacity: (root.notchState === "compact" || root.notchState === "hover") ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
        }

        // App Logo / CommandDeck entry point.
        // The target design places this first in the idle state; it was only
        // present in the hover row, so the resting notch had no identity and no
        // CommandDeck target.
        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: Theme.radiusSmall
            color: compactLogoMouse.containsMouse ? Theme.surfaceHover : "transparent"
            Layout.alignment: Qt.AlignVCenter

            HexMark {
                anchors.centerIn: parent
                width: 18
                height: 18
            }

            MouseArea {
                id: compactLogoMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openCommandDeckRequested()
            }
        }

        // Workspaces as numbered pills.
      //
      // The design numbers them and marks the active one with a filled magenta
      // circle. The previous five-dot row could not say which workspace was
      // which, and at 6px a dot has no room to carry a number at all.
      RowLayout {
          spacing: Theme.spacingXs
          Layout.alignment: Qt.AlignVCenter

          Repeater {
              model: root.workspaceList

              Item {
                  id: wsCell
                  required property var modelData

                  readonly property int wsId: (typeof modelData === "object" && modelData !== null) ? Number(modelData.id) : Number(modelData)
                  readonly property bool isActive: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.active || (wsId === CompositorService.focusedWorkspaceId)) : (wsId === CompositorService.focusedWorkspaceId)
                  readonly property bool isFocused: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.focused || (wsId === CompositorService.focusedWorkspaceId)) : (wsId === CompositorService.focusedWorkspaceId)
                  readonly property bool isUrgent: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.urgent) : false

                  Layout.preferredWidth: isFocused ? 18 : wsLabel.implicitWidth + 6
                  Layout.preferredHeight: 18
                  Layout.alignment: Qt.AlignVCenter

                  Rectangle {
                      anchors.fill: parent
                      radius: height / 2
                      color: wsCell.isFocused ? Theme.accent
                          : (wsCell.isUrgent ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                      border.width: Theme.borderWidth
                      border.color: wsCell.isUrgent ? Theme.destructive : "transparent"

                      Behavior on color {
                          ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
                      }
                  }

                  Text {
                      id: wsLabel
                      anchors.centerIn: parent
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: wsCell.wsId
                      color: wsCell.isFocused ? Theme.navyDeep
                          : (wsCell.isActive ? Theme.textPrimary : Theme.textSecondary)
                      font.family: Theme.fontFamilySans
                      font.pixelSize: Theme.fontSizeCaption
                      font.weight: Theme.fontWeightDemiBold
                  }

                  MouseArea {
                      anchors.fill: parent
                      anchors.margins: -4
                      cursorShape: Qt.PointingHandCursor
                      onClicked: CompositorService.switchToWorkspace(wsCell.wsId)
                  }
              }
          }
      }

      // Divider between the workspace group and the clock, per the design.
      Rectangle {
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: Theme.borderWidth
          Layout.preferredHeight: 22
          visible: root.isCommandCenterOpen
          color: Theme.border
      }

        // Date over clock. The design stacks a small date on a large time, which
        // is also the only arrangement that fits both without shrinking the clock
        // down to caption size.
        Item {
            Layout.preferredWidth: Math.max(dateText.implicitWidth, timeText.implicitWidth)
            Layout.preferredHeight: timeText.implicitHeight
                + (root.showDetail ? dateText.implicitHeight + 2 : 0)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: dateText
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showDetail
                text: Qt.formatDateTime(systemClock.date, "ddd dd MMM").toUpperCase()
                color: Theme.textSecondary
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSizeMicro
                font.weight: Theme.fontWeightDemiBold
            }

            Text {
                id: timeText
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(systemClock.date,
                        root.showDetail ? "HH:mm:ss" : "HH:mm")
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonoNumeric
                font.pixelSize: Theme.fontSizeBody
                font.weight: Theme.fontWeightDemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCalendar()
            }
        }


        // Indicator cluster: glyph over a value, values in the status colour.

      Item { Layout.fillWidth: true }
      // Everything after this is pinned to the trailing edge.
        //
        // Replaces one connected/not-connected dot and an "// IDLE" string. The
        // dot said whether the link was up; it could not say how good the link
        // was, and it left the rest of the bar's right-hand side empty.
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingMedium

            // Collapse control. Only while the panel is open: an idle notch has
            // no room for it and nothing to collapse.
            GlyphIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                visible: root.isCommandCenterOpen
                glyph: "chevron"
                // Glyph points down; collapsing means going back up.
                rotation: 180
                color: Theme.textSecondary
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                visible: NetworkService.isConnected

                GlyphIcon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 16
                    height: 16
                    glyph: "wifi"
                    color: Theme.textSecondary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showDetail
                    text: NetworkService.signalStrength > 0
                        ? Math.round(NetworkService.signalStrength * 100) + "%"
                        : ""
                    color: Theme.statusGreen
                    font.family: Theme.fontFamilyMonoNumeric
                    font.pixelSize: Theme.fontSizeMicro
                    font.weight: Theme.fontWeightDemiBold
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                visible: AudioService.available

                GlyphIcon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 16
                    height: 16
                    glyph: "speaker"
                    color: Theme.textSecondary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showDetail
                    text: AudioService.muted ? "M" : Math.round(AudioService.volume * 100) + "%"
                    color: Theme.statusGreen
                    font.family: Theme.fontFamilyMonoNumeric
                    font.pixelSize: Theme.fontSizeMicro
                    font.weight: Theme.fontWeightDemiBold
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                visible: PowerService.isBatteryPresent

                GlyphIcon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 16
                    height: 16
                    glyph: "battery"
                    color: PowerService.isCharging ? Theme.statusGreen : Theme.textSecondary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showDetail
                    text: Math.round(PowerService.percentage) + "%"
                    color: Theme.statusGreen
                    font.family: Theme.fontFamilyMonoNumeric
                    font.pixelSize: Theme.fontSizeMicro
                    font.weight: Theme.fontWeightDemiBold
                }
            }

            // Status word, which ends the bar. The design shows one in both the
            // idle and expanded states: IDLE with nothing pending, otherwise
            // what is pending.
            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: !NotificationService.doNotDisturb
                text: NotificationService.unreadCount > 0
                    ? NotificationService.unreadCount + " NEW"
                    : (root.hasMedia ? (root.isPlaying ? "PLAYING" : "PAUSED") : "IDLE")
                color: Theme.textSecondary
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSizeMicro
                font.weight: Theme.fontWeightDemiBold
            }

            // DND is kept: it is state the user set and needs to see at a glance.
            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: NotificationService.doNotDisturb
                text: "DND"
                color: Theme.warningRed
                font.family: Theme.fontFamilySans
                font.pixelSize: Theme.fontSizeMicro
                font.weight: Theme.fontWeightBold
            }
        }
    }


    // View 2: Media State (Play/Pause, Title // Artist, Equalizer, Clock)
    // =========================================================================
    RowLayout {
        id: mediaView
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        spacing: Theme.spacingSmall
        opacity: (root.notchState === "media") ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
        }

        Item {
            Layout.preferredWidth: playPauseText.implicitWidth + 4
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: playPauseText
                anchors.centerIn: parent
                text: root.isPlaying ? "▶" : "⏸"
                color: root.isPlaying ? Theme.statusGreen : Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activePlayer && typeof root.activePlayer.playPause === "function") {
                        root.activePlayer.playPause();
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: root.mediaArtist !== "" ? (root.mediaTitle + " // " + root.mediaArtist) : root.mediaTitle
            color: Theme.textPrimary
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // 4-Bar Equalizer
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 14
            spacing: 2

            Repeater {
                model: 4
                Rectangle {
                    id: eqBar
                    required property int index
                    Layout.alignment: Qt.AlignBottom
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: root.isPlaying
                        ? Math.max(3, Math.round((Math.sin((eqBar.index * 1.1) + root.visualizerPhase) * 0.4 + 0.5) * 14))
                        : 3
                    color: root.isPlaying ? Theme.statusGreen : Theme.gray600
                    radius: 1
                }
            }
        }

        Item {
            Layout.preferredWidth: mediaClockText.implicitWidth
            Layout.preferredHeight: mediaClockText.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: mediaClockText
                anchors.centerIn: parent
                text: Qt.formatDateTime(systemClock.date, "HH:mm")
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCalendar()
            }
        }
    }

    // =========================================================================
    // View 3: Notification State (Urgency Dot, App, », Summary)
    // =========================================================================
    RowLayout {
        id: notificationView
        anchors.fill: parent
        anchors.leftMargin: Theme.paddingLarge
        anchors.rightMargin: Theme.paddingLarge
        spacing: Theme.spacingSmall
        opacity: (root.notchState === "notification") ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
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
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    // =========================================================================
    // View 5: Calendar State (NotchCalendarGrid Morph Container)
    // =========================================================================
    Item {
        id: calendarView
        anchors.fill: parent
        focus: root.notchState === "calendar"
        opacity: (root.notchState === "calendar") ? 1.0 : 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
        }

        Keys.onEscapePressed: (event) => {
            event.accepted = true;
            root.closeCalendar();
        }

        Loader {
            id: calendarLoader
            anchors.fill: parent
            active: root.notchState === "calendar" || root.calendarOpen
            source: "NotchCalendarGrid.qml"

            onLoaded: {
                if (calendarLoader.item && typeof calendarLoader.item.closeRequested !== "undefined") {
                    calendarLoader.item.closeRequested.connect(root.closeCalendar);
                }
                if (calendarLoader.item) {
                    calendarLoader.item.forceActiveFocus();
                }
            }
        }
    }

    // =========================================================================
    // Master MouseArea (Hover detection, Wheel Volume Step, DND & CommandCenter)
    // =========================================================================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Sole hover authority for the notch. The per-item targets below carry
        // no hover handling at all: they only route clicks. That is deliberate.
        // Their onEntered handlers were ungated -- they set _isHovered without
        // the isInsidePill test applied here -- which is the hover-loop class
        // this file needed two separate patches for.
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1

        onPressed: (mouse) => {
            if (!root.isInsidePill(mouse.x, mouse.y, root.width, root.height, visualBg.radius)) {
                mouse.accepted = false;
            }
        }

        onPositionChanged: (mouse) => {
            if (root.isInsidePill(mouse.x, mouse.y, root.width, root.height, visualBg.radius)) {
                hoverDebounceTimer.stop();
                if (!root._isCalendarOpen) {
                    root._isHovered = true;
                }
            } else {
                if (root._isHovered) {
                    hoverDebounceTimer.restart();
                }
            }
        }

        onEntered: {
            if (root.isInsidePill(mouseX, mouseY, root.width, root.height, visualBg.radius)) {
                hoverDebounceTimer.stop();
                if (!root._isCalendarOpen) {
                    root._isHovered = true;
                }
            }
        }

        onExited: {
            hoverDebounceTimer.restart();
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                NotificationService.toggleDnd();
            } else {
                if (root.notchState === "notification") {
                    collapseTimer.stop();
                    root.notificationActive = false;
                } else if (root.notchState === "compact") {
                    root.closeCalendar();
                    root.toggleCommandCenterRequested();
                }
            }
        }

        onWheel: (wheel) => {
            if (root.isInsidePill(wheel.x, wheel.y, root.width, root.height, visualBg.radius)) {
                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                AudioService.stepVolume(delta);
                wheel.accepted = true;
            } else {
                wheel.accepted = false;
            }
        }
    }
}
