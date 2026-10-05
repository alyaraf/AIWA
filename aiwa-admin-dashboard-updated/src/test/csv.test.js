import { describe, it, expect } from "vitest";
import { csvCell, neutralizeFormula, toCsv } from "../csv.js";

/** AD-01: user text in a CSV export can never be read as a spreadsheet formula. */
describe("csv formula neutralization", () => {
  it("prefixes cells that start a formula", () => {
    for (const evil of ["=1+1", "+SUM(A1)", "-2+3", "@cmd", "=HYPERLINK(\"http://x\",\"y\")"]) {
      expect(neutralizeFormula(evil)).toBe(`'${evil}`);
    }
  });

  it("also catches a formula hidden behind whitespace or control characters", () => {
    expect(neutralizeFormula("  =1+1")).toBe("'  =1+1");
    expect(neutralizeFormula("\u0001=1+1")).toBe("'\u0001=1+1");
    expect(neutralizeFormula("\t=1+1")).toBe("'\t=1+1");
    expect(neutralizeFormula("\r=1+1")).toBe("'\r=1+1");
    expect(neutralizeFormula(" @x")).toBe("' @x");
  });

  it("leaves ordinary text, numbers and empties alone", () => {
    expect(neutralizeFormula("Great service")).toBe("Great service");
    expect(neutralizeFormula("a=b")).toBe("a=b");
    expect(neutralizeFormula(4.5)).toBe("4.5");
    expect(neutralizeFormula(-3)).toBe("-3"); // a real number, not user text
    expect(neutralizeFormula(null)).toBe("");
    expect(neutralizeFormula(undefined)).toBe("");
  });

  it("still quotes commas, quotes and line breaks after neutralizing", () => {
    expect(csvCell('=A1,"x"')).toBe('"\'=A1,""x"""');
    expect(csvCell("line1\nline2")).toBe('"line1\nline2"');
    expect(csvCell("plain")).toBe("plain");
  });

  it("builds a whole export", () => {
    expect(toCsv(["Author", "Comment"], [["Mona", "=1+1"], ["Omar", "fine, thanks"]]))
      .toBe("Author,Comment\nMona,'=1+1\nOmar,\"fine, thanks\"");
  });
});
