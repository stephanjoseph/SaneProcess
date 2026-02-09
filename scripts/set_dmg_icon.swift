import Cocoa

guard CommandLine.arguments.count == 3 else {
    print("Usage: swift set_dmg_icon.swift <icon_path> <dmg_path>")
    exit(1)
}

let iconPath = CommandLine.arguments[1]
let dmgPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: iconPath) else {
    print("Error: Failed to load icon at \(iconPath)")
    exit(1)
}

// Apply macOS squircle mask so the DMG file icon matches app icon appearance.
// Without this, the raw square icon is stamped directly and looks wrong in Finder.
let iconSize: CGFloat = 512
let targetSize = NSSize(width: iconSize, height: iconSize)

let maskedImage = NSImage(size: targetSize)
maskedImage.lockFocus()

// Apple's icon corner radius is ~22.37% of icon size
let cornerRadius = iconSize * 0.2237
let iconRect = NSRect(origin: .zero, size: targetSize)
let roundedPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
roundedPath.addClip()

// Draw the icon image filling the entire square (clipped by rounded rect)
image.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

maskedImage.unlockFocus()

if NSWorkspace.shared.setIcon(maskedImage, forFile: dmgPath, options: []) {
    print("Icon set successfully (squircle masked)")
} else {
    print("Error: Failed to set icon")
    exit(1)
}
