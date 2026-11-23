#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
task_engine="${GODOT_BIN:-$HOME/.cache/codex-tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$task_engine" ]]; then
  python3 "$task_root/tools/bootstrap_godot.py"
fi
exec "$task_root/tools/launch_godot.sh" "$task_engine" --path "$task_root/game" "$@"
