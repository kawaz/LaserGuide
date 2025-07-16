# LaserGuide

A macOS app that displays laser-like lines from screen corners to your mouse cursor, making it easier to locate your cursor on large or multiple displays.

<img width="1200" alt="LaserGuide Demo" src="https://github.com/kawaz/LaserGuide/assets/326750/demo-placeholder.png">

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

### Install via Homebrew Cask

```bash
brew install --cask kawaz/laserguide/laserguide
```

> **Note**: LaserGuide is now distributed as a Homebrew Cask for easier installation and updates. The previous Formula-based distribution has been deprecated.


### Build from Source (Xcode)

1. Clone the repository:
```bash
git clone https://github.com/kawaz/LaserGuide.git
cd LaserGuide
```

2. Open the project in Xcode:
```bash
open [LaserGuide.xcodeproj](LaserGuide.xcodeproj)
```

3. Build and run the project (⌘+R)

### Build from Source (CLI)

1. Clone the repository:
```bash
git clone https://github.com/kawaz/LaserGuide.git
cd LaserGuide
```

2. Build and run using Make:
```bash
# Build and run debug version
make dev

# Build only (debug)
make build-debug

# Build release version
make build-release

# Build release and create zip
make build-zip
```

3. Manual build with xcodebuild:
```bash
# Build for Debug
xcodebuild -scheme LaserGuide -configuration Debug build

# Build for Release  
xcodebuild -scheme LaserGuide -configuration Release build
```

Note: Current releases are built without code signing for easier distribution.

### Pre-built Binary

Download the latest release from the [Releases page](https://github.com/kawaz/LaserGuide/releases).

1. Download `LaserGuide.zip`
2. Unzip and move `LaserGuide.app` to your Applications folder
3. Open the app (you may need to right-click and select "Open" the first time)

## Usage

1. Launch LaserGuide
2. Look for the 🔍 icon in your menu bar
3. Move your mouse to see the laser lines
4. The lines will automatically disappear after 0.3 seconds of inactivity
5. To quit, click the menu bar icon and select "Quit"

## Configuration

Current configuration options are available in [`Config.swift`](LaserGuide/Config.swift):

- **Visual Settings**: Line width, gradient colors
- **Timing**: Inactivity threshold
- **Performance**: GPU optimization toggle

## Privacy & Security

LaserGuide requires accessibility permissions to track mouse movements globally. The app:
- Does not collect or transmit any data
- Only tracks mouse position for display purposes
- Runs entirely locally on your machine

## Development

### Available Make Commands

```bash
make               # Show available commands
make dev           # Build and run debug version
make build-debug   # Build debug version only
make build-release # Build release version
make build-zip     # Build release and create zip
make clean         # Clean build artifacts
```

### Automated Release Process

LaserGuide uses GitHub Actions for automated releases:

1. **Code Quality Checks**: SwiftLint, static analysis, and memory leak detection
2. **Automated Testing**: Unit tests, integration tests, and performance tests
3. **Auto-Release**: Automatic version bumping and release creation on code changes
4. **Homebrew Integration**: Automatic Cask updates with SHA256 verification

### Release Process

For detailed release instructions, see [CONTRIBUTING.md](CONTRIBUTING.md#release-process).

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and macOS native frameworks
- Uses Metal for GPU-optimized rendering