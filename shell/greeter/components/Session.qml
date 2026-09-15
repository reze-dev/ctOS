import QtQuick
import QtQuick.Layouts

import qs.common
import qs.greeter.components
import qs.greeter.services

ColumnLayout {
    id: root

    spacing: 4 * Units.vh

    readonly property color accentColor: Theme.accentGreen
    readonly property color borderMutedColor: Theme.secondary

    readonly property string currentDesktopName: (SessionManager.activeDesktop && SessionManager.activeDesktop.name) ?
        SessionManager.activeDesktop.name :
        ((SessionManager.desktops && SessionManager.desktops.length > 0) ? SessionManager.desktops[0].name : "STANDBY")

    readonly property int desktopCount: SessionManager.desktops ? SessionManager.desktops.length : 0

    function getActiveIndex(): int {
        if (!SessionManager.desktops || SessionManager.desktops.length === 0) return 0;
        if (!SessionManager.activeDesktop) return 0;
        for (var i = 0; i < SessionManager.desktops.length; i++) {
            if (SessionManager.desktops[i].name === SessionManager.activeDesktop.name) {
                return i;
            }
        }
        return 0;
    }

    function cycleDesktop(forward = true) {
        if (!SessionManager.desktops || SessionManager.desktops.length <= 1) return;

        var count = SessionManager.desktops.length;
        var currentIdx = getActiveIndex();
        var nextIdx = forward ? ((currentIdx + 1) % count) : ((currentIdx - 1 + count) % count);
        var target = SessionManager.desktops[nextIdx];

        if (target) {
            if (typeof SessionManager.setDesktop === "function") {
                SessionManager.setDesktop(target.name, true);
            } else {
                SessionManager.activeDesktop = target;
            }
        }
    }

    // SECTION Identity Badge (Logo, Username, Barcode, User Silhouette)
    RowLayout {
        id: identityRow
        spacing: 0

        ColumnLayout {
            id: code
            Layout.alignment: Qt.AlignTop
            spacing: 0

            RowLayout {
                spacing: 0

                Rectangle {
                    color: Theme.ctosGray
                    height: 56 * Units.vh
                    width: height

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2 * Units.vh
                        fillMode: Image.PreserveAspectFit
                        source: "../resources/blume-logo.svg"
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 150 * Units.vh
                    spacing: 0

                    Rectangle {
                        color: Theme.backgroundBright
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28 * Units.vh

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10 * Units.vh
                                rightMargin: 10 * Units.vh
                            }

                            Typewriter {
                                id: typewriter
                                color: Theme.textPrimary
                                initialText: ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Image {
                                Layout.preferredWidth: 15 * Units.vh
                                Layout.preferredHeight: width
                                source: "../resources/tesseract.svg"
                            }
                        }
                    }

                    Rectangle {
                        id: barcode

                        Layout.preferredHeight: 28 * Units.vh
                        Layout.fillWidth: true
                        color: Theme.ctosGray

                        Image {
                            anchors.fill: parent
                            anchors.margins: 5 * Units.vh
                            fillMode: Image.PreserveAspectFit
                            source: "../resources/user-barcode.svg"
                        }
                    }
                }
            }
        }

        Rectangle {
            id: picture

            color: Theme.secondary
            height: 75 * Units.vh
            width: height

            Image {
                // TODO add proper profile picture
                source: "../resources/user.svg"
                anchors.fill: parent
            }
        }
    }

    // SECTION Compositor Cycle Selector (Cyberpunk Pill Bar)
    Rectangle {
        id: compositorSelector

        Layout.fillWidth: true
        Layout.preferredHeight: 28 * Units.vh
        color: Theme.background
        border.color: selectorMouseArea.containsMouse ? root.accentColor : root.borderMutedColor
        border.width: 1

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left Cycle Arrow Button
            Rectangle {
                id: prevButton
                Layout.preferredWidth: 28 * Units.vh
                Layout.fillHeight: true
                color: prevMouseArea.containsMouse ? Theme.backgroundBright : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "<"
                    color: prevMouseArea.containsMouse ? root.accentColor : Theme.textPrimaryDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Math.round(12 * Units.vh))
                    font.bold: true
                }

                MouseArea {
                    id: prevMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleDesktop(false)
                }
            }

            // Divider Line
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4 * Units.vh
                Layout.bottomMargin: 4 * Units.vh
                color: root.borderMutedColor
                opacity: 0.4
            }

            // Center Content: Desktop Name & Cyberpunk Tag
            Item {
                id: centerContent
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8 * Units.vh
                    anchors.rightMargin: 8 * Units.vh
                    spacing: 6 * Units.vh

                    Text {
                        text: "// COMPOSITOR:"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Math.round(10 * Units.vh))
                    }

                    Text {
                        id: desktopLabel
                        text: root.currentDesktopName.toUpperCase()
                        color: selectorMouseArea.containsMouse ? root.accentColor : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(10, Math.round(11 * Units.vh))
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }

                    Text {
                        text: root.desktopCount > 1 ? `[${String(root.getActiveIndex() + 1).padStart(2, "0")}/${String(root.desktopCount).padStart(2, "0")}]` : "[ACTIVE]"
                        color: root.accentColor
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(9, Math.round(10 * Units.vh))
                    }
                }

                MouseArea {
                    id: selectorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleDesktop(true)
                }
            }

            // Divider Line
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4 * Units.vh
                Layout.bottomMargin: 4 * Units.vh
                color: root.borderMutedColor
                opacity: 0.4
            }

            // Right Cycle Arrow Button
            Rectangle {
                id: nextButton
                Layout.preferredWidth: 28 * Units.vh
                Layout.fillHeight: true
                color: nextMouseArea.containsMouse ? Theme.backgroundBright : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    color: nextMouseArea.containsMouse ? root.accentColor : Theme.textPrimaryDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(10, Math.round(12 * Units.vh))
                    font.bold: true
                }

                MouseArea {
                    id: nextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleDesktop(true)
                }
            }
        }
    }

    Connections {
        target: SessionManager
        function onActiveUserChanged() {
            typewriter.overwrite(SessionManager.activeUser.username.toUpperCase());
        }
    }
}
