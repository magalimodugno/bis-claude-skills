---
name: code-review-go
description: Comprehensive Go code review for bugs, formatting issues, performance problems, and test coverage. Use when user asks to "code review", "review code", "check my code", "review changes", or mentions code quality concerns for Go code.
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Go Code Review Skill

Performs comprehensive code quality review on Go code changes in the current branch against main, detecting bugs, formatting issues, performance problems, and test coverage gaps.

## Overview

This skill analyzes your local Git changes and provides actionable feedback on:
1. **Bugs**: Logic errors, nil pointers, error handling issues
2. **Formatting & Style**: Via golangci-lint
3. **Performance Issues**: Inefficient loops, unnecessary allocations, poor patterns
4. **Test Coverage**: Missing tests, uncovered code paths

**NOT covered by this skill**: Security issues (use `/audit` for IDOR, auth bypass, sensitive logging, etc.)

## Target

Reviews all Go files modified or added in the current branch compared to main.

## Phase 1: Discovery & Setup

### 1.1 Verify Repository State

```bash
# Get repository root
cd $(git rev-parse --show-toplevel)

# Verify we're in a Git repository
git status

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Reviewing branch: $CURRENT_BRANCH"

# Verify main branch exists
git rev-parse --verify main >/dev/null 2>&1 || git rev-parse --verify master >/dev/null 2>&1
```

### 1.2 Identify Changed Files

```bash
# Get all Go files changed between main and current branch
git diff main...HEAD --name-only --diff-filter=ACMR | grep '\.go$' | grep -v '_test\.go$'

# Get all new Go test files
git diff main...HEAD --name-only --diff-filter=ACMR | grep '_test\.go$'
```

Store results in variables:
- `CHANGED_GO_FILES`: Non-test Go files
- `CHANGED_TEST_FILES`: Test files

If no Go files changed, exit with message: "No Go files modified in this branch."

### 1.3 Find CLAUDE.md Files

Search for CLAUDE.md files in:
1. Repository root: `CLAUDE.md`
2. Each directory containing changed files

```bash
# For each changed file, check if CLAUDE.md exists in that directory
for file in $CHANGED_GO_FILES; do
    dir=$(dirname "$file")
    if [ -f "$dir/CLAUDE.md" ]; then
        echo "$dir/CLAUDE.md"
    fi
done | sort -u
```

Store paths to all found CLAUDE.md files for later reference.

## Phase 2: Linting & Formatting Check

### 2.1 Run golangci-lint

Check if golangci-lint is installed:
```bash
which golangci-lint || echo "golangci-lint not found"
```

If not installed, provide installation instructions but continue with other checks.

If installed, run on changed files:
```bash
# Run golangci-lint on changed files only
golangci-lint run --new-from-rev=main --out-format=json $(echo $CHANGED_GO_FILES | tr '\n' ' ')
```

**Parse linter output** and categorize issues:
- **HIGH**: `errcheck`, `govet`, `staticcheck` issues
- **MEDIUM**: `ineffassign`, `gosimple`, `unused`
- **LOW**: Formatting, style issues

**Filter**: Only report issues with confidence >= 8/10

### 2.2 Manual Formatting Check (if golangci-lint unavailable)

```bash
# Check gofmt
gofmt -l $(echo $CHANGED_GO_FILES | tr '\n' ' ')

# Check go vet
go vet ./...
```

## Phase 3: Bug Detection

For each changed Go file, analyze for common bugs:

### 3.1 Read Changed Code

```bash
# Get the actual diff with context
git diff main...HEAD -- <file>
```

Use Read tool to get the full current version of each changed file.

### 3.2 Common Go Bug Patterns

**Check for these patterns:**

#### 1. Nil Pointer Dereferences
```go
// BAD - Potential nil pointer dereference
func process(data *Data) {
    result := data.Field  // What if data is nil?
}

// GOOD - Check for nil first
func process(data *Data) {
    if data == nil {
        return errors.New("data is nil")
    }
    result := data.Field
}
```

#### 2. Unchecked Error Returns
```go
// BAD - Error ignored
result, _ := doSomething()

// GOOD - Error handled
result, err := doSomething()
if err != nil {
    return err
}
```

#### 3. Goroutine Leaks
```go
// BAD - Goroutine may leak
go func() {
    for {
        select {
        case <-ch:
            process()
        }
    }
}()

// GOOD - Can be cancelled
go func() {
    for {
        select {
        case <-ch:
            process()
        case <-ctx.Done():
            return
        }
    }
}()
```

#### 4. Race Conditions
```go
// BAD - Race condition
var counter int
go func() { counter++ }()
go func() { counter++ }()

// GOOD - Use mutex or atomic
var counter int32
go func() { atomic.AddInt32(&counter, 1) }()
go func() { atomic.AddInt32(&counter, 1) }()
```

#### 5. Incorrect Defer Usage
```go
// BAD - Defer in loop (defers pile up)
for _, file := range files {
    f, _ := os.Open(file)
    defer f.Close()  // All close at function end, not loop iteration end
    process(f)
}

// GOOD - Close in same iteration
for _, file := range files {
    func() {
        f, _ := os.Open(file)
        defer f.Close()
        process(f)
    }()
}
```

#### 6. Range Loop Variable Capture
```go
// BAD - Loop variable captured incorrectly
for _, item := range items {
    go func() {
        process(item)  // Wrong! All goroutines see last item
    }()
}

// GOOD - Pass as parameter
for _, item := range items {
    go func(i Item) {
        process(i)
    }(item)
}
```

#### 7. Slice Append Issues
```go
// BAD - May lose data if slice reallocates
func addItem(items []int, item int) {
    items = append(items, item)  // Doesn't modify caller's slice
}

// GOOD - Return the slice or use pointer
func addItem(items []int, item int) []int {
    return append(items, item)
}
```

#### 8. Context Not Propagated
```go
// BAD - Context not passed through
func doWork() error {
    result := callAPI()  // Can't be cancelled
    return result
}

// GOOD - Context propagated
func doWork(ctx context.Context) error {
    result := callAPI(ctx)
    return result
}
```

### 3.3 Analysis Process

For each changed file:
1. Read the git diff to see what changed
2. Read the full file to understand context
3. Search for the bug patterns above
4. Check if the change introduced the bug or fixed it
5. Verify the bug is in **modified lines** (not pre-existing)

**Important**: Only report bugs in lines that were added or modified in this branch.

## Phase 4: Performance Analysis

### 4.1 Common Performance Issues

#### 1. String Concatenation in Loops
```go
// BAD - Inefficient string concatenation
var result string
for _, s := range items {
    result += s  // Creates new string each iteration
}

// GOOD - Use strings.Builder
var builder strings.Builder
for _, s := range items {
    builder.WriteString(s)
}
result := builder.String()
```

#### 2. Unnecessary Allocations
```go
// BAD - Allocates new slice every time
func process() []int {
    return []int{1, 2, 3}
}

// GOOD - Reuse or return reference to pre-allocated
var defaultValues = []int{1, 2, 3}
func process() []int {
    return defaultValues
}
```

#### 3. Map Access in Loops
```go
// BAD - Multiple map lookups
for key := range keys {
    if myMap[key] != nil {
        value := myMap[key].Field  // Two lookups
    }
}

// GOOD - Single lookup
for key := range keys {
    if value, ok := myMap[key]; ok && value != nil {
        field := value.Field
    }
}
```

#### 4. Large Data Copies
```go
// BAD - Copies large struct
func process(data LargeStruct) {  // Copies entire struct
    // ...
}

// GOOD - Use pointer
func process(data *LargeStruct) {
    // ...
}
```

#### 5. Inefficient JSON Marshaling
```go
// BAD - Marshal then unmarshal
bytes, _ := json.Marshal(obj)
json.Unmarshal(bytes, &target)

// GOOD - Direct copy or use mapstructure
```

### 4.2 Benchmarking Hints

If performance-critical code changed, suggest:
```go
// Add benchmark test
func BenchmarkFunction(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Function()
    }
}
```

## Phase 5: Test Coverage Analysis

### 5.1 Identify Functions Without Tests

For each non-test Go file changed:
1. Extract all exported functions: `func (Type) Method()` or `func Function()`
2. Check if corresponding test file exists
3. Check if each function has tests

```bash
# Check if test file exists
if [ -f "${file%%.go}_test.go" ]; then
    # Test file exists, check coverage
    echo "Test file found"
else
    echo "No test file for $file"
fi
```

### 5.2 Coverage Analysis

If tests exist, check coverage:
```bash
# Run tests with coverage for the specific package
go test -cover ./path/to/package
```

Parse output and identify:
- Functions with 0% coverage (newly added)
- Functions with < 80% coverage
- Critical paths without tests (error handling, edge cases)

### 5.3 Suggest Missing Tests

For each uncovered function, suggest test cases:
- **Happy path**: Valid inputs, expected outputs
- **Error cases**: Invalid inputs, error handling
- **Edge cases**: nil values, empty slices, boundary conditions
- **Concurrency**: If function uses goroutines or channels

**Test Pattern**: Follow the codebase's existing test pattern (table-driven with Given/When/Then if using go-test-coverage skill)

## Phase 6: CLAUDE.md Compliance

If CLAUDE.md files were found in Phase 1:

### 6.1 Read Each CLAUDE.md

Use Read tool to read each CLAUDE.md file found.

### 6.2 Check Compliance

For each instruction in CLAUDE.md:
1. Determine if it applies to code review (not all instructions are relevant)
2. Check if changed code follows the instruction
3. Report violations with reference to specific CLAUDE.md instruction

**Example checks:**
- "Always use context.Context as first parameter" → Check function signatures
- "Error messages must start with lowercase" → Check error strings
- "Use dependency injection" → Check constructor patterns

## Phase 7: Confidence Scoring & Filtering

For each issue found, assign confidence score (0-100):

### Confidence Scale

- **100**: Absolutely certain (linter caught it, obvious bug in diff)
- **90-99**: Very high confidence (clear bug pattern, verified in code)
- **80-89**: High confidence (likely bug, matches known pattern)
- **70-79**: Moderate confidence (suspicious but not certain)
- **< 70**: Low confidence (DO NOT REPORT)

### Filter Issues

**Only report issues with confidence >= 80**

### False Positive Exclusions

DO NOT report:
- ❌ Issues in lines not modified by this branch
- ❌ Pre-existing bugs (use git blame to verify)
- ❌ Style issues not flagged by golangci-lint
- ❌ Test coverage issues for unchanged functions
- ❌ Pedantic nitpicks
- ❌ Issues that would be caught by compiler/typechecker
- ❌ General code quality issues not in CLAUDE.md

## Phase 8: Generate Report

### Report Format

```markdown
# Code Review Report - Go

**Branch**: <branch-name>
**Base**: main
**Files Reviewed**: X Go files, Y test files
**Review Date**: YYYY-MM-DD

---

## Summary

- **HIGH**: X issues
- **MEDIUM**: Y issues
- **Linting**: Z issues from golangci-lint

---

## Detailed Findings

### High Priority Issues

#### Issue 1: [Category] - [Brief Description]

**File**: `path/to/file.go:42-45`

**Severity**: HIGH
**Confidence**: 95/100
**Category**: bug | performance | test_coverage | linting

**Description**:
[Detailed description of the issue]

**Code**:
```go
// Current code (problematic)
[code snippet]
```

**Problem**:
[Explain why this is an issue]

**Recommendation**:
```go
// Suggested fix
[fixed code snippet]
```

**Reference**: [If from CLAUDE.md: link to CLAUDE.md and quote instruction]

---

[Repeat for each HIGH issue]

### Medium Priority Issues

[Same format for MEDIUM issues]

---

## Linting Results

golangci-lint found X issues:

1. **errcheck** in `file.go:10` - Error return value not checked
2. **govet** in `file.go:25` - Suspicious comparison
[etc.]

---

## Test Coverage Analysis

### Files Without Tests
- ❌ `pkg/service/new_feature.go` - 0% coverage
- ⚠️ `internal/handler/endpoint.go` - 45% coverage

### Recommended Test Cases

**For `pkg/service/new_feature.go:ProcessData()`:**
```go
func TestProcessData(t *testing.T) {
    tests := []struct {
        name    string
        input   Data
        want    Result
        wantErr bool
    }{
        {
            name:    "Given valid data when processing then returns success",
            input:   validData,
            want:    expectedResult,
            wantErr: false,
        },
        {
            name:    "Given nil data when processing then returns error",
            input:   nil,
            want:    nil,
            wantErr: true,
        },
    }
    // ... test implementation
}
```

---

## CLAUDE.md Compliance

[If CLAUDE.md exists and violations found]

**Violations of `/path/to/CLAUDE.md`:**

1. Line 42: Function signature doesn't follow pattern (CLAUDE.md says: "Always use context.Context as first parameter")
2. Line 55: Error message capitalized (CLAUDE.md says: "Error messages must start lowercase")

---

## Summary & Recommendations

### Critical Actions Required
1. [Action 1]
2. [Action 2]

### Optional Improvements
1. [Improvement 1]
2. [Improvement 2]

### Stats
- **Code Quality Score**: X/100
- **Test Coverage**: Y%
- **Linter Compliance**: Z%
```

## Phase 9: Interactive Follow-up

After displaying the report:

1. **If HIGH issues found**: Ask user if they want you to fix them
   ```
   Found X HIGH priority issues. Would you like me to fix them?
   ```

2. **If test coverage gaps**: Ask if they want you to generate test stubs
   ```
   Found Y functions without tests. Would you like me to generate test templates?
   ```

3. **If linting issues**: Ask if they want you to run auto-fixes
   ```
   golangci-lint can auto-fix Z issues. Run fixes? (this will modify files)
   ```

## Usage Examples

**Review current branch:**
```
User: /code-review-go
```

**Review and fix:**
```
User: /code-review-go
Assistant: [Shows report with 3 HIGH issues]
Assistant: Found 3 HIGH priority issues. Would you like me to fix them?
User: yes
Assistant: [Fixes the issues]
```

## Notes

- This skill focuses on **code quality**, not security
- For security issues (IDOR, auth bypass, etc.), use `/audit`
- Only analyzes code changes (git diff), not entire codebase
- Requires golangci-lint for best results (but works without it)
- Test coverage analysis requires ability to run `go test -cover`
- Always verifies issues are in modified lines, not pre-existing
