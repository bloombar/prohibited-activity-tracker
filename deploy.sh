#!/bin/bash
#
# Deploy helper for prohibited_activity_tracker.
#
# Commands:
#   ./deploy.sh setup-library
#       Creates the Apps Script library project on Google Drive, pushes
#       Prohibition.js, and prints the Script ID to paste into
#       wrapper/appsscript.json. Run once per machine after 'clasp login'.
#
#   ./deploy.sh new [SPREADSHEET_ID]
#       Creates a new bound script on an existing spreadsheet (if ID given)
#       or on a brand-new spreadsheet (if omitted), pushes the wrapper, and
#       deploys it as a web app. Saves the deployment ID to deployments/ and
#       prints the exec URL to paste into the course repo's config.json.
#
#   ./deploy.sh redeploy <DEPLOYMENT_ID>
#       Pushes the current wrapper/doPost.js to an existing deployment,
#       keeping the same exec URL. Use this instead of 'new' when updating
#       a wrapper that is already in production.
#
#   ./deploy.sh delete <DEPLOYMENT_ID>
#       Removes a prior web app deployment from Google Apps Script and deletes
#       its saved record from deployments/. The exec URL stops working immediately.
#
#   ./deploy.sh update-library
#       Pushes local changes to Prohibition.js to the library project.
#       All wrapper scripts using version 0 (HEAD) pick up the change
#       automatically on next execution.

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENTS_DIR="$REPO_DIR/deployments"

# Verify clasp is authenticated before running any command.
if [ ! -f "$HOME/.clasprc.json" ]; then
  echo "Error: clasp credentials not found."
  echo "Run 'clasp login' first, then retry."
  exit 1
fi

_print_exec_url() {
  local deployment_id="$1"
  local exec_url="https://script.google.com/macros/s/${deployment_id}/exec"
  echo ""
  echo "Exec URL (paste into your course repo's .automations/config.json):"
  echo ""
  echo "  $exec_url"
}

case "$1" in

  setup-library)
    cd "$REPO_DIR/library"
    clasp create --type standalone --title "Prohibition Activity Tracker Library"
    clasp push
    echo ""
    echo "Library created and pushed."
    echo "Script ID (copy this into wrapper/appsscript.json):"
    grep '"scriptId"' .clasp.json | sed 's/.*: *"\(.*\)".*/\1/'
    ;;

  new)
    TMP=$(mktemp -d)
    cd "$TMP"
    if [ -n "$2" ]; then
      clasp create --type sheets --parentId "$2" --title "Prohibited Activity Logs"
    else
      clasp create --type sheets --title "Prohibited Activity Logs"
    fi
    # Copy AFTER clasp create — it clones a default appsscript.json which would
    # overwrite ours if copied beforehand, stripping the webapp block and library dep.
    cp "$REPO_DIR/wrapper/appsscript.json" "$TMP/"
    cp "$REPO_DIR/wrapper/doPost.js" "$TMP/"
    clasp push
    DEPLOYMENT_ID=$(clasp deploy --description "initial" | grep -o 'AKfycb[^ ]*')

    # Save deployment info so 'redeploy' can update it in-place later.
    mkdir -p "$DEPLOYMENTS_DIR"
    SCRIPT_ID=$(grep '"scriptId"' .clasp.json | sed 's/.*: *"\(.*\)".*/\1/')
    RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
    printf '{\n  "scriptId": "%s",\n  "deploymentId": "%s"\n}\n' \
      "$SCRIPT_ID" "$DEPLOYMENT_ID" > "$RECORD"

    _print_exec_url "$DEPLOYMENT_ID"
    ;;

  redeploy)
    if [ -z "$2" ]; then
      echo "Usage: $0 redeploy <DEPLOYMENT_ID>"
      echo ""
      echo "Known deployments:"
      ls "$DEPLOYMENTS_DIR"/*.json 2>/dev/null | while read f; do
        echo "  $(basename "$f" .json)"
      done
      exit 1
    fi
    DEPLOYMENT_ID="$2"
    RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
    if [ ! -f "$RECORD" ]; then
      echo "Error: no saved record for deployment $DEPLOYMENT_ID"
      echo "Check the deployments/ directory or use 'new' to create a fresh deployment."
      exit 1
    fi
    SCRIPT_ID=$(grep '"scriptId"' "$RECORD" | sed 's/.*: *"\(.*\)".*/\1/')

    TMP=$(mktemp -d)
    cp "$REPO_DIR/wrapper/appsscript.json" "$TMP/"
    cp "$REPO_DIR/wrapper/doPost.js" "$TMP/"
    printf '{\n  "scriptId": "%s",\n  "rootDir": "."\n}\n' "$SCRIPT_ID" > "$TMP/.clasp.json"
    cd "$TMP"
    clasp push
    clasp deploy --deploymentId "$DEPLOYMENT_ID" --description "update"

    _print_exec_url "$DEPLOYMENT_ID"
    echo "(Same exec URL as before — no need to update config.json)"
    ;;

  delete)
    if [ -z "$2" ]; then
      echo "Usage: $0 delete <DEPLOYMENT_ID>"
      echo ""
      echo "Known deployments:"
      ls "$DEPLOYMENTS_DIR"/*.json 2>/dev/null | while read f; do
        echo "  $(basename "$f" .json)"
      done
      exit 1
    fi
    DEPLOYMENT_ID="$2"
    RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
    if [ ! -f "$RECORD" ]; then
      echo "Error: no saved record for deployment $DEPLOYMENT_ID"
      exit 1
    fi
    SCRIPT_ID=$(grep '"scriptId"' "$RECORD" | sed 's/.*: *"\(.*\)".*/\1/')

    TMP=$(mktemp -d)
    printf '{\n  "scriptId": "%s",\n  "rootDir": "."\n}\n' "$SCRIPT_ID" > "$TMP/.clasp.json"
    cd "$TMP"
    clasp undeploy "$DEPLOYMENT_ID"
    rm "$RECORD"
    echo "Deployment $DEPLOYMENT_ID removed."
    ;;

  update-library)
    cd "$REPO_DIR/library"
    clasp push
    echo ""
    echo "Library updated. All wrappers using version 0 (HEAD) will use the new code."
    ;;

  *)
    echo "Usage:"
    echo "  $0 setup-library                  — first-time library creation"
    echo "  $0 new [SPREADSHEET_ID]           — deploy to new or existing spreadsheet"
    echo "  $0 redeploy <DEPLOYMENT_ID>       — update wrapper in-place, keep same exec URL"
    echo "  $0 delete <DEPLOYMENT_ID>         — remove a prior deployment"
    echo "  $0 update-library                 — push Prohibition.js changes to library"
    exit 1
    ;;

esac
