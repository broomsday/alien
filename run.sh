#!/usr/bin/env bash
# Launch the game windowed. Extra args pass through to godot.
set -euo pipefail
cd "$(dirname "$0")"
exec godot "$@"
