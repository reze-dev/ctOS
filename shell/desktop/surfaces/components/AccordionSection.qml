pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../core"

Item {
    id: root

    property bool isExpanded: false
    property Component headerComponent
    property Component contentComponent

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Loader {
            Layout.fillWidth: true
            sourceComponent: root.headerComponent
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.isExpanded ? contentLoader.implicitHeight : 0
            color: "transparent"
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }

            Loader {
                id: contentLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                sourceComponent: root.contentComponent
            }
        }
    }
}
