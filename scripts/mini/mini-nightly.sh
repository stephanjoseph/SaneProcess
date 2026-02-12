#!/bin/bash
# mini-nightly.sh - Nightly automation for Mac mini build server
# Runs at 2 AM daily via LaunchAgent
# Results available via: ssh mini cat ~/SaneApps/outputs/nightly_report.md

set -uo pipefail

APPS_DIR="$HOME/SaneApps/apps"
INFRA_DIR="$HOME/SaneApps/infra"
OUTPUT_DIR="$HOME/SaneApps/outputs"
REPORT="$OUTPUT_DIR/nightly_report.md"
DATE=$(date +"%Y-%m-%d %A")
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

mkdir -p "$OUTPUT_DIR"

# Lock file (with stale lock detection)
LOCKFILE="$OUTPUT_DIR/.nightly.lock"
if ! mkdir "$LOCKFILE" 2>/dev/null; then
  # Check if lock is stale (older than 2 hours)
  if [ -d "$LOCKFILE" ] && [ "$(find "$LOCKFILE" -maxdepth 0 -mmin +120 2>/dev/null)" ]; then
    echo "Removing stale lock (>2 hours old)" >&2
    rm -rf "$LOCKFILE"
    mkdir "$LOCKFILE" 2>/dev/null || { echo "Cannot acquire lock" >&2; exit 1; }
  else
    echo "Another nightly instance is running" >&2
    exit 1
  fi
fi
trap 'rm -rf "$LOCKFILE"' EXIT

cat > "$REPORT" <<EOF
# Mac Mini Nightly Report — $DATE

Generated at $TIMESTAMP

---

EOF

# =============================================================================
# Section 1: Git Pull All Repos
# =============================================================================
echo "## Git Sync" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Repo | Status | Behind | Ahead |" >> "$REPORT"
echo "|------|--------|--------|-------|" >> "$REPORT"

for repo_dir in "$APPS_DIR"/* "$INFRA_DIR"/*; do
  [ -d "$repo_dir/.git" ] || continue
  repo_name=$(basename "$repo_dir")

  cd "$repo_dir" || continue

  # Fetch and check status
  if ! git fetch origin 2>/dev/null; then
    echo "| $repo_name | Fetch failed (offline?) | - | - |" >> "$REPORT"
    continue
  fi

  local_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [ -z "$local_branch" ]; then
    echo "| $repo_name | Detached HEAD (skipped) | - | - |" >> "$REPORT"
    continue
  fi

  behind=$(git rev-list --count HEAD..origin/"$local_branch" 2>/dev/null || echo "?")
  ahead=$(git rev-list --count origin/"$local_branch"..HEAD 2>/dev/null || echo "?")

  # Pull if behind
  if [ "$behind" != "0" ] && [ "$behind" != "?" ]; then
    if git pull --ff-only origin "$local_branch" 2>/dev/null; then
      status="Updated (+$behind commits)"
    else
      status="Merge conflict"
    fi
  else
    status="Up to date"
  fi

  echo "| $repo_name | $status | $behind | $ahead |" >> "$REPORT"
done

echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "" >> "$REPORT"

# =============================================================================
# Section 2: Build All Apps
# =============================================================================
echo "## Build Results" >> "$REPORT"
echo "" >> "$REPORT"

BUILD_PASS=0
BUILD_FAIL=0

for app_dir in "$APPS_DIR"/Sane*; do
  [ -d "$app_dir" ] || continue
  app_name=$(basename "$app_dir")

  cd "$app_dir" || continue

  # Find xcodeproj or Package.swift
  SCHEME=""
  BUILD_TYPE=""

  if ls *.xcodeproj 1>/dev/null 2>&1; then
    proj=$(ls -d *.xcodeproj | head -1)
    # Prefer workspace over project (resolves local Swift packages)
    ws=""
    if ls *.xcworkspace 1>/dev/null 2>&1; then
      ws=$(ls -d *.xcworkspace | head -1)
      ALL_SCHEMES=$(xcodebuild -workspace "$ws" -list 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+/{print; next} found{exit}' | xargs -I{} echo {})
    else
      ALL_SCHEMES=$(xcodebuild -project "$proj" -list 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+/{print; next} found{exit}' | xargs -I{} echo {})
    fi
    SCHEME=$(echo "$ALL_SCHEMES" | grep -x "$app_name" | head -1)
    [ -z "$SCHEME" ] && SCHEME=$(echo "$ALL_SCHEMES" | head -1)
    if [ -n "$SCHEME" ]; then
      BUILD_TYPE="xcode"
    fi
  elif [ -f "Package.swift" ]; then
    BUILD_TYPE="spm"
  fi

  if [ -z "$BUILD_TYPE" ]; then
    echo "### $app_name" >> "$REPORT"
    echo "**Skipped** — no project or package found" >> "$REPORT"
    echo "" >> "$REPORT"
    continue
  fi

  echo "### $app_name" >> "$REPORT"

  build_start=$(date +%s)
  if [ "$BUILD_TYPE" = "xcode" ]; then
    BUILD_TARGET_FLAG="-project $proj"
    [ -n "$ws" ] && BUILD_TARGET_FLAG="-workspace $ws"
    build_output=$(xcodebuild $BUILD_TARGET_FLAG -scheme "$SCHEME" -configuration Debug build -quiet -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1)
  else
    build_output=$(swift build 2>&1)
  fi
  build_exit=$?
  build_end=$(date +%s)
  build_time=$((build_end - build_start))

  if [ $build_exit -eq 0 ]; then
    echo "**PASS** (${build_time}s)" >> "$REPORT"
    BUILD_PASS=$((BUILD_PASS + 1))
  else
    echo "**FAIL** (exit $build_exit, ${build_time}s)" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo "$build_output" | tail -20 >> "$REPORT"
    echo '```' >> "$REPORT"
    BUILD_FAIL=$((BUILD_FAIL + 1))
  fi
  echo "" >> "$REPORT"
done

echo "**Summary:** $BUILD_PASS passed, $BUILD_FAIL failed" >> "$REPORT"
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "" >> "$REPORT"

# =============================================================================
# Section 3: Run Tests
# =============================================================================
echo "## Test Results" >> "$REPORT"
echo "" >> "$REPORT"

TEST_PASS=0
TEST_FAIL=0

for app_dir in "$APPS_DIR"/Sane*; do
  [ -d "$app_dir" ] || continue
  app_name=$(basename "$app_dir")

  cd "$app_dir" || continue

  # Check if tests exist
  TEST_TYPE=""
  if ls *.xcodeproj 1>/dev/null 2>&1; then
    proj=$(ls -d *.xcodeproj | head -1)
    ws=""
    if ls *.xcworkspace 1>/dev/null 2>&1; then
      ws=$(ls -d *.xcworkspace | head -1)
      ALL_SCHEMES=$(xcodebuild -workspace "$ws" -list 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+/{print; next} found{exit}' | xargs -I{} echo {})
    else
      ALL_SCHEMES=$(xcodebuild -project "$proj" -list 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+/{print; next} found{exit}' | xargs -I{} echo {})
    fi
    SCHEME=$(echo "$ALL_SCHEMES" | grep -x "$app_name" | head -1)
    [ -z "$SCHEME" ] && SCHEME=$(echo "$ALL_SCHEMES" | head -1)
    if [ -n "$SCHEME" ]; then
      TEST_TYPE="xcode"
    fi
  elif [ -f "Package.swift" ]; then
    TEST_TYPE="spm"
  fi

  if [ -z "$TEST_TYPE" ]; then continue; fi

  echo "### $app_name" >> "$REPORT"

  if [ "$TEST_TYPE" = "xcode" ]; then
    TEST_TARGET_FLAG="-project $proj"
    [ -n "$ws" ] && TEST_TARGET_FLAG="-workspace $ws"
    test_output=$(xcodebuild $TEST_TARGET_FLAG -scheme "$SCHEME" test -quiet -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1)
  else
    test_output=$(swift test 2>&1)
  fi
  test_exit=$?

  if [ $test_exit -eq 0 ]; then
    # Extract test count if available
    test_count=$(echo "$test_output" | grep -oE '[0-9]+ test[s]? passed' | head -1)
    echo "**PASS** ${test_count:-""}" >> "$REPORT"
    TEST_PASS=$((TEST_PASS + 1))
  else
    echo "**FAIL** (exit $test_exit)" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo "$test_output" | grep -E "(FAIL|error:|fatal)" | tail -10 >> "$REPORT"
    echo '```' >> "$REPORT"
    TEST_FAIL=$((TEST_FAIL + 1))
  fi
  echo "" >> "$REPORT"
done

echo "**Summary:** $TEST_PASS passed, $TEST_FAIL failed" >> "$REPORT"
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "" >> "$REPORT"

# =============================================================================
# Section 4: Disk & System Health
# =============================================================================
echo "## System Health" >> "$REPORT"
echo "" >> "$REPORT"

disk_free=$(df -h / | tail -1 | awk '{print $4}')
disk_pct=$(df -h / | tail -1 | awk '{print $5}')
echo "**Disk:** $disk_free free ($disk_pct used)" >> "$REPORT"

# Memory pressure
memory_pressure=$(memory_pressure 2>/dev/null | grep "System-wide" | head -1 || echo "Unknown")
echo "**Memory:** $memory_pressure" >> "$REPORT"

# Uptime
echo "**Uptime:** $(uptime | sed 's/.*up /up /' | sed 's/,.*//')" >> "$REPORT"
echo "" >> "$REPORT"

# =============================================================================
# Footer
# =============================================================================
cat >> "$REPORT" <<EOF

---

**Report generated:** $TIMESTAMP
**Machine:** $(hostname) ($(sysctl -n hw.ncpu) cores, $(sysctl -n hw.memsize | awk '{printf "%.0f GB", $1/1073741824}') RAM)
**Next run:** Tomorrow at 2:00 AM
EOF

echo "Nightly report complete: $REPORT" >&2
