#!/bin/bash
set -e

echo "=== Running Go Tests with Coverage ==="
echo ""

# Clean previous coverage files
rm -f coverage.out coverage.html coverage-before.txt coverage-after.txt

echo "Running tests with coverage..."
go test -v -race -coverprofile=coverage.out ./...

echo ""
echo "Generating coverage reports..."
go tool cover -html=coverage.out -o coverage.html
go tool cover -func=coverage.out > coverage.txt

echo ""
echo "=== Coverage Summary ==="
grep total coverage.txt || echo "No coverage data available"

echo ""
echo "📊 Coverage reports generated:"
echo "  - HTML: coverage.html"
echo "  - Text: coverage.txt"
echo "  - Raw:  coverage.out"