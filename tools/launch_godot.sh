#!/usr/bin/env bash
# Linux launcher used by the source demo and the packaged game.
set -u
engine=$1
shift

for arg in "$@"; do
  case "$arg" in
    --|++) break ;;
    --headless|--rendering-method|--rendering-driver|--gpu-index|--rendering-method=*|--rendering-driver=*|--gpu-index=*)
      exec "$engine" "$@" ;;
  esac
done

# Keep stdout and stdin connected to the caller. Inspect only stderr from
# the first attempt because these startup failures precede Godot's game log.
# Allocate unused descriptors. The AppImage runtime holds its FUSE mount
# open through an inherited descriptor, which must survive both attempts.
exec {game_stdout}>&1
exec {diagnostics}< <(exec "$engine" "$@" 2>&1 >&"$game_stdout" {game_stdout}>&-)
game_pid=$!
exec {game_stdout}>&-
trap 'kill -TERM "$game_pid" 2>/dev/null || :' TERM INT HUP

vulkan_failed=false
display_failed=false
while IFS= read -r line || [[ -n $line ]]; do
  printf '%s\n' "$line" >&2
  case "$line" in
    *"Couldn't create Vulkan device"*|*"Couldn't initialize Vulkan device"*) vulkan_failed=true ;;
    *"Unable to create DisplayServer, all display drivers failed"*) display_failed=true ;;
  esac
done <&"$diagnostics"
exec {diagnostics}<&-
wait "$game_pid"
status=$?
trap - TERM INT HUP

if [[ $status -eq 1 && $vulkan_failed == true && $display_failed == true ]]; then
  printf '%s\n' "Last Call: Vulkan could not open the game window. Retrying with OpenGL." >&2
  exec "$engine" --rendering-method gl_compatibility "$@"
fi
exit "$status"
