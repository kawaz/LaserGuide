// EdgeNavigationManager.swift
import Foundation
import CoreGraphics
import AppKit

/// Manages Smart Edge Navigation using logical coordinates and Edge Zone Pairs
/// - Smart Edge Navigation: Controls cursor behavior at display edges based on Edge Zone configuration
class EdgeNavigationManager {
    static let shared = EdgeNavigationManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let calibrationManager = CalibrationDataManager.shared

    private var smartEdgeEnabled: Bool = false
    private var edgeCache: EdgeNavigationCache = EdgeNavigationCache()
    private let status = EdgeNavigationStatus.shared

    // Debug option: Skip actual mouse warp (for debugging only)
    var debugSkipMouseWarp: Bool = false

    // Track last known mouse position to detect boundary crossings
    private var lastMouseLocation: CGPoint = .zero
    private var lastValidScreen: NSScreen?

    private init() {
        lastMouseLocation = NSEvent.mouseLocation
        loadSettings()
        setupNotificationObservers()
        NSLog("📊 EdgeNavigationManager initialized")
    }

    // MARK: - Settings

    private func loadSettings() {
        smartEdgeEnabled = UserDefaults.standard.bool(forKey: "SmartEdgeNavigationEnabled")
    }

    func setSmartEdge(enabled: Bool) {
        smartEdgeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "SmartEdgeNavigationEnabled")
        updateEventTapState()
    }

    var isSmartEdgeEnabled: Bool {
        return smartEdgeEnabled
    }

    // MARK: - Lifecycle

    func startIfNeeded() {
        updateEventTapState()
    }

    func stop() {
        stopEventTap()
    }

    private func updateEventTapState() {
        let shouldBeRunning = smartEdgeEnabled && calibrationManager.loadCalibration() != nil

        if shouldBeRunning && eventTap == nil {
            rebuildCache()
            startEventTap()
        } else if !shouldBeRunning && eventTap != nil {
            stopEventTap()
        }
    }

    private func rebuildCache() {
        guard let config = calibrationManager.loadCalibration() else {
            NSLog("⚠️ No calibration found")
            updateManagerStatus()
            return
        }
        let screens = NSScreen.screens
        edgeCache.rebuild(configuration: config, screens: screens)
        edgeCache.printDebugInfo()

        let cacheInfo = "displays: \(config.displays.count), zones: \(config.edgeZones.count), pairs: \(config.edgeZonePairs.count)"
        NSLog("✅ Edge cache rebuilt: \(cacheInfo)")
        updateManagerStatus()
    }

    private func startEventTap() {
        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.rightMouseDragged.rawValue) |
                        (1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<EdgeNavigationManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("⚠️ Failed to create event tap for SmartEdge (Accessibility permissions needed)")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("🧭 Smart Edge Navigation event tap started")
        updateManagerStatus()
    }

    private func stopEventTap() {
        guard let tap = eventTap else { return }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        runLoopSource = nil
        eventTap = nil
        NSLog("🧭 Smart Edge Navigation event tap stopped")
        updateManagerStatus()
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events (e.g., when accessibility permission is revoked)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("⚠️ Smart Edge Navigation event tap disabled (type: \(type.rawValue))")

            // Check if we still have accessibility permissions
            if !checkAccessibilityPermissions() {
                NSLog("⚠️ Accessibility permissions revoked - stopping event tap")
                DispatchQueue.main.async { [weak self] in
                    self?.setSmartEdge(enabled: false)
                }
            } else {
                // Re-enable the tap if we still have permissions
                if let tap = eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    NSLog("🔄 Event tap re-enabled")
                }
            }

            return Unmanaged.passRetained(event)
        }

        let currentLocation = NSEvent.mouseLocation

        guard smartEdgeEnabled else {
            lastMouseLocation = currentLocation
            lastValidScreen = NSScreen.screens.first(where: { $0.frame.contains(currentLocation) })
            return Unmanaged.passRetained(event)
        }

        guard calibrationManager.loadCalibration() != nil else {
            lastMouseLocation = currentLocation
            lastValidScreen = NSScreen.screens.first(where: { $0.frame.contains(currentLocation) })
            return Unmanaged.passRetained(event)
        }

        guard let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(currentLocation) }) else {
            lastMouseLocation = currentLocation
            return Unmanaged.passRetained(event)
        }

        // Update status with current mouse and display info
        updateStatus(currentLocation: currentLocation, currentScreen: currentScreen, eventType: type)

        // Early return: Same screen, no boundary crossing
        if let lastValid = lastValidScreen, currentScreen == lastValid {
            lastMouseLocation = currentLocation
            return Unmanaged.passRetained(event)
        }

        // Boundary crossing detected
        var didWarp = false
        if let lastValid = lastValidScreen {
            didWarp = handleBoundaryCrossing(
                from: lastValid,
                to: currentScreen,
                lastLocation: lastMouseLocation,
                currentLocation: currentLocation,
                event: event
            )
        }

        // Update tracking state (skip if we warped, as lastMouseLocation was already updated to target)
        if !didWarp {
            lastMouseLocation = currentLocation
        }
        lastValidScreen = currentScreen
        return Unmanaged.passRetained(event)
    }

    // MARK: - Boundary Crossing Logic

    private func handleBoundaryCrossing(
        from sourceScreen: NSScreen,
        to targetScreen: NSScreen,
        lastLocation: CGPoint,
        currentLocation: CGPoint,
        event: CGEvent
    ) -> Bool {
        // Extract RAW CGEvent information
        let eventType = CGEventType(rawValue: UInt32(event.type.rawValue)) ?? .mouseMoved
        let eventName = eventTypeName(eventType)
        let eventTimestamp = Double(event.timestamp) / 1_000_000_000.0  // Convert nanoseconds to seconds
        let eventFlags = event.flags
        let rawEventLocation = event.location  // RAW: CGEvent location (CG coordinates)
        let rawEventDelta = CGPoint(x: event.getDoubleValueField(.mouseEventDeltaX),
                                   y: event.getDoubleValueField(.mouseEventDeltaY))  // RAW: CGEvent delta

        // Calculate PROCESSED values
        let calculatedDelta = CGPoint(x: currentLocation.x - lastLocation.x, y: currentLocation.y - lastLocation.y)

        // Calculate boundary intersection point
        let intersection = calculateBoundaryIntersection(
            from: lastLocation,
            to: currentLocation,
            sourceFrame: sourceScreen.frame
        )

        // Update last display info before switching
        let sourceID = sourceScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let sourceDisplayId = DisplayIdentifier(displayID: sourceID).stringRepresentation
        var sourceEdges: [EdgeNavigationStatus.EdgeInfo] = []
        var sourcePhysicalFrame: String? = nil
        if let config = calibrationManager.loadCalibration() {
            for edge in EdgeDirection.allCases {
                if let zones = getEdgeZonesFor(displayId: sourceDisplayId, edge: edge, config: config, screen: sourceScreen) {
                    sourceEdges.append(contentsOf: zones)
                }
            }
            // Get physical frame from config
            if let display = config.displays.first(where: { $0.identifier.stringRepresentation == sourceDisplayId }) {
                sourcePhysicalFrame = "(\(String(format: "%.1f", display.position.x)), \(String(format: "%.1f", display.position.y)), \(String(format: "%.1f", display.size.width)), \(String(format: "%.1f", display.size.height)))"
            }
        }
        status.updateLastDisplay(
            name: sourceScreen.localizedName,
            logicalFrame: sourceScreen.frame,
            physicalFrame: sourcePhysicalFrame,
            edges: sourceEdges
        )

        // Determine which edge was crossed
        guard let edge = determineEdgeDirection(exitPoint: intersection, frame: sourceScreen.frame) else {
            NSLog("🌐 Boundary: \(sourceScreen.localizedName) → \(targetScreen.localizedName) [edge unknown]")
            return false
        }

        // Reuse display identifier from above
        let displayId = sourceDisplayId

        // Calculate exit point coordinate (X for horizontal edges, Y for vertical edges)
        let exitPoint: CGFloat
        switch edge {
        case .top, .bottom:
            exitPoint = intersection.x
        case .left, .right:
            exitPoint = intersection.y
        }

        // Lookup zone at exit point
        guard let zone = edgeCache.lookup(displayId: displayId, edge: edge, exitPoint: exitPoint) else {
            NSLog("🌐 Boundary: \(sourceScreen.localizedName).\(edge) → \(targetScreen.localizedName) [no zone]")
            return false
        }

        NSLog("🌐 Boundary: \(sourceScreen.localizedName).\(edge) → \(targetScreen.localizedName) [zone: \(zone.type)]")
        NSLog("   Exit: (\(String(format: "%.1f", intersection.x)), \(String(format: "%.1f", intersection.y))) exitPoint=\(String(format: "%.1f", exitPoint))")

        // Handle based on zone type
        switch zone.type {
        case .BB:
            // Block→Block: macOS default, do nothing
            status.updateBoundaryCrossing(EdgeNavigationStatus.BoundaryCrossingInfo(
                timestamp: Date(),
                fromDisplay: sourceScreen.localizedName,
                toDisplay: targetScreen.localizedName,
                edge: edge.rawValue,
                exitPoint: intersection,
                exitCoordinate: exitPoint,
                fromZone: EdgeNavigationStatus.ZoneInfo(
                    type: "\(zone.type)",
                    start: zone.start,
                    end: zone.end
                ),
                toZone: nil,
                action: "BB: Default crossing (no warp)",
                details: [
                    "zoneLength": String(format: "%.1f", zone.end - zone.start)
                ],
                mouseEvent: eventName,
                eventTimestamp: eventTimestamp,
                eventFlags: eventFlags,
                rawEventLocation: rawEventLocation,
                rawEventDelta: rawEventDelta,
                previousPosition: lastLocation,
                newPosition: currentLocation,
                calculatedDelta: calculatedDelta,
                intersection: intersection
            ))
            return false

        case .BP:
            // Block→Pass: Future implementation
            NSLog("   ⚠️ BP zones not yet implemented")
            status.updateBoundaryCrossing(EdgeNavigationStatus.BoundaryCrossingInfo(
                timestamp: Date(),
                fromDisplay: sourceScreen.localizedName,
                toDisplay: targetScreen.localizedName,
                edge: edge.rawValue,
                exitPoint: intersection,
                exitCoordinate: exitPoint,
                fromZone: EdgeNavigationStatus.ZoneInfo(
                    type: "\(zone.type)",
                    start: zone.start,
                    end: zone.end
                ),
                toZone: nil,
                action: "BP: Not implemented",
                details: [:],
                mouseEvent: eventName,
                eventTimestamp: eventTimestamp,
                eventFlags: eventFlags,
                rawEventLocation: rawEventLocation,
                rawEventDelta: rawEventDelta,
                previousPosition: lastLocation,
                newPosition: currentLocation,
                calculatedDelta: calculatedDelta,
                intersection: intersection
            ))
            return false

        case .PP:
            // Pass→Pass: Warp to paired zone with physical correction
            guard let pairedZone = zone.getPairedZone(from: edgeCache) else {
                NSLog("   ⚠️ PP: No paired zone found")
                return false
            }

            // Get target screen
            guard let targetScreen = getScreen(displayId: pairedZone.displayId) else {
                NSLog("   ⚠️ PP: Target screen not found")
                return false
            }

            // Load physical configuration
            guard let config = calibrationManager.loadCalibration() else {
                NSLog("   ⚠️ PP: No calibration data, falling back to logical mapping")
                // Fallback to logical coordinate mapping
                let zoneLength = zone.end - zone.start
                guard zoneLength > 0 else {
                    NSLog("   ⚠️ PP: Invalid zone length")
                    return false
                }
                let t = (exitPoint - zone.start) / zoneLength
                let pairedZoneLength = pairedZone.end - pairedZone.start
                let targetExitPoint = pairedZone.start + t * pairedZoneLength
                let targetPoint = calculatePointOnEdge(
                    exitPoint: targetExitPoint,
                    edge: pairedZone.edge,
                    frame: targetScreen.frame
                )

                // Warp to target
                let cgPoint = convertToCGCoordinates(targetPoint)
                if !debugSkipMouseWarp {
                    CGWarpMouseCursorPosition(cgPoint)
                    lastMouseLocation = targetPoint
                }

                NSLog("   ✨ PP: Warped to \(pairedZone.displayId).\(pairedZone.edge) at t=\(String(format: "%.3f", t)) (logical fallback)\(debugSkipMouseWarp ? " [DRY-RUN]" : "")")
                NSLog("      Target: (\(String(format: "%.1f", targetPoint.x)), \(String(format: "%.1f", targetPoint.y)))")

                status.updateBoundaryCrossing(EdgeNavigationStatus.BoundaryCrossingInfo(
                    timestamp: Date(),
                    fromDisplay: sourceScreen.localizedName,
                    toDisplay: targetScreen.localizedName,
                    edge: edge.rawValue,
                    exitPoint: intersection,
                    exitCoordinate: exitPoint,
                    fromZone: EdgeNavigationStatus.ZoneInfo(
                        type: "\(zone.type)",
                        start: zone.start,
                        end: zone.end
                    ),
                    toZone: EdgeNavigationStatus.ZoneInfo(
                        type: "PP-paired",
                        start: pairedZone.start,
                        end: pairedZone.end
                    ),
                    action: "PP: Warped to paired zone (logical)",
                    details: [
                        "targetDisplay": pairedZone.displayId,
                        "targetEdge": pairedZone.edge.rawValue,
                        "relativePosition": String(format: "%.3f", t),
                        "targetX": String(format: "%.1f", targetPoint.x),
                        "targetY": String(format: "%.1f", targetPoint.y),
                        "zoneLength": String(format: "%.1f", zoneLength),
                        "targetZoneLength": String(format: "%.1f", pairedZoneLength)
                    ],
                    mouseEvent: eventName,
                    eventTimestamp: eventTimestamp,
                    eventFlags: eventFlags,
                    rawEventLocation: rawEventLocation,
                    rawEventDelta: rawEventDelta,
                    previousPosition: lastLocation,
                    newPosition: currentLocation,
                    calculatedDelta: calculatedDelta,
                    intersection: intersection
                ))
                return true
            }

            // Get display physical info
            guard let sourceDisplay = config.displays.first(where: { $0.identifier.stringRepresentation == displayId }),
                  let targetDisplay = config.displays.first(where: { $0.identifier.stringRepresentation == pairedZone.displayId }) else {
                NSLog("   ⚠️ PP: Physical display info not found")
                return false
            }

            // Convert logical exitPoint to physical coordinate (mm)
            let physicalExitPoint = logicalToPhysical(
                logicalCoord: exitPoint,
                edge: edge,
                logicalFrame: sourceScreen.frame,
                physicalPosition: sourceDisplay.position,
                physicalSize: sourceDisplay.size
            )

            // Convert zone ranges to physical coordinates (mm)
            let sourceZonePhysicalStart = logicalToPhysical(
                logicalCoord: zone.start,
                edge: edge,
                logicalFrame: sourceScreen.frame,
                physicalPosition: sourceDisplay.position,
                physicalSize: sourceDisplay.size
            )
            let sourceZonePhysicalEnd = logicalToPhysical(
                logicalCoord: zone.end,
                edge: edge,
                logicalFrame: sourceScreen.frame,
                physicalPosition: sourceDisplay.position,
                physicalSize: sourceDisplay.size
            )

            // Calculate relative position in physical coordinates
            let sourceZonePhysicalLength = abs(sourceZonePhysicalEnd - sourceZonePhysicalStart)
            guard sourceZonePhysicalLength > 0 else {
                NSLog("   ⚠️ PP: Invalid physical zone length")
                return false
            }
            let physicalRelativePosition = (physicalExitPoint - sourceZonePhysicalStart) / sourceZonePhysicalLength

            // Convert target zone ranges to physical coordinates
            let targetZonePhysicalStart = logicalToPhysical(
                logicalCoord: pairedZone.start,
                edge: pairedZone.edge,
                logicalFrame: targetScreen.frame,
                physicalPosition: targetDisplay.position,
                physicalSize: targetDisplay.size
            )
            let targetZonePhysicalEnd = logicalToPhysical(
                logicalCoord: pairedZone.end,
                edge: pairedZone.edge,
                logicalFrame: targetScreen.frame,
                physicalPosition: targetDisplay.position,
                physicalSize: targetDisplay.size
            )

            // Map physical relative position to target zone
            let targetZonePhysicalLength = abs(targetZonePhysicalEnd - targetZonePhysicalStart)
            let targetPhysicalExitPoint = targetZonePhysicalStart + physicalRelativePosition * targetZonePhysicalLength

            // Convert back to logical coordinate
            let targetLogicalExitPoint = physicalToLogical(
                physicalCoord: targetPhysicalExitPoint,
                edge: pairedZone.edge,
                logicalFrame: targetScreen.frame,
                physicalPosition: targetDisplay.position,
                physicalSize: targetDisplay.size
            )

            // Calculate target point on paired edge
            let targetPoint = calculatePointOnEdge(
                exitPoint: targetLogicalExitPoint,
                edge: pairedZone.edge,
                frame: targetScreen.frame
            )

            NSLog("   🔬 Physical mapping: exit=\(String(format: "%.1f", physicalExitPoint))mm, zone=[\(String(format: "%.1f", sourceZonePhysicalStart)), \(String(format: "%.1f", sourceZonePhysicalEnd)))mm, t=\(String(format: "%.3f", physicalRelativePosition))")
            NSLog("      Target: physical=\(String(format: "%.1f", targetPhysicalExitPoint))mm, zone=[\(String(format: "%.1f", targetZonePhysicalStart)), \(String(format: "%.1f", targetZonePhysicalEnd)))mm")

            // Warp to target
            let cgPoint = convertToCGCoordinates(targetPoint)
            if !debugSkipMouseWarp {
                CGWarpMouseCursorPosition(cgPoint)
                // Update last mouse location to prevent detecting this warp as a boundary crossing
                lastMouseLocation = targetPoint
            }

            NSLog("   ✨ PP: Warped to \(pairedZone.displayId).\(pairedZone.edge) at t=\(String(format: "%.3f", physicalRelativePosition))\(debugSkipMouseWarp ? " [DRY-RUN]" : "")")
            NSLog("      Target: (\(String(format: "%.1f", targetPoint.x)), \(String(format: "%.1f", targetPoint.y)))")

            status.updateBoundaryCrossing(EdgeNavigationStatus.BoundaryCrossingInfo(
                timestamp: Date(),
                fromDisplay: sourceScreen.localizedName,
                toDisplay: targetScreen.localizedName,
                edge: edge.rawValue,
                exitPoint: intersection,
                exitCoordinate: exitPoint,
                fromZone: EdgeNavigationStatus.ZoneInfo(
                    type: "\(zone.type)",
                    start: zone.start,
                    end: zone.end
                ),
                toZone: EdgeNavigationStatus.ZoneInfo(
                    type: "PP-paired",
                    start: pairedZone.start,
                    end: pairedZone.end
                ),
                action: "PP: Warped to paired zone",
                details: [
                    "targetDisplay": pairedZone.displayId,
                    "targetEdge": pairedZone.edge.rawValue,
                    "relativePosition": String(format: "%.3f", physicalRelativePosition),
                    "targetX": String(format: "%.1f", targetPoint.x),
                    "targetY": String(format: "%.1f", targetPoint.y),
                    "zoneLength": String(format: "%.1f", zone.end - zone.start),
                    "targetZoneLength": String(format: "%.1f", pairedZone.end - pairedZone.start)
                ],
                mouseEvent: eventName,
                eventTimestamp: eventTimestamp,
                eventFlags: eventFlags,
                rawEventLocation: rawEventLocation,
                rawEventDelta: rawEventDelta,
                previousPosition: lastLocation,
                newPosition: currentLocation,
                calculatedDelta: calculatedDelta,
                intersection: intersection
            ))
            return true

        case .PB:
            // Pass→Block: Constrain cursor to edge
            let constrainedPoint = constrainToEdge(
                exitPoint: intersection,
                edge: edge,
                frame: sourceScreen.frame
            )
            let cgPoint = convertToCGCoordinates(constrainedPoint)
            if !debugSkipMouseWarp {
                CGWarpMouseCursorPosition(cgPoint)
                // Update last mouse location to prevent detecting this warp as a boundary crossing
                lastMouseLocation = constrainedPoint
            }
            NSLog("   🚫 PB: Blocked at edge (\(String(format: "%.1f", constrainedPoint.x)), \(String(format: "%.1f", constrainedPoint.y)))\(debugSkipMouseWarp ? " [DRY-RUN]" : "")")

            status.updateBoundaryCrossing(EdgeNavigationStatus.BoundaryCrossingInfo(
                timestamp: Date(),
                fromDisplay: sourceScreen.localizedName,
                toDisplay: targetScreen.localizedName,
                edge: edge.rawValue,
                exitPoint: intersection,
                exitCoordinate: exitPoint,
                fromZone: EdgeNavigationStatus.ZoneInfo(
                    type: "\(zone.type)",
                    start: zone.start,
                    end: zone.end
                ),
                toZone: nil,
                action: "PB: Blocked at edge",
                details: [
                    "constrainedX": String(format: "%.1f", constrainedPoint.x),
                    "constrainedY": String(format: "%.1f", constrainedPoint.y),
                    "deltaX": String(format: "%.1f", constrainedPoint.x - intersection.x),
                    "deltaY": String(format: "%.1f", constrainedPoint.y - intersection.y)
                ],
                mouseEvent: eventName,
                eventTimestamp: eventTimestamp,
                eventFlags: eventFlags,
                rawEventLocation: rawEventLocation,
                rawEventDelta: rawEventDelta,
                previousPosition: lastLocation,
                newPosition: currentLocation,
                calculatedDelta: calculatedDelta,
                intersection: intersection
            ))
            return true
        }
    }

    // MARK: - Coordinate Utilities

    /// Get NSScreen by display identifier
    private func getScreen(displayId: String) -> NSScreen? {
        for screen in NSScreen.screens {
            let desc = screen.deviceDescription
            guard let cgDisplayID = desc[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }
            let identifier = DisplayIdentifier(displayID: cgDisplayID).stringRepresentation
            if identifier == displayId {
                return screen
            }
        }
        return nil
    }

    /// Calculate a point on the specified edge at the given exit point coordinate
    private func calculatePointOnEdge(exitPoint: CGFloat, edge: EdgeDirection, frame: CGRect) -> CGPoint {
        switch edge {
        case .left:
            return CGPoint(x: frame.minX, y: exitPoint)
        case .right:
            return CGPoint(x: frame.maxX, y: exitPoint)
        case .bottom:
            return CGPoint(x: exitPoint, y: frame.minY)
        case .top:
            return CGPoint(x: exitPoint, y: frame.maxY)
        }
    }

    /// Constrain a point to the specified edge of a frame
    private func constrainToEdge(exitPoint: CGPoint, edge: EdgeDirection, frame: CGRect) -> CGPoint {
        switch edge {
        case .left:
            return CGPoint(x: frame.minX, y: exitPoint.y)
        case .right:
            return CGPoint(x: frame.maxX, y: exitPoint.y)
        case .bottom:
            return CGPoint(x: exitPoint.x, y: frame.minY)
        case .top:
            return CGPoint(x: exitPoint.x, y: frame.maxY)
        }
    }

    /// Determine which edge direction the exit point is on
    private func determineEdgeDirection(exitPoint: CGPoint, frame: CGRect) -> EdgeDirection? {
        let epsilon: CGFloat = 1.0

        if abs(exitPoint.x - frame.minX) < epsilon {
            return .left
        }
        if abs(exitPoint.x - frame.maxX) < epsilon {
            return .right
        }
        if abs(exitPoint.y - frame.minY) < epsilon {
            return .bottom
        }
        if abs(exitPoint.y - frame.maxY) < epsilon {
            return .top
        }

        return nil
    }

    /// Calculate exact boundary intersection point from movement vector
    private func calculateBoundaryIntersection(from: CGPoint, to: CGPoint, sourceFrame: CGRect) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y

        var intersectionX = to.x
        var intersectionY = to.y
        var minT: CGFloat = 1.0

        // Find earliest intersection with any boundary edge

        // Left edge
        if to.x < sourceFrame.minX && dx != 0 {
            let t = (sourceFrame.minX - from.x) / dx
            if t >= 0 && t < minT {
                minT = t
                intersectionX = sourceFrame.minX
                intersectionY = from.y + dy * t
            }
        }

        // Right edge
        if to.x > sourceFrame.maxX && dx != 0 {
            let t = (sourceFrame.maxX - from.x) / dx
            if t >= 0 && t < minT {
                minT = t
                intersectionX = sourceFrame.maxX
                intersectionY = from.y + dy * t
            }
        }

        // Bottom edge
        if to.y < sourceFrame.minY && dy != 0 {
            let t = (sourceFrame.minY - from.y) / dy
            if t >= 0 && t < minT {
                minT = t
                intersectionX = from.x + dx * t
                intersectionY = sourceFrame.minY
            }
        }

        // Top edge
        if to.y > sourceFrame.maxY && dy != 0 {
            let t = (sourceFrame.maxY - from.y) / dy
            if t >= 0 && t < minT {
                minT = t
                intersectionX = from.x + dx * t
                intersectionY = sourceFrame.maxY
            }
        }

        return CGPoint(x: intersectionX, y: intersectionY)
    }

    /// Convert NSEvent mouse location (bottom-left origin) to CGEvent coordinates (top-left origin)
    private func convertToCGCoordinates(_ nsLocation: NSPoint) -> CGPoint {
        // Calculate the unified screen space bounds (all displays)
        var maxY: CGFloat = 0
        for screen in NSScreen.screens {
            let screenMaxY = screen.frame.maxY
            if screenMaxY > maxY {
                maxY = screenMaxY
            }
        }

        // CGEvent uses top-left origin, NSEvent uses bottom-left
        return CGPoint(x: nsLocation.x, y: maxY - nsLocation.y)
    }

    // MARK: - Status Updates

    func requestStatusUpdate() {
        // Update manager status even when Smart Edge is disabled
        updateManagerStatus()

        // Update mouse and display info from current state
        let currentLocation = NSEvent.mouseLocation
        if let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(currentLocation) }) {
            let delta = CGPoint(x: currentLocation.x - lastMouseLocation.x, y: currentLocation.y - lastMouseLocation.y)

            status.updateMousePosition(
                logical: currentLocation,
                physical: nil,
                delta: delta,
                eventName: "polled"
            )

            let deviceDescription = currentScreen.deviceDescription
            let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
            let displayId = DisplayIdentifier(displayID: displayID).stringRepresentation

            var edges: [EdgeNavigationStatus.EdgeInfo] = []
            var physicalFrame: String? = nil
            if let config = calibrationManager.loadCalibration() {
                for edge in EdgeDirection.allCases {
                    if let zones = getEdgeZonesFor(displayId: displayId, edge: edge, config: config, screen: currentScreen) {
                        edges.append(contentsOf: zones)
                    }
                }
                // Get physical frame from config
                if let display = config.displays.first(where: { $0.identifier.stringRepresentation == displayId }) {
                    physicalFrame = "(\(String(format: "%.1f", display.position.x)), \(String(format: "%.1f", display.position.y)), \(String(format: "%.1f", display.size.width)), \(String(format: "%.1f", display.size.height)))"
                }
            }

            status.updateCurrentDisplay(
                name: currentScreen.localizedName,
                logicalFrame: currentScreen.frame,
                physicalFrame: physicalFrame,
                edges: edges
            )
        }
    }

    private func updateManagerStatus() {
        let config = calibrationManager.loadCalibration()
        let cacheInfo: String
        if let config = config {
            cacheInfo = "displays: \(config.displays.count), zones: \(config.edgeZones.count), pairs: \(config.edgeZonePairs.count)"
        } else {
            cacheInfo = "No calibration"
        }

        status.updateManagerState(
            enabled: smartEdgeEnabled,
            hasPermissions: checkAccessibilityPermissions(),
            tapActive: eventTap != nil,
            cache: cacheInfo
        )
    }

    private func updateStatus(currentLocation: CGPoint, currentScreen: NSScreen, eventType: CGEventType) {
        let delta = CGPoint(x: currentLocation.x - lastMouseLocation.x, y: currentLocation.y - lastMouseLocation.y)
        let eventName = eventTypeName(eventType)

        // Update mouse position
        status.updateMousePosition(
            logical: currentLocation,
            physical: nil, // TODO: Calculate physical position if needed
            delta: delta,
            eventName: eventName
        )

        // Update current display info
        let deviceDescription = currentScreen.deviceDescription
        let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        let displayId = DisplayIdentifier(displayID: displayID).stringRepresentation

        // Get edges for this display
        var edges: [EdgeNavigationStatus.EdgeInfo] = []
        var physicalFrame: String? = nil
        if let config = calibrationManager.loadCalibration() {
            for edge in EdgeDirection.allCases {
                if let zones = getEdgeZonesFor(displayId: displayId, edge: edge, config: config, screen: currentScreen) {
                    edges.append(contentsOf: zones)
                }
            }
            // Get physical frame from config
            if let display = config.displays.first(where: { $0.identifier.stringRepresentation == displayId }) {
                physicalFrame = "(\(String(format: "%.1f", display.position.x)), \(String(format: "%.1f", display.position.y)), \(String(format: "%.1f", display.size.width)), \(String(format: "%.1f", display.size.height)))"
            }
        }

        status.updateCurrentDisplay(
            name: currentScreen.localizedName,
            logicalFrame: currentScreen.frame,
            physicalFrame: physicalFrame,
            edges: edges
        )

        // Update manager state (if event tap is working, we must have permissions)
        updateManagerStatus()
    }

    private func eventTypeName(_ type: CGEventType) -> String {
        switch type {
        case .mouseMoved: return "mouseMoved"
        case .leftMouseDragged: return "leftMouseDragged"
        case .rightMouseDragged: return "rightMouseDragged"
        case .otherMouseDragged: return "otherMouseDragged"
        default: return "unknown(\(type.rawValue))"
        }
    }

    private func getEdgeZonesFor(displayId: String, edge: EdgeDirection, config: DisplayConfiguration, screen: NSScreen) -> [EdgeNavigationStatus.EdgeInfo]? {
        // Get all zones for this display and edge from EdgeCache
        let zones = edgeCache.getZones(displayId: displayId, edge: edge)
        guard !zones.isEmpty else {
            return nil
        }

        return zones.map { zone in
            return EdgeNavigationStatus.EdgeInfo(
                direction: edge.rawValue,
                start: zone.start,
                end: zone.end,
                type: "\(zone.type)"
            )
        }
    }

    private func convertToLogicalCoordinates(edge: EdgeDirection, rangeStart: Double, rangeEnd: Double, screen: NSScreen) -> (start: CGFloat, end: CGFloat) {
        let frame = screen.frame
        switch edge {
        case .top, .bottom:
            return (frame.minX + CGFloat(rangeStart) * frame.width,
                    frame.minX + CGFloat(rangeEnd) * frame.width)
        case .left, .right:
            return (frame.minY + CGFloat(rangeStart) * frame.height,
                    frame.minY + CGFloat(rangeEnd) * frame.height)
        }
    }

    private func checkLogicallyAdjacent(displayId: String, edge: EdgeDirection, config: DisplayConfiguration) -> Bool {
        // Simplified - just check if there are any pairs
        return config.edgeZonePairs.count > 0
    }

    private func determineZoneTypeString(isAdjacent: Bool, hasPair: Bool) -> String {
        switch (isAdjacent, hasPair) {
        case (true, true): return "PP"
        case (true, false): return "PB"
        case (false, true): return "BP"
        case (false, false): return "BB"
        }
    }

    // MARK: - Accessibility Permissions

    func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Physical Coordinate Conversion

    /// Convert logical coordinate to physical coordinate (mm)
    /// For horizontal edges (top/bottom), converts X coordinate
    /// For vertical edges (left/right), converts Y coordinate
    private func logicalToPhysical(
        logicalCoord: CGFloat,
        edge: EdgeDirection,
        logicalFrame: CGRect,
        physicalPosition: PhysicalDisplayLayout.PhysicalPoint,
        physicalSize: PhysicalDisplayLayout.PhysicalSize
    ) -> CGFloat {
        switch edge {
        case .top, .bottom:
            // Convert X coordinate
            let relativeX = (logicalCoord - logicalFrame.minX) / logicalFrame.width
            return CGFloat(physicalPosition.x) + relativeX * CGFloat(physicalSize.width)
        case .left, .right:
            // Convert Y coordinate
            let relativeY = (logicalCoord - logicalFrame.minY) / logicalFrame.height
            return CGFloat(physicalPosition.y) + relativeY * CGFloat(physicalSize.height)
        }
    }

    /// Convert physical coordinate (mm) to logical coordinate
    /// For horizontal edges (top/bottom), converts X coordinate
    /// For vertical edges (left/right), converts Y coordinate
    private func physicalToLogical(
        physicalCoord: CGFloat,
        edge: EdgeDirection,
        logicalFrame: CGRect,
        physicalPosition: PhysicalDisplayLayout.PhysicalPoint,
        physicalSize: PhysicalDisplayLayout.PhysicalSize
    ) -> CGFloat {
        switch edge {
        case .top, .bottom:
            // Convert X coordinate
            let relativeX = (physicalCoord - CGFloat(physicalPosition.x)) / CGFloat(physicalSize.width)
            return logicalFrame.minX + relativeX * logicalFrame.width
        case .left, .right:
            // Convert Y coordinate
            let relativeY = (physicalCoord - CGFloat(physicalPosition.y)) / CGFloat(physicalSize.height)
            return logicalFrame.minY + relativeY * logicalFrame.height
        }
    }

    // MARK: - Notifications

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calibrationDidChange),
            name: .calibrationDidSave,
            object: nil
        )
    }

    @objc private func calibrationDidChange() {
        rebuildCache()
        updateEventTapState()
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
}
