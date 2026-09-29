pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../services"
import "./components"

FocusScope {
    id: root

    implicitWidth: 360
    width: 360
    focus: true

    implicitHeight: panelContainer.implicitHeight
    height: panelContainer.height

    readonly property bool isOpen: OverlayController.activeSurface === OverlayController.Surface.CommandCenter

    Keys.onEscapePressed: function (event) {
        OverlayController.close();
        if (event) {
            event.accepted = true;
        }
    }

    Connections {
        target: OverlayController
        function onOverlayOpened(surface: int): void {
            if (surface === OverlayController.Surface.CommandCenter) {
                root.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        if (OverlayController.activeSurface === OverlayController.Surface.CommandCenter) {
            root.forceActiveFocus();
        }
    }

    MouseArea {
        id: canvasDismissArea
        anchors.fill: parent
        onClicked: OverlayController.close()
    }

    Rectangle {
        id: panelContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        implicitHeight: height
        radius: root.isOpen ? Theme.radiusMedium : 17
        color: Theme.background
        border.color: root.isOpen ? Theme.accent : "black"
        border.width: Theme.borderWidth
        clip: true

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges {
                    target: panelContainer
                    width: 360
                    height: mainLayout.implicitHeight + Theme.paddingXl * 2
                }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges {
                    target: panelContainer
                    width: 120
                    height: 34
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { properties: "width,height"; duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { properties: "width,height"; duration: Settings.reducedMotion ? 0 : Theme.durationSlow; easing.type: Easing.InOutQuad }
            }
        ]

        Behavior on radius {
            NumberAnimation {
                duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                easing.type: Easing.InOutQuad
            }
        }

        MouseArea {
            id: insideClickConsumer
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        CornerBrackets {
            id: cornerBrackets
            bracketColor: Theme.acidGreen
            margin: Theme.cornerBracketMargin
            armLength: Theme.cornerBracketArmLength
            thickness: Theme.cornerBracketThickness
            z: 10
            opacity: root.isOpen ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }
        }

        property string expandedAccordion: {
            if (OverlayController.pendingSessionAction !== "")
                return "power";
            if (OverlayController.pendingRailView === "wifi")
                return "wifi";
            return "notifications"; // Default open
        }

        ColumnLayout {
            id: mainLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingXl
            spacing: Theme.spacingMedium
            opacity: root.isOpen ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Settings.reducedMotion ? 0 : Theme.durationSlow
                    easing.type: Easing.InOutQuad
                }
            }

            // Notifications Accordion
            AccordionSection {
                Layout.fillWidth: true
                isExpanded: panelContainer.expandedAccordion === "notifications"
                headerComponent: Component {
                    Rectangle {
                        height: 40
                        color: "transparent"
                        Text {
                            text: "Notifications"
                            color: Theme.accent
                            anchors.centerIn: parent
                            font.family: Theme.fontFamilyMonospace
                            font.weight: Theme.fontWeightBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panelContainer.expandedAccordion = panelContainer.expandedAccordion === "notifications" ? "" : "notifications"
                        }
                    }
                }
                contentComponent: Component {
                    Rectangle {
                        height: 100
                        color: Theme.surfaceSelected
                        Text {
                            text: "Notifications Content placeholder"
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // Wi-Fi Accordion
            AccordionSection {
                Layout.fillWidth: true
                isExpanded: panelContainer.expandedAccordion === "wifi"
                headerComponent: Component {
                    Rectangle {
                        height: 40
                        color: "transparent"
                        Text {
                            text: "Wi-Fi"
                            color: Theme.accent
                            anchors.centerIn: parent
                            font.family: Theme.fontFamilyMonospace
                            font.weight: Theme.fontWeightBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panelContainer.expandedAccordion = panelContainer.expandedAccordion === "wifi" ? "" : "wifi"
                        }
                    }
                }
                contentComponent: Component {
                    Rectangle {
                        height: 100
                        color: Theme.surfaceSelected
                        Text {
                            text: "Wi-Fi Content placeholder"
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // Bluetooth Accordion
            AccordionSection {
                Layout.fillWidth: true
                isExpanded: panelContainer.expandedAccordion === "bluetooth"
                headerComponent: Component {
                    Rectangle {
                        height: 40
                        color: "transparent"
                        Text {
                            text: "Bluetooth"
                            color: Theme.accent
                            anchors.centerIn: parent
                            font.family: Theme.fontFamilyMonospace
                            font.weight: Theme.fontWeightBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panelContainer.expandedAccordion = panelContainer.expandedAccordion === "bluetooth" ? "" : "bluetooth"
                        }
                    }
                }
                contentComponent: Component {
                    Rectangle {
                        height: 100
                        color: Theme.surfaceSelected
                        Text {
                            text: "Bluetooth Content placeholder"
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // Audio Accordion
            AccordionSection {
                Layout.fillWidth: true
                isExpanded: panelContainer.expandedAccordion === "audio"
                headerComponent: Component {
                    Rectangle {
                        height: 40
                        color: "transparent"
                        Text {
                            text: "Audio"
                            color: Theme.accent
                            anchors.centerIn: parent
                            font.family: Theme.fontFamilyMonospace
                            font.weight: Theme.fontWeightBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panelContainer.expandedAccordion = panelContainer.expandedAccordion === "audio" ? "" : "audio"
                        }
                    }
                }
                contentComponent: Component {
                    Rectangle {
                        height: 100
                        color: Theme.surfaceSelected
                        Text {
                            text: "Audio Content placeholder"
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // Power Accordion
            AccordionSection {
                Layout.fillWidth: true
                isExpanded: panelContainer.expandedAccordion === "power"
                headerComponent: Component {
                    Rectangle {
                        height: 40
                        color: "transparent"
                        Text {
                            text: "Power"
                            color: Theme.accent
                            anchors.centerIn: parent
                            font.family: Theme.fontFamilyMonospace
                            font.weight: Theme.fontWeightBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panelContainer.expandedAccordion = panelContainer.expandedAccordion === "power" ? "" : "power"
                        }
                    }
                }
                contentComponent: Component {
                    Rectangle {
                        height: 100
                        color: Theme.surfaceSelected
                        Text {
                            text: "Power Content placeholder"
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }
}
