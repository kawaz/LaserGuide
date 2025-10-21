// CalibrationDataManager.swift
import Foundation
import Cocoa

/// Manages storage and retrieval of physical display layout calibration data
class CalibrationDataManager {
    static let shared = CalibrationDataManager()

    private let userDefaults = UserDefaults.standard
    private let calibrationKeyPrefix = "LaserGuide.Calibration."

    private init() {}

    /// Get current display configuration (logical coordinates and physical specs)
    func getCurrentDisplayConfiguration() -> (logical: [LogicalDisplayInfo], physical: [ScreenInfo]) {
        let screens = NSScreen.screens
        let logical = screens.map { screen -> LogicalDisplayInfo in
            let deviceDescription = screen.deviceDescription
            let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
            return LogicalDisplayInfo(
                displayID: displayID,
                identifier: DisplayIdentifier(displayID: displayID),
                frame: screen.frame
            )
        }
        let physical = screens.compactMap { ScreenInfo(screen: $0) }
        return (logical, physical)
    }

    /// Generate configuration key for current display setup
    func getCurrentConfigurationKey() -> String {
        let (_, physical) = getCurrentDisplayConfiguration()
        let identifiers = physical
            .map { DisplayIdentifier(displayID: $0.displayID).stringRepresentation }
            .sorted()
            .joined(separator: "_")
        return "config_\(identifiers)"
    }

    /// Save calibration data for current display configuration
    func saveCalibration(_ configuration: DisplayConfiguration) {
        let key = calibrationKeyPrefix + configuration.configurationKey
        if let encoded = try? JSONEncoder().encode(configuration) {
            userDefaults.set(encoded, forKey: key)
            print("✅ Saved calibration for: \(configuration.configurationKey)")
        }
    }

    /// Save temporary calibration data for real-time preview (not persisted permanently)
    func saveCalibrationTemporary(_ configuration: DisplayConfiguration) {
        let key = calibrationKeyPrefix + getCurrentConfigurationKey() + ".temporary"
        if let encoded = try? JSONEncoder().encode(configuration) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    /// Load calibration data for current display configuration
    func loadCalibration() -> DisplayConfiguration? {
        // Check for temporary configuration first (for real-time preview)
        let tempKey = calibrationKeyPrefix + getCurrentConfigurationKey() + ".temporary"
        if let tempData = userDefaults.data(forKey: tempKey),
           let tempConfiguration = try? JSONDecoder().decode(DisplayConfiguration.self, from: tempData) {
            return tempConfiguration
        }

        // Fall back to saved configuration
        let key = calibrationKeyPrefix + getCurrentConfigurationKey()
        guard let data = userDefaults.data(forKey: key),
              let configuration = try? JSONDecoder().decode(DisplayConfiguration.self, from: data) else {
            return nil
        }
        return configuration
    }

    /// Clear temporary calibration data
    func clearTemporaryCalibration() {
        let tempKey = calibrationKeyPrefix + getCurrentConfigurationKey() + ".temporary"
        userDefaults.removeObject(forKey: tempKey)
    }

    /// Check if calibration exists for current configuration
    func hasCalibration() -> Bool {
        return loadCalibration() != nil
    }

    /// Delete calibration data for current configuration
    func deleteCalibration() {
        let key = calibrationKeyPrefix + getCurrentConfigurationKey()
        userDefaults.removeObject(forKey: key)
    }

    /// List all saved calibration configurations
    func listAllCalibrations() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys
            .filter { $0.hasPrefix(calibrationKeyPrefix) }
            .map { String($0.dropFirst(calibrationKeyPrefix.count)) }
    }
}

/// Logical display information (macOS coordinate system)
struct LogicalDisplayInfo {
    let displayID: CGDirectDisplayID
    let identifier: DisplayIdentifier
    let frame: CGRect  // Logical coordinates
}
