#!/bin/bash
# mini-train-all.sh - Train unified SaneAI model
# Called by LaunchAgent at 3 AM daily
#
# Architecture (Option B): One unified SaneAI model trained on all product data.
# Per-product behavior comes from system prompts at inference time, not separate models.

SCRIPT_DIR="$(dirname "$0")"
LOG_DIR="$HOME/SaneApps/outputs"
PYTHON="$HOME/mlx-env/bin/python3"
mkdir -p "$LOG_DIR"

# Rotate stderr log if >1MB (LaunchAgent appends, never truncates)
STDERR_LOG="$LOG_DIR/training.stderr.log"
if [ -f "$STDERR_LOG" ] && [ "$(stat -f%z "$STDERR_LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
  mv "$STDERR_LOG" "$STDERR_LOG.old"
fi

echo "=== Training SaneAI (unified model) — $(date) ===" >> "$LOG_DIR/training.stdout.log"

# Step 1: Merge latest per-product training data into SaneAI
SANEAI_DIR="$HOME/SaneApps/apps/SaneAI/training_data"
if [ -f "$SANEAI_DIR/merge_training_data.py" ]; then
  "$PYTHON" "$SANEAI_DIR/merge_training_data.py" >> "$LOG_DIR/training.stdout.log" 2>&1
fi

# Step 2: Train the unified model
bash "$SCRIPT_DIR/mini-train.sh" SaneAI
EXIT_CODE=$?
echo "=== SaneAI complete (exit $EXIT_CODE) — $(date) ===" >> "$LOG_DIR/training.stdout.log"
exit $EXIT_CODE
