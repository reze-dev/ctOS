#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone T7: Cyberpunk Telemetry Widgets E2E Test Suite
# Source: ORIGINAL_REQUEST §R1-§R7, PROJECT.md, vision.md, engineering-guidelines.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SERVICES_DIR="${DESKTOP_DIR}/services"
WIDGETS_DIR="${DESKTOP_DIR}/surfaces/widgets"
CORE_DIR="${DESKTOP_DIR}/core"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

SVC_FILE="${SERVICES_DIR}/SystemMonitorService.qml"
SVC_QMLDIR="${SERVICES_DIR}/qmldir"

WIDGETS_QMLDIR="${WIDGETS_DIR}/qmldir"
HEX_FILE="${WIDGETS_DIR}/CpuHexGrid.qml"
NET_FLOW_FILE="${WIDGETS_DIR}/NetworkFlowMatrix.qml"
RAM_BAR_FILE="${WIDGETS_DIR}/RamBlockBar.qml"
GLITCH_FILE="${WIDGETS_DIR}/AmbientGlitch.qml"
BRACKETS_FILE="${WIDGETS_DIR}/CornerBrackets.qml"

ACTION_FILE="${CORE_DIR}/ActionRegistry.qml"
SETTINGS_FILE="${CORE_DIR}/Settings.qml"
THEME_FILE="${CORE_DIR}/Theme.qml"

# ==============================================================================
# Section 1: T7.01 - SystemMonitorService Contract & Virtual Procfs Telemetry
# ==============================================================================

test_case "T7.01.1" "SystemMonitorService: SystemMonitorService.qml exists and is registered as singleton in services/qmldir"
assert_file_exists "${SVC_FILE}" "SystemMonitorService.qml must exist in services/"
assert_file_exists "${SVC_QMLDIR}" "services/qmldir must exist"
assert_grep "singleton SystemMonitorService 1.0 SystemMonitorService.qml" "${SVC_QMLDIR}" "SystemMonitorService must be declared as singleton in services/qmldir"

test_case "T7.01.2" "SystemMonitorService: Property contract declared with typed defaults"
if [[ -f "${SVC_FILE}" ]]; then
    assert_qml_property "${SVC_FILE}" "available" --type bool
    assert_qml_property "${SVC_FILE}" "cpuThreadLoads" --type "list<real>"
    assert_qml_property "${SVC_FILE}" "cpuTotal" --type real
    assert_qml_property "${SVC_FILE}" "memUsedBytes" --type real
    assert_qml_property "${SVC_FILE}" "memTotalBytes" --type real
    assert_qml_property "${SVC_FILE}" "swapUsedBytes" --type real
    assert_qml_property "${SVC_FILE}" "swapTotalBytes" --type real
    assert_qml_property "${SVC_FILE}" "netRxBytesPerSec" --type real
    assert_qml_property "${SVC_FILE}" "netTxBytesPerSec" --type real
    assert_qml_property "${SVC_FILE}" "refreshInterval" --type int
else
    assert_file_exists "${SVC_FILE}"
fi

test_case "T7.01.3" "SystemMonitorService: Reactive telemetry signals contract declared"
if [[ -f "${SVC_FILE}" ]]; then
    assert_qml_signal "${SVC_FILE}" "telemetryUpdated"
    assert_qml_signal "${SVC_FILE}" "cpuTelemetryUpdated"
    assert_qml_signal "${SVC_FILE}" "memoryTelemetryUpdated"
    assert_qml_signal "${SVC_FILE}" "networkTelemetryUpdated"
else
    assert_file_exists "${SVC_FILE}"
fi

test_case "T7.01.4" "SystemMonitorService: Public methods refresh() and formatBytes() declared"
if [[ -f "${SVC_FILE}" ]]; then
    assert_qml_method "${SVC_FILE}" "refresh"
    assert_qml_method "${SVC_FILE}" "formatBytes"
else
    assert_file_exists "${SVC_FILE}"
fi

test_case "T7.01.5" "SystemMonitorService: Procfs FileViews and discrete Timer read mechanism"
if [[ -f "${SVC_FILE}" ]]; then
    assert_grep 'path:\s*"/proc/stat"' "${SVC_FILE}" "Service must inspect /proc/stat via FileView"
    assert_grep 'path:\s*"/proc/meminfo"' "${SVC_FILE}" "Service must inspect /proc/meminfo via FileView"
    assert_grep 'path:\s*"/proc/net/dev"' "${SVC_FILE}" "Service must inspect /proc/net/dev via FileView"
    assert_grep 'interval:\s*root\.refreshInterval' "${SVC_FILE}" "Timer must bind to refreshInterval"
    assert_grep 'onTriggered:\s*root\.refresh\(\)' "${SVC_FILE}" "Timer must discretely invoke root.refresh()"
    assert_not_grep "Process\s*\{[^}]*running\s*:\s*true" "${SVC_FILE}" "Service must not use persistent Process polling"
else
    assert_file_exists "${SVC_FILE}"
fi

test_case "T7.01.6" "SystemMonitorService: Procfs parsing algorithms and byte formatting unit correctness"
run_qml_test_harness "${HARNESS_DIR}/test_system_monitor_quickshell_adversarial.qml" "SystemMonitorService live runtime harness"

SVC_FILE="${SVC_FILE}" node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.env.SVC_FILE, "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    if (!match) throw new Error("Function " + fnName + " not found in " + process.env.SVC_FILE);
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    if (braceCount !== 0) throw new Error("Unmatched braces for " + fnName);
    return new Function(...params, source.substring(startIndex, i - 1));
}

const formatBytes = extractFunction(qml, "formatBytes");
if (formatBytes(0) !== "0 B") throw new Error("0 B failed");
if (formatBytes(512) !== "512 B") throw new Error("512 B failed");
if (formatBytes(2048) !== "2.0 KB") throw new Error("2.0 KB failed");
if (formatBytes(12.4 * 1048576) !== "12.4 MB") throw new Error("12.4 MB failed");
if (formatBytes(16.0 * 1073741824) !== "16.0 GB") throw new Error("16.0 GB failed");
' || assert_eq "0" "1" "SystemMonitorService formatBytes failed verification against source file"

# ==============================================================================
# Section 2: T7.02 - CpuHexGrid Honeycomb Layout, 1..128 Cores & 5 Visual States
# ==============================================================================

test_case "T7.02.1" "CpuHexGrid: Component and CornerBrackets exist and are registered in widgets/qmldir"
assert_file_exists "${HEX_FILE}" "CpuHexGrid.qml must exist in widgets/"
assert_file_exists "${BRACKETS_FILE}" "CornerBrackets.qml must exist in widgets/"
assert_file_exists "${WIDGETS_QMLDIR}" "widgets/qmldir must exist"
assert_grep "CpuHexGrid 1.0 CpuHexGrid.qml" "${WIDGETS_QMLDIR}" "CpuHexGrid must be exported in widgets/qmldir"
assert_grep "CornerBrackets 1.0 CornerBrackets.qml" "${WIDGETS_QMLDIR}" "CornerBrackets must be exported in widgets/qmldir"

test_case "T7.02.2" "CornerBrackets: Cyberpunk 8-rectangle framing adhering to Theme tokens"
if [[ -f "${BRACKETS_FILE}" ]]; then
    assert_qml_property "${BRACKETS_FILE}" "bracketColor" --type color
    assert_qml_property "${BRACKETS_FILE}" "armLength" --type int
    assert_qml_property "${BRACKETS_FILE}" "thickness" --type int
    assert_qml_property "${BRACKETS_FILE}" "margin" --type int
    assert_grep "Theme\.cornerBracketArmLength" "${BRACKETS_FILE}" "CornerBrackets must reference Theme.cornerBracketArmLength"
    assert_grep "Theme\.cornerBracketThickness" "${BRACKETS_FILE}" "CornerBrackets must reference Theme.cornerBracketThickness"
    assert_grep "Theme\.cornerBracketMargin" "${BRACKETS_FILE}" "CornerBrackets must reference Theme.cornerBracketMargin"
    rect_count=$(grep -c "Rectangle\s*{" "${BRACKETS_FILE}" || true)
    [[ "${rect_count}" -ge 8 ]] || assert_eq "8" "${rect_count}" "CornerBrackets must define 8 bracket rectangles"
else
    assert_file_exists "${BRACKETS_FILE}"
fi

test_case "T7.02.3" "CpuHexGrid: Monospace typography, CornerBrackets framing and aggregate CPU label"
if [[ -f "${HEX_FILE}" ]]; then
    assert_grep 'font\.family:\s*Theme\.fontFamilyMonospace' "${HEX_FILE}" "CpuHexGrid must use monospace font"
    assert_grep '"CPU "\s*\+\s*Math\.round\(root\.cpuTotal\s*\*\s*100\)\s*\+\s*"%"' "${HEX_FILE}" "CpuHexGrid must format CPU aggregate percentage"
    assert_grep 'CornerBrackets\s*\{' "${HEX_FILE}" "CpuHexGrid must embed CornerBrackets framing"
else
    assert_file_exists "${HEX_FILE}"
fi

test_case "T7.02.4" "CpuHexGrid: solveLayout dynamic honeycomb calculation bounds across 1..128 cores"
run_qml_test_harness "${HARNESS_DIR}/test_milestone2_quickshell_adversarial.qml" "CpuHexGrid solveLayout live runtime harness"

HEX_FILE="${HEX_FILE}" node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.env.HEX_FILE, "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    if (!match) throw new Error("Function " + fnName + " not found in " + process.env.HEX_FILE);
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    if (braceCount !== 0) throw new Error("Unmatched braces for " + fnName);
    return new Function(...params, source.substring(startIndex, i - 1));
}

const solveLayout = extractFunction(qml, "solveLayout");
const testCores = [1, 2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128];
for (const cores of testCores) {
    const layout = solveLayout(cores, 280, 150);
    if (layout.cols * layout.rows < cores) throw new Error(`Insufficient hex capacity for ${cores} cores`);
    if (layout.r < 4.0) throw new Error(`Radius below minimum legible 4.0px for ${cores} cores`);
    if (layout.wUsed > 281 || layout.hUsed > 151) throw new Error(`Layout exceeded canvas bounds for ${cores} cores`);
}
' || assert_eq "0" "1" "CpuHexGrid solveLayout failed dynamic core bounds validation against source file"

test_case "T7.02.5" "CpuHexGrid: 5-state load visual styling and thresholds encoded in Canvas render"
if [[ -f "${HEX_FILE}" ]]; then
    # State 1: Idle (< 5%) -> dim outline #202020
    assert_grep '#202020' "${HEX_FILE}" "Idle state must use dim outline"
    # State 2: Light (5% - 40%) -> faint acidGreen fill
    assert_grep 'load\s*>=\s*0\.05' "${HEX_FILE}" "Light state threshold (0.05) must be declared"
    # State 3: Medium (40% - 80%) -> bright acidGreen fill
    assert_grep 'load\s*>=\s*0\.40' "${HEX_FILE}" "Medium state threshold (0.40) must be declared"
    # State 4: Heavy (> 80%) -> pulsing acidGreen
    assert_grep 'load\s*>=\s*0\.80' "${HEX_FILE}" "Heavy state threshold (0.80) must be declared"
    assert_grep 'pulseAlpha' "${HEX_FILE}" "Heavy state must modulate pulseAlpha"
    # State 5: Maxed (100% / >= 99%) -> destructive flicker red (#FC3E38 / #801010)
    assert_grep 'load\s*>=\s*0\.99' "${HEX_FILE}" "Maxed state threshold (0.99) must be declared"
    assert_grep '#FC3E38' "${HEX_FILE}" "Maxed state must use destructive red flicker"
else
    assert_file_exists "${HEX_FILE}"
fi

test_case "T7.02.6" "CpuHexGrid: Overload styling (>= 90%) and motion safety suppression"
if [[ -f "${HEX_FILE}" ]]; then
    assert_grep 'isOverload:\s*root\.cpuTotal\s*>=\s*0\.90' "${HEX_FILE}" "Overload state must trigger when cpuTotal >= 0.90"
    assert_grep 'root\.isOverload\s*\?\s*Theme\.destructive\s*:\s*Theme\.acidGreen' "${HEX_FILE}" "Brackets must turn destructive on overload"
    assert_grep '!Settings\.reducedMotion\s*&&\s*root\.hasHeavyThreads' "${HEX_FILE}" "Pulse animation must disable on Settings.reducedMotion"
    assert_grep '!Settings\.reducedMotion\s*&&\s*root\.hasMaxedThreads' "${HEX_FILE}" "Flicker animation must disable on Settings.reducedMotion"
else
    assert_file_exists "${HEX_FILE}"
fi

# ==============================================================================
# Section 3: T7.03 - NetworkFlowMatrix Real-Time Scrolling Wireframe Graph
# ==============================================================================

test_case "T7.03.1" "NetworkFlowMatrix: Component exists and is registered in widgets/qmldir"
assert_file_exists "${NET_FLOW_FILE}" "NetworkFlowMatrix.qml must exist in widgets/"
assert_grep "NetworkFlowMatrix 1.0 NetworkFlowMatrix.qml" "${WIDGETS_QMLDIR}" "NetworkFlowMatrix must be declared in widgets/qmldir"

test_case "T7.03.2" "NetworkFlowMatrix: 30-sample ring buffer and auto-scaling minimum ceiling floor"
if [[ -f "${NET_FLOW_FILE}" ]]; then
    assert_qml_property "${NET_FLOW_FILE}" "maxSamples" --type int
    assert_qml_property "${NET_FLOW_FILE}" "minCeilingBytesPerSec" --type real
    assert_grep 'maxSamples:\s*30' "${NET_FLOW_FILE}" "Ring buffer must store exactly 30 samples"
    assert_grep 'minCeilingBytesPerSec:\s*65536' "${NET_FLOW_FILE}" "Minimum ceiling floor must be 65536.0 (64 KB/s)"
    assert_grep 'shift\(\)' "${NET_FLOW_FILE}" "pushSample must shift oldest entries when exceeding maxSamples"
else
    assert_file_exists "${NET_FLOW_FILE}"
fi

test_case "T7.03.3" "NetworkFlowMatrix: Dual line styling (RX acidGreen, TX gray300) and wireframe grid (gray700)"
if [[ -f "${NET_FLOW_FILE}" ]]; then
    assert_grep 'Theme\.acidGreen|#1BFD9C' "${NET_FLOW_FILE}" "RX line must use acidGreen accent"
    assert_grep 'Theme\.gray300|#C3C3C3' "${NET_FLOW_FILE}" "TX line must use gray300"
    assert_grep 'Theme\.gray700|#202020' "${NET_FLOW_FILE}" "Wireframe grid lines must use gray700"
    assert_grep 'CornerBrackets\s*\{' "${NET_FLOW_FILE}" "NetworkFlowMatrix must embed CornerBrackets framing"
else
    assert_file_exists "${NET_FLOW_FILE}"
fi

test_case "T7.03.4" "NetworkFlowMatrix: Terse monospace speed labels with arrows"
if [[ -f "${NET_FLOW_FILE}" ]]; then
    assert_grep 'font\.family:\s*Theme\.fontFamilyMonospace' "${NET_FLOW_FILE}" "Labels must use monospace font"
    assert_grep '↓' "${NET_FLOW_FILE}" "RX speed label must include down arrow"
    assert_grep '↑' "${NET_FLOW_FILE}" "TX speed label must include up arrow"
else
    assert_file_exists "${NET_FLOW_FILE}"
fi

test_case "T7.03.5" "NetworkFlowMatrix: Rate formatting helper unit scaling verification"
run_qml_test_harness "${HARNESS_DIR}/test_network_and_glitch_quickshell.qml" "NetworkFlowMatrix live runtime harness"

NET_FLOW_FILE="${NET_FLOW_FILE}" node -e '
const fs = require("fs");
const qml = fs.readFileSync(process.env.NET_FLOW_FILE, "utf8");

function extractFunction(source, fnName) {
    const fnDecl = new RegExp("function\\s+" + fnName + "\\s*\\(([^)]*)\\)[^{]*\\{");
    const match = source.match(fnDecl);
    if (!match) throw new Error("Function " + fnName + " not found in " + process.env.NET_FLOW_FILE);
    const startIndex = match.index + match[0].length;
    const params = match[1].replace(/:\s*[\w<>]+/g, "").split(",").map(s => s.trim()).filter(Boolean);
    let braceCount = 1, i = startIndex;
    while (i < source.length && braceCount > 0) {
        if (source[i] === "{") braceCount++;
        else if (source[i] === "}") braceCount--;
        i++;
    }
    if (braceCount !== 0) throw new Error("Unmatched braces for " + fnName);
    return new Function(...params, source.substring(startIndex, i - 1));
}

const formatRate = extractFunction(qml, "formatRate");
if (formatRate(0) !== "0 B/s") throw new Error("0 B/s rate failed");
if (formatRate(500) !== "500 B/s") throw new Error("500 B/s rate failed");
if (formatRate(1536) !== "1.5 KB/s") throw new Error("1.5 KB/s rate failed");
if (formatRate(1048576 * 12.4) !== "12.4 MB/s") throw new Error("12.4 MB/s rate failed");
if (formatRate(1073741824 * 1.2) !== "1.2 GB/s") throw new Error("1.2 GB/s rate failed");
' || assert_eq "0" "1" "NetworkFlowMatrix formatRate failed unit scaling validation against source file"

# ==============================================================================
# Section 4: T7.04 - RamBlockBar 20-Segment Progress & Critical Threshold
# ==============================================================================

test_case "T7.04.1" "RamBlockBar: Component exists and is registered in widgets/qmldir"
assert_file_exists "${RAM_BAR_FILE}" "RamBlockBar.qml must exist in widgets/"
assert_grep "RamBlockBar 1.0 RamBlockBar.qml" "${WIDGETS_QMLDIR}" "RamBlockBar must be declared in widgets/qmldir"

test_case "T7.04.2" "RamBlockBar: 20-segment chunky progress bar (~5% per block) and memory ratio calculation"
if [[ -f "${RAM_BAR_FILE}" ]]; then
    assert_qml_property "${RAM_BAR_FILE}" "totalBlocks" --type int
    assert_qml_property "${RAM_BAR_FILE}" "filledRamBlocks" --type int
    assert_grep 'totalBlocks:\s*20' "${RAM_BAR_FILE}" "Progress bar must define exactly 20 blocks"
    assert_grep 'SystemMonitorService\.memUsedBytes\s*/\s*SystemMonitorService\.memTotalBytes' "${RAM_BAR_FILE}" "Memory ratio must divide used by total bytes"
    assert_grep 'Repeater\s*\{' "${RAM_BAR_FILE}" "Chunky blocks must be rendered via Repeater"
else
    assert_file_exists "${RAM_BAR_FILE}"
fi

test_case "T7.04.3" "RamBlockBar: Critical threshold transition to Theme.destructive at >= 80%"
if [[ -f "${RAM_BAR_FILE}" ]]; then
    assert_qml_property "${RAM_BAR_FILE}" "isCritical" --type bool
    assert_grep 'isCritical:\s*root\.memRatio\s*>=\s*0\.80' "${RAM_BAR_FILE}" "Critical threshold must trigger at 80% RAM utilization"
    assert_grep 'root\.isCritical\s*\?\s*Theme\.destructive\s*:\s*Theme\.acidGreen' "${RAM_BAR_FILE}" "Filled blocks must turn destructive red when >= 80%"
    assert_grep 'CornerBrackets\s*\{' "${RAM_BAR_FILE}" "RamBlockBar must embed CornerBrackets framing"
    assert_grep 'bracketColor:\s*root\.isCritical\s*\?\s*Theme\.destructive\s*:\s*Theme\.acidGreen' "${RAM_BAR_FILE}" "CornerBrackets must transition to destructive red when >= 80%"
else
    assert_file_exists "${RAM_BAR_FILE}"
fi

test_case "T7.04.4" "RamBlockBar: Secondary swap segmented bar and monospace labels"
if [[ -f "${RAM_BAR_FILE}" ]]; then
    assert_qml_property "${RAM_BAR_FILE}" "hasSwap" --type bool
    assert_qml_property "${RAM_BAR_FILE}" "filledSwapBlocks" --type int
    assert_grep 'SystemMonitorService\.swapUsedBytes\s*/\s*SystemMonitorService\.swapTotalBytes' "${RAM_BAR_FILE}" "Swap ratio must divide swap used by swap total"
    assert_grep '"RAM "\s*\+\s*root\.formatGB\(SystemMonitorService\.memUsedBytes\)' "${RAM_BAR_FILE}" "Label must display RAM X.X / Y.Y GB"
    assert_grep '"SWP "' "${RAM_BAR_FILE}" "Secondary swap section must declare SWP label"
else
    assert_file_exists "${RAM_BAR_FILE}"
fi

# ==============================================================================
# Section 5: T7.05 - AmbientGlitch Bounded Visual Distortion & Motion Safety
# ==============================================================================

test_case "T7.05.1" "AmbientGlitch: Component exists and is registered in widgets/qmldir"
assert_file_exists "${GLITCH_FILE}" "AmbientGlitch.qml must exist in widgets/"
assert_grep "AmbientGlitch 1.0 AmbientGlitch.qml" "${WIDGETS_QMLDIR}" "AmbientGlitch must be declared in widgets/qmldir"

test_case "T7.05.2" "AmbientGlitch: Strictly bounded distortion duration (<= 160ms, non-persistent)"
if [[ -f "${GLITCH_FILE}" ]]; then
    assert_qml_property "${GLITCH_FILE}" "maxGlitchDuration" --type int
    assert_qml_property "${GLITCH_FILE}" "maxChromaDuration" --type int
    assert_grep 'maxGlitchDuration:\s*130' "${GLITCH_FILE}" "Max glitch duration must be <= 160ms (130ms)"
    assert_grep 'maxChromaDuration:\s*120' "${GLITCH_FILE}" "Max chroma duration must be <= 160ms (120ms)"
    assert_grep 'loops:\s*1' "${GLITCH_FILE}" "Glitch animation sequences must execute only once per trigger (loops: 1)"
    assert_grep 'running:\s*false' "${GLITCH_FILE}" "Glitch animations must default to running: false"
    assert_not_grep 'Animation\.Infinite' "${GLITCH_FILE}" "AmbientGlitch must not contain infinite animation loops"
else
    assert_file_exists "${GLITCH_FILE}"
fi

test_case "T7.05.3" "AmbientGlitch: Contextual triggers for CPU spikes (> 90%) and network state changes"
if [[ -f "${GLITCH_FILE}" ]]; then
    assert_grep 'cpuThreshold:\s*0\.90' "${GLITCH_FILE}" "CPU distortion threshold must be 90%"
    assert_grep 'onCpuTelemetryUpdated' "${GLITCH_FILE}" "Glitch must react to CPU telemetry updates"
    assert_grep 'onNetworkTelemetryUpdated' "${GLITCH_FILE}" "Glitch must react to network throughput shifts"
    assert_grep 'onNetworkStateChanged' "${GLITCH_FILE}" "Glitch must react to network connection state changes"
    assert_grep 'triggerCpuGlitch' "${GLITCH_FILE}" "Glitch must expose triggerCpuGlitch method"
    assert_grep 'triggerChromaticFlash' "${GLITCH_FILE}" "Glitch must expose triggerChromaticFlash method"
else
    assert_file_exists "${GLITCH_FILE}"
fi

test_case "T7.05.4" "AmbientGlitch: Motion safety suppression when Settings.reducedMotion is active"
if [[ -f "${GLITCH_FILE}" ]]; then
    assert_grep 'reducedMotionActive:\s*Settings\.reducedMotion' "${GLITCH_FILE}" "Glitch must bind to Settings.reducedMotion"
    python3 -c '
import re, sys
content = open(sys.argv[1], encoding="utf-8").read()
if not re.search(r"triggerCpuGlitch.*?if\s*\(root\.reducedMotionActive\)\s*\{\s*return;\s*\}", content, re.DOTALL):
    sys.exit(1)
if not re.search(r"triggerChromaticFlash.*?if\s*\(root\.reducedMotionActive\)\s*\{\s*return;\s*\}", content, re.DOTALL):
    sys.exit(1)
' "${GLITCH_FILE}" || assert_eq "0" "1" "Trigger methods must abort immediately when reducedMotion is active"
    assert_grep 'function\s+stop\(\)' "${GLITCH_FILE}" "stop() method must reset displacement offsets to zero"
else
    assert_file_exists "${GLITCH_FILE}"
fi

# ==============================================================================
# Section 6: T7.06 - Shell Hosting Integration in shell/shell.qml
# ==============================================================================

test_case "T7.06.1" "Shell Hosting: shell.qml hosts Variants over Quickshell.screens for all three widgets"
assert_file_exists "${SHELL_FILE}" "shell.qml must exist"
assert_grep 'cpuHexGridVariants' "${SHELL_FILE}" "shell.qml must host cpuHexGridVariants"
assert_grep 'ramBlockBarVariants' "${SHELL_FILE}" "shell.qml must host ramBlockBarVariants"
assert_grep 'networkFlowVariants' "${SHELL_FILE}" "shell.qml must host networkFlowVariants"
assert_grep 'model:\s*Quickshell\.screens' "${SHELL_FILE}" "Widgets must instantiate across Quickshell.screens"

test_case "T7.06.2" "Shell Hosting: Wayland bottom layer shell contract (WlrLayer.Bottom, WlrKeyboardFocus.None, ExclusionMode.Ignore)"
if [[ -f "${SHELL_FILE}" ]]; then
    assert_grep 'WlrLayershell\.layer:\s*WlrLayer\.Bottom' "${SHELL_FILE}" "Widgets must be hosted on WlrLayer.Bottom"
    assert_grep 'WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None' "${SHELL_FILE}" "Widgets must never steal keyboard focus"
    assert_grep 'exclusionMode:\s*ExclusionMode\.Ignore' "${SHELL_FILE}" "Widgets must ignore exclusion mode"
    assert_grep 'color:\s*"transparent"' "${SHELL_FILE}" "Widget panel windows must be transparent"
    assert_grep 'WlrLayershell\.namespace:\s*"ctos-widgets"' "${SHELL_FILE}" "Widgets must set ctos-widgets namespace"
else
    assert_file_exists "${SHELL_FILE}"
fi

test_case "T7.06.3" "Shell Hosting: Dynamic vertical top margins avoiding widget overlaps"
if [[ -f "${SHELL_FILE}" ]]; then
    python3 -c '
import re, sys
content = open(sys.argv[1], encoding="utf-8").read()
if not re.search(r"top:\s*Settings\.widgetCpuHexGridVisible\s*\?\s*\(Theme\.barHeight", content, re.DOTALL):
    sys.exit(1)
if not re.search(r"id:\s*networkFlowWindow.*?anchors\s*\{\s*bottom:\s*true\s*right:\s*true\s*\}", content, re.DOTALL):
    sys.exit(1)
' "${SHELL_FILE}" || assert_eq "0" "1" "Widget positioning and dynamic top margin failed verification"
else
    assert_file_exists "${SHELL_FILE}"
fi

# ==============================================================================
# Section 7: T7.07 - ActionRegistry Toggle Actions Discovery
# ==============================================================================

test_case "T7.07.1" "ActionRegistry: Declares 4 telemetry toggle actions (cpu-hex, network-flow, ram-block, all-widgets)"
assert_file_exists "${ACTION_FILE}" "ActionRegistry.qml must exist in desktop/core/"
assert_grep '"action-toggle-cpu-hex"' "${ACTION_FILE}" "action-toggle-cpu-hex must be declared in ActionRegistry"
assert_grep '"action-toggle-network-flow"' "${ACTION_FILE}" "action-toggle-network-flow must be declared in ActionRegistry"
assert_grep '"action-toggle-ram-block"' "${ACTION_FILE}" "action-toggle-ram-block must be declared in ActionRegistry"
assert_grep '"action-toggle-all-widgets"' "${ACTION_FILE}" "action-toggle-all-widgets must be declared in ActionRegistry"

test_case "T7.07.2" "ActionRegistry: Actions declare complete metadata (name, description, keywords, icon)"
if [[ -f "${ACTION_FILE}" ]]; then
    assert_grep '"Toggle CPU Hex-Grid"' "${ACTION_FILE}" "CPU hex action must have human title"
    assert_grep '"Toggle Network Flow Matrix"' "${ACTION_FILE}" "Network flow action must have human title"
    assert_grep '"Toggle RAM Block Bar"' "${ACTION_FILE}" "RAM block action must have human title"
    assert_grep '"Toggle All Desktop Widgets"' "${ACTION_FILE}" "All widgets action must have human title"
    assert_grep 'keywords:\s*\[[^]]*cpu[^]]*\]' "${ACTION_FILE}" "CPU hex action must include keywords"
    assert_grep 'keywords:\s*\[[^]]*network[^]]*\]' "${ACTION_FILE}" "Network action must include keywords"
    assert_grep 'keywords:\s*\[[^]]*ram[^]]*\]' "${ACTION_FILE}" "RAM action must include keywords"
else
    assert_file_exists "${ACTION_FILE}"
fi

test_case "T7.07.3" "ActionRegistry: Telemetry actions discoverable via Command Deck search queries"
run_qml_test_harness "${HARNESS_DIR}/test_milestone3_quickshell.qml" "ActionRegistry search & toggle actions runtime harness"

test_case "T7.07.4" "ActionRegistry: Action execution toggles Settings properties and invokes Settings.save()"
if [[ -f "${ACTION_FILE}" ]]; then
    assert_grep 'Settings\.widgetCpuHexGridVisible\s*=\s*!Settings\.widgetCpuHexGridVisible' "${ACTION_FILE}" "CPU action must toggle Settings.widgetCpuHexGridVisible"
    assert_grep 'Settings\.widgetNetworkFlowVisible\s*=\s*!Settings\.widgetNetworkFlowVisible' "${ACTION_FILE}" "Network action must toggle Settings.widgetNetworkFlowVisible"
    assert_grep 'Settings\.widgetRamBlockBarVisible\s*=\s*!Settings\.widgetRamBlockBarVisible' "${ACTION_FILE}" "RAM action must toggle Settings.widgetRamBlockBarVisible"
    assert_grep 'Settings\.save\(\)' "${ACTION_FILE}" "All toggle actions must call Settings.save()"
else
    assert_file_exists "${ACTION_FILE}"
fi

# ==============================================================================
# Section 8: T7.08 - Settings Persistence & Dual-Schema Compatibility
# ==============================================================================

test_case "T7.08.1" "Settings: Widget visibility properties declared with default true values"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_qml_property "${SETTINGS_FILE}" "widgetCpuHexGridVisible" --type bool
    assert_qml_property "${SETTINGS_FILE}" "widgetNetworkFlowVisible" --type bool
    assert_qml_property "${SETTINGS_FILE}" "widgetRamBlockBarVisible" --type bool
    assert_qml_property "${SETTINGS_FILE}" "defaultWidgetCpuHexGridVisible" --type bool --readonly
    assert_qml_property "${SETTINGS_FILE}" "defaultWidgetNetworkFlowVisible" --type bool --readonly
    assert_qml_property "${SETTINGS_FILE}" "defaultWidgetRamBlockBarVisible" --type bool --readonly
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T7.08.2" "Settings: Dual-schema JSON parsing (flat properties schema)"
TMP_FLAT_QML="$(mktemp /tmp/ctos_test_settings_flat_XXXXXX.qml)"
cat << 'EOF' > "${TMP_FLAT_QML}"
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
                widgetCpuHexGridVisible: false,
                widgetNetworkFlowVisible: false,
                widgetRamBlockBarVisible: false
            }));
            if (Settings.widgetCpuHexGridVisible !== false ||
                Settings.widgetNetworkFlowVisible !== false ||
                Settings.widgetRamBlockBarVisible !== false) {
                console.error("ASSERTION_FAILED: flat schema parsing did not set widget visibility to false");
            } else {
                console.log("=== PASS: Settings flat schema parsed successfully ===");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_FLAT_QML}" "Settings flat schema parsing"
rm -f "${TMP_FLAT_QML}"

test_case "T7.08.3" "Settings: Dual-schema JSON parsing (nested widgets.* schema)"
TMP_NESTED_QML="$(mktemp /tmp/ctos_test_settings_nested_XXXXXX.qml)"
cat << 'EOF' > "${TMP_NESTED_QML}"
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
                    cpuHexGridVisible: false,
                    networkFlowVisible: true,
                    ramBlockBarVisible: false
                }
            }));
            if (Settings.widgetCpuHexGridVisible !== false ||
                Settings.widgetNetworkFlowVisible !== true ||
                Settings.widgetRamBlockBarVisible !== false) {
                console.error("ASSERTION_FAILED: nested schema parsing failed to set widget visibility");
            } else {
                console.log("=== PASS: Settings nested schema parsed successfully ===");
            }
            Qt.quit();
        }
    }
}
EOF
run_qml_test_harness "${TMP_NESTED_QML}" "Settings nested schema parsing"
rm -f "${TMP_NESTED_QML}"

test_case "T7.08.4" "Settings: Persistence save method updates FileView with widget configuration"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_grep 'data\.widgetCpuHexGridVisible\s*=\s*root\.widgetCpuHexGridVisible' "${SETTINGS_FILE}" "save() must serialize widgetCpuHexGridVisible"
    assert_grep 'data\.widgetNetworkFlowVisible\s*=\s*root\.widgetNetworkFlowVisible' "${SETTINGS_FILE}" "save() must serialize widgetNetworkFlowVisible"
    assert_grep 'data\.widgetRamBlockBarVisible\s*=\s*root\.widgetRamBlockBarVisible' "${SETTINGS_FILE}" "save() must serialize widgetRamBlockBarVisible"
    assert_grep 'fileView\.setText\(JSON\.stringify\(data' "${SETTINGS_FILE}" "save() must write updated JSON back to fileView"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

test_case "T7.08.5" "Settings: Malformed JSON resilience without calling Qt.quit()"
if [[ -f "${SETTINGS_FILE}" ]]; then
    assert_not_grep 'Qt\.quit\(\)' "${SETTINGS_FILE}" "Settings must never call Qt.quit() on JSON parse error"
    assert_grep 'resetToDefaults\(\)' "${SETTINGS_FILE}" "Settings must revert safely to defaults on parse failure"
else
    assert_file_exists "${SETTINGS_FILE}"
fi

# ==============================================================================
# Section 9: T7.09 - Zero-Polling & Compliance Rules
# ==============================================================================

test_case "T7.09.1" "Zero Polling: Zero persistent Process loops (running: true) in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    check_no_polling_loops "${DESKTOP_DIR}" || assert_eq "0" "1" "Persistent Process loop detected in desktop/"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T7.09.2" "Zero Polling: Zero literal 'running: true' strings anywhere in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "running:\s*true" "${DESKTOP_DIR}" "Literal 'running: true' prohibited in desktop/"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T7.09.3" "Zero Polling: Zero high-frequency polling intervals (< 500ms) in surfaces/"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    assert_not_grep "interval:\s*(100|200|250|300)" "${DESKTOP_DIR}/surfaces" "No high-frequency timers allowed in surfaces/"
else
    assert_dir_exists "${DESKTOP_DIR}/surfaces"
fi

test_case "T7.09.4" "Zero Polling: Zero sleep/watch/poll scripts or persistent subprocesses in services/"
if [[ -d "${SERVICES_DIR}" ]]; then
    assert_not_grep "(sleep|watch|poll)" "${SERVICES_DIR}" "Services must be reactive and event-driven without external poll scripts"
else
    assert_dir_exists "${SERVICES_DIR}"
fi

# ==============================================================================
# Section 10: T7.10 - Greeter Isolation Boundary
# ==============================================================================

test_case "T7.10.1" "Greeter Isolation: Zero greeter imports in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    check_no_greeter_imports "${DESKTOP_DIR}" || assert_eq "0" "1" "desktop/ must never import from greeter/"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T7.10.2" "Greeter Isolation: Zero greeter file or directory references in desktop/"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "/etc/ctos/greeter" "${DESKTOP_DIR}" "desktop/ must never reference greeter configuration paths"
    assert_not_grep -i "greeter" "${WIDGETS_DIR}" "surfaces/widgets/ must contain zero greeter coupling"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T7.10.3" "Greeter Isolation: Zero PAM or authentication symbols in desktop/widgets"
if [[ -d "${WIDGETS_DIR}" ]]; then
    assert_not_grep -i "(pam|greetd|lockd)" "${WIDGETS_DIR}" "Widgets must contain no authentication or PAM handling"
else
    assert_dir_exists "${WIDGETS_DIR}"
fi

# ==============================================================================
# Section 11: T7.11 - Nix Packaging & Flake Checks
# ==============================================================================

test_case "T7.11.1" "Nix Packaging: nix flake check --no-build passes"
assert_exit_code 0 nix flake check --no-build

test_case "T7.11.2" "Nix Packaging: nix build .#ctos-shell --no-link builds cleanly"
assert_exit_code 0 nix build .#ctos-shell --no-link

report_summary
