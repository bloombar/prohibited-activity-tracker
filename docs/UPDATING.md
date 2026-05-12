# Updating Prohibition.js

When you need to change the script logic — add a payload field, rename a column,
fix a bug — edit `library/Prohibition.js` and push it. All deployed spreadsheets
pick up the change automatically on their next incoming request.

## Steps

1. Edit `library/Prohibition.js`.

2. If you added or renamed logged fields, update `logsSheetFields` in `getConfig()`
   within the same file. The row builder maps each incoming payload key to the column
   list automatically, so adding a name there is sufficient.

3. Push the changes to the library:

   ```bash
   ./deploy.sh update-library
   ```

4. Done. Wrappers using `"version": "0"` (HEAD) execute the new code on their next
   incoming POST. No redeployment of individual spreadsheet wrappers is needed.

## Updating wrapper code

If you change `wrapper/doPost.js` or `wrapper/appsscript.json` (not just library
logic), you must redeploy each affected wrapper individually, because those files
live in the bound script — not the library.

```bash
./deploy.sh redeploy <DEPLOYMENT_ID>
```

The exec URL stays the same after a redeploy; no need to update `config.json` in
course repos.

To see all known deployment IDs:

```bash
ls deployments/
```

## Payload fields

The fields sent by `give-student-credit.py` and logged by `Prohibition.js`:

| Field | Source |
| ----- | ------ |
| `date` | ISO 8601 timestamp at time of hook |
| `repository` | `git remote.origin.url` or local path |
| `username` | `git user.name` → env vars → OS user |
| `email` | `git user.email` → env vars |
| `tool` | AI tool name: `claude`, `cursor`, or `copilot` |
| `event` | Hook event: `PostToolUse`, `afterFileEdit`, `afterTabFileEdit`, `postToolUse` |
| `machine` | `socket.gethostname()` |
| `machine_user` | `getpass.getuser()` (OS login name, cross-platform) |
| `hook_integrity` | SHA-256 prefixes of hook config files |

To add a new field: add it to `give-student-credit.py`'s payload dict, then add its
key to `logsSheetFields` in `getConfig()` in `library/Prohibition.js`, then run
`./deploy.sh update-library`.

## Pinning a version (optional)

By default all wrappers use `"version": "0"` (always the latest pushed library code).
If you want some sheets to stay on a stable version while you develop changes:

```bash
cd library
clasp version "v2 - added machine_user field"
```

Then set the version number printed by that command in `wrapper/appsscript.json`
before running `./deploy.sh new` for those sheets. Sheets already deployed continue
using whatever version is in their own `appsscript.json`.
