#!/usr/bin/env bash
set -euo pipefail

CHECK_INBOX="${HOME}/SaneApps/infra/scripts/check-inbox.sh"

printf '\nSane support kickoff (%s)\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '%s\n' "----------------------------------------"

if [[ -x "$CHECK_INBOX" ]]; then
  "$CHECK_INBOX"
  echo
  echo 'Open items marked needs_human/license/support/bug:'
  "$CHECK_INBOX" | awk '
    /^🔴 NEEDS REPLY/ {flag=1; next}
    flag && /^[[:space:]]*#/{print}
    /^\s*Total:/ {if (flag) exit}
  '
else
  echo "check-inbox.sh not found at $CHECK_INBOX"
fi

printf '\nDone.\n'
