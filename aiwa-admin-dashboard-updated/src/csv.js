// AD-01: user-written text (review comments, names) ends up in CSV exports that an admin opens in a spreadsheet.
// Quoting protects the CSV structure only; a cell that BEGINS with = + - @ (or a tab / carriage return, or one of
// those after whitespace or control characters, which spreadsheets also treat as the start of a formula) is
// evaluated as a formula on open. Such a cell gets a leading apostrophe so it is read as text.

const FORMULA_START = /^[\s\u0000-\u001f ﻿]*[=+\-@]/;
const TAB_OR_CR_START = /^[\t\r]/;

/** Text of one cell with spreadsheet formulas neutralized. Numbers and booleans are not text, so they pass. */
export function neutralizeFormula(value) {
  if (value == null) return "";
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  const text = String(value);
  return FORMULA_START.test(text) || TAB_OR_CR_START.test(text) ? `'${text}` : text;
}

/** One CSV cell: formula-safe, then quoted when it holds a comma, quote or line break. */
export function csvCell(value) {
  const text = neutralizeFormula(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** Whole CSV text from a header row and records. */
export function toCsv(header, records) {
  return [header.map(csvCell).join(","), ...records.map((row) => row.map(csvCell).join(","))].join("\n");
}
