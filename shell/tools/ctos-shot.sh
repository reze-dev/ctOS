#!/usr/bin/env bash
# ==============================================================================
# ctos-shot.sh - render the ctOS shell in a headless compositor and screenshot it
#
# The shell is wlr-layer-shell only. Qt's offscreen platform cannot present a
# layer surface, so verifying it visually needs a real compositor. This boots
# sway with the headless backend and the pixman software renderer, runs the
# shell inside it, captures the output with grim, and tears everything down.
#
# No GPU, no X server, no seat. Works over SSH and in CI.
#
# Usage:
#   ctos-shot [OUTFILE] [WIDTHxHEIGHT] [SETTLE_SECONDS]
#
# Examples:
#   ctos-shot                          -> /tmp/ctos-shell.png at 1280x800
#   ctos-shot /tmp/hover.png 1280 800 2
#
# Environment:
#   CTOS_SHELL_QML   override the entry point (default: shell/shell.qml)
#   CTOS_KEEP        set to 1 to leave the compositor running for inspection
# ==============================================================================
set -uo pipefail

OUT="${1:-/tmp/ctos-shell.png}"
GEOM="${2:-1280x800}"

# Accept either "1280x800" or "1280 800" for geometry.
if [[ "$GEOM" == *x* ]]; then
    W="${GEOM%x*}"
    H="${GEOM#*x}"
    SETTLE="${3:-5}"
else
    W="$GEOM"
    H="${3:-800}"
    SETTLE="${4:-5}"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENTRY="${CTOS_SHELL_QML:-$REPO_ROOT/shell/shell.qml}"

for bin in sway grim quickshell; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ctos-shot: '$bin' not in PATH. Run inside 'nix develop'." >&2
        exit 127
    fi
done

RUNDIR="$(mktemp -d /tmp/ctos-shot.XXXXXX)"
export XDG_RUNTIME_DIR="$RUNDIR"
export WLR_BACKENDS=headless
# The headless backend creates no outputs unless asked to.
export WLR_HEADLESS_OUTPUTS=1
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1
export LIBGL_ALWAYS_SOFTWARE=1

# The devshell presets QT_QPA_PLATFORM=offscreen for qmllint and qmltestrunner.
# That is fatal here: quickshell needs the real wayland platform to have a
# PanelWindow backend, and it fails with "No PanelWindow backend loaded".
unset QT_QPA_PLATFORM
unset QT_QUICK_BACKEND
export QT_QPA_PLATFORM=wayland

# Keep QML console output; it is the only diagnostic when a surface fails to
# appear in the capture.
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-qt.*=false}"

SWAY_PID=""
QS_PID=""
SWAY_DISPLAY=""

cleanup() {
    if [ "${CTOS_KEEP:-0}" = "1" ]; then
        echo "ctos-shot: CTOS_KEEP=1, compositor left running." >&2
        echo "ctos-shot:   dir=$RUNDIR display=$SWAY_DISPLAY" >&2
        return
    fi
    [ -n "$QS_PID" ] && kill "$QS_PID" 2>/dev/null
    [ -n "$SWAY_PID" ] && kill "$SWAY_PID" 2>/dev/null
    sleep 0.3
    pkill -f "sway.*$RUNDIR" 2>/dev/null
    rm -rf "$RUNDIR"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Minimal sway config. One headless output at the requested size.
# ------------------------------------------------------------------------------
cat > "$RUNDIR/sway.conf" <<EOF
# No bar, no gaps, no keybindings: this compositor exists only to host
# layer-shell surfaces.
output * resolution ${W}x${H} position 0 0
default_border none
focus_follows_mouse no
EOF

echo "ctos-shot: booting sway (headless, pixman) at ${W}x${H} ..." >&2
sway -c "$RUNDIR/sway.conf" > "$RUNDIR/sway.log" 2>&1 &
SWAY_PID=$!

# Wait for the socket rather than sleeping a fixed amount.
for _ in $(seq 1 60); do
    SWAY_DISPLAY="$(find "$RUNDIR" -maxdepth 1 -name 'wayland-*' -type s -printf '%f\n' 2>/dev/null | head -1)"
    [ -n "$SWAY_DISPLAY" ] && break
    if ! kill -0 "$SWAY_PID" 2>/dev/null; then
        echo "ctos-shot: sway exited during startup:" >&2
        sed 's/^/  /' "$RUNDIR/sway.log" >&2
        exit 1
    fi
    sleep 0.25
done

if [ -z "$SWAY_DISPLAY" ]; then
    echo "ctos-shot: no wayland socket appeared in $RUNDIR" >&2
    sed 's/^/  /' "$RUNDIR/sway.log" >&2
    exit 1
fi

export WAYLAND_DISPLAY="$SWAY_DISPLAY"
echo "ctos-shot: compositor up on \$WAYLAND_DISPLAY=$SWAY_DISPLAY" >&2

# ------------------------------------------------------------------------------
# Bring up just enough session state that services degrade rather than abort.
# Absence of these is a legitimate condition the shell must survive, but the
# notification server in particular wants a bus.
# ------------------------------------------------------------------------------
if command -v dbus-daemon >/dev/null 2>&1 && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    dbus-daemon --session --fork --print-address=3 3> "$RUNDIR/dbus.addr" 2>/dev/null
    if [ -s "$RUNDIR/dbus.addr" ]; then
        export DBUS_SESSION_BUS_ADDRESS="$(cat "$RUNDIR/dbus.addr")"
        echo "ctos-shot: session bus at \$DBUS_SESSION_BUS_ADDRESS" >&2
    fi
fi

# A plain dark wallpaper so translucency and the border gradient are visible
# against something.
if command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" 2>/dev/null; then
    python3 - "$RUNDIR/bg.png" "$W" "$H" <<'PY'
import sys
from PIL import Image, ImageDraw
out, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
img = Image.new("RGB", (w, h), (16, 24, 40))
d = ImageDraw.Draw(img)
# Faint grid so transparency and the pill's edges are distinguishable.
for x in range(0, w, 64):
    d.line([(x, 0), (x, h)], fill=(24, 34, 54), width=1)
for y in range(0, h, 64):
    d.line([(0, y), (w, y)], fill=(24, 34, 54), width=1)
img.save(out)
PY
    if command -v swaymsg >/dev/null 2>&1; then
        :
    fi
fi

echo "ctos-shot: starting quickshell on $ENTRY ..." >&2
quickshell -p "$ENTRY" > "$RUNDIR/quickshell.log" 2>&1 &
QS_PID=$!

echo "ctos-shot: settling ${SETTLE}s ..." >&2
sleep "$SETTLE"

if ! kill -0 "$QS_PID" 2>/dev/null; then
    echo "ctos-shot: WARNING quickshell exited before capture; log follows:" >&2
    sed 's/^/  /' "$RUNDIR/quickshell.log" | tail -40 >&2
fi

# ------------------------------------------------------------------------------
# Capture. grim needs a live client on the output; if the shell produced no
# surface the capture will be the bare background, which is itself the signal.
# ------------------------------------------------------------------------------
if ! grim "$OUT" 2> "$RUNDIR/grim.err"; then
    echo "ctos-shot: grim failed:" >&2
    sed 's/^/  /' "$RUNDIR/grim.err" >&2
    exit 1
fi

if [ ! -s "$OUT" ]; then
    echo "ctos-shot: capture produced an empty file" >&2
    exit 1
fi

SIZE="$(python3 - "$OUT" <<'PY' 2>/dev/null || echo "?"
import sys, struct
d = open(sys.argv[1], "rb").read(33)
w, h = struct.unpack(">II", d[16:24])
print(f"{w}x{h}")
PY
)"

echo "ctos-shot: wrote $OUT ($SIZE)" >&2

# Surface any QML warnings once, they are usually the reason a surface is wrong.
if [ -s "$RUNDIR/quickshell.log" ]; then
    echo "ctos-shot: quickshell output (tail):" >&2
    tail -20 "$RUNDIR/quickshell.log" | sed 's/^/  /' >&2
fi

echo "$OUT"
