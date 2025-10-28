# GitHub Actions Workflow

## test.yml - Automated Testing Workflow

The `workflows/test.yml` file provides automated testing on every push:

- Bash syntax validation
- ShellCheck static analysis
- Python syntax checking
- BATS unit tests
- Security checks

## Installation Note

Due to GitHub workflow permissions, this file may need to be:
1. Committed manually via GitHub web interface, OR
2. Pushed with an account that has `workflows` permission

If the automated push fails, you can add it manually:
```bash
git add .github/workflows/test.yml
git commit -m "ci: add GitHub Actions workflow"
git push
```

Or commit directly through GitHub's web interface:
1. Go to repository on GitHub
2. Navigate to `.github/workflows/`
3. Create new file `test.yml`
4. Paste contents from local file
5. Commit directly to branch

## Testing Without GitHub Actions

The CI/CD pipeline is optional. You can still use all development tools locally:
- `./dev-tools/validate.sh` - Runs same checks as CI
- `./dev-tools/test-runner.sh` - Test execution
- Pre-commit hooks provide validation before commits

See [DEV_SETUP.md](../DEV_SETUP.md) for complete documentation.
