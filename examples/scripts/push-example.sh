#!/usr/bin/env bash
# Usage: push-example.sh <app>
# Clones the output repo, syncs dist/<app>/ into it, pushes a branch, and opens a PR.
# Requires gh auth login.
set -euo pipefail

APP=${1:?Usage: push-example.sh <app>}

declare -A REPOS=(
  ["react-evm"]="sunrisedotdev/sonar-example-react"
  ["nextjs-evm"]="sunrisedotdev/sonar-example-nextjs"
  ["react-svm"]="sunrisedotdev/sonar-example-react-svm"
  ["nextjs-svm"]="sunrisedotdev/sonar-example-nextjs-svm"
)

REPO=${REPOS[$APP]:?Unknown app: $APP}
SOURCE_SHA=$(git rev-parse HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)
DIST_DIR=$(pwd)/dist/$APP
BRANCH="chore/generated-update"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

gh repo clone "$REPO" "$WORK_DIR/$APP"

cd "$WORK_DIR/$APP"
git checkout -B "$BRANCH"

rsync -a --delete --exclude='.git' "$DIST_DIR/" .

git add -A

if git diff --cached --quiet; then
  echo "${APP}: unchanged, skipping"
  exit 0
fi

git commit -m "chore: generated from sonar@${SOURCE_SHA}"
git push origin "$BRANCH" --force

gh pr create \
  --repo "$REPO" \
  --head "$BRANCH" \
  --base main \
  --title "chore: generated update from sonar@${SHORT_SHA}" \
  --body "Automated update generated from [sonar@\`${SHORT_SHA}\`](https://github.com/sunrisedotdev/sonar/commit/${SOURCE_SHA})." \
  2>/dev/null || true

PR_URL=$(gh pr view --repo "$REPO" "$BRANCH" --json url --jq .url)
echo "${APP}: PR → ${PR_URL}"
