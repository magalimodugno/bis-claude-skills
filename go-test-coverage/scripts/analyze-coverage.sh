#!/bin/bash

echo "=== Coverage Analysis ==="
echo ""

if [ ! -f "coverage.out" ]; then
    echo "Error: coverage.out not found"
    echo "Please run tests with coverage first"
    exit 1
fi

echo "Coverage by Package:"
go tool cover -func=coverage.out | grep -v "total:" | awk '{print $1 "\t" $3}' | sort -k2 -rn

echo ""
echo "Overall Coverage:"
go tool cover -func=coverage.out | grep total:

echo ""
echo "Uncovered Functions:"
go tool cover -func=coverage.out | grep "0.0%" || echo "All functions have some coverage!"

echo ""
echo "Low Coverage Functions (< 50%):"
go tool cover -func=coverage.out | awk '$3 < 50.0 && $3 > 0.0 {print $1 "\t" $2 "\t" $3}' | head -20 || echo "No functions with low coverage!"