#!/bin/bash
# Sprint commit helper - stages all, runs tests, commits with standard format
set -euo pipefail

cd "$(dirname "$0")/.."

# Parse sprint number from existing commits
LAST_SPRINT=$(git log --oneline --grep="sprint " --format="%s" | head -1 | grep -oP 'sprint \K\d+' || echo "0")
NEXT_SPRINT=$((LAST_SPRINT + 1))

# Get description from argument or prompt
DESCRIPTION="${1:-}"
if [ -z "$DESCRIPTION" ]; then
    echo "Last sprint: $LAST_SPRINT"
    echo "Next sprint: $NEXT_SPRINT"
    echo ""
    read -rp "Enter sprint description: " DESCRIPTION
    if [ -z "$DESCRIPTION" ]; then
        echo "Error: description cannot be empty"
        exit 1
    fi
fi

# Run tests
echo ""
echo "Running tests..."
if ! flutter test; then
    echo "Tests failed! Commit aborted."
    exit 1
fi
echo "Tests passed!"

# Stage all changes
echo ""
echo "Staging changes..."
git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

# Show what will be committed
echo ""
echo "Changes to commit:"
git diff --cached --stat
echo ""

# Create commit message
COMMIT_MSG="sprint $NEXT_SPRINT: $DESCRIPTION"
echo "Commit message: $COMMIT_MSG"
read -rp "Confirm commit? (Y/n) " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Commit aborted."
    exit 0
fi

git commit -m "$COMMIT_MSG"
echo ""
echo "Committed successfully!"
