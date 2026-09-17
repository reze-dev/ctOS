import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../services"

Item {
    id: root

    implicitWidth: 320
    implicitHeight: 240
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: bgSurface
        anchors.fill: parent
        color: Qt.rgba(14 / 255, 14 / 255, 14 / 255, 0.85)
        border.color: Theme.gray700
        border.width: Theme.borderWidth
    }

    CornerBrackets {
        bracketColor: Theme.accent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "NET // PACKET ANALYZER"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                font.weight: Theme.fontWeightMedium
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: PacketAnalyzerService.isTracing ? "[ CAPTURING ]" : "[ OFFLINE ]"
                color: PacketAnalyzerService.isTracing ? Theme.accent : Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.gray700
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "TIME"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.preferredWidth: 40
            }
            Text {
                text: "SOURCE"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text: "DEST"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.fillWidth: true
            }
            Text {
                text: "PROT"
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: 10
                Layout.preferredWidth: 36
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: packetList
                anchors.fill: parent
                clip: true
                model: PacketAnalyzerService.packetLog
                visible: PacketAnalyzerService.isTracing

                delegate: Item {
                    width: ListView.view.width
                    height: 18

                    RowLayout {
                        anchors.fill: parent
                        spacing: 4

                        Text {
                            text: time
                            color: Theme.textSecondary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            Layout.preferredWidth: 40
                        }
                        Text {
                            text: src
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Text {
                            text: dst
                            color: Theme.textPrimaryDim
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        Text {
                            text: protocol
                            color: Theme.accent
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: 10
                            Layout.preferredWidth: 36
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !PacketAnalyzerService.isTracing || PacketAnalyzerService.packetLog.count === 0
                spacing: Theme.spacingSmall

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: PacketAnalyzerService.isTracing ? "[ LISTENING... ]" : "[ ANALYZER INACTIVE ]"
                    color: Theme.textMuted
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightMedium
                }
            }
        }
    }
}
