# Go Code Review Skill

Comprehensive code quality review for Go changes in your current branch.

## Quick Start

```bash
# Review all Go changes in current branch vs main
/go-code-review
```

That's it! The skill will analyze your changes and provide a detailed report.

## What It Checks

### 1. Bugs 🐛
- Nil pointer dereferences
- Unchecked error returns
- Goroutine leaks
- Race conditions
- Incorrect defer usage
- Range loop variable capture
- Slice append issues
- Context not propagated

### 2. Formatting & Style 📝
- Via `golangci-lint` (50+ linters)
- `go vet` issues
- `errcheck` - unchecked errors
- `staticcheck` - bugs and performance
- `gosimple` - simplification opportunities
- `ineffassign` - ineffective assignments
- `unused` - unused code

### 3. Performance ⚡
- String concatenation in loops
- Unnecessary allocations
- Inefficient map access
- Large data structure copies
- Inefficient JSON operations

### 4. Test Coverage 🧪
- Functions without tests
- Low coverage functions (< 80%)
- Missing test files
- Suggests test cases (happy path, errors, edge cases)

## What It Doesn't Check

**Security issues** - Use `/audit` for:
- IDOR vulnerabilities
- Authorization bypasses
- Sensitive data logging
- Missing security headers

## Requirements

### Required
- Git repository
- Go code changes vs main branch

### Optional (Recommended)
- `golangci-lint` installed for comprehensive linting
  ```bash
  # Install golangci-lint
  brew install golangci-lint
  # or
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  ```

Without golangci-lint, the skill still works but uses basic `go vet` only.

## How It Works

1. **Discovery**: Finds all Go files changed in your branch
2. **Linting**: Runs golangci-lint on changed files
3. **Bug Detection**: Analyzes code for common Go bug patterns
4. **Performance Analysis**: Identifies inefficient code patterns
5. **Test Coverage**: Checks for missing or insufficient tests
6. **CLAUDE.md**: Validates against codebase guidelines (if exists)
7. **Report**: Generates comprehensive markdown report
8. **Action**: Asks if you want to fix HIGH priority issues

## Report Format

```markdown
# Code Review Report - Go

## Summary
- HIGH: 2 issues
- MEDIUM: 3 issues
- Linting: 5 issues

## Detailed Findings

### Issue 1: Unchecked Error Return
File: `service.go:42-45`
Severity: HIGH
Confidence: 95/100

[Description, code snippet, recommendation]

## Test Coverage
- ❌ new_feature.go - 0% coverage
- ⚠️ handler.go - 45% coverage

[Suggested test cases]
```

## Confidence & Filtering

- **Only reports issues with confidence >= 80/100**
- Filters out pre-existing bugs (not in your changes)
- Excludes pedantic nitpicks
- Focuses on actionable, high-impact issues

## Severity Levels

### HIGH
- Critical bugs (nil pointers, goroutine leaks)
- Unchecked errors from golangci-lint
- Missing tests for new functions
- CLAUDE.md violations

### MEDIUM
- Performance issues
- Code simplification opportunities
- Unused code
- Coverage < 80% for modified functions

### LOW (not reported)
- Style/formatting (auto-fixable)
- Minor inefficiencies
- Pedantic suggestions

## Examples

### Example 1: Basic Review
```bash
$ /go-code-review

# Code Review Report - Go
Branch: feature/new-endpoint
Files Reviewed: 3 Go files, 2 test files

## Summary
- HIGH: 1 issue
- MEDIUM: 2 issues

### Issue 1: Nil Pointer Dereference
File: `service/handler.go:42`
Severity: HIGH

The function dereferences `user` without nil check...
[Fix provided]
```

### Example 2: With Fixes
```bash
$ /go-code-review

[Report shows 2 HIGH issues]

Found 2 HIGH priority issues. Would you like me to fix them?

$ yes

✓ Fixed nil pointer check in handler.go:42
✓ Added error handling in client.go:58

All HIGH issues resolved!
```

## Integration

### Pre-commit Hook
```bash
# .git/hooks/pre-commit
#!/bin/bash
/path/to/claude code-review-go
```

### CI/CD
```yaml
# .github/workflows/code-review.yml
- name: Code Review
  run: |
    claude code-review-go
```

## CLAUDE.md Support

If your repository has `CLAUDE.md` files, the skill will:
1. Find CLAUDE.md in repo root
2. Find CLAUDE.md in directories with changed files
3. Check compliance with instructions
4. Report violations with references

Example CLAUDE.md:
```markdown
# Code Guidelines

- Always use context.Context as first parameter
- Error messages must start with lowercase
- Use dependency injection for all services
```

The skill will verify your changes follow these rules.

## Common Issues Detected

### Bug: Unchecked Error
```go
// BAD - Error ignored
result, _ := fetchData()

// GOOD - Error handled
result, err := fetchData()
if err != nil {
    return nil, err
}
```

### Bug: Goroutine Leak
```go
// BAD - Can't be cancelled
go func() {
    for {
        process()
    }
}()

// GOOD - Respects context
go func() {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            process()
        }
    }
}()
```

### Performance: String Concatenation
```go
// BAD - O(n²) allocations
var s string
for _, item := range items {
    s += item
}

// GOOD - O(n) with Builder
var b strings.Builder
for _, item := range items {
    b.WriteString(item)
}
s := b.String()
```

### Test Coverage: Missing Tests
```go
// New function added
func ProcessOrder(order *Order) error {
    // ... complex logic ...
}

// No test file found!
// Skill suggests creating: order_test.go
```

## Comparison: `/audit` vs `/go-code-review`

| Feature | /audit | /go-code-review |
|---------|--------|-----------------|
| **Focus** | Security | Code Quality |
| **Detects** | IDOR, auth bypass, logging | Bugs, performance, tests |
| **Scope** | Specific lambda | All changed files |
| **Linting** | No | Yes (golangci-lint) |
| **Tests** | No | Yes (coverage check) |
| **When** | Security review | Code review |

**Use both for comprehensive review!**

## Tips

### Best Practices
1. Run `/go-code-review` before committing
2. Address HIGH issues before pushing
3. Fix MEDIUM issues when time allows
4. Use golangci-lint for best results
5. Write tests before removing "0% coverage" warnings

### Performance
- Fast for small changes (< 10 files)
- May take 1-2 minutes for large changesets
- Linting is the slowest part (can be skipped if needed)

### Limitations
- Only checks changed files (not entire codebase)
- Requires local Git history
- golangci-lint must be configured in repo
- Test coverage requires ability to run tests

## Customization

Want to customize checks? Edit the SKILL.md file:
```bash
~/.claude/skills/go-code-review/SKILL.md
```

Add your own patterns, adjust confidence thresholds, or modify report format.

## Troubleshooting

**"golangci-lint not found"**
- Install: `brew install golangci-lint`
- Or skill will fall back to `go vet`

**"No main branch"**
- Skill also checks for `master` branch
- Or specify: `git diff origin/develop...HEAD`

**"No Go files changed"**
- You're on main branch or no .go files modified
- Make changes and try again

## Support

For issues or enhancements:
1. Check SKILL.md for customization options
2. Review references/go-patterns.md for detected patterns
3. See examples/ for issue examples
