pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    // =========================================================================
    // Public Interface Contract
    // =========================================================================

    // The declared toolkit, grouped. This is the shell's half of a contract
    // whose other half is modules/features/desktop/toolkit.nix, which installs
    // the packages.
    //
    // Nothing here is enabled at runtime. Nix decides what exists; this reports
    // what turned up. That is the whole point -- a radial node per tool that
    // merely asserted the tool was present would be exactly the kind of
    // confident fiction Phase 3 removed from this tree.
    //
    // The groups are deliberately coarse. Twenty-odd nodes in one category
    // would make the ring unreadable, so the radial shows one node per group and
    // this service holds the detail.
    readonly property var groups: [
        {
            id: "recon",
            label: "RECON",
            icon: "globe",
            tools: ["nmap", "masscan", "whois", "dig", "host"]
        },
        {
            id: "capture",
            label: "CAPTURE",
            icon: "storage",
            tools: ["tshark", "tcpdump", "socat"]
        },
        {
            id: "wireless",
            label: "WIRELESS",
            icon: "wifi",
            tools: ["aircrack-ng"]
        },
        {
            id: "credentials",
            label: "CREDENTIALS",
            icon: "vpn-key",
            tools: ["john", "hashcat", "hydra"]
        },
        {
            id: "web",
            label: "WEB",
            icon: "globe",
            tools: ["sqlmap"]
        },
        {
            id: "forensics",
            label: "FORENSICS",
            icon: "layers",
            tools: ["binwalk", "exiftool", "file"]
        },
        {
            id: "diagnostics",
            label: "DIAGNOSTICS",
            icon: "bolt",
            tools: ["iperf3", "mtr", "traceroute"]
        }
    ]

    // Flat tool list derived from the groups, so a tool appears once.
    readonly property var tools: {
        const out = [];
        for (let i = 0; i < root.groups.length; ++i) {
            const g = root.groups[i];
            for (let k = 0; k < g.tools.length; ++k) out.push({ id: g.tools[k], group: g.id });
        }
        return out;
    }

    // Present only once the first scan has finished. Distinguishes "none of this
    // group is installed" from "has not looked yet", which is the difference
    // between a truthful zero and an uninformative one.
    readonly property bool scanned: _scanned

    readonly property int installedCount: _installed

    readonly property int totalCount: tools.length

    function groupInstalled(groupId) {
        const g = root.groupFor(groupId);
        if (!g) return 0;
        let n = 0;
        for (let i = 0; i < g.tools.length; ++i) {
            if (_present[g.tools[i]] === true) n += 1;
        }
        return n;
    }

    function groupFor(groupId) {
        for (let i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].id === groupId) return root.groups[i];
        }
        return null;
    }

    function isInstalled(toolId) {
        return _present[toolId] === true;
    }

    // =========================================================================
    // Scanning
    //
    // One shell loop, same pattern as WallpaperService and CalendarService:
    // Quickshell 0.3.1 has no way to ask about PATH from QML, so `command -v`
    // answers it.
    //
    // The tool list is interpolated into the script as a fixed literal rather
    // than passed as an argument, so there is nothing to quote and nothing for a
    // caller to inject. The ids are compile-time constants in this file.
    // =========================================================================

    property var _present: ({})
    property var _versions: ({})
    property bool _scanned: false
    property int _installed: 0

    function rescan() {
        _scanned = false;
        const names = [];
        for (let i = 0; i < root.tools.length; ++i) names.push(root.tools[i].id);
        _scanProc.command = [
            "sh", "-c",
            'for t in ' + names.join(" ") + '; do p=$(command -v "$t" 2>/dev/null) || continue; ' +
            'v=$("$t" --version 2>&1 | head -n 1 | cut -c1-40); ' +
            // A tool that has no --version answers with its usage or an
            // "illegal option" complaint instead of a version. Left in, that
            // string is displayed as the tool's version, which is worse than
            // showing none: BSD `host` is one such tool. Blank it when the
            // output is obviously the tool complaining.
            'case "$v" in *"illegal option"*|*"unknown option"*|*"invalid option"*|usage:*|Usage:*) v="" ;; esac; ' +
            'printf "###CTOSTK:%s:%s\\n" "$t" "$v"; done; printf "###CTOSTKEND\\n"',
            "ctos-toolkit-scan"
        ];
        _scanProc.running = true;
    }

    Process {
        id: _scanProc
        workingDirectory: "/"
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const present = {};
                const versions = {};
                const lines = (text || "").split("\n");

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    if (line.indexOf("###CTOSTK:") !== 0) continue;

                    const rest = line.slice("###CTOSTK:".length);
                    const sep = rest.indexOf(":");
                    if (sep < 0) continue;

                    present[rest.slice(0, sep)] = true;
                    versions[rest.slice(0, sep)] = rest.slice(sep + 1).trim();
                }

                root._present = present;
                root._versions = versions;
                root._installed = Object.keys(present).length;
                root._scanned = true;
            }
        }
    }

    Component.onCompleted: root.rescan()
}