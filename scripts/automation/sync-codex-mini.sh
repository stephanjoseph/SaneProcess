#!/bin/bash
# Sync SaneOps Codex automation config from local machine to Mac mini.
# Local role: paused (no duplicate runs). Mini role: AM active, PM paused.

set -euo pipefail

MINI_HOST="mini"
QUIET=0
RESTART_CODEX=1

usage() {
  cat <<USAGE
Usage: $(basename "$0") [mini-host] [--quiet] [--no-restart]

Examples:
  $(basename "$0")
  $(basename "$0") mini --quiet
  $(basename "$0") mini --no-restart
USAGE
}

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    echo "$@"
  fi
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --no-restart)
      RESTART_CODEX=0
      shift
      ;;
    --*)
      die "Unknown option: $1"
      ;;
    *)
      MINI_HOST="$1"
      shift
      ;;
  esac
done

command -v ssh >/dev/null 2>&1 || die "ssh not found"
command -v scp >/dev/null 2>&1 || die "scp not found"

LOCAL_CODEX_DIR="$HOME/.codex"
LOCAL_AM="$LOCAL_CODEX_DIR/automations/saneops-am-run/automation.toml"
LOCAL_PM="$LOCAL_CODEX_DIR/automations/saneops-pm-run/automation.toml"
LOCAL_DB="$LOCAL_CODEX_DIR/sqlite/codex-dev.db"
LOCAL_CHECK_INBOX="$HOME/SaneApps/infra/scripts/check-inbox.sh"

[[ -f "$LOCAL_AM" ]] || die "Missing local automation file: $LOCAL_AM"
[[ -f "$LOCAL_PM" ]] || die "Missing local automation file: $LOCAL_PM"
[[ -f "$LOCAL_CHECK_INBOX" ]] || die "Missing check-inbox script: $LOCAL_CHECK_INBOX"

set_status_in_file() {
  local file="$1"
  local status="$2"
  perl -0pi -e "s/^status = \"[^\"]*\"/status = \"${status}\"/m" "$file"
}

# Local machine should never run these automatically.
set_status_in_file "$LOCAL_AM" "PAUSED"
set_status_in_file "$LOCAL_PM" "PAUSED"

if [[ -f "$LOCAL_DB" ]]; then
  sqlite3 "$LOCAL_DB" "
    UPDATE automations SET status='PAUSED', updated_at=(strftime('%s','now')*1000) WHERE id='saneops-am-run';
    UPDATE automations SET status='PAUSED', updated_at=(strftime('%s','now')*1000) WHERE id='saneops-pm-run';
  " >/dev/null 2>&1 || true
fi

REMOTE_HOME=$(ssh -o ConnectTimeout=8 "$MINI_HOST" 'printf %s "$HOME"') || die "Could not reach $MINI_HOST"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

TMP_AM="$TMP_DIR/saneops-am-run.toml"
TMP_PM="$TMP_DIR/saneops-pm-run.toml"
cp "$LOCAL_AM" "$TMP_AM"
cp "$LOCAL_PM" "$TMP_PM"

rewrite_paths() {
  local file="$1"
  python3 - "$file" "$HOME" "$REMOTE_HOME" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
local_home = sys.argv[2].rstrip("/") + "/"
remote_home = sys.argv[3].rstrip("/") + "/"
text = path.read_text(encoding="utf-8")
text = text.replace(local_home, remote_home)
path.write_text(text, encoding="utf-8")
PY
}

rewrite_paths "$TMP_AM"
rewrite_paths "$TMP_PM"

# Mini role: AM active, PM paused.
set_status_in_file "$TMP_AM" "ACTIVE"
set_status_in_file "$TMP_PM" "PAUSED"

log "Syncing SaneOps automation files to $MINI_HOST..."
scp -q "$TMP_AM" "$TMP_PM" "$LOCAL_CHECK_INBOX" "$MINI_HOST:$REMOTE_HOME/"

ssh "$MINI_HOST" "
  set -e
  mkdir -p \"$REMOTE_HOME/.codex/automations/saneops-am-run\" \"$REMOTE_HOME/.codex/automations/saneops-pm-run\"
  cp \"$REMOTE_HOME/saneops-am-run.toml\" \"$REMOTE_HOME/.codex/automations/saneops-am-run/automation.toml\"
  cp \"$REMOTE_HOME/saneops-pm-run.toml\" \"$REMOTE_HOME/.codex/automations/saneops-pm-run/automation.toml\"
  mkdir -p \"$REMOTE_HOME/SaneApps/infra/scripts\"
  cp \"$REMOTE_HOME/check-inbox.sh\" \"$REMOTE_HOME/SaneApps/infra/scripts/check-inbox.sh\"
  chmod +x \"$REMOTE_HOME/SaneApps/infra/scripts/check-inbox.sh\"
  rm -f \"$REMOTE_HOME/saneops-am-run.toml\" \"$REMOTE_HOME/saneops-pm-run.toml\" \"$REMOTE_HOME/check-inbox.sh\"
" || die "Remote copy failed"

if [[ "$RESTART_CODEX" -eq 1 ]]; then
  log "Restarting Codex on $MINI_HOST to reload automation definitions..."
  ssh "$MINI_HOST" 'pkill -f "/Applications/Codex.app/Contents/MacOS/Codex" >/dev/null 2>&1 || true; sleep 1; open -ga Codex'
  sleep 3
fi

log ""
log "Local status (should be paused):"
grep -n '^name\|^status\|^rrule' "$LOCAL_AM" "$LOCAL_PM"

log ""
log "Mini status files:"
ssh "$MINI_HOST" "grep -n '^name\\|^status\\|^rrule' \"$REMOTE_HOME/.codex/automations/saneops-am-run/automation.toml\" \"$REMOTE_HOME/.codex/automations/saneops-pm-run/automation.toml\""

log ""
log "Mini scheduler DB:"
ssh "$MINI_HOST" "sqlite3 -header -column \"$REMOTE_HOME/.codex/sqlite/codex-dev.db\" \"SELECT id,name,status,datetime(next_run_at/1000,'unixepoch','localtime') AS next_run_local, datetime(last_run_at/1000,'unixepoch','localtime') AS last_run_local FROM automations;\""

log ""
log "Done. Mini is the active runner; local automations remain paused."
