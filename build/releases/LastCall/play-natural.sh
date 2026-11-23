#!/usr/bin/env bash
set -euo pipefail
task_release="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$task_release/play.sh" "$@" -- --natural-hero
