# One-Time Setup

Perform these steps once per machine, and once ever for the library itself.

## Prerequisites

You need Node.js installed. Then install the clasp CLI:

```bash
npm install -g @google/clasp
```

Authenticate clasp with your Google account (opens a browser window):

```bash
clasp login
```

## Create and deploy the library

Run the setup command from the repo root:

```bash
./deploy.sh setup-library
```

This does three things automatically:

1. Creates a new standalone Apps Script project on your Google Drive titled
   "Prohibition Activity Tracker Library"
2. Pushes `library/Prohibition.js` and `library/appsscript.json` to it
3. Prints the Script ID

**After it runs**, copy the Script ID into `wrapper/appsscript.json`, replacing the
placeholder:

```json
{
  "dependencies": {
    "libraries": [
      {
        "userSymbol": "Prohibition",
        "scriptId": "PASTE_SCRIPT_ID_HERE",
        ...
      }
    ]
  }
}
```

Commit that change so future deployments use the correct library.

## What "version 0" means

The wrapper references the library at `"version": 0`, which means **HEAD** — always
the latest pushed version of `Prohibition.js`. This is convenient for active development.
If you need stability across many deployed sheets, change `0` to a specific version
number after running `clasp version "description"` in the `library/` directory.

## Verify the library is reachable

In the Apps Script console (script.google.com), open the library project.
Under **Project Settings**, confirm the Script ID matches what is in
`library/.clasp.json` and `wrapper/appsscript.json`.
