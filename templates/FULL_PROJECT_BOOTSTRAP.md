# Full Sane* Project Bootstrap Guide

> **Complete checklist for launching a new macOS app from scratch to distribution**
> Last updated: 2026-01-20 (Migrated to sane-apps org, removed Homebrew, added paid distribution model)

---

## Part 0: Execution Environment

> **Before starting a bootstrap, set up your environment for long-running tasks.**

### 0.1 Prevent Sleep During Long Tasks

Start caffeinate at the beginning of any bootstrap session:

```bash
# Prevent sleep during bootstrap (kill when done)
caffeinate -d -i -m -s &
CAFFEINATE_PID=$!
echo "caffeinate running as PID $CAFFEINATE_PID"
```

Flags:
- `-d` - Prevent display sleep
- `-i` - Prevent idle sleep
- `-m` - Prevent disk sleep
- `-s` - Prevent system sleep when on AC power

**Kill when done:**
```bash
kill $CAFFEINATE_PID
```

### 0.2 Kill Stale Claude Processes

Before starting a new bootstrap, clean up any zombie Claude processes:

```bash
# Check for stale Claude processes
ps aux | grep -E 'claude|node.*mcp' | grep -v grep

# Kill stale processes if found (be careful!)
pkill -f 'claude.*dangerously-skip-permissions'
```

### 0.3 RESEARCH.md Requirement

**Every project MUST have a RESEARCH.md** as the single source of truth for:

1. **API Research** - External APIs, SDKs, dependencies with verified documentation
2. **Architecture Decisions** - Why certain patterns were chosen
3. **State Machine Diagrams** - Mermaid diagrams for all stateful components
4. **Competitor Analysis** - How similar apps solve the problem
5. **Platform Requirements** - macOS version constraints, entitlements, permissions

**Template location:** `SaneProcess/templates/RESEARCH-TEMPLATE.md`

### 0.4 State Machine Documentation

Every RESEARCH.md must include state machine diagrams using the 13-section audit format:

1. State diagrams (Mermaid)
2. State details table
3. Transitions table
4. Sub-state machines
5. Service dependencies
6. **Concurrency model** (threads, races)
7. **Error handling matrix**
8. Notifications (events)
9. External API calls
10. Entry/Exit actions
11. **Invariants**
12. Security considerations
13. Test coverage checklist

> Key insight: State diagrams alone show happy paths. Auditors need error paths, races, and invariants.

### 0.5 Subagent Usage

For bootstrap tasks, use subagents with verification:

| Task | Subagent | Verification |
|------|----------|--------------|
| Codebase exploration | `Explore` | Review returned file list |
| Architecture planning | `Plan` | Read written plan file |
| Code review | `feature-dev:code-reviewer` | Review issues found |
| Research | `general-purpose` | Verify sources cited |

**Always verify subagent work:**
```
1. Subagent completes → Read its output
2. Verify claims → Spot-check files/APIs mentioned
3. Don't blindly trust → Subagents can hallucinate too
```

---

## Quick Reference

| Item | Value |
|------|-------|
| **Team ID** | `M78L6FXD48` |
| **Signing Identity** | `Developer ID Application: Stephan Joseph (M78L6FXD48)` |
| **Keychain Profile** | `notarytool` |
| **API Key ID** | `7LMFF3A258` |
| **API Key Issuer** | `c98b1e0a-8d10-4fce-a417-536b31c09bfb` |
| **GitHub Org** | `sane-apps` |
| **Apple ID** | `stephanjoseph2007@gmail.com` |

## Distribution Model

| Channel | What Users Get | Cost |
|---------|----------------|------|
| **Website** | Built DMG, ready to install | $5 |
| **GitHub** | Source code (clone & build yourself) | Free |

**No Homebrew distribution.** No free DMGs on GitHub releases.

---

## Part 1: Project Structure

### Directory Layout
```
ProjectName/
├── .claude/                    # Claude Code config
│   ├── .gitignore
│   ├── settings.json
│   └── rules/                  # Copy from SaneProcess
├── RESEARCH.md                 # Single source of truth (state machines, APIs, decisions)
├── .github/
│   ├── FUNDING.yml
│   ├── workflows/
│   │   └── weekly-release.yml
│   ├── ISSUE_TEMPLATE/
│   │   └── bug_report.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/                       # GitHub Pages
│   ├── index.html
│   ├── CNAME
│   ├── appcast.xml
│   ├── robots.txt
│   ├── sitemap.xml
│   └── images/
│       └── og-image.png
├── fastlane/
│   ├── Fastfile
│   ├── Appfile
│   └── keys/                   # Git-ignored!
│       └── AuthKey_7LMFF3A258.p8
├── scripts/
│   ├── release.sh
│   ├── full_release.sh
│   └── generate_dmg_background.swift
├── ProjectName/
│   ├── Info.plist
│   ├── ProjectName.entitlements
│   └── [Source files]
├── .mcp.json
├── CLAUDE.md
├── CONTRIBUTING.md
├── README.md
├── PRIVACY.md
├── LICENSE
└── project.yml                 # XcodeGen
```

---

## Part 2: Credentials Setup

### 2.1 Notarization Keychain Profile (One-Time)

Already configured. Verify with:
```bash
xcrun notarytool history --keychain-profile "notarytool"
```

If missing, create:
```bash
xcrun notarytool store-credentials "notarytool" \
  --apple-id stephanjoseph2007@gmail.com \
  --password <app-specific-password> \
  --team-id M78L6FXD48
```

### 2.2 Sparkle EdDSA Keys (Per-Project)

Generate new key pair:
```bash
# Using Sparkle's generate_keys tool
/path/to/Sparkle/bin/generate_keys
```

Store private key in Keychain:
```bash
security add-generic-password \
  -s "https://sparkle-project.org" \
  -a "ed25519" \
  -w "<base64-private-key>" \
  -T "" \
  -U
```

Or store in `fastlane/keys/sparkle_private_key.txt` (git-ignored).

### 2.3 API Key File

Copy from existing project:
```bash
cp /Users/sj/SaneBar/fastlane/keys/AuthKey_7LMFF3A258.p8 \
   /Users/sj/Projects/NewProject/fastlane/keys/
```

### 2.4 GitHub Secrets (For CI/CD)

Set in repo Settings → Secrets → Actions:

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded .p12 certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Certificate password |
| `KEYCHAIN_PASSWORD` | Temporary keychain password |
| `APPLE_TEAM_ID` | `M78L6FXD48` |
| `NOTARY_API_KEY` | Contents of AuthKey_7LMFF3A258.p8 |
| `NOTARY_API_KEY_ID` | `7LMFF3A258` |
| `NOTARY_API_ISSUER_ID` | `c98b1e0a-8d10-4fce-a417-536b31c09bfb` |

---

## Part 3: Sparkle Auto-Update

### 3.1 Info.plist Configuration

```xml
<key>SUFeedURL</key>
<string>https://projectname.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>[YOUR-PUBLIC-EDDSA-KEY]</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUEnableSystemProfiling</key>
<false/>
```

> **CRITICAL**: `SUFeedURL` is REQUIRED for Sparkle to work. Without it, "Check for Updates" does nothing.
> Learned from SaneClip audit (2026-01-19) - missing this key breaks auto-updates silently.

### 3.2 UpdateService.swift

```swift
import Sparkle

@MainActor
class UpdateService: NSObject, ObservableObject {
    private var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
```

### 3.3 Sparkle Dependency (project.yml)

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.6.0
```

### 3.4 appcast.xml Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ProjectName Updates</title>
    <link>https://projectname.com/appcast.xml</link>
    <item>
      <title>1.0.0</title>
      <pubDate>Mon, 20 Jan 2026 12:00:00 -0500</pubDate>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://github.com/sane-apps/ProjectName/releases/download/v1.0.0/ProjectName-1.0.0.dmg"
        sparkle:version="1.0.0"
        sparkle:shortVersionString="1.0.0"
        length="2000000"
        type="application/x-apple-diskimage"
        sparkle:edSignature="[SIGNATURE]"/>
    </item>
  </channel>
</rss>
```

### 3.5 Menu Bar App Configuration

For menu bar apps (no dock icon):

```xml
<key>LSUIElement</key>
<true/>
```

This hides the app from the Dock and Cmd+Tab switcher.

---

## Part 3B: Required Entitlements & Architecture

### Common Entitlements (ProjectName.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for AppleScript automation (admin prompts, etc.) -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>

    <!-- Disable sandbox if app needs system file access -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

> **Note**: Both SaneBar and SaneClip require `automation.apple-events` for AppleScript-based operations.
> Without this entitlement, notarization will succeed but AppleScript calls fail at runtime.

### Architecture Recommendation

For new projects (2024+), target arm64 only:

```yaml
# In project.yml
settings:
  ARCHS: arm64
  VALID_ARCHS: arm64
```

Benefits:
- Smaller binary size
- No Rosetta overhead
- Intel Macs are legacy (last sold 2021)

---

## Part 4: DMG & Release Scripts

### 4.1 Notarization Preflight (CRITICAL)

Before notarizing, check for issues that cause rejection:

```bash
# Check hardened runtime is enabled
codesign -dv --verbose=4 "path/to/App.app" 2>&1 | grep "flags=.*runtime"

# Remove get-task-allow from embedded frameworks (causes rejection)
for framework in build/export/App.app/Contents/Frameworks/*.framework; do
    codesign --remove-signature "$framework" 2>/dev/null || true
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime "$framework"
done

# Verify no forbidden entitlements
codesign -d --entitlements :- "path/to/App.app" 2>&1 | grep -E "get-task-allow|disable-library-validation"
```

**Common notarization failures:**
| Error | Fix |
|-------|-----|
| Missing hardened runtime | Add `ENABLE_HARDENED_RUNTIME = YES` to xcconfig |
| get-task-allow in framework | Re-sign frameworks without debug entitlements |
| Invalid signature | Remove and re-sign the entire .app |
| Binary not signed | Check all binaries in Contents/MacOS/ |

### 4.2 release.sh (Core)

```bash
#!/bin/bash
set -e

APP_NAME="ProjectName"
BUNDLE_ID="com.projectname.app"
TEAM_ID="M78L6FXD48"
SIGNING_IDENTITY="Developer ID Application: Stephan Joseph (M78L6FXD48)"

# Build
xcodebuild archive \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -archivePath "build/${APP_NAME}.xcarchive" \
  -configuration Release \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
  DEVELOPMENT_TEAM="${TEAM_ID}"

# Export
xcodebuild -exportArchive \
  -archivePath "build/${APP_NAME}.xcarchive" \
  -exportPath "build/export" \
  -exportOptionsPlist ExportOptions.plist

# Create DMG
hdiutil create -volname "${APP_NAME}" \
  -srcfolder "build/export/${APP_NAME}.app" \
  -ov -format UDZO \
  "releases/${APP_NAME}-${VERSION}.dmg"

# Sign DMG
codesign --force --sign "${SIGNING_IDENTITY}" \
  --options runtime \
  "releases/${APP_NAME}-${VERSION}.dmg"

# Notarize
xcrun notarytool submit "releases/${APP_NAME}-${VERSION}.dmg" \
  --keychain-profile "notarytool" \
  --wait

# Staple
xcrun stapler staple "releases/${APP_NAME}-${VERSION}.dmg"

# Output SHA256 for verification
SHA256=$(shasum -a 256 "releases/${APP_NAME}-${VERSION}.dmg" | awk '{print $1}')
echo "SHA256: ${SHA256}"
echo "Upload releases/${APP_NAME}-${VERSION}.dmg to Lemon Squeezy"
```

### 4.3 full_release.sh (Comprehensive)

This script handles the complete release cycle including version bumps and appcast generation:

```bash
#!/bin/bash
set -e

# Configuration
APP_NAME="ProjectName"
BUNDLE_ID="com.projectname.app"
TEAM_ID="M78L6FXD48"
SIGNING_IDENTITY="Developer ID Application: Stephan Joseph (M78L6FXD48)"
SPARKLE_KEY_ACCOUNT="ed25519"  # Keychain account for Sparkle private key
DMG_HOSTING_URL="https://projectname.com/downloads"  # Where paid DMGs are served

# Parse arguments
BUMP_TYPE="${1:-patch}"  # major, minor, patch

# Get current version from project.yml
CURRENT_VERSION=$(grep "MARKETING_VERSION" Config/Shared.xcconfig | cut -d'=' -f2 | tr -d ' ')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump version
case "$BUMP_TYPE" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Releasing ${APP_NAME} v${NEW_VERSION}"

# Update version in xcconfig
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = ${NEW_VERSION}/" Config/Shared.xcconfig

# Build, sign, notarize (as in release.sh above)
# ... [same as release.sh] ...

# Generate appcast entry
DMG_SIZE=$(stat -f%z "releases/${APP_NAME}-${NEW_VERSION}.dmg")
DMG_DATE=$(date -R)

# Sign with Sparkle EdDSA key
SIGNATURE=$(./bin/sign_update "releases/${APP_NAME}-${NEW_VERSION}.dmg" 2>&1 | grep "sparkle:edSignature" | cut -d'"' -f2)

# Append to appcast.xml (URL points to your download server, not GitHub)
cat >> docs/appcast.xml << EOF
    <item>
      <title>${NEW_VERSION}</title>
      <pubDate>${DMG_DATE}</pubDate>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DMG_HOSTING_URL}/${APP_NAME}-${NEW_VERSION}.dmg"
        sparkle:version="${NEW_VERSION}"
        sparkle:shortVersionString="${NEW_VERSION}"
        length="${DMG_SIZE}"
        type="application/x-apple-diskimage"
        sparkle:edSignature="${SIGNATURE}"/>
    </item>
EOF

# Git commit and push (source code only, no DMG)
git add -A
git commit -m "Release v${NEW_VERSION}"
git tag "v${NEW_VERSION}"
git push origin main --tags

# Manual step: Upload DMG to Lemon Squeezy or your download server
echo ""
echo "=== MANUAL STEPS ==="
echo "1. Upload releases/${APP_NAME}-${NEW_VERSION}.dmg to Lemon Squeezy"
echo "2. Update download link on website"
echo "3. Verify appcast.xml URL resolves correctly"
```

### 4.4 DMG Background Generator

```swift
#!/usr/bin/env swift
import AppKit

let width: CGFloat = 660
let height: CGFloat = 400
let scale: CGFloat = 2  // Retina

let image = NSImage(size: NSSize(width: width * scale, height: height * scale))
image.lockFocus()

// Dark background
NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: width * scale, height: height * scale).fill()

// Title
let title = "ProjectName"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 36 * scale),
    .foregroundColor: NSColor.white
]
title.draw(at: NSPoint(x: 200 * scale, y: 300 * scale), withAttributes: titleAttrs)

// Subtitle
let subtitle = "Drag to Applications to install"
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14 * scale),
    .foregroundColor: NSColor.lightGray
]
subtitle.draw(at: NSPoint(x: 200 * scale, y: 260 * scale), withAttributes: subAttrs)

image.unlockFocus()

// Save
let data = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: data)!
let png = bitmap.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "scripts/dmg-resources/dmg-background.png"))
```

---

## Part 5: GitHub Pages Website

### 5.1 CNAME
```
projectname.com
```

### 5.2 robots.txt
```
User-agent: *
Allow: /
Sitemap: https://projectname.com/sitemap.xml
```

### 5.3 sitemap.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://projectname.com/</loc>
    <lastmod>2026-01-18</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
```

### 5.4 Essential index.html Sections

1. **SEO Meta Tags** (og:image, twitter:card, JSON-LD schema)
2. **Hero** (headline, badges, download buttons)
3. **Features** (grid with icons)
4. **Comparison Table** (vs competitors)
5. **Support/Donate** (GitHub Sponsors + crypto)
6. **Footer** (privacy pledge, links)

### 5.5 Open Graph Image Specs
- **Dimensions**: 1200x630px
- **Format**: PNG
- **Location**: `/docs/images/og-image.png`

---

## Part 6: Monetization

### 6.1 Distribution Model

| Channel | What Users Get | Cost |
|---------|----------------|------|
| **Website** | Built DMG, ready to install | $5 |
| **GitHub** | Source code (clone & build yourself) | Free |

### 6.2 Payment Setup (Lemon Squeezy)

- Store: `[appname].lemonsqueezy.com`
- Standard price: $5 one-time
- Deliver DMG download link after payment

### 6.3 FUNDING.yml

```yaml
github: sane-apps
custom: ["https://projectname.com"]
```

### 6.4 Optional: GitHub Sponsors

**GitHub Sponsors**: `https://github.com/sponsors/sane-apps`

For users who want to support beyond the $5.

---

## Part 7: GitHub Templates

### 7.1 Bug Report Template (.github/ISSUE_TEMPLATE/bug_report.yml)

```yaml
name: Bug Report
description: Report a bug
labels: ["bug"]
body:
  - type: input
    id: version
    attributes:
      label: App Version
    validations:
      required: true
  - type: input
    id: macos
    attributes:
      label: macOS Version
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Description
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
    validations:
      required: true
```

### 7.2 PR Template (.github/PULL_REQUEST_TEMPLATE.md)

```markdown
## Summary
Brief description

## Changes
- Change 1
- Change 2

## Testing
- [ ] Ran ./scripts/release.sh --skip-notarize
- [ ] Tested on macOS
- [ ] No regressions

## Checklist
- [ ] Code follows style guide
- [ ] Self-reviewed
- [ ] Updated docs if needed
```

---

## Part 8: Fastlane Configuration

### 8.1 Appfile

```ruby
app_identifier("com.projectname.app")
apple_id("stephanjoseph2007@gmail.com")
team_id("M78L6FXD48")
```

### 8.2 Fastfile

```ruby
default_platform(:mac)

API_KEY_ID = "7LMFF3A258"
API_KEY_ISSUER_ID = "c98b1e0a-8d10-4fce-a417-536b31c09bfb"
API_KEY_PATH = "keys/AuthKey_7LMFF3A258.p8"

platform :mac do
  lane :notarize_dmg do |options|
    notarize(
      package: options[:dmg_path],
      api_key_path: API_KEY_PATH,
      api_key: API_KEY_ID,
      api_key_issuer: API_KEY_ISSUER_ID,
      print_log: true
    )
  end
end
```

---

## Part 9: Claude Code Setup

### 9.1 .mcp.json

```json
{
  "mcpServers": {
    "apple-docs": {
      "command": "npx",
      "args": ["-y", "@mweinbach/apple-docs-mcp@latest"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

### 9.2 Shell Alias

Add to `~/.zshrc`:
```bash
alias pn='cd /Users/sj/Projects/ProjectName && claude --dangerously-skip-permissions'
alias gpn='cd /Users/sj/Projects/ProjectName && gemini'
```

---

## Part 10: Swift Style Guide

### Core Standards

| Pattern | Use | Don't Use |
|---------|-----|-----------|
| State | `@Observable` | `@StateObject` |
| Testing | Swift Testing | XCTest |
| Services | `actor` | Singletons |
| Errors | Typed enums | `NSError` |
| Models | `struct` + Codable | Mutable classes |

### View Body Limit
- Max 50 lines
- Extract into subviews

### Swift Testing
```swift
import Testing

struct MyTests {
    @Test("Description")
    func testSomething() {
        #expect(result == expected)
    }
}
```

---

## Part 11: Release Checklist

```
[ ] Version bumped in project.yml
[ ] xcodegen generate
[ ] Tests pass
[ ] Build succeeds
[ ] DMG created
[ ] DMG signed
[ ] Notarized
[ ] Stapled
[ ] appcast.xml updated (for Sparkle auto-updates)
[ ] Upload DMG to payment provider (Lemon Squeezy)
[ ] Announce on social media
```

**Note:** No GitHub releases with DMGs. No Homebrew. Paid users get DMG from website.

---

## Part 12: Reference Projects

| Project | Location | Notes |
|---------|----------|-------|
| **SaneBar** | `~/SaneApps/apps/SaneBar` | Full mature setup, menu bar app, weekly GitHub Actions release |
| **SaneClip** | `~/SaneApps/apps/SaneClip` | Clipboard manager, $5 paid |
| **SaneSync** | `~/SaneApps/apps/SaneSync` | Cloud sync (WIP) |
| **SaneHosts** | `~/SaneApps/apps/SaneHosts` | Hosts file manager |
| **SaneProcess** | `~/SaneApps/infra/SaneProcess` | Hook master, templates |

### Known Issues in Reference Projects

| Project | Issue | Status |
|---------|-------|--------|
| **SaneClip** | Missing `SUFeedURL` in Sparkle config - auto-updates broken | **FIX NEEDED** |

> Audit date: 2026-01-19. Run periodic audits to catch config drift.

---

## Summary: New Project Bootstrap

### Phase 0: Environment Setup
```bash
caffeinate -d -i -m -s &  # Prevent sleep
ps aux | grep claude | grep -v grep  # Check for stale processes
```

### Phase 1: Research & Planning
1. Create RESEARCH.md with:
   - API research (use apple-docs, context7, github MCPs)
   - State machine diagrams (Mermaid)
   - Architecture decisions
2. Verify all APIs exist before writing code

### Phase 2: Project Setup
3. Create repo and clone
4. Copy `.claude/`, `.mcp.json`, `CLAUDE.md` from template
5. Copy `scripts/release.sh` from SaneBar
6. Copy `fastlane/` folder, update bundle ID

### Phase 3: Build & Test
7. Write code following RESEARCH.md design
8. Tests must pass (Swift Testing, not XCTest)
9. Build must succeed

### Phase 4: Distribution Setup
10. Set up `docs/` with CNAME, index.html skeleton
11. Generate Sparkle keys, add to Info.plist
12. Set up Lemon Squeezy store for $5 DMG sales
13. Add alias to `~/.zshrc`

### Phase 5: Release
14. First release: `./scripts/release.sh`
15. Upload DMG to Lemon Squeezy
16. Kill caffeinate when done

**Key differences:**
- Research comes FIRST, not during coding
- No Homebrew, no free DMGs on GitHub
- Source free on GitHub, built DMG costs $5 on website
