#!/usr/bin/env bash
# Quality gate 2 (DESIGN §10): run every gdUnit4 suite headless.
set -euo pipefail
cd "$(dirname "$0")/.."
export GODOT_BIN="${GODOT:-godot}"
"$GODOT_BIN" --headless --import >/dev/null 2>&1 || true
bash addons/gdUnit4/runtest.sh --ignoreHeadlessMode -a res://tests -rd reports
