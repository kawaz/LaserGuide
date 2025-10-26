// EdgeNavigationStatus.swift
import Foundation
import CoreGraphics
import AppKit

/// Edge Navigation のリアルタイム状態管理
class EdgeNavigationStatus: ObservableObject {
    static let shared = EdgeNavigationStatus()

    // MARK: - Current Mouse State
    @Published var currentLogicalPosition: CGPoint = .zero
    @Published var currentPhysicalPosition: String = "N/A"
    @Published var lastMouseEvent: String = "None"
    @Published var mouseDelta: CGPoint = .zero

    // MARK: - Current Display State
    @Published var currentDisplayName: String = "N/A"
    @Published var currentDisplayLogicalFrame: String = "N/A"
    @Published var currentDisplayPhysicalFrame: String = "N/A"
    @Published var currentDisplayEdges: [EdgeInfo] = []

    // MARK: - Last Display State
    @Published var lastDisplayName: String = "N/A"
    @Published var lastDisplayLogicalFrame: String = "N/A"
    @Published var lastDisplayPhysicalFrame: String = "N/A"
    @Published var lastDisplayEdges: [EdgeInfo] = []

    // MARK: - Boundary Crossing History
    @Published var boundaryCrossingHistory: [BoundaryCrossingInfo] = []
    private let maxHistoryCount = 50  // Keep last 50 crossings

    // MARK: - Manager State
    @Published var isSmartEdgeEnabled: Bool = false
    @Published var hasAccessibilityPermissions: Bool = false
    @Published var eventTapActive: Bool = false
    @Published var cacheInfo: String = "Not built"
    @Published var debugSkipMouseWarp: Bool = false

    struct EdgeInfo: Identifiable {
        let id = UUID()
        let direction: String
        let start: CGFloat
        let end: CGFloat
        let type: String
    }

    struct BoundaryCrossingInfo: Identifiable, Equatable, Hashable {
        let id = UUID()

        static func == (lhs: BoundaryCrossingInfo, rhs: BoundaryCrossingInfo) -> Bool {
            return lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        let timestamp: Date
        let fromDisplay: String
        let toDisplay: String
        let edge: String
        let exitPoint: CGPoint
        let exitCoordinate: CGFloat
        let fromZone: ZoneInfo?
        let toZone: ZoneInfo?
        let action: String
        let details: [String: String]

        // Mouse event details (from CGEvent)
        let mouseEvent: String              // Event type name
        let eventTimestamp: CFTimeInterval  // RAW: CGEvent timestamp
        let eventFlags: CGEventFlags        // RAW: Modifier keys (Shift, Control, etc)

        // RAW values from CGEvent
        let rawEventLocation: CGPoint       // RAW: CGEvent.location (in CG coordinates)
        let rawEventDelta: CGPoint          // RAW: CGEvent delta fields

        // PROCESSED values (tracking + calculation)
        let previousPosition: CGPoint       // PROCESSED: Previous mouse position (NSEvent.mouseLocation)
        let newPosition: CGPoint            // PROCESSED: New mouse position (NSEvent.mouseLocation)
        let calculatedDelta: CGPoint        // PROCESSED: Calculated delta (newPosition - previousPosition)
        let intersection: CGPoint           // PROCESSED: Calculated boundary intersection point

        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var allDetails: String {
            var lines: [String] = []
            lines.append("=== Boundary Crossing ===")
            lines.append("Time: \(formattedTime)")
            lines.append("From: \(fromDisplay)")
            lines.append("To: \(toDisplay)")
            lines.append("Edge: \(edge)")
            lines.append("Exit Point: (\(String(format: "%.1f", exitPoint.x)), \(String(format: "%.1f", exitPoint.y)))")
            lines.append("Exit Coordinate: \(String(format: "%.1f", exitCoordinate))")

            lines.append("\n=== RAW CGEvent Data ===")
            lines.append("Event Type: \(mouseEvent)")
            lines.append("Event Timestamp: \(String(format: "%.6f", eventTimestamp)) seconds")
            lines.append("Event Flags: \(eventFlags.rawValue) (0x\(String(format: "%X", eventFlags.rawValue)))")
            lines.append("RAW Location: (\(String(format: "%.1f", rawEventLocation.x)), \(String(format: "%.1f", rawEventLocation.y)))")
            lines.append("RAW Delta: (\(String(format: "%.1f", rawEventDelta.x)), \(String(format: "%.1f", rawEventDelta.y)))")

            lines.append("\n=== PROCESSED Mouse Tracking ===")
            lines.append("Previous Position: (\(String(format: "%.1f", previousPosition.x)), \(String(format: "%.1f", previousPosition.y)))")
            lines.append("New Position: (\(String(format: "%.1f", newPosition.x)), \(String(format: "%.1f", newPosition.y)))")
            lines.append("Calculated Delta: (\(String(format: "%.1f", calculatedDelta.x)), \(String(format: "%.1f", calculatedDelta.y)))")
            lines.append("Intersection: (\(String(format: "%.1f", intersection.x)), \(String(format: "%.1f", intersection.y)))")

            if let fromZone = fromZone {
                lines.append("\n=== From Zone ===")
                lines.append("Type: \(fromZone.type)")
                lines.append("Range: [\(String(format: "%.1f", fromZone.start)), \(String(format: "%.1f", fromZone.end)))")
            }

            if let toZone = toZone {
                lines.append("\n=== To Zone ===")
                lines.append("Type: \(toZone.type)")
                lines.append("Range: [\(String(format: "%.1f", toZone.start)), \(String(format: "%.1f", toZone.end)))")
            }

            lines.append("\n=== Action ===")
            lines.append(action)

            if !details.isEmpty {
                lines.append("\n=== Additional Details ===")
                for (key, value) in details.sorted(by: { $0.key < $1.key }) {
                    lines.append("\(key): \(value)")
                }
            }

            return lines.joined(separator: "\n")
        }
    }

    struct ZoneInfo {
        let type: String
        let start: CGFloat
        let end: CGFloat
    }

    private init() {}

    func updateMousePosition(logical: CGPoint, physical: String?, delta: CGPoint, eventName: String) {
        DispatchQueue.main.async { [weak self] in
            self?.currentLogicalPosition = logical
            self?.currentPhysicalPosition = physical ?? "N/A"
            self?.mouseDelta = delta
            self?.lastMouseEvent = eventName
        }
    }

    func updateCurrentDisplay(name: String, logicalFrame: NSRect, physicalFrame: String?, edges: [EdgeInfo]) {
        DispatchQueue.main.async { [weak self] in
            self?.currentDisplayName = name
            self?.currentDisplayLogicalFrame = "(\(String(format: "%.0f", logicalFrame.minX)), \(String(format: "%.0f", logicalFrame.minY)), \(String(format: "%.0f", logicalFrame.width)), \(String(format: "%.0f", logicalFrame.height)))"
            self?.currentDisplayPhysicalFrame = physicalFrame ?? "N/A"
            self?.currentDisplayEdges = edges
        }
    }

    func updateLastDisplay(name: String, logicalFrame: NSRect, physicalFrame: String?, edges: [EdgeInfo]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastDisplayName = name
            self?.lastDisplayLogicalFrame = "(\(String(format: "%.0f", logicalFrame.minX)), \(String(format: "%.0f", logicalFrame.minY)), \(String(format: "%.0f", logicalFrame.width)), \(String(format: "%.0f", logicalFrame.height)))"
            self?.lastDisplayPhysicalFrame = physicalFrame ?? "N/A"
            self?.lastDisplayEdges = edges
        }
    }

    func updateBoundaryCrossing(_ info: BoundaryCrossingInfo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Append at the end (chronological order, newest at bottom)
            self.boundaryCrossingHistory.append(info)
            // Keep only last N items (remove from beginning if exceeded)
            if self.boundaryCrossingHistory.count > self.maxHistoryCount {
                self.boundaryCrossingHistory.removeFirst(self.boundaryCrossingHistory.count - self.maxHistoryCount)
            }
        }
    }

    func updateManagerState(enabled: Bool, hasPermissions: Bool, tapActive: Bool, cache: String, debugSkipWarp: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            self?.isSmartEdgeEnabled = enabled
            self?.hasAccessibilityPermissions = hasPermissions
            self?.eventTapActive = tapActive
            self?.cacheInfo = cache
            self?.debugSkipMouseWarp = debugSkipWarp
        }
    }
}
