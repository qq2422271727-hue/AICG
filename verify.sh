#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
godot_bin="${GODOT_BIN:-godot}"
task_xdg="$(mktemp -d /tmp/ashwake-v05-checks-XXXXXX)"
export XDG_DATA_HOME="$task_xdg/data"
export XDG_CONFIG_HOME="$task_xdg/config"
export XDG_CACHE_HOME="$task_xdg/cache"
mkdir -p test_logs
run_check() {
  local title="$1"
  shift
  "$godot_bin" --headless --path . "$@" >"test_logs/$title.log" 2>&1
  if rg -n 'SCRIPT ERROR|Parse Error|FAIL:' "test_logs/$title.log"; then
    printf 'FAILED: %s\n' "$title"
    return 1
  fi
  printf 'COMPLETE: %s\n' "$title"
  rg 'RESULT:|WORLD ART VERIFY:|V05 MAP VERIFY:' "test_logs/$title.log" || true
}
run_check import --editor --quit
run_check main_scene --fixed-fps 60 --quit-after 180
run_check smoke --fixed-fps 60 --script res://tests/smoke_test.gd
run_check touch --fixed-fps 60 --script res://tests/touch_test.gd
run_check visual --fixed-fps 60 --script res://tests/visual_test.gd
for fps in 30 60 120; do
  run_check "camera_$fps" --fixed-fps "$fps" --script res://tests/camera_test.gd
done
if [[ -f tests/combo_test.gd ]]; then
  run_check combo --fixed-fps 60 --script res://tests/combo_test.gd
fi
if [[ -f tests/map_test.gd ]]; then
  for fps in 30 60 120; do
    run_check "map_$fps" --fixed-fps "$fps" --script res://tests/map_test.gd
  done
fi
mkdir -p test_logs/independent
for suite in independent_combo_edges independent_live_qa independent_hitstop; do
  if [[ -f "tests/independent/$suite.gd" ]]; then
    run_check "independent/final-$suite" --fixed-fps 60 --script "res://tests/independent/$suite.gd"
  fi
done
