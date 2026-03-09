#!/bin/bash
set -e

echo "=== Building Go Project ==="
echo ""

# Find go.mod to determine project root
if [ ! -f "go.mod" ]; then
    echo "Error: go.mod not found in current directory"
    echo "Please run this script from the project root"
    exit 1
fi

echo "Building all packages..."
go build -v ./...

echo ""
echo "✅ Build successful!"