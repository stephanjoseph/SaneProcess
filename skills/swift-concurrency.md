# Swift Concurrency

> When to use: Working with async/await, actors, Tasks, or fixing "not Sendable" errors

---

## What This Is (Plain English)

Swift Concurrency is how Swift handles doing multiple things at once without crashing or corrupting data. Instead of using threads directly (which is error-prone), you use:

- **async/await** - Wait for slow things without blocking
- **Actors** - Objects that protect their data from simultaneous access
- **Tasks** - Units of work that can run in the background

The compiler checks your code at build time to prevent race conditions. If it complains about "Sendable" or "actor isolation," that's the compiler saving you from a crash.

---

## Key Concepts

### @MainActor = "Run this on the main thread"

Use it for anything that touches the UI:

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []  // Safe to update from SwiftUI

    func loadItems() async {
        let fetched = await api.fetchItems()  // Runs in background
        items = fetched  // Back on main thread automatically
    }
}
```

### Actors = "Protect this data"

Use actors when multiple parts of your code might access the same data:

```swift
actor ImageCache {
    private var cache: [URL: Image] = [:]

    func image(for url: URL) async -> Image? {
        if let cached = cache[url] { return cached }
        let image = await downloadImage(url)
        cache[url] = image  // Safe - actor protects this
        return image
    }
}
```

### Task = "Do this in the background"

```swift
// Fire and forget
Task {
    await saveToDatabase()
}

// With cancellation
let task = Task {
    await longRunningWork()
}
task.cancel()  // Asks it to stop (doesn't force)
```

---

## Swift 6.2 Changes (New in 2025)

### @concurrent = "Explicitly run in background"

Before Swift 6.2, non-isolated async functions ran on a global executor (background). Now they run on the caller's actor by default. Use `@concurrent` to get the old behavior:

```swift
// Runs on caller's actor (new default)
func processImage() async -> Image { ... }

// Explicitly runs in background (old behavior)
@concurrent
func processImageInBackground() async -> Image { ... }
```

### Isolated deinit

Actors can now have `isolated deinit` - the cleanup code runs on the actor's executor:

```swift
actor ResourceManager {
    var resources: [Resource] = []

    isolated deinit {
        // Safe to access 'resources' here
        for resource in resources {
            resource.cleanup()
        }
    }
}
```

### Approachable Concurrency Build Setting

Enable in Xcode: Build Settings → "Approachable Concurrency" → Yes

This makes the compiler less strict - good for migrating old code, but you lose some safety checks.

---

## Common Patterns

### Notification → MainActor (The Safe Way)

Notifications aren't Sendable. Extract values BEFORE crossing actor boundaries:

```swift
// ❌ WRONG - notification isn't Sendable
NotificationCenter.default.addObserver(forName: .userLoggedIn, object: nil, queue: nil) { notification in
    Task { @MainActor in
        self.user = notification.userInfo?["user"] as? User  // Compiler error
    }
}

// ✅ CORRECT - extract values first
NotificationCenter.default.addObserver(forName: .userLoggedIn, object: nil, queue: nil) { notification in
    let user = notification.userInfo?["user"] as? User  // Extract here
    Task { @MainActor in
        self.user = user  // Now safe
    }
}
```

### nonisolated(unsafe) for Known-Safe Cases

When YOU know it's safe but the compiler doesn't:

```swift
class LegacyService {
    // Only accessed from main thread, but compiler doesn't know
    nonisolated(unsafe) var delegate: ServiceDelegate?
}
```

**Use sparingly** - you're telling the compiler to trust you.

---

## Gotchas

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `assumeIsolated` in deinit | `dispatch_assert_queue_fail` crash | Use `nonisolated(unsafe)` or remove |
| Nested `Task { Task { } }` | Freezes at `_isSameExecutor` | Flatten to single Task |
| Passing non-Sendable across actors | Compiler error | Extract values, make Sendable, or use actor |
| `@MainActor` on init | Can't call from background | Remove or use `Task { await init() }` |

---

## Verification

```bash
# Check for concurrency warnings
swiftlint lint --config .swiftlint.yml | grep -i "sendable\|actor\|concurrency"

# Build with strict concurrency
xcodebuild -scheme YourScheme -destination 'platform=macOS' \
  OTHER_SWIFT_FLAGS="-strict-concurrency=complete" build

# Run Thread Sanitizer
xcodebuild test -scheme YourScheme -enableThreadSanitizer YES
```

---

*~180 lines • Last updated: 2026-01-02*
