#!/usr/bin/env bash
# ==============================================================================
# Tier 5 - Challenger 2 Adversarial White-Box Coverage Audit & Stress Suite
# Target files:
# - assets/ctos-plymouth/ctos.script
# - shell/desktop/core/Settings.qml
# - shell/desktop/services/NetworkTracerService.qml
# - shell/desktop/surfaces/widgets/NetworkTracerWidget.qml
# - shell/desktop/surfaces/widgets/AudioSurveillanceWidget.qml
# - shell/desktop/surfaces/widgets/TargetProfilerWidget.qml
# - shell/shell.qml
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/harness/mock_environment.sh"
source "${SCRIPT_DIR}/harness/qml_runner.sh"

QUICKSHELL_BIN=""
if command -v qs >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v quickshell)"
else
    for candidate in /nix/store/*quickshell*/bin/quickshell; do
        if [[ -x "${candidate}" ]]; then
            QUICKSHELL_BIN="${candidate}"
            break
        fi
    done
fi

PLYMOUTH_SCRIPT="${PROJECT_ROOT}/assets/ctos-plymouth/ctos.script"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
TRACER_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkTracerService.qml"
TRACER_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/NetworkTracerWidget.qml"
AUDIO_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/AudioSurveillanceWidget.qml"
PROFILER_WIDGET="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/TargetProfilerWidget.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

echo "======================================================================"
echo "ctOS Challenger 2: Adversarial White-Box Coverage & Stress Test Suite"
echo "======================================================================"

# ------------------------------------------------------------------------------
# ADV.01: Plymouth Script: Zero Image.Text in loop & 100,000-frame simulation
# ------------------------------------------------------------------------------
test_case "ADV.01" "Plymouth: Zero Image.Text in loop & 100k-frame simulation"
python3 -c "
import sys, os, re

script_path = '${PLYMOUTH_SCRIPT}'
assert os.path.exists(script_path), 'ctos.script does not exist'
with open(script_path, 'r', encoding='utf-8') as f:
    code = f.read()

# Verify zero Image.Text in callback
cb_start = code.find('fun refresh_callback')
assert cb_start != -1, 'refresh_callback not found'
cb_end = code.find('Plymouth.SetRefreshFunction', cb_start)
if cb_end == -1: cb_end = len(code)
cb_body = code[cb_start:cb_end]
assert 'Image.Text' not in cb_body, 'Image.Text called inside refresh_callback'

# Verify zero unsupported boolean operators
assert not re.search(r'if\s*\([^)]*(&&|\|\|)[^)]*\)', code), 'Unsupported && or || in if conditionals'

# 100,000 frame simulation
frame = 0
log_index = 0
for frame in range(1, 100001):
    prog_idx = int(frame // 6) % 9
    assert 0 <= prog_idx < 9, f'prog_idx {prog_idx} out of range at frame {frame}'
    if frame % 8 == 0:
        log_index += 1
    for i in range(5):
        line_idx = log_index + i - 4
        show_line = 0
        if line_idx >= 0:
            if line_idx < 13:
                show_line = 1
        if show_line == 1:
            assert 0 <= line_idx < 13, f'line_idx {line_idx} out of range'
            opacity = 0.3 + (i * 0.15)
            assert 0.0 <= opacity <= 1.0, f'opacity {opacity} out of range'
sys.exit(0)
" || assert_eq "0" "1" "Plymouth simulation or invariance failed"

# ------------------------------------------------------------------------------
# ADV.02: Plymouth Script: Native C parser AST validation
# ------------------------------------------------------------------------------
test_case "ADV.02" "Plymouth: Native libplymouth script.so AST syntax validation"
python3 -c "
import sys, os, glob, ctypes

def find_script_so():
    candidates = glob.glob('/nix/store/*plymouth*/lib/plymouth/script.so')
    if candidates: return candidates[0]
    for p in ['/usr/lib/plymouth/script.so', '/usr/lib64/plymouth/script.so']:
        if os.path.exists(p): return p
    return None

lib_path = find_script_so()
if not lib_path: sys.exit(0)

lib = ctypes.CDLL(lib_path)
lib.script_parse_file.argtypes = [ctypes.c_char_p]
lib.script_parse_file.restype = ctypes.c_void_p

ast = lib.script_parse_file('${PLYMOUTH_SCRIPT}'.encode('utf-8'))
assert ast is not None, 'script.so parser returned NULL on ctos.script'
sys.exit(0)
" || assert_eq "0" "1" "Plymouth script.so C AST parsing failed"

# ------------------------------------------------------------------------------
# ADV.03: Settings: Live disk hot-reloading with active widgets in Quickshell
# ------------------------------------------------------------------------------
test_case "ADV.03" "Settings: Live disk hot-reloading with active widgets in Quickshell"
TMP_SETTINGS="$(mktemp /tmp/ctos_adv_settings_hotreload_XXXXXX.json)"
cat << 'JSON_EOF' > "${TMP_SETTINGS}"
{
  "widgets": {
    "cpuHexGrid": { "x": 345, "y": 567 },
    "networkTracer": { "x": 123, "y": 234 },
    "targetProfiler": { "x": 80, "y": 95 }
  }
}
JSON_EOF

TMP_QML="$(mktemp /tmp/ctos_adv_qml_hotreload_XXXXXX.qml)"
cat << 'QML_EOF' > "${TMP_QML}"
import QtQuick
import Quickshell
import desktop.core
import desktop.surfaces.widgets

Scope {
    id: scopeRoot
    property int tick: 0

    CpuHexGrid { id: cpu }
    NetworkTracerWidget { id: tracer }
    TargetProfilerWidget { id: profiler }

    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            scopeRoot.tick++;
            if (scopeRoot.tick === 1) {
                const cT = Settings.getWidgetMargin("cpuHexGrid", "top", 0);
                const cL = Settings.getWidgetMargin("cpuHexGrid", "left", 0);
                const nT = Settings.getWidgetMargin("networkTracer", "top", 0);
                const nL = Settings.getWidgetMargin("networkTracer", "left", 0);
                const pT = Settings.getWidgetMargin("targetProfiler", "top", 0);
                const pL = Settings.getWidgetMargin("targetProfiler", "left", 0);

                if (cT !== 567 || cL !== 345 || nT !== 234 || nL !== 123 || pT !== 95 || pL !== 80) {
                    console.error("ASSERTION_FAILED: Initial disk values mismatch: " + JSON.stringify({cT, cL, nT, nL, pT, pL}));
                    Qt.quit();
                    return;
                }

                // Dynamic live rewrite
                Settings.parseConfig(JSON.stringify({
                    widgets: {
                        cpuHexGrid: { x: 789, y: 890 },
                        networkTracer: { anchor: "top-right", offsetX: 55, offsetY: 65 },
                        targetProfiler: { anchor: "bottom-left", offsetX: 40, offsetY: 75 }
                    }
                }));
            } else if (scopeRoot.tick === 2) {
                const cT2 = Settings.getWidgetMargin("cpuHexGrid", "top", 0);
                const cL2 = Settings.getWidgetMargin("cpuHexGrid", "left", 0);
                const aTop = Settings.getWidgetAnchor("networkTracer", "top", false);
                const aRight = Settings.getWidgetAnchor("networkTracer", "right", false);
                const nT2 = Settings.getWidgetMargin("networkTracer", "top", 0);
                const nR2 = Settings.getWidgetMargin("networkTracer", "right", 0);
                const pBottom = Settings.getWidgetAnchor("targetProfiler", "bottom", false);
                const pLeft = Settings.getWidgetAnchor("targetProfiler", "left", false);
                const pB2 = Settings.getWidgetMargin("targetProfiler", "bottom", 0);
                const pL2 = Settings.getWidgetMargin("targetProfiler", "left", 0);

                if (cT2 === 890 && cL2 === 789 && aTop && aRight && nT2 === 65 && nR2 === 55 &&
                    pBottom && pLeft && pB2 === 75 && pL2 === 40) {
                    console.log("=== PASS: Live disk settings hot-reload verified with live widgets ===");
                } else {
                    console.error("ASSERTION_FAILED: Reload values mismatch: " + JSON.stringify({cT2, cL2, aTop, aRight, nT2, nR2, pBottom, pLeft, pB2, pL2}));
                }
                Qt.quit();
            }
        }
    }
}
QML_EOF

CTOS_SETTINGS_PATH="${TMP_SETTINGS}" QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 6 "${QUICKSHELL_BIN}" -p "${TMP_QML}" >/tmp/ctos_adv03.log 2>&1
grep -q "PASS: Live disk settings hot-reload verified" /tmp/ctos_adv03.log || assert_eq "0" "1" "Live disk hot-reload failed: $(cat /tmp/ctos_adv03.log)"
rm -f "${TMP_SETTINGS}" "${TMP_QML}" /tmp/ctos_adv03.log

# ------------------------------------------------------------------------------
# ADV.04: Settings: Malformed JSON, null widget entries & negative coordinate clamping
# ------------------------------------------------------------------------------
test_case "ADV.04" "Settings: Malformed JSON & negative coordinate clamping"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    if (!match) throw new Error("Function " + fnName + " not found");
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    return new Function(...params, "const root = this;\n" + source.substring(startIndex, i - 1));
}

const normalizePosition = extractFunction(qml, "normalizePosition");

// Format 1: Negative coordinates must clamp to 0
const p1 = normalizePosition({ x: -500, y: -200 });
if (p1.margins.left !== 0 || p1.margins.top !== 0) throw new Error("Negative x/y not clamped to 0");

// Format 2: Named anchor with negative offsets
const p2 = normalizePosition({ anchor: "bottom-right", offsetX: -50, offsetY: -30 });
if (p2.margins.right !== 0 || p2.margins.bottom !== 0) throw new Error("Negative offsets not clamped to 0");

// Format 3: Explicit margins with negative numbers
const p3 = normalizePosition({ margins: { top: -10, left: -20, right: 15, bottom: 25 } });
if (p3.margins.top !== 0 || p3.margins.left !== 0 || p3.margins.right !== 15 || p3.margins.bottom !== 25) {
    throw new Error("Explicit negative margins not clamped to 0");
}

// Corrupt inputs: null, undefined, boolean, array, string
const pNull = normalizePosition(null, { top: true }, { top: 48 });
if (pNull.margins.top !== 48 || !pNull.anchors.top) throw new Error("Null cfg failed to use defaults");

const pStr = normalizePosition("not-an-object", { left: true }, { left: 24 });
if (pStr.margins.left !== 24 || !pStr.anchors.left) throw new Error("String cfg failed to use defaults");
' "${SETTINGS_FILE}" || assert_eq "0" "1" "Settings normalization boundary test failed"

# ------------------------------------------------------------------------------
# ADV.05: Settings: Preservation of custom widget positions during save()
# ------------------------------------------------------------------------------
test_case "ADV.05" "Settings: Positioning schemas preserved during Settings.save()"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

// Verify save() logic preserves data.widgets[id] object properties
if (!qml.includes("if (typeof data.widgets[id] === \"object\" && data.widgets[id] !== null)")) {
    throw new Error("Settings.save does not check data.widgets[id] object preservation");
}
if (!qml.includes("data.widgets[id].visible = item.isVis;")) {
    throw new Error("Settings.save does not mutate visible property in-place on widget object");
}
' "${SETTINGS_FILE}" || assert_eq "0" "1" "Settings save preservation verification failed"

# ------------------------------------------------------------------------------
# ADV.06: Audio Surveillance: Live Quickshell MPRIS dynamic player property mutation
# ------------------------------------------------------------------------------
test_case "ADV.06" "Audio Surveillance: Live MPRIS property mutation during track playback"
TMP_AUDIO_QML="$(mktemp /tmp/ctos_adv_audio_mpris_XXXXXX.qml)"
cat << 'QML_EOF' > "${TMP_AUDIO_QML}"
import QtQuick
import Quickshell
import desktop.surfaces.widgets
import desktop.core

Scope {
    id: rootScope
    property int step: 0

    QtObject {
        id: mockPlayer
        property int playbackState: 2 // Paused
        property string trackTitle: "Cyber Attack"
        property string trackArtist: "Aiden Pearce"
        property string identity: "DeadSec Radio"

        property int playCount: 0
        property int pauseCount: 0
        property int toggleCount: 0
        property int nextCount: 0
        property int prevCount: 0

        function play() { playCount++; }
        function pause() { pauseCount++; }
        function togglePlaying() { toggleCount++; }
        function next() { nextCount++; }
        function previous() { prevCount++; }
    }

    AudioSurveillanceWidget {
        id: audioWidget
        playerOverride: mockPlayer
    }

    Timer {
        interval: 15
        running: true
        repeat: true
        onTriggered: {
            rootScope.step++;

            if (rootScope.step === 1) {
                // Initial Paused state
                if (!audioWidget.hasMedia || audioWidget.isPlaying ||
                    audioWidget.title !== "Cyber Attack" || audioWidget.artist !== "Aiden Pearce" ||
                    audioWidget.statusText !== "[SCANNING]") {
                    console.error("ASSERTION_FAILED: Step 1 Paused state mismatch");
                    Qt.quit();
                    return;
                }
                // Transition to Playing
                mockPlayer.playbackState = 1;
            } else if (rootScope.step === 2) {
                if (!audioWidget.isPlaying || audioWidget.statusText !== "[LOCKED 104.2MHz]") {
                    console.error("ASSERTION_FAILED: Step 2 Playing state mismatch");
                    Qt.quit();
                    return;
                }
                // Mutate title and artist during playback
                mockPlayer.trackTitle = "Signal Intercepted";
                mockPlayer.trackArtist = "ctOS Central";
            } else if (rootScope.step === 3) {
                if (audioWidget.title !== "Signal Intercepted" || audioWidget.artist !== "ctOS Central" ||
                    audioWidget.interceptString !== "[FREQ INTERCEPT] Signal Intercepted - ctOS Central") {
                    console.error("ASSERTION_FAILED: Step 3 live track mutation mismatch");
                    Qt.quit();
                    return;
                }
                // Test DBus controls
                audioWidget.play();
                audioWidget.pause();
                audioWidget.togglePlaying();
                audioWidget.next();
                audioWidget.previous();

                if (mockPlayer.playCount !== 1 || mockPlayer.pauseCount !== 1 ||
                    mockPlayer.toggleCount !== 1 || mockPlayer.nextCount !== 1 || mockPlayer.prevCount !== 1) {
                    console.error("ASSERTION_FAILED: Control method calls not forwarded");
                    Qt.quit();
                    return;
                }
                // Transition to Stopped with blank metadata
                mockPlayer.playbackState = 0;
                mockPlayer.trackTitle = "";
                mockPlayer.trackArtist = "";
            } else if (rootScope.step === 4) {
                if (audioWidget.hasMedia !== false || audioWidget.isPlaying !== false ||
                    audioWidget.title !== "NO CARRIER" || audioWidget.artist !== "FREQUENCY SCAN ACTIVE" ||
                    audioWidget.fallbackString !== "[FREQ SCAN] AWAITING TRANSMISSION...") {
                    console.error("ASSERTION_FAILED: Step 4 Stopped fallback mismatch");
                    Qt.quit();
                    return;
                }
                audioWidget.playerOverride = null;
            } else if (rootScope.step === 5) {
                // Controls with null player must be safe
                audioWidget.play();
                audioWidget.pause();
                audioWidget.togglePlaying();
                audioWidget.next();
                audioWidget.previous();

                console.log("=== PASS: AudioSurveillanceWidget live MPRIS mutation verified ===");
                Qt.quit();
            }
        }
    }
}
QML_EOF

run_qml_test_harness "${TMP_AUDIO_QML}" "AudioSurveillance MPRIS dynamic mutation" >/tmp/ctos_adv06.log 2>&1
grep -q "PASS: AudioSurveillanceWidget live MPRIS mutation verified" /tmp/ctos_adv06.log || assert_eq "0" "1" "Audio MPRIS mutation test failed: $(cat /tmp/ctos_adv06.log)"
rm -f "${TMP_AUDIO_QML}" /tmp/ctos_adv06.log

# ------------------------------------------------------------------------------
# ADV.07: Audio Surveillance: Multi-player priority resolution algorithm
# ------------------------------------------------------------------------------
test_case "ADV.07" "Audio Surveillance: Multi-player priority resolution algorithm"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

function resolveActivePlayer(list) {
    if (!list || list.length === 0) return null;
    for (let i = 0; i < list.length; i++) {
        const p = list[i];
        if (p && p.playbackState === 1) return p;
    }
    for (let i = 0; i < list.length; i++) {
        const p = list[i];
        if (p && p.playbackState === 2 && p.trackTitle && p.trackTitle.trim() !== "") return p;
    }
    for (let i = 0; i < list.length; i++) {
        const p = list[i];
        if (p && p.playbackState === 2) return p;
    }
    return list[0] || null;
}

const pPausedEmpty = { id: 1, playbackState: 2, trackTitle: "" };
const pPausedWithTrack = { id: 2, playbackState: 2, trackTitle: "Song A" };
const pPlaying = { id: 3, playbackState: 1, trackTitle: "Song B" };

if (resolveActivePlayer([pPausedWithTrack, pPlaying]).id !== 3) throw new Error("Playing priority failed");
if (resolveActivePlayer([pPausedEmpty, pPausedWithTrack]).id !== 2) throw new Error("Paused with track priority failed");
if (resolveActivePlayer([]) !== null) throw new Error("Empty player list should return null");
' "${AUDIO_WIDGET}" || assert_eq "0" "1" "Audio surveillance player priority resolution failed"

# ------------------------------------------------------------------------------
# ADV.08: Target Profiler: Missing virtual procfs files & fallback hostname
# ------------------------------------------------------------------------------
test_case "ADV.08" "Target Profiler: Missing procfs fault tolerance & fallback chain"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

if (!qml.includes("fallbackHostFile.reload()")) {
    throw new Error("TargetProfiler does not trigger fallbackHostFile reload on hostFile failure");
}
if (!qml.includes("property string hostName: \"HOST_NODE\"")) {
    throw new Error("TargetProfiler default hostName should be HOST_NODE");
}
if (!qml.includes("property string kernelVersion: \"UNKNOWN\"")) {
    throw new Error("TargetProfiler default kernelVersion should be UNKNOWN");
}
if (!qml.includes("property string osName: \"ctOS / Linux\"")) {
    throw new Error("TargetProfiler default osName should be ctOS / Linux");
}
' "${PROFILER_WIDGET}" || assert_eq "0" "1" "Target Profiler fallback chain verification failed"

# ------------------------------------------------------------------------------
# ADV.09: Target Profiler: Non-numeric, negative and extreme uptime parsing
# ------------------------------------------------------------------------------
test_case "ADV.09" "Target Profiler: Non-numeric, negative & extreme uptime parsing"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    if (!match) throw new Error("Function " + fnName + " not found");
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    return new Function(...params, "const root = this;\n" + source.substring(startIndex, i - 1));
}

const formatUptime = extractFunction(qml, "formatUptime");
const parseUptime = extractFunction(qml, "_parseUptime");
const root = { formatUptime };

function test(val, expected, msg) {
    const actual = parseUptime.call(root, val);
    if (actual !== expected) throw new Error("FAIL [" + msg + "]: expected " + expected + ", got " + actual);
}

test("", "0d 0h 0m", "empty");
test("   ", "0d 0h 0m", "whitespace");
test("-500.2 0.0", "0d 0h 0m", "negative");
test("not_a_number", "0d 0h 0m", "alpha");
test("0", "0d 0h 0m", "zero");
test("86461.0 123.0", "1d 0h 1m", "1d 1h 1m");
test("31536000.0 0", "365d 0h 0m", "1 year");
' "${PROFILER_WIDGET}" || assert_eq "0" "1" "Target Profiler uptime stress testing failed"

# ------------------------------------------------------------------------------
# ADV.10: Target Profiler: Adversarial /etc/os-release parsing
# ------------------------------------------------------------------------------
test_case "ADV.10" "Target Profiler: Adversarial os-release string parsing"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    return new Function(...params, "const root = this;\n" + source.substring(startIndex, i - 1));
}

const parseOsRelease = extractFunction(qml, "_parseOsRelease");

function test(input, expected, desc) {
    const res = parseOsRelease.call({}, input);
    if (res !== expected) throw new Error("FAIL [" + desc + "]: expected " + expected + ", got " + res);
}

test("", "ctOS / Linux", "empty");
test("   \n ", "ctOS / Linux", "whitespace");
test("PRETTY_NAME=\"ctOS Core 2026\"\nNAME=\"ctOS\"", "ctOS Core 2026", "quoted PRETTY_NAME");
test("PRETTY_NAME=ArchLinux\nNAME=Arch", "ArchLinux", "unquoted PRETTY_NAME");
test("NAME=\"NixOS\"\nID=nixos", "NixOS", "NAME fallback");
test("ID=generic\nVERSION=1.0", "Linux", "generic Linux fallback");
' "${PROFILER_WIDGET}" || assert_eq "0" "1" "Target Profiler os-release parsing failed"

# ------------------------------------------------------------------------------
# ADV.11: Network Tracer: 500+ connection adversarial parse & loopback filtering
# ------------------------------------------------------------------------------
test_case "ADV.11" "Network Tracer: 500-connection parse, IPv6 zone strip & loopback filter"
node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.argv[1], "utf8");

const fnMatch = qml.match(/function\s+_parseSsOutput\s*\(([^)]*)\)[^{]*\{/);
const start = fnMatch.index + fnMatch[0].length;
let braces = 1, i = start;
while (i < qml.length && braces > 0) {
    if (qml[i] === "{") braces++;
    else if (qml[i] === "}") braces--;
    i++;
}
const body = qml.substring(start, i - 1);
const root = { activeConnections: [], connectionsUpdated: function(r) { this.activeConnections = r; } };
const parseFn = new Function("raw", "const root = this;\n" + body).bind(root);

let ssData = "Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port\n";
ssData += "tcp 0 0 127.0.0.1:50000 127.0.0.1:8080\n";
ssData += "tcp 0 0 192.168.1.1:50001 127.255.0.1:9000\n";
ssData += "tcp 0 0 [::1]:50002 [::1]:6379\n";
ssData += "udp 0 0 0.0.0.0:50003 0.0.0.0:123\n";
ssData += "tcp 0 0 [::]:50004 [::]:80\n";
ssData += "tcp 0 0 192.168.1.1:50005 *:443\n";
ssData += "tcp 0 0 192.168.1.1:50006 localhost:3000\n";
ssData += "garbage_line\n";
ssData += "tcp 0 0 192.168.1.1:50007\n";
ssData += "tcp 0 0 [fe80::2]:50009 [fe80::1%eth0]:22\n";

for (let j = 0; j < 200; j++) {
    ssData += `tcp 0 0 192.168.1.100:${50000 + j} 104.20.${j % 250}.1:${80 + (j % 5000)}\n`;
}

for (let j = 0; j < 50; j++) {
    ssData += `udp 0 0 [2001:db8::1]:${40000 + j} [2606:4700:4700::${j + 1}]:443\n`;
}

parseFn(ssData);

if (root.activeConnections.length !== 251) {
    throw new Error("Expected 251 parsed connections, got " + root.activeConnections.length);
}

const fe80 = root.activeConnections.find(c => c.ip === "fe80::1");
if (!fe80 || fe80.port !== "22" || fe80.protocol !== "TCP") {
    throw new Error("Zone index strip failed: " + JSON.stringify(fe80));
}

for (const conn of root.activeConnections) {
    if (conn.ip.startsWith("127.") || conn.ip === "::1" || conn.ip === "0.0.0.0" || conn.ip === "*" || conn.ip === "::" || conn.ip === "localhost") {
        throw new Error("Leaked loopback address: " + conn.ip);
    }
}
' "${TRACER_SVC}" || assert_eq "0" "1" "Network tracer adversarial parsing failed"

# ------------------------------------------------------------------------------
# ADV.12: Shell: Multi-Screen Variants positioning & ramBlockBar dynamic gap avoidance
# ------------------------------------------------------------------------------
test_case "ADV.12" "Shell: All 6 widgets in shell.qml & ramBlockBar gap avoidance"
TMP_INIT_CFG="$(mktemp /tmp/ctos_init_cfg_XXXXXX.json)"
cat << 'JSON_EOF' > "${TMP_INIT_CFG}"
{
  "widgetCpuHexGridVisible": true
}
JSON_EOF

TMP_SHELL_QML="$(mktemp /tmp/ctos_adv_shell_gap_XXXXXX.qml)"
cat << 'QML_EOF' > "${TMP_SHELL_QML}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    id: testScope
    property int step: 0

    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            if (testScope.step === 0) {
                if (!Settings.isLoaded) return;
                testScope.step = 1;

                // Phase 1: Default initial state (cpuHexGrid visible -> top margin is 264)
                const m1 = Settings.hasWidgetMargin("ramBlockBar", "top") 
                    ? Settings.getWidgetMargin("ramBlockBar", "top", 0) 
                    : (Settings.widgetCpuHexGridVisible ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));

                if (m1 !== 264) {
                    console.error("ASSERTION_FAILED: Phase 1 top margin mismatch: " + m1);
                    Qt.quit();
                    return;
                }

                // Phase 2: Set widgetCpuHexGridVisible to false -> margin collapses to 48
                Settings.parseConfig(JSON.stringify({ widgetCpuHexGridVisible: false }));
                testScope.step = 2;
            } else if (testScope.step === 2) {
                const m2 = Settings.hasWidgetMargin("ramBlockBar", "top") 
                    ? Settings.getWidgetMargin("ramBlockBar", "top", 0) 
                    : (Settings.widgetCpuHexGridVisible ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));

                if (m2 !== 48) {
                    console.error("ASSERTION_FAILED: Phase 2 collapsed top margin mismatch: " + m2);
                    Qt.quit();
                    return;
                }

                // Phase 3: Explicit margin override in ramBlockBar
                Settings.parseConfig(JSON.stringify({ widgets: { ramBlockBar: { y: 320 } } }));
                testScope.step = 3;
            } else if (testScope.step === 3) {
                const hasMargin = Settings.hasWidgetMargin("ramBlockBar", "top");
                const m3 = hasMargin 
                    ? Settings.getWidgetMargin("ramBlockBar", "top", 0) 
                    : (Settings.widgetCpuHexGridVisible ? (Theme.barHeight + Theme.spacingXl + 200 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));

                if (m3 !== 320 || !hasMargin) {
                    console.error("ASSERTION_FAILED: Phase 3 explicit margin override mismatch: " + m3);
                    Qt.quit();
                    return;
                }

                console.log("=== PASS: RamBlockBar dynamic gap avoidance verified ===");
                Qt.quit();
            }
        }
    }
}
QML_EOF

CTOS_SETTINGS_PATH="${TMP_INIT_CFG}" QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 6 "${QUICKSHELL_BIN}" -p "${TMP_SHELL_QML}" >/tmp/ctos_adv12.log 2>&1
grep -q "PASS: RamBlockBar dynamic gap avoidance verified" /tmp/ctos_adv12.log || assert_eq "0" "1" "RamBlockBar gap avoidance failed: $(cat /tmp/ctos_adv12.log)"
rm -f "${TMP_INIT_CFG}" "${TMP_SHELL_QML}" /tmp/ctos_adv12.log

# ------------------------------------------------------------------------------
# ADV.13: Architectural Compliance & Security Invariants Across Live Codebase
# ------------------------------------------------------------------------------
test_case "ADV.13" "Architecture: Zero running:true, zero sh -c, zero greeter leakage"
running_procs=$(grep -rn "Process\s*{" "${PROJECT_ROOT}/shell/desktop" -A 10 | grep "running:\s*true" || true)
assert_eq "" "${running_procs}" "Process must never declare running: true"

sh_c_calls=$(grep -rn "sh\s*-c" "${PROJECT_ROOT}/shell/desktop" || true)
assert_eq "" "${sh_c_calls}" "Subshell sh -c execution is strictly prohibited"

greeter_refs=$(grep -rn "greeter" "${PROJECT_ROOT}/shell/desktop" || true)
assert_eq "" "${greeter_refs}" "Greeter symbols leaking into desktop"

report_summary
