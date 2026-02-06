#!/bin/bash
# frozen_string_literal: true
# nv-audit.sh - Multi-app codebase audit using nv CLI
# Usage: nv-audit.sh [app-name] [-m MODEL]

set -euo pipefail

# Default settings
NV_BIN="/Users/sj/.local/bin/nv"
DEFAULT_MODEL="kimi-fast"
APPS_DIR="/Users/sj/SaneApps/apps"
OUTPUT_DIR="/Users/sj/SaneApps/infra/SaneProcess/outputs/audit"
DATE=$(date +%Y%m%d-%H%M%S)

# Available apps
ALL_APPS=("SaneBar" "SaneClick" "SaneClip" "SaneHosts" "SaneSync" "SaneVideo")

# Audit prompt
AUDIT_PROMPT="Review for: (1) bugs and logic errors, (2) security issues, (3) deprecated API usage, (4) memory leaks or retain cycles, (5) concurrency issues. One line per finding, prefix with severity [HIGH/MED/LOW]."

# Parse arguments
MODEL="$DEFAULT_MODEL"
TARGET_APP=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -m)
      MODEL="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      TARGET_APP="$1"
      shift
      ;;
  esac
done

# Check if nv exists
if [[ ! -x "$NV_BIN" ]]; then
  echo "Error: nv CLI not found at $NV_BIN" >&2
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Determine which apps to audit
APPS_TO_AUDIT=()

if [[ -n "$TARGET_APP" ]]; then
  # Specific app requested
  APPS_TO_AUDIT=("$TARGET_APP")
elif [[ -f "$(pwd)/Package.swift" ]] || [[ -f "$(pwd)/*.xcodeproj" ]] || [[ -d "$(pwd)/Sources" ]]; then
  # We're inside a project - detect which one
  CURRENT_DIR=$(basename "$(pwd)")
  if [[ " ${ALL_APPS[*]} " =~ " ${CURRENT_DIR} " ]]; then
    APPS_TO_AUDIT=("$CURRENT_DIR")
    echo "Detected current project: $CURRENT_DIR"
  else
    echo "Warning: Couldn't detect project, auditing all apps" >&2
    APPS_TO_AUDIT=("${ALL_APPS[@]}")
  fi
else
  # No args, audit all
  APPS_TO_AUDIT=("${ALL_APPS[@]}")
fi

# Summary tracking
declare -A HIGH_COUNT
declare -A MED_COUNT
declare -A LOW_COUNT

# Function to find source directory
find_source_dir() {
  local app_path="$1"

  if [[ -d "$app_path/Sources" ]]; then
    echo "$app_path/Sources"
  elif [[ -d "$app_path/src" ]]; then
    echo "$app_path/src"
  elif [[ -d "$app_path/$app_path" ]]; then
    echo "$app_path/$app_path"
  else
    # Fallback to app directory itself
    echo "$app_path"
  fi
}

# Function to audit a single app
audit_app() {
  local app_name="$1"
  local app_path="$APPS_DIR/$app_name"

  echo "[auditing $app_name...]"

  # Check if app exists
  if [[ ! -d "$app_path" ]]; then
    echo "  ⚠️  Skipping $app_name: directory not found at $app_path" >&2
    return 1
  fi

  # Find source directory
  local src_dir=$(find_source_dir "$app_path")

  # Check if source directory has .swift files
  if ! find "$src_dir" -name "*.swift" -type f | grep -q .; then
    echo "  ⚠️  Skipping $app_name: no .swift files found in $src_dir" >&2
    return 1
  fi

  # Create output file
  local output_file="$OUTPUT_DIR/${app_name}-${DATE}.md"

  # Run audit
  echo "# $app_name Audit - $DATE" > "$output_file"
  echo "" >> "$output_file"
  echo "Model: $MODEL" >> "$output_file"
  echo "Source: $src_dir" >> "$output_file"
  echo "" >> "$output_file"
  echo "## Findings" >> "$output_file"
  echo "" >> "$output_file"

  # Run nv sweep - use ** for recursive glob
  local glob_pattern="$src_dir/**/*.swift"

  if "$NV_BIN" --sweep "$glob_pattern" -m "$MODEL" "$AUDIT_PROMPT" >> "$output_file" 2>&1; then
    echo "  ✅ Audit complete: $output_file"
  else
    echo "  ⚠️  Audit completed with errors (see $output_file)" >&2
  fi

  # Count severities
  HIGH_COUNT[$app_name]=$(grep -c "\[HIGH\]" "$output_file" || echo "0")
  MED_COUNT[$app_name]=$(grep -c "\[MED\]" "$output_file" || echo "0")
  LOW_COUNT[$app_name]=$(grep -c "\[LOW\]" "$output_file" || echo "0")

  return 0
}

# Main audit loop
echo "Starting audit with model: $MODEL"
echo "Apps to audit: ${APPS_TO_AUDIT[*]}"
echo ""

SUCCESSFUL_AUDITS=0
FAILED_AUDITS=0

for app in "${APPS_TO_AUDIT[@]}"; do
  if audit_app "$app"; then
    ((SUCCESSFUL_AUDITS++))
  else
    ((FAILED_AUDITS++))
  fi
  echo ""
done

# Print summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AUDIT SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "%-15s %6s %6s %6s\n" "App" "HIGH" "MED" "LOW"
echo "───────────────────────────────────────────"

for app in "${APPS_TO_AUDIT[@]}"; do
  if [[ -n "${HIGH_COUNT[$app]:-}" ]]; then
    printf "%-15s %6d %6d %6d\n" \
      "$app" \
      "${HIGH_COUNT[$app]}" \
      "${MED_COUNT[$app]}" \
      "${LOW_COUNT[$app]}"
  fi
done

echo ""
echo "Successful audits: $SUCCESSFUL_AUDITS"
echo "Failed audits: $FAILED_AUDITS"
echo ""
echo "Results saved to: $OUTPUT_DIR"
