pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool isExpanded: false
    property bool autoToggle: true
    property bool animateHeight: true
    property Component contentComponent: null
    property Component headerAction: null
    property Item headerActionItem: null
    property Component headerComponent: null

    signal headerClicked()

    function toggle(): void {
        root.isExpanded = !root.isExpanded;
    }

    Layout.fillWidth: true
    width: parent ? parent.width : undefined
    implicitWidth: parent ? parent.width : undefined
    readonly property real _contentTargetHeight: contentLoader.item ? (contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight : (contentLoader.item.height > 0 ? contentLoader.item.height : 0)) : 0

    implicitHeight: headerLoader.height + (root.isExpanded ? _contentTargetHeight + Theme.spacingMedium : 0)

    Loader {
        id: headerLoader
        width: parent ? parent.width : undefined
        anchors.top: parent.top
        sourceComponent: root.headerComponent !== null ? root.headerComponent : defaultHeaderComponent
    }

    Item {
        id: contentContainer
        width: parent ? parent.width : undefined
        anchors.top: headerLoader.bottom
        anchors.topMargin: root.isExpanded ? Theme.spacingMedium : 0
        clip: true
        height: root.isExpanded ? _contentTargetHeight : 0
        visible: height > 0 || root.isExpanded

        Behavior on anchors.topMargin {
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

        Loader {
            id: contentLoader
            width: parent ? parent.width : undefined
            sourceComponent: root.contentComponent
        }
    }

    Component {
        id: defaultHeaderComponent

        Rectangle {
            id: headerBg
            width: parent ? parent.width : undefined
            height: Theme.accordionHeaderHeight
            color: headerMouseArea.containsMouse ? Theme.surfaceHover : (root.isExpanded ? Theme.surfaceActive : Theme.surface)
            border.color: root.isExpanded ? Theme.accent : Theme.borderMuted
            border.width: Theme.borderWidth
            radius: Theme.radiusSmall

            readonly property bool hasAction: (actionLoader.item !== null) || (root.headerActionItem !== null)

            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: headerBg.hasAction ? actionContainer.left : parent.right
                anchors.rightMargin: headerBg.hasAction ? Theme.paddingSmall : Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMedium
                clip: true

                Text {
                    id: chevronText
                    text: root.isExpanded ? "▼" : "▶"
                    color: root.isExpanded ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Loader {
                    id: iconLoader
                    visible: root.icon !== ""
                    width: visible ? 16 : 0
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.icon !== "" ? ((root.icon.indexOf("/") !== -1 || root.icon.indexOf(".") !== -1) ? fileIconComponent : ctosIconComponent) : null
                }

                Text {
                    id: titleText
                    text: root.title
                    color: root.isExpanded ? Theme.accent : Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                id: actionContainer
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                width: actionLoader.item ? actionLoader.item.width : (root.headerActionItem ? root.headerActionItem.width : 0)
                height: actionLoader.item ? actionLoader.item.height : (root.headerActionItem ? root.headerActionItem.height : 0)
                z: 2

                Loader {
                    id: actionLoader
                    anchors.centerIn: parent
                    sourceComponent: root.headerAction
                }

                Binding {
                    target: root.headerActionItem
                    property: "parent"
                    value: actionContainer
                    when: root.headerActionItem !== null
                }
            }

            MouseArea {
                id: headerMouseArea
                anchors.left: parent.left
                anchors.right: headerBg.hasAction ? actionContainer.left : parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.headerClicked();
                    if (root.autoToggle) {
                        root.isExpanded = !root.isExpanded;
                    }
                }
            }
        }
    }

    Component {
        id: fileIconComponent

        Image {
            source: root.icon
            width: 16
            height: 16
            fillMode: Image.PreserveAspectFit
        }
    }

    Component {
        id: ctosIconComponent

        CtosIcon {
            name: root.icon
            size: 16
            color: root.isExpanded ? Theme.accent : Theme.textPrimary
        }
    }
}
