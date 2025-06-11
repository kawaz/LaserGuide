# CursorFinder

A macOS app that displays laser-like lines from screen corners to your mouse cursor, making it easier to locate your cursor on large or multiple displays.

<img width="1200" alt="CursorFinder Demo" src="https://github.com/kawaz/CursorFinder/assets/326750/demo-placeholder.png">

## Features

- **Laser Lines**: Displays gradient laser lines from all four screen corners to your mouse cursor
- **Multi-Display Support**: Works seamlessly across multiple monitors
- **Smart Visibility**: Automatically hides when the mouse is idle and reappears on movement
- **Screenshot Safe**: Laser lines are excluded from screenshots (macOS's built-in screenshot tools won't capture them)
- **Distance Indicator**: Shows percentage distance when cursor is on another screen
- **Visual Effects**: 
  - Tapered laser lines (thick at corners, thin near cursor)
  - Gradient coloring for better visibility
  - GPU-optimized rendering using Metal

## Requirements

- macOS 15.3 or later
- Xcode 15.0 or later (for building from source)

## Installation

### Install via Homebrew

```bash
brew tap kawaz/tap
brew install cursorfinder
```

### Build from Source (Xcode)

1. Clone the repository:
```bash
git clone https://github.com/kawaz/CursorFinder.git
cd CursorFinder
```

2. Open the project in Xcode:
```bash
open CursorFinder.xcodeproj
```

3. Build and run the project (⌘+R)

### Build from Source (CLI)

1. Clone the repository:
```bash
git clone https://github.com/kawaz/CursorFinder.git
cd CursorFinder
```

2. Build the app using xcodebuild:
```bash
# Build for Debug
xcodebuild -scheme CursorFinder -configuration Debug build

# Build for Release
xcodebuild -scheme CursorFinder -configuration Release build
```

3. The built app will be located at:
```bash
# Debug build
~/Library/Developer/Xcode/DerivedData/CursorFinder-*/Build/Products/Debug/CursorFinder.app

# Release build
~/Library/Developer/Xcode/DerivedData/CursorFinder-*/Build/Products/Release/CursorFinder.app
```

4. Run the app:
```bash
# Find and run the Debug build
open ~/Library/Developer/Xcode/DerivedData/CursorFinder-*/Build/Products/Debug/CursorFinder.app

# Or copy to Applications folder (Release build)
cp -r ~/Library/Developer/Xcode/DerivedData/CursorFinder-*/Build/Products/Release/CursorFinder.app /Applications/
open /Applications/CursorFinder.app
```

### Pre-built Binary

Coming soon...

## Usage

1. Launch CursorFinder
2. Look for the 🔍 icon in your menu bar
3. Move your mouse to see the laser lines
4. The lines will automatically disappear after 0.3 seconds of inactivity
5. To quit, click the menu bar icon and select "Quit"

## Configuration

Current configuration options are available in `Config.swift`:

- **Visual Settings**: Line width, gradient colors
- **Timing**: Inactivity threshold
- **Performance**: GPU optimization toggle

## Privacy & Security

CursorFinder requires accessibility permissions to track mouse movements globally. The app:
- Does not collect or transmit any data
- Only tracks mouse position for display purposes
- Runs entirely locally on your machine

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and macOS native frameworks
- Uses Metal for GPU-optimized rendering