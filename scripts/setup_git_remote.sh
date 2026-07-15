#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Git Remote Setup Script for Delwaqty
# =============================================================================
# This script configures the GitHub remote for this repository.
#
# Usage:
#   GITHUB_REMOTE_URL=git@github.com:yourorg/delwaqty.git ./scripts/setup_git_remote.sh
#
# Or run without the env var to get instructions:
#   ./scripts/setup_git_remote.sh
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_NAME="origin"

cd "$REPO_ROOT"

echo "=== Delwaqty Git Remote Setup ==="
echo ""

# Check if remote already exists
if git remote get-url "$REMOTE_NAME" &>/dev/null; then
    CURRENT_URL=$(git remote get-url "$REMOTE_NAME")
    echo "Remote '$REMOTE_NAME' already configured:"
    echo "  URL: $CURRENT_URL"
    echo ""
    read -rp "Update remote URL? (y/N) " UPDATE
    if [[ "$UPDATE" =~ ^[Yy]$ ]]; then
        read -rp "Enter new GitHub remote URL: " NEW_URL
        if [[ -n "$NEW_URL" ]]; then
            git remote set-url "$REMOTE_NAME" "$NEW_URL"
            echo "Remote URL updated to: $NEW_URL"
        fi
    fi
else
    # Try to get URL from environment
    REMOTE_URL="${GITHUB_REMOTE_URL:-}"

    if [[ -z "$REMOTE_URL" ]]; then
        echo "No GitHub remote URL configured."
        echo ""
        echo "Please provide the remote URL in one of these formats:"
        echo "  SSH:   git@github.com:yourorg/delwaqty.git"
        echo "  HTTPS: https://github.com/yourorg/delwaqty.git"
        echo ""
        echo "Run again with:"
        echo "  GITHUB_REMOTE_URL=<url> $0"
        echo ""
        echo "Or add manually with:"
        echo "  git remote add origin <url>"
        exit 0
    fi

    echo "Adding remote '$REMOTE_NAME' -> $REMOTE_URL"
    git remote add "$REMOTE_NAME" "$REMOTE_URL"
    echo "Remote configured successfully."
fi

echo ""
echo "=== Current remotes ==="
git remote -v
echo ""

# Push all branches and set upstream tracking
echo "=== Pushing all branches ==="
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Use the first branch if no default found
if ! git rev-parse --verify "$DEFAULT_BRANCH" &>/dev/null; then
    DEFAULT_BRANCH=$(git branch --show-current)
    if [[ -z "$DEFAULT_BRANCH" ]]; then
        DEFAULT_BRANCH="main"
    fi
fi

echo "Default branch: $DEFAULT_BRANCH"

# Push all local branches
for branch in $(git branch --format='%(refname:short)'); do
    echo "Pushing branch: $branch"
    if [[ "$branch" == "$DEFAULT_BRANCH" ]]; then
        git push -u "$REMOTE_NAME" "$branch"
    else
        git push "$REMOTE_NAME" "$branch"
    fi
done

echo ""
echo "=== Pushing tags ==="
git push "$REMOTE_NAME" --tags

echo ""
echo "=== Setting upstream tracking for $DEFAULT_BRANCH ==="
git branch --set-upstream-to="$REMOTE_NAME/$DEFAULT_BRANCH" "$DEFAULT_BRANCH" 2>/dev/null || true

echo ""
echo "=== Done! ==="
git remote -v
git branch -vv
