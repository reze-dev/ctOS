#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature R5: Target Profiler Widget
# Requirements: ORIGINAL_REQUEST §R5, PROJECT.md
# Verifies TargetProfilerWidget.qml system telemetry fetch via procfs FileView,
# zero subprocesses (zero uname/uptime commands), uptime formatting (Xd Xh Xm),
# Watch Dogs NPC profiler HUD styling, reticle header, and barcode accent.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

WIDGET_FILE="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/TargetProfilerWidget.qml"

# ------------------------------------------------------------------------------
# R5.01: File Existence & Public Dimensions
# ------------------------------------------------------------------------------
test_case "R5.01" "Target Profiler: Widget file exists in desktop/surfaces/widgets/"
assert_file_exists "${WIDGET_FILE}" "shell/desktop/surfaces/widgets/TargetProfilerWidget.qml required"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "implicitWidth:\s*[0-9]+" "${WIDGET_FILE}" "Widget must define implicitWidth"
    assert_grep "implicitHeight:\s*[0-9]+" "${WIDGET_FILE}" "Widget must define implicitHeight"
fi

# ------------------------------------------------------------------------------
# R5.02: Zero-Subprocess Architecture (No Process, No sh -c, No uname/uptime)
# ------------------------------------------------------------------------------
test_case "R5.02" "Target Profiler: Zero subprocesses spawned (pure FileView procfs reads)"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_not_grep "Process\s*\{" "${WIDGET_FILE}" "Widget must never declare Process components"
    assert_not_grep "sh\s+-c" "${WIDGET_FILE}" "Widget must not invoke shell commands"
    assert_not_grep '["'\''"](uname|uptime|hostname)["'\''"]' "${WIDGET_FILE}" "Widget must not spawn external system binaries"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R5.03: Virtual Procfs & System File Targets
# ------------------------------------------------------------------------------
test_case "R5.03" "Target Profiler: Inspects /proc/sys/kernel/hostname, osrelease, /etc/os-release, /proc/uptime"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep 'path:\s*"/proc/sys/kernel/hostname"' "${WIDGET_FILE}" "Must read hostname via FileView"
    assert_grep 'path:\s*"/proc/sys/kernel/osrelease"' "${WIDGET_FILE}" "Must read kernel version via FileView"
    assert_grep 'path:\s*"/etc/os-release"' "${WIDGET_FILE}" "Must read OS release via FileView"
    assert_grep 'path:\s*"/proc/uptime"' "${WIDGET_FILE}" "Must read uptime via FileView"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R5.04: Uptime Parsing & Formatting Helper (Xd Xh Xm)
# ------------------------------------------------------------------------------
test_case "R5.04" "Target Profiler: Uptime helper converts total seconds into 'Xd Xh Xm' format"
if [[ -f "${WIDGET_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${WIDGET_FILE}"'", "utf8");

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
if (formatUptime(0) !== "0d 0h 0m") throw new Error("0 seconds failed: " + formatUptime(0));
if (formatUptime(65) !== "0d 0h 1m") throw new Error("65 seconds failed: " + formatUptime(65));
if (formatUptime(3665) !== "0d 1h 1m") throw new Error("3665 seconds failed: " + formatUptime(3665));
if (formatUptime(90065) !== "1d 1h 1m") throw new Error("90065 seconds failed: " + formatUptime(90065));
if (formatUptime(-100) !== "0d 0h 0m") throw new Error("Negative seconds failed: " + formatUptime(-100));

const parseUptime = extractFunction(qml, "_parseUptime");
const mockUptimeRaw = "1211.13 18348.99";
// 1211s = 20 mins, 11 secs -> 0d 0h 20m
const parsed = parseUptime.call({ formatUptime }, mockUptimeRaw);
if (parsed !== "0d 0h 20m") throw new Error("parseUptime failed: " + parsed);
' || assert_eq "0" "1" "TargetProfilerWidget uptime formatting failed unit test"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R5.05: OS Release Parser (PRETTY_NAME extraction)
# ------------------------------------------------------------------------------
test_case "R5.05" "Target Profiler: OS release parser extracts PRETTY_NAME from os-release"
if [[ -f "${WIDGET_FILE}" ]]; then
    node -e '
const fs = require("fs");
const qml = fs.readFileSync("'"${WIDGET_FILE}"'", "utf8");

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
    return new Function(...params, source.substring(startIndex, i - 1));
}

const parseOs = extractFunction(qml, "_parseOsRelease");
const sample1 = `
NAME="NixOS"
ID=nixos
VERSION="26.11 (Zokor)"
PRETTY_NAME="NixOS 26.11 (Zokor)"
`;
if (parseOs(sample1) !== "NixOS 26.11 (Zokor)") throw new Error("PRETTY_NAME failed: " + parseOs(sample1));

const sample2 = `
NAME=LinuxGeneric
ID=linux
`;
if (parseOs(sample2) !== "LinuxGeneric") throw new Error("NAME fallback failed: " + parseOs(sample2));
' || assert_eq "0" "1" "TargetProfilerWidget _parseOsRelease failed unit test"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R5.06: Watch Dogs NPC Profiler UI: Reticle Header & CornerBrackets
# ------------------------------------------------------------------------------
test_case "R5.06" "Target Profiler: Boxed HUD layout with reticle icon, PROFILED badge & CornerBrackets"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "CornerBrackets" "${WIDGET_FILE}" "Must embed CornerBrackets framing"
    assert_grep "Theme\.fontFamilyMonospace" "${WIDGET_FILE}" "Must use monospace typography"
    assert_grep "(⌖|TARGET PROFILER)" "${WIDGET_FILE}" "Must render reticle or TARGET PROFILER title"
    assert_grep "PROFILED" "${WIDGET_FILE}" "Must render [PROFILED] status badge"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R5.07: Decorative Barcode & Geometric Accent
# ------------------------------------------------------------------------------
test_case "R5.07" "Target Profiler: Renders decorative barcode accent and system code"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "barcode" "${WIDGET_FILE}" -i "Widget must include barcode graphic or accent"
    assert_grep "Repeater" "${WIDGET_FILE}" "Widget must use Repeater for barcode strip rendering"
else
    assert_file_exists "${WIDGET_FILE}"
fi

report_summary
