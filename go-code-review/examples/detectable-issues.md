# Detectable Issues - Examples

Real-world examples of issues the code-review-go skill can detect.

## Example 1: Nil Pointer Dereference

### Code Submitted
```go
// File: pkg/user/service.go
func (s *Service) GetUserEmail(userID string) (string, error) {
    user, err := s.repo.FindByID(userID)
    if err != nil {
        return "", err
    }

    return user.Email, nil  // BUG: user might be nil even if err is nil
}
```

### Detection
```markdown
### Issue 1: Potential Nil Pointer Dereference

**File**: `pkg/user/service.go:7`
**Severity**: HIGH
**Confidence**: 90/100
**Category**: bug

**Description**:
The function dereferences `user.Email` without checking if `user` is nil.
If `repo.FindByID()` returns (nil, nil), this will panic.

**Code**:
```go
return user.Email, nil  // Potential panic
```

**Recommendation**:
```go
if user == nil {
    return "", fmt.Errorf("user %s not found", userID)
}
return user.Email, nil
```
```

## Example 2: Unchecked Error Return

### Code Submitted
```go
// File: internal/handler/http.go
func (h *Handler) ProcessRequest(w http.ResponseWriter, r *http.Request) {
    var req Request
    json.NewDecoder(r.Body).Decode(&req)  // Error ignored!

    result := h.service.Process(req)
    json.NewEncoder(w).Encode(result)
}
```

### Detection
```markdown
### Issue 2: Unchecked Error Return

**File**: `internal/handler/http.go:4`
**Severity**: HIGH
**Confidence**: 100/100 (caught by golangci-lint errcheck)
**Category**: linting

**Description**:
Error return value from `json.NewDecoder(r.Body).Decode(&req)` is not checked.
Invalid JSON will be silently ignored, leading to incorrect behavior.

**golangci-lint output**:
```
internal/handler/http.go:4:2: Error return value of `json.NewDecoder(r.Body).Decode` is not checked (errcheck)
```

**Recommendation**:
```go
if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
    http.Error(w, "invalid request body", http.StatusBadRequest)
    return
}
```
```

## Example 3: Goroutine Leak

### Code Submitted
```go
// File: pkg/worker/pool.go
func (p *Pool) Start() {
    for i := 0; i < p.size; i++ {
        go func() {
            for task := range p.taskCh {
                task.Execute()
            }
        }()
    }
}
```

### Detection
```markdown
### Issue 3: Goroutine Leak - No Cancellation

**File**: `pkg/worker/pool.go:3-8`
**Severity**: HIGH
**Confidence**: 85/100
**Category**: bug

**Description**:
Goroutines are started without any way to stop them. If `taskCh` is never closed
or if you want to gracefully shutdown, these goroutines will leak.

**Code**:
```go
go func() {
    for task := range p.taskCh {
        task.Execute()
    }
}()
```

**Recommendation**:
```go
func (p *Pool) Start(ctx context.Context) {
    for i := 0; i < p.size; i++ {
        go func() {
            for {
                select {
                case task := <-p.taskCh:
                    task.Execute()
                case <-ctx.Done():
                    return
                }
            }
        }()
    }
}
```
```

## Example 4: String Concatenation in Loop

### Code Submitted
```go
// File: pkg/report/generator.go
func (g *Generator) BuildReport(items []Item) string {
    var report string
    for _, item := range items {
        report += fmt.Sprintf("%s: %s\n", item.Name, item.Value)
    }
    return report
}
```

### Detection
```markdown
### Issue 4: Inefficient String Concatenation

**File**: `pkg/report/generator.go:3-5`
**Severity**: MEDIUM
**Confidence**: 90/100
**Category**: performance

**Description**:
String concatenation in a loop using `+=` creates a new string allocation
on each iteration. For large `items` slices, this is O(n²) time complexity.

**Performance Impact**:
- 100 items: ~50x slower than strings.Builder
- 1000 items: ~500x slower
- 10000 items: ~5000x slower

**Recommendation**:
```go
func (g *Generator) BuildReport(items []Item) string {
    var b strings.Builder
    for _, item := range items {
        fmt.Fprintf(&b, "%s: %s\n", item.Name, item.Value)
    }
    return b.String()
}
```
```

## Example 5: Range Loop Variable Capture

### Code Submitted
```go
// File: pkg/processor/batch.go
func (p *Processor) ProcessAll(items []Item) {
    for _, item := range items {
        go func() {
            p.process(item)  // BUG: Captures loop variable
        }()
    }
}
```

### Detection
```markdown
### Issue 5: Loop Variable Captured by Goroutine

**File**: `pkg/processor/batch.go:3-6`
**Severity**: HIGH
**Confidence**: 95/100
**Category**: bug

**Description**:
The goroutine captures the loop variable `item` by reference. All goroutines
will see the final value of `item` (the last item in the slice), not the
value from each iteration.

**Example Bug**:
```go
items := []Item{{ID: 1}, {ID: 2}, {ID: 3}}
ProcessAll(items)
// All goroutines process Item{ID: 3} three times!
```

**Recommendation**:
```go
for _, item := range items {
    go func(i Item) {  // Pass as parameter
        p.process(i)
    }(item)
}

// Or (Go 1.22+):
for _, item := range items {
    item := item  // Shadow variable
    go func() {
        p.process(item)
    }()
}
```
```

## Example 6: Missing Test Coverage

### Code Submitted
```go
// File: pkg/validator/rules.go (NEW FILE)
package validator

func ValidateEmail(email string) error {
    if email == "" {
        return errors.New("email is required")
    }
    if !strings.Contains(email, "@") {
        return errors.New("invalid email format")
    }
    return nil
}
```

### Detection
```markdown
### Issue 6: Missing Test Coverage

**File**: `pkg/validator/rules.go`
**Severity**: HIGH
**Confidence**: 100/100
**Category**: test_coverage

**Description**:
New file `rules.go` was added with exported function `ValidateEmail`,
but no corresponding test file `rules_test.go` exists.

**Coverage**: 0%

**Recommended Test Cases**:

```go
// File: pkg/validator/rules_test.go
package validator

import "testing"

func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {
            name:    "Given valid email when validating then returns no error",
            email:   "user@example.com",
            wantErr: false,
        },
        {
            name:    "Given empty email when validating then returns error",
            email:   "",
            wantErr: true,
        },
        {
            name:    "Given email without @ when validating then returns error",
            email:   "invalid-email",
            wantErr: true,
        },
        {
            name:    "Given email with multiple @ when validating then returns no error",
            email:   "user@@example.com",
            wantErr: false,  // Current implementation allows this
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail(%q) error = %v, wantErr %v", tt.email, err, tt.wantErr)
            }
        })
    }
}
```
```

## Example 7: Defer in Loop

### Code Submitted
```go
// File: pkg/file/processor.go
func (p *Processor) ProcessFiles(paths []string) error {
    for _, path := range paths {
        f, err := os.Open(path)
        if err != nil {
            return err
        }
        defer f.Close()  // BUG: Accumulates until function returns

        if err := p.process(f); err != nil {
            return err
        }
    }
    return nil
}
```

### Detection
```markdown
### Issue 7: Defer in Loop

**File**: `pkg/file/processor.go:5`
**Severity**: MEDIUM
**Confidence**: 85/100
**Category**: bug

**Description**:
`defer f.Close()` is called inside a loop, but defers execute at function return,
not loop iteration end. This means all files stay open until the entire function
completes, potentially causing "too many open files" errors.

**Problem**:
```go
// If processing 1000 files:
for i := 0; i < 1000; i++ {
    f, _ := os.Open(files[i])
    defer f.Close()  // All 1000 files stay open!
}
// All files close here (at function end)
```

**Recommendation**:

Option 1 - Extract to function:
```go
func (p *Processor) ProcessFiles(paths []string) error {
    for _, path := range paths {
        if err := p.processFile(path); err != nil {
            return err
        }
    }
    return nil
}

func (p *Processor) processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()  // Closes at this function's end
    return p.process(f)
}
```

Option 2 - IIFE:
```go
for _, path := range paths {
    if err := func() error {
        f, err := os.Open(path)
        if err != nil {
            return err
        }
        defer f.Close()
        return p.process(f)
    }(); err != nil {
        return err
    }
}
```
```

## Example 8: CLAUDE.md Violation

### CLAUDE.md Content
```markdown
# Code Guidelines

## Function Signatures

All service methods must accept `context.Context` as the first parameter
for proper cancellation and timeout support.

Example:
```go
func (s *Service) DoSomething(ctx context.Context, arg string) error
```
```

### Code Submitted
```go
// File: internal/service/operations.go
func (s *Service) CreateOrder(orderID string, items []Item) error {
    // ... implementation
}
```

### Detection
```markdown
### Issue 8: CLAUDE.md Violation - Missing Context Parameter

**File**: `internal/service/operations.go:2`
**Severity**: HIGH
**Confidence**: 100/100
**Category**: claude_md_violation

**Description**:
Function `CreateOrder` does not accept `context.Context` as first parameter,
violating the guideline in `/internal/service/CLAUDE.md`.

**CLAUDE.md says**:
> All service methods must accept `context.Context` as the first parameter
> for proper cancellation and timeout support.

**Current signature**:
```go
func (s *Service) CreateOrder(orderID string, items []Item) error
```

**Required signature**:
```go
func (s *Service) CreateOrder(ctx context.Context, orderID string, items []Item) error
```

**Reference**: [/internal/service/CLAUDE.md](link)
```

## Summary Statistics

From these examples:
- **3 HIGH severity bugs** (nil pointer, unchecked error, goroutine leak)
- **2 MEDIUM severity issues** (string concat, defer in loop)
- **1 HIGH test coverage** (missing tests)
- **1 HIGH CLAUDE.md violation** (missing context)
- **1 bug caught by linter** (errcheck)

All issues have confidence >= 80/100 and would be reported by `/code-review-go`.
