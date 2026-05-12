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
#       deploys it as a web app. Prints the exec URL to paste into
#       the course repo's .automations/config.json.
#
#   ./deploy.sh update-library
#       Pushes local changes to Prohibition.js to the library project.
#       All wrapper scripts using version 0 (HEAD) pick up the change
#       automatically on next execution.

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

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
    cp "$REPO_DIR/wrapper/appsscript.json" "$TMP/"
    cp "$REPO_DIR/wrapper/doPost.js" "$TMP/"
    cd "$TMP"
    if [ -n "$2" ]; then
      clasp create --type sheets --parentId "$2" --title "Prohibited Activity Logs"
    else
      clasp create --type sheets --title "Prohibited Activity Logs"
    fi
    clasp push
    clasp deploy --description "initial"
    echo ""
    echo "Copy the exec URL above into your course repo's .automations/config.json"
    ;;

  update-library)
    cd "$REPO_DIR/library"
    clasp push
    echo ""
    echo "Library updated. All wrappers using version 0 (HEAD) will use the new code."
    ;;

  *)
    echo "Usage:"
    echo "  $0 setup-library            — first-time library creation"
    echo "  $0 new [SPREADSHEET_ID]     — deploy to new or existing spreadsheet"
    echo "  $0 update-library           — push Prohibition.js changes to library"
    exit 1
    ;;

esac
