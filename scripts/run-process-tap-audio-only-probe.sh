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
} >"$output_dir/environment.txt"

set +e
"$binary" --output "$result" --tone "$tone" \
  >"$output_dir/stdout.txt" 2>"$output_dir/stderr.txt" &
probe_pid=$!

deadline=$((SECONDS + 20))
while kill -0 "$probe_pid" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    kill -TERM "$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null
    echo "process-tap probe exceeded 20-second deadline" >"$output_dir/deadline.txt"
    exit 124
  fi
  sleep 0.1
done
wait "$probe_pid"
probe_status=$?
set -e

test -s "$result"
jq -e '
  .schemaVersion == 1 and
  .microphoneRequested == false and
  .screenPixelsRequested == false and
  (if .status == "PASS" then
    .permissionOutcome == "process_tap_created" and
    .capturedFrames > 0 and
    .rms >= 0.005 and
    .targetAmplitude >= 0.005
  else true end)
' "$result" >/dev/null

exit "$probe_status"
