import QtQuick
import Quickshell
import "../../core"
import "../../services"

// Month grid over a day timeline, the agenda half of the calendar card.
//
// The design puts these side by side, but the card lives in the CCC's right
// column at roughly 318px wide, which leaves about 40px per weekday once the
// card's own padding is subtracted. Side by side would give the timeline about
// 150px -- too narrow for a time range and a title on one row. Stacked, the grid
// gets full width and the timeline reads as a list underneath it.
//
// The month shown and the day selected are local state rather than anything
// CalendarService owns: the service answers "what events exist", this decides
// "which month am I looking at".
Item {
    id: root

    // =========================================================================
    // View State
    // =========================================================================

    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    // Selected day. Defaults to today, so the card opens on something useful
    // instead of an empty grid.
    property var selected: new Date(today.getFullYear(), today.getMonth(), today.getDate())

    // Bumping this re-reads CalendarService's derived queries. Bound to
    // revision because the service rebuilds its arrays wholesale on reload, and
    // the grid dots and timeline both derive from those.
    property int calRevision: CalendarService.revision

    // Routed through functions that take the revision as an argument, so these
    // bindings actually depend on it. Calling CalendarService directly would
    // depend only on `selected`, and since the service rebuilds its arrays
    // wholesale on reload rather than mutating them, nothing would re-evaluate
    // when new events arrived -- the card would stay empty until the month
    // changed.
    readonly property var monthMarks: root._marksForRevision(viewYear, viewMonth, calRevision)
    readonly property var dayEvents: root._eventsForRevision(selected, calRevision)

    function _marksForRevision(year: int, month: int, rev: int): var {
        return CalendarService.eventDaysInMonth(year, month);
    }

    function _eventsForRevision(date: var, rev: int): var {
        return CalendarService.eventsForDay(date);
    }

    readonly property string monthLabel:
        Qt.locale().standaloneMonthName(viewMonth) + " " + viewYear

    readonly property string selectedLabel: {
        const d = Qt.locale().standaloneDayName(selected)
            + " " + Qt.locale().standaloneMonthName(selected.getMonth())
            + " " + String(selected.getDate()).padStart(2, "0")
            + " " + selected.getFullYear();
        return d;
    }

    function _isSameDay(a: var, b: var): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    function _shiftMonth(delta: int): void {
        const shifted = new Date(viewYear, viewMonth + delta, 1);
        viewYear = shifted.getFullYear();
        viewMonth = shifted.getMonth();
    }

    // Stable colour per event, derived from the summary.
    //
    // .ics has a CATEGORIES field but it is inconsistently used, and the design's
    // coloured bars are per-event rather than per-calendar. Hashing the summary
    // gives the same event the same bar across reloads, which is what makes the
    // timeline scannable, without inventing a colour field.
    // Accent hues only. statusGreen and the reds are deliberately excluded: Theme
    // documents those as status and destructive semantics that "must not be
    // interchanged", and a decorative category bar is neither. Note also that
    // Theme.accentGreen resolves to magenta, so it would have silently collapsed
    // to the same colour as the first entry.
    readonly property var _barPalette: [
        Theme.accentMagenta, Theme.accentBlue, Theme.accentViolet, Theme.pastelOrange
    ]

    function _colorFor(summary: string): color {
        let hash = 0;
        const text = summary || "";
        for (let i = 0; i < text.length; ++i)
            hash = (hash * 31 + text.charCodeAt(i)) | 0;
        const index = (hash < 0 ? -hash : hash) % _barPalette.length;
        return _barPalette[index];
    }

    // =========================================================================
    // Geometry
    // =========================================================================

    readonly property int gridCols: 7
    readonly property int headerHeight: 24
    readonly property int dayCellHeight: 26
    // Six rows always, so the grid does not change height between months.
    readonly property int gridRows: 6
    readonly property int gridHeight: headerHeight + gridRows * dayCellHeight
    readonly property int cellWidth: (width - Theme.spacingSmall * 2) / gridCols

    readonly property int timelineHeaderHeight: 22
    // Six rows is enough to show a full day without turning the card into a
    // scroll area inside a scroll area.
    readonly property int maxVisibleEvents: 6
    readonly property int eventRowHeight: 34

    implicitHeight: headerHeight + gridHeight
                 + Theme.spacingMedium
                 + timelineHeaderHeight
                 + Math.min(dayEvents.length, maxVisibleEvents) * eventRowHeight
                 + Theme.spacingSmall

    // =========================================================================
    // Month Navigation
    // =========================================================================

    Row {
        id: monthBar
        width: parent.width
        height: root.headerHeight

        NavButton {
            id: prevMonth
            anchors.verticalCenter: parent.verticalCenter
            label: "‹"
            onClicked: root._shiftMonth(-1)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: prevMonth.x + prevMonth.width + Theme.spacingMedium
            text: root.monthLabel
            color: Theme.textPrimary
            font.family: Theme.fontFamilySans
            font.pixelSize: Theme.fontSizeBody
            font.weight: Theme.fontWeightDemiBold
        }

        NavButton {
            id: nextMonth
            anchors.verticalCenter: parent.verticalCenter
            x: monthBar.width - width
            label: "›"
            onClicked: root._shiftMonth(1)
        }
    }

    // =========================================================================
    // Month Grid
    // =========================================================================

    Column {
        id: gridColumn
        y: monthBar.height
        width: parent.width
        spacing: Theme.spacingSmall

        // Weekday initials, Monday first.
        Row {
            width: parent.width
            height: root.headerHeight

            Repeater {
                model: [ "M", "T", "W", "T", "F", "S", "S" ]
                delegate: Text {
                    required property string modelData
                    width: root.cellWidth
                    height: root.headerHeight
                    text: modelData
                    color: Theme.textMuted
                    font.family: Theme.fontFamilySans
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightDemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Day cells.
        //
        // A Grid, not a bare Repeater: a Repeater contributes children to its
        // parent, and a Column stacks its children vertically. Without the Grid
        // the 42 cells fall into one column and the month reads as a list.
        Grid {
            columns: root.gridCols

            Repeater {
                model: root._cells
                delegate: Item {
                required property var modelData
                width: root.cellWidth
                height: root.dayCellHeight

                readonly property bool inMonth: modelData.inMonth
                readonly property bool isSelected: root._isSameDay(modelData.date, root.selected)
                readonly property bool isToday: root._isSameDay(modelData.date, root.today)
                readonly property bool hasEvents: root.monthMarks[modelData.date.getDate()] === true
                    && modelData.inMonth

                // Selected day gets the filled accent circle from the design;
                // today, when not selected, gets a ring instead so "today" stays
                // findable after the user browses into another month.
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    visible: parent.isSelected
                    color: Theme.accentMagenta
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 4
                    height: width
                    radius: width / 2
                    visible: !parent.isSelected && parent.isToday
                    color: "transparent"
                    border.width: Theme.borderWidth
                    border.color: Theme.accentMagenta
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.date.getDate()
                    color: parent.inMonth
                        ? (parent.isSelected ? Theme.navyDeep : Theme.textPrimary)
                        : Theme.textDim
                    font.family: Theme.fontFamilySans
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: parent.isToday || parent.isSelected
                        ? Theme.fontWeightDemiBold
                        : Theme.fontWeightNormal
                }

                // Event indicator. Dots rather than a count: at this cell size a
                // number is unreadable, and presence is what the grid is for.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 3
                    width: 3
                    height: 3
                    radius: 1.5
                    visible: parent.hasEvents
                    // On the selected day the dot would sit on the filled accent
                    // circle, so it inverts to the circle's own dark fill instead
                    // of matching it and disappearing.
                    color: parent.isSelected ? Theme.navyDeep : Theme.accentBlue
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selected = modelData.date;
                        // Clicking a trailing day from the next month should move
                        // the view too, otherwise the selection is off-screen.
                        if (!modelData.inMonth)
                            root._shiftMonth(modelData.date.getMonth() > root.viewMonth ? 1 : -1);
                    }
                }
            }
        }
    }
    }

    // =========================================================================
    // Day Timeline
    // =========================================================================

    Rectangle {
        id: divider
        y: gridColumn.y + gridColumn.height + Theme.spacingMedium
        width: parent.width
        height: Theme.borderWidth
        color: Theme.border
    }

    Text {
        id: timelineHeader
        y: divider.y + divider.height + Theme.spacingMedium
        width: parent.width
        height: root.timelineHeaderHeight
        text: root.selectedLabel
        color: Theme.textSecondary
        font.family: Theme.fontFamilySans
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightDemiBold
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Empty state. Covers all three cases the service distinguishes, so the card
    // never renders as a blank box with no explanation.
    Column {
        anchors.top: timelineHeader.bottom
        anchors.topMargin: Theme.spacingMedium
        width: parent.width
        spacing: Theme.spacingSmall
        visible: root.dayEvents.length === 0

        Text {
            width: parent.width
            text: CalendarService.emptyReason
            color: Theme.textMuted
            font.family: Theme.fontFamilySans
            font.pixelSize: Theme.fontSizeCaption
            wrapMode: Text.WordWrap
        }
    }

    Column {
        anchors.top: timelineHeader.bottom
        anchors.topMargin: Theme.spacingSmall
        width: parent.width
        spacing: Theme.spacingXs

        Repeater {
            model: root.dayEvents.length > root.maxVisibleEvents
                ? root.dayEvents.slice(0, root.maxVisibleEvents)
                : root.dayEvents

            delegate: Item {
                required property var modelData
                required property int index

                width: parent.width
                height: root.eventRowHeight

                readonly property bool allDay: modelData.allDay
                // start/end are epoch milliseconds, so they have to be wrapped
                // before Qt.formatTime will render them -- handing it the raw
                // number yields an empty string rather than an error.
                readonly property string startText: modelData.allDay
                    ? "All day"
                    : Qt.formatTime(new Date(modelData.start), "HH:mm")
                readonly property string endText: modelData.allDay
                    ? ""
                    : Qt.formatTime(new Date(modelData.end), "HH:mm")

                // Stacked start/end, as in the design's 09:00 / 10:00 column.
                Column {
                    id: timeColumn
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    spacing: 1

                    Text {
                        text: parent.parent.startText
                        color: Theme.textSecondary
                        font.family: Theme.fontFamilySans
                        font.pixelSize: Theme.fontSizeMicro
                    }
                    Text {
                        text: parent.parent.endText
                        visible: text.length > 0
                        color: Theme.textDim
                        font.family: Theme.fontFamilySans
                        font.pixelSize: Theme.fontSizeMicro
                    }
                }

                // Category colour bar. Hue is derived from the summary so an
                // event keeps a stable colour between reloads, without needing a
                // colour field in the .ics.
                Rectangle {
                    id: categoryBar
                    x: timeColumn.width + Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: parent.height - Theme.spacingMedium
                    radius: 1
                    color: root._colorFor(modelData.summary)
                }

                Column {
                    anchors.left: categoryBar.right
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.summary
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilySans
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightDemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        // Location is the subtitle in the design; fall back to the
                        // .ics category when there is no location.
                        text: modelData.location.length > 0
                            ? modelData.location
                            : modelData.category
                        color: Theme.textDim
                        font.family: Theme.fontFamilySans
                        font.pixelSize: Theme.fontSizeMicro
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // "+ N more" when the day is busier than the card shows.
    Text {
        y: timelineHeader.height + root.timelineHeaderHeight + Theme.spacingSmall
              + Math.min(root.dayEvents.length, root.maxVisibleEvents) * root.eventRowHeight
        width: parent.width
        height: Theme.fontSizeCaption + 2
        visible: root.dayEvents.length > root.maxVisibleEvents
        text: qsTr("+%1 more").arg(root.dayEvents.length - root.maxVisibleEvents)
        color: Theme.textMuted
        font.family: Theme.fontFamilySans
        font.pixelSize: Theme.fontSizeMicro
    }

    // =========================================================================
    // Derived
    // =========================================================================

    // 42 cells covering the displayed month, padded with the neighbouring
    // months' days so the grid is always six rows.
    readonly property var _cells: {
        const out = [];
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() + 6) % 7; // Monday-first
        const cursor = new Date(viewYear, viewMonth, 1 - offset);

        for (let i = 0; i < gridRows * gridCols; ++i) {
            out.push({
                date: new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate()),
                inMonth: cursor.getMonth() === viewMonth
            });
            cursor.setDate(cursor.getDate() + 1);
        }
        return out;
    }

    // Small square nav button. Local rather than in components/ because the CCC
    // already has its own chrome and this is only used by the calendar grid.
    component NavButton: Item {
        id: nav
        property string label: ""
        signal clicked()
        width: 22
        height: 22

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: hover.hovered ? Theme.surfaceHover : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: nav.label
            color: Theme.textSecondary
            font.family: Theme.fontFamilySans
            font.pixelSize: Theme.fontSizeLarge
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }
}