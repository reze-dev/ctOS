pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"
import "../components"
import "../widgets"

Item {
    id: root

    // =========================================================================
    // Properties
    // =========================================================================

    property var model: null
    property int focusedCategoryIndex: 0
    property string selectedNodeId: ""
    property bool isExpanded: false

    readonly property var currentCategory: model ? model.getCategory(focusedCategoryIndex) : null
    readonly property var currentNode: (model && currentCategory) ? model.getNode(focusedCategoryIndex, selectedNodeId) : null

    readonly property bool isLocked: currentNode ? Boolean(currentNode.locked) : false
    readonly property bool isActive: {
        if (!currentNode || !model) return false;
        var _ = model.revision;
        return typeof currentNode.value === "function" && Boolean(currentNode.value());
    }

    // Whether a status pill means anything for this control.
    //
    // isActive is Boolean(value()), which is the right question for a toggle and
    // a slider and nonsense for a picker: a picker's value() is the name of the
    // selected option, so every option is truthy and the pill would read
    // "ONLINE // ACTIVE" no matter which one was chosen. Rather than make picker
    // nodes lie about their value to satisfy the pill, the pill stands down.
    readonly property bool showsStatusPill:
        currentNode
        && currentNode.controlType !== "picker"
        && currentNode.controlType !== "browser"
        && currentNode.controlType !== "readonly"
        && !root.isLocked

    // The one control that is a list rather than a row, and the only one that
    // needs the panel's remaining height. See the control box below.
    readonly property bool currentIsBrowser:
        currentNode && currentNode.controlType === "browser"

    width: parent ? Math.min(440, Math.max(340, parent.width * 0.3)) : 440
    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.right: parent ? parent.right : undefined
    anchors.topMargin: parent ? Math.max(50, parent.height * 0.06) : 60
    anchors.bottomMargin: parent ? Math.max(20, parent.height * 0.04) : 40
    anchors.rightMargin: parent ? Math.max(16, parent.width * 0.02) : 40

    opacity: isExpanded ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic }
    }

    // Slide transition
    transform: Translate {
        x: root.isExpanded ? 0 : 60
        Behavior on x {
            NumberAnimation { duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.OutCubic }
        }
    }

    // Panel Background
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Theme.gray900
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    // Corner Brackets
    CornerBrackets {
        bracketColor: root.isLocked ? Theme.warningRed : Theme.acidGreen
    }

    // Inside click consumer
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function(mouse) {
            mouse.accepted = true;
        }
        onWheel: function(wheel) {
            wheel.accepted = true;
        }
    }

    onSelectedNodeIdChanged: {
        if (root.isExpanded) {
            contentTransitionAnim.restart();
        }
    }

    SequentialAnimation {
        id: contentTransitionAnim
        PropertyAction { target: layout; property: "opacity"; value: 0.2 }
        NumberAnimation {
            target: layout
            property: "opacity"
            to: 1.0
            duration: Settings.reducedMotion ? 0 : Theme.durationNormal
            easing.type: Easing.OutCubic
        }
    }

    // Main Content Column
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.paddingXl
        spacing: Theme.spacingLarge

        // Category Breadcrumb Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 12
                color: root.isLocked ? Theme.warningRed : Theme.acidGreen
            }

            Text {
                text: {
                    var catName = root.currentCategory ? root.currentCategory.name : "SYSTEM";
                    var nodeSub = root.currentNode ? root.currentNode.subtitle : "NODE.00";
                    return catName + " // " + nodeSub;
                }
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
                color: root.isLocked ? Theme.warningRed : Theme.acidGreen
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        // Node Title
        Text {
            id: titleText
            text: root.currentNode ? root.currentNode.title : "-- NO NODE SELECTED --"
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Theme.fontWeightBold
            color: Theme.textPrimary
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Status Pill Badge
        //
        // Hidden where it would be meaningless -- see root.showsStatusPill. A
        // readonly node states its value in the control area below, and a picker
        // states it beside the SELECT OPTION caption.
        Rectangle {
            visible: root.showsStatusPill
            Layout.preferredHeight: 24
            Layout.preferredWidth: statusText.implicitWidth + 16
            radius: Theme.radiusSmall
            color: Theme.gray800
            border.width: 1
            border.color: root.isLocked ? Theme.warningRed : (root.isActive ? Theme.acidGreen : Theme.gray600)

            Text {
                id: statusText
                anchors.centerIn: parent
                text: {
                    if (root.isLocked) return "RESTRICTED // ACCESS DENIED";
                    if (root.isActive) return "ONLINE // ACTIVE";
                    return "STANDBY";
                }
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                color: root.isLocked ? Theme.warningRed : (root.isActive ? Theme.acidGreen : Theme.textSecondary)
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.dividerWidth
            color: Theme.gray700
        }

        // Locked Prerequisite Warning Alert Banner
        Rectangle {
            id: lockedAlertBanner
            Layout.fillWidth: true
            Layout.preferredHeight: alertCol.implicitHeight + 20
            color: Theme.gray800
            border.color: Theme.warningRed
            border.width: 1
            visible: root.isLocked

            RowLayout {
                id: alertCol
                anchors.fill: parent
                anchors.margins: Theme.paddingMedium
                spacing: Theme.spacingMedium

                CtosIcon {
                    name: "warning"
                    size: 24
                    color: Theme.warningRed
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        // Was an unconditional "PREREQUISITE LOCKED". No node is
                        // gated on another node's state: `requires` records what a
                        // branch hangs off, which `edges` already expresses, and
                        // every setting in the tree is independently reachable. The
                        // locks that remain are real conditions -- an absent
                        // NetworkManager, an absent input device, a dead awww
                        // daemon -- so the banner names the condition rather than
                        // inventing a prerequisite graph that does not exist.
                        text: "UNAVAILABLE"
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        color: Theme.destructive
                    }

                    Text {
                        text: root.currentNode ? (root.currentNode.lockReason || "This control is unavailable right now.") : ""
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textPrimaryDim
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Description Text
        Text {
            id: descText
            text: root.currentNode ? root.currentNode.description : ""
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeBody
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            lineHeight: 1.3
        }

        // Interactive Settings Control Box
        Item {
            Layout.fillWidth: true

            // 90 for the four single-row controls, which is what this has always
            // been sized for. The browser is a list, so it takes the rest of the
            // panel instead -- and only it does, because filling the height
            // unconditionally would leave every other control's row floating in
            // the middle of a very tall empty box.
            Layout.preferredHeight: root.currentIsBrowser ? 0 : 90
            Layout.fillHeight: root.currentIsBrowser
            visible: root.currentNode !== null

            // 1. Toggle Control
            Item {
                anchors.fill: parent
                visible: root.currentNode && root.currentNode.controlType === "toggle" && !root.isLocked

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingLarge

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "STATE TOGGLE"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            color: Theme.textMuted
                        }

                        Text {
                            text: {
                                if (!root.currentNode || !root.model) return "OFF";
                                var _ = root.model.revision;
                                return (typeof root.currentNode.valueText === "function") ? root.currentNode.valueText() : "OFF";
                            }
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightBold
                            color: root.isActive ? Theme.acidGreen : Theme.textPrimaryDim
                        }
                    }

                    Rectangle {
                        id: toggleBtn
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 36
                        radius: Theme.radiusSmall
                        color: root.isActive ? Theme.acidGreen : Theme.gray800
                        border.color: root.isActive ? Theme.acidGreen : Theme.gray600
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.isActive ? "ENABLED" : "DISABLED"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            color: root.isActive ? Theme.gray900 : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentNode && typeof root.currentNode.execute === "function") {
                                    root.currentNode.execute();
                                }
                            }
                        }
                    }
                }
            }

            // 2. Slider Control
            Item {
                anchors.fill: parent
                visible: root.currentNode && root.currentNode.controlType === "slider" && !root.isLocked

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "MAGNITUDE LEVEL"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (!root.currentNode || !root.model) return "0";
                                var _ = root.model.revision;
                                return (typeof root.currentNode.valueText === "function") ? root.currentNode.valueText() : "0";
                            }
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Theme.fontWeightBold
                            color: Theme.acidGreen
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMedium

                        // Minus step button
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            color: Theme.gray800
                            border.color: Theme.gray600
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "-"
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.currentNode) return;
                                    var current = (typeof root.currentNode.value === "function") ? root.currentNode.value() : 0;
                                    var step = root.currentNode.step || 1;
                                    var minVal = root.currentNode.minVal ?? 0;
                                    var nextVal = Math.max(minVal, current - step);
                                    if (typeof root.currentNode.execute === "function") {
                                        root.currentNode.execute(nextVal);
                                    }
                                }
                            }
                        }

                        // Slider Bar Visual
                        Rectangle {
                            id: sliderTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            color: Theme.gray800
                            border.color: Theme.gray700
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: {
                                    if (!root.currentNode) return 0;
                                    var _ = root.model ? root.model.revision : 0;
                                    var current = (typeof root.currentNode.value === "function") ? root.currentNode.value() : 0;
                                    var minVal = root.currentNode.minVal ?? 0;
                                    var maxVal = root.currentNode.maxVal ?? 100;
                                    var fraction = Math.max(0.0, Math.min(1.0, (current - minVal) / Math.max(1, maxVal - minVal)));
                                    return parent.width * fraction;
                                }
                                color: Theme.acidGreen
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                function updateFromTrack(mouseX) {
                                    if (!root.currentNode || typeof root.currentNode.execute !== "function") return;
                                    var minVal = root.currentNode.minVal ?? 0;
                                    var maxVal = root.currentNode.maxVal ?? 100;
                                    var fraction = Math.max(0.0, Math.min(1.0, mouseX / sliderTrack.width));
                                    var targetVal = minVal + fraction * (maxVal - minVal);
                                    var step = root.currentNode.step || 1;
                                    targetVal = Math.round(targetVal / step) * step;
                                    root.currentNode.execute(targetVal);
                                }

                                onPressed: function(mouse) { updateFromTrack(mouse.x); }
                                onPositionChanged: function(mouse) { if (pressed) updateFromTrack(mouse.x); }
                            }
                        }

                        // Plus step button
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            color: Theme.gray800
                            border.color: Theme.gray600
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.currentNode) return;
                                    var current = (typeof root.currentNode.value === "function") ? root.currentNode.value() : 0;
                                    var step = root.currentNode.step || 1;
                                    var maxVal = root.currentNode.maxVal ?? 100;
                                    var nextVal = Math.min(maxVal, current + step);
                                    if (typeof root.currentNode.execute === "function") {
                                        root.currentNode.execute(nextVal);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Action Control
            Item {
                anchors.fill: parent
                visible: root.currentNode && root.currentNode.controlType === "action" && !root.isLocked

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingLarge

                    Text {
                        text: "MANUAL TRIGGER"
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        color: Theme.textMuted
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 36
                        color: Theme.gray800
                        border.color: Theme.acidGreen
                        border.width: 1
                        radius: Theme.radiusSmall

                        Text {
                            anchors.centerIn: parent
                            text: (root.currentNode && root.currentNode.actionLabel) ? root.currentNode.actionLabel : "EXECUTE"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightBold
                            color: Theme.acidGreen
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.currentNode && typeof root.currentNode.execute === "function") {
                                    root.currentNode.execute();
                                }
                            }
                        }
                    }
                }
            }

            // 4. Picker Control
            //
            // A discrete choice among named options, where a slider would be a
            // lie: theme and wallpaper are a small closed set, not a magnitude.
            //
            // Deliberately not arrow-driven. NavigationController.handleKeyPress
            // already spends Left/Right on spatial traversal between nodes, so a
            // picker that claimed them would either break node navigation or be
            // unreachable by keyboard. Instead a chip selects directly on click,
            // and the node's own execute() cycles when called with no argument,
            // which is what ENTER reaches through executeCurrentNode().
            Item {
                anchors.fill: parent
                visible: root.currentNode && root.currentNode.controlType === "picker" && !root.isLocked

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "SELECT OPTION"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (!root.currentNode || !root.model) return "--";
                                var _ = root.model.revision;
                                return (typeof root.currentNode.valueText === "function") ? root.currentNode.valueText() : "--";
                            }
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Theme.fontWeightBold
                            color: Theme.acidGreen
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Repeater {
                            model: (root.currentNode && Array.isArray(root.currentNode.options)) ? root.currentNode.options : []

                            delegate: Rectangle {
                                id: optionChip
                                required property var modelData

                                // Options are either bare strings or objects with a
                                // label and an optional distinct value, so a node can
                                // display something readable while storing an
                                // identifier the service understands.
                                readonly property string label: {
                                    if (typeof modelData === "string") return modelData;
                                    if (modelData && modelData.label) return modelData.label;
                                    return "";
                                }
                                readonly property string optionValue: {
                                    if (typeof modelData === "string") return modelData;
                                    if (modelData && modelData.value !== undefined) return modelData.value;
                                    return optionChip.label;
                                }
                                readonly property bool isCurrent: {
                                    if (!root.currentNode || !root.model) return false;
                                    var _ = root.model.revision;
                                    if (typeof root.currentNode.value !== "function") return false;
                                    return root.currentNode.value() === optionChip.optionValue;
                                }

                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: Theme.radiusSmall
                                color: isCurrent ? Theme.acidGreen : Theme.gray800
                                border.color: isCurrent ? Theme.acidGreen : Theme.gray600
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.spacingMedium
                                    text: optionChip.label
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightBold
                                    color: optionChip.isCurrent ? Theme.gray900 : Theme.textSecondary
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.currentNode && typeof root.currentNode.execute === "function") {
                                            root.currentNode.execute(optionChip.optionValue);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. Browser Control
            //
            // Directory plus a grid of what is in it. Not a picker: a picker
            // offers a closed set the panel already knows about, and this is an
            // open one the user points at. It also has to stay legible when the
            // directory is empty, when it does not exist, and while a scan is in
            // flight, which a row of chips has no room to say.
            Item {
                id: browserControl
                anchors.fill: parent
                visible: root.currentNode && root.currentNode.controlType === "browser" && !root.isLocked

                // Held on the service so it survives the node being unselected,
                // and so a half-typed path is not thrown away by a click
                // elsewhere in the tree.
                property string dirDraft: ""

                function adoptDirectory() {
                    if (browserControl.dirDraft !== WallpaperService.directory) {
                        WallpaperService.setDirectory(browserControl.dirDraft);
                    }
                }

                // Adopting on activation rather than on every keystroke: a scan
                // per character would fork a process per character, and a
                // half-typed path is not a directory anyway.
                onVisibleChanged: {
                    if (visible) {
                        browserControl.dirDraft = WallpaperService.directory;
                        // Re-list on open. The service scans once at startup and
                        // again only when the directory changes -- deliberately,
                        // since a watch would mean holding a descriptor open on a
                        // path the user can point anywhere -- so files added or
                        // deleted while the shell was running never appeared or
                        // disappeared here. The grid showed whatever the directory
                        // held at boot, indefinitely.
                        //
                        // Opening the browser is a deliberate act and costs one
                        // `sh`, so that is the moment worth paying for a fresh
                        // listing.
                        WallpaperService.rescan();
                    }
                }
                Component.onCompleted: {
                    browserControl.dirDraft = WallpaperService.directory;
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSmall

                    // --- directory row ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            text: "DIRECTORY"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            color: Theme.textMuted
                        }

                        // Core TextInput with a sibling background, not a Controls
                        // TextField. The desktop tree does not take a
                        // QtQuick.Controls dependency: the Wi-Fi prompt in
                        // CommandCenter hit exactly this and had to be rewritten,
                        // because `background:` is a Controls feature and a core
                        // TextInput does not have it. Placeholder text is a
                        // Controls feature too, hence the sibling Text.
                        Item {
                            id: dirField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: Theme.gray800
                                border.color: dirField.activeFocus ? Theme.acidGreen : Theme.gray600
                                border.width: 1
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingSmall
                                anchors.rightMargin: Theme.spacingSmall
                                verticalAlignment: Text.AlignVCenter
                                visible: dirInput.text.length === 0
                                text: "~/.local/share/ctos/wallpapers"
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                color: Theme.textMuted
                                elide: Text.ElideMiddle
                            }

                            TextInput {
                                id: dirInput
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingSmall
                                anchors.rightMargin: Theme.spacingSmall
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true

                                text: browserControl.dirDraft
                                color: Theme.textPrimary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                selectByMouse: true
                                selectionColor: Theme.acidGreen
                                selectedTextColor: Theme.textInverse

                                onTextEdited: browserControl.dirDraft = text
                                onAccepted: browserControl.adoptDirectory()

                                Keys.onEscapePressed: {
                                    // Abandon the edit rather than committing a
                                    // path the user did not mean to type.
                                    browserControl.dirDraft = WallpaperService.directory;
                                    text = browserControl.dirDraft;
                                }
                            }
                        }

                        Rectangle {
                            id: applyDirButton
                            Layout.preferredWidth: scanLabel.implicitWidth + Theme.spacingLarge
                            Layout.preferredHeight: 28
                            radius: Theme.radiusSmall
                            color: applyDirMouse.pressed ? Theme.acidGreen : Theme.gray800
                            border.color: Theme.acidGreen
                            border.width: 1

                            Text {
                                id: scanLabel
                                anchors.centerIn: parent
                                text: WallpaperService.scanning ? "SCAN" : "SET"
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeCaption
                                font.weight: Theme.fontWeightBold
                                color: applyDirMouse.pressed ? Theme.textInverse : Theme.acidGreen
                            }

                            MouseArea {
                                id: applyDirMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !WallpaperService.scanning
                                onClicked: browserControl.adoptDirectory()
                            }
                        }
                    }

                    // --- status line ---
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (WallpaperService.scanning) return "SCANNING " + WallpaperService.directory + " ...";
                            if (!WallpaperService.scanned) return "";
                            if (WallpaperService.lastError !== "") return WallpaperService.lastError;
                            if (WallpaperService.count === 0) return "NO IMAGES IN " + WallpaperService.directory;
                            return WallpaperService.count + (WallpaperService.count === 1 ? " IMAGE" : " IMAGES")
                                + (WallpaperService.count >= WallpaperService.maxWallpapers ? " (CAPPED)" : "")
                                + "  //  " + WallpaperService.currentName;
                        }
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeMicro
                        color: WallpaperService.lastError !== "" ? Theme.destructive : Theme.textMuted
                        elide: Text.ElideMiddle
                        Layout.maximumHeight: 14
                    }

                    // --- the grid ---
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: Theme.gray900
                        border.color: Theme.gray700
                        border.width: 1

                        // Two per row. With the control box now taking the panel's
                        // remaining height there is room for tiles big enough to
                        // recognise a wallpaper, and one-per-row wasted most of
                        // it on scrolling.
                        //
                        // cellWidth and cellHeight are derived from `width`
                        // directly. Routing them through intermediate readonly
                        // properties on the GridView broke the column count --
                        // the view laid the delegates out one per row instead of
                        // two, which is a silent layout fault rather than a
                        // visible error.
                        //
                        // The height is floor(halfWidth * 9/16) plus a 16px label
                        // band, so the thumbnails keep their aspect and the
                        // filename stays legible underneath.
                        GridView {
                            id: wallpaperGrid
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSmall
                            clip: true
                            model: WallpaperService.wallpapers
                            boundsBehavior: Flickable.StopAtBounds

                            cellWidth: Math.floor(width / 2)
                            cellHeight: Math.floor(Math.floor(width / 2) * 9 / 16) + 20

                            delegate: Rectangle {
                                id: wallpaperTile
                                required property var modelData

                                readonly property bool isCurrent:
                                    modelData.name === WallpaperService.currentName
                                readonly property int labelHeight: 16

                                width: GridView.view.cellWidth - Theme.spacingSmall
                                height: GridView.view.cellHeight - Theme.spacingSmall
                                radius: Theme.radiusSmall
                                color: mouse.containsMouse ? Theme.gray800 : Theme.surface
                                border.color: isCurrent ? Theme.acidGreen : Theme.gray700
                                border.width: isCurrent ? 2 : 1

                                // sourceSize is what keeps this affordable: the
                                // shipped images are 6000-7500px wide and tens of
                                // megabytes, and a grid that decoded them at full
                                // size would exhaust memory long before it filled.
                                Image {
                                    id: thumb
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 2
                                    height: parent.height - wallpaperTile.labelHeight - 4
                                    source: "file://" + modelData.path
                                    sourceSize.width: 300
                                    sourceSize.height: 170
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    clip: true
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 3
                                    text: modelData.name
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeMicro
                                    color: Theme.textSecondary
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.currentNode && typeof root.currentNode.execute === "function") {
                                            root.currentNode.execute(modelData.name);
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: WallpaperService.scanned && WallpaperService.count === 0 && !WallpaperService.scanning
                            text: "EMPTY"
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDisabled
                        }

                        // Scroll indicator, hand-rolled.
                        //
                        // QtQuick.Controls' ScrollBar is not available here -- this
                        // panel deliberately has no Controls dependency, the same
                        // constraint that forced the directory field above to be a
                        // core TextInput with a sibling background -- so the track
                        // and thumb are built by hand. The grid already flicks on
                        // wheel and drag; what it had was no indication that it
                        // could, which matters more now that it holds five rows.
                        Rectangle {
                            id: scrollTrack
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 4
                            radius: 2
                            visible: wallpaperGrid.contentHeight > wallpaperGrid.height
                            color: Theme.gray700

                            readonly property real usable:
                                height - thumb.height

                            Rectangle {
                                id: thumb
                                width: parent.width
                                radius: 2
                                color: Theme.acidGreen
                                opacity: 0.8

                                // Proportional to the visible fraction, with a
                                // floor so a long list still leaves a thumb you
                                // can see and aim at.
                                height: Math.max(
                                    24,
                                    scrollTrack.height
                                        * (wallpaperGrid.height / Math.max(1, wallpaperGrid.contentHeight)))

                                y: wallpaperGrid.contentY
                                    * (scrollTrack.usable / Math.max(1, wallpaperGrid.contentHeight - wallpaperGrid.height))
                            }
                        }
                    }
                }
            }

            // 6. Readonly Value Readout
            Item {
                anchors.fill: parent
                visible: root.currentNode && (root.currentNode.controlType === "readonly" || root.isLocked)

                RowLayout {
                    anchors.fill: parent

                    Text {
                        text: "METRIC STATE"
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        color: Theme.textMuted
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: valText.implicitWidth + 24
                        color: Theme.gray800
                        border.color: root.isLocked ? Theme.warningRed : Theme.gray600
                        border.width: 1

                        Text {
                            id: valText
                            anchors.centerIn: parent
                            text: {
                                if (!root.currentNode || !root.model) return "--";
                                var _ = root.model.revision;
                                return (typeof root.currentNode.valueText === "function") ? root.currentNode.valueText() : "--";
                            }
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeBody
                            font.weight: Theme.fontWeightBold
                            color: root.isLocked ? Theme.warningRed : Theme.textPrimary
                        }
                    }
                }
            }
        }

        // Filler that pins the key hint to the bottom.
        //
        // It yields when the browser is active, because the control box above is
        // also fillHeight and QtQuick.Layouts splits leftover space equally among
        // every fillHeight item. With both filling, the browser's control box
        // received roughly half the leftover and the wallpaper grid was left at
        // 328px regardless of a 972px panel -- two rows on a screen with room for
        // six. Only one of the two needs the space, and it is the browser.
        Item {
            Layout.fillHeight: !root.currentIsBrowser
        }

        // Bottom Tactical Key Navigation Hint
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: Theme.gray800
            border.color: Theme.gray700
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMedium
                anchors.rightMargin: Theme.paddingMedium

                Text {
                    text: "[ENTER] ACTIVATE   [ESC] BACK   [ARROWS] SELECT"
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }
            }
        }
    }

    function executeCurrentNode() {
        if (!currentNode || isLocked) return;
        if (typeof currentNode.execute === "function") {
            currentNode.execute();
        }
    }
}
