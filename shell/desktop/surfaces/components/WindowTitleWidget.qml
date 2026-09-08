import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    readonly property string windowAddress: CompositorService.activeWindowAddress ?? ""
    readonly property string windowClass: CompositorService.activeWindowClass ?? ""
    readonly property string windowTitle: CompositorService.activeWindowTitle ?? ""
    readonly property bool hasWindow: windowAddress !== "" || windowTitle !== "" || windowClass !== ""

    readonly property string displayTitle: {
        if (windowTitle !== "") {
            return windowTitle;
        }
        if (windowClass !== "") {
            return windowClass;
        }
        return "ctOS";
    }

    clip: true
    implicitHeight: Theme.barHeight
    implicitWidth: Math.min(layout.implicitWidth, 400)

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: Theme.spacingSmall

        Rectangle {
            id: classBadge

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 18
            Layout.preferredWidth: classLabel.implicitWidth + Theme.paddingSmall * 2
            border.color: Theme.borderMuted
            border.width: Theme.borderWidth
            color: Theme.surfaceHover
            radius: Theme.radiusSmall
            visible: root.hasWindow && root.windowClass !== ""

            Text {
                id: classLabel

                anchors.centerIn: parent
                color: Theme.textSecondary
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightDemiBold
                maximumLineCount: 1
                text: root.windowClass.toUpperCase()
                wrapMode: Text.NoWrap
            }
        }

        Text {
            id: titleText

            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            clip: true
            color: root.hasWindow ? Theme.textPrimary : Theme.textMuted
            elide: Text.ElideRight
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightNormal
            maximumLineCount: 1
            text: root.displayTitle
            wrapMode: Text.NoWrap
        }
    }
}
