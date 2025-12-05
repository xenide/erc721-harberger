# GitHub CI Setup

This project uses GitHub Actions to run automated tests and gas snapshot checks on every push and pull request.

## What the CI does

The CI workflow (`.github/workflows/test.yml`) performs the following checks:

1. **Format Check** - Verifies code follows the project's formatting standards using `forge fmt --check`
2. **Build** - Compiles the smart contracts with `forge build --sizes` to check for build errors
3. **Tests** - Runs all tests with `forge test -vvv` in verbose mode
4. **Gas Snapshots** - Generates gas usage snapshots and compares them against the baseline

## Local Setup

Before pushing changes, you can run these checks locally:

### Format
```bash
# Check formatting
forge fmt --check

# Auto-fix formatting
forge fmt
```

### Tests
```bash
forge test -vvv
```

### Gas Snapshots
```bash
# Generate or update gas snapshots
forge snapshot --snap snapshots/.gas-snapshot

# View changes
git diff snapshots/.gas-snapshot
```

## Gas Snapshot Workflow

The CI uses [Rubilmax/foundry-gas-diff](https://github.com/Rubilmax/foundry-gas-diff) to automatically check for gas regressions.

### First time setup
On the first run of the workflow or when tests are added:
1. The workflow will generate new snapshots
2. Commit the changes to `snapshots/.gas-snapshot`
3. Future PRs will be checked against this baseline

### Updating snapshots
If you intentionally change gas usage (e.g., optimizations):
1. The workflow will show the diff in the PR
2. Review the changes to ensure they're expected
3. Commit the updated `snapshots/.gas-snapshot` file

## Triggering CI

CI runs automatically on:
- Every push to any branch
- Every pull request
- Manual trigger via GitHub Actions UI

