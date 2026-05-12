#!/bin/bash
#
# implement.sh — copy automation files into a student repository.
#
# Usage:
#   ./implement.sh <DEPLOYMENT_ID> <REPOSITORY_URL>
#
#   DEPLOYMENT_ID   — the Apps Script deployment ID (AKfycb...)
#   REPOSITORY_URL  — git clone URL of the target student repository
#
# The script clones the repository, copies all subdirectories from examples/
# into the repo root (with the real exec URL substituted into config.json),
# commits, pushes, and removes all temporary files.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/examples"
DEPLOYMENTS_DIR="$SCRIPT_DIR/deployments"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <DEPLOYMENT_ID> <REPOSITORY_URL>"
  echo ""
  echo "  DEPLOYMENT_ID   — the Apps Script deployment ID (AKfycb...)"
  echo "  REPOSITORY_URL  — git clone URL of the target student repository"
  exit 1
fi

DEPLOYMENT_ID="$1"
REPO_URL="$2"

# Validate that a record exists for this deployment ID.
RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
if [ ! -f "$RECORD" ]; then
  echo "Error: no saved record for deployment ID: $DEPLOYMENT_ID"
  echo "Check the deployments/ directory for known IDs."
  exit 1
fi

# Clone into a temp dir; always clean up on exit regardless of success or failure.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Cloning $REPO_URL..."
git clone "$REPO_URL" "$TMP/repo"

# Copy all subdirectories from examples/ into the repo root, skipping README.md.
# rsync merges into existing directories rather than nesting them.
rsync -a --exclude='/README.md' --exclude='/README.txt' "$EXAMPLES_DIR/" "$TMP/repo/"

# Substitute the real deployment ID into the copied config.json.
CONFIG="$TMP/repo/.automations/config.json"
TMP_CONFIG=$(mktemp)
sed "s/YOUR_DEPLOYMENT_ID_HERE/$DEPLOYMENT_ID/g" "$CONFIG" > "$TMP_CONFIG"
mv "$TMP_CONFIG" "$CONFIG"

# Stage only the automation directories.
cd "$TMP/repo"
git add .automations .claude .cursor .github

# Commit only if there are staged changes.
if git diff --staged --quiet; then
  echo "No changes to commit — automation files are already up to date."
else
  git commit -m "Add instructor automations"
  git push
  echo ""
  echo "Done. Automation files pushed to $REPO_URL"
fi
