# Deploying to a New Spreadsheet

Run this command once per course or semester when you need a new tracking spreadsheet.

## Option A — Bind to an existing spreadsheet

If you already have a Google Sheet and just need the script attached to it, find its
ID from the URL (`https://docs.google.com/spreadsheets/d/<SPREADSHEET_ID>/edit`) and run:

```bash
./deploy.sh new <SPREADSHEET_ID>
```

## Option B — Create a new spreadsheet automatically

To have clasp create a fresh spreadsheet and bind the script to it in one step:

```bash
./deploy.sh new
```

## After running either command

The script prints an exec URL like:

```
https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec
```

Paste this URL into the course repo's `.automations/config.json`:

```json
{
  "comment": "DO NOT MODIFY THIS FILE!",
  "url": "https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec"
}
```

## What happens under the hood

1. `deploy.sh` copies `wrapper/doPost.js` and `wrapper/appsscript.json` to a temp
   directory.
2. `clasp create` creates a new Apps Script project bound to the spreadsheet.
3. `clasp push` uploads the wrapper files.
4. `clasp deploy` publishes a web app deployment accessible to anyone (anonymous).

The wrapper's `doPost` function delegates every call to the `Prohibition` library,
which reads and writes the bound spreadsheet via `SpreadsheetApp.getActiveSpreadsheet()`.

## Troubleshooting

- **"Script ID not found"** in the wrapper: make sure you completed the setup step
  and pasted the library Script ID into `wrapper/appsscript.json`.
- **Permission errors**: the web app runs as the deploying user (`USER_DEPLOYING`),
  so that Google account must have edit access to the spreadsheet.
- **No rows appearing**: check Apps Script execution logs — in the spreadsheet go to
  Extensions → Apps Script → Executions.
