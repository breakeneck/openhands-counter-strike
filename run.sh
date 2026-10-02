#!/usr/bin/env bash
# Launch the tactical FPS (openhands-counter-strike) windowed on the X11 display.
#   ./run.sh                     # normal play
#   ./run.sh --windowed 1280x720 # smaller window
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DISPLAY="${DISPLAY:-:0}"
exec "$HOME/bin/godot" --path "$SCRIPT_DIR" --rendering-driver vulkan "$@"