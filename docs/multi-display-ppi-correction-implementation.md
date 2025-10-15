# Multi-Display PPI Correction - Implementation Details

## Overview

Implementation of PPI (Pixels Per Inch) correction for accurate laser line angles across displays with different pixel densities.

## Implementation Date

2025-10-07

## Core Components

### 1. ScreenInfo (`Models/ScreenInfo.swift`)

Manages display information including PPI calculations:

```swift
struct ScreenInfo {
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    let ppi: CGFloat
    let physicalSize: CGSize  // in millimeters

    func correctionFactor(cursorScreen: ScreenInfo) -> CGFloat {
        return cursorScreen.ppi / self.ppi
    }
}
```

**Features:**
- Automatically calculates PPI from physical size and resolution
- Provides correction factor calculation method
- Fallback to standard PPI if physical size unavailable
- Helper properties for display name and built-in detection

### 2. ScreenManager Updates (`Managers/ScreenManager.swift`)

Enhanced to maintain display information:

```swift
class ScreenManager: ObservableObject {
    private(set) var screenInfos: [ScreenInfo] = []

    func setupOverlays() {
        screenInfos = NSScreen.screens.compactMap { ScreenInfo(screen: $0) }

        for screenInfo in screenInfos {
            let viewModel = LaserViewModel(
                screenInfo: screenInfo,
                allScreens: screenInfos
            )
            // ... overlay setup
        }
    }
}
```

**Changes:**
- Builds and caches `ScreenInfo` array for all displays
- Passes display information to each `LaserViewModel`

### 3. LaserViewModel Updates (`Models/LaserViewModel.swift`)

Added PPI correction logic:

```swift
class LaserViewModel: ObservableObject {
    private let screenInfo: ScreenInfo
    private let allScreens: [ScreenInfo]

    func correctionFactor(for cursorLocation: CGPoint) -> CGFloat {
        guard let cursorScreen = getScreen(containing: cursorLocation) else {
            return 1.0
        }

        // No correction needed for same screen
        if cursorScreen.displayID == screenInfo.displayID {
            return 1.0
        }

        // Apply PPI-based correction for cross-display drawing
        return screenInfo.correctionFactor(cursorScreen: cursorScreen)
    }
}
```

**Logic:**
- Detects which screen contains the cursor
- Returns 1.0 (no correction) if cursor is on same screen
- Returns PPI ratio for cross-display correction

### 4. LaserCanvasView Updates (`Views/LaserCanvasView.swift`)

Applied correction to laser drawing:

```swift
private func drawAllLasers(
    context: GraphicsContext,
    target: CGPoint,
    targetSIMD: SIMD2<Float>,
    correctionFactor: Float,
    gradient: Gradient
) {
    for corner in corners {
        let delta = targetSIMD - corner

        // Apply PPI correction
        let correctedTarget = corner + delta * correctionFactor
        let correctedDelta = correctedTarget - corner
        let correctedDistance = length(correctedDelta)

        // Draw with corrected values
        let path = createOptimizedLaserPath(
            from: corner,
            to: correctedTarget,
            delta: correctedDelta,
            distance: correctedDistance
        )
        // ...
    }
}
```

**Correction Applied To:**
1. Laser line endpoints
2. Laser line gradients
3. Distance indicators (percentage calculations)

## How It Works

### Example: Cursor on Built-in Display, Laser on LG Display

**Display Specs:**
- Built-in: 3456×2234, 344mm, PPI = 255
- LG: 3440×1440, 1053mm, PPI = 83

**Correction Calculation:**
```
correctionFactor = cursorPPI / laserPPI
                 = 255 / 83
                 = 3.07
```

**Result:**
- Laser line on LG display extends **3.07× farther** from corner
- Compensates for LG's larger physical pixels
- Physical angle now matches cursor angle on built-in display

### Example: Cursor on LG Display, Laser on Built-in Display

**Correction Calculation:**
```
correctionFactor = cursorPPI / laserPPI
                 = 83 / 255
                 = 0.33
```

**Result:**
- Laser line on built-in display extends **0.33× shorter** from corner
- Compensates for built-in's smaller physical pixels
- Physical angle matches cursor angle on LG display

## Algorithm Details

### Distance Correction Formula

For a laser line from corner `C` to cursor position `P`:

```
Original vector: D = P - C
Corrected vector: D' = D × correctionFactor
Corrected target: P' = C + D'
```

This maintains:
- ✅ Direction: Same angle from corner
- ✅ Physical accuracy: Scaled by PPI ratio
- ✅ Visual consistency: Lines point correctly across displays

### Coordinate System

Uses logical coordinate system (macOS native):
- Respects System Preferences display arrangement
- No physical arrangement inference needed
- Works with any display configuration

## Performance Considerations

1. **PPI Calculation:** Done once during overlay setup
2. **Correction Factor:** Calculated per frame, but lightweight
3. **SIMD Operations:** Vector math uses SIMD for efficiency
4. **No Additional Overhead:** Correction is a simple multiplication

## Testing Checklist

- [ ] Cursor on Built-in, laser on LG: Lines point correctly
- [ ] Cursor on LG, laser on Built-in: Lines point correctly
- [ ] Cursor on same screen: No correction (factor = 1.0)
- [ ] 3+ displays: Each display corrects independently
- [ ] Distance indicators show correct percentages
- [ ] No performance degradation

## Known Limitations

1. **Arrangement Mismatch:**
   - If logical arrangement differs significantly from physical layout
   - User should adjust System Preferences to match physical setup

2. **Display Mirroring:**
   - Not tested with mirrored displays
   - Correction may not be necessary for mirrored setups

3. **Rotation:**
   - Not tested with rotated displays
   - May need additional angle correction

## Future Enhancements

1. **User Calibration:**
   - Optional manual adjustment factor (0.5× - 2.0×)
   - Preference UI for fine-tuning

2. **Rotation Support:**
   - Detect display rotation
   - Apply angle correction for rotated displays

3. **Mirroring Detection:**
   - Detect mirrored displays
   - Disable correction when appropriate

## References

- Design Decision: `docs/multi-display-ppi-correction.md`
- Display Info Script: `scripts/display-info.swift`
- Issue Discussion: 2025-10-07 multi-display correction analysis
