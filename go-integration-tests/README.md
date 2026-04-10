# Go Integration Tests Skill

A Claude Code skill for implementing integration tests in Go lambda repositories using Docker Compose, WireMock for HTTP mocking, and optionally DynamoDB Local.

## What This Skill Does

When you invoke `/integration-tests`, Claude will:

1. **setup-repo**: Set up the complete integration test infrastructure in a new repo (docker-compose, WireMock, testcontainers package, CI workflow, Makefile targets, README section)
2. **nueva-lambda**: Add integration tests to an existing lambda (test file, go.mod updates, WireMock mappings)

## Features

- Docker Compose with dynamic ports (no port conflicts)
- WireMock for mocking HTTP services (Auth0, external APIs)
- Shared test scaffolding (`FakeSecretClient`, `SetupTest`, `RunAndCleanup`)
- HTTPS-to-HTTP transport for clients that hardcode `https://`
- JWT utilities for testing Lambda authorizers (RSA key generation, JWKS, token signing)
- WireMock Scenarios for stateful behavior (e.g., max retry attempts)
- GitHub Actions CI workflow
- Makefile targets for local development

## Usage

### Setup a new repo

```
/integration-tests setup-repo
```

This creates:
- `docker-compose.test.yml`
- `testcontainers/wiremock/` (Dockerfile + mappings)
- `pkg/testcontainers/` (integration.go, helper.go, utils.go)
- `.github/workflows/integration-tests.yaml`
- Makefile targets (docker-up, docker-down, test-integration)
- README.md section

### Add tests to a lambda

```
/integration-tests nueva-lambda
```

This creates:
- `cmd/integration_test.go` with GIVEN-WHEN-THEN documented tests
- Updates `go.mod` with replace directives
- Adds WireMock mappings if needed
- Runs `/simplify` on the test code

## Test Naming Convention

```go
func Test_Integration_Action_Condition(t *testing.T)
```

Examples:
- `Test_Integration_Verify_ValidOTP`
- `Test_Integration_DeleteUsers_UserNotFoundTreatedAsSuccess`
- `Test_Integration_AuthorizeJWT_PasswordExpired_ResetEndpoint`

## Minimum Test Coverage

Per lambda:
- 1+ happy path tests
- 2+ input validation tests
- 1 error test per external dependency
- Edge cases as needed

## Running Tests Locally

```bash
# Run all integration tests
make test-integration

# Run a specific lambda
go test -v ./lambdas/go/my-lambda/cmd/... -run Integration

# Start/stop containers manually
make docker-up
make docker-down
```

## Requirements

- Docker Desktop (includes Docker Compose)
- Go 1.26+

## Key Design Decisions

- **Dynamic ports**: Avoids "port already allocated" conflicts
- **go.work not committed**: Generated locally and in CI; added to `.gitignore`
- **Safe cleanup**: Only `docker compose down`, no global `docker rm` filters that could affect other projects
- **Real clients + WireMock**: Tests use real HTTP clients pointed at WireMock, not mocks, for better coverage
- **No deprecated APIs**: `rand.Read()`, `math/rand`, `ioutil.*` are explicitly banned

## Installation

```bash
# Symlink for development
ln -s $(pwd)/go-integration-tests ~/.claude/skills/go-integration-tests

# Or copy
cp -r go-integration-tests ~/.claude/skills/
```

---

Created for comprehensive Go integration testing with Claude Code
