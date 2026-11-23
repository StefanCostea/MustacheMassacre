#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
task_engine="${GODOT_BIN:-$HOME/.cache/codex-tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
mkdir -p "$task_root/build/releases/LastCall"
install -m 755 "$task_root/tools/launch_godot.sh" "$task_root/build/releases/LastCall/launch_godot.sh"
"$task_engine" --headless --path "$task_root/game" --editor --import --quit
"$task_engine" --headless --path "$task_root/game" --export-release Linux
