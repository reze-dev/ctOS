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
        border.color: mouseArea.containsMouse ? Theme.ctosGray : "transparent"
        border.width: Theme.borderWidth
        color: mouseArea.containsMouse ? Theme.surfaceHover : "transparent"
        radius: Theme.radiusSmall

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Theme.spacingXs

            CtosIcon {
                Layout.alignment: Qt.AlignVCenter
                size: 14
                name: {
                    if (!root.isOnline) return "wifi-slash";
                    if (NetworkService.isEthernet) return "network";
                    return "wifi";
                }
                active: root.isOnline
                destructive: !root.isOnline && NetworkService.available
                color: {
                    if (!NetworkService.available) return Theme.unavailable;
                    if (!root.isOnline) return Theme.destructive;
                    return mouseArea.containsMouse ? Theme.accent : Theme.textSecondary;
                }
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

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                OverlayController.toggleSystemRail();
            }
        }
    }
}
