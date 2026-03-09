---
name: go-test-coverage
description: Build Go code, fix build errors, run tests with coverage, fix failing tests, add missing tests using table-driven patterns with Given/When/Then nomenclature, and display coverage results in terminal
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Go Test Coverage Workflow

Build, test, improve coverage with table-driven tests using Given/When/Then nomenclature, and display results in terminal. No report files created.

## Step 1: Build

```bash
go build ./...
```

If build fails:
- Show the errors to the user
- Ask if they want you to fix them
- If yes, fix the errors and rebuild

## Step 2: Run Tests with Coverage

```bash
go test -v -coverprofile=coverage.out ./...
```

If tests fail:
- Analyze the failures
- Ask the user if they want you to fix the failing tests
- If yes, fix them and re-run

## Step 3: Analyze Coverage Gaps

```bash
go tool cover -func=coverage.out
```

Identify functions with coverage < 100% (excluding main() functions which are typically not testable).

For each uncovered function:
- Read the function code
- Determine what test cases are needed
- Add table-driven tests with Given/When/Then nomenclature

## Table Test Pattern

Use this pattern for all new tests:

```go
func TestFunctionName(t *testing.T) {
	tests := []struct {
		name    string
		// Given - setup
		input   InputType
		// Then - expected
		want    OutputType
		wantErr bool
	}{
		{
			name:    "Given valid input when processing then returns success",
			input:   validInput,
			want:    expectedOutput,
			wantErr: false,
		},
		{
			name:    "Given invalid input when processing then returns error",
			input:   invalidInput,
			want:    nil,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When
			got, err := FunctionName(tt.input)

			// Then
			if (err != nil) != tt.wantErr {
				t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("got %v, want %v", got, tt.want)
			}
		})
	}
}
```

**Test naming:** Always use "Given [condition] when [action] then [outcome]"

## Step 4: Add Missing Tests

For each coverage gap:
1. Use Glob to find existing test files
2. Use Read to read the test file and the source file
3. Use Edit or Write to add new table-driven test cases
4. Ensure all test names follow Given/When/Then pattern

## Step 5: Re-run Tests

After adding tests:

```bash
go test -v -coverprofile=coverage.out ./...
```

## Step 6: Display Final Coverage

```bash
echo ""
echo "=== Coverage by Package ==="
go tool cover -func=coverage.out

echo ""
echo "=== Overall Coverage ==="
go tool cover -func=coverage.out | grep total
```

## Step 7: Clean Up

```bash
rm -f coverage.out
```

## Output

Display in the chat:
1. Build status
2. Initial coverage
3. Tests added (count and names with Given/When/Then pattern)
4. Final coverage
5. Summary of improvements

No report files created. Just terminal output and chat summary.