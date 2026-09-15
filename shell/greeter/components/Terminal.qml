pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQml.Models

import qs.greeter.services
import qs.common
import qs.common.services
import qs.common.components
import qs.greeter.config

ColumnLayout {
    id: terminal

    property int margins: 10

    property int fontSize: 14 * Units.vh

    property int maxLines: {
        const totalSpace = Screen.height * 0.25;
        const takenSpace = version.height + terminal.spacing;

        const availableLines = (totalSpace - takenSpace) / lineHeight;
        return Utils.clamp(Math.floor(availableLines), 0, 10);
    }

    property int lineHeight: textMetrics.height + 5 * Units.vh
    property alias rem: textMetrics.width

    readonly property font font: Qt.font({
        family: Settings.fontFamily,
        pixelSize: terminal.fontSize
    })

    required property var logModel

    property bool restoreTerminalFocus: false

    spacing: 15 * Units.vh

    TextMetrics {
        id: textMetrics
        font: terminal.font
        text: "-"
    }

    ListView {
        id: logView

        model: terminal.logModel
        clip: true

        Layout.fillWidth: true
        Layout.preferredHeight: terminal.lineHeight * terminal.maxLines

        boundsBehavior: Flickable.StopAtBounds
        verticalLayoutDirection: ListView.TopToBottom

        Behavior on contentY {
            id: scrollBehavior
            NumberAnimation {
                id: scrollAnimation
                duration: 50
                easing.type: Easing.OutCubic
            }
        }

        header: Item {
            id: headerItem
            width: logView.width
            height: logView.height
        }

        Connections {
            target: terminal.logModel

            function onCountChanged() {
                Qt.callLater(() => {
                    logView.contentY = Math.max(0, logView.contentHeight - logView.height);
                });
            }
        }

        delegate: DelegateChooser {
            role: "type"

            DelegateChoice {
                roleValue: TerminalManager.MessageType.Output

                delegate: Item {
                    id: outputDelegate
                    width: logView.width
                    height: terminal.lineHeight

                    required property string message
                    required property string type
                    required property bool instant

                    Binding {
                        target: scrollAnimation
                        property: "duration"
                        value: outputDelegate.instant ? 0 : 50
                    }

                    Text {
                        id: entry

                        color: Theme.textPrimaryDimmer
                        font: terminal.font

                        lineHeight: terminal.lineHeight
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.Wrap

                        width: logView.width

                        text: {
                            if (parent.message.startsWith("---")) {
                                const stripped = parent.message.replace(/-/g, "");

                                const spareRoom = Math.floor(terminal.width / textMetrics.advanceWidth) - 4 - (stripped.length);

                                const hyphenCount = Math.floor(spareRoom / 2);

                                return `${("-").repeat(hyphenCount)}  ${stripped}  ${("-").repeat(hyphenCount)}`;
                            }

                            return `${parent.message}`;
                        }
                    }
                }
            }

            DelegateChoice {
                roleValue: TerminalManager.MessageType.Prompt

                delegate: Row {
                    id: inputDelegate
                    width: logView.width
                    height: terminal.lineHeight

                    spacing: 0

                    required property bool instant
                    required property string syntheticCommand

                    Binding {
                        target: scrollAnimation
                        property: "duration"
                        value: inputDelegate.instant ? 0 : 50
                    }

                    Text {
                        id: terminalPrompt

                        property int charIndex: 0

                        property string command: inputDelegate.syntheticCommand

                        text: "» " + command.substr(0, charIndex)
                        color: Theme.textPrimaryDim
                        font: terminal.font
                        height: inputDelegate.height
                        verticalAlignment: Text.AlignVCenter

                        onCommandChanged: {
                            typewriterAnimation.to = command.length;
                            typewriterAnimation.start();
                        }

                        NumberAnimation {
                            id: typewriterAnimation
                            target: terminalPrompt
                            property: "charIndex"
                            from: 0
                            easing.type: Easing.Linear
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: {
                                if (terminalInput.enabled) {
                                    terminalInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    TextInput {
                        id: terminalInput

                        height: inputDelegate.height
                        width: Math.max(0, inputDelegate.width - terminalPrompt.width)

                        color: Theme.textPrimaryDim
                        font: terminal.font
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        enabled: !inputDelegate.syntheticCommand
                        focus: false
                        cursorVisible: activeFocus
                        selectByMouse: true

                        onAccepted: {
                            terminal.restoreTerminalFocus = terminalInput.activeFocus;
                            enabled = false;
                            focus = false;

                            CommandManager.sendCommand(terminalInput.text);
                        }

                        Keys.onUpPressed: (event) => {
                            terminalInput.text = CommandManager.previousHistory();
                            terminalInput.cursorPosition = terminalInput.text.length;
                            event.accepted = true;
                        }

                        Keys.onDownPressed: (event) => {
                            terminalInput.text = CommandManager.nextHistory();
                            terminalInput.cursorPosition = terminalInput.text.length;
                            event.accepted = true;
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                FocusManager.requestFocus(terminalInput);
                            }
                        }

                        Component.onCompleted: {
                            FocusManager._targets = FocusManager._targets.filter(t => {
                                try {
                                    return t.item && t.tabIndex !== 1;
                                } catch (e) {
                                    return false;
                                }
                            });

                            FocusManager.registerTarget(terminalInput, {
                                tabIndex: 1
                            });

                            if (terminal.restoreTerminalFocus && FocusManager._currentTarget && FocusManager._currentTarget.tabIndex === 1) {
                                terminalInput.forceActiveFocus();
                            }
                            terminal.restoreTerminalFocus = false;
                        }

                        Component.onDestruction: {
                            FocusManager._targets = FocusManager._targets.filter(t => {
                                try {
                                    return t.item && t.item !== terminalInput;
                                } catch (e) {
                                    return false;
                                }
                            });
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            TerminalManager.notifyReady();
        }
    }

    Accents {
        id: accents

        opacityDuration: 200
        translateDuration: 300

        Layout.fillWidth: true
        Layout.preferredHeight: versionBorder.height

        SequentialAnimation {
            id: accentAnimation

            PauseAnimation {
                duration: 200
            }
            ScriptAction {
                script: accents.start()
            }
        }

        Component.onCompleted: {
            accentAnimation.start();
        }

        Rectangle {
            id: versionBorder

            color: "transparent"

            height: Math.round(version.height + 8)

            anchors {
                left: parent.left
                right: parent.right
            }

            border {
                color: Qt.darker(Theme.textPrimary, 1.6)
                width: 1
            }

            Text {
                id: version
                color: Qt.darker(Theme.textPrimary, 1.2)

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    leftMargin: 10
                }

                font {
                    pixelSize: 13 * Units.vh
                    family: Settings.fontFamily
                }

                text: "blume-krn-1.0.8 <> ctOS-1.0.0-a"
            }
        }
    }
}
