# Edge Navigation Design Specification

**Date**: 2025-10-21
**Status**: Design document for clean reimplementation

## Key Insights from Previous Attempts

### Mouse Cursor Position Control

- **Use `CGWarpMouseCursorPosition`**: Only reliable method
- **Cannot modify event coordinates**: `event.location` setter is read-only or ignored
- **System mouse position unchanged**: Even if event is modified, `NSEvent.mouseLocation` stays the same

### Boundary Detection Architecture

- **No buffering or debounce**: Adds complexity and causes bugs
- **Process all events**: Don't skip any mouse movement events
- **Store only previous location**: `lastMouseLocation: CGPoint`
- **Fast path optimization**: Quick `currentScreen != lastValidScreen` check, return immediately if no crossing
- **No cooldown timers**: Causes "sticking" feeling and event loss

### Coordinate System Handling

- **Keep floating point precision**: Never round coordinates unnecessarily
- **Edge coordinate intervals**: For displays [A][B]:
  - A: x ∈ [Ax0, Ax0+Aw) = [0, Bx0)
  - B: x ∈ [Bx0, Bx0+Bw)
  - Use half-open intervals to avoid ambiguity at boundaries
- **Physical coordinates**: Always in millimeters (mm)
- **Logical coordinates**: macOS screen coordinates (pixels)

## Edge Type Classifications

### 1. Guard Edge (物理的に存在しないエッジ)

**Definition**: Logical display boundaries where no physical display exists on the other side.

**macOS Default Behavior**: Allows crossing (warps to unrelated display based on logical layout).

**Our Behavior**: Block crossing.

**Implementation**:
- Detect physical validity of transition using calibration data
- If physically invalid:
  - Constrain only perpendicular axis to edge
  - Preserve parallel axis movement (allow sliding along edge)
  - Example: Bottom edge crossed → set Y to edge, keep X unchanged

```
Built-in Display (logical)    LG Display (logical)
┌─────────────────┐          ┌───────────────────────┐
│                 │          │                       │
│                 │          │                       │
└─────────────────┘          └───────────────────────┘
     (0,0)~(1470,482)            (0,482)~(3440,2234)

Physical Layout:
        ┌─────────────────┐
        │   Built-in      │
        │                 │
        └─────────────────┘
  ┌───────────────────────────────┐
  │         LG Display            │
  └───────────────────────────────┘

Guard Edge: LG right side has no physical neighbor
```

### 2. Smart Edge (物理配置を考慮した自然な越境)

**Definition**: Logical display boundaries where physical displays are adjacent but misaligned.

**macOS Default Behavior**: Warps based on logical alignment (often unnatural).

**Our Behavior**: Warp based on physical alignment.

**Implementation**:
- Calculate intersection point in physical coordinates
- Check if intersection is within target display's physical bounds
- If yes: Convert back to logical coordinates and warp
- If no: Return nil (let macOS handle)
- Only modify edge-parallel axis (preserve crossing direction)

```
Logical Layout:
┌─────────────────┐
│   Built-in      │ Width: 1470px
│   (0,0)         │
└─────────────────┘
┌───────────────────────────────┐
│         LG Display            │ Width: 3440px
│         (0,482)               │
└───────────────────────────────┘

Physical Layout (to scale):
        ┌─────────────────┐
        │   Built-in      │ Width: 344mm
        └─────────────────┘
  ┌───────────────────────────────┐
  │         LG Display            │ Width: 761mm
  └───────────────────────────────┘

Problem: Built-in left edge (logical x=0) is NOT aligned with LG left edge
Smart Edge: Calculate physical position and find correct logical position
```

### 3. Block Edge Release (ブロックエッジ解放) - Future Feature

**Definition**: Two scenarios:
1. Dead-end edges in logical layout that could cross to adjacent display
2. Opposite-shore edges in U-shaped or C-shaped multi-display setups

**Status**: Not yet implemented. Focus on Guard and Smart first.

## Implementation Requirements

### Boundary Crossing Detection

```swift
// Detect screen change
if let lastValid = lastValidScreen, currentScreen != lastValid {
    let intersection = calculateBoundaryIntersection(
        from: lastMouseLocation,
        to: currentLocation,
        sourceFrame: lastValid.frame
    )

    // Process Guard and Smart Edge logic
    // ...
}

// Update tracking
lastMouseLocation = currentLocation
lastValidScreen = currentScreen
```

### Guard Edge: Edge-Constrained Position

```swift
// Determine which edge was crossed
let distToLeft = abs(intersection.x - frame.minX)
let distToRight = abs(intersection.x - frame.maxX)
let distToBottom = abs(intersection.y - frame.minY)
let distToTop = abs(intersection.y - frame.maxY)

let minDist = min(distToLeft, distToRight, distToBottom, distToTop)

var guardedPosition = currentLocation  // Start with mouse position

// Constrain only perpendicular axis
if minDist == distToBottom {
    // Bottom edge crossed
    guardedPosition.y = frame.minY + safeInset  // Constrain Y only
    // X preserved from currentLocation - allows horizontal sliding
}
```

### Smart Edge: Physical Alignment

```swift
// 1. Convert intersection to physical coordinates
let sourceLocalX = intersection.x - sourceDisplay.frame.minX
let sourceLocalY = intersection.y - sourceDisplay.frame.minY

let physicalX = sourceLayout.position.x +
                (sourceLocalX / sourceScreenSize.width) * sourceLayout.size.width
let physicalY = sourceLayout.position.y +
                (sourceLocalY / sourceScreenSize.height) * sourceLayout.size.height

// 2. Check if within target display's physical bounds
let targetPhysicalBounds = CGRect(
    x: targetLayout.position.x,
    y: targetLayout.position.y,
    width: targetLayout.size.width,
    height: targetLayout.size.height
)

if targetPhysicalBounds.contains(CGPoint(x: physicalX, y: physicalY)) {
    // 3. Convert back to logical coordinates
    let relativeX = physicalX - targetLayout.position.x
    let relativeY = physicalY - targetLayout.position.y

    let logicalX = targetDisplay.frame.minX +
                   (relativeX / targetLayout.size.width) * targetScreenSize.width
    let logicalY = targetDisplay.frame.minY +
                   (relativeY / targetLayout.size.height) * targetScreenSize.height

    return CGPoint(x: logicalX, y: logicalY)
} else {
    return nil  // Let macOS handle
}
```

## Critical Implementation Details

### Coordinate Conversion: NSEvent ↔ CGEvent

```swift
func convertToCGCoordinates(_ nsLocation: NSPoint) -> CGPoint {
    // NSEvent: Bottom-left origin, Y-axis up
    // CGEvent: Top-left origin, Y-axis down

    // Calculate unified screen space (all displays)
    var maxY: CGFloat = 0
    for screen in NSScreen.screens {
        maxY = max(maxY, screen.frame.maxY)
    }

    return CGPoint(x: nsLocation.x, y: maxY - nsLocation.y)
}
```

### Laser Flicker Suppression

```swift
// When warping cursor
NotificationCenter.default.post(
    name: .cursorDidWarp,
    object: warpDestination
)

// In LaserViewModel
NotificationCenter.default.publisher(for: .cursorDidWarp)
    .sink { [weak self] notification in
        // Suppress updates for 30ms to prevent flicker
        self?.suppressLocationUpdateUntil = Date().addingTimeInterval(0.03)

        // Update immediately to warp destination
        if let destination = notification.object as? CGPoint {
            self?.currentMouseLocation = destination
        }
    }
```

### Event Tap Setup

```swift
let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                (1 << CGEventType.leftMouseDragged.rawValue) |
                (1 << CGEventType.rightMouseDragged.rawValue) |
                (1 << CGEventType.otherMouseDragged.rawValue)

// Do NOT monitor .scrollWheel - causes inertia scroll issues
```

## Feature Independence

- **Guard Edge**: Can be enabled/disabled independently
- **Smart Edge**: Can be enabled/disabled independently
- **Combined mode**:
  - Guard Edge takes precedence
  - If physically invalid → Guard blocks
  - If physically valid → Smart Edge remaps (if enabled)

## User Settings

```swift
UserDefaults keys:
- "GuardEdgeEnabled": Bool (default: false)
- "SmartEdgeNavigationEnabled": Bool (default: false)
```

## Menu Items

```
"Guard Edge (Physical)" - Toggle guard edge blocking
"Smart Edge Navigation" - Toggle smart edge remapping
```

Both require Accessibility permissions for CGEventTap.

## Known Issues from Previous Attempts

1. **Boundary intersection calculation**: Must correctly detect which edge is crossed
2. **Screen changed condition**: After warp, `currentScreen` may not change, breaking detection
3. **Event coordinate modification**: Cannot modify event in-place, must warp actual cursor
4. **Coordinate system confusion**: Must carefully handle NSEvent vs CGEvent coordinate systems
5. **Floating point precision**: Edge cases when cursor is exactly on boundary

## Testing Strategy

### Test Cases

1. **Guard Edge**:
   - LG right edge → Down (should block)
   - LG left edge → Down (should block or allow based on physical layout)
   - Sliding along blocked edge (should be smooth, no sticking)

2. **Smart Edge**:
   - LG center-right → Built-in (should warp to physically aligned position)
   - Built-in left → LG (should warp to physically aligned position)
   - LG far-right → Built-in (should use macOS default - out of physical bounds)

3. **Combined**:
   - Both ON: Guard blocks where no physical neighbor, Smart remaps where aligned
   - Verify no conflicts or double-warping

### Performance

- No perceptible lag during normal mouse movement
- Smooth sliding along edges
- No event loss or skipping

## Implementation Order

1. **Phase 1**: Smart Edge only (simpler, well-understood)
2. **Phase 2**: Guard Edge (more complex edge detection)
3. **Phase 3**: Combined mode testing
4. **Future**: Block Edge Release feature
