# Updating Prohibition.js

When you need to change the script logic (e.g. add a new payload field, rename a column,
fix a bug), edit `library/Prohibition.js` in this repo and push it. All deployed
spreadsheets pick up the change automatically.

## Steps

1. Edit `library/Prohibition.js`.

2. If you added or renamed fields, also update `logsSheetFields` in `getConfig()` and
   the JSDoc comment in `doPost()` within the same file.

3. Push the changes to the library:

   ```bash
   ./deploy.sh update-library
   ```

4. That's it. Wrappers using `"version": 0` (HEAD) execute the new code on their next
   incoming POST request. No redeployment of individual spreadsheet wrappers is needed.

## Payload fields

The payload fields sent by `give-student-credit.py` and logged by `Prohibition.js` are:

| Field          | Source                                      |
| -------------- | ------------------------------------------- |
| `date`         | ISO 8601 timestamp at time of hook          |
| `repository`   | `git remote.origin.url` or local path       |
| `username`     | `git user.name` → env vars → OS user        |
| `email`        | `git user.email` → env vars                 |
| `tool`         | AI tool: `claude`, `cursor`, or `copilot`   |
| `event`        | Hook event: `PostToolUse`, `afterFileEdit`, `afterTabFileEdit`, `postToolUse` |
| `machine`      | `socket.gethostname()`                      |
| `machine_user` | `getpass.getuser()` (OS login name)         |
| `hook_integrity` | SHA-256 prefixes of hook config files     |

If you add a new field to `give-student-credit.py`, add its name to `logsSheetFields`
in `getConfig()` — the row builder picks it up automatically.

## Adding a pinned version (optional)

If you want some spreadsheets to stay on a stable version while you develop changes:

```bash
cd library
clasp version "v2 - added machine_user field"
```

Then update `wrapper/appsscript.json` to use the printed version number instead of `0`
before running `./deploy.sh new` for those sheets.
