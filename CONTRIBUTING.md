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

- `feat:` - New feature (minor version bump)
- `fix:` - Bug fix (patch version bump)
- `docs:` - Documentation only changes
- `chore:` - Changes that don't affect functionality
- `BREAKING CHANGE:` - Breaking API change (major version bump)

Examples:
```
feat: add keyboard shortcut to toggle laser visibility
fix: correct laser position on external displays
docs: update installation instructions
chore: update dependencies
```

### Release Process

1. **Automatic Release Draft**: Every push to `main` updates a draft release
2. **Version Bumping**: Based on commit messages
3. **Publishing**: When you publish the draft release:
   - CI builds Universal Binary
   - Uploads `CursorFinder.zip` to release
   - Updates Homebrew formula automatically
   - Users can `brew upgrade` to get the latest version

### Testing Locally

```bash
# Build and test
xcodebuild -scheme CursorFinder -configuration Debug build

# Test Homebrew formula locally
brew install --build-from-source Formula/cursorfinder.rb
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