# SaneApps Rebranding Plan: Personal Name → Sane Apps

**Created:** 2026-01-19
**Updated:** 2026-01-19 (Phase 1, 2, 4 completed)
**Goal:** Remove all personal name references (Stephan Joseph, stephanjoseph) and migrate to sane-apps org

---

## Current State

### GitHub Organization: ✅ EXISTS
- **Org:** `sane-apps` (https://github.com/sane-apps)
- **Existing repos in org:**
  - `sane-apps.github.io` - Main org site
  - `sanesync.com` - SaneSync website

### Repos to Transfer (from stephanjoseph → sane-apps)

| Repo | Visibility After | Notes |
|------|------------------|-------|
| SaneBar | Public | Main product |
| SaneClip | Public | Main product |
| SaneProcess | Public | Open source infra |
| SaneHosts | Public | Main product |
| SaneSync | Public | Main product |
| SaneAI | Public | Main product |
| SaneVideo | **Private** | Keep private |
| Sane-Mem | **Private** | Fork - not directly used |
| Sane-AppleDocs | **Private** | Fork - not directly used |
| Sane-XcodeBuildMCP | **Private** | Fork - not directly used |

**Note:** Fork repos can be private - MCP tools use npm packages, not GitHub URLs.

---

## Phase 1: Transfer Repos to Org

### Step 1: Transfer each repo
For each repo, go to: `Settings → Danger Zone → Transfer repository`
- New owner: `sane-apps`
- GitHub auto-redirects old URLs

### Step 2: Make tool forks private
After transfer, change visibility:
- `sane-apps/Sane-Mem` → Private
- `sane-apps/Sane-AppleDocs` → Private
- `sane-apps/Sane-XcodeBuildMCP` → Private

### Step 3: Update local git remotes
```bash
# In each project directory:
git remote set-url origin git@github.com:sane-apps/REPO_NAME.git
```

---

## Phase 2: Update File References (63 files)

After transfer, update `stephanjoseph` → `sane-apps` in these files:

### Apps
| App | Files |
|-----|-------|
| SaneBar | README, PRIVACY, CONTRIBUTING, CHANGELOG, ROADMAP, docs/index.html, docs/appcast.xml, marketing/* |
| SaneClip | README, PRIVACY, CONTRIBUTING, ROADMAP, docs/index.html |
| SaneHosts | README, PRIVACY, CONTRIBUTING, CHANGELOG, CLAUDE.md, docs/appcast.xml, website/*.html |
| SaneSync | README, PRIVACY, SECURITY, CONTRIBUTING |
| SaneAI | PRIVACY, SECURITY, CONTRIBUTING |
| SaneVideo | PRIVACY, CONTRIBUTING |
| SaneScript | PRIVACY |

### Infrastructure
| Location | Files |
|----------|-------|
| SaneProcess | README, CONTRIBUTING, SECURITY, docs/*.md, templates/*.md |
| SaneProcess-templates | templates/*.md, docs/*.md |
| SaneUI | README |
| meta/ | SaneApps-Master-Project.md, Guides/*.md |

### Find/Replace Command
```bash
# Run in ~/SaneApps after transfers complete:
find . -type f \( -name "*.md" -o -name "*.html" -o -name "*.xml" -o -name "*.rb" \) \
  -exec sed -i '' 's/stephanjoseph/sane-apps/g' {} \;
```

---

## Phase 3: Update Copyright Holder

Update LICENSE files and Info.plist:
- "Stephan Joseph" → "Sane Apps" (or keep personal name for legal)

**Decision needed:** Copyright holder name preference?

---

## Phase 4: Distribution Model Change

### Decision: Paid DMGs, Free Source

| Channel | What Users Get | Cost |
|---------|----------------|------|
| **Website** | Built DMG, ready to install | $5 |
| **GitHub** | Source code (clone & build yourself) | Free |

### Actions Required

1. **Delete Homebrew taps:**
   - Delete `sane-apps/homebrew-sanebar`
   - Delete `sane-apps/homebrew-saneclip`
   - Delete any other homebrew-* repos

2. **Remove DMGs from GitHub Releases:**
   - Go to each repo's Releases page
   - Delete all .dmg assets from releases
   - Keep release tags (for version history)

3. **Update documentation:**
   - Remove all `brew install` instructions
   - Remove GitHub release download links
   - Point to website for downloads
   - Add "Build from source" instructions for developers

4. **Update websites:**
   - Add payment integration ($5)
   - Serve DMGs after payment
   - Keep GitHub links for source access

### Rationale
- Open source for transparency and contributions
- Paid binaries for sustainable development
- Users who can build from source = developers who may contribute
- Users who pay = support continued development

---

## Phase 5: Bundle ID Standardization (Optional)

Current state (inconsistent):
- SaneHosts: `com.mrsane.SaneHosts` ✓
- SaneBar: `com.sanebar.app`
- SaneClip: `com.saneclip.app`
- SaneSync: `com.sanesync.SaneSync`
- SaneVideo: `com.sanevideo.app`

**Recommendation:** Keep existing bundle IDs - changing breaks:
- User preferences
- Keychain items
- Launch at login settings

Standardize only for NEW apps: `com.mrsane.{AppName}`

---

## Execution Checklist

- [x] **Phase 1: Transfer repos** ✅ COMPLETED 2026-01-19
  - [x] Transfer SaneBar to sane-apps
  - [x] Transfer SaneClip to sane-apps
  - [x] Transfer SaneProcess to sane-apps
  - [x] Transfer SaneHosts to sane-apps
  - [x] Transfer SaneSync to sane-apps
  - [x] Transfer SaneAI to sane-apps
  - [x] Transfer SaneVideo to sane-apps
  - [x] Transfer Sane-Mem to sane-apps → make private
  - [x] Transfer Sane-AppleDocs to sane-apps → make private
  - [x] Transfer Sane-XcodeBuildMCP to sane-apps → make private
  - [x] Update local git remotes in all projects

- [x] **Phase 2: Update file references** ✅ COMPLETED 2026-01-19
  - [x] Run find/replace across ~/SaneApps
  - [x] Update sponsor links (github.com/sponsors/sane-apps)
  - [x] Update FUNDING.yml files
  - [x] Update appcast URLs
  - [ ] Verify website links work (needs manual test)

- [ ] **Phase 3: Copyright (if desired)** - DEFERRED
  - [ ] Update LICENSE files
  - [ ] Update Info.plist copyright strings

- [x] **Phase 4: Distribution model** ✅ COMPLETED 2026-01-19
  - [x] ~~Delete sane-apps/homebrew-sanebar repo~~ (never created)
  - [x] ~~Delete sane-apps/homebrew-saneclip repo~~ (never created)
  - [x] Remove brew install instructions from all docs
  - [x] Remove homebrew references from templates
  - [x] Update release workflows (no homebrew steps)
  - [x] Add "Build from source" instructions to READMEs
  - [ ] Set up payment on websites ($5) - PENDING
  - [ ] Configure DMG delivery after payment - PENDING

---

## Notes

- GitHub redirects old URLs automatically after transfer (for a period)
- Code signing identity unchanged (tied to Apple Developer account)
- Team ID unchanged: M78L6FXD48
- MCP tools use npm packages, not GitHub - forks can be private
- Don't change bundle IDs for existing apps
- **Distribution model:** Open source + paid binaries (no free DMGs)
- **Appcast.xml:** May need updating - Sparkle updates could pull from paid-only server
- **License consideration:** MIT allows commercial use - users could theoretically build and redistribute. Consider if this matters for $5 apps.
