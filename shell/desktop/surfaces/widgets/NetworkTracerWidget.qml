import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    implicitWidth: 280
    implicitHeight: 200
    width: implicitWidth
    height: implicitHeight

    readonly property var connections: NetworkTracerService.activeConnections
    readonly property int count: NetworkTracerService.connectionCount

    // =========================================================================
    // Background Surface & Framing
    // =========================================================================

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    CornerBrackets {
        bracketColor: Theme.acidGreen
    }

    // =========================================================================
    // Content Layout
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        // Header: Title and Connection Count Badge
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "NET // PACKET TRACER"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: "ESTAB: " + root.count
                color: Theme.acidGreen
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        // Subhead: Column Titles
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "PROTO"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.preferredWidth: 46
            }
            Text {
                text: "REMOTE ENDPOINT"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text: "PORT"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 42
            }
        }

        // Active Connections Telemetry Feed / Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: packetList
                anchors.fill: parent
                clip: true
                model: root.connections
                visible: root.count > 0

                delegate: Item {
                    id: delegateItem
                    required property var modelData
                    width: ListView.view.width
                    height: 18

                    RowLayout {
                        anchors.fill: parent
                        spacing: 4

                        Text {
                            text: delegateItem.modelData && delegateItem.modelData.protocol ? delegateItem.modelData.protocol : ""
                            color: delegateItem.modelData && delegateItem.modelData.protocol === "TCP" ? Theme.acidGreen : Theme.textPrimaryDim
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 11
                            font.weight: Theme.fontWeightMedium
                            Layout.preferredWidth: 46
                        }
                        Text {
                            text: delegateItem.modelData && delegateItem.modelData.ip ? delegateItem.modelData.ip : ""
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Text {
                            text: delegateItem.modelData && delegateItem.modelData.port ? delegateItem.modelData.port : ""
                            color: Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 42
                        }
                    }
                }
            }

            // Scanning / Idle State when 0 outbound connections exist
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.count === 0
                spacing: Theme.spacingSmall

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "[ SCANNING SUBNET... ]"
                    color: Theme.textMuted
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightMedium
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "NO OUTBOUND CARRIER"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: 10
                }
            }
        }
    }
}
