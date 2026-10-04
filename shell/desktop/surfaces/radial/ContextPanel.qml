pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
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
        NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
    }

    // Slide transition
    transform: Translate {
        x: root.isExpanded ? 0 : 60
        Behavior on x {
            NumberAnimation { duration: Theme.durationSlow; easing.type: Easing.OutCubic }
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
            duration: Theme.durationNormal
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
        Rectangle {
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
                        text: "PREREQUISITE LOCKED"
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightBold
                        color: Theme.warningRed
                    }

                    Text {
                        text: root.currentNode ? (root.currentNode.lockReason || "Prerequisites not fulfilled.") : ""
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
            Layout.preferredHeight: 90
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

            // 5. Readonly Value Readout
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

        Item {
            Layout.fillHeight: true
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
