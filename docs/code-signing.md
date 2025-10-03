# Code Signing Documentation

**Note**: Current automated releases are built without code signing (`CODE_SIGNING_REQUIRED=NO`) for easier distribution. This documentation is for future implementation when code signing is re-enabled.

## Overview

Code signing allows macOS to verify that an app hasn't been modified since it was signed. While not currently implemented in our automated builds, this guide documents the process for future use.

## Certificate Types

| Type | Cost | Gatekeeper | Best For |
|------|------|------------|----------|
| Apple Development | Free | Shows warning | Personal/Testing |
| Developer ID | $99/year | No warning | Distribution |

## Creating Certificates

### Free Apple Development Certificate

1. Create an Apple ID at https://appleid.apple.com (no Apple device required)
2. Sign in to Xcode with the Apple ID
3. Create certificate in Xcode → Settings → Accounts → Manage Certificates

### Paid Developer ID Certificate

1. Join Apple Developer Program ($99/year)
2. For companies: D-U-N-S Number required
3. Create Developer ID Application certificate for distribution

## Local Signing

For local builds:
```bash
codesign --force --sign "Apple Development: YOUR_EMAIL (TEAM_ID)" --deep LaserGuide.app
```

To verify:
```bash
codesign -dv --verbose=4 LaserGuide.app
spctl -a -vvv -t install LaserGuide.app
```

## GitHub Actions Setup

To enable automatic code signing in CI/CD:

### 1. Export Certificate

```bash
# Generate a secure random password
CERT_PASSWORD="$(openssl rand -base64 48)"

# Save the password (you'll need it for GitHub Secrets)
echo "Certificate password: $CERT_PASSWORD"

# Export certificate to .p12 file
security export -k ~/Library/Keychains/login.keychain-db \
  -t certs -f pkcs12 -P "$CERT_PASSWORD" -o certificate.p12

# Convert to base64 for GitHub Secrets
base64 -i certificate.p12 | pbcopy
```

### 2. Create GitHub Secrets

Add these secrets to your repository:

- `APPLE_CERTIFICATE_BASE64`: The base64 encoded certificate (from clipboard)
- `APPLE_CERTIFICATE_PASSWORD`: The password used during export
- `APPLE_DEVELOPMENT_TEAM`: Your Team ID (found in Xcode)
- `APPLE_SIGNING_IDENTITY`: From `security find-identity -v -p codesigning`

### 3. Update Workflow

The release workflow ([`cd-auto-release-and-deploy.yml`](../.github/workflows/cd-auto-release-and-deploy.yml)) would need to be updated to use these secrets instead of building with `CODE_SIGNING_REQUIRED=NO`.

## Security Best Practices

### Workflow Security

1. **Never use `pull_request_target`** with secrets
2. **Only trigger on specific events**:
   - `push` to main/master
   - Version tag pushes (`v*.*.*`) - now automatically created by [`cd-auto-release-and-deploy.yml`](../.github/workflows/cd-auto-release-and-deploy.yml)
   - `workflow_dispatch` (manual)

3. **Restrict workflow permissions**:
   ```yaml
   permissions:
     contents: read  # Minimum required
   ```

### Current Configuration

Our workflows are secure:
- [`code-quality.yml`](../.github/workflows/code-quality.yml): Runs linting and code quality checks (no secrets)
- [`integration-tests.yml`](../.github/workflows/integration-tests.yml): Runs tests on push/PR (no secrets)
- [`cd-auto-release-and-deploy.yml`](../.github/workflows/cd-auto-release-and-deploy.yml): Automatically creates releases, tags, and updates Homebrew tap based on commit messages

### Additional Recommendations

1. Enable branch protection rules
2. Require PR reviews for workflow changes
3. Monitor Actions usage in Settings → Actions
4. Use CODEOWNERS file for [`.github/workflows/`](../.github/workflows/)

## Why Unsigned Builds?

We currently build without signing because:
- Easier distribution for open source projects
- Users can inspect the code and build themselves
- No annual fee required
- Users just need to right-click → Open on first launch

When/if we implement signing in the future, this documentation provides the complete setup process. The release workflow ([`cd-auto-release-and-deploy.yml`](../.github/workflows/cd-auto-release-and-deploy.yml)) would need to be updated to enable code signing.