#!/bin/bash
# Run all tests, then build debug APK
cd "$(dirname "$0")/.."
echo "Running tests..."
flutter test
if [ $? -eq 0 ]; then
  echo "Tests passed! Building APK..."
  ./build.sh
else
  echo "Tests failed! Fix errors before building."
  exit 1
fi
