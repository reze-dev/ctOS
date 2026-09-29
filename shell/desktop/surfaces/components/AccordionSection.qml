pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
    id: root

    property bool isExpanded: false
    property Component headerComponent
    property Component contentComponent

    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Loader {
            id: headerLoader
            width: parent.width
            sourceComponent: root.headerComponent
        }

        Item {
            width: parent.width
            height: root.isExpanded ? (contentLoader.item ? (contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight : contentLoader.item.height) : 0) : 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }

            Loader {
                id: contentLoader
                width: parent.width
                sourceComponent: root.contentComponent
            }
        }
    }
}
