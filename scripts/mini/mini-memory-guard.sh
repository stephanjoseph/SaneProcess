#!/bin/bash
# mini-memory-guard.sh - Daily Mac mini hygiene + safe reboot gate
# Intended to run via LaunchAgent in early-morning hours.
#
# Goals:
# - Keep the mini responsive as a build server.
# - Kill stale dev app binaries from DerivedData.
# - Rotate oversized logs.
# - Reboot only when safe (night window, no critical jobs).

set -euo pipefail

DRY_RUN=0
FORCE_REBOOT=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force-reboot) FORCE_REBOOT=1 ;;
    *)
      echo "Usage: $0 [--dry-run] [--force-reboot]" >&2
      exit 2
      ;;
  esac
done

OUTPUT_DIR="$HOME/SaneApps/outputs"
LOG_FILE="$OUTPUT_DIR/mini_memory_guard.log"
mkdir -p "$OUTPUT_DIR"

log() {
  local msg="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$LOG_FILE"
}

get_load1() {
  uptime | awk -F'load averages: ' '{print $2}' | tr -d ',' | awk '{print $1}'
}

get_swap_used_mb() {
  sysctl vm.swapusage | awk -F'used = ' '{print $2}' | awk '{gsub(/M/,"",$1); print $1}'
}

get_free_pct() {
  memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print $2; exit}'
}

get_uptime_days() {
  local up
  up="$(uptime)"
  if echo "$up" | grep -q " day"; then
    echo "$up" | sed -E 's/.* up ([0-9]+) day.*/\1/'
  else
    echo "0"
  fi
}

is_training_running() {
  pgrep -f "mlx_lm lora --train" >/dev/null 2>&1 || \
    pgrep -f "mini-train.sh" >/dev/null 2>&1 || \
    pgrep -f "mini-train-all.sh" >/dev/null 2>&1
}

is_nightly_running() {
  pgrep -f "mini-nightly.sh" >/dev/null 2>&1 || \
    pgrep -f "xcodebuild .*Sane" >/dev/null 2>&1
}

rotate_if_large() {
  local file="$1"
  local max_bytes="$2"
  local keep_bytes="$3"

  [ -f "$file" ] || return 0
  local size
  size=$(stat -f%z "$file" 2>/dev/null || echo 0)
  if [ "$size" -gt "$max_bytes" ]; then
    local tmp="${file}.tmp"
    tail -c "$keep_bytes" "$file" > "$tmp" && mv "$tmp" "$file"
    log "Rotated $file (size=${size}B, kept last ${keep_bytes}B)"
  fi
}

cleanup_stale_deriveddata_apps() {
  local stale_count
  stale_count=$(ps -axo command | awk '/\/DerivedData\/.*\/Sane[^ ]*\.app\/Contents\/MacOS\/Sane/{count++} END{print count+0}')
  if [ "$stale_count" -eq 0 ]; then
    log "No stale DerivedData Sane app processes"
    return 0
  fi

  log "Found $stale_count stale DerivedData Sane app process(es)"
  if [ "$DRY_RUN" -eq 1 ]; then
    ps -axo pid,etime,command | grep -E '/DerivedData/.*/Sane[^ ]*\.app/Contents/MacOS/Sane' | grep -v grep | tee -a "$LOG_FILE" || true
    return 0
  fi

  pkill -f '/DerivedData/.*/Sane[^ ]*\.app/Contents/MacOS/Sane' || true
  sleep 1
  log "Killed stale DerivedData Sane app process(es)"
}

in_reboot_window() {
  local hour
  hour=$(date +%H)
  hour=$((10#$hour))
  # Reboot window: 05:00-05:59 local
  [ "$hour" -eq 5 ]
}

should_reboot() {
  local load1 swap_mb free_pct uptime_days
  load1="$(get_load1)"
  swap_mb="$(get_swap_used_mb)"
  free_pct="$(get_free_pct)"
  uptime_days="$(get_uptime_days)"

  local reasons=""
  if awk "BEGIN {exit !($swap_mb >= 3072)}"; then
    reasons="high swap (${swap_mb}MB)"
  fi
  if [ "$uptime_days" -ge 7 ]; then
    if [ -n "$reasons" ]; then reasons="$reasons, "; fi
    reasons="${reasons}long uptime (${uptime_days}d)"
  fi
  if awk "BEGIN {exit !($load1 >= 14)}"; then
    if [ -n "$reasons" ]; then reasons="$reasons, "; fi
    reasons="${reasons}high load (${load1})"
  fi

  if [ "$FORCE_REBOOT" -eq 1 ]; then
    reasons="forced by operator"
  fi

  if [ -z "$reasons" ]; then
    echo ""
  else
    echo "$reasons"
  fi
}

maybe_reboot() {
  local reasons
  reasons="$(should_reboot)"
  if [ -z "$reasons" ]; then
    log "Reboot not needed"
    return 0
  fi

  if ! in_reboot_window; then
    log "Reboot needed ($reasons) but outside safe window (05:00-05:59). Skipping."
    return 0
  fi

  if is_training_running; then
    log "Reboot needed ($reasons) but training is active. Skipping."
    return 0
  fi

  if is_nightly_running; then
    log "Reboot needed ($reasons) but nightly build/test is active. Skipping."
    return 0
  fi

  log "Reboot approved ($reasons)"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY RUN: would restart now via System Events"
    return 0
  fi

  if /usr/bin/osascript -e 'tell application "System Events" to restart' >/dev/null 2>&1; then
    log "Restart command sent successfully"
  else
    log "Restart command failed (osascript/System Events denied)"
    return 1
  fi
}

main() {
  local load1 swap_mb free_pct uptime_days
  load1="$(get_load1)"
  swap_mb="$(get_swap_used_mb)"
  free_pct="$(get_free_pct)"
  uptime_days="$(get_uptime_days)"

  log "mini-memory-guard start (dry_run=$DRY_RUN force_reboot=$FORCE_REBOOT)"
  log "Health before: load1=$load1 swap_used_mb=$swap_mb free_pct=${free_pct:-unknown} uptime_days=$uptime_days"

  rotate_if_large "$OUTPUT_DIR/training.stdout.log" 31457280 8388608
  rotate_if_large "$OUTPUT_DIR/training.stderr.log" 10485760 2097152
  rotate_if_large "$OUTPUT_DIR/nightly.stdout.log" 10485760 2097152
  rotate_if_large "$OUTPUT_DIR/nightly.stderr.log" 10485760 2097152

  cleanup_stale_deriveddata_apps
  maybe_reboot

  load1="$(get_load1)"
  swap_mb="$(get_swap_used_mb)"
  free_pct="$(get_free_pct)"
  uptime_days="$(get_uptime_days)"
  log "Health after: load1=$load1 swap_used_mb=$swap_mb free_pct=${free_pct:-unknown} uptime_days=$uptime_days"
  log "mini-memory-guard complete"
}

main "$@"
