#!/bin/bash
# Quick test script
set -e
echo "Running flutter test..."
flutter test "$@"
echo ""
echo "Tests complete!"
