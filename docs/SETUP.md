# One-Time Setup

Perform these steps once per machine, and once ever for the library itself.

## 1. Install clasp and authenticate

You need Node.js installed. Then install the clasp CLI and authenticate:

```bash
npm install -g @google/clasp
clasp login          # opens a browser — sign in with your Google account
```

`clasp login` writes credentials to `~/.clasprc.json`. This is a one-time step per
machine; all future `deploy.sh` calls use those credentials automatically.

## 2. Create and deploy the library

Run this from the repo root:

```bash
./deploy.sh setup-library
```

This does four things automatically:

1. Creates a new standalone Apps Script project on your Google Drive titled
   "Prohibition Activity Tracker Library"
2. Pushes `library/Prohibition.js` and `library/appsscript.json` to it
3. Writes `LIBRARY_SCRIPT_ID=<id>` into a local `.env` file (gitignored)
4. Prints the Script ID for reference

Output looks like:

```
Library created and pushed.
Script ID saved to .env as LIBRARY_SCRIPT_ID:

  1_tdlX4gOk_jkb9guKpe6OB9HHMQPflz1lizNLXBRVSkDi7IG-DrSYT6q
```

From this point on, every `deploy.sh` command reads `LIBRARY_SCRIPT_ID` from `.env`
automatically. No manual copy-pasting of the Script ID is needed.

## Setting up on a second machine

If you clone this repo onto another machine after the library already exists:

1. Run `clasp login`
2. Copy `.env` from the original machine (or create it manually):

```dotenv
LIBRARY_SCRIPT_ID=your_existing_script_id_here
```

All `deploy.sh` commands will then work as normal.

## What "version 0" means

`"version": "0"` means **HEAD** — always the latest pushed version of `Prohibition.js`.
This is the right default during active development. If you need a subset of sheets to
stay on a stable version while you develop changes, see [UPDATING.md](UPDATING.md).

## Verify the library is reachable

In the Apps Script console at [script.google.com](https://script.google.com), open the
library project. Under **Project Settings**, confirm the Script ID matches what is in
`library/.clasp.json` and `wrapper/appsscript.json`.
