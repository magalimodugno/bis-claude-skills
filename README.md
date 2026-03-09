# Claude Code Skills

Este repositorio contiene skills personalizadas para Claude Code que ayudan en tareas comunes de desarrollo.

## Skills Disponibles

### 1. audit
Auditoría de seguridad integral para detectar vulnerabilidades IDOR, bypasses de autorización, logging de datos sensibles y headers de seguridad faltantes.

**Uso:**
```bash
/audit                          # Audita todos los lambdas en lambdas/go/
/audit bff-example-service     # Audita un lambda específico
```

**Detecta:**
- Vulnerabilidades IDOR (Insecure Direct Object References)
- Bypasses de autorización
- Logging de datos sensibles (PII, tokens, passwords)
- Headers de seguridad faltantes

### 2. go-code-review
Code review integral para código Go que detecta bugs, problemas de formateo, issues de performance y gaps de cobertura de tests.

**Uso:**
```bash
/go-code-review    # Revisa todos los cambios Go en el branch actual
```

**Detecta:**
- Bugs comunes (nil pointers, errores sin chequear, goroutine leaks)
- Problemas de formateo y estilo (vía golangci-lint)
- Issues de performance (concatenación de strings, allocations innecesarias)
- Cobertura de tests insuficiente
- Validación contra CLAUDE.md (guidelines del codebase)

**Características:**
- Análisis de 50+ linters vía golangci-lint
- Solo reporta issues con confianza >= 80/100
- Sugiere casos de prueba para código sin tests
- Ofrece arreglar issues de alta prioridad automáticamente

### 3. go-test-coverage
Workflow completo para construir código Go, correr tests con cobertura, agregar tests faltantes usando patrones table-driven con nomenclatura Given/When/Then, y mostrar resultados.

**Uso:**
```bash
/go-test-coverage
```

**Características:**
- Build del código Go
- Ejecución de tests con cobertura
- Identificación de gaps de cobertura
- Agregado automático de tests table-driven
- Nomenclatura Given/When/Then para casos de prueba
- Reporte de cobertura en terminal

## Instalación

### Opción 1: Instalación Manual

1. Copia las carpetas de las skills al directorio de configuración de Claude:

```bash
# Linux/Mac
cp -r audit ~/.claude/skills/
cp -r go-code-review ~/.claude/skills/
cp -r go-test-coverage ~/.claude/skills/

```

2. Reinicia Claude Code si está en ejecución

3. Verifica que las skills estén disponibles:
```bash
claude # Inicia Claude Code
# Escribe /audit o /go-test-coverage para usar las skills
```

### Opción 2: Instalación con Symlinks (Desarrollo)

Si quieres mantener las skills en este repositorio y que se actualicen automáticamente:

```bash
# Linux/Mac
ln -s $(pwd)/audit ~/.claude/skills/audit
ln -s $(pwd)/go-code-review ~/.claude/skills/go-code-review
ln -s $(pwd)/go-test-coverage ~/.claude/skills/go-test-coverage
```

## Estructura de una Skill

Cada skill contiene:
- `SKILL.md`: Configuración y definición de la skill
- `README.md`: Documentación de uso
- Archivos adicionales: referencias, scripts, templates, etc.