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

        return [1, 2, 3, 4, 5];
    }

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Theme.spacingXs

        Repeater {
            model: root.workspaceList

            Rectangle {
                id: wsCell

                readonly property int wsId: (typeof modelData === "object" && modelData !== null) ? Number(modelData.id) : Number(modelData)
                readonly property bool isActive: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.active) : (wsId === CompositorService.focusedWorkspaceId)
                readonly property bool isFocused: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.focused || (wsId === CompositorService.focusedWorkspaceId)) : (wsId === CompositorService.focusedWorkspaceId)
                readonly property bool isUrgent: (typeof modelData === "object" && modelData !== null) ? Boolean(modelData.urgent) : false
                required property var modelData

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 22
                Layout.preferredWidth: 24
                border.color: isUrgent ? Theme.accentRed : (isFocused ? Theme.accent : (mouseArea.containsMouse ? Theme.ctosGray : Theme.borderMuted))
                border.width: Theme.borderWidth
                color: isFocused ? Theme.surfaceSelected : (mouseArea.containsMouse ? Theme.surfaceHover : "transparent")
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: wsCell.isUrgent ? Theme.accentRed : (wsCell.isFocused ? Theme.accent : (wsCell.isActive ? Theme.textPrimary : Theme.textMuted))
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: wsCell.isFocused ? Theme.fontWeightBold : Theme.fontWeightMedium
                    text: (typeof wsCell.modelData === "object" && wsCell.modelData !== null && wsCell.modelData.name) ? wsCell.modelData.name : String(wsCell.wsId)
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        CompositorService.switchToWorkspace(wsCell.wsId);
                    }
                }
            }
        }
    }
}
