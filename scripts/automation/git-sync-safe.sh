#!/bin/bash
# Safe nightly Git sync.
# - Auto-pushes clean main/master commits.
# - Auto-pulls fast-forward when clean.
# - Never auto-commits. Never pushes dirty trees.

set -euo pipefail

ROOT="$HOME/SaneApps"
OUT_DIR="$ROOT/infra/SaneProcess/outputs"
LOG_FILE="$OUT_DIR/git_sync_safe.log"
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$OUT_DIR"

log() {
  echo "$*" | tee -a "$LOG_FILE"
}

repos=()
for d in "$ROOT/apps"/*; do
  [[ -d "$d/.git" ]] && repos+=("$d")
done
[[ -d "$ROOT/SaneAI/.git" ]] && repos+=("$ROOT/SaneAI")
[[ -d "$ROOT/infra/SaneProcess/.git" ]] && repos+=("$ROOT/infra/SaneProcess")

if [[ ${#repos[@]} -eq 0 ]]; then
  echo "[$NOW_LOCAL] No repos found under $ROOT" >> "$LOG_FILE"
  exit 0
fi

{
  echo
  echo "================================================================"
  echo "[$NOW_LOCAL] Safe Git Sync Start"
  echo "Host: $(hostname)"
  echo "================================================================"
} >> "$LOG_FILE"

issues=0
for repo in "${repos[@]}"; do
  name=$(basename "$repo")
  log ""
  log "[$name] $repo"

  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "  - Skipped: not a git repo"
    continue
  fi

  if ! git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    log "  - Skipped: no origin remote"
    continue
  fi

  branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
  if [[ "$branch" == "DETACHED" ]]; then
    log "  - Skipped: detached HEAD"
    continue
  fi

  if ! git -C "$repo" fetch origin --prune >/dev/null 2>&1; then
    log "  - ERROR: fetch failed"
    issues=$((issues + 1))
    continue
  fi

  dirty=$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')
  behind=$(git -C "$repo" rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo "0")
  ahead=$(git -C "$repo" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo "0")

  log "  - branch=$branch dirty=$dirty behind=$behind ahead=$ahead"

  if [[ "$dirty" -eq 0 && "$behind" -gt 0 ]]; then
    if git -C "$repo" pull --ff-only >/dev/null 2>&1; then
      log "  - Pulled: fast-forwarded $behind commit(s)"
    else
      log "  - ERROR: ff-only pull failed"
      issues=$((issues + 1))
    fi
  elif [[ "$behind" -gt 0 ]]; then
    log "  - WARNING: behind but dirty; skipped pull"
    issues=$((issues + 1))
  fi

  if [[ "$dirty" -eq 0 && "$ahead" -gt 0 ]]; then
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
      if git -C "$repo" push >/dev/null 2>&1; then
        log "  - Pushed: $ahead commit(s)"
      else
        log "  - ERROR: push failed"
        issues=$((issues + 1))
      fi
    else
      log "  - WARNING: ahead on non-main branch '$branch'; skipped auto-push"
      issues=$((issues + 1))
    fi
  elif [[ "$ahead" -gt 0 ]]; then
    log "  - WARNING: ahead but dirty; skipped push"
    issues=$((issues + 1))
  fi

done

log ""
if [[ "$issues" -gt 0 ]]; then
  log "Safe Git Sync finished with $issues warning/error item(s)."
  osascript -e "display notification \"$issues repo sync item(s) need attention\" with title \"SaneApps Git Sync\"" >/dev/null 2>&1 || true
  exit 1
else
  log "Safe Git Sync finished clean."
  exit 0
fi
