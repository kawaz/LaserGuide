# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2025-06-19

### Fixed
- Prevent laser display on app startup - laser now only appears after first mouse movement

### Changed
- Simplified Makefile with better build targets
- Consolidated release workflows into single automated flow
- Improved version management to check remote tags

## [0.2.0] - 2025-06-19

### Fixed
- Prevent laser display on app startup

### Changed
- Refactored Makefile and automated release workflows

## [0.1.5] - 2025-06-19

### Added
- Signed release with automatic signing

## [0.1.3] - 2025-06-19

### Added
- First signed release

## [0.1.2] - 2025-06-18

### Added
- Initial release
- Display laser lines from all four screen corners to mouse cursor
- Multi-display support
- Automatic hide when mouse is idle
- Screenshot safe (laser lines excluded from screenshots)
- Distance indicator for off-screen cursor
- GPU-optimized rendering using Metal
- Universal Binary (Intel + Apple Silicon)