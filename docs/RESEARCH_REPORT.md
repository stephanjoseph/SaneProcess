# SaneProcess Research Report: Maximizing Product Value

> **Research Date**: 2026-01-02
> **Last Updated**: 2026-01-02
> **Status**: ✅ Phase 1 Complete (750+ lines shipped)
> **Methodology**: Competitive analysis, WWDC 2025 research, Memory MCP review

---

## Executive Summary

The "Supervisor" positioning nails it: **"Your AI Developer is drunk. Here is the Supervisor."**

After researching competitors, WWDC 2025 APIs, and existing Claude Code configuration tools, I've identified **18 specific additions** that would significantly increase product value.

**Update**: Phase 1 complete. mac_context.rb now ships **757 lines** of Mac-native knowledge (up from 225). All "nice-to-have" WWDC 2025 APIs included.

The key insight: **Competitors ship "skills" (domain knowledge modules). We should too.**

---

## Part 1: Competitive Landscape

### Direct Competitors

| Tool | Model | Strength | Weakness |
|------|-------|----------|----------|
| [steipete/agent-scripts](https://github.com/steipete/agent-scripts) | Free/OSS | Skills library, pointer workflow | Personal setup, not productized |
| [rulesync](https://github.com/dyoshikawa/rulesync) | Free/OSS | Multi-tool sync (Cursor, Claude, Gemini) | No enforcement, just file sync |
| [Codacy Guardrails](https://www.codacy.com/guardrails) | SaaS | Security focus, IDE integration | Enterprise pricing, not Mac-native |
| Cursor .cursorrules | Built-in | Path-specific rules, rule types | Rules often ignored (user reports) |

### What steipete Ships (For Reference)

Peter Steinberger (steipete) maintains a skills library at [agent-scripts](https://github.com/steipete/agent-scripts):
- `swift-concurrency-expert` - Actor isolation, Sendable patterns
- `swiftui-liquid-glass` - macOS Tahoe/iOS 26 glass APIs
- `swiftui-performance-audit` - Anti-patterns checklist

**Our Response**: ✅ We now have a skill loader (`scripts/skill_loader.rb`) with 3 skills:
- `swift-concurrency` - Actors, @MainActor, Swift 6.2 changes (176 lines)
- `swiftui-performance` - View anti-patterns, optimization (218 lines)
- `crash-analysis` - Reading crash reports, symbolication (212 lines)

**Key insight**: Skills are **loadable on demand**, not always-on context bloat.

---

## Part 2: What We're Missing (Gap Analysis)

### A. Mac Context Gaps (Was: 225 lines → Now: 757 lines ✅)

| Topic | Status | Notes |
|-------|--------|-------|
| **Liquid Glass APIs** | ✅ SHIPPED | glassEffect(), GlassEffectContainer, availability gating |
| **Swift 6.2 Approachable Concurrency** | ✅ SHIPPED | @concurrent, isolated deinit, Sendable inference |
| **Foundation Models Framework** | ✅ SHIPPED | On-device LLM API with code examples |
| **Spotlight App Intents** | ✅ SHIPPED | AppIntentsPackage pattern |
| **WebView in SwiftUI** | ✅ SHIPPED | Native WebView API (macOS 26+) |
| **Chart3D API** | ✅ SHIPPED | Interactive 3D charts examples |
| **Sandboxing File Access Patterns** | ✅ SHIPPED | Security-scoped bookmarks with full code |
| **Notarization Workflow** | ✅ SHIPPED | codesign + notarytool + stapler |
| **SwiftUI Performance Anti-patterns** | ✅ SHIPPED | Anti-patterns table, cached formatters |
| **Crash Analysis Patterns** | ✅ SHIPPED | Address ranges table, thread analysis |
| **Instruments Profiling** | ✅ SHIPPED | Templates and command-line workflow |

### B. Enforcement Gaps

| Feature | Competitors Have | We Have | Gap |
|---------|------------------|---------|-----|
| Circuit Breaker | Codacy (security) | Yes | None |
| API Verification | Tabnine (enterprise) | Yes | None |
| Test Quality Gate | SonarQube | Yes | None |
| Path-specific Rules | Cursor | No | **ADD** |
| Rule Types (Always/Auto/Requested) | Cursor | No | **ADD** |
| Security-scoped File Deny | Codacy | Partial | **EXPAND** |
| Cross-tool Sync | rulesync | No | Consider |

### C. Skills We Should Ship

Based on steipete's library and WWDC 2025:

| Skill Name | Content | Lines Est. |
|------------|---------|------------|
| `swift-concurrency` | Actor isolation, Sendable, Swift 6.2 changes | 200 |
| `swiftui-performance` | Anti-patterns, audit checklist, profiling | 250 |
| `liquid-glass-migration` | glassEffect(), availability gating, fallbacks | 150 |
| `macos-permissions` | TCC, entitlements, accessibility, screen recording | 200 |
| `menu-bar-apps` | NSStatusItem, template images, dark mode | 100 |
| `app-distribution` | Signing, notarization, stapling, TestFlight | 150 |
| `crash-analysis` | SIGSEGV patterns, symbolication, Thread 0 vs N | 150 |
| `xcodegen-patterns` | project.yml templates, multi-target, SPM | 100 |

**Total new content: ~1,300 lines of domain knowledge**

---

## Part 3: WWDC 2025 APIs to Cover

### Must-Have (Apps will break without knowledge)

1. **Liquid Glass Design System**
   - `glassEffect(_:in:isEnabled:)` modifier
   - `GlassEffectContainer` for grouping
   - `.buttonStyle(.glass)` and `.glassProminent`
   - One-year grace period opt-out

2. **Swift 6.2 Approachable Concurrency**
   - `@concurrent` for explicit background work
   - Automatic `@Sendable` inference for method refs
   - `isolated` deinitializers for actors
   - New nonisolated async default behavior

3. **Foundation Models Framework**
   - On-device LLM without internet
   - iOS, iPadOS, macOS, visionOS
   - No app size increase (system-provided)

### Nice-to-Have

4. **Native WebView in SwiftUI** - No more WKWebView wrapping
5. **Chart3D API** - Interactive 3D charts
6. **Spotlight App Intents** - System-wide surfacing

---

## Part 4: Recommendations (Prioritized)

### Tier 1: ✅ COMPLETE

| # | Action | Status |
|---|--------|--------|
| 1 | **Expand mac_context.rb to 500+ lines** | ✅ Done (757 lines) |
| 2 | **Add Swift Concurrency knowledge** | ✅ Included in mac_context |
| 3 | **Add Liquid Glass knowledge** | ✅ Included in mac_context |
| 4 | **Add SwiftUI Performance knowledge** | ✅ Included in mac_context |

### Tier 2: Ship This Month (Product Differentiation)

| # | Action | Effort | Value |
|---|--------|--------|-------|
| 5 | **Add skill loader to SaneMaster** (`/skill swift-concurrency`) | 3 hrs | HIGH |
| 6 | **Add path-specific rules** (.claude/rules/*.md) | 2 hrs | MEDIUM |
| 7 | **Add macOS Permissions skill** (TCC deep dive) | 2 hrs | HIGH |
| 8 | **Add Distribution skill** (signing, notarization) | 2 hrs | MEDIUM |

### Tier 3: V2 Features (Future Expansion)

| # | Action | Effort | Value |
|---|--------|--------|-------|
| 9 | rulesync compatibility (export to Cursor format) | 4 hrs | MEDIUM |
| 10 | Visual "Read Only" mode for free tier | 6 hrs | HIGH |
| 11 | Instruments profiling workflow skill | 2 hrs | MEDIUM |
| 12 | Crash analysis automation | 4 hrs | MEDIUM |

---

## Part 5: Marketing Feedback

The "Railgun" pitch is excellent. Minor refinements:

### Keep (These Kill)
- **"Your AI Developer is drunk. Here is the Supervisor."** - Perfect hook
- **"Constraint is the Feature"** - Differentiator manifesto
- **"Zero Project Corruption"** - Unique value prop
- **"No pip, no npm, no brew. Double click and build."** - Addresses real pain

### Adjust
- **"Zero Hallucinations"** - You already flagged this. Consider: **"Reduced Hallucinations"** or **"Supervised Hallucinations"** (the joke being it still hallucinates but we catch it)
- **"2,000-token Supervisor Context"** - Make this a feature: **"2,000-token Mac Brain"** or just cite the actual line count (500+ lines of Mac knowledge)

### Add
- **Skills library** - "Comes with 8 domain skills: Concurrency, SwiftUI Performance, Liquid Glass..."
- **Memory across sessions** - "Learns from your crashes. Remembers your patterns."
- **Circuit breaker visual** - "Stops after 3 failures. No more $20 token burns."

---

## Part 6: What mac_context.rb Now Includes (757 lines)

All items below are **SHIPPED** in the current version:

### Core Build Knowledge
- Build System Rules (xcodebuild patterns)
- Info.plist Templates (all required keys)
- Entitlements (sandbox, hardened runtime, network)

### Security & Distribution
- Security-Scoped Bookmarks (full code example)
- Notarization Workflow (codesign → notarytool → stapler)
- Common Notarization Failures table

### Crash Analysis
- Address Range Analysis table (0x0-0x1000 = NULL, etc.)
- Thread Analysis table (Thread 0 = main, N = background)
- Symbolication commands (atos, dSYM)

### WWDC 2025 APIs
- Swift 6.2 Approachable Concurrency (@concurrent, isolated deinit)
- Liquid Glass (glassEffect(), GlassEffectContainer)
- Foundation Models Framework (on-device LLM)
- WebView in SwiftUI (native, no WKWebView)
- Chart3D API (3D charting)
- App Intents + Spotlight integration

### SwiftUI & Performance
- Anti-patterns table (from steipete research)
- Cached formatter pattern
- Stable identity patterns
- View extraction guidelines

### Menu Bar & Accessibility
- NSStatusItem patterns
- Template images for dark mode
- AXUIElement hierarchy
- Trusted application flow

### Instruments Profiling
- Template recommendations (Time Profiler, Allocations, etc.)
- Command-line workflow (xctrace)
- Profile naming conventions

---

## Part 7: Next Steps (Tier 2 Roadmap)

### ✅ Completed
1. **mac_context.rb expanded** - 757 lines shipped
2. **All WWDC 2025 APIs included** - Liquid Glass, Swift 6.2, Foundation Models, etc.
3. **Tested and verified** - Both SaneMaster (our tooling) and SaneProcess (product) work

### Next Up (Tier 2)
1. **Skill loader system** - `/skill swift-concurrency` command
2. **Path-specific rules** - `.claude/rules/*.md` pattern
3. **macOS Permissions skill** - TCC deep dive as separate module
4. **Distribution skill** - Detailed signing/notarization as separate module

### V2 Features (Tier 3)
1. **rulesync compatibility** - Export to Cursor format
2. **Visual "Read Only" mode** - Free tier preview
3. **Crash analysis automation** - Parse crash logs automatically

---

## Sources

- [steipete/agent-scripts](https://github.com/steipete/agent-scripts) - Skills library reference
- [rulesync](https://github.com/dyoshikawa/rulesync) - Multi-tool sync approach
- [Codacy Guardrails](https://www.codacy.com/guardrails) - Enterprise security patterns
- [WWDC 2025 Recap](https://povio.com/blog/wwdc-2025-updates-for-apple-developers) - New APIs
- [Swift 6.2 Approachable Concurrency](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) - Concurrency changes
- [Apple Developer - What's New](https://developer.apple.com/whats-new/) - Official updates
- [Anthropic - Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices) - CLAUDE.md patterns
- [HumanLayer - Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md) - Configuration best practices

---

*Report generated by Claude Opus 4.5 using SOP-compliant research protocol*

---

## Product Summary

**SaneProcess** - The Supervisor for Claude Code

> "Your AI Developer is drunk. Here is the Supervisor."

| Feature | Status |
|---------|--------|
| Mac Context Injection | ✅ 757 lines |
| Circuit Breaker | ✅ Shipped |
| Test Quality Gate | ✅ Shipped |
| WWDC 2025 APIs | ✅ All included |
| Skill Loader | 🔜 Tier 2 |
| Path-specific Rules | 🔜 Tier 2 |
