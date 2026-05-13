# Contributing

## Prerequisites

- Python 3.8+
- Node.js 18+ (for JavaScript tests)
- pip, or pipenv if you prefer managed virtual environments

## Cloning the repo

```bash
git clone <repo-url>
cd prohibited-activity-tracker
```

## Setting up Python tests

Choose either pip/venv or pipenv.

### Option A — pip + venv

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
```

### Option B — pipenv

```bash
pipenv install --dev
```

## Setting up JavaScript tests

```bash
npm install
```

## Running tests

### Python

```bash
# pip/venv
pytest tests/test_give_student_credit.py -v --cov --cov-report=term-missing

# pipenv
pipenv run pytest tests/test_give_student_credit.py -v --cov --cov-report=term-missing
```

### JavaScript

```bash
npm test
```

`npm test` runs Jest with `--coverage` and prints a per-file coverage table.

## Coverage

Both suites target 100% line coverage.

- Python coverage is configured in `.coveragerc`. The `if __name__ == "__main__":` guard
  is excluded as it is untestable when the module is imported.
- JavaScript coverage is collected by Jest from `library/` and `wrapper/`. The
  `typeof module !== "undefined"` export guards are marked `/* istanbul ignore next */`
  because the false branch only executes inside the Google Apps Script runtime.

## Project layout

```
library/          Google Apps Script library (core logic)
wrapper/          Thin web-app wrapper that delegates to the library
examples/         Template files distributed to student repositories
  .automations/   Python hook script fired by AI tool events
tests/            All test files
docs/             Documentation
```

## Making changes

- **`library/Prohibition.js`** — core server-side logic; has JavaScript tests in
  `tests/test_prohibition.test.js`.
- **`examples/.automations/give-student-credit.py`** — client hook; has Python tests in
  `tests/test_give_student_credit.py`.

After editing either file, re-run the relevant test suite and confirm coverage does not
drop before opening a pull request.
