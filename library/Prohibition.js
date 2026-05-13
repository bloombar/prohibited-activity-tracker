const getConfig = () => {
  /**
   * Global settings.
   * Should match name and fields of the container spreadsheet.
   * If no name match, a new sheet with the specified fields will be created.
   */
  return {
    course: "Intro to Web Design",
    logsSheetName: "Prohibited Activity Logs", // must match container sheet name
    logsSheetFields: [
      "date",
      "repository",
      "username",
      "email",
      "tool",
      "event",
      "machine",
      "machine_user",
      "hook_integrity",
    ], // must match container sheet columns
  };
};

const getSheet = (ss) => {
  /**
   * Returns the named worksheet within the given spreadsheet, creating it if absent.
   * ss must be passed in by the caller — getActiveSpreadsheet() returns null in
   * library context when invoked via a web app doPost.
   */
  const config = getConfig();
  let sheet = ss.getSheetByName(config.logsSheetName);
  if (sheet == null) {
    // create worksheet if none
    sheet = ss.insertSheet(config.logsSheetName);
    sheet.appendRow(config.logsSheetFields); // heading row
  }
  return sheet;
};

function doPost(e, ss) {
  /**
   * Logs incoming POST request with JSON array of objects in body, e.g.
   * {
   *  "date": <ISO 8601 timestamp>,
   *  "repository": <remote origin url or local path>,
   *  "username": <git user.name or OS username>,
   *  "email": <git user.email>,
   *  "tool": <ai tool name, e.g. claude, cursor, copilot>,
   *  "event": <specific hook event, e.g. afterFileEdit, PostToolUse>,
   *  "machine": <hostname>,
   *  "machine_user": <os login name>,
   *  "hook_integrity": <object of file hashes>
   * }
   */
  Logger.log("Incoming post request");
  // Logger.log(JSON.stringify(e, null, 2))
  const commit_data = JSON.parse(e.postData.contents); // should be an array of objects
  const config = getConfig();
  const sheet = getSheet(ss);
  // response object
  const res = {
    type: "post",
    data_type: typeof commit_data,
    success: false, // will flip to true if successfully logged
    e: e,
  };
  if (Array.isArray(commit_data)) {
    // if array, log each object into sheet
    for (let i = 0; i < commit_data.length; i++) {
      const commit = commit_data[i];
      Logger.log(JSON.stringify(commit, null, 2));
      // build row in column order defined by logsSheetFields
      const row = config.logsSheetFields.map((field) => commit[field] ?? "");
      sheet.appendRow(row);
    }
    res.success = true; // flip it now that we've logged data
  }
  // send json response
  return ContentService.createTextOutput(
    JSON.stringify(res, null, 2),
  ).setMimeType(ContentService.MimeType.JSON);
}

/* istanbul ignore next */
if (typeof module !== "undefined") {
  module.exports = { getConfig, getSheet, doPost };
}
