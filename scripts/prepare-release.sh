#!/bin/bash
set -e

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --staged --quiet; then
  echo "Error: You have uncommitted changes. Please commit or stash them first."
  exit 1
fi

# Check we're on main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Error: You must be on the main branch to prepare a release."
  exit 1
fi

# Pull latest
echo "Pulling latest changes..."
git pull origin main

# Run changeset version
echo "Running changeset version..."
pnpm changeset version

# Check if there are changes to commit
if git diff --quiet && git diff --staged --quiet; then
  echo "No version changes to commit. Make sure you have changesets to consume."
  exit 1
fi

# Generate branch name with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH_NAME="release/$TIMESTAMP"

# Create release branch
echo "Creating branch $BRANCH_NAME..."
git checkout -b "$BRANCH_NAME"

# Commit changes
echo "Committing version changes..."
git add -A
git commit -m "chore: version packages"

# Push branch
echo "Pushing branch..."
git push origin "$BRANCH_NAME"

echo ""
echo "✅ Release branch created and pushed!"
echo ""
echo "Next steps:"
echo "  1. Create a PR from $BRANCH_NAME to main"
echo "  2. Merge the PR to trigger the release"
echo ""
echo "Or run: gh pr create --title 'chore: release' --body 'Release packages'"
