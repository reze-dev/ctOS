import QtQuick
import QtQuick.Layouts
import "../../adapters/hyprland"
import "../../core"
import "../../services"

Item {
    id: root

    property string monitorName: ""
    readonly property var workspaceList: {
        if (root.monitorName !== "" && HyprlandAdapter.available) {
            const monList = HyprlandAdapter.workspacesForMonitor(root.monitorName);
            if (monList && monList.length > 0) {
                return monList;
            }
        }

        const rawList = CompositorService.workspaces;
        if (rawList && rawList.length > 0) {
            return rawList;
        }

        return [];
    }

    implicitHeight: Theme.barHeight
    implicitWidth: layout.implicitWidth

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: Theme.spacingXs

        Repeater {
            model: root.workspaceList

            Rectangle {
                id: wsCell

                readonly property bool isActive: Boolean(modelData.active)
                readonly property bool isFocused: Boolean(modelData.focused || (modelData.id === CompositorService.focusedWorkspaceId))
                readonly property bool isUrgent: Boolean(modelData.urgent)
                required property var modelData

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 22
                Layout.preferredWidth: 24
                border.color: isUrgent ? Theme.accentRed : (isFocused ? Theme.accent : (hoverHandler.hovered ? Theme.ctosGray : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: isFocused ? Theme.surfaceSelected : (hoverHandler.hovered ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: wsCell.isUrgent ? Theme.accentRed : (wsCell.isFocused ? Theme.accent : (wsCell.isActive ? Theme.textPrimary : Theme.textMuted))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: wsCell.isFocused ? Theme.fontWeightBold : Theme.fontWeightMedium
                    text: wsCell.modelData.name || String(wsCell.modelData.id)
                }

                HoverHandler {
                    id: hoverHandler

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        CompositorService.switchToWorkspace(wsCell.modelData.id);
                    }
                }
            }
        }
    }
}
