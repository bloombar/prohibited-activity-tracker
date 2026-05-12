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
Apps Script wrapper (bound to the spreadsheet) delegates to this library
        ↓
Prohibition.js logs the row into the sheet
```

The library is deployed once and shared across all course spreadsheets. Each spreadsheet
has a tiny bound wrapper script (3 lines) that calls the library. Updating the library
propagates to all sheets automatically.

## Prerequisites

```bash
npm install -g @google/clasp
clasp login
```

## Quick reference

| Task | Command |
| ---- | ------- |
| First-time library setup | `./deploy.sh setup-library` |
| Add a new course spreadsheet | `./deploy.sh new [SPREADSHEET_ID]` |
| Push a Prohibition.js update | `./deploy.sh update-library` |

## Repository layout

```
library/          Prohibition.js library — the source of truth
  Prohibition.js  Script logic (getConfig, getSheet, doPost)
  appsscript.json Apps Script manifest (no webapp block — library only)
  .clasp.json     clasp config (fill in scriptId after setup-library)

wrapper/          Template for each spreadsheet's bound script
  doPost.js       One-line delegator: Prohibition.doPost(e)
  appsscript.json Webapp config + library dependency (fill in scriptId)

deploy.sh         Automation helper
docs/             Full documentation
  SETUP.md        One-time setup walkthrough
  NEW_SPREADSHEET.md  Per-sheet deployment workflow
  UPDATING.md     How to push Prohibition.js changes
```

## Detailed docs

- [One-time setup](docs/SETUP.md)
- [Deploying to a new spreadsheet](docs/NEW_SPREADSHEET.md)
- [Updating Prohibition.js](docs/UPDATING.md)
