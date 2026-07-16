#!/bin/bash
# Comprehensive git status report
set -euo pipefail

cd "$(dirname "$0")/.."

echo "============================================"
echo "  Delwaqty - Git Status Report"
echo "============================================"
echo ""

# Branch info
echo "Branches:"
CURRENT_BRANCH=$(git branch --show-current)
echo "  Current: $CURRENT_BRANCH"
echo "  Local branches:"
git branch --format='    %(refname:short)%(if)%(HEAD)%(then) * (HEAD)%(end)' 2>/dev/null
if [ $? -ne 0 ]; then
    while IFS= read -r line; do
        echo "    $line"
    done <<< "$(git branch)"
fi
echo ""

# Tracking info
echo "Tracking:"
BRANCHES=$(git branch -vv --format='%(refname:short)%(if)%(upstream:short)%(then) -> %(upstream:short) [%(upstream:trackshort)]%(end)')
echo "$BRANCHES" | sed 's/^/    /'
echo ""

# Remote info
echo "Remotes:"
git remote -v | sed 's/^/    /'
echo ""

# Staging status
echo "Staging area:"
STAGED=$(git diff --cached --stat)
if [ -n "$STAGED" ]; then
    echo "$STAGED" | sed 's/^/    /'
else
    echo "    (nothing staged)"
fi
echo ""

# Unstaged changes
echo "Unstaged changes:"
UNSTAGED=$(git diff --stat)
if [ -n "$UNSTAGED" ]; then
    echo "$UNSTAGED" | sed 's/^/    /'
else
    echo "    (clean)"
fi
echo ""

# Untracked files
echo "Untracked files:"
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "$UNTRACKED" | sed 's/^/    /'
else
    echo "    (none)"
fi
echo ""

# Last 5 commits
echo "Recent commits (last 5):"
git log --oneline -5 | sed 's/^/    /'
echo ""

# Ahead/behind origin
if git remote get-url origin &>/dev/null; then
    AHEAD_BEHIND=$(git rev-list --left-right --count HEAD...origin/$CURRENT_BRANCH 2>/dev/null || echo "0 0")
    AHEAD=$(echo "$AHEAD_BEHIND" | cut -f1)
    BEHIND=$(echo "$AHEAD_BEHIND" | cut -f2)
    echo "vs origin/$CURRENT_BRANCH:"
    echo "    Ahead:  $AHEAD commits"
    echo "    Behind: $BEHIND commits"
fi
echo ""

# Tags
TAGS=$(git tag -l --sort=-version:refname | head -5)
if [ -n "$TAGS" ]; then
    echo "Recent tags:"
    echo "$TAGS" | sed 's/^/    /'
fi
echo ""

echo "============================================"
