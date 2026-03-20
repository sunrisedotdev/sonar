#!/usr/bin/env bash
# Generates all example apps and opens PRs in their output repos.
# Run from the sonar repo root.
# Flags:
#   --svm   include react-svm and nextjs-svm (requires framework dirs to exist)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/../.."

SVM=false
for arg in "$@"; do
  [[ "$arg" == "--svm" ]] && SVM=true
done

EVM_APPS=(react-evm nextjs-evm)
SVM_APPS=(react-svm nextjs-svm)

APPS=("${EVM_APPS[@]}")
$SVM && APPS+=("${SVM_APPS[@]}")

SOURCE_SHA=$(git rev-parse --short HEAD)

echo "==> Generating example apps"
for APP in "${APPS[@]}"; do
  node examples/scripts/generate-example.mjs "$APP"
done

echo ""
echo "==> Opening PRs"
declare -A PR_URLS
PUSHED=()
SKIPPED=()
for APP in "${APPS[@]}"; do
  OUTPUT=$(bash examples/scripts/push-example.sh "$APP")
  echo "$OUTPUT"
  if [[ "$OUTPUT" == *"skipping"* ]]; then
    SKIPPED+=("$APP")
  else
    PUSHED+=("$APP")
    PR_URL=$(echo "$OUTPUT" | grep -o 'https://.*')
    PR_URLS["$APP"]="$PR_URL"
  fi
done

echo ""
echo "==> Done"

if [ ${#PUSHED[@]} -eq 0 ]; then
  echo "No apps were updated."
  exit 0
fi

cat <<EOF

==> Slack message

:ship: *Sonar example apps updated* (sonar@${SOURCE_SHA})

$(for APP in "${PUSHED[@]}"; do
  echo "• *${APP}*: ${PR_URLS[$APP]}"
done)

Let us know if you run into any issues getting set up.
EOF
