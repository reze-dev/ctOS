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
    // =====================================================================
    // Media Player Selection
    // =====================================================================

    // Reading Mpris.players.values is not reactive to a player's own property
    // changes, so activePlayer needs an explicit trigger to re-evaluate when a
    // track changes or playback state flips. The watcher below bumps it.
    property int _mprisTrigger: 0

    Repeater {
        model: Mpris.players.values

        Item {
            id: mprisWatcher
            required property var modelData

            Connections {
                target: mprisWatcher.modelData

                function onPlaybackStateChanged(): void { root._mprisTrigger++; }
                function onTrackTitleChanged(): void    { root._mprisTrigger++; }
                function onTrackArtistChanged(): void   { root._mprisTrigger++; }
            }
        }
    }

    // Preference order: something actually playing, then something paused that
    // has a title (so the panel does not jump to a bare idle player), then any
    // paused player, then whatever is there.
    readonly property var activePlayer: {
        const trigger = root._mprisTrigger;
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;

        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Playing)
                return p;
        }
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused
                    && p.trackTitle && p.trackTitle.trim() !== "")
                return p;
        }
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && p.playbackState === MprisPlaybackState.Paused)
                return p;
        }
        return list[0] || null;
    }

    readonly property bool isPlaying:
        activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing

    function applyRequestedCard(): void {
        if (requestedCard === "")
            return;

        if (requestedCard === "notifications")      cardNotifications.expanded = true;
        else if (requestedCard === "wifi")         cardWifi.expanded = true;
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
                    id: cardWifi
                    width: parent.width
                    title: qsTr("Wi-Fi")
                    // Reports the wireless link only. This card's body lists
                    // wireless networks, so a header driven by the global
                    // wired-first connectionType made it announce "Ethernet"
                    // above a list of Wi-Fi networks.
                    subtitle: NetworkService.wifiConnected
                        ? (NetworkService.wifiNetworkName !== ""
                           ? NetworkService.wifiNetworkName
                           : qsTr("Connected"))
                        : (NetworkService.wifiEnabled ? "" : qsTr("Off"))
                    icon: "wifi"
                    accent: Theme.accentBlue
                    collapsible: true
                    // Collapsed by default, like the design: the header already
                    // says which network you are on, and the rest of the list is
                    // one click away. Expanded by default this card listed five
                    // networks and pushed Bluetooth and Audio off the panel.
                    expanded: false

                    action: Component {
                        ToggleSwitch {
                            checked: NetworkService.wifiEnabled
                            onToggled: NetworkService.toggleWifi()
                        }
                    }

                    // Selection state for the inline flows. Per-card rather than
                    // global so closing and reopening the panel starts clean.
                    property string selectedSsid: ""
                    property string confirmingForgetSsid: ""

                    readonly property bool passwordPromptOpen:
                        selectedSsid !== "" && wifiNeedsPassword(selectedSsid)

                    function wifiNeedsPassword(ssid: string): bool {
                        const list = NetworkService.availableNetworks || [];
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].ssid === ssid)
                                return list[i].requiresPassword && !list[i].known;
                        }
                        return false;
                    }

                    // Closes the password prompt without attempting a join.
                    // Clearing selectedSsid also clears the row's selected
                    // highlight, which is what the prompt's visibility is keyed
                    // off, so there is no second piece of state to reset.
                    function dismissPasswordPrompt(): void {
                        selectedSsid = "";
                    }

                    function signalFor(ssid: string): real {
                        const list = NetworkService.availableNetworks || [];
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].ssid === ssid)
                                return list[i].signalStrength;
                        }
                        return 0;
                    }

                    // Choose what clicking a network does. Selecting a secured
                    // unknown network opens the prompt instead of connecting,
                    // because there is no key to connect with.
                    function activate(ssid: string, known: bool, connected: bool): void {
                        if (connected)
                            return;
                        if (known) {
                            NetworkService.connectToNetwork(ssid);
                            return;
                        }
                        if (wifiNeedsPassword(ssid)) {
                            selectedSsid = cardWifi.selectedSsid === ssid ? "" : ssid;
                            confirmingForgetSsid = "";
                        } else {
                            NetworkService.connectToNetwork(ssid);
                        }
                    }

                    contentComponent: Component {
                        Item {
                            id: wifiBody
                            width: parent ? parent.width : undefined

                            readonly property var nets: NetworkService.availableNetworks || []
                            readonly property int netCount: nets.length

                            // A dense urban environment lists twenty-odd
                            // networks, and rendering every one of them gave the
                            // Wi-Fi card the entire column. Five is enough to
                            // find a network by; the rest are reachable by
                            // scanning once the ones you care about are
                            // remembered as known and sort to the top.
                            readonly property int connectedCount: {
                                let n = 0;
                                for (let i = 0; i < nets.length; i++) {
                                    if (nets[i].connected)
                                        n++;
                                }
                                return n;
                            }

                            // Collapsed, only the connected network is listed --
                            // the one fact the header cannot show. Expanded, the
                            // full list up to the cap.
                            readonly property int visibleCount: cardWifi.expanded
                                ? Math.min(netCount, 5)
                                : Math.min(netCount, connectedCount)

                            readonly property bool hasOverflow:
                                cardWifi.expanded && netCount > visibleCount

                            // 22 for the scan row; 34 per network; the password prompt's
                            // own promptHeight; 26 for a forget
                            // confirmation; 18 for the overflow note. The
                            // trailing term is the Column's own spacing between
                            // its children, which is not part of any child's
                            // height and was being left out -- the last row and
                            // the overflow note were clipped by the card. It
                            // counts visibleCount + 1 + overflow because the
                            // prompt and the forget confirmation are mutually
                            // exclusive, so exactly one of them supplies the
                            // second "+1".
                            implicitHeight: NetworkService.wifiEnabled && NetworkService.available
                                    ? 22
                                      + visibleCount * 34
                                      + (cardWifi.passwordPromptOpen ? pwPrompt.promptHeight : 0)
                                      + (cardWifi.confirmingForgetSsid !== "" ? 26 : 0)
                                      + (hasOverflow ? 18 : 0)
                                      + Theme.spacingSmall
                                        * (cardWifi.expanded
                                               ? (visibleCount + 1 + (hasOverflow ? 1 : 0))
                                               : 0)
                                    : 0
                            height: implicitHeight
                            visible: height > 0

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                height: visible ? 22 : 0
                                visible: cardWifi.expanded
                                verticalAlignment: Text.AlignVCenter
                                text: NetworkService.isScanning
                                    ? qsTr("Scanning...") : qsTr("Scan for networks")
                                color: scanHover.containsMouse
                                    ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontFamilySans
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightDemiBold

                                MouseArea {
                                    id: scanHover
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NetworkService.toggleScan()
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: scanRowProxy.bottom
                                anchors.topMargin: Theme.spacingSmall
                                height: visible ? 30 : 0
                                visible: NetworkService.available && wifiBody.netCount === 0
                                verticalAlignment: Text.AlignVCenter
                                text: NetworkService.isConnecting
                                    ? qsTr("Connecting...") : qsTr("No networks found")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilySans
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Item {
                                id: scanRowProxy
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: 1
                                height: cardWifi.expanded ? 22 : 0
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: scanRowProxy.bottom
                                anchors.topMargin: Theme.spacingSmall
                                spacing: Theme.spacingSmall

                                Repeater {
                                    // Index into the full list rather than a
                                    // modelData delegate, so the visible rows can
                                    // be a prefix of a longer array.
                                    model: NetworkService.wifiEnabled && NetworkService.available
                                        ? wifiBody.visibleCount : 0

                                    delegate: Item {
                                        id: netRow
                                        required property int index

                                        readonly property var net: wifiBody.nets[index]
                                        readonly property string ssid: net.ssid
                                        readonly property bool connected: net.connected
                                        readonly property bool known: net.known
                                        readonly property bool selected:
                                            cardWifi.selectedSsid === ssid

                                        width: wifiBody.width
                                        height: 34

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.radiusMedium
                                            color: netRow.connected || netRowHover.containsMouse
                                                ? Theme.surfaceHover : Theme.surfaceElevated
                                            border.width: Theme.borderWidth
                                            border.color: netRow.selected
                                                ? Theme.borderHover
                                                : (netRow.connected ? Theme.statusGreen : Theme.border)

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Settings.reducedMotion ? 0 : Theme.durationFast
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: netRowHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardWifi.activate(
                                                netRow.ssid, netRow.known, netRow.connected)
                                        }

                                        GlyphIcon {
                                            id: netGlyph
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingMedium
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16
                                            height: 16
                                            glyph: "wifi"
                                            color: netRow.connected ? Theme.statusGreen
                                                : (netRow.known ? Theme.textSecondary : Theme.textDisabled)
                                        }

                                        Text {
                                            anchors.left: netGlyph.right
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.right: strengthText.left
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: netRow.ssid
                                            color: netRow.connected || netRow.known
                                                ? Theme.textPrimary : Theme.textSecondary
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: netRow.connected
                                                ? Theme.fontWeightDemiBold : Theme.fontWeightNormal
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: strengthText
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingMedium
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(netRow.net.signalStrength * 100) + "%"
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeCaption
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: visible ? 18 : 0
                                    visible: wifiBody.hasOverflow
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("+ %1 more").arg(wifiBody.netCount - wifiBody.visibleCount)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSizeCaption
                                }

                                // Password prompt, for a secured network with no
                                // stored profile.
Rectangle {
                                        id: pwPrompt
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    visible: cardWifi.passwordPromptOpen
                                    radius: Theme.radiusMedium
                                    color: Theme.surfaceDeep
                                    border.width: Theme.borderWidth
                                    border.color: Theme.border

                                    // Field and button heights are declared here
                                    // and consumed below so the prompt can never be
                                    // shorter than the stack it contains.
                                    readonly property int fieldHeight: 28
                                    readonly property int buttonHeight: 26

                                    // Single source of truth for the prompt's
                                    // height: the Column's implicitHeight far below
                                    // adds this same value, and the two drifting
                                    // apart is what clipped the overflow note
                                    // before. Label height is measured rather than
                                    // guessed so a font change cannot desync it.
                                    readonly property int promptHeight:
                                          Theme.spacingSmall * 2
                                        + pwLabel.implicitHeight
                                        + Theme.spacingSmall
                                        + fieldHeight
                                        + Theme.spacingSmall
                                        + buttonHeight

                                    height: visible ? promptHeight : 0

                                    Text {
                                        id: pwLabel
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingSmall
                                        anchors.top: parent.top
                                        anchors.topMargin: Theme.spacingSmall
                                        text: qsTr("Password for %1").arg(cardWifi.selectedSsid)
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption
                                        elide: Text.ElideRight
                                        width: parent.width - Theme.spacingSmall * 2
                                    }

                                    // Field background drawn as a sibling rather
                                    // than a `background:` property, which is a
                                    // QtQuick.Controls TextField feature -- and
                                    // this is a core TextInput, so the whole card
                                    // failed to load with "non-existent property".
                                    Item {
                                        id: pwField
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingSmall
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingSmall
                                        anchors.top: pwLabel.bottom
                                        anchors.topMargin: Theme.spacingSmall
                                        height: pwPrompt.fieldHeight

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.radiusSmall
                                            color: Theme.background
                                            border.width: Theme.borderWidth
                                            border.color: pwInput.activeFocus
                                                ? Theme.borderHover : Theme.border
                                        }

                                        TextInput {
                                            id: pwInput
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilyMonospace
                                            font.pixelSize: Theme.fontSizeSmall
                                            echoMode: TextInput.Password
                                            selectionColor: Theme.accentBlue
                                            selectedTextColor: Theme.navyDeep
                                            onAccepted: submitHover.triggered()

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: Theme.spacingSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: pwInput.text === ""
                                                text: qsTr("Network password")
                                                color: Theme.textDisabled
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeCaption
                                            }
                                        }
                                    }

                                    // Cancel, left of Join and the same size. The prompt was
                                    // dismissable only by clicking the
                                    // selected network row again, which toggles
                                    // selectedSsid -- true, but nothing on screen
                                    // said so, so a prompt opened by mistake
                                    // looked like it could not be closed.
                                    Rectangle {
                                        id: pwCancelBtn
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingSmall
                                        anchors.top: pwField.bottom
                                        anchors.topMargin: Theme.spacingSmall
                                        // Half the panel's inner width: two margins,
                                        // the field's, plus the gap between them.
                                        // Join copies this value, so the two are
                                        // equal by construction rather than by two
                                        // independent calculations agreeing.
                                        width: Math.floor((pwPrompt.width
                                                            - Theme.spacingSmall * 3) / 2)
                                        height: pwPrompt.buttonHeight
                                        radius: Theme.radiusSmall
                                        color: pwCancelHover.containsMouse ? Theme.surfaceHover : "transparent"
                                        border.width: Theme.borderWidth
                                        border.color: Theme.border

                                        Text {
                                            id: pwCancelLabel
                                            anchors.centerIn: parent
                                            text: qsTr("Cancel")
                                            color: Theme.textSecondary
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightDemiBold
                                        }

                                        MouseArea {
                                            id: pwCancelHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardWifi.dismissPasswordPrompt()
                                        }
                                    }

                                    Row {
                                        id: pwSubmit
                                        anchors.left: pwCancelBtn.right
                                        anchors.leftMargin: Theme.spacingSmall
                                        anchors.top: pwCancelBtn.top
                                        width: pwCancelBtn.width
                                        height: pwPrompt.buttonHeight
                                        property bool clicked: false

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.radiusSmall
                                            color: submitHover.containsMouse ? Theme.accent : Theme.surfaceSelected
                                            border.width: Theme.borderWidth
                                            border.color: Theme.accent
                                        }

                                        Text {
                                            id: pwSubmitLabel
                                            anchors.centerIn: parent
                                            text: qsTr("Join")
                                            color: Theme.textPrimary
                                            font.family: Theme.fontFamilySans
                                            font.pixelSize: Theme.fontSizeCaption
                                            font.weight: Theme.fontWeightDemiBold
                                        }

                                        MouseArea {
                                            id: submitHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            // Submit is shared between the button and
                                            // Enter in the field.
                                            function triggered(): void {
                                                if (pwInput.text === "")
                                                    return;
                                                NetworkService.connectToNetwork(
                                                    cardWifi.selectedSsid, pwInput.text);
                                                pwInput.text = "";
                                                cardWifi.selectedSsid = "";
                                            }
                                            onClicked: {
                                                if (pwInput.text === "")
                                                    return;
                                                NetworkService.connectToNetwork(
                                                    cardWifi.selectedSsid, pwInput.text);
                                                pwInput.text = "";
                                                cardWifi.selectedSsid = "";
                                            }
                                        }
                                    }
                                }

                                // Forget confirmation.
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: visible ? 26 : 0
                                    visible: cardWifi.confirmingForgetSsid !== ""
                                    radius: Theme.radiusSmall
                                    color: Theme.surfaceDeep
                                    border.width: Theme.borderWidth
                                    border.color: Theme.destructive

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Forget %1?").arg(cardWifi.confirmingForgetSsid)
                                        color: Theme.destructive
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption
                                        elide: Text.ElideRight
                                        width: parent.width - 120
                                    }

                                    Text {
                                        id: forgetYes
                                        anchors.right: forgetNo.left
                                        anchors.rightMargin: Theme.spacingSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Yes")
                                        color: Theme.destructive
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption
                                        font.weight: Theme.fontWeightDemiBold

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NetworkService.forgetNetwork(
                                                    cardWifi.confirmingForgetSsid);
                                                cardWifi.confirmingForgetSsid = "";
                                            }
                                        }
                                    }

                                    Text {
                                        id: forgetNo
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("No")
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardWifi.confirmingForgetSsid = ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Card {
                    id: cardBluetooth
                    width: parent.width
                    title: qsTr("Bluetooth")
                    subtitle: BluetoothService.powered
                        ? (BluetoothService.isConnected && BluetoothService.deviceName !== ""
                           ? BluetoothService.deviceName
                           : qsTr("%1 paired").arg(BluetoothService.pairedDevices.count))
                        : qsTr("Off")
                    icon: "bluetooth"
                    accent: Theme.accentBlue
                    collapsible: true

                    action: Component {
                        ToggleSwitch {
                            checked: BluetoothService.powered
                            onToggled: BluetoothService.togglePower()
                        }
                    }

                    contentComponent: Component {
                        Item {
                            id: btBody
                            width: parent ? parent.width : undefined

                            readonly property int rowCount:
                                BluetoothService.powered
                                    ? BluetoothService.deviceModel.count : 0

                            // Devices are 34 tall each, the scan row is 22, the
                            // empty message 34, and the trailing term is the
                            // Column's spacing between its children.
                            implicitHeight: BluetoothService.powered
                                    ? 22 + (rowCount === 0 ? 34 : 0)
                                      + rowCount * 34
                                      + Theme.spacingSmall * (1 + rowCount)
                                    : 0
                            height: implicitHeight
                            visible: BluetoothService.powered

                            Row {
                                id: scanRow
                                anchors.left: parent.left
                                anchors.top: parent.top
                                height: 22
                                spacing: Theme.spacingSmall

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: BluetoothService.isScanning
                                        ? qsTr("Scanning...") : qsTr("Scan for devices")
                                    color: scanHover.containsMouse
                                        ? Theme.textPrimary : Theme.textSecondary
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightDemiBold

                                    MouseArea {
                                        id: scanHover
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BluetoothService.toggleScan()
                                    }
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: scanRow.bottom
                                anchors.topMargin: Theme.spacingSmall
                                spacing: Theme.spacingSmall

                                Text {
                                    width: parent.width
                                    height: visible ? 34 : 0
                                    visible: btBody.rowCount === 0
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("No paired devices")
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamilySans
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Repeater {
                                    model: BluetoothService.powered
                                        ? BluetoothService.deviceModel : null

                                    delegate: Rectangle {
                                        id: btRow
                                        required property string mac
                                        required property string name
                                        required property bool connected
                                        required property bool paired

                                        width: btBody.width
                                        height: 34
                                        radius: Theme.radiusMedium
                                        color: rowHover.containsMouse ? Theme.surfaceHover : Theme.surfaceElevated
                                        border.width: Theme.borderWidth
                                        border.color: Theme.border

                                        Behavior on color {
                                            ColorAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationFast }
                                        }

                                        MouseArea {
                                            id: rowHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }

                                        GlyphIcon {
                                            id: btGlyph
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingMedium
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16
                                            height: 16
                                            glyph: "bluetooth"
                                            color: btRow.connected ? Theme.statusGreen : Theme.textSecondary
                                        }

                                        Column {
                                            anchors.left: btGlyph.right
                                            anchors.leftMargin: Theme.spacingSmall
                                            anchors.right: actionBtn.left
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0

                                            Text {
                                                width: parent.width
                                                text: btRow.name.length > 0 ? btRow.name : btRow.mac
                                                color: Theme.textPrimary
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Theme.fontWeightDemiBold
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: btRow.connected ? qsTr("Connected")
                                                    : btRow.paired ? qsTr("Paired")
                                                    : qsTr("Available")
                                                color: btRow.connected ? Theme.statusGreen : Theme.textSecondary
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeCaption
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // One button, whose action follows the
                                        // device's state rather than four
                                        // controls per row.
                                        Rectangle {
                                            id: actionBtn
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: actionLabel.implicitWidth + Theme.spacingMedium * 2
                                            height: 24
                                            radius: Theme.radiusSmall
                                            color: actionHover.containsMouse ? Theme.surfaceHover : "transparent"
                                            border.width: Theme.borderWidth
                                            border.color: btRow.connected ? Theme.destructive : Theme.border

                                            Text {
                                                id: actionLabel
                                                anchors.centerIn: parent
                                                text: btRow.connected ? qsTr("Disconnect")
                                                    : btRow.paired ? qsTr("Connect")
                                                    : qsTr("Pair")
                                                color: btRow.connected
                                                    ? Theme.destructive : Theme.textSecondary
                                                font.family: Theme.fontFamilySans
                                                font.pixelSize: Theme.fontSizeCaption
                                                font.weight: Theme.fontWeightDemiBold
                                            }

                                            MouseArea {
                                                id: actionHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (btRow.connected)
                                                        BluetoothService.disconnectDevice(btRow.mac);
                                                    else if (btRow.paired)
                                                        BluetoothService.connectDevice(btRow.mac);
                                                    else
                                                        BluetoothService.pairDevice(btRow.mac);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Card {
                    id: cardAudio
                    width: parent.width
                    title: qsTr("Audio & Media")
                    subtitle: AudioService.available && AudioService.sinkName !== ""
                        ? AudioService.sinkName : ""
                    icon: "speaker"
                    accent: Theme.accentBlue
                    collapsible: true

                    action: Component {
                        ToggleSwitch {
                            checked: !AudioService.muted
                            onToggled: AudioService.toggleMute()
                        }
                    }

                    contentComponent: Component {
                        Item {
                            id: audioBody
                            width: parent ? parent.width : undefined
                            // The transport is the only thing left in this card, so
                            // the height no longer varies with whether a microphone
                            // exists. That conditional was the 24px of slack for the
                            // capture row; with both level rows gone it is dead, and
                            // the audio card is the same height whether or not the
                            // machine has an input device.
                            implicitHeight: 52
                            height: implicitHeight

                            // Output and capture levels are not here. Both moved to
                            // the radial (AUD.03 output, AUD.04 mic volume, AUD.05 mic
                            // mute) because a slider in a card that also has transport
                            // controls is a second place to look for the same setting,
                            // and the two could disagree. Nothing is lost: the radial
                            // drives the same AudioService calls.
                            //
                            // The transport block below used to be positioned against
                            // outputRow.bottom; it is anchored to the top instead.

                            // Transport.
                            Rectangle {
                                id: transport
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 52
                                radius: Theme.radiusMedium
                                color: Theme.surfaceElevated
                                border.width: Theme.borderWidth
                                border.color: Theme.border

                                // Clipped by a Rectangle rather than a rounded
                                // Image: Image has no radius of its own, and an
                                // opacity mask for one 40px thumbnail is not
                                // worth the extra render pass.
                                Rectangle {
                                    id: art
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    height: 40
                                    radius: Theme.radiusSmall
                                    clip: true
                                    color: Theme.surfaceHover
                                    border.width: Theme.borderWidth
                                    border.color: Theme.border

                                    Image {
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                        source: root.activePlayer !== null
                                            && root.activePlayer.trackArtUrl !== ""
                                            ? root.activePlayer.trackArtUrl : ""
                                    }

                                    // Stands in when there is no art, so the row
                                    // keeps its rhythm.
                                    GlyphIcon {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        visible: art.children.length === 1
                                            || (art.children[0].visible === false)
                                        glyph: "speaker"
                                        color: Theme.textDisabled
                                    }
                                }

                                Column {
                                    anchors.left: art.right
                                    anchors.leftMargin: Theme.spacingSmall
                                    anchors.right: transportButtons.left
                                    anchors.rightMargin: Theme.spacingSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: root.activePlayer !== null
                                            && root.activePlayer.trackTitle !== ""
                                            ? root.activePlayer.trackTitle.trim()
                                            : qsTr("Nothing playing")
                                        color: root.activePlayer !== null
                                            ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightDemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.activePlayer !== null
                                            && root.activePlayer.trackArtist !== ""
                                            ? root.activePlayer.trackArtist.trim()
                                            : (root.activePlayer !== null
                                               ? root.activePlayer.identity : "")
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamilySans
                                        font.pixelSize: Theme.fontSizeCaption
                                        elide: Text.ElideRight
                                    }
                                }

                                Row {
                                    id: transportButtons
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXs

                                    // Disabled rather than hidden when the player
                                    // cannot do it, so the row does not reflow as
                                    // capabilities change.
                                    Repeater {
                                        model: [
                                            { act: "previous", glyph: "skipPrevious", rot: 0,  enabled: root.activePlayer !== null && root.activePlayer.canGoPrevious },
                                            { act: "toggle",  glyph: "play",         rot: 0,  enabled: root.activePlayer !== null && root.activePlayer.canControl },
                                            { act: "next",     glyph: "skipNext",     rot: 0,  enabled: root.activePlayer !== null && root.activePlayer.canGoNext }
                                        ]
                                        delegate: Item {
                                            id: btn
                                            required property var modelData
                                            width: 28
                                            height: 28

                                            readonly property bool actionEnabled:
                                                modelData.enabled && !SessionService.isBusy

                                            GlyphIcon {
                                                anchors.centerIn: parent
                                                width: 16
                                                height: 16
                                                glyph: btn.modelData.act === "toggle"
                                                    ? (root.isPlaying ? "pause" : "play")
                                                    : btn.modelData.glyph
                                                rotation: btn.modelData.rot
                                                color: btn.actionEnabled
                                                    ? (btnHover.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                                    : Theme.textDisabled
                                            }

                                            MouseArea {
                                                id: btnHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: btn.actionEnabled
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const p = root.activePlayer;
                                                    if (p === null)
                                                        return;
                                                    if (btn.modelData.act === "previous")
                                                        p.previous();
                                                    else if (btn.modelData.act === "next")
                                                        p.next();
                                                    else
                                                        p.togglePlaying();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                            // A StatRing with a caption is 78 tall, so 76 clipped
                            // the bottom of the rings by 2px.
                            implicitHeight: 78
                            height: 78

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
                            // `pendingAction` is declared on this card, so write
                            // it through the card's own id. These four sites said
                            // `root.pendingAction`, and `root` is the command
                            // centre, which has no such property -- the assignment
                            // threw "Cannot assign to non-existent property" and
                            // aborted the function, so the confirmation never
                            // armed and Logout, Reboot and Poweroff did nothing.
                            //
                            // Unqualified does not work either: `isConfirming` reads
                            // `pendingAction` fine because a binding is evaluated in
                            // the object's scope, but a bare assignment inside a
                            // function body is plain JavaScript and binds a global.
                            cardPower.pendingAction = key;
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
                        cardPower.pendingAction = "";
                    }

                    function confirmAction(): void {
                        const action = cardPower.pendingAction;
                        cardPower.pendingAction = "";
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
                            // The tiles are 64 tall, so reserving 76 left 12px of dead
                            // space under them -- the other half of the bottom-heavy
                            // gap the card's own padding was only part of.
                            implicitHeight: 64
                            height: 64

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
                      // Count of calendars actually contributing, so an empty
                      // title bar is distinguishable from "nothing scheduled".
                      subtitle: CalendarService.calendarCount > 0
                          ? qsTr("%1 file(s)").arg(CalendarService.calendarCount)
                          : ""
                      icon: "calendar"
                      accent: Theme.accentBlue
                      collapsible: true

                      contentComponent: CalendarAgenda {}
                  }
            }
        }
    }
}