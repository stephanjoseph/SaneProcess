import Cocoa

// Generates a clean light DMG background that works in both light and dark mode.
// Solves: Applications folder icon invisible in dark mode with no background.
// Rule: Never use dark backgrounds (causes unreadable text). Light backgrounds are fine.

let width: CGFloat = 800
let height: CGFloat = 400

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift generate_dmg_background.swift <output.png> [width] [height]")
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let w = CommandLine.arguments.count > 2 ? CGFloat(Int(CommandLine.arguments[2]) ?? Int(width)) : width
let h = CommandLine.arguments.count > 3 ? CGFloat(Int(CommandLine.arguments[3]) ?? Int(height)) : height
let size = NSSize(width: w, height: h)

let image = NSImage(size: size)
image.lockFocus()

// Soft light gradient: white to very light gray
let gradient = NSGradient(
    starting: NSColor(white: 0.98, alpha: 1.0),
    ending: NSColor(white: 0.93, alpha: 1.0)
)
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 270)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    print("Error: Failed to generate PNG")
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Background generated: \(outputPath) (\(Int(w))x\(Int(h)))")
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
