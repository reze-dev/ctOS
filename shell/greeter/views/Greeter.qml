import QtQuick
import Quickshell

import qs.greeter.config
import qs.greeter.components
import qs.common

Variants {
    model: Quickshell.screens

    delegate: Component {
        // qmllint disable
        // Cage is a kiosk compositor and does not expose the layer-shell
        // protocol required by PanelWindow. Use a regular fullscreen window
        // so the greeter can render under Cage.
        FloatingWindow {
            id: window

            required property var modelData
            screen: modelData

            color: Theme.background
            visible: screen.name === Settings.monitor
            visibility: Window.FullScreen

            Loader {
                active: window.screen.name === Settings.monitor
                anchors.fill: parent
                sourceComponent: MainLayout {}
            }
        }
    }
}
