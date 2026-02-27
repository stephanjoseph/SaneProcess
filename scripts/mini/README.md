# Mac Mini Build Server Scripts

Scripts that run on the Mac mini (M1, 8GB) build server. This is the **source of truth** — edit here, deploy via `deploy.sh`.

## Scripts

| Script | Schedule | Purpose |
|--------|----------|---------|
| `mini-memory-guard.sh` | 5:40 AM daily | Mini hygiene + safe reboot gate (only when idle and needed) |
| `mini-install-memory-guard.sh` | On demand | Installs/updates memory guard LaunchAgent |
| `mini-train.sh` | 3 AM Sunday | MLX LoRA fine-tuning pipeline (sweeps, validation, reporting) |
| `mini-train-all.sh` | 3 AM Sunday | Wrapper that calls mini-train.sh for SaneAI |
| `mini-nightly.sh` | 2 AM daily | Nightly builds + tests for all SaneApps repos |

## Deploying

```bash
# Deploy all mini scripts to the build server
bash scripts/mini/deploy.sh

# Or deploy a single script
scp scripts/mini/mini-train.sh mini:~/SaneApps/infra/scripts/
```

## Architecture

```
LaunchAgent (3 AM Sunday)
  → mini-train-all.sh
    → merge_training_data.py (if exists)
    → mini-train.sh SaneAI
      → git pull (sync training data)
      → sed (per-sweep LR config)
      → mlx_lm lora --train (1000 + 2000 iters)
      → Python validation (13 test cases)
      → Summary report → ~/SaneApps/outputs/training_report_SaneAI.md

LaunchAgent (2 AM)
  → mini-nightly.sh
    → git fetch + pull all repos
    → xcodebuild (build + test each app)
    → System health (disk, memory, uptime)
    → Report → ~/SaneApps/outputs/nightly_report.md

LaunchAgent (5:40 AM)
  → mini-memory-guard.sh
    → health snapshot + stale-process cleanup
    → optional reboot only in safe window and only when mini is idle
```

## Key Details

- **Bash 3.2** — mini runs macOS default bash. No `+=()` arrays, no `<<<` herestrings. Use file-based alternatives.
- **8GB RAM** — training uses ~3.7GB peak. One sweep at a time.
- **Lock files** — both scripts use `mkdir`-based locks with 8-hour stale detection.
- **Logs** — LaunchAgent stderr appends (never truncates). `mini-train-all.sh` rotates at 1MB.

## LaunchAgents (on mini)

```
~/Library/LaunchAgents/com.saneapps.training.plist  → mini-train-all.sh (3 AM Sunday)
~/Library/LaunchAgents/com.saneapps.nightly.plist   → mini-nightly.sh (2 AM)
~/Library/LaunchAgents/com.saneapps.memory-guard.plist → mini-memory-guard.sh (5:40 AM)
```

## Outputs (on mini)

```
~/SaneApps/outputs/training_report_SaneAI.md   # Training results + validation
~/SaneApps/outputs/nightly_report.md            # Build + test results
~/SaneApps/outputs/training.stderr.log          # Training stderr (rotated at 1MB)
~/SaneApps/outputs/training.stdout.log          # Training stdout (appended)
```
