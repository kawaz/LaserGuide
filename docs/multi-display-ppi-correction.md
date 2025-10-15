# Multi-Display PPI Correction

## Problem Statement

When using multiple displays with different PPI (Pixels Per Inch) values, laser lines pointing to the mouse cursor appear misaligned on the display where the cursor is not present.

This occurs because macOS uses a logical coordinate system where displays with different physical sizes can have similar logical resolutions, but the physical distance represented by the same logical distance differs significantly.

## Real-World Example

### Display Configuration (Actual Measurement)

**Display 1: Built-in Display (MacBook)**
- Resolution: 3456 x 2234 points
- Physical Size: 344mm x 222mm
- PPI: **255**
- Refresh Rate: 120 Hz
- Position: Origin at (0, 0)

**Display 2: LG ULTRAGEAR+**
- Resolution: 3440 x 1440 points
- Physical Size: 1053mm x 441mm
- PPI: **83**
- Refresh Rate: 240 Hz
- Position: Origin at (0, 2234) - placed above Display 1

### Display Arrangement

```
┌─────────────────────────────────┐
│   LG ULTRAGEAR+ (3440x1440)     │ ← PPI: 83
│   Physical: 1053mm x 441mm      │
└─────────────────────────────────┘
┌──────────────────────────────┐
│  Built-in (3456x2234)        │ ← PPI: 255
│  Physical: 344mm x 222mm     │
└──────────────────────────────┘
```

### The Issue

Although both displays have similar logical widths (~3450 points), their physical sizes differ by a factor of ~3:
- Built-in display: 344mm wide
- LG display: 1053mm wide (~3.06x larger)

This means:
- 1 point on built-in display = 0.135mm (344mm / 3456 points)
- 1 point on LG display = 0.306mm (1053mm / 3440 points)

When the cursor is on one display and laser lines are drawn on another, the angle appears incorrect because the same logical distance represents different physical distances.

## Correction Method

### Approach: PPI-Based Scaling

To maintain correct physical angles across displays:

1. **Determine cursor's display** and its PPI
2. **For each display showing laser lines**, calculate a correction factor
3. **Apply scaling** based on PPI ratio

### Correction Formula

```
correctionFactor = cursorDisplayPPI / laserDisplayPPI
```

### Example Calculation

**Case: Cursor on Built-in Display, Laser on LG Display**

```
correctionFactor = 255 / 83 ≈ 3.07
```

This means when drawing laser lines on the LG display:
- The calculated distance from the corner should be **multiplied by 3.07**
- This compensates for the LG display's lower PPI (larger physical pixels)

**Case: Cursor on LG Display, Laser on Built-in Display**

```
correctionFactor = 83 / 255 ≈ 0.33
```

This means when drawing laser lines on the built-in display:
- The calculated distance from the corner should be **multiplied by 0.33**
- This compensates for the built-in display's higher PPI (smaller physical pixels)

## Implementation Considerations

### Required Information per Display

For each `NSScreen`:
1. Logical resolution (`screen.frame.size`)
2. Physical size (`CGDisplayScreenSize()`)
3. PPI calculation: `pixels / (physicalSize / 25.4)`
4. Display position in coordinate system (`screen.frame.origin`)

### Correction Application

When calculating laser line endpoints:

```swift
// Current implementation (incorrect for multi-display)
let endpoint = calculateLineEndpoint(from: corner, to: cursorPosition)

// Corrected implementation
let cursorScreen = getScreen(containing: cursorPosition)
let laserScreen = getScreen(containing: corner)
let correctionFactor = cursorScreen.ppi / laserScreen.ppi

let endpoint = calculateLineEndpoint(
    from: corner,
    to: cursorPosition,
    scaleFactor: correctionFactor
)
```

### Edge Cases

1. **Cursor on display boundary**: Need to determine which display is primary for the cursor
2. **More than 2 displays**: Each display needs independent correction relative to cursor's display
3. **Display mirroring**: Correction may not be necessary if displays are mirrored
4. **Rotation**: Physical angle correction becomes more complex

## Alternative Approaches

### 1. Physical Coordinate System
Convert all calculations to physical units (mm) instead of logical points.

**Pros:**
- Mathematically pure
- Handles any display configuration

**Cons:**
- More complex implementation
- Potential floating-point precision issues

### 2. Per-Display Calibration
Allow users to manually adjust correction factors.

**Pros:**
- Can account for viewing distance and personal preference
- Simple fallback if automatic detection fails

**Cons:**
- Requires user configuration
- Not automatic

## Recommended Solution

**PPI-based automatic correction** with optional manual calibration:
1. Calculate PPI for each display automatically
2. Apply PPI ratio correction by default
3. Provide user preference to adjust correction factor (0.5x - 2.0x range)

This provides:
- ✅ Automatic correction for common cases
- ✅ User override for edge cases or preferences
- ✅ Simple implementation
- ✅ Maintainable code

## References

- macOS Coordinate System: https://developer.apple.com/documentation/appkit/nsscreen
- Display Information: `CGDisplayScreenSize()`, `CGDisplayCopyDisplayMode()`
- PPI Calculation: pixels per inch = (pixel count) / (physical size in inches)

## Coordinate System Design Decision

### Logical vs Physical Coordinate Problem

Concern about cases where physical display arrangement differs from logical arrangement:

```
Physical arrangement:
111111      (LG: 1053mm wide)
332233      (Built-in: 344mm physically split left/right)

Possible logical arrangements:
111111      111111      111111      111111
332233       332233      332233       332233
(Left)      (Center)    (Right)     (Custom)
```

### Adopted Solution

**Respect the logical coordinate system and focus on PPI correction within displays**

#### Rationale:

1. **Trust macOS coordinate system**
   - System Preferences "Arrangement" is reflected in logical coordinates
   - Respecting user-configured arrangement is most natural

2. **Avoid physical arrangement inference**
   - Impossible to perfectly infer physical arrangement from logical coordinates
   - Incorrect inference causes more problems

3. **Focus on relative distance correction**
   - The essence is scale correction of relative distances, not absolute positions
   - Correctly represent the "physical angle" between cursor and corner

#### Implementation approach:

```swift
// Only correct when cursor and laser display are on different screens
let cursorScreen = getScreen(containing: cursorPosition)
let cornerScreen = getScreen(containing: corner)

if cursorScreen != cornerScreen {
    // Correct distance with PPI
    let correctionFactor = cursorScreen.ppi / cornerScreen.ppi
    // Adjust distance from corner to cursor with correction factor
}
```

#### Benefits:

- ✅ Respects System Preferences arrangement settings
- ✅ No physical arrangement inference needed
- ✅ No user configuration or calibration required
- ✅ Simple and maintainable implementation
- ✅ Works with 3+ displays using same logic

#### Limitations:

- Not perfect if logical arrangement differs significantly from physical arrangement
- However, most users configure logical arrangement to match physical layout

## Measurement Date

Display information measured on: 2025-10-07

Configuration may change when displays are added, removed, or reconfigured.

## Design Decision History

- 2025-10-07: Initial problem analysis and PPI-based correction approach decision
- 2025-10-07: Coordinate system approach decision (respect logical coordinates, focus on relative distance correction)
