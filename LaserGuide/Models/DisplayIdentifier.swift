// DisplayIdentifier.swift
import Cocoa

/// Unique identifier for a display based on hardware properties
struct DisplayIdentifier: Hashable, Codable {
    let vendorID: UInt32
    let modelID: UInt32
    let serialNumber: UInt32

    init(displayID: CGDirectDisplayID) {
        self.vendorID = CGDisplayVendorNumber(displayID)
        self.modelID = CGDisplayModelNumber(displayID)
        self.serialNumber = CGDisplaySerialNumber(displayID)
    }

    /// String representation for use in configuration keys
    var stringRepresentation: String {
        return "\(vendorID)-\(modelID)-\(serialNumber)"
    }
}

/// Physical position and size of a display in millimeters
struct PhysicalDisplayLayout: Codable {
    let identifier: DisplayIdentifier
    let position: PhysicalPoint  // Bottom-left corner in mm
    let size: PhysicalSize       // Width and height in mm

    struct PhysicalPoint: Codable {
        let x: Double  // mm
        let y: Double  // mm
    }

    struct PhysicalSize: Codable {
        let width: Double   // mm
        let height: Double  // mm
    }
}

/// Complete display configuration including all connected displays
struct DisplayConfiguration: Codable {
    let displays: [PhysicalDisplayLayout]
    let timestamp: Date

    /// Generate unique configuration key based on connected displays
    /// Key format: "config_vendorID-modelID-serial_vendorID-modelID-serial_..."
    var configurationKey: String {
        let identifiers = displays
            .map { $0.identifier.stringRepresentation }
            .sorted()  // Sort to ensure consistent key regardless of display order
            .joined(separator: "_")
        return "config_\(identifiers)"
    }
}
