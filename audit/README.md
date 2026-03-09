# Security Audit Skill

Comprehensive security auditing for Go Lambda functions.

## Quick Start

```bash
# Audit specific lambda
/audit bff-get-transactions-aws-lambda

# Audit all lambdas
/audit

# Audit with path
/audit lambdas/go/bff-*-aws-lambda
```

## What It Checks

### 1. IDOR (Insecure Direct Object Reference)
- Missing ownership validation on resource access
- Path parameters accepted but not validated
- Authorization checks bypassed

### 2. Authorization Bypass
- Missing Organizations client in Service struct
- No context propagation
- Missing validateOwnership functions
- Endpoints accessible without proper auth

### 3. Sensitive Data Logging
- PII in logs (emails, tax IDs, names)
- Secrets in logs (tokens, passwords, API keys)
- Full response bodies logged
- Financial data exposure

### 4. Missing Security Headers
- No MaxBytesReader (unlimited request size)
- Missing Content-Type validation
- Missing Authorization header propagation
- Insecure HTTP client configuration

## Security Patterns

### Known-Good References

The skill learns from these secure implementations:
- `bff-delete-contact-accounts-aws-lambda` - Perfect authorization example
- `bff-get-balance-aws-lambda` - ValidateUserAuthorization pattern
- `bff-get-contacts-aws-lambda` - validateOwnership implementation

### Required Security Controls

For any lambda that accepts resource IDs:

1. **Service struct must include:**
   ```go
   type Service struct {
       BackendClient    client.Client
       Organizations    organizations.APIClient  // REQUIRED
   }
   ```

2. **HTTP handlers must:**
   ```go
   func (s *Service) HandlerHTTP(w http.ResponseWriter, r *http.Request) {
       ctx := r.Context()  // Extract auth context

       // Validate ownership BEFORE accessing resource
       if err := s.validateOwnership(ctx, resourceID); err != nil {
           // Return 403
       }

       // Now safe to access resource
   }
   ```

3. **Ownership validation function:**
   ```go
   func (s *Service) validateOwnership(ctx context.Context, orgID string) error {
       authEmail, err := s.Organizations.GetAuthEmail(ctx)
       if err != nil {
           return ErrGetAuthEmail
       }

       _, org, err := s.Organizations.GetOrganizationByEmail(authEmail)
       if err != nil {
           return ErrGetOrganization
       }

       if org == nil || org.ID != orgID {
           return ErrAccessDenied
       }

       return nil
   }
   ```

## Report Format

The skill generates a markdown report with:
- Executive summary (findings count)
- Detailed vulnerability descriptions
- Exploit scenarios
- Fix recommendations
- Comparison table with other lambdas
- Security score

## Severity Levels

- **HIGH**: Unauthorized data access, privilege escalation, secret exposure
- **MEDIUM**: PII logging, incomplete auth, information disclosure
- **LOW**: Missing defense-in-depth controls

## False Positive Prevention

Only reports findings with 8+/10 confidence. Excludes:
- DOS vulnerabilities
- Rate limiting issues
- Test files
- Theoretical issues without exploitation path
- Pattern deviations that are intentional

## Example Report

```markdown
# Security Audit Report

## Executive Summary
- HIGH: 2 findings
- MEDIUM: 0 findings

## Vuln 1: IDOR: `http.go:20`
* Severity: HIGH
* Missing authorization allows cross-org data access
* Fix: Add validateOwnership call

[Details...]
```

## Customization

To customize for your codebase:
1. Edit SKILL.md to add more reference implementations
2. Add codebase-specific patterns to recognize
3. Update sensitive field list for your domain
4. Adjust severity thresholds

## Integration

Can be used:
- Ad-hoc during development
- In PR reviews
- As part of CI/CD pipeline
- Before security review meetings

## Support

For issues or enhancements, update the SKILL.md file and test with `/audit`.
