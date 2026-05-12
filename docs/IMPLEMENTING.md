# Example Files for Student Repositories

The [/examples](../examples/) directory contains the files you need to drop into each student course repository to enable AI tool tracking. When a student uses Claude Code, Cursor, or GitHub Copilot to edit a file, a hook fires automatically and logs the event to your Google Spreadsheet.

## Directory structure

```
.automations/
  config.json             URL of the Apps Script web app for this course
  give-student-credit.py  Tracking script called by every editor hook
  README.txt              Student-facing notice (do not modify)

.claude/
  settings.json           Claude Code PostToolUse hook

.cursor/
  hooks.json              Cursor afterFileEdit and afterTabFileEdit hooks
  README.txt              Student-facing notice (do not modify)

.github/
  hooks/
    hooks.json            GitHub Copilot postToolUse hook
    README.txt            Student-facing notice (do not modify)
```

## Before you copy these files

1. **[Deploy a spreadsheet](./NEW_SPREADSHEET.md)** for the course using `deploy.sh` from the repo root:

   ```bash
   ./deploy.sh new "Course Name Semester Year"
   ```

2. **Authorize the web app.** After the first deployment, open the newly created Apps
   Script project at [script.google.com](https://script.google.com), run any function,
   and complete the OAuth consent dialog. This only needs to be done once per deployment.

3. **Copy the exec URL** printed by `deploy.sh` into [.automations/config.json](../examples/.automations/config.json),
   replacing the placeholder:

   ```json
   {
     "comment": "DO NOT MODIFY THIS FILE!",
     "url": "https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID_HERE/exec"
   }
   ```

## Adding the files to a student repository

Copy the four directories into the root of the student repository, then commit and push:

```bash
cp -r examples/.automations  /path/to/student-repo/
cp -r examples/.claude        /path/to/student-repo/
cp -r examples/.cursor        /path/to/student-repo/
cp -r examples/.github        /path/to/student-repo/

cd /path/to/student-repo
git add .automations .claude .cursor .github
git commit -m "Add instructor automations"
git push
```

If the repository uses a template or is created from a GitHub Classroom assignment, you can add these files to the template repository instead so every student fork receives them automatically.

## Keeping the files intact

Students are instructed via the `README.txt` files in each of these directories not to modify these files.
The tracking script also computes a SHA-256 hash of each hook file on every run and logs it alongside the activity record, so any tampering is detectable - you can compare the hash of your copy to the hash logged with each row of student's data to see whether they modified any of these tracking scripts.

## Updating the tracking script

If you update `library/Prohibition.js` (the Apps Script library), run:

```bash
./deploy.sh update-library
```

All deployed spreadsheets pick up the change automatically — no need to re-copy files into student repositories. See [./UPDATING.md](./UPDATING.md) for details.

If you update `give-student-credit.py` or any of the hook config files, copy the new versions into each student repository and push the changes.
