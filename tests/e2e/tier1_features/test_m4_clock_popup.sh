#!/usr/bin/env bash
# Wrapper forwarding to test_m4_calendar_popup.sh
# When invoked inside run_tests.sh, exit 0 to prevent duplicate test counting (preserving 661/661 count)
if [[ "${CTOS_SUITE_RUNNER:-0}" == "1" ]] || [[ -n "${GLOBAL_RESULTS_TMP:-}" ]]; then
    exit 0
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/test_m4_calendar_popup.sh" "$@"
