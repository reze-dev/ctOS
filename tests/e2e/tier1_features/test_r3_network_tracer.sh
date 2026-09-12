#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature R3: Network Packet Tracer Service & Widget
# Requirements: ORIGINAL_REQUEST §R3, PROJECT.md
# Verifies NetworkTracerService.qml backend and NetworkTracerWidget.qml UI.
# Tests allowlisted ss command execution, zero sh -c, established connection parsing,
# IPv6 bracket stripping, loopback address filtering, and monospace UI display.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SERVICE_FILE="${PROJECT_ROOT}/shell/desktop/services/NetworkTracerService.qml"
WIDGET_FILE="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/NetworkTracerWidget.qml"

# ------------------------------------------------------------------------------
# R3.01: File Existence & Basic Structure
# ------------------------------------------------------------------------------
test_case "R3.01" "Network Tracer: Service and Widget files exist in desktop/"
assert_file_exists "${SERVICE_FILE}" "shell/desktop/services/NetworkTracerService.qml required"
assert_file_exists "${WIDGET_FILE}" "shell/desktop/surfaces/widgets/NetworkTracerWidget.qml required"

# ------------------------------------------------------------------------------
# R3.02: Zero-Polling & Security Compliance (No running: true, No sh -c)
# ------------------------------------------------------------------------------
test_case "R3.02" "Network Tracer: Process declared running: false, strictly zero sh -c invocations"
if [[ -f "${SERVICE_FILE}" ]]; then
    # Must declare Process with running: false
    assert_grep 'running:\s*false' "${SERVICE_FILE}" "Process must be declared with running: false initially"
    assert_not_grep '["'\''"]sh["'\''"]\s*,\s*["'\''"]-c["'\''"]' "${SERVICE_FILE}" "Process must never invoke sh -c"
    assert_not_grep 'sh\s+-c' "${SERVICE_FILE}" "No shell string invocations permitted"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# R3.03: Allowlisted Command Arguments: ss -H -t -u -n state established
# ------------------------------------------------------------------------------
test_case "R3.03" "Network Tracer: Subprocess executes discrete allowlisted ss command array"
if [[ -f "${SERVICE_FILE}" ]]; then
    assert_grep 'command:\s*\[\s*"ss"' "${SERVICE_FILE}" "Process command array must start with 'ss'"
    assert_grep '"-H"' "${SERVICE_FILE}" "ss command must include -H (suppress header)"
    assert_grep '"-t"' "${SERVICE_FILE}" "ss command must include -t (TCP)"
    assert_grep '"-u"' "${SERVICE_FILE}" "ss command must include -u (UDP)"
    assert_grep '"-n"' "${SERVICE_FILE}" "ss command must include -n (numeric, prevents DNS lag)"
    assert_grep '"established"' "${SERVICE_FILE}" "ss command must filter state established"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# R3.04: Service Public Contract & Refresh Interval
# ------------------------------------------------------------------------------
test_case "R3.04" "Network Tracer: Service exposes activeConnections, connectionCount, refreshInterval >= 1000"
if [[ -f "${SERVICE_FILE}" ]]; then
    assert_qml_property "${SERVICE_FILE}" "activeConnections" --type var
    assert_qml_property "${SERVICE_FILE}" "connectionCount" --type int
    assert_qml_property "${SERVICE_FILE}" "refreshInterval" --type int
    assert_qml_signal "${SERVICE_FILE}" "connectionsUpdated"
    assert_qml_method "${SERVICE_FILE}" "refresh"
    # Ensure refreshInterval is >= 1000ms
    assert_grep 'refreshInterval:\s*[1-9][0-9]{3,}' "${SERVICE_FILE}" "refreshInterval must be >= 1000ms"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# R3.05: Backend Connection Parsing Algorithm & Loopback Exclusion
# ------------------------------------------------------------------------------
test_case "R3.05" "Network Tracer: Output parser strips IPv6 brackets & filters loopback addresses"
if [[ -f "${SERVICE_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${SERVICE_FILE}"'", "utf8");

// Extract _parseSsOutput function body
const fnMatch = qml.match(/function\s+_parseSsOutput\s*\(([^)]*)\)[^{]*\{/);
if (!fnMatch) throw new Error("Could not find _parseSsOutput in NetworkTracerService.qml");

const start = fnMatch.index + fnMatch[0].length;
let braces = 1, i = start;
while (i < qml.length && braces > 0) {
    if (qml[i] === "{") braces++;
    else if (qml[i] === "}") braces--;
    i++;
}
const body = qml.substring(start, i - 1);

const root = {
    activeConnections: [],
    connectionsUpdated: function(res) { this.activeConnections = res; }
};

const parseFn = new Function("raw", "const root = this;\n" + body).bind(root);

// Test sample output
const mockSs = `
tcp  0  0  192.168.1.50:42196  34.54.84.110:443
tcp  0  0  127.0.0.1:5432      127.0.0.1:40120
udp  0  0  192.168.1.50:51234  1.1.1.1:53
tcp  0  0  [fe80::1]:50000     [2001:4860:4860::8888]:443
tcp  0  0  192.168.1.50:44444  0.0.0.0:80
`;

parseFn(mockSs);

const res = root.activeConnections;
if (!Array.isArray(res) || res.length !== 3) {
    throw new Error("Expected 3 connections (loopback and 0.0.0.0 filtered out), got: " + JSON.stringify(res));
}

// 1. IPv4 TCP
if (res[0].protocol !== "TCP" || res[0].ip !== "34.54.84.110" || res[0].port !== "443") {
    throw new Error("IPv4 TCP entry mismatch: " + JSON.stringify(res[0]));
}

// 2. UDP
if (res[1].protocol !== "UDP" || res[1].ip !== "1.1.1.1" || res[1].port !== "53") {
    throw new Error("UDP entry mismatch: " + JSON.stringify(res[1]));
}

// 3. IPv6 without brackets
if (res[2].ip !== "2001:4860:4860::8888" || res[2].port !== "443") {
    throw new Error("IPv6 bracket stripping mismatch: " + JSON.stringify(res[2]));
}
' || assert_eq "0" "1" "NetworkTracerService _parseSsOutput failed unit verification"
else
    assert_file_exists "${SERVICE_FILE}"
fi

# ------------------------------------------------------------------------------
# R3.06: Surface HUD Layout, Monospace Typography & Badges
# ------------------------------------------------------------------------------
test_case "R3.06" "Network Tracer: Widget embeds CornerBrackets, monospace typography & status badges"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "CornerBrackets" "${WIDGET_FILE}" "Widget must embed CornerBrackets framing"
    assert_grep "Theme\.fontFamilyMonospace" "${WIDGET_FILE}" "Widget must use monospace font"
    assert_grep "Theme\.acidGreen" "${WIDGET_FILE}" "Widget must use acidGreen accent color"
    assert_grep 'text:\s*"NET // PACKET TRACER"' "${WIDGET_FILE}" "Widget must render cyber header"
    assert_grep 'text:\s*"ESTAB:\s*"' "${WIDGET_FILE}" "Widget must render established connection count badge"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R3.07: Empty State & Idle Feed Handling
# ------------------------------------------------------------------------------
test_case "R3.07" "Network Tracer: Idle state renders clean cyber subnet scanning notice"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "(SCANNING|SUBNET IDLE|NO OUTBOUND|CARRIER)" "${WIDGET_FILE}" "Widget must provide themed cyber idle state"
else
    assert_file_exists "${WIDGET_FILE}"
fi

report_summary
