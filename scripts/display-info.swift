#!/usr/bin/env swift

import Cocoa

print("=== Display Information ===\n")

let screens = NSScreen.screens
print("Number of displays: \(screens.count)\n")

for (index, screen) in screens.endIndex > 0 ? screens.enumerated() : [].enumerated() {
    print("Display \(index + 1):")
    print("  Frame: \(screen.frame)")
    print("  Visible Frame: \(screen.visibleFrame)")
    print("  Backing Scale Factor: \(screen.backingScaleFactor)")

    let deviceDescription = screen.deviceDescription as [NSDeviceDescriptionKey: Any]
    if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
        print("  Display ID: \(screenNumber)")

        // Physical size in millimeters
        let size = CGDisplayScreenSize(screenNumber)
        print("  Physical Size: \(size.width)mm x \(size.height)mm")

        // Display mode
        if let mode = CGDisplayCopyDisplayMode(screenNumber) {
            print("  Native Resolution: \(mode.width) x \(mode.height)")
            print("  Refresh Rate: \(mode.refreshRate) Hz")
        }

        // PPI calculation
        let points = screen.frame.size
        let pixels = NSSize(width: points.width * screen.backingScaleFactor,
                          height: points.height * screen.backingScaleFactor)

        if size.width > 0 {
            let ppiX = (pixels.width / (size.width / 25.4))
            let ppiY = (pixels.height / (size.height / 25.4))
            print("  PPI: \(String(format: "%.1f", ppiX)) x \(String(format: "%.1f", ppiY))")
        }

        // Check if built-in
        let isBuiltIn = CGDisplayIsBuiltin(screenNumber) != 0
        print("  Built-in: \(isBuiltIn)")

        // Display name
        if let info = CoreDisplay_DisplayCreateInfoDictionary(screenNumber)?.takeRetainedValue() as? [String: Any],
           let names = info["DisplayProductName"] as? [String: String],
           let name = names["en_US"] ?? names.values.first {
            print("  Name: \(name)")
        }
    }

    // Local name
    let localizedName = screen.localizedName
    print("  Localized Name: \(localizedName)")

    print()
}

// Display arrangement
print("=== Display Arrangement ===")
if let mainScreen = NSScreen.main {
    print("Main display frame: \(mainScreen.frame)")
}

for (index, screen) in screens.enumerated() {
    let origin = screen.frame.origin
    print("Display \(index + 1) origin: x=\(origin.x), y=\(origin.y)")
}

@_silgen_name("CoreDisplay_DisplayCreateInfoDictionary")
func CoreDisplay_DisplayCreateInfoDictionary(_ display: CGDirectDisplayID) -> Unmanaged<CFDictionary>?
