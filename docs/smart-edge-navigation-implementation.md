# Smart Edge Navigation - Implementation Details

## Architecture

### Module Independence

Smart Edge Navigation is designed as a standalone, loosely-coupled module within LaserGuide:

```
LaserGuide Application
│
├─ [Existing] MouseTrackingManager
│  └─ Tracks mouse for laser display (NSEvent)
│
├─ [New] EdgeNavigationManager
│  ├─ Independent CGEventTap
│  ├─ Edge detection logic
│  ├─ Cursor warping
│  └─ Reads from CalibrationDataManager
│
└─ [Shared] CalibrationDataManager
   └─ Physical layout data storage
```

**Design Principles:**
- **No cross-dependencies**: EdgeNavigationManager doesn't depend on MouseTrackingManager
- **Shared data source**: Both read from CalibrationDataManager
- **Independent lifecycle**: Can be started/stopped without affecting laser display
- **Clean separation**: Easy to disable or remove without impacting core functionality

## Core Components

### EdgeNavigationManager Class

**Location**: `Managers/EdgeNavigationManager.swift`

```swift
class EdgeNavigationManager {
    // MARK: - Properties

    /// CGEventTap for low-level mouse monitoring
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Enable/disable flag
    private var isEnabled: Bool = true

    /// Recent mouse movement history for intent detection
    private var recentMovements: [(location: CGPoint, delta: CGPoint, timestamp: Date)] = []
    private let movementHistoryLimit = 5

    /// Cached display information
    private var displayEdges: [DisplayEdgeInfo] = []

    /// Data manager for calibration
    private let calibrationManager = CalibrationDataManager.shared

    // MARK: - Configuration

    /// Edge proximity threshold (pixels)
    private let edgeThreshold: CGFloat = 5.0

    /// Intent detection duration (milliseconds)
    private let intentThreshold: TimeInterval = 0.05  // 50ms

    /// Minimum delta magnitude to consider movement
    private let minimumDelta: CGFloat = 1.0

    // MARK: - Public Methods

    func start()
    func stop()
    func setEnabled(_ enabled: Bool)

    // MARK: - Private Methods

    private func setupEventTap()
    private func handleMouseEvent(_ event: CGEvent) -> Unmanaged<CGEvent>?
    private func updateDisplayEdges()
    private func detectEdgeAndWarp(location: CGPoint, delta: CGPoint)
    private func findTargetDisplay(from edge: DisplayEdge, direction: Direction) -> WarpTarget?
    private func warpCursor(to target: WarpTarget)
}
```

### Data Structures

```swift
/// Represents a display edge
struct DisplayEdge {
    let displayID: CGDirectDisplayID
    let side: EdgeSide
    let rect: CGRect  // Display frame
    let edgeLine: EdgeLine  // The edge line coordinates
}

enum EdgeSide {
    case top, bottom, left, right
}

struct EdgeLine {
    let start: CGPoint
    let end: CGPoint

    func contains(point: CGPoint, threshold: CGFloat) -> Bool
    func relativePosition(of point: CGPoint) -> CGFloat  // 0.0 to 1.0
}

/// Movement direction
enum Direction {
    case up, down, left, right

    init?(delta: CGPoint, threshold: CGFloat) {
        // Determine dominant direction from delta
    }
}

/// Information about where to warp
struct WarpTarget {
    let displayID: CGDirectDisplayID
    let targetPoint: CGPoint
    let edge: EdgeSide
}

/// Display edge information with dead zone detection
struct DisplayEdgeInfo {
    let edge: DisplayEdge
    let hasAdjacentDisplay: Bool  // True if directly adjacent
    let physicalPosition: CGPoint?  // From calibration data
}
```

## Algorithm Details

### 1. Edge Detection

**When**: On every mouse move event

```swift
func isAtEdge(location: CGPoint, displays: [CGRect]) -> DisplayEdge? {
    for (index, display) in displays.enumerated() {
        if !display.contains(location) { continue }

        let threshold = edgeThreshold

        // Check each edge
        if location.y >= display.maxY - threshold {
            return DisplayEdge(displayID: index, side: .top, rect: display, ...)
        }
        if location.y <= display.minY + threshold {
            return DisplayEdge(displayID: index, side: .bottom, rect: display, ...)
        }
        if location.x <= display.minX + threshold {
            return DisplayEdge(displayID: index, side: .left, rect: display, ...)
        }
        if location.x >= display.maxX - threshold {
            return DisplayEdge(displayID: index, side: .right, rect: display, ...)
        }
    }
    return nil
}
```

### 2. Movement Intent Detection

**Criteria**: Sustained movement in blocked direction

```swift
func detectIntent(edge: DisplayEdge, delta: CGPoint, history: [Movement]) -> Bool {
    // Get direction from delta
    guard let direction = Direction(delta: delta, threshold: minimumDelta) else {
        return false
    }

    // Check if direction is outward from edge
    guard edge.side.isOutward(direction) else {
        return false
    }

    // Check recent history for sustained movement
    let recentTime = Date().timeIntervalSince1970 - intentThreshold
    let recentMovements = history.filter { $0.timestamp > recentTime }

    // All recent movements should be in same direction
    return recentMovements.allSatisfy { movement in
        let movementDir = Direction(delta: movement.delta, threshold: minimumDelta)
        return movementDir == direction
    }
}

extension EdgeSide {
    func isOutward(_ direction: Direction) -> Bool {
        switch (self, direction) {
        case (.top, .up), (.bottom, .down), (.left, .left), (.right, .right):
            return true
        default:
            return false
        }
    }
}
```

### 3. Target Display Search

**Strategy**: Multi-stage search with fallbacks

```swift
func findTargetDisplay(from edge: DisplayEdge, direction: Direction) -> WarpTarget? {
    // Stage 1: Direct adjacency check (logical coordinates)
    if let adjacent = findLogicallyAdjacentDisplay(from: edge, direction: direction) {
        return adjacent
    }

    // Stage 2: Physical proximity (if calibration exists)
    if calibrationManager.hasCalibration() {
        if let physical = findPhysicallyNearestDisplay(from: edge, direction: direction) {
            return physical
        }
    }

    // Stage 3: Any display in that general direction (fallback)
    return findDisplayInDirection(from: edge, direction: direction)
}
```

**Stage 1: Logical Adjacency**

```swift
func findLogicallyAdjacentDisplay(from edge: DisplayEdge, direction: Direction) -> WarpTarget? {
    let allDisplays = NSScreen.screens.map { $0.frame }
    let sourceRect = edge.rect

    for (index, targetRect) in allDisplays.enumerated() {
        if targetRect == sourceRect { continue }

        switch direction {
        case .up:
            // Check if target is directly above source
            if abs(targetRect.minY - sourceRect.maxY) < 1.0 {
                // Check for horizontal overlap
                if targetRect.maxX > sourceRect.minX && targetRect.minX < sourceRect.maxX {
                    return createWarpTarget(to: targetRect, from: edge, direction: direction)
                }
            }
        case .down:
            if abs(sourceRect.minY - targetRect.maxY) < 1.0 {
                if targetRect.maxX > sourceRect.minX && targetRect.minX < sourceRect.maxX {
                    return createWarpTarget(to: targetRect, from: edge, direction: direction)
                }
            }
        // ... similar for left/right
        }
    }
    return nil
}
```

**Stage 2: Physical Proximity**

```swift
func findPhysicallyNearestDisplay(from edge: DisplayEdge, direction: Direction) -> WarpTarget? {
    guard let config = calibrationManager.loadCalibration() else { return nil }

    // Get physical position of edge
    guard let sourcePhysical = getPhysicalEdgePosition(edge: edge, config: config) else {
        return nil
    }

    var nearestDisplay: (display: PhysicalDisplayLayout, distance: CGFloat)?

    for display in config.displays {
        // Skip source display
        if display.identifier.matches(edge.displayID) { continue }

        // Calculate distance in physical space
        let distance = calculatePhysicalDistance(
            from: sourcePhysical,
            to: display,
            direction: direction
        )

        // Update nearest if closer
        if distance > 0, let nearest = nearestDisplay {
            if distance < nearest.distance {
                nearestDisplay = (display, distance)
            }
        } else if distance > 0 {
            nearestDisplay = (display, distance)
        }
    }

    if let nearest = nearestDisplay {
        return createWarpTarget(
            toPhysical: nearest.display,
            from: edge,
            direction: direction,
            config: config
        )
    }

    return nil
}
```

### 4. Warp Point Calculation

**Goal**: Map edge position proportionally

```swift
func createWarpTarget(to targetRect: CGRect, from edge: DisplayEdge, direction: Direction) -> WarpTarget {
    // Calculate relative position along source edge (0.0 to 1.0)
    let relativePosition: CGFloat

    switch edge.side {
    case .top, .bottom:
        // Horizontal edge
        relativePosition = (edge.cursorLocation.x - edge.rect.minX) / edge.rect.width
    case .left, .right:
        // Vertical edge
        relativePosition = (edge.cursorLocation.y - edge.rect.minY) / edge.rect.height
    }

    // Map to corresponding position on target edge
    let targetPoint: CGPoint

    switch direction {
    case .up:
        targetPoint = CGPoint(
            x: targetRect.minX + relativePosition * targetRect.width,
            y: targetRect.minY + 1  // Just inside the edge
        )
    case .down:
        targetPoint = CGPoint(
            x: targetRect.minX + relativePosition * targetRect.width,
            y: targetRect.maxY - 1
        )
    case .left:
        targetPoint = CGPoint(
            x: targetRect.maxX - 1,
            y: targetRect.minY + relativePosition * targetRect.height
        )
    case .right:
        targetPoint = CGPoint(
            x: targetRect.minX + 1,
            y: targetRect.minY + relativePosition * targetRect.height
        )
    }

    return WarpTarget(
        displayID: targetRect.displayID,
        targetPoint: targetPoint,
        edge: direction.oppositeEdge
    )
}
```

### 5. Cursor Warping

```swift
func warpCursor(to target: WarpTarget) {
    NSLog("🔀 Warping cursor to \(target.targetPoint) on display \(target.displayID)")

    // Perform the warp
    CGWarpMouseCursorPosition(target.targetPoint)

    // Re-associate cursor with mouse for smooth movement
    CGAssociateMouseAndMouseCursorPosition(true)

    // Clear movement history to avoid re-triggering
    recentMovements.removeAll()
}
```

## CGEventTap Setup

### Permission Handling

```swift
func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [
        kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
    ]
    return AXIsProcessTrustedWithOptions(options)
}

func start() {
    guard checkAccessibilityPermission() else {
        NSLog("⚠️ Accessibility permission required for Smart Edge Navigation")
        return
    }

    setupEventTap()
}
```

### Event Tap Creation

```swift
func setupEventTap() {
    let eventMask = (1 << CGEventType.mouseMoved.rawValue)

    let callback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }

        let manager = Unmanaged<EdgeNavigationManager>.fromOpaque(refcon).takeUnretainedValue()
        return manager.handleMouseEvent(event)
    }

    eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
    )

    guard let eventTap = eventTap else {
        NSLog("❌ Failed to create event tap")
        return
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    NSLog("✅ Smart Edge Navigation event tap created")
}
```

### Event Handling

```swift
private func handleMouseEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    guard isEnabled else {
        return Unmanaged.passRetained(event)
    }

    let location = event.location
    let deltaX = event.getIntegerValueField(.mouseEventDeltaX)
    let deltaY = event.getIntegerValueField(.mouseEventDeltaY)
    let delta = CGPoint(x: CGFloat(deltaX), y: CGFloat(deltaY))

    // Add to history
    let movement = (location: location, delta: delta, timestamp: Date())
    recentMovements.append(movement)
    if recentMovements.count > movementHistoryLimit {
        recentMovements.removeFirst()
    }

    // Check for edge and warp conditions
    detectEdgeAndWarp(location: location, delta: delta)

    return Unmanaged.passRetained(event)
}
```

## Integration with AppDelegate

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var edgeNavigationManager = EdgeNavigationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ... existing code ...

        // Start edge navigation
        let isEnabled = UserDefaults.standard.bool(forKey: "EdgeNavigationEnabled")
        if isEnabled || !UserDefaults.standard.object(forKey: "EdgeNavigationEnabled") {
            // Default to enabled
            edgeNavigationManager.start()
        }
    }

    private func setupStatusBar() {
        // ... existing menu items ...

        let edgeNavItem = NSMenuItem(
            title: "Smart Edge Navigation",
            action: #selector(toggleEdgeNavigation),
            keyEquivalent: ""
        )
        edgeNavItem.target = self
        edgeNavItem.state = edgeNavigationManager.isEnabled ? .on : .off
        menu.addItem(edgeNavItem)
    }

    @objc private func toggleEdgeNavigation(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off

        if newState {
            edgeNavigationManager.start()
        } else {
            edgeNavigationManager.stop()
        }

        UserDefaults.standard.set(newState, forKey: "EdgeNavigationEnabled")
    }
}
```

## Performance Optimizations

### Edge Caching

```swift
private var displayEdgeCache: [DisplayEdgeInfo] = []
private var cacheInvalidationTime: Date?

func updateDisplayEdges() {
    // Only update if cache is stale or displays changed
    if let invalidation = cacheInvalidationTime,
       Date().timeIntervalSince(invalidation) < 5.0 {
        return
    }

    // Rebuild edge cache
    displayEdgeCache = buildEdgeCache()
    cacheInvalidationTime = Date()
}

func buildEdgeCache() -> [DisplayEdgeInfo] {
    // Calculate all edges and their adjacency status
    // This is done once, not on every mouse move
}
```

### Lazy Evaluation

```swift
func detectEdgeAndWarp(location: CGPoint, delta: CGPoint) {
    // Quick check: is cursor even near an edge?
    guard isNearAnyEdge(location) else {
        return  // Early exit for 95% of mouse movements
    }

    // More expensive checks only if near edge
    guard let edge = findExactEdge(location) else {
        return
    }

    // ... continue with intent detection and warping
}
```

## Testing Strategy

### Unit Tests

- Edge detection accuracy
- Direction determination from deltas
- Relative position calculation
- Warp target selection

### Integration Tests

- CGEventTap setup and teardown
- Permission handling
- Display configuration changes
- Calibration data integration

### Manual Test Cases

See [smart-edge-navigation.md](smart-edge-navigation.md) - Test Cases section

## Debugging

### Logging

```swift
// Enable debug logging
private let debugMode = false

func log(_ message: String) {
    if debugMode {
        NSLog("🔀 [EdgeNav] \(message)")
    }
}

// Usage
log("Edge detected: \(edge.side) at \(location)")
log("Intent confirmed: \(direction) for \(intentDuration)ms")
log("Warping to: \(target)")
```

### Visual Debugging

Future enhancement: Optional visual overlay showing:
- Detected edges (red lines)
- Current edge detection zone (highlighted)
- Warp trajectory (animated arrow)
- Target display (highlighted)

## Future Enhancements

### Configurable Parameters

Expose in preferences:
```swift
struct EdgeNavigationConfig {
    var edgeThreshold: CGFloat = 5.0      // pixels
    var intentThreshold: TimeInterval = 0.05  // seconds
    var minimumDelta: CGFloat = 1.0       // pixels
    var historyLimit: Int = 5             // events
}
```

### Per-Display Settings

```swift
struct DisplayEdgeSettings {
    let displayID: CGDirectDisplayID
    var enabledEdges: Set<EdgeSide>  // Enable only specific edges
    var warpBehavior: WarpBehavior
}

enum WarpBehavior {
    case automatic       // Smart search
    case specificTarget(CGDirectDisplayID)  // Always warp to this display
    case disabled        // Don't warp from this edge
}
```

### Statistics Tracking

```swift
struct EdgeNavigationStats {
    var totalWarps: Int
    var warpsByDirection: [Direction: Int]
    var warpsByDisplay: [CGDirectDisplayID: Int]
    var averageIntentDuration: TimeInterval
}
```

## See Also

- [Smart Edge Navigation](smart-edge-navigation.md) - User documentation
- [Physical Layout Calibration](physical-layout-calibration.md) - Calibration system details
