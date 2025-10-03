# GitHub Actions Workflows

## Active Workflows

### 1. CI - Build and Test (`integration-tests.yml`)
- **Trigger**: Push to main, Pull Requests
- **Purpose**: Build verification and unit tests

### 2. Code Quality (`code-quality.yml`)
- **Trigger**: Push to main, Pull Requests  
- **Purpose**: SwiftLint and static analysis

### 3. CD - Auto Release (`cd-auto-release-and-deploy.yml`)
- **Trigger**: Push to main (code changes only)
- **Purpose**: Automatic version bump, build, release, and Homebrew tap update

## Release Flow

Code changes → CI/CD → Version bump → Build → GitHub Release → Homebrew Tap update

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for details.
