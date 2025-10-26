// EdgeNavigationCache.swift
import Foundation
import Cocoa

/// Runtime cache for fast edge zone lookup using logical coordinates
class EdgeNavigationCache {

    // MARK: - Zone Type Definition

    /// Zone types based on logical adjacency and user configuration
    enum ZoneType {
        case BB  // Block→Block: macOS default (not logically adjacent, no pair)
        case BP  // Block→Pass: Make impassable edge passable (not adjacent, has pair) - Future
        case PP  // Pass→Pass: Warp with physical correction (adjacent, has pair)
        case PB  // Pass→Block: Block previously passable edge (adjacent, no pair)
    }

    // MARK: - Cache Structures

    /// Cached zone information with logical coordinates
    struct EdgeZoneCache {
        let id: UUID
        let displayId: String
        let edge: EdgeDirection
        let start: CGFloat        // Logical coordinate [start, end)
        let end: CGFloat          // Logical coordinate [start, end)
        let type: ZoneType
        let pairedZoneId: UUID?   // Paired zone ID (for PP/BP)

        /// Get the paired zone from cache
        func getPairedZone(from cache: EdgeNavigationCache) -> EdgeZoneCache? {
            guard let pairedId = pairedZoneId else { return nil }
            return cache.zonesById[pairedId]
        }
    }

    // MARK: - Storage

    // displayId → edge → sorted zones
    private var zonesByDisplay: [String: [EdgeDirection: [EdgeZoneCache]]] = [:]

    // zoneId → zone (for quick paired zone lookup)
    private var zonesById: [UUID: EdgeZoneCache] = [:]

    // MARK: - Initialization

    /// Build cache from DisplayConfiguration and current screens
    init(configuration: DisplayConfiguration, screens: [NSScreen]) {
        buildCache(configuration: configuration, screens: screens)
    }

    /// Empty cache
    init() {}

    // MARK: - Cache Building

    /// Rebuild cache from configuration
    func rebuild(configuration: DisplayConfiguration, screens: [NSScreen]) {
        zonesByDisplay.removeAll()
        zonesById.removeAll()
        buildCache(configuration: configuration, screens: screens)
    }

    private func buildCache(configuration: DisplayConfiguration, screens: [NSScreen]) {
        // Build screen lookup by DisplayIdentifier
        let screenByDisplayId = buildScreenLookup(screens: screens)

        // Build zone pair lookup
        let zonePairLookup = buildZonePairLookup(configuration: configuration)

        // Process each display
        for display in configuration.displays {
            let displayId = display.identifier.stringRepresentation
            guard let screen = screenByDisplayId[displayId] else {
                continue  // Skip disconnected displays
            }

            // Process each edge
            for edge in EdgeDirection.allCases {
                // Get zones for this display-edge
                let zones = configuration.edgeZones.filter {
                    $0.displayId == displayId && $0.edge == edge
                }

                // Convert to cache format with zone type determination
                var cacheZones: [EdgeZoneCache] = []
                for zone in zones {
                    let pairedZoneId = zonePairLookup[zone.id]
                    let isLogicallyAdjacent = checkLogicalAdjacency(
                        display: display,
                        screen: screen,
                        edge: edge,
                        allDisplays: configuration.displays,
                        allScreens: screenByDisplayId
                    )

                    let zoneType = determineZoneType(
                        isLogicallyAdjacent: isLogicallyAdjacent,
                        hasPair: pairedZoneId != nil
                    )

                    // Convert normalized coordinates [0,1] to logical pixel coordinates
                    let (start, end) = convertToLogicalCoordinates(
                        edge: edge,
                        rangeStart: zone.rangeStart,
                        rangeEnd: zone.rangeEnd,
                        screen: screen
                    )

                    let cacheZone = EdgeZoneCache(
                        id: zone.id,
                        displayId: displayId,
                        edge: edge,
                        start: start,
                        end: end,
                        type: zoneType,
                        pairedZoneId: pairedZoneId
                    )

                    cacheZones.append(cacheZone)
                    zonesById[zone.id] = cacheZone
                }

                // Sort zones by start position
                cacheZones.sort { $0.start < $1.start }

                // Store in cache
                if zonesByDisplay[displayId] == nil {
                    zonesByDisplay[displayId] = [:]
                }
                zonesByDisplay[displayId]?[edge] = cacheZones

                NSLog("🗂️ Cached \(cacheZones.count) zones for \(displayId).\(edge)")
            }
        }

        NSLog("✅ EdgeNavigationCache built: \(zonesById.count) total zones")
    }

    // MARK: - Zone Type Determination

    private func determineZoneType(isLogicallyAdjacent: Bool, hasPair: Bool) -> ZoneType {
        switch (isLogicallyAdjacent, hasPair) {
        case (true, true):   return .PP  // Adjacent, has pair → Pass→Pass
        case (true, false):  return .PB  // Adjacent, no pair → Pass→Block
        case (false, true):  return .BP  // Not adjacent, has pair → Block→Pass (future)
        case (false, false): return .BB  // Not adjacent, no pair → Block→Block
        }
    }

    // MARK: - Logical Adjacency Check

    private func checkLogicalAdjacency(
        display: PhysicalDisplayLayout,
        screen: NSScreen,
        edge: EdgeDirection,
        allDisplays: [PhysicalDisplayLayout],
        allScreens: [String: NSScreen]
    ) -> Bool {
        let frame = screen.frame
        let epsilon: CGFloat = 1.0

        for otherDisplay in allDisplays {
            let otherId = otherDisplay.identifier.stringRepresentation
            guard otherId != display.identifier.stringRepresentation,
                  let otherScreen = allScreens[otherId] else {
                continue
            }

            let otherFrame = otherScreen.frame

            // Check if adjacent based on edge
            switch edge {
            case .top:
                if abs(frame.maxY - otherFrame.minY) < epsilon {
                    return true  // Top edge touches other's bottom
                }
            case .bottom:
                if abs(frame.minY - otherFrame.maxY) < epsilon {
                    return true  // Bottom edge touches other's top
                }
            case .right:
                if abs(frame.maxX - otherFrame.minX) < epsilon {
                    return true  // Right edge touches other's left
                }
            case .left:
                if abs(frame.minX - otherFrame.maxX) < epsilon {
                    return true  // Left edge touches other's right
                }
            }
        }

        return false
    }

    // MARK: - Coordinate Conversion

    private func convertToLogicalCoordinates(
        edge: EdgeDirection,
        rangeStart: Double,
        rangeEnd: Double,
        screen: NSScreen
    ) -> (start: CGFloat, end: CGFloat) {
        let frame = screen.frame

        switch edge {
        case .top, .bottom:
            // Horizontal edges: use X coordinates
            let start = frame.minX + CGFloat(rangeStart) * frame.width
            let end = frame.minX + CGFloat(rangeEnd) * frame.width
            return (start, end)

        case .left, .right:
            // Vertical edges: use Y coordinates (already in macOS coords, origin at bottom)
            let start = frame.minY + CGFloat(rangeStart) * frame.height
            let end = frame.minY + CGFloat(rangeEnd) * frame.height
            return (start, end)
        }
    }

    // MARK: - Lookup

    /// Find zone at the given exit point
    /// - Parameters:
    ///   - displayId: Source display ID
    ///   - edge: Edge direction
    ///   - exitPoint: Exit point in logical coordinates (X for horizontal edges, Y for vertical edges)
    /// - Returns: The zone containing the exit point, or nil if not found
    func lookup(displayId: String, edge: EdgeDirection, exitPoint: CGFloat) -> EdgeZoneCache? {
        guard let zones = zonesByDisplay[displayId]?[edge], !zones.isEmpty else {
            return nil
        }

        // Check if exitPoint is before the first zone
        if exitPoint < zones[0].start {
            return nil
        }

        // Linear scan with corrected comparison logic
        // Zone ranges are [start, end), so we compare with next zone's start
        for i in 1..<zones.count {
            if exitPoint < zones[i].start {
                // Check if exitPoint is within the previous zone's range [start, end)
                let zone = zones[i - 1]
                if exitPoint >= zone.start && exitPoint < zone.end {
                    return zone
                }
                return nil
            }
        }

        // Check if point is in the last zone
        if let lastZone = zones.last, exitPoint >= lastZone.start && exitPoint < lastZone.end {
            return lastZone
        }

        return nil
    }

    /// Get all zones for a specific display and edge
    /// - Parameters:
    ///   - displayId: Display ID
    ///   - edge: Edge direction
    /// - Returns: Array of zones for the specified display and edge, empty if none exist
    func getZones(displayId: String, edge: EdgeDirection) -> [EdgeZoneCache] {
        return zonesByDisplay[displayId]?[edge] ?? []
    }

    // MARK: - Helper Methods

    private func buildScreenLookup(screens: [NSScreen]) -> [String: NSScreen] {
        var lookup: [String: NSScreen] = [:]
        for screen in screens {
            let desc = screen.deviceDescription
            guard let displayID = desc[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }
            let identifier = DisplayIdentifier(displayID: displayID).stringRepresentation
            lookup[identifier] = screen
        }
        return lookup
    }

    private func buildZonePairLookup(configuration: DisplayConfiguration) -> [UUID: UUID] {
        var lookup: [UUID: UUID] = [:]
        for pair in configuration.edgeZonePairs {
            // Bidirectional mapping
            lookup[pair.zone1Id] = pair.zone2Id
            lookup[pair.zone2Id] = pair.zone1Id
        }
        return lookup
    }

    // MARK: - Debug

    func printDebugInfo() {
        NSLog("=== EdgeNavigationCache Debug Info ===")
        NSLog("Total zones: \(zonesById.count)")

        for (displayId, edgeDict) in zonesByDisplay.sorted(by: { $0.key < $1.key }) {
            for (edge, zones) in edgeDict.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                NSLog("Display \(displayId), Edge \(edge):")
                for zone in zones {
                    let pairInfo = zone.pairedZoneId != nil ? "→ \(zone.pairedZoneId!)" : "no pair"
                    NSLog("  [\(zone.start)..\(zone.end)) \(zone.type) \(pairInfo)")
                }
            }
        }
    }
}
