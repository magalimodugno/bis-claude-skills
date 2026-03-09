---
name: audit
description: Comprehensive security audit for IDOR vulnerabilities, authorization bypasses, sensitive data logging, and missing security headers. Use when user asks to "audit", "security audit", "check for vulnerabilities", "security review", or mentions security concerns.
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Write, Glob, Grep, Task
---

# Security Audit Skill

Performs comprehensive security audits on Go Lambda functions to detect IDOR vulnerabilities, authorization bypasses, sensitive data logging, and missing security headers.

## Overview

This skill systematically analyzes Lambda functions for common security vulnerabilities by:
1. Comparing against known-good security patterns in the codebase
2. Identifying deviations from established security controls
3. Flagging missing authorization checks
4. Detecting sensitive data exposure

## Target

If the user specifies a lambda/directory, audit that specific target. Otherwise, audit all lambdas in `lambdas/go/`.

## Phase 1: Discovery & Baseline Analysis

### 1.1 Discover All Lambdas

```bash
# Find all lambda directories
ls -d lambdas/go/*-lambda/
```

### 1.2 Identify Known-Good Security Patterns

Read these reference implementations that follow security best practices:

**Authorization Pattern Examples:**
- `lambdas/go/bff-delete-resource-lambda/internal/service/service.go` (lines 51-67)
- `lambdas/go/bff-get-data-lambda/internal/service/http.go` (line 33)
- `lambdas/go/bff-list-items-lambda/internal/service/service.go` (lines 41-57)

**Key Security Patterns to Verify:**
1. ✅ Services have `AuthService auth.Client` in their struct
2. ✅ HTTP handlers call `r.Context()` to extract auth context
3. ✅ Ownership validation via `validateOwnership(ctx, resourceID)` or `ValidateUserAuthorization(ctx, resourceID)`
4. ✅ Validation happens BEFORE calling backend services
5. ✅ Path parameters (resource_id, account_id, item_id) are used for auth checks

## Phase 2: Security Checks

For each lambda, perform these checks:

### Check 1: IDOR Detection

**What to look for:**
- Endpoints that accept resource identifiers (organization_id, resource_id, item_id, user_id)
- Missing ownership validation before accessing resources
- Path parameters that are extracted but never validated

**Steps:**
1. Use Glob to find HTTP handler files: `**/internal/service/http.go`
2. Read each http.go file
3. Identify all endpoints and their path parameters
4. Check if authorization validation exists before resource access
5. Verify path parameters are actually used (not ignored)

**Red Flags:**
- ❌ Endpoint accepts ID parameter but has no `validateOwnership()` call
- ❌ Service struct missing `AuthService` client
- ❌ Context not extracted with `r.Context()`
- ❌ Path parameter extracted but never referenced in validation

**Example Vulnerability Pattern:**
```go
// VULNERABLE - No ownership check!
func (s *Service) GetResourceHTTP(w http.ResponseWriter, r *http.Request) {
    resourceID := r.PathValue("resource_id")
    // Direct call to backend without validation
    response, err := s.BackendClient.GetResource(resourceID)
}
```

**Secure Pattern:**
```go
// SECURE - Ownership validated
func (s *Service) GetResourceHTTP(w http.ResponseWriter, r *http.Request) {
    resourceID := r.PathValue("resource_id")

    // Validate ownership BEFORE accessing resource
    if err := s.validateOwnership(r.Context(), resourceID); err != nil {
        // Return 403 Forbidden
        return
    }

    response, err := s.BackendClient.GetResource(resourceID)
}
```

### Check 2: Auth Bypass Detection

**What to look for:**
- Missing context propagation through service layers
- Services without AuthService client
- Endpoints that don't extract or use authentication context
- Missing authorization middleware

**Steps:**
1. Use Glob to find service files: `**/internal/service/service.go`
2. Read each service.go file
3. Check if Service struct includes `AuthService auth.Client`
4. Verify methods accept and use `context.Context` as first parameter
5. Look for `validateOwnership` or `ValidateUserAuthorization` functions

**Red Flags:**
- ❌ Service struct has no `AuthService` field
- ❌ Service methods don't accept `context.Context`
- ❌ No `validateOwnership()` function exists
- ❌ Context passed to service but never used

**Required Service Structure:**
```go
type Service struct {
    BackendClient    client.Client
    AuthService      auth.Client  // REQUIRED for auth
}

func (s *Service) validateOwnership(ctx context.Context, resourceID string) error {
    userID, err := s.AuthService.GetAuthUser(ctx)
    if err != nil {
        return ErrGetAuthUser
    }

    resource, err := s.AuthService.GetUserResource(userID, resourceID)
    if err != nil {
        return ErrGetResource
    }

    if resource == nil || !resource.HasAccess {
        return ErrAccessDenied
    }

    return nil
}
```

### Check 3: Sensitive Data Logging

**What to look for:**
- Logging of PII: names, emails, tax_ids, phone numbers
- Logging of secrets: passwords, tokens, api_keys
- Logging of full response bodies from backend services
- Logging of account numbers, transaction details, financial data

**Steps:**
1. Use Grep to find all logging statements: `ulog.With|ulog.Info|ulog.Error|ulog.Debug`
2. Read surrounding context for each logging statement
3. Identify what data is being logged
4. Check against sensitive field list

**Sensitive Fields (DO NOT LOG):**
- `password`, `secret`, `token`, `api_key`, `bearer`
- `tax_id`, `ssn`, `ein`
- `email` (in most contexts)
- `account_number` (if contains PII)
- Full response bodies (may contain any of the above)

**Red Flags:**
- ❌ `ulog.Str("password", ...)` or `ulog.Str("token", ...)`
- ❌ `ulog.Str("Body", string(responseBytes))` on success responses
- ❌ Logging struct fields that contain PII without redaction

**Safe Logging Pattern:**
```go
// UNSAFE
ulog.With(ulog.Str("Body", string(responseBytes))).Info("API response")

// SAFE - Only log status codes and error indicators
ulog.With(ulog.Int("StatusCode", statusCode)).Info("API request completed")
```

**Exception:** Logging error response bodies (non-200 responses) is generally safe as they contain error messages, not sensitive data.

### Check 4: Missing Security Headers

**What to look for:**
- Missing Content-Type validation on incoming requests
- Missing MaxBytesReader to limit request body size
- Missing Authorization header propagation to backend services
- Missing security response headers

**Steps:**
1. Read HTTP handler files
2. Check for `http.MaxBytesReader` usage
3. Verify Content-Type is validated for POST/PUT requests
4. Check if clients pass Authorization headers to backends

**Red Flags:**
- ❌ No `http.MaxBytesReader` (allows unlimited request bodies)
- ❌ JSON decoder without size limit
- ❌ No Content-Type validation
- ❌ Backend HTTP clients don't include auth headers

**Secure Pattern:**
```go
// Limit request body size
r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
defer r.Body.Close()

// Validate Content-Type
if r.Header.Get("Content-Type") != "application/json" {
    // Return 415 Unsupported Media Type
}

// Set security response headers
w.Header().Set("Content-Type", "application/json")
w.Header().Set("X-Content-Type-Options", "nosniff")
```

## Phase 3: Comparative Analysis

Compare the target lambda against similar lambdas:

1. Find all lambdas with similar functionality (e.g., all "get-*" lambdas)
2. Identify which ones have proper security controls
3. Flag the target if it deviates from the secure pattern
4. Calculate "security score" based on controls present

**Example Comparison:**
```
Similar lambdas:
✅ bff-list-items-lambda: Has validateOwnership
✅ bff-get-data-lambda: Has ValidateUserAuthorization
❌ bff-example-service-lambda: NO authorization check ← VULNERABLE
```

## Phase 4: Generate Report

### Output Format

Create a markdown report with:

1. **Executive Summary**: Count of findings by severity
2. **Detailed Findings**: One section per vulnerability
3. **Comparison Analysis**: How target compares to secure lambdas
4. **Recommendations**: Prioritized action items

### Finding Template

For each vulnerability found:

```markdown
# Vuln N: [Category]: `file.go:line`

* **Severity**: HIGH|MEDIUM|LOW
* **Category**: idor|auth_bypass|sensitive_logging|missing_headers
* **Description**: Brief description of the issue
* **Exploit Scenario**: Concrete step-by-step attack scenario showing:
  1. Attacker's initial position (authenticated user)
  2. Actions they can take
  3. Data they can access
  4. Impact on other users/organizations
* **Recommendation**: Specific fix with code examples
* **Reference Implementation**: Point to similar lambda that does it correctly
```

### Severity Guidelines

**HIGH Severity:**
- Direct unauthorized access to other organizations' data
- Missing authorization checks on destructive operations
- Logging of passwords, tokens, or API keys
- Horizontal/vertical privilege escalation

**MEDIUM Severity:**
- Logging of PII (names, emails, tax IDs)
- Missing request size limits (potential for abuse)
- Incomplete authorization checks
- Information disclosure through error messages

**LOW Severity:**
- Missing security headers (defense-in-depth)
- Suboptimal error handling
- Logging sensitive business data (non-PII)

## Confidence Scoring & False Positive Filtering

**Only report findings with confidence ≥ 8/10**

### Hard Exclusions (DO NOT REPORT):
1. ❌ Denial of Service (DOS) vulnerabilities
2. ❌ Secrets stored on disk (handled separately)
3. ❌ Rate limiting concerns
4. ❌ Resource exhaustion issues
5. ❌ Test files (\_test.go)
6. ❌ Log spoofing / unsanitized input to logs
7. ❌ SSRF that only controls path (not host)
8. ❌ Regex injection
9. ❌ Outdated dependencies (managed separately)
10. ❌ Missing audit logs

### Precedents to Apply:
- ✅ UUIDs are unguessable UNLESS exposed through APIs
- ✅ Environment variables are trusted
- ✅ Error response bodies (non-200) generally safe to log
- ✅ Logging URLs is safe
- ⚠️ UUID unguessability is NOT a substitute for authorization

### Validation Questions:
Before reporting a finding, ask:
1. Is there a concrete exploitation path?
2. Can an authenticated user access data they shouldn't?
3. Is sensitive data actually exposed (not just hypothetically)?
4. Does this deviate from the codebase's security patterns?
5. Would this pass security review at other similar companies?

## Example Output

```markdown
# Security Audit Report - bff-example-service-lambda

**Audit Date**: 2026-03-08
**Audited By**: Claude Code Security Audit
**Target**: lambdas/go/bff-example-service-lambda

## Executive Summary

- **HIGH**: 2 findings
- **MEDIUM**: 0 findings
- **LOW**: 0 findings

## Detailed Findings

### Vuln 1: IDOR - Missing Authorization Check: `internal/service/http.go:20`

* **Severity**: HIGH
* **Category**: idor
* **Description**: The GetResourceHTTP endpoint accepts resource_id but performs no ownership validation
* **Exploit Scenario**:
  1. User A authenticates to Organization X
  2. User A guesses resource_id "123456" (belongs to Org Y)
  3. User A calls GET /resources/123456
  4. BFF validates format only, no auth check
  5. User A receives Org Y's resource data
* **Recommendation**: Add validateOwnership check before s.GetResource()
* **Reference**: See bff-delete-resource-lambda/internal/service/service.go:29

[Additional findings...]

## Comparison Analysis

| Lambda | AuthService Client | Context Usage | Auth Check | Security Score |
|--------|---------------------|---------------|------------|----------------|
| bff-list-items | ✅ | ✅ | ✅ | 100% |
| bff-get-data | ✅ | ✅ | ✅ | 100% |
| bff-delete-resource | ✅ | ✅ | ✅ | 100% |
| **bff-example-service** | ❌ | ❌ | ❌ | **0%** |

## Recommendations

1. **CRITICAL**: Add AuthService client to Service struct
2. **CRITICAL**: Implement validateOwnership function
3. **CRITICAL**: Call validateOwnership in all HTTP handlers before backend calls
4. Add comprehensive authorization tests
5. Document authorization model in README.md
```

## Usage Examples

**Audit a specific lambda:**
```
User: /audit bff-example-service-lambda
```

**Audit all lambdas:**
```
User: /audit
User: /audit lambdas/go/
```

**Audit with focus:**
```
User: /audit bff-service-a --idor-only
User: /audit bff-service-b --check-logging
```

## Post-Audit Actions

After generating the report:
1. Display the report to the user
2. Ask if they want you to fix the HIGH severity issues
3. If yes, offer to create a plan for remediation
4. Optionally create GitHub issues for tracking

## Notes

- This skill uses comparative analysis - it learns from secure lambdas in the codebase
- Always verify findings against established patterns before reporting
- Prioritize HIGH confidence findings over theoretical vulnerabilities
- When in doubt, compare to 3+ similar lambdas to establish pattern