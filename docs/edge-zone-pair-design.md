# Edge Zone Pair Design Specification

**Date**: 2025-10-21
**Status**: Design document for unified edge navigation implementation

## Overview

This document describes a unified approach to edge navigation in multi-monitor setups using **Edge Zone Pairs**. This replaces the previous Guard Edge / Smart Edge dichotomy with a single, flexible model.

## Core Concept

### Unified Model

Instead of categorizing edges as "Guard" or "Smart", we define **ranges on edges** and **pair them** with ranges on other edges:

- **Paired Range**: Mouse crossing triggers warp to paired range on target monitor
- **Unpaired Range**: Mouse crossing is blocked (cursor cannot leave this range)

This model naturally handles:
- Physical alignment mismatches (previous "Smart Edge")
- Dead-end edges (previous "Guard Edge")
- Complex multi-monitor arrangements (T-shape, U-shape, etc.)
- Future features like wrap-around connections

---

## 1. Data Model

### Persistent Storage (JSON)

```swift
struct EdgeZone: Codable, Identifiable {
    let id: UUID
    let displayId: String        // Which monitor
    let edge: EdgeDirection      // top/bottom/left/right
    let rangeStart: CGFloat      // 0.0 - 1.0 (normalized position on edge)
    let rangeEnd: CGFloat        // 0.0 - 1.0 (normalized position on edge)
}

struct EdgeZonePair: Codable, Identifiable {
    let id: UUID
    let sourceZoneId: UUID
    let targetZoneId: UUID
}

struct DisplayConfiguration: Codable {
    var displays: [PhysicalDisplayLayout]  // Existing
    var edgeZones: [EdgeZone]              // New
    var edgeZonePairs: [EdgeZonePair]      // New
}
```

**Normalized Coordinates**: Range values are 0.0-1.0 relative to edge length, making them resolution-independent.

### Runtime Cache (Performance Optimized)

```swift
class EdgeNavigationCache {
    // Screen ID → Direction → Zone List
    private var zones: [String: [EdgeDirection: [ZoneRuntime]]]

    struct ZoneRuntime {
        let id: UUID
        let range: Range<CGFloat>      // Logical coordinates (pixels)
        let targetZone: ZoneRuntime?   // Reference to paired zone
        let targetScreen: NSScreen     // Target screen reference
    }

    // Fast lookup for event processing
    func zonesForEdge(screenId: String, direction: EdgeDirection) -> [ZoneRuntime]?
}
```

**Initialization**: Convert normalized [0-1] coordinates to logical pixel coordinates at startup.

---

## 2. Default Pair Auto-Generation

### Algorithm

Detect overlapping ranges between logically adjacent edges.

**Steps**:
1. For each display and each edge direction
2. Find displays adjacent in logical layout
3. Calculate overlapping ranges (in normalized coordinates)
4. Create EdgeZone for each overlapping range
5. Create EdgeZonePair connecting them

### Example: T-Shape Layout

```
Logical Layout:
  ┌─────┐
  │ D1  │ 1470px width
  └─────┘
┌─────┬─────┐
│ D2  │ D3  │ Each 1720px width
└─────┴─────┘
```

**Generated Pairs**:
1. D1.bottom[0.0-0.5] ↔ D2.top[0.0-1.0]
2. D1.bottom[0.5-1.0] ↔ D3.top[0.0-1.0]
3. D2.right[0.0-1.0] ↔ D3.left[0.0-1.0]

**U-Shape Remote Connections**: Not auto-generated (can be manually added later).

---

## 3. UI Design

### CalibrationView Extensions

```
DisplayLayoutCanvas
├── DisplayPhysicalView (monitor rectangles)
└── EdgeZoneOverlay
    ├── Normal Mode (default)
    │   ├── PairConnectionLines (always visible)
    │   └── Faint trapezoid fill for paired ranges (optional)
    └── Edit Mode (when zone selected)
        ├── Color-coded ranges (green=paired, red=unpaired)
        ├── Draggable handles at range boundaries
        └── Overlap prevention constraints
```

### Real Monitor Overlays

During calibration, show feedback on actual monitors:

#### Monitor Identification Flash
- **Trigger**: Click logical/physical layout rectangle, or start dragging
- **Display**: Large number at screen center + subtle white glow at edges
- **Duration**: 2 seconds fade in/out
- **Style**: Subtle (50% opacity, white color)

#### Edge Zone Overlay
- **Trigger**: When editing edge zones
- **Display**: Thin lines along actual screen edges
  - Green: Paired ranges (can cross)
  - Red: Unpaired ranges (blocked)
- **Width**: 3-5 pixels
- **Style**: Minimal, non-intrusive

### Real-Time Preview

**Behavior**:
- **On drop**: Update laser display immediately (without saving)
- **On save**: Persist configuration permanently
- **On reset/close**: Restore original configuration and update laser

**Implementation**:
```swift
// New notification for temporary preview
.calibrationDidChange  // Temporary update (no save)
.calibrationDidSave    // Permanent update (saved)
```

---

## 4. Boundary Crossing Logic (Optimized)

### Event Processing Flow

```
1. Calculate boundary intersection point
   ↓
2. Determine edge direction (top/bottom/left/right)
   ↓ Fast path check
3. Are there any zones for this direction?
   NO → return nil (block crossing)
   ↓
4. Which zone contains the intersection point?
   NONE → return nil (block crossing)
   ↓
5. Calculate relative position within zone (t ∈ [0, 1))
   ↓
6. Map to target zone using same relative position
   ↓
7. Construct warp target point and return
```

### Performance Optimizations

- **Direction-based pruning**: Early exit if no zones in crossing direction
- **Deferred target lookup**: Only check pair info after confirming zone hit
- **Runtime cache**: Pre-converted pixel coordinates for fast comparison
- **No iteration**: Direct lookup by screen ID and direction

### Code Sketch

```swift
func handleBoundaryCrossing(
    from: CGPoint,
    to: CGPoint,
    sourceScreen: NSScreen,
    targetScreen: NSScreen
) -> CGPoint? {
    let intersection = calculateBoundaryIntersection(from, to, sourceScreen.frame)
    let direction = determineEdgeDirection(intersection, sourceScreen.frame)

    // Fast path: Check if any zones exist for this direction
    guard let zones = cache.zonesForEdge(
        screenId: sourceScreen.localizedName,
        direction: direction
    ), !zones.isEmpty else {
        return nil  // No zones → block crossing
    }

    // Extract edge position (logical pixels)
    let edgePos = extractEdgePosition(intersection, direction, sourceScreen.frame)

    // Find containing zone
    guard let zone = zones.first(where: { $0.range.contains(edgePos) }),
          let target = zone.targetZone else {
        return nil  // Outside zones or unpaired → block crossing
    }

    // Map relative position to target zone
    let t = (edgePos - zone.range.lowerBound) / (zone.range.upperBound - zone.range.lowerBound)
    let targetEdgePos = target.range.lowerBound + t * (target.range.upperBound - target.range.lowerBound)

    return constructTargetPoint(targetEdgePos, target, target.targetScreen)
}
```

---

## 5. Implementation Order

### Phase 1: Existing UI Improvements
1. Real-time preview (drop → instant update, close → restore)
2. Monitor identification flash
3. Edge zone overlay on real monitors (preparation)

### Phase 2: Data Model
1. Define EdgeZone, EdgeZonePair structs
2. Extend DisplayConfiguration
3. Implement EdgeNavigationCache

### Phase 3: Auto-Generation
1. Logical adjacency detection
2. Overlap range calculation
3. Default pair generation

### Phase 4: Edge Zone UI
1. EdgeZoneOverlay component
2. Draggable handles with overlap constraints
3. PairConnectionLines visualization
4. Edit mode toggle

### Phase 5: Persistence + Crossing Logic
1. JSON serialization/deserialization
2. Runtime cache initialization
3. PhysicalEdgeNavigationManager rewrite
4. Integration with AppDelegate

---

## Key Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Range Units** | Normalized [0-1] in storage | Resolution-independent, easier to edit |
| **Runtime Format** | Logical pixels | Direct comparison with event coordinates |
| **Overlap Prevention** | UI-level constraint | Prevent invalid configurations at input time |
| **UI Complexity** | Minimal (no separate editor panel) | Focus on intuitive drag-and-drop |
| **Performance** | Direction-based pruning + cache | Minimize overhead in hot event loop |
| **Preview Mode** | Drop → instant, close → restore | Better UX for fine-tuning |

---

## Future Enhancements

- **Wrap-around connections**: Connect opposite edges of same monitor
- **Multi-hop pairs**: Chain multiple zones for complex routing
- **Ratio adjustment**: Allow different-sized ranges to map with custom scaling
- **Templates**: Save/load edge configurations for common setups

---

## Migration from Previous Design

The previous `edge-navigation-design.md` defined Guard Edge and Smart Edge as separate features. This new design unifies them:

- **Guard Edge** → Unpaired EdgeZones (no EdgeZonePair)
- **Smart Edge** → Paired EdgeZones with physical alignment
- **Block Edge Release** → Manually created EdgeZonePairs between non-adjacent edges

All previous requirements are met, with additional flexibility for complex scenarios.
