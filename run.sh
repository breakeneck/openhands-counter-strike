#!/usr/bin/env bash
# Launch the tactical FPS (openhands-counter-strike) windowed on the X11 display.
#   ./run.sh                     # auto-update from GitHub, then play
#   ./run.sh --noupdate          # skip git pull
#   ./run.sh --windowed 1280x720 # smaller window (godot arg)
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DISPLAY="${DISPLAY:-:0}"
GODOT="${GODOT:-$HOME/bin/godot}"

# --- auto-update: fast-forward pull, re-import assets only if files changed ---
GODOT_ARGS=()
SKIP_UPDATE="${NOUPDATE:-0}"
for arg in "$@"; do
	if [[ "$arg" == "--noupdate" ]]; then
		SKIP_UPDATE=1
	else
		GODOT_ARGS+=("$arg")
	fi
done

if [[ "$SKIP_UPDATE" != "1" ]] && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
	if git -C "$SCRIPT_DIR" diff --quiet && git -C "$SCRIPT_DIR" diff --cached --quiet; then
		before=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
		if git -C "$SCRIPT_DIR" pull --ff-only --quiet 2>/dev/null; then
			after=$(git -C "$SCRIPT_DIR" rev-parse HEAD)
			if [[ "$before" != "$after" ]]; then
				echo "[run] updated $(git -C "$SCRIPT_DIR" rev-parse --short "$before") -> $(git -C "$SCRIPT_DIR" rev-parse --short "$after")"
			else
				echo "[run] up to date"
			fi
		else
			echo "[run] pull failed (offline or conflict) — running current copy"
		fi
	else
		echo "[run] local changes present — skipping update"
	fi
fi

# Always ensure imports are current (incremental — fast when nothing changed).
# Fixes stale .godot/imported caches after asset updates (e.g. "Failed loading resource ... pistol_01.wav").
"$GODOT" --headless --path "$SCRIPT_DIR" --import >/dev/null 2>&1 || true

exec "$GODOT" --path "$SCRIPT_DIR" --rendering-driver vulkan "${GODOT_ARGS[@]+"${GODOT_ARGS[@]}"}"