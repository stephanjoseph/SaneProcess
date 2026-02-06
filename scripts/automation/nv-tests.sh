#!/bin/bash
# frozen_string_literal: true
# Test case generator using nv CLI
# Usage: nv-tests.sh <source-file.swift> [output-dir]

set -euo pipefail

# Default model
MODEL="or-kimi"
REVIEW=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--model)
      MODEL="$2"
      shift 2
      ;;
    --review)
      REVIEW=true
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

# Check arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: nv-tests.sh [-m MODEL] [--review] <source-file.swift> [output-dir]" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  -m, --model MODEL    Override model (default: or-kimi)" >&2
  echo "  --review             Send generated tests back for quality check" >&2
  exit 1
fi

SOURCE_FILE="$1"
OUTPUT_DIR="${2:-}"

# Validate source file
if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: File not found: $SOURCE_FILE" >&2
  exit 1
fi

if [[ ! "$SOURCE_FILE" =~ \.swift$ ]]; then
  echo "Error: Not a Swift file: $SOURCE_FILE" >&2
  exit 1
fi

# Check file size
LINE_COUNT=$(wc -l < "$SOURCE_FILE")
if [[ $LINE_COUNT -gt 500 ]]; then
  echo "⚠️  Warning: File has $LINE_COUNT lines (>500). Generated tests may need manual review." >&2
fi

# Check for public methods
if ! grep -qE '^\s*(public|open|internal)\s+(func|var|let|class|struct|enum|actor)' "$SOURCE_FILE"; then
  echo "⚠️  No public/testable methods found in $SOURCE_FILE. Skipping." >&2
  exit 0
fi

# Generate test prompt
PROMPT="Generate Swift Testing test cases for this code. Use: import Testing, @Test attribute, #expect() assertions, struct-based test suites (not XCTest classes). Include edge cases: nil inputs, empty collections, boundary values. Return ONLY the test code, no explanations."

# Generate tests
echo "🧪 Generating tests for $(basename "$SOURCE_FILE")..." >&2
TEST_CODE=$(/Users/sj/.local/bin/nv -f "$SOURCE_FILE" -m "$MODEL" "$PROMPT")

if [[ -z "$TEST_CODE" ]]; then
  echo "Error: nv returned empty response" >&2
  exit 1
fi

# Optional review pass
if [[ "$REVIEW" == true ]]; then
  echo "🔍 Reviewing generated tests..." >&2
  REVIEW_PROMPT="Review these Swift Testing test cases. Check for:
1. Are all edge cases covered?
2. Any tautologies (#expect(true), #expect(x == x))?
3. Are assertions meaningful?
4. Any missing async/throws handling?
Return: 'PASS' if good, or 'IMPROVE: [specific issues]'"

  REVIEW_RESULT=$(echo "$TEST_CODE" | /Users/sj/.local/bin/nv -m "$MODEL" "$REVIEW_PROMPT")

  if [[ ! "$REVIEW_RESULT" =~ ^PASS ]]; then
    echo "⚠️  Review found issues:" >&2
    echo "$REVIEW_RESULT" >&2
  else
    echo "✅ Tests passed review" >&2
  fi
fi

# Output handling
if [[ -n "$OUTPUT_DIR" ]]; then
  # Create output directory if needed
  mkdir -p "$OUTPUT_DIR"

  # Generate output filename
  BASENAME=$(basename "$SOURCE_FILE" .swift)
  OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}Tests.swift"

  echo "$TEST_CODE" > "$OUTPUT_FILE"
  echo "✅ Tests written to: $OUTPUT_FILE" >&2

  # Show line count
  TEST_LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
  echo "   Generated $TEST_LINE_COUNT lines of test code" >&2
else
  # Print to stdout
  echo "$TEST_CODE"
fi
