# Contributing to CursorFinder

## Development Workflow

### Branch Strategy

- `main`: Production-ready code
- `feature/*`: New features
- `fix/*`: Bug fixes
- `docs/*`: Documentation updates
- `chore/*`: Maintenance tasks

### Commit Messages

We use conventional commits for automatic versioning:

- `feat:` - New feature (triggers minor version bump)
- `fix:` - Bug fix (triggers patch version bump)
- `docs:` - Documentation only changes (no release)
- `chore:` - Changes that don't affect functionality (no release)
- `refactor:` - Code refactoring (triggers patch version bump)
- `test:` - Adding tests (no release)
- `BREAKING CHANGE:` - Breaking API change (currently treated as minor)

Examples:
```
feat: add keyboard shortcut to toggle laser visibility
fix: correct laser position on external displays
docs: update installation instructions
chore: update dependencies
refactor: simplify mouse tracking logic
```

**Important**: Only commits that modify code files (.swift, .m, .plist, etc.) will trigger a release.

### Release Process

#### Automatic Release (Recommended)

Simply merge your PR to main! The system will automatically:

1. **Detect Code Changes**: Only releases if code files were modified
2. **Determine Version**: Based on commit messages:
   - `feat:` commits → minor version bump
   - Other code changes → patch version bump
3. **Create Release**: Automatically tags, builds, and publishes
4. **Update Formula**: Homebrew formula is updated automatically

#### Manual Release (When Needed)

If you need to manually control the version:

```bash
make version-patch  # For bug fixes (0.0.X)
make version-minor  # For new features (0.X.0)  
make version-major  # For breaking changes (X.0.0)
git push origin v0.2.3
```

**Note**: The automatic process ensures consistent versioning and prevents accidental releases when only documentation is updated.

### Testing Locally

```bash
# Build and run debug version
make dev

# Build only
make build-debug

# Test Homebrew formula locally
brew install --build-from-source [Formula/cursorfinder.rb](Formula/cursorfinder.rb)
```

## Pull Request Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Code Style

- Use SwiftLint rules (if configured)
- Follow Apple's Swift API Design Guidelines
- Keep code modular and testable