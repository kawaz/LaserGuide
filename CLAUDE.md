# AI Assistant Guidelines for CursorFinder

This document provides context and guidelines for AI assistants working on the CursorFinder project.

## Project Overview

CursorFinder is a macOS app that displays laser lines from screen corners to the mouse cursor, helping users locate their cursor on large or multiple displays.

## Development Workflow

### Branch Management
- **Use feature branches**: For any significant changes, create a feature branch
- **Use git worktree**: Don't switch branches in main project directory
  ```bash
  # Create new worktree for feature
  git worktree add .worktrees/feature-name -b feature/feature-name
  
  # Work in the worktree directory
  cd .worktrees/feature-name
  
  # After merge, clean up
  git worktree remove .worktrees/feature-name
  git branch -d feature/feature-name
  ```
- **Update workspace file**: When creating worktree, update [`.code-workspace`](CursorFinder.code-workspace) to include the new directory
- **Get approval before merge**: Explain changes to human and get confirmation before merging to main

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
- [`LaserViewModel.swift`](CursorFinder/Models/LaserViewModel.swift) - Core laser display logic
- [`Config.swift`](CursorFinder/Config.swift) - App configuration constants
- [`Makefile`](Makefile) - Build and release commands
- [`Formula/cursorfinder.rb`](Formula/cursorfinder.rb) - Homebrew distribution

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
- **Documentation exists**: See [`docs/code-signing.md`](docs/code-signing.md) for future implementation
- **Reason**: Easier distribution for open source project

### Workflows
1. [`01-ci-test.yml`](.github/workflows/01-ci-test.yml) - Tests on every push
2. [`02-cd-draft-release.yml`](.github/workflows/02-cd-draft-release.yml) - Prepares release notes
3. [`03-cd-release.yml`](.github/workflows/03-cd-release.yml) - Builds and deploys on tag push
4. [`04-cd-auto-release.yml`](.github/workflows/04-cd-auto-release.yml) - Auto-versions and tags on main push

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
1. Create feature branch with worktree:
   ```bash
   git worktree add .worktrees/feature-name -b feature/feature-name
   cd .worktrees/feature-name
   ```
2. Update [`.code-workspace`](CursorFinder.code-workspace) to include new worktree
3. Implement in appropriate manager/view
4. Update [`Config.swift`](CursorFinder/Config.swift) if adding settings
5. Test with `make dev`
6. Update README.md features section
7. Commit with `feat:` prefix
8. Push branch and explain changes to human
9. After approval, merge to main
10. Clean up worktree:
    ```bash
    cd ../..
    git worktree remove .worktrees/feature-name
    git branch -d feature/feature-name
    ```

### Fixing Bugs
1. For simple fixes: work directly on main
2. For complex fixes: use feature branch with worktree
3. Identify root cause
4. Fix with minimal changes
5. Test the fix
6. Commit with `fix:` prefix

### Updating Documentation
1. Make changes to relevant .md files
2. Ensure consistency across docs
3. Commit with `docs:` prefix (won't trigger release)

## Important Reminders

- **Branch discipline**: Always use worktrees for feature branches, never switch in main directory
- **Human approval**: Get confirmation before merging significant changes to main
- **Workspace maintenance**: Update `.code-workspace` when creating/removing worktrees
- **Cleanup**: Remove worktrees after features are merged
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