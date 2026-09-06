import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../core"
import "./components"

FocusScope {
    id: root

    width: 680
    height: 500
    focus: true

    // Background styling: near-black with hairline border
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Theme.gray900
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    // Corner brackets matching ctOS visual grammar
    Item {
        id: cornerBrackets
        anchors.fill: parent
        z: 10

        // Top-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: Theme.acidGreen
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: Theme.acidGreen
        }

        // Top-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: Theme.acidGreen
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: Theme.cornerBracketMargin
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: Theme.acidGreen
        }

        // Bottom-Left
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: Theme.acidGreen
        }
        Rectangle {
            x: Theme.cornerBracketMargin
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: Theme.acidGreen
        }

        // Bottom-Right
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            width: Theme.cornerBracketArmLength
            height: Theme.cornerBracketThickness
            color: Theme.acidGreen
        }
        Rectangle {
            x: parent.width - Theme.cornerBracketMargin - Theme.cornerBracketThickness
            y: parent.height - Theme.cornerBracketMargin - Theme.cornerBracketArmLength
            width: Theme.cornerBracketThickness
            height: Theme.cornerBracketArmLength
            color: Theme.acidGreen
        }
    }

    // Inside clicks consumed so they don't dismiss scrim
    MouseArea {
        id: insideClickConsumer
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: function (mouse) {
            mouse.accepted = true;
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.paddingLarge
        spacing: Theme.spacingMedium

        // Header Category Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Text {
                text: "// COMMAND DECK"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightBold
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "SYSTEM READY"
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
            }
        }

        // Query Input Row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.maximumHeight: 36
            Layout.fillHeight: false
            spacing: Theme.spacingMedium

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: ">"
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Theme.fontWeightBold
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TextInput {
                    id: queryInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeTitle
                    color: Theme.textPrimary
                    selectionColor: Theme.surfaceSelected
                    selectedTextColor: Theme.textPrimary
                    cursorVisible: activeFocus
                    focus: true

                    cursorDelegate: Component {
                        Rectangle {
                            width: 2
                            color: Theme.acidGreen
                        }
                    }

                    onTextChanged: {
                        resultsList.currentIndex = 0;
                    }

                    Keys.onDownPressed: function (event) {
                        if (resultsList.count > 0) {
                            resultsList.currentIndex = (resultsList.currentIndex + 1) % resultsList.count;
                        }
                        event.accepted = true;
                    }

                    Keys.onUpPressed: function (event) {
                        if (resultsList.count > 0) {
                            resultsList.currentIndex = (resultsList.currentIndex - 1 + resultsList.count) % resultsList.count;
                        }
                        event.accepted = true;
                    }

                    Keys.onReturnPressed: function (event) {
                        root.executeCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onEnterPressed: function (event) {
                        root.executeCurrentItem();
                        event.accepted = true;
                    }

                    Keys.onEscapePressed: function (event) {
                        OverlayController.close();
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "SEARCH APPLICATIONS & ACTIONS..."
                    color: Theme.textMuted
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeTitle
                    visible: queryInput.text.length === 0 && !queryInput.inputMethodComposing
                }
            }
        }

        // Hairline divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Results List
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            model: ActionRegistry.search(queryInput.text)

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < count) {
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }
            }

            section.property: "category"
            section.criteria: ViewSection.FullString
            section.delegate: Component {
                Item {
                    width: resultsList.width
                    height: 28

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.rightMargin: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        Text {
                            text: "// " + section.toUpperCase()
                            color: Theme.acidGreen
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.borderWidth
                            color: Theme.gray700
                        }
                    }
                }
            }

            delegate: Component {
                Item {
                    id: delegateItem
                    width: resultsList.width
                    height: 44

                    readonly property bool isCurrent: resultsList.currentIndex === index
                    readonly property var itemData: modelData

                    Rectangle {
                        anchors.fill: parent
                        color: delegateItem.isCurrent ? Theme.surfaceSelected : (itemMouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                    }

                    // 2px acid green left indicator bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: Theme.acidGreen
                        visible: delegateItem.isCurrent
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingMedium + 4
                        anchors.rightMargin: Theme.paddingMedium
                        spacing: Theme.spacingMedium

                        CtosIcon {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            name: (modelData.icon && modelData.icon !== "" && modelData.icon !== "application-x-executable") ? modelData.icon : (modelData.id || modelData.name || "")
                            size: 24
                            active: delegateItem.isCurrent
                            destructive: Boolean(modelData.destructive)
                            fallbackIcon: "application-x-executable"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingMedium

                                Text {
                                    text: modelData.title || modelData.name || ""
                                    color: modelData.enabled ? Theme.textPrimary : Theme.textDisabled
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeBody
                                    font.weight: delegateItem.isCurrent ? Theme.fontWeightBold : Theme.fontWeightNormal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: !modelData.enabled && Boolean(modelData.disabledNote)
                                    text: "[" + modelData.disabledNote + "]"
                                    color: Theme.warningRed
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightDemiBold
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: modelData.description || modelData.desc || modelData.genericName || modelData.comment || ""
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMonospace
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: {
                            resultsList.currentIndex = index;
                        }
                        onClicked: {
                            root.executeItem(modelData);
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: resultsList.count === 0
                text: "// NO MATCHING APPLICATIONS OR ACTIONS"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeBody
            }
        }

        // Hairline divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Footer status / hint line
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            Text {
                text: "↑↓ NAVIGATE  •  ↵ EXECUTE  •  ESC DISMISS"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "[" + resultsList.count + " " + (resultsList.count === 1 ? "RESULT" : "RESULTS") + "]"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
            }
        }
    }

    function executeCurrentItem(): void {
        if (!resultsList.model || resultsList.currentIndex < 0 || resultsList.currentIndex >= resultsList.count) {
            return;
        }
        const item = resultsList.model[resultsList.currentIndex];
        executeItem(item);
    }

    function executeItem(item: var): void {
        if (!item)
            return;

        if (!item.enabled) {
            // Destructive actions are disabled in Command Deck
            return;
        }

        if (item.isApp) {
            if (item.entry && typeof item.entry.execute === "function") {
                item.entry.execute();
            }
            OverlayController.close();
        } else if (typeof item.execute === "function") {
            item.execute();
            if (item.id !== "action-system-rail" && item.id !== "action-event-log") {
                OverlayController.close();
            }
        }
    }

    Keys.onEscapePressed: function (event) {
        OverlayController.close();
        event.accepted = true;
    }

    Component.onCompleted: {
        OverlayController.registerFocusTarget(OverlayController.Surface.CommandDeck, queryInput);
        queryInput.forceActiveFocus();
    }

    Component.onDestruction: {
        OverlayController.unregisterFocusTarget(OverlayController.Surface.CommandDeck);
    }

    onVisibleChanged: {
        if (visible) {
            queryInput.text = "";
            resultsList.currentIndex = 0;
            queryInput.forceActiveFocus();
        }
    }
}
