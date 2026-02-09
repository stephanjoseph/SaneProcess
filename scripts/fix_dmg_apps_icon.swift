import Cocoa

// Replaces the Applications symlink in a mounted DMG with a Finder alias,
// then explicitly sets the system's /Applications folder icon on it.
// Fixes: symlinks/aliases in DMGs don't show the target's icon on macOS 14+.

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift fix_dmg_apps_icon.swift <mounted_volume_path>")
    exit(1)
}

let volumePath = CommandLine.arguments[1]
let appsLinkPath = (volumePath as NSString).appendingPathComponent("Applications")
let appsURL = URL(fileURLWithPath: "/Applications")
let aliasURL = URL(fileURLWithPath: appsLinkPath)

let fm = FileManager.default

// Remove existing symlink/alias
if fm.fileExists(atPath: appsLinkPath) || (try? fm.attributesOfItem(atPath: appsLinkPath)) != nil {
    do {
        try fm.removeItem(atPath: appsLinkPath)
    } catch {
        print("Warning: Could not remove existing item: \(error)")
        exit(0)
    }
}

// Create a Finder alias (bookmark) to /Applications
do {
    let bookmarkData = try appsURL.bookmarkData(
        options: .suitableForBookmarkFile,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    try URL.writeBookmarkData(bookmarkData, to: aliasURL)
    print("Applications alias created")
} catch {
    print("Warning: Alias creation failed (\(error)), recreating symlink")
    try? fm.createSymbolicLink(atPath: appsLinkPath, withDestinationPath: "/Applications")
}

// Now explicitly set the /Applications folder icon on the alias file
let appsIcon = NSWorkspace.shared.icon(forFile: "/Applications")
if NSWorkspace.shared.setIcon(appsIcon, forFile: appsLinkPath, options: []) {
    print("Applications icon set successfully")
} else {
    print("Warning: Could not set icon on alias (Finder should still resolve it)")
}
