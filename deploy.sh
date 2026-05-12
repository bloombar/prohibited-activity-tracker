#!/bin/bash
#
# Deploy helper for prohibited_activity_tracker.
#
# Commands:
#   ./deploy.sh setup-library
#       Creates the Apps Script library project on Google Drive, pushes
#       Prohibition.js, and saves the Script ID to .env as LIBRARY_SCRIPT_ID.
#       Run once per machine after 'clasp login'.
#
#   ./deploy.sh new [NAME] [FOLDER_ID]
#       Creates a new spreadsheet and bound Apps Script (both named NAME,
#       defaulting to "Prohibited Activity Logs"), optionally inside FOLDER_ID
#       on Drive. Pushes the wrapper, deploys it as a web app, saves the
#       deployment ID to deployments/, and prints the exec URL to paste into
#       the course repo's .automations/config.json.
#
#   ./deploy.sh redeploy <DEPLOYMENT_ID>
#       Pushes the current wrapper files to an existing deployment, keeping
#       the same exec URL. Use this instead of 'new' when updating a wrapper
#       that is already in production.
#
#   ./deploy.sh delete <DEPLOYMENT_ID>
#       Removes a prior web app deployment from Google Apps Script and deletes
#       its saved record from deployments/. The exec URL stops working immediately.
#
#   ./deploy.sh finalize <SCRIPT_ID> [NAME]
#       Pushes wrapper files to an existing Apps Script project that was already
#       created (e.g. by a failed 'new' run), deploys it as a web app, and saves
#       the deployment record. Use this to recover from a partial 'new' failure.
#
#   ./deploy.sh update-library
#       Pushes local changes to Prohibition.js to the library project.
#       All wrapper scripts using version "0" (HEAD) pick up the change
#       automatically on next execution.

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENTS_DIR="$REPO_DIR/deployments"

# Load .env if present — sets LIBRARY_SCRIPT_ID and any other local vars.
ENV_FILE="$REPO_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# Verify clasp is authenticated before running any command.
if [ ! -f "$HOME/.clasprc.json" ]; then
  echo "Error: clasp credentials not found."
  echo "Run 'clasp login' first, then retry."
  exit 1
fi

# Require LIBRARY_SCRIPT_ID to be set (from .env or environment).
_require_library_script_id() {
  if [ -z "$LIBRARY_SCRIPT_ID" ]; then
    echo "Error: LIBRARY_SCRIPT_ID is not set."
    echo "Either run './deploy.sh setup-library' first, or add it to .env"
    echo "  LIBRARY_SCRIPT_ID=your_script_id_here"
    exit 1
  fi
}

# Write library/.clasp.json from LIBRARY_SCRIPT_ID (file is gitignored).
_write_library_clasp_json() {
  printf '{\n  "scriptId": "%s",\n  "rootDir": "."\n}\n' \
    "$LIBRARY_SCRIPT_ID" > "$REPO_DIR/library/.clasp.json"
}

# Copy wrapper files to TMP, substituting the real Script ID into appsscript.json.
_copy_wrapper() {
  local dest="$1"
  sed "s/LIBRARY_SCRIPT_ID_PLACEHOLDER/$LIBRARY_SCRIPT_ID/g" \
    "$REPO_DIR/wrapper/appsscript.json" > "$dest/appsscript.json"
  cp "$REPO_DIR/wrapper/doPost.js" "$dest/"
}

# Save or update a key=value line in .env.
_set_env_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    TMP_ENV=$(mktemp)
    sed "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" > "$TMP_ENV"
    mv "$TMP_ENV" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

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
    clasp push --force
    LIBRARY_SCRIPT_ID=$(grep '"scriptId"' .clasp.json | sed 's/.*: *"\(.*\)".*/\1/')
    _set_env_var "LIBRARY_SCRIPT_ID" "$LIBRARY_SCRIPT_ID"
    echo ""
    echo "Library created and pushed."
    echo "Script ID saved to .env as LIBRARY_SCRIPT_ID:"
    echo ""
    echo "  $LIBRARY_SCRIPT_ID"
    ;;

  new)
    _require_library_script_id
    SHEET_TITLE="${2:-Prohibited Activity Logs}"
    FOLDER_ID="${3:-}"
    TMP=$(mktemp -d)
    cd "$TMP"
    # Capture both stdout and stderr — newer clasp versions write to stderr.
    if [ -n "$FOLDER_ID" ]; then
      CREATE_OUTPUT=$(clasp create --type sheets --parentId "$FOLDER_ID" --title "$SHEET_TITLE" 2>&1)
    else
      CREATE_OUTPUT=$(clasp create --type sheets --title "$SHEET_TITLE" 2>&1)
    fi
    echo "$CREATE_OUTPUT"

    # Abort early if clasp create did not produce a .clasp.json (e.g. bad folder ID).
    if [ ! -f ".clasp.json" ]; then
      echo ""
      echo "Error: clasp create failed — .clasp.json was not created."
      echo "If you passed a FOLDER_ID, verify it is a valid Google Drive folder ID."
      exit 1
    fi

    # clasp create prints the document as a Drive URL: https://drive.google.com/open?id=<ID>
    # Extract the file ID and build a direct spreadsheet URL.
    SHEET_FILE_ID=$(echo "$CREATE_OUTPUT" | grep -o 'open?id=[^ ]*' | sed 's/open?id=//' || true)
    if [ -n "$SHEET_FILE_ID" ]; then
      SHEET_URL="https://docs.google.com/spreadsheets/d/${SHEET_FILE_ID}/edit"
    else
      SHEET_URL=""
    fi

    # clasp ignores --parentId for sheet-bound scripts; move the file via Drive API.
    if [ -n "$FOLDER_ID" ] && [ -n "$SHEET_FILE_ID" ]; then
      python3 - "$SHEET_FILE_ID" "$FOLDER_ID" <<'PYEOF'
import json, sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError

file_id, folder_id = sys.argv[1], sys.argv[2]
try:
    creds = json.loads(Path.home().joinpath('.clasprc.json').read_text())
    token = creds['token']['access_token']
except Exception as e:
    print(f"Warning: could not read clasp credentials: {e}")
    sys.exit(0)

headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
base = 'https://www.googleapis.com/drive/v3/files'
try:
    req = Request(f'{base}/{file_id}?fields=parents', headers={'Authorization': f'Bearer {token}'})
    old_parents = ','.join(json.loads(urlopen(req).read()).get('parents', []))
    url = f'{base}/{file_id}?addParents={folder_id}'
    if old_parents:
        url += f'&removeParents={old_parents}'
    urlopen(Request(url, data=b'{}', method='PATCH', headers=headers))
    print(f"Spreadsheet moved to folder {folder_id}.")
except URLError as e:
    print(f"Warning: could not move spreadsheet to folder: {e}")
    print("The deployment will continue; move the file manually in Google Drive if needed.")
PYEOF
    fi
    SCRIPT_ID=$(grep '"scriptId"' .clasp.json | sed 's/.*: *"\(.*\)".*/\1/')

    # Copy AFTER clasp create — it clones a default appsscript.json which would
    # overwrite ours if copied beforehand, stripping the webapp block and library dep.
    _copy_wrapper "$TMP"
    echo "Pushing files: $(ls -1 "$TMP" | grep -v '^\.' | tr '\n' ' ')"
    clasp push --force
    DEPLOY_OUTPUT=$(clasp deploy --description "initial" 2>&1)
    echo "$DEPLOY_OUTPUT"
    DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -o 'AKfycb[^ ]*' || true)
    if [ -z "$DEPLOYMENT_ID" ]; then
      echo ""
      echo "Error: could not extract deployment ID from clasp output above."
      echo "The script project was created with ID: $SCRIPT_ID"
      echo "To complete the deployment manually, run:"
      echo "  ./deploy.sh finalize $SCRIPT_ID \"$SHEET_TITLE\""
      exit 1
    fi

    # Save deployment info so 'redeploy' can update it in-place later.
    mkdir -p "$DEPLOYMENTS_DIR"
    RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
    printf '{\n  "scriptId": "%s",\n  "deploymentId": "%s",\n  "title": "%s",\n  "folderId": "%s",\n  "sheetUrl": "%s"\n}\n' \
      "$SCRIPT_ID" "$DEPLOYMENT_ID" "$SHEET_TITLE" "$FOLDER_ID" "$SHEET_URL" > "$RECORD"

    _print_exec_url "$DEPLOYMENT_ID"
    ;;

  finalize)
    _require_library_script_id
    if [ -z "$2" ]; then
      echo "Usage: $0 finalize <SCRIPT_ID> [NAME]"
      exit 1
    fi
    SCRIPT_ID="$2"
    SHEET_TITLE="${3:-Prohibited Activity Logs}"
    TMP=$(mktemp -d)
    _copy_wrapper "$TMP"
    printf '{\n  "scriptId": "%s",\n  "rootDir": "."\n}\n' "$SCRIPT_ID" > "$TMP/.clasp.json"
    cd "$TMP"
    echo "Pushing files: $(ls -1 "$TMP" | grep -v '^\.' | tr '\n' ' ')"
    clasp push --force
    DEPLOY_OUTPUT=$(clasp deploy --description "initial" 2>&1)
    echo "$DEPLOY_OUTPUT"
    DEPLOYMENT_ID=$(echo "$DEPLOY_OUTPUT" | grep -o 'AKfycb[^ ]*' || true)
    if [ -z "$DEPLOYMENT_ID" ]; then
      echo ""
      echo "Error: could not extract deployment ID from clasp output above."
      exit 1
    fi
    mkdir -p "$DEPLOYMENTS_DIR"
    RECORD="$DEPLOYMENTS_DIR/${DEPLOYMENT_ID}.json"
    printf '{\n  "scriptId": "%s",\n  "deploymentId": "%s",\n  "title": "%s",\n  "folderId": "",\n  "sheetUrl": ""\n}\n' \
      "$SCRIPT_ID" "$DEPLOYMENT_ID" "$SHEET_TITLE" > "$RECORD"
    _print_exec_url "$DEPLOYMENT_ID"
    ;;

  redeploy)
    _require_library_script_id
    if [ -z "$2" ]; then
      echo "Usage: $0 redeploy <DEPLOYMENT_ID>"
      echo ""
      echo "Known deployments:"
      ls "$DEPLOYMENTS_DIR"/*.json 2>/dev/null | while read f; do
        title=$(grep '"title"' "$f" | sed 's/.*: *"\(.*\)".*/\1/')
        echo "  $(basename "$f" .json)  ($title)"
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
    _copy_wrapper "$TMP"
    printf '{\n  "scriptId": "%s",\n  "rootDir": "."\n}\n' "$SCRIPT_ID" > "$TMP/.clasp.json"
    cd "$TMP"
    clasp push --force
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
    _require_library_script_id
    _write_library_clasp_json
    cd "$REPO_DIR/library"
    clasp push --force
    echo ""
    echo "Library updated. All wrappers using version \"0\" (HEAD) will use the new code."
    ;;

  *)
    echo "Usage:"
    echo "  $0 setup-library                  — first-time library creation, saves ID to .env"
    echo "  $0 new [NAME] [FOLDER_ID]         — deploy; NAME sets both sheet and script title"
    echo "  $0 finalize <SCRIPT_ID> [NAME]    — push + deploy an already-created script project
  $0 redeploy <DEPLOYMENT_ID>       — update wrapper in-place, keep same exec URL"
    echo "  $0 delete <DEPLOYMENT_ID>         — remove a prior deployment"
    echo "  $0 update-library                 — push Prohibition.js changes to library"
    exit 1
    ;;

esac
