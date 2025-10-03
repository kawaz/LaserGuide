# AI Assistant Guidelines for LaserGuide

LaserGuide: macOS app displaying laser lines from screen corners to mouse cursor.

## Quick Reference

### Testing After Changes
```bash
# After push to main
./scripts/verify-ci-cd.sh    # Wait for CI/CD completion
./scripts/test-install.sh     # Install via Homebrew and test
```

### Development Workflow
- **Direct commits to main**: For simple fixes
- **Feature branches with worktrees**: For complex features only
- **Conventional commits**: `feat:` (minor bump) / `fix:` (patch bump) / `docs:` (no release)

### Project Structure
- `LaserGuide/` - Swift source code
- `scripts/` - Test automation scripts
- `Casks/` - Homebrew cask template
- `.github/workflows/` - CI/CD automation

## Automated Systems

### CI/CD Pipeline
Push to main → Build/Test → Version bump (if code changed) → Release → Update Homebrew tap

### Release Process
Fully automated. Code changes trigger:
1. Version determination from commit messages
2. Build and create GitHub release
3. Update `kawaz/homebrew-laserguide` repository

## Code Guidelines

### Key Files
- `Managers/MouseTrackingManager.swift` - Mouse event handling (debounce pattern)
- `Models/LaserViewModel.swift` - Laser display logic
- `Config.swift` - App configuration

### Mouse Tracking
- Monitor: `.mouseMoved`, `.leftMouseDragged`, `.rightMouseDragged`, `.otherMouseDragged`
- **Do not** monitor: `.scrollWheel` (prevents inertia scroll issues)
- Use `DispatchWorkItem` for debounce (not `Timer`)

## Documentation Maintenance

### Regular Cleanup Tasks
When starting a new session, check:
1. Remove obsolete files/directories
2. Update outdated documentation
3. Keep CLAUDE.md concise (this file)

### Documentation Files
- `README.md` / `README.ja.md` - User documentation (synced)
- `CONTRIBUTING.md` - Development guide
- `CLAUDE.md` - This file (AI assistant context)
- `.github/workflows/README.md` / `README.ja.md` - CI/CD overview (synced)

### Maintenance Principles
- **Concise over comprehensive**: Remove redundancy
- **Actionable over explanatory**: Focus on what to do
- **Current over complete**: Delete outdated content
- **Automated over manual**: Use scripts for repetitive tasks

## Common Tasks

### Fix and Deploy
1. Make code changes
2. Commit with conventional prefix
3. Push to main
4. Run `./scripts/verify-ci-cd.sh`
5. Run `./scripts/test-install.sh`
6. Verify functionality

### Add Feature
1. Create worktree if complex: `git worktree add .worktrees/feature-name -b feature/feature-name`
2. Implement and test locally
3. Commit with `feat:` prefix
4. Merge to main
5. Clean up worktree
6. Follow "Fix and Deploy" steps

### Documentation Update
1. Update relevant .md files
2. Run `./scripts/sync-ja-docs.sh` to sync Japanese versions
3. Commit with `docs:` prefix (no release triggered)
4. Keep documentation minimal and current

## Important Notes
- **No code signing**: Builds use `CODE_SIGNING_REQUIRED=NO`
- **Homebrew tap**: Separate repository `kawaz/homebrew-laserguide`
- **Test scripts**: Use provided scripts to avoid repetitive work
- **Keep this file short**: Remove outdated information regularly
