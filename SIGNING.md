# Code Signing Setup for CursorFinder

This document describes how to set up code signing for CursorFinder releases.

**Note**: Current automated releases are built without code signing (`CODE_SIGNING_REQUIRED=NO`) for easier distribution. This documentation is for future implementation when code signing is re-enabled.

## Local Signing

For local builds, you can sign with your Apple Development certificate:

```bash
codesign --force --sign "Apple Development: YOUR_EMAIL (TEAM_ID)" --deep CursorFinder.app
```

## GitHub Actions Signing

To enable automatic code signing in GitHub Actions:

### 1. Export Certificate

```bash
# Export your certificate to a .p12 file
security export -k ~/Library/Keychains/login.keychain-db -t certs -f pkcs12 -P YOUR_PASSWORD -o certificate.p12
```

### 2. Create GitHub Secrets

Add the following secrets to your repository:

- `APPLE_CERTIFICATE_BASE64`: Base64 encoded certificate
  ```bash
  base64 -i certificate.p12 | pbcopy
  ```
- `APPLE_CERTIFICATE_PASSWORD`: The password you used when exporting
- `APPLE_DEVELOPMENT_TEAM`: Your Team ID (e.g., "33YX9FVF45")
- `APPLE_SIGNING_IDENTITY`: Your signing identity from `security find-identity -v -p codesigning`
  - Example: "Apple Development: your-email@example.com (TEAM_ID)"
  - Use the exact string shown in the output, including quotes

### 3. Update Release Workflow

The release workflow (`03-cd-release.yml`) currently builds without signing. To enable signing, the workflow would need to be updated to use these secrets.

## Verification

To verify the signature:

```bash
codesign -dv --verbose=4 CursorFinder.app
spctl -a -vvv -t install CursorFinder.app
```

## Notes

- Apple Development certificates allow the app to run after user approval
- For distribution without Gatekeeper warnings, you need a Developer ID certificate ($99/year)
- The current setup uses Apple Development certificate which is free