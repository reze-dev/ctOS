#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Expansion Boundary & Corner Cases Test Suite
# Requirements: ORIGINAL_REQUEST §R1-R5, PROJECT.md
# Tests degenerate, boundary, and resource fault-tolerance conditions:
# - Empty ss output, header-only, malformed columns
# - Loopback, wildcard, and multicast filtering
# - Empty/missing/corrupted settings.json positioning fallbacks
# - Negative & overflow coordinate clamping
# - Missing procfs files and non-numeric uptime
# - Zero active MPRIS players, empty track metadata
# - Unknown / invalid named anchor strings
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SERVICE_FILE="${PROJECT_ROOT}/shell/desktop/services/NetworkTracerService.qml"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
PROFILER_FILE="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/TargetProfilerWidget.qml"
AUDIO_FILE="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/AudioSurveillanceWidget.qml"

# ------------------------------------------------------------------------------
# T2.EXP.01: Empty & Header-Only ss Command Output Handling
# ------------------------------------------------------------------------------
test_case "T2.EXP.01" "Expansion Boundary: NetworkTracerService handles empty & header-only ss output"
if [[ -f "${SERVICE_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${SERVICE_FILE}"'", "utf8");
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

// 1. Empty string
parseFn("");
if (root.activeConnections.length !== 0) throw new Error("Empty string failed");

// 2. Whitespace only
parseFn("   \n\t  \n  ");
if (root.activeConnections.length !== 0) throw new Error("Whitespace only failed");

// 3. Header only
parseFn("Netid  State  Recv-Q  Send-Q  Local Address:Port  Peer Address:Port\n");
if (root.activeConnections.length !== 0) throw new Error("Header only failed");
' || assert_eq "0" "1" "Empty ss output handling failed"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.02: Malformed Rows in ss Output (Incomplete Columns, Missing Colon)
# ------------------------------------------------------------------------------
test_case "T2.EXP.02" "Expansion Boundary: NetworkTracerService skips incomplete & malformed rows"
if [[ -f "${SERVICE_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${SERVICE_FILE}"'", "utf8");
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

const malformed = `
tcp
tcp 0 0
udp 0 0 192.168.1.1:123
tcp 0 0 192.168.1.1:50000 8.8.8.8-nocolon
tcp 0 0 192.168.1.1:50001 8.8.8.8:53
`;
parseFn(malformed);
if (root.activeConnections.length !== 1 || root.activeConnections[0].ip !== "8.8.8.8") {
    throw new Error("Malformed rows handling failed: " + JSON.stringify(root.activeConnections));
}
' || assert_eq "0" "1" "Malformed ss rows parsing failed"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.03: Comprehensive Loopback, Multicast and Wildcard Address Filtering
# ------------------------------------------------------------------------------
test_case "T2.EXP.03" "Expansion Boundary: NetworkTracerService filters all loopback & wildcard endpoints"
if [[ -f "${SERVICE_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${SERVICE_FILE}"'", "utf8");
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

const input = `
tcp 0 0 192.168.1.5:40001 127.0.0.1:8080
tcp 0 0 192.168.1.5:40002 127.10.20.30:9000
tcp 0 0 192.168.1.5:40003 [::1]:6379
tcp 0 0 192.168.1.5:40004 0.0.0.0:443
tcp 0 0 192.168.1.5:40005 *:80
tcp 0 0 192.168.1.5:40006 localhost:3000
tcp 0 0 192.168.1.5:40007 142.250.190.46:443
`;
parseFn(input);
if (root.activeConnections.length !== 1 || root.activeConnections[0].ip !== "142.250.190.46") {
    throw new Error("Loopback filtering failed: " + JSON.stringify(root.activeConnections));
}
' || assert_eq "0" "1" "Loopback filtering verification failed"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.04: Negative & Extreme Overflow Coordinate Clamping in Settings
# ------------------------------------------------------------------------------
test_case "T2.EXP.04" "Expansion Boundary: Settings.normalizePosition clamps negative coordinates to 0"
TMP_QML_CLAMP="$(mktemp /tmp/ctos_test_t2_clamp_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_CLAMP}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    cpuHexGrid: { x: -500, y: -120 },
                    ramBlockBar: { anchor: "bottom-right", offsetX: -80, offsetY: -30 }
                }
            }));

            const cpuTop = Settings.getWidgetMargin("cpuHexGrid", "top", -1);
            const cpuLeft = Settings.getWidgetMargin("cpuHexGrid", "left", -1);
            const ramBottom = Settings.getWidgetMargin("ramBlockBar", "bottom", -1);
            const ramRight = Settings.getWidgetMargin("ramBlockBar", "right", -1);

            if (cpuTop === 0 && cpuLeft === 0 && ramBottom === 0 && ramRight === 0) {
                console.log("=== PASS: Negative coordinate clamping verified ===");
            } else {
                console.error("ASSERTION_FAILED: Negative coordinates not clamped to 0: cpuTop=" + cpuTop + " cpuLeft=" + cpuLeft);
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_CLAMP}" "Negative coordinate clamping harness"
rm -f "${TMP_QML_CLAMP}"

# ------------------------------------------------------------------------------
# T2.EXP.05: Corrupted & Non-Object Settings Fallbacks
# ------------------------------------------------------------------------------
test_case "T2.EXP.05" "Expansion Boundary: Settings gracefully handles non-object & null widget entries"
TMP_QML_CORRUPT="$(mktemp /tmp/ctos_test_t2_corrupt_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_CORRUPT}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            // Nulls, arrays, and primitive strings inside widgets
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    cpuHexGrid: null,
                    ramBlockBar: "invalid-string",
                    networkFlow: [1, 2, 3],
                    targetProfiler: { x: "not-a-number", y: true }
                }
            }));

            // Should fall back to default anchors/margins without error
            const cpuTop = Settings.getWidgetMargin("cpuHexGrid", "top", 48);
            const ramTop = Settings.getWidgetMargin("ramBlockBar", "top", 264);
            const netBottom = Settings.getWidgetMargin("networkFlow", "bottom", 24);

            if (cpuTop === 48 && ramTop === 264 && netBottom === 24) {
                console.log("=== PASS: Corrupt widget positioning handled gracefully ===");
            } else {
                console.error("ASSERTION_FAILED: Fallback mismatch on corrupted widgets");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_CORRUPT}" "Corrupted widget positioning harness"
rm -f "${TMP_QML_CORRUPT}"

# ------------------------------------------------------------------------------
# T2.EXP.06: Missing Virtual Procfs System Files
# ------------------------------------------------------------------------------
test_case "T2.EXP.06" "Expansion Boundary: TargetProfilerWidget handles missing procfs files with fallbacks"
if [[ -f "${PROFILER_FILE}" ]]; then
    # Must declare printErrors: false on all FileViews to avoid spamming logs
    assert_grep 'printErrors:\s*false' "${PROFILER_FILE}" "FileViews must set printErrors: false for missing virtual files"
    assert_grep 'fallbackHostFile' "${PROFILER_FILE}" "Must implement fallback host file (/etc/hostname)"
else
    assert_file_exists "${PROFILER_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.07: Non-Numeric & Missing /proc/uptime Parsing
# ------------------------------------------------------------------------------
test_case "T2.EXP.07" "Expansion Boundary: TargetProfilerWidget parses non-numeric or empty uptime cleanly"
if [[ -f "${PROFILER_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${PROFILER_FILE}"'", "utf8");

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

// 1. Empty string
if (parseUptime.call({ formatUptime }, "") !== "0d 0h 0m") throw new Error("Empty uptime failed");
// 2. Corrupted alpha text
if (parseUptime.call({ formatUptime }, "corrupted_text_no_float") !== "0d 0h 0m") throw new Error("Corrupted uptime failed");
// 3. Negative seconds
if (parseUptime.call({ formatUptime }, "-500.0 0.0") !== "0d 0h 0m") throw new Error("Negative uptime failed");
' || assert_eq "0" "1" "Uptime boundary parsing failed"
else
    assert_file_exists "${PROFILER_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.08: Zero Active MPRIS Players (Headless / Idle Environment)
# ------------------------------------------------------------------------------
test_case "T2.EXP.08" "Expansion Boundary: AudioSurveillanceWidget renders scan mode with 0 active players"
if [[ -f "${AUDIO_FILE}" ]]; then
    # Must guard null activePlayer and return safe fallback strings
    assert_grep 'NO CARRIER' "${AUDIO_FILE}" "Must provide fallback title when activePlayer is null"
    assert_grep 'FREQUENCY SCAN ACTIVE' "${AUDIO_FILE}" "Must provide fallback artist when activePlayer is null"
    assert_grep '\[FREQ SCAN\]' "${AUDIO_FILE}" "Must provide fallback intercept status when idle"
else
    assert_file_exists "${AUDIO_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.09: Missing Track Metadata on Active Player
# ------------------------------------------------------------------------------
test_case "T2.EXP.09" "Expansion Boundary: AudioSurveillanceWidget handles empty title/artist on player"
if [[ -f "${AUDIO_FILE}" ]]; then
    assert_grep "(--UNTITLED--)" "${AUDIO_FILE}" "Must supply --UNTITLED-- when trackTitle is blank"
    assert_grep "(--UNKNOWN SOURCE--)" "${AUDIO_FILE}" "Must supply --UNKNOWN SOURCE-- when trackArtist is blank"
else
    assert_file_exists "${AUDIO_FILE}"
fi

# ------------------------------------------------------------------------------
# T2.EXP.10: Unknown / Unrecognized Named Anchor Strings
# ------------------------------------------------------------------------------
test_case "T2.EXP.10" "Expansion Boundary: Unknown anchor strings ('center', 'floating') default safely"
TMP_QML_UNK_ANCHOR="$(mktemp /tmp/ctos_test_t2_unk_anchor_XXXXXX.qml)"
cat << 'EOF' > "${TMP_QML_UNK_ANCHOR}"
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    networkTracer: { anchor: "middle-center-unrecognized", offsetX: 50, offsetY: 50 }
                }
            }));

            const aTop = Settings.getWidgetAnchor("networkTracer", "top", false);
            const aBottom = Settings.getWidgetAnchor("networkTracer", "bottom", false);
            const aLeft = Settings.getWidgetAnchor("networkTracer", "left", false);
            const aRight = Settings.getWidgetAnchor("networkTracer", "right", false);

            // None of the edges should match
            if (!aTop && !aBottom && !aLeft && !aRight) {
                console.log("=== PASS: Unrecognized anchor string handled safely ===");
            } else {
                console.error("ASSERTION_FAILED: Unrecognized anchor produced spurious edge");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_QML_UNK_ANCHOR}" "Unrecognized anchor string harness"
rm -f "${TMP_QML_UNK_ANCHOR}"

report_summary
