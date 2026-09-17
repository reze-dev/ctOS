pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool isTracing: Boolean(Settings.widgetPacketAnalyzerVisible)
    property ListModel packetLog: ListModel {}

    Process {
        id: tsharkProcess
        command: ["tshark", "-l", "-i", "any", "-T", "fields", "-e", "frame.time_relative", "-e", "ip.src", "-e", "ip.dst", "-e", "frame.protocols", "-e", "frame.len", "-E", "separator=|"]
        running: root.isTracing
        
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.split("|");
                if (parts.length >= 5 && parts[1] !== "") {
                    // Extract the highest level protocol name from frame.protocols (e.g. "eth:ethertype:ip:tcp:tls" -> "TLS")
                    let protoRaw = parts[3].split(":").pop();
                    if (!protoRaw || protoRaw === "") {
                        protoRaw = "UNK";
                    } else if (protoRaw.includes(".")) {
                        protoRaw = protoRaw.split(".").pop();
                    }
                    const packet = {
                        time: parseFloat(parts[0]).toFixed(3),
                        src: parts[1],
                        dst: parts[2],
                        protocol: protoRaw.toUpperCase(),
                        length: parts[4]
                    };
                    root.packetLog.insert(0, packet);
                    if (root.packetLog.count > 100) {
                        root.packetLog.remove(100);
                    }
                }
            }
        }
    }

    function toggleTracing(): void {
        Settings.widgetPacketAnalyzerVisible = !Settings.widgetPacketAnalyzerVisible;
    }
    
    function clear(): void {
        root.packetLog.clear();
    }
}
