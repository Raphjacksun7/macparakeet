#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 64
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=$1
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

binary="$output_dir/process-tap-audio-only-probe"
result="$output_dir/result.json"
tone="$output_dir/generated-997hz.wav"
cycles=${MACPARAKEET_PROCESS_TAP_PROBE_CYCLES:-1}
tone_duration_seconds=${MACPARAKEET_PROCESS_TAP_PROBE_TONE_SECONDS:-2}
deadline_seconds=${MACPARAKEET_PROCESS_TAP_PROBE_DEADLINE_SECONDS:-20}

managed_outputs=(
  "$binary"
  "$result"
  "$tone"
  "$output_dir/environment.txt"
  "$output_dir/stdout.txt"
  "$output_dir/stderr.txt"
  "$output_dir/deadline.txt"
)
for managed_output in "${managed_outputs[@]}"; do
  if [[ -e "$managed_output" ]]; then
    echo "output directory already contains probe artifact: $managed_output" >&2
    echo "use a fresh output directory so a failed run cannot retain prior PASS data" >&2
    exit 73
  fi
done

swiftc \
  -parse-as-library \
  -O \
  -framework AudioToolbox \
  -framework CoreAudio \
  -framework Foundation \
  "$repo_root/scripts/process-tap-audio-only-probe.swift" \
  -o "$binary"

codesign --force --sign - \
  --identifier io.pocketstation.macparakeet-process-tap-probe \
  "$binary"

{
  sw_vers
  uname -m
  swift --version
  codesign -dv --verbose=4 "$binary" 2>&1
} >"$output_dir/environment.txt" 2>&1

set +e
probe_pid=""

probe_children() {
  /usr/bin/pgrep -P "$probe_pid" 2>/dev/null || true
}

wait_for_probe_exit() {
  local attempts=$1
  local attempt=0
  while kill -0 "$probe_pid" 2>/dev/null && (( attempt < attempts )); do
    sleep 0.1
    attempt=$((attempt + 1))
  done
  ! kill -0 "$probe_pid" 2>/dev/null
}

stop_probe_tree() {
  [[ -n "$probe_pid" ]] || return 0
  kill -0 "$probe_pid" 2>/dev/null || return 0

  local child_pid
  while IFS= read -r child_pid; do
    [[ -n "$child_pid" ]] && kill -TERM "$child_pid" 2>/dev/null || true
  done < <(probe_children)

  if wait_for_probe_exit 20; then
    wait "$probe_pid" 2>/dev/null || true
    return 0
  fi

  kill -TERM "$probe_pid" 2>/dev/null || true
  if ! wait_for_probe_exit 20; then
    kill -KILL "$probe_pid" 2>/dev/null || true
  fi
  wait "$probe_pid" 2>/dev/null || true
}

trap stop_probe_tree EXIT INT TERM

"$binary" \
  --output "$result" \
  --tone "$tone" \
  --cycles "$cycles" \
  --tone-duration-seconds "$tone_duration_seconds" \
  >"$output_dir/stdout.txt" 2>"$output_dir/stderr.txt" &
probe_pid=$!

deadline=$((SECONDS + deadline_seconds))
while kill -0 "$probe_pid" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    echo "process-tap probe exceeded ${deadline_seconds}-second deadline" >"$output_dir/deadline.txt"
    stop_probe_tree
    probe_pid=""
    exit 124
  fi
  sleep 0.1
done
wait "$probe_pid"
probe_status=$?
probe_pid=""
set -e

test -s "$result"
/usr/bin/plutil -convert xml1 -o /dev/null "$result"

result_field() {
  /usr/bin/plutil -extract "$1" raw -o - "$result"
}

test "$(result_field schemaVersion)" = "2"
test "$(result_field microphoneRequested)" = "false"
test "$(result_field screenPixelsRequested)" = "false"

if [[ "$(result_field status)" == "PASS" ]]; then
  test "$(result_field permissionOutcome)" = "process_tap_created"
  test "$(result_field completedCycles)" = "$(result_field requestedCycles)"
  test "$(result_field completedCycles)" = "$cycles"
  test "$(result_field capturedFrames)" -gt 0
  /usr/bin/awk -v value="$(result_field minimumCycleRMS)" \
    'BEGIN { exit !(value >= 0.005) }'
  /usr/bin/awk -v value="$(result_field minimumCycleTargetAmplitude)" \
    'BEGIN { exit !(value >= 0.005) }'
  for ((cycle_index = 0; cycle_index < cycles; cycle_index += 1)); do
    test "$(result_field "cycles.${cycle_index}.teardownVerified")" = "true"
    test "$(result_field "cycles.${cycle_index}.capturedFrames")" -gt 0
    /usr/bin/awk -v value="$(result_field "cycles.${cycle_index}.rms")" \
      'BEGIN { exit !(value >= 0.005) }'
    /usr/bin/awk -v value="$(result_field "cycles.${cycle_index}.targetAmplitude")" \
      'BEGIN { exit !(value >= 0.005) }'
  done
fi

exit "$probe_status"
