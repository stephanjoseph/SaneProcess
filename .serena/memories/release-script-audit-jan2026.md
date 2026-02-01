# Release Script Audit - January 30, 2026

## The Problem
Cross-project audit found Sparkle signing bugs in release scripts across ALL SaneApps projects. The bugs would cause broken auto-updates for users.

## What Was Fixed

### SaneClick (`scripts/release.sh`)
- Added missing `<description>` CDATA tag
- Changed upload instructions from GitHub Releases to Cloudflare R2
- Added `.meta` file output

### SaneClip (`scripts/release.sh`)
- Added **entire Sparkle signing section** (was completely missing)

### SaneHosts (`scripts/build_release.sh`, `scripts/generate_appcast.sh`)
- Fixed `sparkle:version` from VERSION to BUILD_NUMBER

### SaneProcess Template (`scripts/release.sh`, `scripts/full_release.sh`)
- Replaced echo statements with heredoc (fixes leading-space corruption)
- Fixed `sparkle:version` to use BUILD_NUMBER
- Fixed URL pattern to `dist.X.com/updates/`
- Removed Homebrew references

## The Rules (NEVER BREAK)
1. `sparkle:version` = BUILD_NUMBER (numeric CFBundleVersion)
2. `sparkle:shortVersionString` = VERSION (semantic version)
3. Use heredoc (`cat <<EOF`) for appcast templates, NEVER echo
4. URL: `https://dist.{app}.com/updates/{App}-{version}.dmg`
5. Always generate `.meta` file alongside DMG
6. Distribution: Cloudflare R2, NOT GitHub Releases
