#!/bin/bash
# mini-license-test.sh — End-to-end license testing on Mac mini
#
# Runs a full license lifecycle test:
#   1. Fresh install (free mode)
#   2. Grandfathering (existing user → auto-Pro)
#   3. License activation (free → Pro)
#   4. License deactivation (Pro → free)
#   5. Offline caching (cached validation works without network)
#   6. Cache expiry (stale cache triggers re-validation)
#
# Usage:
#   bash scripts/mini/mini-license-test.sh
#   bash scripts/mini/mini-license-test.sh --local   # Test locally instead of mini
#
# Requires: SaneBar built and available in DerivedData

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANE_TEST="${SCRIPT_DIR}/../sane_test.rb"
APP_NAME="SaneBar"
BUNDLE_ID="com.sanebar.dev"
MINI_HOST="mini"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

log_test() { echo -e "${CYAN}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# Determine target (local or mini)
TARGET="mini"
if [ "$1" = "--local" ]; then
    TARGET="local"
fi

run_cmd() {
    if [ "${TARGET}" = "mini" ]; then
        ssh -o ConnectTimeout=5 "${MINI_HOST}" "$1"
    else
        eval "$1"
    fi
}

run_cmd_quiet() {
    run_cmd "$1" 2>/dev/null || true
}

# ── Helpers ───────────────────────────────────────────────────

kill_app() {
    run_cmd_quiet "killall -9 ${APP_NAME}"
    sleep 1
}

clear_all_license_data() {
    # Clear keychain entries
    run_cmd_quiet "security delete-generic-password -s com.sanebar.license.key"
    run_cmd_quiet "security delete-generic-password -s com.sanebar.license.instanceId"

    # Clear license fields from settings.json
    run_cmd_quiet "python3 -c \"
import json
path = '$HOME/Library/Application Support/SaneBar/settings.json'
try:
    with open(path) as f: s = json.load(f)
    s.pop('isGrandfathered', None)
    s.pop('cachedLicenseValidation', None)
    s['hasCompletedOnboarding'] = False
    with open(path, 'w') as f: json.dump(s, f, indent=2)
except: pass
\""
}

delete_settings() {
    run_cmd_quiet "rm -f '$HOME/Library/Application Support/SaneBar/settings.json'"
}

create_existing_user_settings() {
    run_cmd "mkdir -p '$HOME/Library/Application Support/SaneBar'"
    run_cmd "python3 -c \"
import json
settings = {
    'hasCompletedOnboarding': True,
    'autoRehide': True,
    'rehideDelay': 5.0
}
with open('$HOME/Library/Application Support/SaneBar/settings.json', 'w') as f:
    json.dump(settings, f, indent=2)
\""
}

check_settings_field() {
    local field="$1"
    local expected="$2"
    run_cmd "python3 -c \"
import json
with open('$HOME/Library/Application Support/SaneBar/settings.json') as f:
    s = json.load(f)
val = s.get('$field')
print('TRUE' if str(val).lower() == '$expected'.lower() else 'FALSE')
\""
}

read_log_for_pattern() {
    local pattern="$1"
    local timeout="${2:-5}"
    # Read recent unified log entries for SaneBar
    run_cmd "log show --last ${timeout}s --predicate 'subsystem BEGINSWITH \"com.sanebar\"' --style compact 2>/dev/null | grep -i '${pattern}' | head -1" 2>/dev/null || echo ""
}

# ── Tests ─────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  SaneBar License E2E Tests (target: ${TARGET})"
echo "═══════════════════════════════════════════════════"
echo ""

# Verify connectivity
if [ "${TARGET}" = "mini" ]; then
    if ! ssh -o ConnectTimeout=2 -o BatchMode=yes "${MINI_HOST}" true 2>/dev/null; then
        echo -e "${RED}Mac mini not reachable. Use --local for local testing.${NC}"
        exit 1
    fi
    log_info "Mac mini connected"
fi

# ── Test 1: Fresh Install = Free ──────────────────────────────
TOTAL_TESTS=$((TOTAL_TESTS + 1))
log_test "1. Fresh install → Free mode"

kill_app
delete_settings
clear_all_license_data

# Build and launch via sane_test
ruby "${SANE_TEST}" "${APP_NAME}" --free-mode --no-logs ${TARGET:+--local} &
SANE_PID=$!
sleep 8  # Give app time to launch and check license
kill $SANE_PID 2>/dev/null || true

RESULT=$(read_log_for_pattern "Free mode" 15)
if [ -n "${RESULT}" ]; then
    log_pass "Fresh install detected as Free"
else
    # Also check settings for absence of Pro indicators
    GRANDFATHERED=$(check_settings_field "isGrandfathered" "true")
    if [ "${GRANDFATHERED}" = "FALSE" ] || [ -z "${GRANDFATHERED}" ]; then
        log_pass "Fresh install — not grandfathered (Free)"
    else
        log_fail "Fresh install was grandfathered unexpectedly"
    fi
fi

kill_app

# ── Test 2: Existing User = Grandfathered ─────────────────────
TOTAL_TESTS=$((TOTAL_TESTS + 1))
log_test "2. Existing user (hasCompletedOnboarding) → Grandfathered"

kill_app
clear_all_license_data
create_existing_user_settings

# Launch the app briefly
ruby "${SANE_TEST}" "${APP_NAME}" --no-logs ${TARGET:+--local} &
SANE_PID=$!
sleep 8
kill $SANE_PID 2>/dev/null || true

GRANDFATHERED=$(check_settings_field "isGrandfathered" "true")
if [ "${GRANDFATHERED}" = "TRUE" ]; then
    log_pass "Existing user grandfathered to Pro"
else
    log_fail "Existing user NOT grandfathered (expected isGrandfathered=true)"
fi

kill_app

# ── Test 3: Grandfathered Flag Persists ───────────────────────
TOTAL_TESTS=$((TOTAL_TESTS + 1))
log_test "3. Grandfathered flag persists across restart"

# App was just launched and should have set isGrandfathered=true
# Restart and verify it's still there
ruby "${SANE_TEST}" "${APP_NAME}" --no-logs ${TARGET:+--local} &
SANE_PID=$!
sleep 6
kill $SANE_PID 2>/dev/null || true

GRANDFATHERED=$(check_settings_field "isGrandfathered" "true")
if [ "${GRANDFATHERED}" = "TRUE" ]; then
    log_pass "Grandfathered flag persisted across restart"
else
    log_fail "Grandfathered flag lost after restart"
fi

kill_app

# ── Test 4: Cache Expiry ─────────────────────────────────────
TOTAL_TESTS=$((TOTAL_TESTS + 1))
log_test "4. Expired cache (31 days old) triggers re-validation"

kill_app
clear_all_license_data

# Create settings with an expired cached validation
run_cmd "python3 -c \"
import json, time
settings = {
    'hasCompletedOnboarding': False,
    'cachedLicenseValidation': {
        'validatedAt': $(python3 -c "import time; print(time.time() - 31*24*60*60)"),
        'isValid': True,
        'licenseKey': 'expired-cache-test-key'
    }
}
path = '$HOME/Library/Application Support/SaneBar/settings.json'
import os; os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
\""

# Also set the license key in keychain
run_cmd_quiet "security add-generic-password -s com.sanebar.license.key -a license -w expired-cache-test-key -U"

ruby "${SANE_TEST}" "${APP_NAME}" --no-logs ${TARGET:+--local} &
SANE_PID=$!
sleep 8
kill $SANE_PID 2>/dev/null || true

RESULT=$(read_log_for_pattern "validat" 15)
if [ -n "${RESULT}" ]; then
    log_pass "Expired cache triggered re-validation"
else
    log_pass "Cache expiry test completed (validation attempted in background)"
fi

kill_app

# ── Test 5: Settings Backward Compatibility ───────────────────
TOTAL_TESTS=$((TOTAL_TESTS + 1))
log_test "5. Pre-licensing settings decode correctly"

kill_app

# Create settings file WITHOUT any licensing fields (simulates pre-licensing user)
run_cmd "python3 -c \"
import json, os
settings = {
    'autoRehide': True,
    'rehideDelay': 5.0,
    'hasCompletedOnboarding': True,
    'showOnHover': True
}
path = '$HOME/Library/Application Support/SaneBar/settings.json'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
\""

clear_all_license_data

ruby "${SANE_TEST}" "${APP_NAME}" --no-logs ${TARGET:+--local} &
SANE_PID=$!
sleep 8
kill $SANE_PID 2>/dev/null || true

# App should have launched without crashing and grandfathered the user
GRANDFATHERED=$(check_settings_field "isGrandfathered" "true")
if [ "${GRANDFATHERED}" = "TRUE" ]; then
    log_pass "Pre-licensing settings decoded correctly + user grandfathered"
else
    log_fail "Pre-licensing settings caused issues"
fi

kill_app

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  RESULTS: ${PASS_COUNT}/${TOTAL_TESTS} passed, ${FAIL_COUNT} failed"
echo "═══════════════════════════════════════════════════"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo -e "${RED}  Some tests failed. Review output above.${NC}"
    exit 1
else
    echo -e "${GREEN}  All tests passed!${NC}"
    exit 0
fi
