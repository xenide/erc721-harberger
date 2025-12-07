# GitHub CI Setup

This project uses GitHub Actions to run automated tests and gas snapshot checks on every push and pull request.

## What the CI does

The CI workflow (`.github/workflows/test.yml`) performs the following checks:

1. **Format Check** - Verifies code follows the project's formatting standards using `forge fmt --check`
2. **Build** - Compiles the smart contracts with `forge build --sizes` to check for build errors
3. **Tests** - Runs all tests with `forge test -vvv` in verbose mode
4. **Coverage** - Generates code coverage reports and uploads to Codecov
5. **Gas Snapshots** - Generates gas usage snapshots and compares them against the baseline

A dedicated **Coverage Workflow** (`.github/workflows/coverage.yml`) also runs to:
- Generate detailed coverage reports with optimized settings
- Upload coverage data to Codecov
- Display coverage summary in GitHub Actions

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

### Coverage
```bash
# Generate coverage report
npm run coverage

# Generate coverage with detailed report file
npm run coverage:report

# View coverage excluding tests
forge coverage --report summary --exclude-tests

# Generate LCOV format for IDE integration
forge coverage --report lcov
```

For more details on coverage analysis, see [COVERAGE.md](./COVERAGE.md).

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

