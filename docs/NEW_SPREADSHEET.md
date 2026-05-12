# Deploying to a New Spreadsheet

Run this once per course. Each deployment creates one Google Spreadsheet and one bound Apps Script project, then publishes the script as a web app.

## Command

```bash
./deploy.sh new [NAME] [FOLDER_ID]
```

Both arguments are optional:

| Invocation                                           | Effect                                                                  |
| ---------------------------------------------------- | ----------------------------------------------------------------------- |
| `./deploy.sh new`                                    | Creates spreadsheet named "Prohibited Activity Logs" in your Drive root |
| `./deploy.sh new "Web Design Fall 2026"`             | Custom name, Drive root                                                 |
| `./deploy.sh new "Web Design Fall 2026" <FOLDER_ID>` | Custom name, specific Drive folder                                      |

`FOLDER_ID` is the ID from a Google Drive folder URL:
`https://drive.google.com/drive/folders/<FOLDER_ID>`

The NAME is applied to both the spreadsheet and the Apps Script project.

## After running the command

The script prints an exec URL:

```
Exec URL (paste into your course repo's .automations/config.json):

  https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec
```

Paste this into the course repo's [.automations/config.json](../examples/.automations/config.json):

```json
{
  "comment": "DO NOT MODIFY THIS FILE!",
  "url": "https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec"
}
```

The exec URL (ending in `/exec`) is permanent for this deployment — it does not change when you push code updates via `redeploy`.

## Authorize the web app (first access only)

The first time the web app receives a request, Google requires the deploying account
to grant OAuth consent for the Sheets scope. To trigger this:

1. Open the newly created Apps Script project at [script.google.com](https://script.google.com)
2. Select **Run → Run function → doPost** (or any function)
3. A permissions dialog will appear — click **Review permissions**, choose your Google account, and click **Allow**

Once authorized, all incoming POST requests are handled automatically with no further interaction.

## One deployment = one spreadsheet

A deployment is permanently bound to the spreadsheet that was created with it. There is no way to rebind it to a different spreadsheet. This is by design — each course or semester gets its own spreadsheet and its own exec URL in `config.json`.

## Redeploying wrapper code

If you change `wrapper/doPost.js` or `wrapper/appsscript.json` (but not the library logic), update an existing deployment in-place without changing the exec URL:

```bash
./deploy.sh redeploy <DEPLOYMENT_ID>
```

To see known deployment IDs:

```bash
ls deployments/
```

## Deleting a deployment

To permanently remove a deployment and stop its exec URL from working:

```bash
./deploy.sh delete <DEPLOYMENT_ID>
```

## What happens under the hood

1. `deploy.sh` creates a temp directory and runs `clasp create --type sheets`, which
   creates both a new Google Spreadsheet and a bound Apps Script project.
2. After `clasp create`, `wrapper/doPost.js` and `wrapper/appsscript.json` are copied
   in (they must be copied after, or `clasp create` overwrites them with defaults).
3. `clasp push` uploads the wrapper files to the new script project.
4. `clasp deploy` publishes a web app deployment accessible to anyone anonymously.
5. The deployment ID and script ID are saved to `deployments/<DEPLOYMENT_ID>.json`
   so future `redeploy` and `delete` commands can target them.

The wrapper's `doPost` function gets a reference to the bound spreadsheet via
`SpreadsheetApp.getActiveSpreadsheet()` and passes it to `Prohibition.doPost(e, ss)`.
The library cannot call `getActiveSpreadsheet()` itself — this handoff is why the
wrapper exists.

## Troubleshooting

- **"No credentials found"**: run `clasp login` first.
- **Library Script ID missing**: complete the one-time setup in [SETUP.md](SETUP.md)
  and paste the Script ID into `wrapper/appsscript.json` before deploying.
- **No rows appearing after a POST**: check the execution logs — in the spreadsheet,
  go to **Extensions → Apps Script → Executions**. If executions appear but no rows
  were written, the script may be writing to the wrong sheet name; check `logsSheetName`
  in `getConfig()` inside `library/Prohibition.js`.
- **403 / permission error on the exec URL**: the web app's access is set to
  "Anyone, even anonymous" in `wrapper/appsscript.json`. If you see 403, the
  authorization step above was not completed — open the script and run any function
  to trigger the OAuth consent flow.
