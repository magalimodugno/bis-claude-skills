# Go Test Coverage Skill

A Claude Code skill for Go testing that builds code, fixes errors, runs tests with coverage, adds missing tests to achieve full coverage using table-driven patterns with Given/When/Then nomenclature, and displays results in the terminal.

## What This Skill Does

When you say "test this branch" or invoke `/go-test-coverage`, Claude will:

1. **Build the project** - Compile all packages and fix build errors (with your approval)
2. **Run tests with coverage** - Execute the test suite with coverage analysis
3. **Fix failing tests** - Fix any broken tests (with your approval)
4. **Add missing tests** - Write table-driven tests with Given/When/Then naming to improve coverage
5. **Display results** - Show coverage by package and overall coverage in the terminal

## Features

✅ Build verification and error fixing
✅ Test execution with coverage analysis
✅ Automatic test generation for uncovered code
✅ Table-driven tests with Given/When/Then nomenclature
✅ Clean terminal output only
✅ No report files created

## Usage

### Automatic Invocation

Just say:
- "test this branch"

Claude will automatically invoke this skill.

### Manual Invocation

```
/go-test-coverage
```

## Test Pattern

All tests added by this skill follow the **Given/When/Then** nomenclature:

```
"Given [initial condition] when [action] then [expected outcome]"
```

Examples:
- `"Given valid user ID when fetching user then returns user data"`
- `"Given invalid input when processing then returns validation error"`
- `"Given empty database when querying then returns empty list"`

## Table-Driven Test Structure

Tests are structured as table-driven tests:

```go
func TestFunctionName(t *testing.T) {
    tests := []struct {
        name    string
        input   InputType
        want    OutputType
        wantErr bool
    }{
        {
            name:    "Given valid input when processing then returns success",
            input:   validInput,
            want:    expectedOutput,
            wantErr: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

## Output

The skill displays in the chat:
1. Build status
2. Initial coverage
3. Tests added (count and names)
4. Final coverage
5. Summary of improvements

**No files are created** - just terminal output and chat summary.

## Requirements

- Go 1.16 or later
- Project must have a `go.mod` file
- Run from the project root directory

## Tips

1. **Review changes** - Claude will ask before fixing build errors or failing tests
2. **Iterative improvement** - Run multiple times to progressively improve coverage
3. **Focus on critical paths** - Claude prioritizes business logic over boilerplate

## Troubleshooting

**Skill not triggering automatically?**
- Try saying "test this branch" explicitly
- Or invoke manually with `/go-test-coverage`

**Build failing?**
- The skill will ask if you want to fix build errors
- You can also fix them manually first

**Tests not being added?**
- Claude only adds tests for uncovered code (< 100%)
- main() functions are excluded as they're typically not testable

---

Created for comprehensive Go testing with Claude Code