#!/usr/bin/env bash
# Smoke-run the game headless and exit. Godot's --quit-after counts frames
# (not seconds), so QUIT_AFTER is a frame budget — defaults to 5, which is
# enough to verify _ready and the first _process tick.
# QUIT_AFTER=600 ./run-headless.sh ≈ a few real seconds of simulation.
# Extra args pass through to godot.
set -euo pipefail
cd "$(dirname "$0")"
exec godot --headless --quit-after "${QUIT_AFTER:-5}" "$@"
