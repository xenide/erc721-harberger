# Code Coverage Guide

This document explains how to generate, view, and maintain code coverage reports for the ERC721 Harberger project.

## Overview

Code coverage measures how much of the source code is executed during testing. This project uses Foundry's built-in coverage tools to track coverage across all Solidity contracts.

### Current Coverage Status

| Metric | Coverage | Status |
|--------|----------|--------|
| Lines | 86.32% | ✅ Good |
| Statements | 93.16% | ✅ Excellent |
| Branches | 80.56% | ⚠️ Fair |
| Functions | 70.37% | ⚠️ Fair |

**Last Updated:** Generated via `forge coverage`

## Generating Coverage Reports Locally

### Quick Start

```bash
# Generate both summary and LCOV format reports
npm run coverage

# Generate with detailed report file
npm run coverage:report
```

### Detailed Forge Commands

```bash
# Generate coverage with summary report
forge coverage --report summary

# Generate LCOV format (for IDE integration and tools like Codecov)
forge coverage --report lcov

# Generate both formats
forge coverage --report summary --report lcov

# Generate with custom report file location
forge coverage --report lcov --report-file coverage/lcov.info

# View coverage excluding test files
forge coverage --report summary --exclude-tests

# View coverage including library files
forge coverage --report summary --include-libs
```

### Coverage Report Formats

- **Summary**: Human-readable output showing coverage percentages per file
- **LCOV**: Machine-readable format compatible with tools like:
  - Codecov
  - Coveralls
  - VS Code Coverage Gutters extension
  - GitHub Coverage reports

## Interpreting Coverage Reports

### Coverage Metrics

1. **Lines**: Percentage of executable lines covered by tests
2. **Statements**: Percentage of statements executed
3. **Branches**: Percentage of conditional branches tested (if/else, ternary, etc.)
4. **Functions**: Percentage of functions called during testing

### What Counts as Coverage?

Code is considered "covered" if it's executed at least once during the test suite. This includes:
- Normal execution paths
- Error cases (reverts)
- Edge cases (boundary conditions)
- Different code branches

### Reading the Output

```
╭-----------------------------------+------------------+------------------+----------------+----------------╮
 File                               % Lines           % Statements      % Branches      % Funcs        
+===========================================================================================================+
 src/ERC721Harberger.sol            88.12% (89/101)   94.29% (99/105)   80.56% (29/36)  71.43% (15/21)
-----------------------------------+------------------+------------------+----------------+----------------
 src/libraries/Utils.sol            100.00% (4/4)     100.00% (5/5)     100.00% (0/0)   100.00% (1/1)  
-----------------------------------+------------------+------------------+----------------+----------------
 Total                              86.32% (101/117)  93.16% (109/117)  80.56% (29/36)  70.37% (19/27) 
╰-----------------------------------+------------------+------------------+----------------+----------------╯
```

**Interpretation:**
- `src/ERC721Harberger.sol` has 88.12% line coverage (89 out of 101 lines executed)
- `src/libraries/Utils.sol` has 100% coverage (fully tested)
- Overall project has 86.32% line coverage

## Improving Coverage

### Identifying Uncovered Code

1. Generate LCOV report:
   ```bash
   forge coverage --report lcov
   ```

2. Use IDE integration (VS Code with "Coverage Gutters" extension):
   - Install the extension
   - Open the lcov.info file
   - Uncovered lines appear highlighted in red

3. Analyze the summary report for gaps:
   ```bash
   forge coverage --report summary --exclude-tests
   ```

### Common Uncovered Code Patterns

- **Error handling**: Add tests that trigger `require()` statements
- **Conditional branches**: Test both true and false paths of if/else statements
- **State changes**: Verify state changes in different scenarios
- **Edge cases**: Test boundary conditions and special values

### Adding Coverage Tests

1. Identify uncovered code sections from the report
2. Add test cases in `test/unit/` or `test/integration/`
3. Run `npm run coverage` to verify improvement
4. Commit improved coverage along with test code

## CI/CD Integration

### GitHub Actions

Coverage is automatically generated in two workflows:

1. **test.yml** - Runs on every push/PR
   - Generates coverage report
   - Uploads to Codecov
   - Fails silently if upload fails (doesn't block CI)

2. **coverage.yml** - Dedicated coverage analysis
   - Runs coverage analysis with optimized settings
   - Uploads to Codecov
   - Displays coverage summary in GitHub Actions summary

### Codecov Integration

The project uploads coverage reports to [Codecov](https://codecov.io/). This provides:
- Coverage badges for README
- Historical coverage trends
- Pull request coverage comparisons
- Automatic coverage report comments on PRs

#### Getting Codecov Badge

Add to your README:
```markdown
[![codecov](https://codecov.io/gh/xenide/erc721-harberger/branch/main/graph/badge.svg)](https://codecov.io/gh/xenide/erc721-harberger)
```

## Foundry Coverage Profile

The `foundry.toml` includes a `[profile.coverage]` section for optimized coverage analysis:

```toml
[profile.coverage]
optimizer = false
via_ir = false
```

This profile:
- Disables optimizer for more accurate source mapping
- Disables IR for better compatibility with coverage tools
- Can be used with: `forge coverage --profile coverage`

## Troubleshooting

### "Stack too deep" errors during coverage

Solution: Use the `--ir-minimum` flag:
```bash
forge coverage --report summary --ir-minimum
```

This enables `viaIR` with minimum optimization to work around stack depth limits.

### Coverage report not generated

1. Verify all tests pass: `forge test`
2. Check Solc version compatibility: `forge --version`
3. Try with verbose output: `forge coverage -vvv`

### Codecov upload failing

- Ensure `lcov.info` is properly generated
- Check GitHub Actions logs for specific error
- Verify Codecov is enabled for the repository
- Note: Upload failures don't block CI (set with `fail_ci_if_error: false`)

## Best Practices

1. **Aim for >80% coverage** for critical contracts
2. **Test error paths**: Don't just test happy paths
3. **Test state transitions**: Verify state changes between operations
4. **Use fuzz testing**: Combine with coverage for edge case discovery
5. **Review uncovered branches**: Some unreachable code may need refactoring

## Coverage Goals by Contract

| Contract | Target | Status | Notes |
|----------|--------|--------|-------|
| ERC721Harberger.sol | 90%+ | 88.12% | Primary contract, focus on uncovered branches |
| Utils.sol | 100% | 100% ✅ | Fully covered |
| Errors.sol | N/A | - | Library, coverage tools ignore |
| Events.sol | N/A | - | Library, coverage tools ignore |

## References

- [Foundry Coverage Documentation](https://book.getfoundry.sh/forge/coverage)
- [LCOV Format Specification](http://ltp.sourceforge.net/coverage/lcov.php)
- [Codecov Documentation](https://docs.codecov.io/)
- [VS Code Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters)

## Future Improvements

- [ ] Increase ERC721Harberger branch coverage to 90%+
- [ ] Add integration tests for multi-user scenarios
- [ ] Set up coverage regression detection
- [ ] Integrate coverage reports with merge requirements
- [ ] Add coverage metrics to CI status checks

