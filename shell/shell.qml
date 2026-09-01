import Quickshell
import QtQuick

// T1 smoke shell: this deliberately has no greeter or desktop-surface imports.
Scope {
    PanelWindow {
        color: "#0e0e0e"
        implicitHeight: 1
        anchors {
            top: true
            left: true
            right: true
        }
    }
}
