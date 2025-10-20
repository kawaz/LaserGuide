# Smart Display Edge Navigation

## Overview

**Smart Edge Navigation** is a feature that improves cursor movement between displays in multi-monitor setups. It automatically warps the cursor to adjacent displays even when the display edges don't directly touch, eliminating "dead zones" where the cursor gets stuck.

## The Problem: Cursor Dead Zones

### Typical Scenario

Imagine you have two monitors stacked vertically:
- **Top Monitor**: Large, 27-inch (2560×1440 pixels)
- **Bottom Monitor**: Smaller, 13-inch (2880×1800 pixels), center-aligned

In macOS Display Settings, the smaller monitor is centered under the larger one:

```
┌─────────────────────────────────────┐
│                                     │
│         Top Monitor (Large)         │
│                                     │
├─────┬───────────────────────┬───────┤
│ ◄─┐ │                       │ ┌─► │
│ Dead│  Bottom Monitor (Small) │Dead │
│Zone │                       │Zone │
└─────┴───────────────────────┴─────┘
```

**The Issue:**
- When you move the cursor to the bottom-left or bottom-right corner of the top monitor...
- ...and try to move further down...
- **The cursor gets stuck!** There's no display directly below those corners.

This creates frustrating "dead zones" where cursor movement stops unexpectedly.

### Real-World Impact

Dead zones commonly occur when:
- Displays have different sizes (laptop + external monitor)
- Center-aligned vertical stacking
- Center-aligned horizontal arrangement
- L-shaped or U-shaped multi-monitor setups
- Any configuration where edges don't perfectly align

## The Solution: Smart Edge Warping

Smart Edge Navigation detects when you're trying to move past a dead zone and automatically warps the cursor to the nearest display in that direction.

### How It Works

1. **Edge Detection**: Monitors when cursor reaches a screen edge (within 5 pixels)
2. **Intent Recognition**: Detects continued movement attempts in the blocked direction
3. **Smart Search**: Finds the nearest display in that direction, even if not directly adjacent
4. **Natural Warping**: Moves cursor to the corresponding position on the target display's edge
5. **Physical Awareness**: Uses calibration data when available for more natural transitions

### Example Behavior

Using the stacked monitors example:

```
Top Monitor:
  User moves cursor to bottom-right corner → Continues moving down

Smart Edge Navigation:
  Detects: At edge + downward intent
  Finds: Bottom monitor (not directly below, but exists downward)
  Warps: Cursor to top-right of bottom monitor

Result:
  Smooth transition despite the dead zone!
```

## Technical Approach

### CGEventTap for Accurate Detection

Smart Edge Navigation uses `CGEventTap` to monitor mouse events at a low level:

**Why CGEventTap?**
- Provides accurate mouse movement deltas (`deltaX`, `deltaY`)
- Detects the *direction* of movement attempts, not just position
- Can distinguish "stuck at edge trying to move further" from "resting at edge"

**Movement Intent Detection:**
```swift
// Example: Cursor is at bottom edge
if cursorY == screenMaxY {  // At edge
    if deltaY < 0 {          // Still trying to move down (negative Y)
        // User wants to go further → Trigger warp!
    }
}
```

### Display Search Strategy

When warping, the system searches for target displays in this order:

1. **Logically Adjacent**: Check if there's a display directly touching in that direction
2. **Physical Proximity**: If calibration data exists, find the nearest display physically
3. **Position Mapping**: Calculate relative position along the edge (0-100%)
4. **Corresponding Point**: Map to the same relative position on target display's edge

### Coordinate Systems

**Without Calibration:**
- Uses macOS logical coordinates
- Searches based on display frame boundaries
- Maps edge-to-edge using logical dimensions

**With Calibration:**
- Uses physical coordinates (millimeters)
- Searches based on actual physical positions
- Provides more natural transitions for complex setups

## User Experience

### Enabling/Disabling

- **Default**: Enabled
- **Toggle**: Menu bar → **LaserGuide** > **Smart Edge Navigation** (checkmark)
- **Persistent**: Setting saved across app restarts

### Permission Requirements

Smart Edge Navigation requires **Accessibility permissions** because it uses CGEventTap.

**On First Activation:**
1. macOS shows a permission prompt
2. User clicks "Open System Settings"
3. User toggles the permission for LaserGuide
4. Feature activates automatically

**If Permission Denied:**
- Feature remains inactive
- Menu item shows "(Permission Required)"
- Clicking it re-prompts for permission

### Behavioral Details

**When Warping Occurs:**
- Cursor reaches screen edge (within 5px)
- Movement continues in the blocked direction for 50-100ms
- Target display found in that direction
- Cursor warps instantly to target position

**When Warping Doesn't Occur:**
- Cursor is at edge but not moving
- Movement is parallel to the edge (not outward)
- No display exists in that direction
- Feature is disabled in settings

**Natural Feel:**
- Preserves horizontal/vertical position when possible
- Smooth instant teleportation (no animation needed)
- Consistent with macOS display edge behavior

### System Compatibility

**Works With:**
- Hot Corners - no interference
- Dock auto-hide - no interference
- Mission Control edge gestures - no interference
- Fullscreen app edge reveals - no interference

**Why No Conflicts?**
Smart Edge Navigation only acts on dead zones (edges with no adjacent display). When displays are directly adjacent, normal macOS behavior continues unchanged.

## Multi-Monitor Configurations

### Supported Layouts

**Vertical Stack (different sizes):**
```
┌─────────────┐
│    Large    │
├────┬───┬────┤
     │Sm │     ← Warps work from gray zones
     └───┘
```

**Horizontal Arrangement (different heights):**
```
┌───┐ ┌─────┐
│Sml│ │Large│
└───┘ └─────┘
  ↕           ← Warps work from gray zones
```

**L-Shape:**
```
┌───┬───┐
│ A │ B │
└───┴───┤
    │ C │    ← Warps B↔C despite no direct touch
    └───┘
```

**U-Shape:**
```
┌───┬───┬───┐
│ A │ B │ C │
└───┘   └───┘
  ↕  (gap) ↕  ← Warps A↔C through the gap
```

### With Physical Calibration

When [Physical Layout Calibration](physical-layout-calibration.md) is configured:

- Warps respect actual physical positions
- More natural transitions in complex setups
- Accounts for rotation and 3D desk arrangements
- Handles bezel widths and gaps correctly

**Example:**
If your bottom monitor is physically offset to the right but logically centered, warping will target the physically correct position, not just the logical alignment.

## Implementation Notes

### Independent Module

Smart Edge Navigation is implemented as a separate, independent module:
- Doesn't interfere with laser display functionality
- Shares only calibration data via `CalibrationDataManager`
- Can be enabled/disabled independently
- Runs its own CGEventTap

### Performance

- **Low Overhead**: Only active when cursor is near edges
- **Efficient Detection**: Uses hardware-accelerated event system
- **No Polling**: Event-driven architecture
- **Instant Warping**: No animation delay

### Safety

- **No Interference**: Doesn't block normal cursor movement
- **Reversible**: Easy to disable if unwanted
- **Configurable**: Thresholds tunable for different preferences
- **Logged**: Debug output for troubleshooting

## Future Enhancements

Potential improvements:

- **Per-Edge Configuration**: Enable/disable specific edges
- **Adjustable Sensitivity**: Tune intent detection timing
- **Custom Warp Points**: User-defined warp destinations
- **Visual Feedback**: Optional indicators when warp occurs
- **Statistics**: Track how often warping is used

## FAQ

**Q: Will this interfere with my Hot Corners?**
A: No. Hot Corners trigger on corners where displays actually meet. Smart Edge Navigation only acts on dead zones.

**Q: Can I use this without Physical Calibration?**
A: Yes! It works with logical coordinates by default. Calibration just makes it more accurate for complex setups.

**Q: What if I don't like the warping behavior?**
A: Simply toggle "Smart Edge Navigation" off in the menu. The setting persists.

**Q: Does this require additional permissions?**
A: Yes, Accessibility permission for CGEventTap. macOS will prompt you on first use.

**Q: Will this drain my battery?**
A: No significant impact. The system uses efficient event-driven monitoring, not continuous polling.

**Q: Can I adjust the detection sensitivity?**
A: Not yet in the UI, but the implementation uses tunable constants. Future versions may expose these as settings.

## See Also

- [Physical Layout Calibration](physical-layout-calibration.md) - Enhance warping accuracy
- [Smart Edge Navigation Implementation](smart-edge-navigation-implementation.md) - Technical details
