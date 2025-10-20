// CalibrationWindow.swift
import SwiftUI

// MARK: - Display Color Helper

extension Color {
    /// Generate display color based on color index
    /// - colorIndex 0: Blue (built-in display)
    /// - colorIndex 1+: Distinct colors for external displays
    static func displayColor(for colorIndex: Int) -> Color {
        switch colorIndex {
        case 0: return .blue      // Built-in
        case 1: return .orange
        case 2: return .green
        case 3: return .purple
        case 4: return .red
        case 5: return .cyan
        case 6: return .yellow
        case 7: return .pink
        default:
            // Generate color from hue for 8+ displays
            let hue = Double((colorIndex - 8) % 12) / 12.0
            return Color(hue: hue, saturation: 0.7, brightness: 0.9)
        }
    }
}

struct CalibrationView: View {
    @StateObject private var viewModel = CalibrationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var logicalWidth: CGFloat = 350

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Main content: Logical vs Physical comparison
            HStack(alignment: .top, spacing: 20) {
                // Left: Logical coordinate system (resizable)
                logicalDisplayView()
                    .frame(width: logicalWidth)

                // Resizable divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = logicalWidth + value.translation.width
                                logicalWidth = min(max(newWidth, 250), 800)
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Right: Physical coordinate system (takes remaining space)
                physicalDisplayView()
            }
            .padding()

            Divider()

            // Footer: Controls
            footerView
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            viewModel.loadConfiguration()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Physical Display Layout Calibration")
                .font(.title2)
                .fontWeight(.bold)

            Text("Drag displays on the right to match your actual physical setup")
                .font(.caption)
                .foregroundColor(.secondary)

            if let key = viewModel.currentConfigKey {
                Text("Configuration: \(key)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func logicalDisplayView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logical Coordinates (macOS)")
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .border(Color.gray, width: 1)

                    // Draw logical displays
                    ForEach(viewModel.logicalDisplays) { display in
                        LogicalDisplayRect(display: display, canvasSize: geometry.size)
                    }
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewModel.updateLogicalCanvasSize(newSize)
                }
                .onAppear {
                    viewModel.updateLogicalCanvasSize(geometry.size)
                }
            }

            HStack {
                Text("This is how macOS sees your displays")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Open Display Settings...") {
                    openDisplaySettings()
                }
                .font(.caption)
                .buttonStyle(.link)
            }
            .frame(height: 20)
        }
    }

    private func openDisplaySettings() {
        // Try macOS 13+ first
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
            // Fallback for macOS 12 and earlier
            NSWorkspace.shared.open(url)
        }
    }

    private func physicalDisplayView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Physical Layout (Drag to Arrange)")
                .font(.headline)

            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .border(Color.gray, width: 1)

                    // Draw physical displays (draggable)
                    ForEach(viewModel.physicalDisplays) { display in
                        PhysicalDisplayRect(
                            display: display,
                            canvasSize: geometry.size,
                            viewModel: viewModel,
                            onDrag: { offset in
                                viewModel.updatePosition(for: display.id, offset: offset)
                            }
                        )
                    }
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewModel.updateCanvasSize(newSize)
                }
                .onAppear {
                    viewModel.updateCanvasSize(geometry.size)
                }
            }

            Spacer()
                .frame(height: 20)
        }
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Reset to Default") {
                viewModel.resetToDefault()
            }

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save Calibration") {
                viewModel.saveCalibration()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Display Rectangle Views

struct LogicalDisplayRect: View {
    let display: LogicalDisplay
    let canvasSize: CGSize

    var body: some View {
        let displayColor = Color.displayColor(for: display.colorIndex)

        ZStack {
            Rectangle()
                .fill(displayColor.opacity(0.2))
                .border(displayColor, width: 2)

            // Display info (center)
            VStack(alignment: .center, spacing: 4) {
                Text(display.name)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(verbatim: "\(Int(display.frame.width))×\(Int(display.frame.height)) px")
                    .font(.system(.caption2, design: .monospaced))
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(4)

            // Bottom-left coordinate
            coordinateLabel(
                text: "(\(Int(display.frame.minX)), \(Int(display.frame.minY)))",
                alignment: .bottomLeading,
                offset: CGPoint(x: 2, y: -2)
            )

            // Top-right coordinate
            coordinateLabel(
                text: "(\(Int(display.frame.maxX)), \(Int(display.frame.maxY)))",
                alignment: .topTrailing,
                offset: CGPoint(x: -2, y: 2)
            )
        }
        .frame(width: display.scaledFrame.width, height: display.scaledFrame.height)
        .position(
            x: display.scaledFrame.minX + display.scaledFrame.width / 2,
            y: display.scaledFrame.minY + display.scaledFrame.height / 2
        )
    }

    @ViewBuilder
    private func coordinateLabel(text: String, alignment: Alignment, offset: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .padding(2)
            .foregroundColor(.white)
            .cornerRadius(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .offset(x: offset.x, y: offset.y)
    }
}

struct PhysicalDisplayRect: View {
    let display: PhysicalDisplay
    let canvasSize: CGSize
    @ObservedObject var viewModel: CalibrationViewModel
    let onDrag: (CGSize) -> Void

    @State private var isDragging = false
    @GestureState private var dragOffset = CGSize.zero

    // Calculate current physical position (considering drag offset)
    private var currentPhysicalPosition: CGPoint {
        if dragOffset == .zero {
            return display.physicalPosition
        }
        let currentCanvasPosition = CGPoint(
            x: display.scaledPosition.x + dragOffset.width,
            y: display.scaledPosition.y + dragOffset.height
        )
        return viewModel.calculatePhysicalPosition(from: currentCanvasPosition, scaledSize: display.scaledSize)
    }

    var body: some View {
        let displayColor = Color.displayColor(for: display.colorIndex)

        ZStack {
            Rectangle()
                .fill(displayColor.opacity(0.2))
                .border(displayColor, width: 2)

            // Display info (center)
            VStack(alignment: .center, spacing: 2) {
                Text(display.name)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(verbatim: "\(Int(display.physicalSize.width))×\(Int(display.physicalSize.height)) mm")
                    .font(.system(.caption2, design: .monospaced))
            }
            .padding(6)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(4)

            // Bottom-left coordinate (updates during drag)
            coordinateLabel(
                text: "(\(Int(currentPhysicalPosition.x)), \(Int(currentPhysicalPosition.y)))",
                alignment: .bottomLeading,
                offset: CGPoint(x: 2, y: -2)
            )

            // Top-right coordinate (updates during drag)
            coordinateLabel(
                text: "(\(Int(currentPhysicalPosition.x + display.physicalSize.width)), \(Int(currentPhysicalPosition.y + display.physicalSize.height)))",
                alignment: .topTrailing,
                offset: CGPoint(x: -2, y: 2)
            )
        }
        .frame(width: display.scaledSize.width, height: display.scaledSize.height)
        .position(
            x: display.scaledPosition.x + dragOffset.width + display.scaledSize.width / 2,
            y: display.scaledPosition.y + dragOffset.height + display.scaledSize.height / 2
        )
        .shadow(color: isDragging ? Color.blue.opacity(0.5) : Color.clear, radius: 10)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { value in
                    isDragging = false
                    onDrag(value.translation)
                }
        )
    }

    @ViewBuilder
    private func coordinateLabel(text: String, alignment: Alignment, offset: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .padding(2)
            .foregroundColor(.white)
            .cornerRadius(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .offset(x: offset.x, y: offset.y)
    }
}

#Preview {
    CalibrationView()
}
