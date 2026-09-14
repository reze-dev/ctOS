pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import desktop.services
import desktop.surfaces

Scope {
    id: root

    AmbientBar {
        id: bar
    }

    Timer {
        id: step1
        interval: 300
        running: true
        repeat: false
        onTriggered: {
            BluetoothService._parseConnectedOutput("Device 12:34:56:78:9A:BC 123456789012345678901234\n");
            step2.start();
        }
    }

    Timer {
        id: step2
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            let rightRow = bar.contentItem.children[2];
            let btSec = rightRow.children[3];
            let btWidget = btSec.children[0];
            let rowLayout = btWidget.children[0];
            let textItem = rowLayout.children[1];

            console.log("btSec.width: " + btSec.width);
            console.log("textItem.width: " + textItem.width);

            // Restore live state
            BluetoothService.refresh();
            Qt.quit();
        }
    }
}
