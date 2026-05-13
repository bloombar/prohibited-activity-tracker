"use strict";

// GAS globals must be set before requiring modules that reference them at call time.
const mockAppendRow = jest.fn();
const mockSheet = { appendRow: mockAppendRow };

const mockTextOutput = { setMimeType: jest.fn().mockReturnThis() };
global.Logger = { log: jest.fn() };
global.ContentService = {
  createTextOutput: jest.fn().mockReturnValue(mockTextOutput),
  MimeType: { JSON: "application/json" },
};

const { getConfig, getSheet, doPost } = require("../library/Prohibition");

// ─── getConfig ────────────────────────────────────────────────────────────────

describe("getConfig", () => {
  it("returns an object with course, logsSheetName, and logsSheetFields", () => {
    const cfg = getConfig();
    expect(cfg).toHaveProperty("course");
    expect(cfg).toHaveProperty("logsSheetName");
    expect(Array.isArray(cfg.logsSheetFields)).toBe(true);
  });

  it("includes all nine expected field names", () => {
    const { logsSheetFields } = getConfig();
    const expected = [
      "date", "repository", "username", "email",
      "tool", "event", "machine", "machine_user", "hook_integrity",
    ];
    expect(logsSheetFields).toEqual(expected);
  });
});

// ─── getSheet ─────────────────────────────────────────────────────────────────

describe("getSheet", () => {
  it("returns the existing sheet when found by name", () => {
    const ss = { getSheetByName: jest.fn().mockReturnValue(mockSheet) };
    const result = getSheet(ss);
    expect(result).toBe(mockSheet);
    expect(ss.getSheetByName).toHaveBeenCalledWith(getConfig().logsSheetName);
  });

  it("creates a new sheet with a header row when none exists", () => {
    const insertSheet = jest.fn().mockReturnValue(mockSheet);
    const ss = {
      getSheetByName: jest.fn().mockReturnValue(null),
      insertSheet,
    };
    mockAppendRow.mockClear();

    const result = getSheet(ss);

    expect(insertSheet).toHaveBeenCalledWith(getConfig().logsSheetName);
    expect(mockAppendRow).toHaveBeenCalledWith(getConfig().logsSheetFields);
    expect(result).toBe(mockSheet);
  });
});

// ─── doPost ───────────────────────────────────────────────────────────────────

describe("doPost", () => {
  let ss;

  beforeEach(() => {
    ss = { getSheetByName: jest.fn().mockReturnValue(mockSheet) };
    mockAppendRow.mockClear();
    global.Logger.log.mockClear();
    global.ContentService.createTextOutput.mockClear();
    mockTextOutput.setMimeType.mockClear();
  });

  function makeEvent(data) {
    return { postData: { contents: JSON.stringify(data) } };
  }

  it("returns success:true and appends a row for a valid array payload", () => {
    const commit = {
      date: "2024-01-01T00:00:00",
      repository: "https://github.com/org/repo",
      username: "alice",
      email: "alice@test.com",
      tool: "claude",
      event: "PostToolUse",
      machine: "testhost",
      machine_user: "alice",
      hook_integrity: { "file.py": "abc123" },
    };
    const e = makeEvent([commit]);

    doPost(e, ss);

    expect(mockAppendRow).toHaveBeenCalledTimes(1);
    const row = mockAppendRow.mock.calls[0][0];
    expect(row).toEqual([
      commit.date, commit.repository, commit.username, commit.email,
      commit.tool, commit.event, commit.machine, commit.machine_user,
      commit.hook_integrity,
    ]);

    const jsonArg = global.ContentService.createTextOutput.mock.calls[0][0];
    const res = JSON.parse(jsonArg);
    expect(res.success).toBe(true);
    expect(res.type).toBe("post");
    expect(mockTextOutput.setMimeType).toHaveBeenCalledWith(
      global.ContentService.MimeType.JSON
    );
  });

  it("fills missing fields with empty string via ?? operator", () => {
    const e = makeEvent([{ tool: "cursor" }]);
    doPost(e, ss);

    const row = mockAppendRow.mock.calls[0][0];
    // All fields except "tool" should be empty string
    const cfg = getConfig();
    cfg.logsSheetFields.forEach((field, i) => {
      if (field === "tool") {
        expect(row[i]).toBe("cursor");
      } else {
        expect(row[i]).toBe("");
      }
    });
  });

  it("appends one row per commit when array has multiple entries", () => {
    const commits = [
      { tool: "claude", event: "PostToolUse" },
      { tool: "cursor", event: "afterFileEdit" },
    ];
    doPost(makeEvent(commits), ss);
    expect(mockAppendRow).toHaveBeenCalledTimes(2);
  });

  it("returns success:false and appends no rows for a non-array body", () => {
    const e = makeEvent({ tool: "claude" }); // object, not array
    doPost(e, ss);

    expect(mockAppendRow).not.toHaveBeenCalled();
    const jsonArg = global.ContentService.createTextOutput.mock.calls[0][0];
    const res = JSON.parse(jsonArg);
    expect(res.success).toBe(false);
  });
});

// ─── wrapper/doPost.js ────────────────────────────────────────────────────────

describe("wrapper doPost", () => {
  const mockSS = { getSheetByName: jest.fn().mockReturnValue(mockSheet) };
  const mockResponse = { setMimeType: jest.fn().mockReturnThis() };

  beforeEach(() => {
    global.SpreadsheetApp = {
      getActiveSpreadsheet: jest.fn().mockReturnValue(mockSS),
    };
    global.Prohibition = {
      doPost: jest.fn().mockReturnValue(mockResponse),
    };
  });

  it("delegates to Prohibition.doPost with the active spreadsheet", () => {
    const { doPost: wrapperDoPost } = require("../wrapper/doPost");
    const fakeEvent = { postData: { contents: "[]" } };

    const result = wrapperDoPost(fakeEvent);

    expect(global.SpreadsheetApp.getActiveSpreadsheet).toHaveBeenCalled();
    expect(global.Prohibition.doPost).toHaveBeenCalledWith(fakeEvent, mockSS);
    expect(result).toBe(mockResponse);
  });
});
