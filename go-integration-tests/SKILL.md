---
name: integration-tests
description: Implement integration tests for Go lambdas using testcontainers (Docker Compose), WireMock for HTTP mocks, and optionally DynamoDB Local
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: Integration Tests para Lambdas Go

Esta skill implementa tests de integracion para lambdas Go usando testcontainers (Docker Compose), WireMock para mocks HTTP, y DynamoDB Local.

## Uso

```
/integration-tests [nueva-lambda | setup-repo]
```

- `nueva-lambda`: Agrega integration tests a una lambda existente
- `setup-repo`: Configura la infraestructura completa de tests en un repo nuevo

---

## Estructura de Archivos

```
repo/
├── .github/workflows/
│   └── integration-tests.yaml      # CI workflow
├── docker-compose.test.yml         # Infraestructura de tests (puertos dinamicos)
├── testcontainers/
│   ├── dynamodb-init/
│   │   ├── Dockerfile
│   │   └── dynamodb-init.sh        # Crea tablas DynamoDB
│   └── wiremock/
│       ├── Dockerfile
│       └── mappings/               # Mocks HTTP por servicio
│           ├── users.json
│           ├── organizations.json
│           └── ...
├── pkg/
│   ├── testcontainers/             # Infraestructura de tests
│   │   ├── go.mod
│   │   ├── integration.go          # Manejo de containers
│   │   ├── helper.go               # TestHelper, TestConfig, FakeSecretClient, SetupTest, RunAndCleanup
│   │   └── utils.go                # Utilidades (usa crypto/rand, NO math/rand)
│   └── testclients/                # Clientes HTTP compartidos para tests (opcional)
│       ├── go.mod
│       └── ...
└── lambdas/go/
    └── mi-lambda/
        ├── go.mod
        └── cmd/
            ├── main.go
            └── integration_test.go
```

---

## Convencion de Nombres de Tests

Usar formato **Test_Integration_Action_Condition**:

```go
func Test_Integration_Action_Condition(t *testing.T)
```

### Ejemplos:

```go
// Happy path
func Test_Integration_Process_ValidApprovedOrg(t *testing.T)
func Test_Integration_PutAndGet_ReturnsStoredData(t *testing.T)
func Test_Integration_Handle_ApprovedToActive(t *testing.T)

// Error scenarios
func Test_Integration_Process_UserNotFound(t *testing.T)
func Test_Integration_Process_TICServiceFails(t *testing.T)

// Validacion de input
func Test_Integration_Process_NilOrganization(t *testing.T)
func Test_Integration_Process_InvalidProvince(t *testing.T)

// Edge cases
func Test_Integration_ActivateProducts_MultipleOrganizations(t *testing.T)
func Test_Integration_CRUD_DataIsIsolatedPerOrg(t *testing.T)
```

### Reglas:
- Prefijo: `Test_Integration_`
- Seguido de la accion (Process, Handle, PutAndGet, Delete, etc.)
- Seguido de la condicion o resultado esperado
- Usar PascalCase sin espacios
- Ser especifico pero conciso
- Cada test debe tener comentarios GIVEN-WHEN-THEN arriba de la funcion

---

## Cobertura Minima Requerida

### Tests obligatorios por lambda:

1. **Happy Path** (minimo 1-2 tests)
   - Flujo principal exitoso
   - Variaciones validas de input

2. **Validacion de Input** (minimo 2-3 tests)
   - Input nil/vacio
   - Campos requeridos faltantes
   - Formato invalido

3. **Errores de Servicios Externos** (1 por dependencia)
   - Servicio HTTP retorna 500
   - Servicio HTTP retorna 404
   - Timeout (si aplica)

4. **Edge Cases** (segun complejidad)
   - Datos duplicados
   - Concurrencia (si aplica)
   - Limites de datos

---

## Estructura del Integration Test

```go
package main_test

import (
    "testing"

    "mi-lambda/internal/service"
    "mi-lambda/pkg/auth0"

    "github.com/Bancar/<repo>/pkg/testcontainers"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestMain(m *testing.M) { testcontainers.RunAndCleanup(m) }

var defaultEnv = map[string]string{
    "SECRET_NAME": "test-secret",
}

func newService(t *testing.T, tc *testcontainers.TestContext) *service.Service {
    auth0Client, err := auth0.New(testcontainers.GetTestHTTPClient())
    require.NoError(t, err)
    return service.New(&service.Clients{
        Auth0:  auth0Client,
        Secret: &testcontainers.FakeSecretClient{Credentials: tc.Helper.Auth0TestCredentials(t)},
    })
}

// GIVEN a valid input
// WHEN the Process method is called
// THEN it should return no error
func Test_Integration_Process_ValidInput(t *testing.T) {
    tc := testcontainers.SetupTest(t, defaultEnv)
    svc := newService(t, tc)

    err := svc.Process(tc.Ctx, newValidInput())

    assert.NoError(t, err)
}

// GIVEN an input that triggers an error
// WHEN the Process method is called
// THEN it should return ErrProcessFailed
func Test_Integration_Process_ServiceError(t *testing.T) {
    tc := testcontainers.SetupTest(t, defaultEnv)
    svc := newService(t, tc)

    err := svc.Process(tc.Ctx, newErrorInput())

    require.Error(t, err)
    assert.ErrorIs(t, err, service.ErrProcessFailed)
}
```

### Scaffolding compartido en pkg/testcontainers:

| Tipo | Uso |
|------|-----|
| `testcontainers.RunAndCleanup(m)` | Reemplaza el boilerplate de TestMain |
| `testcontainers.SetupTest(t, envVars)` | Crea TestContext y configura env vars |
| `testcontainers.TestContext` | Struct con Ctx, Helper, Cfg |
| `testcontainers.FakeSecretClient` | Implementa secret.Client para tests |
| `testcontainers.GetTestHTTPClient()` | HTTP client con HTTPS→HTTP redirect para WireMock |
| `testcontainers.GenerateTestEmail()` | Genera email unico para tests |
| `testcontainers.ErrorPrefix` | Constante "error-" para WireMock |
| `testcontainers.NotFoundPrefix` | Constante "not-found-" para WireMock |

### Assertions: `require` vs `assert`

- Usar **`require`** cuando el fallo debe detener el test inmediatamente (ej: dentro de loops, precondiciones criticas)
- Usar **`assert`** para la mayoria de validaciones

---

## WireMock Mappings

### Estructura por servicio:

```json
{
  "mappings": [
    {
      "name": "Service - Error Case",
      "priority": 1,
      "request": {
        "method": "GET",
        "urlPathPattern": "/api/v1/resource/not-found-.*"
      },
      "response": {
        "status": 404,
        "headers": { "Content-Type": "application/json" },
        "jsonBody": { "error": "Not found" }
      }
    },
    {
      "name": "Service - Success",
      "priority": 5,
      "request": {
        "method": "GET",
        "urlPathPattern": "/api/v1/resource/.*"
      },
      "response": {
        "status": 200,
        "headers": { "Content-Type": "application/json" },
        "jsonBody": { "id": "123", "name": "Test" }
      }
    }
  ]
}
```

### Convenciones:
- **priority 1**: Casos de error (mas especificos)
- **priority 5**: Casos de exito (catch-all)
- Usar `urlPathPattern` con regex para IDs dinamicos
- Prefijo `not-found-` o `error-` para triggear errores en tests
- Para bodyPatterns, usar siempre la sintaxis nested de `matchesJsonPath`:
  ```json
  {"matchesJsonPath": {"expression": "$.field", "contains": "value"}}
  ```
  NO usar la forma plana `{"matchesJsonPath": "$.field", "contains": "value"}` ya que WireMock la interpreta incorrectamente.

---

## Docker Compose Test

**IMPORTANTE**: Los puertos se exponen sin mapeo fijo al host (puerto dinamico). Docker asigna un puerto efimero aleatorio en el host.

```yaml
services:
  wiremock:
    build:
      context: ./testcontainers/wiremock
    ports:
      - "8080"          # Puerto dinamico en el host (NO 8080:8080)
    command: >
      --global-response-templating
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/__admin/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s
```

### Por que puertos dinamicos?

Evita conflictos de "port already allocated" cuando hay otros servicios usando esos puertos. El CI y los tests locales deben consultar el puerto asignado con `docker compose port`.

---

## CI Workflow

```yaml
name: Integration Tests

on:
  workflow_dispatch:
    inputs:
      branch:
        description: 'Branch to run the workflow on'
        required: true
        default: 'main'
        type: string
  pull_request:
    branches: [main, develop]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.26'

      - name: Cache Go modules
        uses: actions/cache@v4
        with:
          path: |
            ~/.cache/go-build
            ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}

      - name: Configure Git for private modules
        env:
          GITHUB_TOKEN: ${{ secrets.UALA_GLOBAL_GITHUB_TOKEN }}
        run: |
          git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

      - name: Configure Go for private modules
        run: |
          echo "GOPRIVATE=github.com/Bancar/*" >> $GITHUB_ENV

      - name: Create Go workspace
        run: |
          go work init
          find lambdas/go pkg -name 'go.mod' -exec dirname {} \; | xargs -I {} go work use {}

      - name: Start test infrastructure
        run: |
          docker compose -f docker-compose.test.yml up -d --build --wait
          sleep 5
          WIREMOCK_PORT=$(docker compose -f docker-compose.test.yml port wiremock 8080 | cut -d: -f2)
          echo "TEST_WIREMOCK_URL=http://localhost:${WIREMOCK_PORT}" >> $GITHUB_ENV
          echo "TEST_SKIP_CONTAINER_SETUP=true" >> $GITHUB_ENV

      - name: Run integration tests
        run: |
          for dir in $(find lambdas/go -name 'go.mod' -exec dirname {} \;); do
            if ls ${dir}/cmd/*integration_test.go 1>/dev/null 2>&1; then
              go test -v -p 1 ./${dir}/cmd/... -run Integration || exit 1
            fi
          done

      - name: Stop test infrastructure
        if: always()
        run: |
          docker compose -f docker-compose.test.yml down --remove-orphans
```

### Notas importantes del CI:
- **Puertos dinamicos**: Usar `docker compose port` para obtener el puerto real
- **Go workspace**: Se genera dinamicamente con `find` para incluir todos los modulos
- **go.work y go.work.sum**: NO commitear, agregar al .gitignore. El CI los genera dinamicamente.
- **Cleanup**: Usar solo `docker compose down --remove-orphans`. **NO usar** `docker rm -f` con filtros globales como `--filter "name=test-"` ni `docker network prune` ya que pueden afectar containers y redes de otros proyectos en la maquina del desarrollador. El cleanup debe limitarse a los recursos creados por el compose file o al `stackIdentifier` exacto usando labels (`com.docker.compose.project=<stackId>`)

---

## Configuracion de go.mod en Lambdas

Cada lambda debe tener directivas `replace` en su `go.mod` para los paquetes locales:

```go
module mi-lambda

go 1.26

replace github.com/Bancar/<repo>/pkg/testcontainers => ../../../pkg/testcontainers

require (
    github.com/Bancar/<repo>/pkg/testcontainers v0.0.0
    // ... otras dependencias
)
```

**Importante:** Sin estas directivas `replace`, Go intentara descargar los paquetes desde GitHub (donde no estan publicados). Usar `v0.0.0` como version ya que el `replace` redirige al path local.

---

## Checklist para Nueva Lambda

### Setup inicial:
- [ ] Crear `cmd/integration_test.go` con estructura estandar
- [ ] Agregar directivas `replace` en `go.mod` para `testcontainers`
- [ ] Agregar `require` con `v0.0.0` para los paquetes de test

### Implementacion de tests:
- [ ] Usar `testcontainers.RunAndCleanup(m)` en TestMain
- [ ] Usar `testcontainers.SetupTest(t, envVars)` para setup
- [ ] Implementar `newService(t, tc)` helper por lambda
- [ ] Usar `testcontainers.FakeSecretClient` para el secret client
- [ ] Usar `testcontainers.GetTestHTTPClient()` para clientes HTTP
- [ ] Usar constantes `testcontainers.ErrorPrefix`, `NotFoundPrefix`, etc. para WireMock patterns

### Tests requeridos:
- [ ] Tests happy path (minimo 1)
- [ ] Tests de validacion de input (minimo 2)
- [ ] Tests de error por cada dependencia externa
- [ ] Verificar naming convention `Test_Integration_Action_Condition`
- [ ] Comentarios GIVEN-WHEN-THEN en cada test
- [ ] Usar `require` para precondiciones, `assert` para validaciones

### Infraestructura:
- [ ] Agregar WireMock mappings si hay nuevos endpoints
- [ ] Actualizar `dynamodb-init.sh` si se necesitan nuevas tablas

### Documentacion:
- [ ] Si el README.md no tiene seccion de tests de integracion, agregar una con: prerequisitos (Docker Desktop, version de Go), setup del go workspace, y comandos para correr tests (`make test-integration`, test de lambda especifica, `make docker-up`, `make docker-down`)

### Verificacion:
- [ ] Correr tests localmente antes de push
- [ ] Verificar que todos los tests pasan con containers pre-existentes
- [ ] Verificar que no se modifico codigo de produccion
- [ ] Correr `/simplify` sobre el codigo de tests

---

## Troubleshooting

### Error: "go.work already exists" en CI
El `go.work` fue commiteado por error. Agregarlo al `.gitignore`:
```
go.work
go.work.sum
```

### Error: "port is already allocated"
```bash
docker compose -f docker-compose.test.yml down --remove-orphans
```

### Error: "no such file or directory" para docker-compose.test.yml
Crear el `go.work` en la raiz del repo:
```bash
go work init
find lambdas/go pkg -name 'go.mod' -exec dirname {} \; | xargs -I {} go work use {}
```

### Error: "unsupported protocol scheme"
Falta configurar `TEST_WIREMOCK_URL`:
```bash
WIREMOCK_PORT=$(docker compose -f docker-compose.test.yml port wiremock 8080 | cut -d: -f2)
export TEST_WIREMOCK_URL=http://localhost:${WIREMOCK_PORT}
```

### WireMock matchesJsonPath no matchea correctamente
Usar siempre la sintaxis nested:
```json
{"matchesJsonPath": {"expression": "$.field", "contains": "value"}}
```
NO usar: `{"matchesJsonPath": "$.field", "contains": "value"}`

### APIs deprecadas a evitar
- **NO usar** `math/rand` -> usar `crypto/rand` (deprecated desde Go 1.20)
- **NO usar** `rand.Read()` de `crypto/rand` -> usar `io.ReadFull(rand.Reader, buf)` o funciones de nivel superior como `uuid.New()` (deprecated desde Go 1.24)
- **NO usar** `aws.EndpointResolverWithOptionsFunc` -> usar el endpoint resolver del servicio especifico de AWS SDK v2
- **NO usar** `ioutil.*` -> usar `io` y `os` (deprecated desde Go 1.16)
