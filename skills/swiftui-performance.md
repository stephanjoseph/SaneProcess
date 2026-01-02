# SwiftUI Performance

> When to use: Views are slow, laggy scrolling, high CPU during UI updates, or "why does this re-render so much?"

---

## What This Is (Plain English)

SwiftUI re-renders views when their data changes. Performance problems happen when:
1. Views re-render too often (unnecessary updates)
2. Views are too expensive to render (complex body)
3. Identity is unstable (SwiftUI thinks it's a new view)

The fix is usually: make fewer things change, make changes cheaper, or help SwiftUI know what's actually the same view.

---

## Anti-Patterns (Things That Kill Performance)

| Bad Pattern | Why It's Bad | Fix |
|-------------|--------------|-----|
| Creating objects in `body` | New object every render | Move to `@State` or compute once |
| `DateFormatter()` in body | Expensive to create | Cache as static property |
| Large `@Observable` with many properties | Any change re-renders all observers | Split into focused objects |
| `ForEach(items)` without stable ID | SwiftUI recreates cells | Use `ForEach(items, id: \.stableID)` |
| `.id(UUID())` or `.id(Date())` | Forces complete recreation | Use stable identifier |
| `AnyView` | Loses type information | Use `@ViewBuilder` or generics |
| View body > 50 lines | Hard to diff, hard to read | Extract sub-views |

---

## Key Concepts

### Stable Identity = SwiftUI Knows It's the Same View

```swift
// ❌ BAD - new UUID every time, SwiftUI thinks it's new
ForEach(items) { item in
    ItemRow(item: item)
        .id(UUID())  // Never do this
}

// ✅ GOOD - stable ID, SwiftUI can diff properly
ForEach(items, id: \.persistentID) { item in
    ItemRow(item: item)
}
```

### Cached Formatters

```swift
// ❌ BAD - creates new formatter every render
var body: some View {
    Text(date, formatter: DateFormatter())  // Expensive!
}

// ✅ GOOD - single formatter, reused
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

var body: some View {
    Text(date, formatter: Self.dateFormatter)
}
```

### @Observable Granularity

```swift
// ❌ BAD - one big object, any change updates everything
@Observable
class AppState {
    var user: User?
    var settings: Settings
    var items: [Item]
    var networkStatus: NetworkStatus
    // Every view that observes this re-renders on ANY change
}

// ✅ GOOD - split by concern
@Observable class UserState { var user: User? }
@Observable class ItemsState { var items: [Item] }
@Observable class NetworkState { var status: NetworkStatus }

// Views only re-render when their specific state changes
```

---

## Common Patterns

### Extract Views (Keep body Small)

```swift
// ❌ BAD - 100+ line body
var body: some View {
    VStack {
        // Header code...
        // Content code...
        // Footer code...
        // More code...
    }
}

// ✅ GOOD - extracted components
var body: some View {
    VStack {
        HeaderView()
        ContentView(items: items)
        FooterView()
    }
}

// Even better - private views in same file
private struct HeaderView: View {
    var body: some View { ... }
}
```

### Lazy Loading for Lists

```swift
// ❌ BAD - creates all 10,000 cells immediately
ScrollView {
    VStack {
        ForEach(items) { ItemRow($0) }
    }
}

// ✅ GOOD - only creates visible cells
List(items) { item in
    ItemRow(item)
}

// Or for custom layouts:
ScrollView {
    LazyVStack {
        ForEach(items) { ItemRow($0) }
    }
}
```

### Equatable for Complex Views

```swift
// Tell SwiftUI exactly when to re-render
struct ExpensiveView: View, Equatable {
    let item: Item

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.item.lastModified == rhs.item.lastModified
    }

    var body: some View {
        // Complex rendering...
    }
}

// Use with .equatable() modifier
ExpensiveView(item: item)
    .equatable()
```

---

## Debugging Performance

### Instruments Template

1. Open Instruments (⌘I from Xcode)
2. Choose "SwiftUI" template
3. Look for:
   - **View Body** - how often body is called
   - **View Properties** - what changed to trigger update
   - **Core Animation Commits** - actual screen updates

### Debug Overlay

```swift
// Add to view to see render counts
var body: some View {
    let _ = Self._printChanges()  // Prints to console on each render
    // ... your view
}
```

### Performance Checklist

Before shipping:
- [ ] No formatters created in body
- [ ] ForEach has stable IDs
- [ ] No `AnyView` usage
- [ ] Large lists use `List` or `LazyVStack`
- [ ] No `@Observable` god objects
- [ ] View bodies under 50 lines

---

## Verification

```bash
# Profile with Instruments
xcodebuild -scheme YourScheme -destination 'platform=macOS' build
xcrun xctrace record --template 'SwiftUI' --launch YourApp.app

# Check for AnyView usage
grep -r "AnyView" Sources/

# Check for in-body object creation
grep -r "DateFormatter()\|NumberFormatter()" Sources/Views/
```

---

*~150 lines • Last updated: 2026-01-02*
