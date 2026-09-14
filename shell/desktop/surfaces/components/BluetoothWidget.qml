import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    property bool isHovered: false

    readonly property bool available: BluetoothService.available
    readonly property bool powered: BluetoothService.powered
    readonly property bool isConnected: BluetoothService.isConnected
    readonly property string deviceName: BluetoothService.deviceName

    readonly property string stateText: {
        if (!root.available) {
            return "--N/A--";
        }
        if (!root.powered) {
            return "OFF";
        }
        if (root.isConnected) {
            return root.deviceName !== "" ? root.deviceName : "CONNECTED";
        }
        return "ON";
    }

    implicitHeight: visible ? layout.implicitHeight : 0
    implicitWidth: visible ? layout.implicitWidth : 0
    visible: root.available

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Theme.spacingXs

        CtosIcon {
            Layout.alignment: Qt.AlignVCenter
            size: 14
            name: root.powered ? "bluetooth" : "bluetooth-slash"
            active: root.isConnected
            color: {
                if (!root.available) {
                    return Theme.textMuted;
                }
                if (root.isConnected) {
                    return Theme.acidGreen;
                }
                if (root.powered) {
                    return root.isHovered ? Theme.accent : Theme.textPrimary;
                }
                return Theme.textSecondary;
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 120
            color: {
                if (!root.available) {
                    return Theme.textMuted;
                }
                if (root.isConnected) {
                    return Theme.accent;
                }
                if (root.powered) {
                    return root.isHovered ? Theme.accent : Theme.textPrimary;
                }
                return Theme.textSecondary;
            }
            elide: Text.ElideRight
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            maximumLineCount: 1
            text: root.stateText
            wrapMode: Text.NoWrap
        }
    }
}
