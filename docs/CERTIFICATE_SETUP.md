# Certificate Setup Guide

**Note**: Current automated releases are built without code signing. This guide is for future reference when code signing is implemented.

## Creating Apple ID Without Apple Device

You can create an Apple ID from any web browser:

1. Visit https://appleid.apple.com/
2. Click "Create Your Apple Account"
3. Fill in:
   - Email address (becomes your Apple ID)
   - Password
   - Name and birthday
   - Security questions

4. Verify via email

**Note**: While Apple ID can be created without Apple devices, creating development certificates requires access to a Mac with Xcode.

## Creating a New Apple Development Certificate

### Option 1: New Apple ID with Public Email

1. Create a new Apple ID at https://appleid.apple.com
   - Use a public email (e.g., `developer@zunsystem.co.jp`)
   
2. Sign in to Xcode with the new Apple ID
   - Xcode → Settings → Accounts → Add Apple ID
   
3. Create a new certificate
   - Xcode → Settings → Accounts → Manage Certificates
   - Click "+" → Apple Development

### Option 2: Developer ID Certificate (Paid)

1. Join Apple Developer Program ($99/year)
   - https://developer.apple.com/programs/
   
2. For company enrollment:
   - D-U-N-S Number required
   - Legal entity documentation
   
3. Create Developer ID Application certificate
   - Better for distribution (no Gatekeeper warnings)
   - Professional appearance

## Certificate Comparison

| Type | Cost | Gatekeeper | Email Visibility | Best For |
|------|------|------------|------------------|----------|
| Apple Development | Free | Warning | Visible | Personal/Testing |
| Developer ID | $99/year | No Warning | Company Name | Distribution |

## Switching Certificates

To switch to a new certificate:

1. Create the new certificate
2. Export it as .p12
3. Update GitHub Secrets
4. Next release will use the new certificate

The app's functionality remains the same regardless of certificate type.