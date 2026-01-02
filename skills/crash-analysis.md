# Crash Analysis

> When to use: App crashed, analyzing crash logs, seeing SIGSEGV/EXC_BAD_ACCESS, or "what does this crash report mean?"

---

## What This Is (Plain English)

When your app crashes, macOS creates a crash report. This report tells you:
1. **What happened** (signal type like SIGSEGV)
2. **Where it happened** (which function, which line)
3. **Why it might have happened** (memory address patterns)

Reading crash reports is detective work. This skill teaches you how to decode them.

---

## Quick Reference: Crash Types

| Signal | Name | Meaning | Common Cause |
|--------|------|---------|--------------|
| `SIGSEGV` | Segmentation Fault | Accessed invalid memory | Use-after-free, null pointer |
| `SIGBUS` | Bus Error | Misaligned memory access | Rare on modern systems |
| `SIGABRT` | Abort | Intentional crash | Assertion failed, fatalError() |
| `SIGILL` | Illegal Instruction | Invalid CPU instruction | Corrupted binary, bad cast |
| `SIGTRAP` | Trap | Debugger breakpoint | Swift precondition failed |
| `EXC_BAD_ACCESS` | Bad Access | Memory you can't touch | Deallocated object, null pointer |
| `EXC_BREAKPOINT` | Breakpoint | Code triggered trap | Swift assertion, actor isolation |

---

## Address Ranges (What the Memory Address Tells You)

| Address Pattern | What It Means | Likely Cause |
|-----------------|---------------|--------------|
| `0x0` - `0x1000` | NULL pointer | Object was deallocated, optional was nil |
| `0x1000` - `0xFFFF` | Small offset from NULL | Accessed struct member on nil object |
| `0x7fff...` | Stack address | Stack overflow or corruption |
| Large random hex | Heap address | Use-after-free or heap corruption |
| `0xDEADBEEF` | Debug pattern | Memory was deliberately poisoned |

**Example**: Crash at address `0x0000000000000048`
- 0x48 = 72 bytes from null
- This means: accessed a property at offset 72 on a nil object
- Translation: "something.someProperty" where "something" was nil

---

## Thread Analysis

| Faulting Thread | What It Tells You |
|-----------------|-------------------|
| Thread 0 | Main thread - likely UI or state issue |
| Thread N > 0 | Background thread - likely concurrency bug |
| libdispatch in stack | GCD queue issue |
| Swift runtime in stack | Type casting or protocol issue |

### Main Thread Crash (Thread 0)

Usually means:
- UI accessed from wrong thread
- State corruption during update
- Force unwrap of nil

### Background Thread Crash

Usually means:
- Race condition
- Actor isolation violation
- Concurrent access to non-thread-safe code

---

## Reading a Crash Report

### Step 1: Find the Exception

```
Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
Exception Codes: KERN_INVALID_ADDRESS at 0x0000000000000048
```

This tells you: tried to access memory at address 0x48 (nil + offset).

### Step 2: Find the Crashing Thread

```
Thread 0 Crashed:
0   YourApp                      0x100abc123 ViewModel.updateUI() + 48
1   YourApp                      0x100abc456 ViewController.viewDidLoad() + 112
```

This tells you: crashed in `ViewModel.updateUI()`, called from `viewDidLoad()`.

### Step 3: Symbolicate (If Needed)

If you see addresses without function names:

```bash
# Get dSYM from archive
# Then:
atos -arch arm64 -o YourApp.app.dSYM/Contents/Resources/DWARF/YourApp -l 0x100000000 0x100abc123
```

---

## Common Crash Patterns

### Pattern 1: Actor Isolation Violation

```
Thread 0 Crashed:
0   libdispatch.dylib    dispatch_assert_queue_fail
1   YourApp              ViewModel.deinit()
```

**Cause**: Used `MainActor.assumeIsolated` in deinit
**Fix**: Use `nonisolated(unsafe)` or remove actor-isolated code from deinit

### Pattern 2: Use-After-Free

```
Exception Type: EXC_BAD_ACCESS
Thread 3:
0   objc_release
1   YourApp    SomeClass.deinit
```

**Cause**: Object deallocated while still in use
**Fix**: Check retain cycles, add `isActive` guards, use weak references

### Pattern 3: Force Unwrap Nil

```
Fatal error: Unexpectedly found nil while unwrapping an Optional
```

**Cause**: `value!` when value was nil
**Fix**: Use `guard let`, `if let`, or `??` default

### Pattern 4: Index Out of Bounds

```
Fatal error: Index out of range
```

**Cause**: `array[index]` where index >= array.count
**Fix**: Check bounds first, use `array.indices.contains(index)`

---

## Debugging Tools

### Enable Zombie Objects

Catches use-after-free by keeping deallocated objects around:

Xcode → Edit Scheme → Run → Diagnostics → Enable Zombie Objects

### Address Sanitizer

Catches memory bugs at runtime:

Xcode → Edit Scheme → Run → Diagnostics → Address Sanitizer

### Thread Sanitizer

Catches race conditions:

Xcode → Edit Scheme → Run → Diagnostics → Thread Sanitizer

---

## Crash Log Locations

```bash
# User crash reports
~/Library/Logs/DiagnosticReports/

# System crash reports
/Library/Logs/DiagnosticReports/

# Recent crashes (quick check)
ls -lt ~/Library/Logs/DiagnosticReports/*.crash | head -5

# View latest crash
cat "$(ls -t ~/Library/Logs/DiagnosticReports/*.crash | head -1)"
```

---

## Verification

After fixing a crash:

```bash
# Run with sanitizers
xcodebuild test -scheme YourScheme \
  -enableAddressSanitizer YES \
  -enableThreadSanitizer YES

# Check for Zombie detection
xcodebuild test -scheme YourScheme \
  -enableZombie YES

# Monitor for new crashes
./Scripts/SaneMaster.rb crashes
```

---

*~120 lines • Last updated: 2026-01-02*
