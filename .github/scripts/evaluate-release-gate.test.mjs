// A24-04: behaviour of the release decision. Run: node --test .github/scripts/evaluate-release-gate.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { evaluate } from "./evaluate-release-gate.mjs";
import { REQUIRED } from "./check-ci-graph.mjs";

const SHA = "a".repeat(40);
const OTHER = "b".repeat(40);

/** A gate input where everything succeeded for SHA; tweak it per case. */
function healthy(overrides = {}) {
  const needs = {};
  for (const job of REQUIRED) needs[job] = { result: "success", outputs: {} };
  needs["dependency-scan"].outputs.scan = "ran";
  needs.codeql.outputs.scanned_sha = SHA;
  needs.trivy.outputs.scanned_sha = SHA;
  for (const [job, patch] of Object.entries(overrides)) needs[job] = { ...needs[job], ...patch, outputs: { ...needs[job]?.outputs, ...patch.outputs } };
  return { needs, sha: SHA, requireCveScan: "false" };
}

test("every job succeeded for the released commit: authorized", () => {
  const r = evaluate(healthy());
  assert.equal(r.ok, true, r.problems.join("; "));
});

for (const scanner of ["codeql", "trivy"]) {
  for (const result of ["failure", "cancelled", "skipped"]) {
    test(`${scanner} ${result}: not authorized`, () => {
      const r = evaluate(healthy({ [scanner]: { result } }));
      assert.equal(r.ok, false);
      assert.ok(r.problems.some((p) => p.startsWith(`${scanner} did not succeed (${result})`)), r.problems.join("; "));
    });
  }
  test(`${scanner} absent from needs: not authorized`, () => {
    const input = healthy();
    delete input.needs[scanner];
    const r = evaluate(input);
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.includes(`${scanner} did not succeed (missing)`)));
  });
  test(`${scanner} succeeded but scanned a different commit: not authorized`, () => {
    const r = evaluate(healthy({ [scanner]: { outputs: { scanned_sha: OTHER } } }));
    assert.equal(r.ok, false);
    assert.ok(r.problems.some((p) => p.includes(`${scanner} did not report a scan of the released commit`)));
  });
  test(`${scanner} succeeded but reported no commit: not authorized`, () => {
    const r = evaluate(healthy({ [scanner]: { outputs: { scanned_sha: "" } } }));
    assert.equal(r.ok, false);
  });
}

test("an unknown released commit never matches a scan", () => {
  const input = healthy();
  input.sha = "";
  assert.equal(evaluate(input).ok, false);
});

test("any other required job failing, cancelled or skipped is refused", () => {
  for (const job of REQUIRED.filter((j) => j !== "codeql" && j !== "trivy")) {
    for (const result of ["failure", "cancelled", "skipped"]) {
      assert.equal(evaluate(healthy({ [job]: { result } })).ok, false, `${job} ${result}`);
    }
  }
});

test("a skipped backend CVE scan passes with a warning unless REQUIRE_CVE_SCAN=true", () => {
  const skipped = healthy({ "dependency-scan": { outputs: { scan: "skipped" } } });
  const lax = evaluate(skipped);
  assert.equal(lax.ok, true);
  assert.ok(lax.lines.some((l) => l.startsWith("WARNING")));
  const strict = evaluate({ ...skipped, requireCveScan: "true" });
  assert.equal(strict.ok, false);
  assert.ok(strict.problems.some((p) => p.includes("REQUIRE_CVE_SCAN=true")));
});

test("REQUIRE_CVE_SCAN=true with a completed scan is authorized; an unreported scan is not 'ran'", () => {
  assert.equal(evaluate({ ...healthy(), requireCveScan: "true" }).ok, true);
  const unknown = healthy();
  delete unknown.needs["dependency-scan"].outputs.scan;
  assert.equal(evaluate({ ...unknown, requireCveScan: "true" }).ok, false);
});

// The real entry point, as the workflow runs it (env in, exit code out).
const script = resolve(dirname(fileURLToPath(import.meta.url)), "evaluate-release-gate.mjs");
function run(env) {
  return spawnSync(process.execPath, [script], { env: { PATH: process.env.PATH, ...env }, encoding: "utf8" });
}

test("CLI: exit 0 for a healthy release, 1 for a failed scan, 1 for unreadable input", () => {
  const ok = healthy();
  assert.equal(run({ NEEDS: JSON.stringify(ok.needs), GITHUB_SHA: SHA }).status, 0);
  const bad = healthy({ trivy: { result: "failure" } });
  const refused = run({ NEEDS: JSON.stringify(bad.needs), GITHUB_SHA: SHA });
  assert.equal(refused.status, 1);
  assert.match(refused.stderr, /trivy did not succeed \(failure\)/);
  assert.equal(run({ NEEDS: "not json", GITHUB_SHA: SHA }).status, 1);
  assert.equal(run({ GITHUB_SHA: SHA }).status, 1);
  const otherCommit = run({ NEEDS: JSON.stringify(ok.needs), GITHUB_SHA: OTHER });
  assert.equal(otherCommit.status, 1);
});
