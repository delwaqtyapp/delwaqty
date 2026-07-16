#!/bin/bash
# Code generation script
set -e
echo "Running code generation..."
dart run build_runner build --delete-conflicting-outputs
echo ""
echo "Code generation complete!"
