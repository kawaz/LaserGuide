// CalibrationViewModel.swift
import SwiftUI
import Cocoa

class CalibrationViewModel: ObservableObject {
    @Published var logicalDisplays: [LogicalDisplay] = []
    @Published var physicalDisplays: [PhysicalDisplay] = []
    @Published var currentConfigKey: String?
    @Published var hasExistingCalibration: Bool = false
    @Published var scaleInfo: String = "Scale: 1:2 (1px = 2mm)"
    @Published var canvasSize = CGSize(width: 500, height: 400)  // Physical canvas size, updated by view
    @Published var flashingDisplayNumber: Int? = nil  // Currently flashing display number (only one at a time)

    private let calibrationManager = CalibrationDataManager.shared
    private var logicalCanvasSize = CGSize(width: 300, height: 300)  // Logical canvas size
    private var currentScale: CGFloat = 0.5  // Current scale factor (1px = 2mm at 0.5)
    private var savedConfiguration: DisplayConfiguration?  // For restoring on cancel/close
    private var flashTimer: DispatchWorkItem? = nil  // Timer for hiding flash

    init() {
        // Monitor display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensDidChange() {
        NSLog("🔄 Screen parameters changed, reloading configuration...")
        loadConfiguration()
    }

    func loadConfiguration() {
        let (logical, physical) = calibrationManager.getCurrentDisplayConfiguration()
        currentConfigKey = calibrationManager.getCurrentConfigurationKey()
        hasExistingCalibration = calibrationManager.hasCalibration()

        // Save current configuration for restoration
        savedConfiguration = calibrationManager.loadCalibration()

        // Load logical displays
        loadLogicalDisplays(logical)

        // Load physical displays (from calibration or default)
        if let savedConfig = savedConfiguration {
            loadPhysicalDisplaysFromCalibration(savedConfig, screenInfos: physical)
        } else {
            loadDefaultPhysicalDisplays(physical)
        }
    }

    func updateLogicalCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0 && newSize.height > 0 else { return }
        let oldSize = logicalCanvasSize
        logicalCanvasSize = newSize

        // Force recalculation if canvas size changed significantly
        if abs(oldSize.width - newSize.width) > 10 || abs(oldSize.height - newSize.height) > 10 {
            // Reload logical displays with new canvas size
            let (logical, _) = calibrationManager.getCurrentDisplayConfiguration()
            loadLogicalDisplays(logical)
        }
    }

    func updateCanvasSize(_ newSize: CGSize) {
        guard newSize.width > 0 && newSize.height > 0 else { return }
        let oldSize = canvasSize
        canvasSize = newSize

        // Force recalculation if canvas size changed significantly
        if abs(oldSize.width - newSize.width) > 10 || abs(oldSize.height - newSize.height) > 10 {
            // Recalculate optimal scale and update all positions
            refitToCanvas(force: true)
        }
    }

    private func loadLogicalDisplays(_ displays: [LogicalDisplayInfo]) {
        guard !displays.isEmpty else { return }

        // Calculate bounds
        let allFrames = displays.map { $0.frame }
        let minX = allFrames.map { $0.minX }.min() ?? 0
        let maxX = allFrames.map { $0.maxX }.max() ?? 0
        let minY = allFrames.map { $0.minY }.min() ?? 0
        let maxY = allFrames.map { $0.maxY }.max() ?? 0

        let totalWidth = maxX - minX
        let totalHeight = maxY - minY

        // Calculate scale to fit in canvas
        let scaleX = (logicalCanvasSize.width * 0.9) / totalWidth
        let scaleY = (logicalCanvasSize.height * 0.9) / totalHeight
        let scale = min(scaleX, scaleY)

        // Assign color indices: Built-in = 0, External = 1, 2, 3...
        var externalIndex = 1

        logicalDisplays = displays.enumerated().map { index, info in
            // Simple approach: just scale and flip Y
            // Input: info.frame in logical coords (Y=0 is bottom)
            // Output: scaledFrame in canvas coords (Y=0 is top)

            let scaledWidth = info.frame.width * scale
            let scaledHeight = info.frame.height * scale

            // Position relative to minX, minY
            let relativeX = info.frame.minX - minX
            let relativeY = info.frame.minY - minY

            // Scale the position
            let scaledX = relativeX * scale
            let scaledY = relativeY * scale

            // Flip Y axis: logical bottom (Y=0) becomes canvas bottom (Y=max)
            // logical top (Y=max) becomes canvas top (Y=0)
            let totalScaledHeight = totalHeight * scale
            let flippedY = totalScaledHeight - scaledY - scaledHeight

            // Add margin to center
            let marginX = (logicalCanvasSize.width - totalWidth * scale) / 2
            let marginY = (logicalCanvasSize.height - totalHeight * scale) / 2

            let scaledFrame = CGRect(
                x: marginX + scaledX,
                y: marginY + flippedY,
                width: scaledWidth,
                height: scaledHeight
            )

            let isBuiltIn = CGDisplayIsBuiltin(info.displayID) != 0
            let colorIndex: Int
            if isBuiltIn {
                colorIndex = 0
            } else {
                colorIndex = externalIndex
                externalIndex += 1
            }

            return LogicalDisplay(
                id: UUID(),
                displayID: info.displayID,
                identifier: info.identifier,
                name: NSScreen.screens.first(where: {
                    let desc = $0.deviceDescription
                    return desc[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == info.displayID
                })?.localizedName ?? "Display \(index + 1)",
                frame: info.frame,
                scaledFrame: scaledFrame,
                isBuiltIn: isBuiltIn,
                colorIndex: colorIndex
            )
        }
    }

    private func loadDefaultPhysicalDisplays(_ screenInfos: [ScreenInfo]) {
        // BFS algorithm to calculate physical positions based on logical adjacency
        guard !screenInfos.isEmpty else { return }

        // Get logical arrangement
        let (logical, _) = calibrationManager.getCurrentDisplayConfiguration()

        // Build a map: displayID -> (logicalInfo, screenInfo)
        var displayMap: [CGDirectDisplayID: (logical: LogicalDisplayInfo, screen: ScreenInfo)] = [:]
        for logicalInfo in logical {
            if let screenInfo = screenInfos.first(where: { $0.displayID == logicalInfo.displayID }) {
                displayMap[logicalInfo.displayID] = (logicalInfo, screenInfo)
            }
        }

        // Find the origin display (contains logical point (0, 0))
        guard let originID = logical.first(where: { $0.frame.contains(CGPoint(x: 0, y: 0)) })?.displayID,
              let _ = displayMap[originID] else {
            return
        }

        // Physical positions in mm (can be negative)
        var physicalPositions: [CGDirectDisplayID: CGPoint] = [:]
        physicalPositions[originID] = CGPoint(x: 0, y: 0)

        // BFS queue
        var queue: [CGDirectDisplayID] = [originID]
        var processed: Set<CGDirectDisplayID> = [originID]

        while !queue.isEmpty {
            let currentID = queue.removeFirst()
            guard let currentData = displayMap[currentID],
                  let currentPhysicalPos = physicalPositions[currentID] else {
                continue
            }

            let currentLogical = currentData.logical.frame
            let currentPhysical = currentData.screen.physicalSize

            // Find adjacent displays
            for (candidateID, candidateData) in displayMap {
                if processed.contains(candidateID) { continue }

                let candidateLogical = candidateData.logical.frame
                let candidatePhysical = candidateData.screen.physicalSize

                var newPhysicalPos: CGPoint? = nil

                // Check if adjacent (borders touch)
                let epsilon: CGFloat = 1.0

                // Top: current.maxY == candidate.minY
                if abs(currentLogical.maxY - candidateLogical.minY) < epsilon {
                    newPhysicalPos = CGPoint(
                        x: currentPhysicalPos.x + (candidateLogical.minX - currentLogical.minX) / currentLogical.width * currentPhysical.width,
                        y: currentPhysicalPos.y + currentPhysical.height
                    )
                }
                // Bottom: current.minY == candidate.maxY
                else if abs(currentLogical.minY - candidateLogical.maxY) < epsilon {
                    newPhysicalPos = CGPoint(
                        x: currentPhysicalPos.x + (candidateLogical.minX - currentLogical.minX) / currentLogical.width * currentPhysical.width,
                        y: currentPhysicalPos.y - candidatePhysical.height
                    )
                }
                // Right: current.maxX == candidate.minX
                else if abs(currentLogical.maxX - candidateLogical.minX) < epsilon {
                    newPhysicalPos = CGPoint(
                        x: currentPhysicalPos.x + currentPhysical.width,
                        y: currentPhysicalPos.y + (candidateLogical.minY - currentLogical.minY) / currentLogical.height * currentPhysical.height
                    )
                }
                // Left: current.minX == candidate.maxX
                else if abs(currentLogical.minX - candidateLogical.maxX) < epsilon {
                    newPhysicalPos = CGPoint(
                        x: currentPhysicalPos.x - candidatePhysical.width,
                        y: currentPhysicalPos.y + (candidateLogical.minY - currentLogical.minY) / currentLogical.height * currentPhysical.height
                    )
                }

                if let pos = newPhysicalPos {
                    physicalPositions[candidateID] = pos
                    processed.insert(candidateID)
                    queue.append(candidateID)
                }
            }
        }

        // Calculate bounds of physical positions
        let allPhysicalX = physicalPositions.values.map { $0.x }
        let allPhysicalY = physicalPositions.values.map { $0.y }
        let minPhysicalX = allPhysicalX.min() ?? 0
        let maxPhysicalX = (physicalPositions.map { id, pos in
            pos.x + (displayMap[id]?.screen.physicalSize.width ?? 0)
        }).max() ?? 1000
        let minPhysicalY = allPhysicalY.min() ?? 0
        let maxPhysicalY = (physicalPositions.map { id, pos in
            pos.y + (displayMap[id]?.screen.physicalSize.height ?? 0)
        }).max() ?? 1000

        let totalPhysicalWidth = maxPhysicalX - minPhysicalX
        let totalPhysicalHeight = maxPhysicalY - minPhysicalY

        // Calculate scale to fit in canvas
        let scaleX = (canvasSize.width * 0.9) / totalPhysicalWidth
        let scaleY = (canvasSize.height * 0.9) / totalPhysicalHeight
        let fitScale = min(scaleX, scaleY, 0.5)
        currentScale = fitScale
        updateScaleInfo()

        // Create displayID -> colorIndex mapping from logical displays
        let colorIndexMap = Dictionary(uniqueKeysWithValues: logicalDisplays.map { ($0.displayID, $0.colorIndex) })

        // Build physical displays
        physicalDisplays = screenInfos.compactMap { info in
            guard let physicalPos = physicalPositions[info.displayID] else {
                return nil
            }

            // Convert physical mm to canvas coordinates
            let relativeX = physicalPos.x - minPhysicalX
            let relativeY = physicalPos.y - minPhysicalY

            let scaledX = relativeX * fitScale
            let scaledY = relativeY * fitScale
            let scaledWidth = info.physicalSize.width * fitScale
            let scaledHeight = info.physicalSize.height * fitScale

            // Flip Y axis: physical bottom (Y=0) becomes canvas bottom (Y=max)
            let totalScaledHeight = totalPhysicalHeight * fitScale
            let flippedY = totalScaledHeight - scaledY - scaledHeight

            // Add margin to center
            let marginX = (canvasSize.width - totalPhysicalWidth * fitScale) / 2
            let marginY = (canvasSize.height - totalPhysicalHeight * fitScale) / 2

            let canvasX = marginX + scaledX
            let canvasY = marginY + flippedY

            // Calculate position similar to logical displays (for .offset)
            let scaledFrame = CGRect(x: canvasX, y: canvasY, width: scaledWidth, height: scaledHeight)

            let result = PhysicalDisplay(
                id: UUID(),
                displayID: info.displayID,
                identifier: DisplayIdentifier(displayID: info.displayID),
                name: info.name,
                physicalPosition: physicalPos,
                physicalSize: info.physicalSize,
                scaledPosition: CGPoint(x: scaledFrame.minX, y: scaledFrame.minY),
                scaledSize: CGSize(width: scaledWidth, height: scaledHeight),
                isBuiltIn: info.isBuiltIn,
                resolution: CGSize(width: info.screen.frame.width * info.screen.backingScaleFactor,
                                 height: info.screen.frame.height * info.screen.backingScaleFactor),
                ppi: info.ppi,
                colorIndex: colorIndexMap[info.displayID] ?? 0
            )

            NSLog("📍 Initial: %@ - physicalPos:(%.1f,%.1f) scaledPos:(%.1f,%.1f) scaledSize:(%.1fx%.1f)",
                  info.name, physicalPos.x, physicalPos.y,
                  scaledFrame.minX, scaledFrame.minY,
                  scaledWidth, scaledHeight)

            return result
        }
    }

    private func loadPhysicalDisplaysFromCalibration(_ config: DisplayConfiguration, screenInfos: [ScreenInfo]) {
        // Calculate bounds of saved physical positions
        let allX = config.displays.map { $0.position.x }
        let allY = config.displays.map { $0.position.y }
        let minPhysicalX = allX.min() ?? 0
        let maxPhysicalX = (config.displays.map { $0.position.x + $0.size.width }).max() ?? 1000
        let minPhysicalY = allY.min() ?? 0
        let maxPhysicalY = (config.displays.map { $0.position.y + $0.size.height }).max() ?? 1000

        let totalPhysicalWidth = maxPhysicalX - minPhysicalX
        let totalPhysicalHeight = maxPhysicalY - minPhysicalY

        let scaleX = (canvasSize.width * 0.9) / totalPhysicalWidth
        let scaleY = (canvasSize.height * 0.9) / totalPhysicalHeight
        let fitScale = min(scaleX, scaleY, 0.5)
        currentScale = fitScale
        updateScaleInfo()

        // Create displayID -> colorIndex mapping from logical displays
        let colorIndexMap = Dictionary(uniqueKeysWithValues: logicalDisplays.map { ($0.displayID, $0.colorIndex) })

        physicalDisplays = config.displays.compactMap { layout in
            guard let info = screenInfos.first(where: {
                DisplayIdentifier(displayID: $0.displayID) == layout.identifier
            }) else {
                return nil
            }

            // Convert physical mm to canvas coordinates (same logic as loadDefaultPhysicalDisplays)
            let relativeX = layout.position.x - minPhysicalX
            let relativeY = layout.position.y - minPhysicalY

            let scaledX = relativeX * fitScale
            let scaledY = relativeY * fitScale
            let scaledWidth = layout.size.width * fitScale
            let scaledHeight = layout.size.height * fitScale

            // Flip Y axis: physical bottom (Y=0) becomes canvas bottom (Y=max)
            let totalScaledHeight = totalPhysicalHeight * fitScale
            let flippedY = totalScaledHeight - scaledY - scaledHeight

            // Add margin to center
            let marginX = (canvasSize.width - totalPhysicalWidth * fitScale) / 2
            let marginY = (canvasSize.height - totalPhysicalHeight * fitScale) / 2

            let canvasX = marginX + scaledX
            let canvasY = marginY + flippedY

            return PhysicalDisplay(
                id: UUID(),
                displayID: info.displayID,
                identifier: layout.identifier,
                name: info.name,
                physicalPosition: CGPoint(x: layout.position.x, y: layout.position.y),
                physicalSize: CGSize(width: layout.size.width, height: layout.size.height),
                scaledPosition: CGPoint(x: canvasX, y: canvasY),
                scaledSize: CGSize(width: scaledWidth, height: scaledHeight),
                isBuiltIn: info.isBuiltIn,
                resolution: CGSize(width: info.screen.frame.width * info.screen.backingScaleFactor,
                                 height: info.screen.frame.height * info.screen.backingScaleFactor),
                ppi: info.ppi,
                colorIndex: colorIndexMap[info.displayID] ?? 0
            )
        }
    }

    func updatePosition(for id: UUID, offset: CGSize) {
        guard let index = physicalDisplays.firstIndex(where: { $0.id == id }) else { return }

        var display = physicalDisplays[index]
        var newScaledX = display.scaledPosition.x + offset.width
        var newScaledY = display.scaledPosition.y + offset.height

        // Check collision with other displays
        let newRect = CGRect(x: newScaledX, y: newScaledY, width: display.scaledSize.width, height: display.scaledSize.height)

        for (otherIndex, other) in physicalDisplays.enumerated() {
            if otherIndex == index { continue }

            let otherRect = CGRect(x: other.scaledPosition.x, y: other.scaledPosition.y,
                                  width: other.scaledSize.width, height: other.scaledSize.height)

            if newRect.intersects(otherRect) {
                // Calculate overlap on each side
                let overlapLeft = otherRect.maxX - newRect.minX
                let overlapRight = newRect.maxX - otherRect.minX
                let overlapTop = otherRect.maxY - newRect.minY
                let overlapBottom = newRect.maxY - otherRect.minY

                // Find minimum overlap direction
                let minOverlap = min(overlapLeft, overlapRight, overlapTop, overlapBottom)

                if minOverlap == overlapLeft {
                    // Push left
                    newScaledX = otherRect.maxX
                } else if minOverlap == overlapRight {
                    // Push right
                    newScaledX = otherRect.minX - display.scaledSize.width
                } else if minOverlap == overlapTop {
                    // Push up
                    newScaledY = otherRect.maxY
                } else {
                    // Push down
                    newScaledY = otherRect.minY - display.scaledSize.height
                }

                // Recheck after adjustment (in case of multiple collisions)
                break
            }
        }

        // Update scaled position
        display.scaledPosition = CGPoint(x: newScaledX, y: newScaledY)

        // Update physical position from canvas position
        // Calculate physical bounds for proper conversion
        let allPhysicalMinX = physicalDisplays.map { $0.physicalPosition.x }.min() ?? 0
        let allPhysicalMinY = physicalDisplays.map { $0.physicalPosition.y }.min() ?? 0
        let allPhysicalMaxX = physicalDisplays.map { $0.physicalPosition.x + $0.physicalSize.width }.max() ?? 1000
        let allPhysicalMaxY = physicalDisplays.map { $0.physicalPosition.y + $0.physicalSize.height }.max() ?? 1000
        let physicalWidth = allPhysicalMaxX - allPhysicalMinX
        let physicalHeight = allPhysicalMaxY - allPhysicalMinY

        let totalScaledHeight = physicalHeight * currentScale
        let marginX = (canvasSize.width - physicalWidth * currentScale) / 2
        let marginY = (canvasSize.height - totalScaledHeight) / 2

        let relativeX = newScaledX - marginX
        let relativeY = newScaledY - marginY
        let unflippedY = totalScaledHeight - relativeY - display.scaledSize.height

        display.physicalPosition = CGPoint(
            x: allPhysicalMinX + relativeX / currentScale,
            y: allPhysicalMinY + unflippedY / currentScale
        )

        physicalDisplays[index] = display

        // Refit to canvas if any display is outside
        refitToCanvas()

        // Notify laser display for real-time preview
        notifyCalibrationChange()
    }

    private func updatePhysicalPositionsFromCanvas() {
        // This function is called after drag to update physical positions
        // We don't need to do anything here because physical positions
        // will be recalculated properly when saving
        // For now, just keep the old physical positions unchanged
    }

    private func refitToCanvas(force: Bool = false) {
        // Calculate physical bounds (in mm)
        let allPhysicalMinX = physicalDisplays.map { $0.physicalPosition.x }.min() ?? 0
        let allPhysicalMinY = physicalDisplays.map { $0.physicalPosition.y }.min() ?? 0
        let allPhysicalMaxX = physicalDisplays.map { $0.physicalPosition.x + $0.physicalSize.width }.max() ?? 1000
        let allPhysicalMaxY = physicalDisplays.map { $0.physicalPosition.y + $0.physicalSize.height }.max() ?? 1000

        let physicalWidth = allPhysicalMaxX - allPhysicalMinX
        let physicalHeight = allPhysicalMaxY - allPhysicalMinY

        // Calculate optimal scale to fit in canvas
        let scaleX = (canvasSize.width * 0.9) / physicalWidth
        let scaleY = (canvasSize.height * 0.9) / physicalHeight
        let newScale = min(scaleX, scaleY, 0.5)

        // Check if scale needs update (allow 5% tolerance, unless forced)
        if !force {
            let scaleTolerance: CGFloat = 0.05
            let scaleRatio = abs(newScale - currentScale) / currentScale

            if scaleRatio <= scaleTolerance {
                NSLog("✅ No refit needed: currentScale=%.3f newScale=%.3f ratio=%.3f", currentScale, newScale, scaleRatio)
                return
            }
        }

        NSLog("⚠️ Refit %@: currentScale=%.3f newScale=%.3f", force ? "(forced)" : "needed", currentScale, newScale)

        // Update scale and recalculate all canvas positions from physical positions
        currentScale = newScale
        updateScaleInfo()

        var updatedDisplays = physicalDisplays

        for i in 0..<updatedDisplays.count {
            let physicalPos = updatedDisplays[i].physicalPosition
            let physicalSize = updatedDisplays[i].physicalSize

            // Convert physical mm to canvas coordinates
            let relativeX = physicalPos.x - allPhysicalMinX
            let relativeY = physicalPos.y - allPhysicalMinY

            let scaledX = relativeX * newScale
            let scaledY = relativeY * newScale
            let scaledWidth = physicalSize.width * newScale
            let scaledHeight = physicalSize.height * newScale

            // Flip Y axis: physical bottom (Y=0) becomes canvas bottom (Y=max)
            let totalScaledHeight = physicalHeight * newScale
            let flippedY = totalScaledHeight - scaledY - scaledHeight

            // Add margin to center
            let marginX = (canvasSize.width - physicalWidth * newScale) / 2
            let marginY = (canvasSize.height - physicalHeight * newScale) / 2

            let canvasX = marginX + scaledX
            let canvasY = marginY + flippedY

            updatedDisplays[i].scaledPosition = CGPoint(x: canvasX, y: canvasY)
            updatedDisplays[i].scaledSize = CGSize(width: scaledWidth, height: scaledHeight)
        }

        // Trigger UI update by reassigning the array
        physicalDisplays = updatedDisplays
        NSLog("✅ Rescaling complete")
    }

    func resetToDefault() {
        let (_, physical) = calibrationManager.getCurrentDisplayConfiguration()
        loadDefaultPhysicalDisplays(physical)
    }

    func saveCalibration() {
        // Physical positions are already up-to-date from updatePhysicalPositionsFromCanvas()
        let layouts = physicalDisplays.map { display in
            PhysicalDisplayLayout(
                identifier: display.identifier,
                position: PhysicalDisplayLayout.PhysicalPoint(
                    x: display.physicalPosition.x,
                    y: display.physicalPosition.y
                ),
                size: PhysicalDisplayLayout.PhysicalSize(
                    width: display.physicalSize.width,
                    height: display.physicalSize.height
                )
            )
        }

        let configuration = DisplayConfiguration(
            displays: layouts,
            timestamp: Date()
        )

        calibrationManager.saveCalibration(configuration)
        hasExistingCalibration = true

        // Update saved configuration to new save point
        savedConfiguration = configuration

        // Clear temporary configuration
        calibrationManager.clearTemporaryCalibration()

        // Notify laser display to reload physical configuration
        NotificationCenter.default.post(name: .calibrationDidSave, object: nil)
        NSLog("📐 Notified laser display to reload physical configuration")
    }

    func restoreOriginal() {
        guard let saved = savedConfiguration else {
            NSLog("⚠️ No saved configuration to restore")
            return
        }

        // Clear temporary configuration
        calibrationManager.clearTemporaryCalibration()

        // Reload from saved configuration
        let (_, physical) = calibrationManager.getCurrentDisplayConfiguration()
        loadPhysicalDisplaysFromCalibration(saved, screenInfos: physical)

        // Notify laser display to restore original configuration
        NotificationCenter.default.post(name: .calibrationDidChange, object: nil)
        NSLog("🔄 Restored original configuration")
    }

    private func notifyCalibrationChange() {
        // Build temporary configuration from current physical displays
        let layouts = physicalDisplays.map { display in
            PhysicalDisplayLayout(
                identifier: display.identifier,
                position: PhysicalDisplayLayout.PhysicalPoint(
                    x: display.physicalPosition.x,
                    y: display.physicalPosition.y
                ),
                size: PhysicalDisplayLayout.PhysicalSize(
                    width: display.physicalSize.width,
                    height: display.physicalSize.height
                )
            )
        }

        let tempConfiguration = DisplayConfiguration(
            displays: layouts,
            timestamp: Date()
        )

        // Temporarily save to allow laser display to load it
        calibrationManager.saveCalibrationTemporary(tempConfiguration)

        // Notify laser display for real-time preview
        NotificationCenter.default.post(name: .calibrationDidChange, object: nil)
    }

    private func updateScaleInfo() {
        let ratio = 1.0 / currentScale
        scaleInfo = String(format: "Scale: 1:%.1f (1px = %.1fmm)", ratio, ratio)
    }

    // Calculate physical position from canvas position (for real-time display during drag)
    func calculatePhysicalPosition(from canvasPosition: CGPoint, scaledSize: CGSize) -> CGPoint {
        let allCanvasX = physicalDisplays.map { $0.scaledPosition.x }
        let allCanvasY = physicalDisplays.map { $0.scaledPosition.y }
        let minCanvasX = allCanvasX.min() ?? 0
        let minCanvasY = allCanvasY.min() ?? 0

        let maxCanvasX = (physicalDisplays.map { $0.scaledPosition.x + $0.scaledSize.width }).max() ?? canvasSize.width
        let maxCanvasY = (physicalDisplays.map { $0.scaledPosition.y + $0.scaledSize.height }).max() ?? canvasSize.height

        let totalCanvasWidth = maxCanvasX - minCanvasX
        let totalCanvasHeight = maxCanvasY - minCanvasY

        let marginX = (canvasSize.width - totalCanvasWidth) / 2
        let marginY = (canvasSize.height - totalCanvasHeight) / 2

        let relativeX = canvasPosition.x - marginX
        let relativeY = canvasPosition.y - marginY

        // Unflip Y axis
        let unflippedY = totalCanvasHeight - relativeY - scaledSize.height

        let physicalX = relativeX / currentScale
        let physicalY = unflippedY / currentScale

        return CGPoint(x: physicalX, y: physicalY)
    }

    // MARK: - Flash Control

    /// Start flashing a display number (2 seconds auto-hide)
    func startFlash(displayNumber: Int) {
        // Cancel previous timer
        flashTimer?.cancel()

        // Set flashing number
        flashingDisplayNumber = displayNumber

        // Update LaserViewModel for all screens
        updateLaserViewModels()

        // Auto-hide after 2 seconds
        let hideTask = DispatchWorkItem { [weak self] in
            self?.flashingDisplayNumber = nil
            self?.updateLaserViewModels()
        }
        flashTimer = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hideTask)
    }

    /// Start flashing and keep it visible (for drag)
    func startContinuousFlash(displayNumber: Int) {
        // Cancel previous timer
        flashTimer?.cancel()

        // Set flashing number
        flashingDisplayNumber = displayNumber

        // Update LaserViewModel for all screens
        updateLaserViewModels()
    }

    /// Stop continuous flash
    func stopContinuousFlash() {
        flashingDisplayNumber = nil
        updateLaserViewModels()
    }

    private func updateLaserViewModels() {
        let screenManager = ScreenManager.shared
        for (index, controller) in screenManager.hostingControllers.enumerated() {
            let viewModel = controller.rootView.viewModel
            let screenNumber = index + 1

            if flashingDisplayNumber == screenNumber {
                viewModel.displayNumber = screenNumber
                viewModel.showIdentification = true
            } else {
                viewModel.showIdentification = false
                viewModel.displayNumber = nil
            }
        }
    }
}

// MARK: - Display Models

struct LogicalDisplay: Identifiable {
    let id: UUID
    let displayID: CGDirectDisplayID
    let identifier: DisplayIdentifier
    let name: String
    let frame: CGRect  // Original logical coordinates
    let scaledFrame: CGRect  // Scaled for display in UI
    let isBuiltIn: Bool
    let colorIndex: Int  // For color differentiation
}

struct PhysicalDisplay: Identifiable {
    let id: UUID
    let displayID: CGDirectDisplayID
    let identifier: DisplayIdentifier
    let name: String
    var physicalPosition: CGPoint  // In mm
    var physicalSize: CGSize  // In mm
    var scaledPosition: CGPoint  // For SwiftUI .position (center point)
    var scaledSize: CGSize  // For SwiftUI .frame
    let isBuiltIn: Bool
    let resolution: CGSize  // Pixel resolution
    let ppi: CGFloat
    let colorIndex: Int  // For color differentiation
}
