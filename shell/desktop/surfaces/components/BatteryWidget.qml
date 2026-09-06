import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

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

    implicitHeight: visible ? Theme.barHeight : 0
    implicitWidth: visible ? layout.implicitWidth + Theme.paddingSmall * 2 : 0
    visible: PowerService.available && PowerService.isBatteryPresent
    width: visible ? implicitWidth : 0

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

            Text {
                color: Theme.textSecondary
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightDemiBold
                maximumLineCount: 1
                text: "BAT"
                wrapMode: Text.NoWrap
            }

            Text {
                color: Theme.accent
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                text: "+"
                visible: root.isCharging
            }

            Text {
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
