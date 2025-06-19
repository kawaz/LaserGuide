# GitHub Actions Security Best Practices

## Secrets Protection

1. **Never use `pull_request_target`** with Secrets
2. **Only trigger on specific events**:
   - `push` to main/master
   - `release` published
   - `workflow_dispatch` (manual)

3. **Restrict workflow permissions**:
   ```yaml
   permissions:
     contents: read  # Minimum required permissions
   ```

4. **Review all workflow changes** before merging

## Current Safe Configuration

Our release workflow only runs on:
- `release: types: [published]` - Only when maintainers publish a release
- No external PRs can trigger certificate signing

## Additional Recommendations

1. Enable branch protection rules
2. Require PR reviews for workflow changes
3. Monitor Actions usage in Settings → Actions
4. Use CODEOWNERS file for .github/workflows/

## Why This Matters

When using secrets (like Apple signing certificates) in GitHub Actions, it's crucial to ensure they can't be accessed by untrusted code. The `pull_request_target` event runs in the context of the base branch with access to secrets, which could be exploited by malicious PRs.

Our current setup ensures that only trusted events (tags pushed by maintainers) can access sensitive secrets.