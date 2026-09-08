import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    readonly property bool isAvail: AudioService.available
    readonly property bool isMuted: AudioService.muted
    readonly property int volumePercent: Math.round(AudioService.volume * 100)
    readonly property string volumeText: {
        if (!isAvail) {
            return "--N/A--";
        }
        if (isMuted) {
            return "[MUTED]";
        }
        return volumePercent.toString() + "%";
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
                    if (!root.isAvail) return "volume-slash";
                    if (root.isMuted) return "volume-slash";
                    return "volume";
                }
                active: mouseArea.containsMouse && root.isAvail && !root.isMuted
                destructive: root.isMuted
                color: {
                    if (!root.isAvail) return Theme.unavailable;
                    if (root.isMuted) return Theme.destructive;
                    if (mouseArea.containsMouse) return Theme.accent;
                    return Theme.textSecondary;
                }
            }

            Text {
                id: valText

                color: {
                    if (!root.isAvail) {
                        return Theme.unavailable;
                    }
                    if (root.isMuted) {
                        return Theme.accentRed;
                    }
                    return mouseArea.containsMouse ? Theme.accent : Theme.textPrimary;
                }
                elide: Text.ElideRight
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                maximumLineCount: 1
                text: root.volumeText
                wrapMode: Text.NoWrap
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                AudioService.toggleMute();
            }

            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                AudioService.stepVolume(delta);
            }
        }
    }
}
