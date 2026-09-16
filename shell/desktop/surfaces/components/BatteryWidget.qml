import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    property bool isHovered: false
    readonly property real batteryPercent: PowerService.percentage
    readonly property bool isCharging: PowerService.isCharging
    readonly property bool isFull: PowerService.isFull
    readonly property bool isLow: !isCharging && batteryPercent <= 20.0
    readonly property string percentText: {
        if (!PowerService.isBatteryPresent) {
            return "--N/A--";
        }
        return Math.round(batteryPercent).toString() + "%";
    }

    implicitHeight: visible ? layout.implicitHeight : 0
    implicitWidth: visible ? layout.implicitWidth : 0
    visible: PowerService.available && PowerService.isBatteryPresent

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Theme.spacingXs

        CtosIcon {
            Layout.alignment: Qt.AlignVCenter
            size: 14
            name: {
                if (root.isCharging) return "battery-charging";
                if (root.isLow) return "battery-low";
                return "battery";
            }
            active: root.isCharging
            destructive: root.isLow
            color: {
                if (root.isLow) return Theme.destructive;
                if (root.isCharging) return Theme.acidGreen;
                if (root.isHovered) return Theme.accent;
                return Theme.textSecondary;
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            color: {
                if (root.isLow) {
                    return Theme.accentRed;
                }
                if (root.isCharging) {
                    return Theme.accent;
                }
                return Theme.textPrimary;
            }
            elide: Text.ElideRight
            font.family: Theme.fontFamilyMonospace
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            maximumLineCount: 1
            text: root.percentText
            wrapMode: Text.NoWrap
        }
    }
}
