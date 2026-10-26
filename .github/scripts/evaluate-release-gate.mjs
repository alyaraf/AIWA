// A24-04: the decision behind the "release-gate" job of ci.yml, as code that can be tested (no jq, no YAML).
//
// Input (environment): NEEDS = toJSON(needs) of the gate, GITHUB_SHA = the commit being released,
// REQUIRE_CVE_SCAN = the repository variable of that name, GITHUB_STEP_SUMMARY (optional).
// Exit 0 only when EVERY required job really succeeded for the commit being released:
//   - a failed, cancelled, skipped or missing job refuses the release;
//   - the security scans (CodeQL, Trivy) must also report that the commit they scanned IS the released commit, so a scan
//     of another commit (or one that reports nothing) never authorizes a deployment;
//   - REQUIRE_CVE_SCAN=true additionally refuses a backend CVE scan that was skipped instead of run.
import { appendFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { REQUIRED, COMMIT_BOUND } from "./check-ci-graph.mjs";

/** Returns { ok, lines, problems } for a gate input; pure, so the tests can drive it with synthetic needs. */
export function evaluate({ needs, sha, requireCveScan }) {
  const lines = [];
  const problems = [];
  for (const job of REQUIRED) {
    const result = needs?.[job]?.result ?? "missing";
    lines.push(`${job}: ${result}`);
    if (result !== "success") problems.push(`${job} did not succeed (${result})`);
  }
  for (const job of COMMIT_BOUND) {
    const scanned = needs?.[job]?.outputs?.scanned_sha ?? "";
    const ok = Boolean(sha) && scanned === sha;
    lines.push(`${job} scanned commit: ${scanned || "none reported"}`);
    if (!ok) problems.push(`${job} did not report a scan of the released commit ${sha || "(unknown)"} (reported: ${scanned || "none"})`);
  }
  const scan = needs?.["dependency-scan"]?.outputs?.scan ?? "unknown";
  lines.push(`backend CVE scan: ${scan}`);
  if (scan !== "ran") {
    lines.push(`WARNING: the backend CVE scan did not run (${scan}): this release has no backend vulnerability scan evidence`);
    if (requireCveScan === "true") problems.push(`REQUIRE_CVE_SCAN=true and the backend CVE scan did not run (${scan})`);
  }
  return { ok: problems.length === 0, lines, problems };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let needs;
  try {
    needs = JSON.parse(process.env.NEEDS ?? "");
  } catch {
    console.error("::error::NEEDS is missing or is not JSON: the release cannot be evaluated");
    process.exit(1);
  }
  const { ok, lines, problems } = evaluate({ needs, sha: process.env.GITHUB_SHA, requireCveScan: process.env.REQUIRE_CVE_SCAN });
  lines.forEach((l) => console.log(l));
  problems.forEach((p) => console.error(`::error::${p}`));
  if (process.env.GITHUB_STEP_SUMMARY) {
    const rows = ["| check | result |", "| --- | --- |", ...lines.map((l) => `| ${l.replace(/: /, " | ")} |`)];
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${rows.join("\n")}\n\n${ok ? "Release gate: PASS" : "Release gate: REFUSED"}\n`);
  }
  process.exit(ok ? 0 : 1);
}
