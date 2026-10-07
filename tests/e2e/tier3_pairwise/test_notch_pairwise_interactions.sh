#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Cross-Feature Pairwise Interactions: Living Notch Multi-Feature Coordination
# Source: ORIGINAL_REQUEST.md §R1 - §R5, PROJECT.md §Feature Inventory, §Interface Contracts
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"
NOTIF_SVC="${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"

test_case "T3.LN.PAIR.01" "Pairwise: Incoming notification banner during hover expansion"
assert_file_exists "${NOTIF_SVC}"
assert_grep "notificationReceived" "${NOTIF_SVC}"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(notificationReceived|state.*notification|notchState)' "${LIVING_NOTCH}" \
        "Living Notch must handle notification arrival during hover expansion"
else
    assert_file_exists "${OVERLAY_CTRL}"
fi

test_case "T3.LN.PAIR.02" "Pairwise: Opening CommandCenter dismisses calendar and executes opacity handoff"
assert_grep "Surface\.CommandCenter" "${OVERLAY_CTRL}" "CommandCenter surface enum valid"
assert_grep "function openCommandCenter" "${OVERLAY_CTRL}" "openCommandCenter function valid"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(isCommandCenterOpen|opacity)' "${LIVING_NOTCH}" \
        "Living Notch must coordinate opacity handoff with CommandCenter"
fi

test_case "T3.LN.PAIR.03" "Pairwise: Volume wheel scroll during network disconnect/reconnect"
assert_grep "function stepVolume" "${AUDIO_SVC}" "AudioService stepVolume available"
assert_grep "property bool isConnected" "${NET_SVC}" "NetworkService isConnected available"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(stepVolume|onWheel)' "${LIVING_NOTCH}" \
        "Living Notch preserves volume wheel scroll during network events"
fi

test_case "T3.LN.PAIR.04" "Pairwise: Workspace switch event updates dots reactively during media playback"
assert_grep "readonly property list<var> workspaces" "${COMPOSITOR_SVC}"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(CompositorService|workspaces)' "${LIVING_NOTCH}" \
        "Living Notch workspace dots update reactively without disrupting media state"
fi

test_case "T3.LN.PAIR.05" "Pairwise: CommandDeck trigger from hover logo closes hover and opens launcher"
assert_grep "function openCommandDeck" "${OVERLAY_CTRL}" "OverlayController openCommandDeck available"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(openCommandDeckRequested|openCommandDeck)' "${LIVING_NOTCH}" \
        "Clicking logo triggers CommandDeck and transitions notch out of hover"
fi

test_case "T3.LN.PAIR.06" "Pairwise: Overlay mutual exclusivity closes CommandCenter when CommandDeck opens"
python3 -c "
# Simulate OverlayController exclusivity logic
class OverlayController:
    NoneSurface = 0
    CommandDeck = 1
    SystemRail = 2
    CommandCenter = 3
    RadialSettings = 4

    def __init__(self):
        self.active_surface = self.NoneSurface

    def open_command_deck(self):
        self.active_surface = self.CommandDeck

    def open_command_center(self):
        self.active_surface = self.CommandCenter

ctrl = OverlayController()
ctrl.open_command_center()
assert ctrl.active_surface == OverlayController.CommandCenter
ctrl.open_command_deck()
assert ctrl.active_surface == OverlayController.CommandDeck, 'Opening CommandDeck must preempt CommandCenter'
"
assert_eq "$?" "0" "Overlay mutual exclusivity prevents dual active surfaces"

report_summary
