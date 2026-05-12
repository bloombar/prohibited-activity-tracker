# Prohibited Activity Tracker

Tracks student use of AI coding tools (Claude Code, Cursor, GitHub Copilot) by logging
hook events to a Google Spreadsheet via a Google Apps Script web app.

## How it works

The Google Apps Script library contained in this repository is set up once as a Library withn Google Apps Scripts. That Library can be then imported into as many course-specific spreadsheets as desired. Updating the library implements the update across all spreadsheets using it. Setting up the library and attaching it to spreadsheets is handled through a simple `./deploy.sh` script included in this repository.

The flow once the Library has been [setup](docs/SETUP.md), [imported into a Google Sheet](docs/NEW_SPREADSHEET.md) and associated tracking code [added to student repostories](docs/IMPLEMENTING.md):

1. Student edits a file directly with an agentic AI tool.
2. Editor hook fires [give-student-credit.py](./examples/.automations/give-student-credit.py) (a Python script placed into the student's repo by the instructor)
3. The script sends a POST request including a JSON payload to the Google Apps Script "wrapper" bound to the spreadsheet.
4. The Apps Script wrapper invokes the library, which handles the logic.
5. The Library logs the data received in the POST request as a new row into the sheet for the instructor to later review.

## Prerequisites

```bash
npm install -g @google/clasp
clasp login
```

## Quick reference

Run `./deploy.sh` to see command line arguments:

```txt
Usage:
  ./deploy.sh setup-library                  — first-time library creation, saves ID to .env... do it once.
  ./deploy.sh update-library                 — push Prohibition.js changes to library... do only if library code changed
  ./deploy.sh new [NAME] [FOLDER_ID]         — deploy; NAME sets both sheet and script title... do once per course
  ./deploy.sh redeploy <DEPLOYMENT_ID>       — update wrapper in-place, keep same exec URL... do only if wrapper code changed
  ./deploy.sh delete <DEPLOYMENT_ID>         — remove a prior deployment
```

To summarize:

| Task                         | Command                                |
| ---------------------------- | -------------------------------------- |
| First-time library setup     | `./deploy.sh setup-library`            |
| New course spreadsheet       | `./deploy.sh new [NAME] [FOLDER_ID]`   |
| Update wrapper code in-place | `./deploy.sh redeploy <DEPLOYMENT_ID>` |
| Delete a deployment          | `./deploy.sh delete <DEPLOYMENT_ID>`   |
| Push a Prohibition.js update | `./deploy.sh update-library`           |

Each `./deploy.sh new` creates one spreadsheet and one bound Apps Script. Run it once per course; each deployment has its own `exec` URL that goes into that course repo's `.automations/config.json`.

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
- [Implementing the tracker](./docs/IMPLEMENTING.md) into student repositories so agentic AI use is tracked and logged.
