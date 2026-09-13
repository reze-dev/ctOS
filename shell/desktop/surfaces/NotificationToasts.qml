pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"

Item {
    id: root

    implicitWidth: 340
    width: 340
    implicitHeight: toastColumn.implicitHeight

    Column {
        id: toastColumn
        width: parent.width
        spacing: Theme.spacingMedium

        Repeater {
            id: toastRepeater
            model: NotificationService.activeToasts

            delegate: Rectangle {
                id: cardItem
                required property int index
                required property var notifId
                required property string appName
                required property string summary
                required property string body
                required property int urgency
                required property string timestamp
                required property var actions

                readonly property color urgencyColor: {
                    if (cardItem.urgency === 2) {
                        return Theme.warningRed;
                    }
                    if (cardItem.urgency === 0) {
                        return Theme.textMuted;
                    }
                    return Theme.acidGreen;
                }

                property color pulseColor: Theme.warningRed
                readonly property alias pulseAnimation: criticalPulseAnimation

                SequentialAnimation on pulseColor {
                    id: criticalPulseAnimation
                    running: cardItem.urgency === 2
                    loops: Animation.Infinite

                    ColorAnimation {
                        from: Theme.warningRed
                        to: Theme.gray800
                        duration: Theme.durationSlow * 2
                        easing.type: Easing.InOutQuad
                    }
                    ColorAnimation {
                        from: Theme.gray800
                        to: Theme.warningRed
                        duration: Theme.durationSlow * 2
                        easing.type: Easing.InOutQuad
                    }
                }

                width: toastColumn.width
                implicitHeight: cardLayout.implicitHeight + Theme.paddingMedium * 2
                color: Theme.gray900
                border.width: Theme.borderWidth
                border.color: cardItem.urgency === 2 ? cardItem.pulseColor : cardItem.urgencyColor
                radius: Theme.radiusSmall

                property bool isClosing: false
                opacity: isClosing ? 0.0 : 1.0

                Behavior on opacity {
                    NumberAnimation {
                        id: fadeAnim
                        duration: Theme.durationNormal
                        easing.type: Easing.OutQuad

                        onRunningChanged: {
                            if (!running && cardItem.opacity === 0.0) {
                                NotificationService.dismissToast(cardItem.notifId);
                            }
                        }
                    }
                }

                function dismissAnimated(): void {
                    cardItem.isClosing = true;
                }

                MouseArea {
                    id: cardMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: {
                        NotificationService.pauseToastTimer(cardItem.notifId);
                    }

                    onExited: {
                        NotificationService.resumeToastTimer(cardItem.notifId);
                    }

                    onClicked: {
                        NotificationService.dismissToast(cardItem.notifId);
                    }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.left: parent.left
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
                            color: cardItem.urgencyColor
                            radius: 3
                        }

                        Text {
                            Layout.fillWidth: true
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            font.weight: Theme.fontWeightMedium
                            text: cardItem.appName.toUpperCase()
                        }

                        Text {
                            color: Theme.textMuted
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeCaption
                            text: cardItem.timestamp
                        }
                    }

                    // Summary text (bold)
                    Text {
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightBold
                        text: cardItem.summary
                    }

                    // Body text (word wrap, max 3 lines, elide)
                    Text {
                        Layout.fillWidth: true
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        maximumLineCount: 3
                        text: cardItem.body
                        visible: cardItem.body !== ""
                        wrapMode: Text.WordWrap
                    }

                    // Action buttons row (if actions exist)
                    RowLayout {
                        id: actionsRow
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall
                        visible: cardItem.actions && (cardItem.actions.count > 0 || (typeof cardItem.actions.length === "number" && cardItem.actions.length > 0))

                        Repeater {
                            model: cardItem.actions

                            delegate: Rectangle {
                                id: actionBtn
                                required property var modelData

                                readonly property string actionLabelText: {
                                    if (actionBtn.modelData) {
                                        return String(actionBtn.modelData.text || actionBtn.modelData.identifier || "Action");
                                    }
                                    return "Action";
                                }

                                Layout.preferredHeight: 22
                                Layout.preferredWidth: actionLabel.implicitWidth + Theme.paddingMedium * 2
                                color: actionMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                border.color: actionMouseArea.containsMouse ? Theme.accent : Theme.borderMuted
                                border.width: Theme.borderWidth
                                radius: Theme.radiusSmall

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    color: actionMouseArea.containsMouse ? Theme.accent : Theme.textPrimary
                                    font.family: Theme.fontFamilyMonospace
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.weight: Theme.fontWeightMedium
                                    text: actionBtn.actionLabelText
                                }

                                MouseArea {
                                    id: actionMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    preventStealing: true

                                    onEntered: {
                                        NotificationService.pauseToastTimer(cardItem.notifId);
                                    }

                                    onExited: {
                                        NotificationService.resumeToastTimer(cardItem.notifId);
                                    }

                                    onClicked: {
                                        if (actionBtn.modelData && typeof actionBtn.modelData.invoke === "function") {
                                            actionBtn.modelData.invoke();
                                        } else if (actionBtn.modelData && actionBtn.modelData.identifier) {
                                            NotificationService.invokeAction(cardItem.notifId, actionBtn.modelData.identifier);
                                        }
                                        NotificationService.dismissToast(cardItem.notifId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
