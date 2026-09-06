import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    readonly property bool isOnline: NetworkService.available && NetworkService.isConnected
    readonly property string netText: {
        if (!NetworkService.available || !NetworkService.isConnected) {
            return "--N/A--";
        }
        return NetworkService.networkName !== "" ? NetworkService.networkName : "--N/A--";
    }
    readonly property string prefixTag: {
        if (!NetworkService.available || !NetworkService.isConnected) {
            return "NET";
        }
        if (NetworkService.isEthernet) {
            return "ETH";
        }
        if (NetworkService.isWifi) {
            return "WIFI";
        }
        return "NET";
    }

    implicitHeight: Theme.barHeight
    implicitWidth: layout.implicitWidth + Theme.paddingSmall * 2

    Rectangle {
        id: container

        anchors.fill: parent
        anchors.margins: Theme.paddingXs
        border.color: hoverHandler.hovered ? Theme.ctosGray : "transparent"
        border.width: Theme.borderWidth
        color: hoverHandler.hovered ? Theme.surfaceHover : "transparent"
        radius: Theme.radiusSmall

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Theme.spacingXs

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 6
                Layout.preferredWidth: 6
                color: root.isOnline ? Theme.connected : Theme.unavailable
                radius: 3
            }

            Text {
                color: root.isOnline ? Theme.textSecondary : Theme.textMuted
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightDemiBold
                maximumLineCount: 1
                text: root.prefixTag
                wrapMode: Text.NoWrap
            }

            Text {
                id: label

                Layout.maximumWidth: 120
                color: root.isOnline ? Theme.textPrimary : Theme.unavailable
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                maximumLineCount: 1
                text: root.netText
                wrapMode: Text.NoWrap
            }
        }

        HoverHandler {
            id: hoverHandler

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                OverlayController.toggleSystemRail();
            }
        }
    }
}
