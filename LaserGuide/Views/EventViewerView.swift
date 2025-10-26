// EventViewerView.swift
import SwiftUI

struct EventViewerView: View {
    @StateObject private var status = EdgeNavigationStatus.shared
    @State private var updateTimer: Timer?
    @State private var selectedCrossing: EdgeNavigationStatus.BoundaryCrossingInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edge Navigation Status Monitor")
                    .font(.headline)
                Spacer()

                // Debug option: Skip mouse warp
                Toggle("Debug: Skip Warp", isOn: Binding(
                    get: { EdgeNavigationManager.shared.debugSkipMouseWarp },
                    set: { EdgeNavigationManager.shared.debugSkipMouseWarp = $0 }
                ))
                .toggleStyle(.switch)
                .font(.caption)
                .help("When enabled, performs edge detection and logging but skips actual cursor movement")

                Spacer()
                    .frame(width: 16)

                StatusIndicator(
                    enabled: status.isSmartEdgeEnabled,
                    hasPermissions: status.hasAccessibilityPermissions,
                    tapActive: status.eventTapActive
                )
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main content: Left (history list) + Right (details)
            HSplitView {
                // Left: Boundary Crossing History List
                VStack(spacing: 0) {
                    HStack {
                        Text("Boundary Crossing History (\(status.boundaryCrossingHistory.count))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    if status.boundaryCrossingHistory.isEmpty {
                        VStack {
                            Spacer()
                            Text("No boundary crossings yet")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 0) {
                            // Header
                            HStack(spacing: 4) {
                                Text("Time")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 72, alignment: .trailing)
                                Text("")
                                    .frame(width: 40)
                                Text("E")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 14, alignment: .center)
                                Text("Zone")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 48, alignment: .center)
                                Text("Display")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(minWidth: 60, alignment: .leading)
                                Spacer()
                                Text("A")
                                    .font(.system(size: 9, weight: .semibold))
                                    .frame(width: 20, alignment: .center)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))

                            Divider()

                            // List
                            ScrollViewReader { proxy in
                                List(selection: $selectedCrossing) {
                                    ForEach(Array(status.boundaryCrossingHistory.enumerated()), id: \.element.id) { index, crossing in
                                        let previousTimestamp = index > 0 ? status.boundaryCrossingHistory[index - 1].timestamp : nil
                                        BoundaryCrossingRow(crossing: crossing, previousTimestamp: previousTimestamp)
                                            .tag(crossing)
                                            .id(crossing.id)
                                    }
                                }
                                .listStyle(.plain)
                                .onChange(of: status.boundaryCrossingHistory.count) { oldValue, newValue in
                                    // Auto-select the newest crossing (last item) when a new one is added
                                    if let latest = status.boundaryCrossingHistory.last {
                                        selectedCrossing = latest
                                        // Scroll to bottom
                                        withAnimation {
                                            proxy.scrollTo(latest.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 250, idealWidth: 350)

                // Right: Details
                VSplitView {
                    // Status Info (always visible)
                    VStack(spacing: 0) {
                        HStack {
                            Text("Current Status")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))

                        Divider()

                        ScrollView {
                            SelectableText(statusJson)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                    }
                    .frame(minHeight: 150, idealHeight: 300)

                    // Crossing Details (when selected)
                    VStack(spacing: 0) {
                        HStack {
                            Text(selectedCrossing == nil ? "Select a crossing to view details" : "Crossing Details")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))

                        Divider()

                        if let crossing = selectedCrossing {
                            ScrollView {
                                SelectableText(crossing.allDetails)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                        } else {
                            VStack {
                                Spacer()
                                Text("No crossing selected")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    .frame(minHeight: 150)
                }
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            // Start periodic status update
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                EdgeNavigationManager.shared.requestStatusUpdate()
            }
        }
        .onDisappear {
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }

    private var statusJson: String {
        var lines: [String] = []

        lines.append("{")
        lines.append("  \"managerState\": {")
        lines.append("    \"smartEdgeEnabled\": \(status.isSmartEdgeEnabled),")
        lines.append("    \"hasAccessibilityPermissions\": \(status.hasAccessibilityPermissions),")
        lines.append("    \"eventTapActive\": \(status.eventTapActive),")
        lines.append("    \"cache\": \"\(status.cacheInfo)\"")
        lines.append("  },")

        lines.append("  \"mouse\": {")
        lines.append("    \"logicalPosition\": {\"x\": \(String(format: "%.1f", status.currentLogicalPosition.x)), \"y\": \(String(format: "%.1f", status.currentLogicalPosition.y))},")
        lines.append("    \"physicalPosition\": \"\(status.currentPhysicalPosition)\",")
        lines.append("    \"delta\": {\"x\": \(String(format: "%.1f", status.mouseDelta.x)), \"y\": \(String(format: "%.1f", status.mouseDelta.y))},")
        lines.append("    \"lastEvent\": \"\(status.lastMouseEvent)\"")
        lines.append("  },")

        lines.append("  \"currentDisplay\": {")
        lines.append("    \"name\": \"\(status.currentDisplayName)\",")
        lines.append("    \"logicalFrame\": \"\(status.currentDisplayLogicalFrame)\",")
        lines.append("    \"physicalFrame\": \"\(status.currentDisplayPhysicalFrame)\",")
        lines.append("    \"edges\": [")
        for (index, edge) in status.currentDisplayEdges.enumerated() {
            let comma = index < status.currentDisplayEdges.count - 1 ? "," : ""
            lines.append("      {\"direction\": \"\(edge.direction)\", \"start\": \(String(format: "%.1f", edge.start)), \"end\": \(String(format: "%.1f", edge.end)), \"type\": \"\(edge.type)\"}\(comma)")
        }
        lines.append("    ]")
        lines.append("  },")

        lines.append("  \"lastDisplay\": {")
        lines.append("    \"name\": \"\(status.lastDisplayName)\",")
        lines.append("    \"logicalFrame\": \"\(status.lastDisplayLogicalFrame)\",")
        lines.append("    \"physicalFrame\": \"\(status.lastDisplayPhysicalFrame)\",")
        lines.append("    \"edges\": [")
        for (index, edge) in status.lastDisplayEdges.enumerated() {
            let comma = index < status.lastDisplayEdges.count - 1 ? "," : ""
            lines.append("      {\"direction\": \"\(edge.direction)\", \"start\": \(String(format: "%.1f", edge.start)), \"end\": \(String(format: "%.1f", edge.end)), \"type\": \"\(edge.type)\"}\(comma)")
        }
        lines.append("    ]")
        lines.append("  }")

        lines.append("}")

        return lines.joined(separator: "\n")
    }

    private func edgeIcon(_ edge: String) -> String {
        switch edge {
        case "top": return "arrow.up"
        case "bottom": return "arrow.down"
        case "left": return "arrow.left"
        case "right": return "arrow.right"
        default: return "arrow.up.arrow.down"
        }
    }

    private func shortDisplayName(_ name: String) -> String {
        let components = name.components(separatedBy: " ")
        return components.first ?? name
    }

    private func shortAction(_ action: String) -> String {
        if action.contains("Warped") { return "W" }
        if action.contains("Blocked") { return "B" }
        if action.contains("Passed") { return "P" }
        return action.prefix(1).uppercased()
    }

    private func actionColor(_ action: String) -> Color {
        switch action {
        case _ where action.contains("Warped"): return .blue
        case _ where action.contains("Blocked"): return .red
        case _ where action.contains("Passed"): return .green
        default: return .gray
        }
    }
}

struct BoundaryCrossingRow: View {
    let crossing: EdgeNavigationStatus.BoundaryCrossingInfo
    let previousTimestamp: Date?

    private var elapsedMilliseconds: Int? {
        guard let previous = previousTimestamp else { return nil }
        let elapsed = crossing.timestamp.timeIntervalSince(previous)
        return Int(elapsed * 1000)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Time
            Text(crossing.formattedTime)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 72, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)

            // Elapsed
            if let elapsed = elapsedMilliseconds {
                Text("+\(elapsed)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(elapsed < 100 ? .red : .orange)
                    .lineLimit(1)
                    .frame(width: 40, alignment: .trailing)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text("")
                    .frame(width: 40)
            }

            // Edge icon
            Image(systemName: edgeIcon(crossing.edge))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 14, alignment: .center)
                .fixedSize()

            // Zone transition
            Text(zoneTransition)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 48, alignment: .center)
                .fixedSize(horizontal: true, vertical: false)

            // Display transition
            Text(displayTransition)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 60, maxWidth: 120, alignment: .leading)
                .fixedSize(horizontal: false, vertical: false)

            Spacer(minLength: 0)

            // Action badge
            Text(shortAction(crossing.action))
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(actionColor(crossing.action))
                .foregroundColor(.white)
                .cornerRadius(3)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var zoneTransition: String {
        let from = crossing.fromZone?.type ?? "--"
        let to = crossing.toZone?.type ?? "--"
        return "\(from)→\(to)"
    }

    private var displayTransition: String {
        let from = shortDisplayName(crossing.fromDisplay)
        let to = shortDisplayName(crossing.toDisplay)
        return "\(from)→\(to)"
    }

    private func shortDisplayName(_ name: String) -> String {
        let components = name.components(separatedBy: " ")
        return components.first ?? name
    }

    private func shortAction(_ action: String) -> String {
        if action.contains("Warped") { return "W" }
        if action.contains("Blocked") { return "B" }
        if action.contains("Passed") { return "P" }
        return action.prefix(1).uppercased()
    }

    private func actionColor(_ action: String) -> Color {
        switch action {
        case _ where action.contains("Warped"): return .blue
        case _ where action.contains("Blocked"): return .red
        case _ where action.contains("Passed"): return .green
        default: return .gray
        }
    }

    private func edgeIcon(_ edge: String) -> String {
        switch edge {
        case "top": return "arrow.up"
        case "bottom": return "arrow.down"
        case "left": return "arrow.left"
        case "right": return "arrow.right"
        default: return "arrow.up.arrow.down"
        }
    }
}

struct StatusIndicator: View {
    let enabled: Bool
    let hasPermissions: Bool
    let tapActive: Bool

    var color: Color {
        if !enabled {
            return .gray
        } else if !hasPermissions {
            return .red
        } else if !tapActive {
            return .orange
        } else {
            return .green
        }
    }

    var statusText: String {
        if !enabled {
            return "Disabled"
        } else if !hasPermissions {
            return "No Permissions"
        } else if !tapActive {
            return "Inactive"
        } else {
            return "Active"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SelectableText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textSelection(.enabled)
    }
}

#Preview {
    EventViewerView()
        .frame(width: 900, height: 700)
}
