#!/bin/bash
# frozen_string_literal: true
# Build log filter using nv CLI
# Usage: xcodebuild ... 2>&1 | nv-buildlog.sh
#    or: nv-buildlog.sh <logfile>

set -euo pipefail

# Default model
MODEL="kimi-fast"
BUGS_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    --bugs-only)
      BUGS_ONLY=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# Read input from file or stdin
if [[ $# -eq 1 ]]; then
  LOG_FILE="$1"
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: File not found: $LOG_FILE" >&2
    exit 1
  fi
  INPUT=$(cat "$LOG_FILE")
else
  INPUT=$(cat)
fi

# Extract warnings and errors
FILTERED=$(echo "$INPUT" | grep -E '(warning:|error:|note:)' || true)

if [[ -z "$FILTERED" ]]; then
  echo "✅ No warnings or errors found" >&2
  exit 0
fi

# Deduplicate (same warning from multiple targets)
DEDUPED=$(echo "$FILTERED" | sort -u)

LINE_COUNT=$(echo "$DEDUPED" | wc -l | tr -d ' ')
echo "🔍 Analyzing $LINE_COUNT unique warnings/errors..." >&2

# Send to nv for classification
PROMPT="Classify each Xcode warning/error. For each one, output ONE line in this format:
[BUG|STYLE|NOISE|DEPRECATION] file:line — description
BUG = actual code problem that could cause crashes or incorrect behavior
STYLE = code quality issue but not a bug
NOISE = build system noise, linker warnings, deployment target mismatches
DEPRECATION = deprecated API that needs updating
Sort by severity (BUG first)."

CLASSIFIED=$(echo "$DEDUPED" | /Users/sj/.local/bin/nv -m "$MODEL" "$PROMPT")

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Count by category
BUG_COUNT=0
DEPRECATION_COUNT=0
STYLE_COUNT=0
NOISE_COUNT=0

# Process and color output
echo "" # Blank line before output
while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    continue
  fi

  # Extract category
  if [[ "$line" =~ ^\[BUG\] ]]; then
    BUG_COUNT=$((BUG_COUNT + 1))
    if [[ "$BUGS_ONLY" == false ]]; then
      echo -e "${RED}$line${RESET}"
    else
      echo -e "${RED}$line${RESET}"
    fi
  elif [[ "$line" =~ ^\[DEPRECATION\] ]]; then
    DEPRECATION_COUNT=$((DEPRECATION_COUNT + 1))
    if [[ "$BUGS_ONLY" == false ]]; then
      echo -e "${YELLOW}$line${RESET}"
    fi
  elif [[ "$line" =~ ^\[STYLE\] ]]; then
    STYLE_COUNT=$((STYLE_COUNT + 1))
    if [[ "$BUGS_ONLY" == false ]]; then
      echo -e "${BLUE}$line${RESET}"
    fi
  elif [[ "$line" =~ ^\[NOISE\] ]]; then
    NOISE_COUNT=$((NOISE_COUNT + 1))
    if [[ "$BUGS_ONLY" == false ]]; then
      echo -e "${GRAY}$line${RESET}"
    fi
  else
    # Unknown format, print as-is
    if [[ "$BUGS_ONLY" == false ]]; then
      echo "$line"
    fi
  fi
done <<< "$CLASSIFIED"

# Summary
echo "" # Blank line before summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $BUG_COUNT -gt 0 ]]; then
  echo -e "${RED}🐛 $BUG_COUNT bugs${RESET}"
fi

if [[ $DEPRECATION_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  $DEPRECATION_COUNT deprecations${RESET}"
fi

if [[ "$BUGS_ONLY" == false ]]; then
  if [[ $STYLE_COUNT -gt 0 ]]; then
    echo -e "${BLUE}🎨 $STYLE_COUNT style issues${RESET}"
  fi

  if [[ $NOISE_COUNT -gt 0 ]]; then
    echo -e "${GRAY}🔇 $NOISE_COUNT noise${RESET}"
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit with error code if bugs found
if [[ $BUG_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
