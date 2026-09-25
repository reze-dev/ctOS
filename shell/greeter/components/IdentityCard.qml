import QtQuick
import QtQuick.Layouts

import qs.greeter.common
import qs.greeter.config
import qs.greeter.services

Item {
    id: root

    // =========================================================================
    // InfoField inline component
    // =========================================================================

    component InfoField: Column {
        id: field
        property string label: "FIELD"
        property string value: "VALUE"
        property color valueColor: Theme.textPrimary
        property alias fieldValueOpacity: fieldValue.opacity

        Text {
            id: fieldLabel
            text: field.label
            color: Theme.textPrimaryDim
            font {
                family: Settings.fontFamily
                pixelSize: Math.round(11 * Units.vh)
            }
        }

        Text {
            id: fieldValue
            text: field.value
            color: field.valueColor
            font {
                family: Settings.fontFamily
                pixelSize: Math.round(17 * Units.vh)
                weight: 500
            }
            elide: Text.ElideRight
        }
    }

    // =========================================================================
    // Card layout — unified RowLayout splitting left info from right photo
    // =========================================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left column: fields + barcode ────────────────────────────────────
        ColumnLayout {
            id: infoColumn
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(4 * Units.vh)

            // Row 1: EMPID / CLASS / ACCESS
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * Units.vh)

                InfoField {
                    id: employeeId
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "EMPID ##"
                    value: SessionManager.activeUser ? ("UID-" + SessionManager.activeUser.uid) : "UID-STANDBY"
                }
                InfoField {
                    id: employeeClass
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "CLASS"
                    value: {
                        if (!SessionManager.activeUser) {
                            return "STANDBY";
                        }
                        if (SessionManager.activeUser.uid === 0) {
                            return "L0_ROOT";
                        }
                        if (SessionManager.activeUser.uid === 1000) {
                            return "L5_ADMIN";
                        }
                        return "OPERATOR";
                    }
                }
                InfoField {
                    id: employeeAccess
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "ACCESS"
                    value: "RESTRICTED"
                    valueColor: Theme.accentRed
                }
            }

            // Row 2: Full name
            InfoField {
                id: employeeName
                Layout.fillWidth: true
                label: "FULL NAME"
                value: SessionManager.activeUser ? SessionManager.activeUser.username.toUpperCase() : "UNKNOWN"
            }

            // Spacer
            Item {
                Layout.fillHeight: true
            }

            // Row 3: Barcode — constrain height by aspect ratio of the SVG (241:72)
            Image {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * (72 / 241))
                fillMode: Image.Stretch
                source: "../resources/id-barcode.svg"
            }
        }

        // ── Right column: profile picture ─────────────────────────────────────
        Item {
            id: profilePicture
            // Keep the photo panel square-ish: take 32% of total card width
            Layout.preferredWidth: Math.round(root.width * 0.32)
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: "#1effffff"
            }

            Image {
                source: "../resources/user.svg"
                opacity: 0.9
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                anchors.margins: Math.round(4 * Units.vh)
            }
        }
    }

    // =========================================================================
    // Reveal animation
    // =========================================================================

    SequentialAnimation {
        id: revealAnimation
        running: true

        // SECTION Setup

        PropertyAction {
            target: root
            property: "opacity"
            value: 0
        }
        PropertyAction {
            targets: [employeeId, employeeClass, employeeAccess, employeeName]
            property: "fieldValueOpacity"
            value: 0
        }

        ScriptAction {
            script: revealAnimation.pause()
        }

        // SECTION Begin

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 150
            }
            NumberAnimation {
                target: employeeId
                property: "fieldValueOpacity"
                to: 1
                duration: 150
            }
            ParallelAnimation {

                NumberAnimation {
                    target: employeeClass
                    property: "fieldValueOpacity"
                    to: 1
                    duration: 150
                }
                NumberAnimation {
                    target: employeeAccess
                    property: "fieldValueOpacity"
                    to: 1
                    duration: 150
                }
                SequentialAnimation {

                    PauseAnimation {
                        duration: 50
                    }
                    NumberAnimation {
                        target: employeeName
                        property: "fieldValueOpacity"
                        to: 1
                        duration: 150
                    }
                }
            }
        }
    }

    function start() {
        revealAnimation.resume();
    }
}
