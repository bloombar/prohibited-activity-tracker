# Prohibited Activity Tracker

Tracks student use of AI coding tools (Claude Code, Cursor, GitHub Copilot) by logging
hook events to a Google Spreadsheet via a Google Apps Script web app.

## How it works

```
Student edits a file with an AI tool
        ↓
Editor hook fires give-student-credit.py (in the course repo)
        ↓
Script POSTs a JSON payload to an Apps Script exec URL
        ↓
Apps Script wrapper (bound to the spreadsheet) passes the spreadsheet to this library
        ↓
Prohibition.js logs the row into the sheet
```

The library is deployed once and shared across all course spreadsheets. Each spreadsheet
has a tiny bound wrapper script that calls the library. Updating the library propagates
to all sheets automatically.

## Prerequisites

```bash
npm install -g @google/clasp
clasp login
```

## Quick reference

| Task                            | Command                                |
| ------------------------------- | -------------------------------------- |
| First-time library setup        | `./deploy.sh setup-library`            |
| New course/semester spreadsheet | `./deploy.sh new [NAME] [FOLDER_ID]`   |
| Update wrapper code in-place    | `./deploy.sh redeploy <DEPLOYMENT_ID>` |
| Delete a deployment             | `./deploy.sh delete <DEPLOYMENT_ID>`   |
| Push a Prohibition.js update    | `./deploy.sh update-library`           |

Each `./deploy.sh new` creates one spreadsheet and one bound Apps Script — this is
the correct granularity. Run it once per course or semester; each deployment has its
own exec URL that goes into that course repo's `.automations/config.json`.

## Repository layout

```
library/          Prohibition.js library — the source of truth
  Prohibition.js  Script logic (getConfig, getSheet, doPost)
  appsscript.json Apps Script manifest (no webapp block — library only)
  .clasp.json     clasp config pointing at the live library project

wrapper/          Template for each spreadsheet's bound script
  doPost.js       Thin delegator: passes spreadsheet ref to Prohibition.doPost
  appsscript.json Webapp config + library dependency

deploy.sh         Automation helper — run this for all deploy operations
deployments/      Auto-created; stores scriptId + deploymentId per deployment
docs/             Full documentation
  SETUP.md        One-time setup walkthrough
  NEW_SPREADSHEET.md  Per-sheet deployment workflow
  UPDATING.md     How to push Prohibition.js changes
```

## Detailed docs

- [One-time setup](docs/SETUP.md) of this library.
- [Updating the library as needed](docs/UPDATING.md) after it is set up.
- [Deploying a new spreadsheet](docs/NEW_SPREADSHEET.md) pre-set to use this library.
