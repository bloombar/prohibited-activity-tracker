function doPost(e) {
  return Prohibition.doPost(e, SpreadsheetApp.getActiveSpreadsheet());
}

/* istanbul ignore next */
if (typeof module !== "undefined") {
  module.exports = { doPost };
}
