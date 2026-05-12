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

3. **Note the deployment ID** printed by `deploy.sh` — it looks like `AKfycb...` and
   is also the filename (without `.json`) of the record saved in `deployments/`.

## Adding the files to a student repository

Use `implement.sh` to copy the automation files into a repository in one step:

```bash
./implement.sh <DEPLOYMENT_ID> <REPOSITORY_URL>
```

For example:

```bash
./implement.sh AKfycbzFfk9cHh... https://github.com/org/student-repo.git
```

The script clones the repository, copies all files from `examples/` into the repo root, substitutes the real exec URL into `.automations/config.json`, commits, pushes, and removes all temporary files. If the automation files are already present and up to date, the script exits cleanly with no commit.

### Adding to a GitHub Classroom template repository

If you use GitHub Classroom, run `implement.sh` once against the template repository instead. Every student fork will receive the files automatically at assignment acceptance:

```bash
./implement.sh <DEPLOYMENT_ID> https://github.com/org/template-repo.git
```

### Manual alternative

If you prefer to copy the files by hand, copy each directory into the student repo root, then edit `.automations/config.json` to replace `YOUR_DEPLOYMENT_ID_HERE` with the actual deployment ID before committing:

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
