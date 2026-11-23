#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec ./launch_godot.sh ./LastCall.x86_64 "$@"
