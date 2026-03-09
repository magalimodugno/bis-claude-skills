# Go Bug Patterns & Best Practices

Comprehensive guide to common Go bugs, anti-patterns, and their fixes.

## 1. Nil Pointer Issues

### Pattern: Nil Dereference
```go
// VULNERABLE
func GetUserName(user *User) string {
    return user.Name  // Panics if user is nil
}

// SAFE
func GetUserName(user *User) string {
    if user == nil {
        return ""
    }
    return user.Name
}

// BETTER - Return error
func GetUserName(user *User) (string, error) {
    if user == nil {
        return "", errors.New("user is nil")
    }
    return user.Name, nil
}
```

### Pattern: Nil Map Assignment
```go
// VULNERABLE
var m map[string]int
m["key"] = 42  // Panics - map is nil

// SAFE
m := make(map[string]int)
m["key"] = 42
```

### Pattern: Nil Slice vs Empty Slice
```go
// Different behaviors
var nilSlice []int        // nil
emptySlice := []int{}     // not nil, len=0

// Use nil for "not set", empty for "set but empty"
func GetItems() []int {
    if noItems {
        return nil  // Indicates "no items available"
    }
    return []int{}  // Indicates "items available but empty"
}
```

## 2. Error Handling

### Pattern: Ignored Errors
```go
// BAD
result, _ := doSomething()  // Error ignored

// GOOD
result, err := doSomething()
if err != nil {
    return nil, fmt.Errorf("failed to do something: %w", err)
}
```

### Pattern: Error Wrapping (Go 1.13+)
```go
// BAD - Lost context
if err != nil {
    return errors.New("failed")
}

// GOOD - Wrapped with context
if err != nil {
    return fmt.Errorf("process user %s: %w", userID, err)
}

// Can unwrap later
if errors.Is(err, ErrNotFound) {
    // Handle specific error
}
```

### Pattern: Sentinel Errors
```go
// Define sentinel errors
var (
    ErrNotFound = errors.New("not found")
    ErrInvalid  = errors.New("invalid input")
)

// Use errors.Is for comparison
if errors.Is(err, ErrNotFound) {
    // Handle not found
}

// NOT: err == ErrNotFound (doesn't work with wrapped errors)
```

### Pattern: Error Types
```go
// Custom error type
type ValidationError struct {
    Field string
    Issue string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Issue)
}

// Check with errors.As
var validErr *ValidationError
if errors.As(err, &validErr) {
    log.Printf("Validation failed on %s", validErr.Field)
}
```

## 3. Concurrency Issues

### Pattern: Goroutine Leaks
```go
// BAD - Goroutine never stops
func startWorker() {
    go func() {
        for {
            work := <-workCh
            process(work)
        }
    }()
}

// GOOD - Can be cancelled
func startWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case work := <-workCh:
                process(work)
            case <-ctx.Done():
                return
            }
        }
    }()
}
```

### Pattern: Race Conditions
```go
// BAD - Race condition
type Counter struct {
    value int
}

func (c *Counter) Increment() {
    c.value++  // Not atomic!
}

// GOOD - Use mutex
type Counter struct {
    mu    sync.Mutex
    value int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    c.value++
    c.mu.Unlock()
}

// BETTER - Use atomic
type Counter struct {
    value int64
}

func (c *Counter) Increment() {
    atomic.AddInt64(&c.value, 1)
}
```

### Pattern: Loop Variable Capture
```go
// BAD - All goroutines see final value
for _, item := range items {
    go func() {
        process(item)  // Wrong! All see last item
    }()
}

// GOOD - Pass as parameter
for _, item := range items {
    go func(i Item) {
        process(i)
    }(item)
}

// ALSO GOOD - Shadow variable (Go 1.22+)
for _, item := range items {
    item := item  // Shadows loop variable
    go func() {
        process(item)
    }()
}
```

### Pattern: WaitGroup Errors
```go
// BAD - WaitGroup passed by value
func worker(wg sync.WaitGroup) {
    defer wg.Done()  // Doesn't affect original WaitGroup!
}

// GOOD - Pass pointer
func worker(wg *sync.WaitGroup) {
    defer wg.Done()
}
```

### Pattern: Channel Closing
```go
// BAD - Close from receiver
go func() {
    for val := range ch {
        process(val)
    }
    close(ch)  // Wrong! Receiver shouldn't close
}()

// GOOD - Close from sender
go func() {
    for i := 0; i < 10; i++ {
        ch <- i
    }
    close(ch)  // Sender closes
}()
```

## 4. Defer Issues

### Pattern: Defer in Loop
```go
// BAD - All defers execute at function end
func processFiles(files []string) error {
    for _, file := range files {
        f, err := os.Open(file)
        if err != nil {
            return err
        }
        defer f.Close()  // Accumulates! Closes at function end
        process(f)
    }
    return nil
}

// GOOD - Defer in function scope
func processFiles(files []string) error {
    for _, file := range files {
        if err := processFile(file); err != nil {
            return err
        }
    }
    return nil
}

func processFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return err
    }
    defer f.Close()  // Closes at function end
    return process(f)
}

// ALSO GOOD - IIFE
func processFiles(files []string) error {
    for _, file := range files {
        func() {
            f, _ := os.Open(file)
            defer f.Close()  // Closes at IIFE end
            process(f)
        }()
    }
    return nil
}
```

### Pattern: Defer Evaluation
```go
// BAD - Arguments evaluated immediately
func process() error {
    defer log.Println("Processed:", getData())  // getData() called now!
    // ... rest of function
}

// GOOD - Use closure for late evaluation
func process() error {
    defer func() {
        log.Println("Processed:", getData())  // getData() called at defer time
    }()
    // ... rest of function
}
```

## 5. Slice & Map Issues

### Pattern: Slice Append
```go
// BAD - Doesn't modify caller's slice
func addItem(items []int, item int) {
    items = append(items, item)  // Creates new slice
}

// GOOD - Return new slice
func addItem(items []int, item int) []int {
    return append(items, item)
}

// ALSO GOOD - Use pointer (for large slices)
func addItem(items *[]int, item int) {
    *items = append(*items, item)
}
```

### Pattern: Slice Sharing
```go
// BAD - Slices share underlying array
original := []int{1, 2, 3, 4, 5}
slice1 := original[:2]  // [1, 2]
slice2 := original[2:]  // [3, 4, 5]
slice1[0] = 99  // Modifies original!

// GOOD - Copy if needed
slice1 := make([]int, 2)
copy(slice1, original[:2])
slice1[0] = 99  // Doesn't affect original
```

### Pattern: Nil vs Empty Map
```go
// Different behaviors
var nilMap map[string]int      // Reading OK, writing panics
emptyMap := map[string]int{}   // Both OK

// Read from nil map is OK
val := nilMap["key"]  // Returns zero value

// Write to nil map panics
nilMap["key"] = 42  // PANIC!

// Always initialize
m := make(map[string]int)
m["key"] = 42  // OK
```

## 6. Context Issues

### Pattern: Context Not Propagated
```go
// BAD - Can't be cancelled
func fetchData() (*Data, error) {
    resp, err := http.Get(url)  // No timeout/cancellation
    // ...
}

// GOOD - Accept context
func fetchData(ctx context.Context) (*Data, error) {
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    // ...
}
```

### Pattern: Context in Struct
```go
// BAD - Don't store context in struct
type Worker struct {
    ctx context.Context  // Anti-pattern!
}

// GOOD - Pass context to methods
type Worker struct {
    // other fields
}

func (w *Worker) Process(ctx context.Context, data Data) error {
    // Use ctx here
}
```

### Pattern: Passing nil Context
```go
// BAD
doWork(nil)  // nil context

// GOOD
doWork(context.Background())  // Non-nil context

// BETTER - Use specific context
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
doWork(ctx)
```

## 7. Performance Issues

### Pattern: String Concatenation
```go
// BAD - O(n²) time complexity
var result string
for _, s := range strings {
    result += s  // Creates new string each time
}

// GOOD - O(n) with strings.Builder
var builder strings.Builder
for _, s := range strings {
    builder.WriteString(s)
}
result := builder.String()
```

### Pattern: Unnecessary Allocations
```go
// BAD - Allocates every call
func getDefaults() []int {
    return []int{1, 2, 3}  // New allocation
}

// GOOD - Reuse allocation
var defaultValues = []int{1, 2, 3}

func getDefaults() []int {
    return defaultValues
}
```

### Pattern: Large Struct Copies
```go
// BAD - Copies entire struct
type LargeData struct {
    buffer [1024]byte
    // ... more fields
}

func process(data LargeData) {  // Copy!
    // ...
}

// GOOD - Use pointer
func process(data *LargeData) {
    // ...
}
```

### Pattern: Map Growth
```go
// BAD - Map grows dynamically
m := make(map[string]int)
for i := 0; i < 10000; i++ {
    m[fmt.Sprintf("key%d", i)] = i
}

// GOOD - Pre-allocate with capacity
m := make(map[string]int, 10000)
for i := 0; i < 10000; i++ {
    m[fmt.Sprintf("key%d", i)] = i
}
```

## 8. HTTP & JSON Issues

### Pattern: Missing Context in HTTP
```go
// BAD - No timeout
resp, err := http.Get(url)

// GOOD - With context and timeout
ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
defer cancel()

req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
resp, err := http.DefaultClient.Do(req)
```

### Pattern: JSON Marshal/Unmarshal
```go
// BAD - Marshal then Unmarshal
bytes, _ := json.Marshal(source)
json.Unmarshal(bytes, &target)

// GOOD - Direct assignment or mapstructure
target = convertDirectly(source)
```

### Pattern: Response Body Close
```go
// BAD - Body not closed
resp, err := http.Get(url)
body, _ := io.ReadAll(resp.Body)

// GOOD - Always close body
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
body, _ := io.ReadAll(resp.Body)
```

## 9. Testing Issues

### Pattern: Table Tests
```go
// GOOD - Use table-driven tests
func TestAdd(t *testing.T) {
    tests := []struct {
        name    string
        a, b    int
        want    int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

### Pattern: Test Helpers
```go
// Mark test helpers with t.Helper()
func assertEqual(t *testing.T, got, want interface{}) {
    t.Helper()  // Makes error show caller's line
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}
```

## 10. Error Messages

### Pattern: Error Message Format
```go
// BAD - Capitalized, punctuation
return errors.New("Failed to connect.")

// GOOD - Lowercase, no punctuation
return errors.New("failed to connect")

// GOOD - With context
return fmt.Errorf("failed to connect to %s: %w", host, err)
```

## Confidence Levels for Detection

- **100%**: Linter catches it (errcheck, govet, staticcheck)
- **95%**: Clear bug pattern (nil dereference without check)
- **90%**: Common anti-pattern (goroutine without context)
- **85%**: Performance issue (string concat in loop)
- **80%**: Missing best practice (defer in loop)
- **< 80%**: Don't report (too subjective)
