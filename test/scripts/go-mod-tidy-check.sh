#!/bin/bash
# Checks if go.mod/go.sum are in sync by running go mod tidy and checking for changes
set -e

if [ ! -f "go.mod" ]; then
    echo "No go.mod found in current directory"
    exit 0
fi

cp go.mod go.mod.backup
cp go.sum go.sum.backup 2>/dev/null || true

go mod tidy

if ! diff -q go.mod go.mod.backup > /dev/null 2>&1 || \
   ! diff -q go.sum go.sum.backup > /dev/null 2>&1; then
    echo "ERROR: go.mod or go.sum is out of sync. Run 'go mod tidy' and commit the changes."
    mv go.mod.backup go.mod
    mv go.sum.backup go.sum 2>/dev/null || true
    exit 1
fi

rm go.mod.backup go.sum.backup 2>/dev/null || true
echo "go mod tidy check passed"
