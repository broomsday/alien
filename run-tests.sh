#!/usr/bin/env bash
# Run every tests/test_*.gd file as its own headless Godot process.
# Each script extends SceneTree and calls quit(0) on success / quit(1) on fail.
set -euo pipefail
cd "$(dirname "$0")"

shopt -s nullglob
tests=(tests/test_*.gd)
if [ ${#tests[@]} -eq 0 ]; then
	echo "no tests found under tests/"
	exit 1
fi

fail=0
for t in "${tests[@]}"; do
	if ! godot --headless --script "res://$t"; then
		echo "FAIL: $t"
		fail=1
	fi
done
exit "$fail"
