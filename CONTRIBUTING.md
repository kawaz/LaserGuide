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

1. **Make Changes**: Commit and push your changes to `main`
2. **Create Version Tag**: Use Make commands to create a new version:
   ```bash
   make version-patch  # For bug fixes (0.0.X)
   make version-minor  # For new features (0.X.0)  
   make version-major  # For breaking changes (X.0.0)
   ```
3. **Push Tag**: This triggers the automated release:
   ```bash
   git push origin v0.2.3
   ```
4. **Automated Process**: GitHub Actions will:
   - Create a GitHub release with changelog
   - Build Universal Binary (unsigned)
   - Upload `CursorFinder.zip` to release
   - Update Homebrew formula automatically
   - Users can `brew upgrade cursorfinder` to get the latest version

### Testing Locally

```bash
# Build and run debug version
make dev

# Build only
make build-debug

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