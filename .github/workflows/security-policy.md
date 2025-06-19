# Workflow Security Policy

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