import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 200
    height: 100
    color: Theme.background
    radius: Theme.radiusMedium
    border.color: Theme.border
    border.width: Theme.borderWidth

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingMedium

        Rectangle {
            width: 150
            height: 30
            color: Theme.newColorA
            radius: Theme.radiusSmall
            
            Text {
                anchors.centerIn: parent
                text: "New Color A"
                color: Theme.textInverse
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }

        Rectangle {
            width: 150
            height: 30
            color: Theme.newColorB
            radius: Theme.radiusSmall
            
            Text {
                anchors.centerIn: parent
                text: "New Color B"
                color: Theme.textInverse
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }
}
