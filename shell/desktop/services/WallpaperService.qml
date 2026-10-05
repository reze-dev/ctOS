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

    // The directory being scanned. Mirrors Settings so the browser's field and
    // the service can never disagree about which directory is current.
    readonly property string directory: Settings.wallpaperDir

    // What the scan found: [{ name, path }], sorted, current selection flagged.
    readonly property var wallpapers: _entries

    readonly property bool scanning: _scanProc.running

    // True once a scan has completed for the current directory. Distinguishes
    // "no wallpapers here" from "has not looked yet", which the browser needs so
    // an empty directory does not read as an error.
    readonly property bool scanned: _scanned

    readonly property int count: _entries.length

    // The selected filename, or "" when the directory holds nothing selected.
    readonly property string currentName: Settings.wallpaper

    readonly property bool currentPresent: entryFor(root.currentName) !== null

    // Backend health, derived from consecutive failures rather than assigned.
    //
    // Same reasoning as SystemMonitorService.available: anything that gates work
    // on this property must not have that work be what sets it, or one failure
    // disables the retry that would have recovered.
    readonly property bool available: _consecutiveFailures < maxConsecutiveFailures
    readonly property int maxConsecutiveFailures: 3

    readonly property bool applying: _awwwProcess.running

    // Last failure, for the radial's error state and the startup diagnostic the
    // engineering guidelines require of every optional integration.
    readonly property string lastError: _lastError

    // The awww daemon's control socket. awww derives the name from the
    // compositor it is serving, so it is not a fixed path.
    readonly property string _socketPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/" +
        (Quickshell.env("WAYLAND_DISPLAY") || "") + "-awww-daemon.sock"

    // =========================================================================
    // Scanning
    //
    // Quickshell 0.3.1 has no DirectoryView -- the Io module ships FileView,
    // Process, StdioCollector, Socket and the rest, but nothing that enumerates a
    // directory. So this shells out, on the CalendarService pattern: one `sh`
    // loop with a marker per line, output split back apart in JS.
    //
    // Re-scanned whenever the directory changes rather than watched. A wallpaper
    // directory is not a hot path, and a watch would mean holding a descriptor
    // open on a path the user can change to anything at all.
    //
    // Results are capped and extension-filtered. The directory is user-supplied,
    // so it may hold a photo dump, and decoding every one of those into the
    // browser's grid would be the shell's fault, not the user's.
    // =========================================================================

    readonly property int maxWallpapers: 60

    property var _entries: []
    property bool _scanned: false
    property string _scannedDir: ""
    property int _consecutiveFailures: 0
    property string _lastError: ""

    function entryFor(name) {
        for (var i = 0; i < root._entries.length; ++i) {
            if (root._entries[i].name === name) return root._entries[i];
        }
        return null;
    }

    function isImage(name) {
        var lower = name.toLowerCase();
        return lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")
            || lower.endsWith(".webp") || lower.endsWith(".bmp");
    }

    // Point the switcher at a different directory and look again.
    //
    // The selection is cleared when it does not survive the move, because
    // leaving Settings.wallpaper pointing into a directory the user just left
    // would make every chip unhighlighted and the next boot try to apply a file
    // that is not there.
    function setDirectory(dir) {
        const trimmed = (dir || "").trim();
        if (trimmed.length === 0) return;
        if (trimmed === root.directory) {
            root.rescan();
            return;
        }
        Settings.wallpaperDir = trimmed;
        Settings.save();
        root.rescan();
    }

    function rescan() {
        _scanned = false;
        _scannedDir = root.directory;
        _scanProc.command = [
            "sh", "-c",
            'if [ ! -d "$1" ]; then printf "%s\\n" "###CTOSWPERR"; exit 0; fi; for f in "$1"/*; do [ -f "$f" ] || continue; printf "%s\\n" "$f"; done',
            "ctos-wallpaper-scan", root.directory
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
                // Guard against a scan whose result arrives after the user has
                // already pointed somewhere else.
                if (root._scannedDir !== root.directory) return;

                const raw = text || "";

                // A sentinel line rather than an exit code: StdioCollector
                // exposes only `text`, so there is no exitCode to read here, and
                // this is the same marker technique CalendarService uses to split
                // its combined output.
                if (raw.indexOf("###CTOSWPERR") >= 0) {
                    root._entries = [];
                    root._scanned = true;
                    root._lastError = "not a directory: " + root.directory;
                    console.warn("[WallpaperService] " + root._lastError);
                    return;
                }

                const found = [];
                const lines = raw.split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const path = lines[i].trim();
                    if (path.length === 0) continue;

                    const slash = path.lastIndexOf("/");
                    const name = slash >= 0 ? path.slice(slash + 1) : path;
                    if (!root.isImage(name)) continue;

                    found.push({ name: name, path: path });
                    if (found.length >= root.maxWallpapers) break;
                }

                found.sort(function (a, b) { return a.name.localeCompare(b.name); });

                root._entries = found;
                root._scanned = true;
                root._lastError = "";

                if (root.entryFor(root.currentName) === null && found.length > 0) {
                    console.warn("[WallpaperService] selection '" + root.currentName
                        + "' is not in " + root.directory + "; falling back to '"
                        + found[0].name + "'");
                    Settings.wallpaper = found[0].name;
                    Settings.save();
                    root.apply(found[0].name);
                }
            }
        }
    }

    // =========================================================================
    // Actions
    // =========================================================================

    // Apply a wallpaper by filename within the current directory.
    //
    // The filename is checked against the scan rather than trusted: a selection
    // can be stale (directory changed, file deleted), and handing awww a path
    // that does not exist would blank the desktop with no way back from the UI.
    function apply(name) {
        const entry = root.entryFor(name);
        if (!entry) {
            _lastError = "no such wallpaper in " + root.directory + ": " + name;
            console.warn("[WallpaperService] " + _lastError);
            return false;
        }
        if (_awwwProcess.running) return false;

        _pendingPath = entry.path;
        _attempt = 0;
        _lastError = "";
        _launch();
        return true;
    }

    function _launch() {
        _awwwProcess.command = [
            "awww", "img", _pendingPath,
            "--transition-type", "fade",
            "--transition-duration", "1"
        ];
        _awwwProcess.running = true;
    }

    // =========================================================================
    // Retry
    //
    // The daemon socket can appear a little after the graphical session target
    // does, so a first failure is a startup race rather than a real one. Retry
    // briefly, exactly as the session-start unit does, and only then believe it.
    //
    // 20 attempts at 250ms is ~5s, which covers the race without turning a
    // genuinely missing daemon into a five-second hang on every selection.
    // =========================================================================

    readonly property int maxAttempts: 20
    readonly property int retryDelayMs: 250

    property string _pendingPath: ""
    property int _attempt: 0

    Process {
        id: _awwwProcess

        onExited: function(exitCode) {
            if (exitCode === 0) {
                _consecutiveFailures = 0;
                _lastError = "";
                return;
            }

            _attempt += 1;
            if (_attempt < root.maxAttempts) {
                _retryTimer.restart();
                return;
            }

            _consecutiveFailures += 1;
            _lastError = "awww img exited " + exitCode + " after " + root.maxAttempts + " attempts";
            console.warn("[WallpaperService] " + _lastError
                + " (socket: " + root._socketPath + ")");
        }
    }

    Timer {
        id: _retryTimer
        interval: root.retryDelayMs
        onTriggered: root._launch()
    }

    // =========================================================================
    // Session start
    //
    // The session-start systemd unit applies a wallpaper too, and that is
    // deliberate: it is the fallback for a session where the shell never starts.
    // Re-applying the same image is idempotent, so applying the recorded choice
    // here as well is what makes the shell authoritative after a shell restart.
    // =========================================================================

    Component.onCompleted: {
        root.rescan();
    }

    // Re-scan when the directory changes from anywhere, including a hand-edited
    // settings file. Settings.wallpaperDir is a plain property, so this is the
    // only thing keeping the browser in step with it.
    Connections {
        target: Settings
        function onWallpaperDirChanged() {
            root.rescan();
        }
    }
}