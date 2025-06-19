# AI Assistant Guidelines for CursorFinder

This document provides context and guidelines for AI assistants working on the CursorFinder project.

## Project Overview

CursorFinder is a macOS app that displays laser lines from screen corners to the mouse cursor, helping users locate their cursor on large or multiple displays.

## Development Workflow

### Commit Practices
- **Always create appropriate commits**: Make atomic commits with clear messages
- **Use conventional commits**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`
- **Commit regularly**: Don't accumulate too many changes in a single commit

### Version Management
- **Automatic versioning**: PRs merged to main trigger automatic releases
- **Version determination**: 
  - `feat:` → minor version bump
  - Other code changes → patch version bump
  - Documentation-only changes → no release

### Testing Changes
- **Use `make dev`**: Build and run the debug version to test changes
- **Check for existing functionality**: Before making changes, understand current behavior

## Documentation Maintenance

### Keep Documentation in Sync
When making code changes, always check and update:
1. `README.md` - User-facing features and build instructions
2. `CONTRIBUTING.md` - Development workflow changes
3. `CHANGELOG.md` - Notable changes (updated automatically by release workflow)
4. `.github/workflows/README.md` - Workflow changes
5. `docs/code-signing.md` - Security or signing-related changes

### Documentation Principles
- **Single source of truth**: Avoid duplicating content across files
- **Cross-reference**: Link between documents rather than duplicating
- **Keep current**: Update docs in the same commit as code changes
- **Consider the audience**: README for users, CONTRIBUTING for developers

## Code Organization

### Project Structure
```
CursorFinder/
├── CursorFinder/          # Swift source code
│   ├── Views/            # SwiftUI views
│   ├── Models/           # View models and data models
│   ├── Managers/         # Business logic managers
│   └── Config/           # Configuration constants
├── .github/workflows/    # CI/CD automation
├── Formula/              # Homebrew formula
├── docs/                 # Technical documentation
└── Makefile             # Build automation
```

### Key Files
- `LaserViewModel.swift` - Core laser display logic
- `Config.swift` - App configuration constants
- `Makefile` - Build and release commands
- `Formula/cursorfinder.rb` - Homebrew distribution

## Release Process

### Automated Releases
1. Code changes pushed to main are automatically detected
2. Version is determined by commit messages
3. Tag is created and pushed automatically
4. Release workflow builds and publishes

### Manual Controls
- `make version-patch/minor/major` - Manual version control
- Useful for specific version requirements

## Current State Notes

### Code Signing
- **Currently disabled**: Builds use `CODE_SIGNING_REQUIRED=NO`
- **Documentation exists**: See `docs/code-signing.md` for future implementation
- **Reason**: Easier distribution for open source project

### Workflows
1. `01-ci-test.yml` - Tests on every push
2. `02-cd-draft-release.yml` - Prepares release notes
3. `03-cd-release.yml` - Builds and deploys on tag push
4. `04-cd-auto-release.yml` - Auto-versions and tags on main push

## Guidelines for Changes

### Before Making Changes
1. Understand the current implementation
2. Check if similar functionality exists
3. Consider impact on existing features

### When Making Changes
1. Test locally with `make dev`
2. Update relevant documentation
3. Create clear, atomic commits
4. Ensure CI/CD compatibility

### After Making Changes
1. Verify documentation is updated
2. Check that workflows still function
3. Ensure Makefile targets work correctly

## Common Tasks

### Adding New Features
1. Implement in appropriate manager/view
2. Update Config.swift if adding settings
3. Test with `make dev`
4. Update README.md features section
5. Commit with `feat:` prefix

### Fixing Bugs
1. Identify root cause
2. Fix with minimal changes
3. Test the fix
4. Commit with `fix:` prefix

### Updating Documentation
1. Make changes to relevant .md files
2. Ensure consistency across docs
3. Commit with `docs:` prefix (won't trigger release)

## Important Reminders

- **Documentation reviews**: Regularly check that docs match implementation
- **Workflow updates**: Test workflow changes carefully
- **Breaking changes**: Currently treated as minor version bumps
- **Security**: Never commit secrets or API keys
- **Code style**: Follow existing Swift patterns and conventions

## Questions to Ask

When starting a new session, consider asking:
1. "What's the current status of the project?"
2. "Are there any pending changes or issues?"
3. "Has the release process changed?"
4. "Are there any new requirements or constraints?"

This document should be updated whenever significant changes are made to the project structure, workflows, or development practices.