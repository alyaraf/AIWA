// R4-08: verifies the dependency graph of .github/workflows/ci.yml, with no YAML library (the workflow only uses
// "needs: [a, b]" and block-list needs). Fails when a deployment can start without every required validation job.
//
//   node .github/scripts/check-ci-graph.mjs              check the real workflow
//   node .github/scripts/check-ci-graph.mjs --self-test  also prove that the check rejects broken graphs
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const WORKFLOW = resolve(here, "../workflows/ci.yml");
const WORKFLOW_DIR = resolve(here, "../workflows");

// The validation jobs a release must wait for, and the jobs that deploy or promote.
// A24-04: CodeQL and Trivy are required jobs too (reusable workflows called from ci.yml), so a deployment cannot
// start while either is running, failed, cancelled or skipped.
export const REQUIRED = ["ci-graph", "backend", "admin", "monitoring-rules", "backup-restore", "sbom", "flutter", "android", "dependency-scan", "codeql", "trivy"];
export const DEPLOYERS = ["deploy-staging"];
// The security scans are called workflows; each must report the commit it scanned (output scanned_sha), which the
// release decision compares with the commit being released.
export const COMMIT_BOUND = ["codeql", "trivy"];
export const CALLED_WORKFLOWS = { codeql: "codeql.yml", trivy: "scan.yml" };
export const GATE_SCRIPT = "node .github/scripts/evaluate-release-gate.mjs";

export function parse(text) {
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  const jobs = {};
  let inJobs = false;
  let current = null;
  let collectingNeeds = false;
  for (const line of lines) {
    if (/^jobs:\s*$/.test(line)) { inJobs = true; continue; }
    if (!inJobs) continue;
    if (/^\S/.test(line) && line.trim() !== "") break; // next top-level key
    const job = line.match(/^  ([A-Za-z0-9_-]+):\s*$/);
    if (job) { current = job[1]; jobs[current] = { needs: [], ifExpr: "", continueOnError: false, outputs: [], uses: "" }; collectingNeeds = false; continue; }
    if (!current) continue;
    const inline = line.match(/^    needs:\s*\[(.*)\]\s*$/);
    const single = line.match(/^    needs:\s*([A-Za-z0-9_-]+)\s*$/);
    if (inline) { jobs[current].needs = inline[1].split(",").map((s) => s.trim()).filter(Boolean); collectingNeeds = false; continue; }
    if (single) { jobs[current].needs = [single[1]]; continue; }
    if (/^    needs:\s*$/.test(line)) { collectingNeeds = true; continue; }
    if (collectingNeeds) {
      const item = line.match(/^      - ([A-Za-z0-9_-]+)\s*$/);
      if (item) { jobs[current].needs.push(item[1]); continue; }
      collectingNeeds = false;
    }
    const usesLine = line.match(/^    uses:\s*(\S+)/);
    if (usesLine) jobs[current].uses = usesLine[1];
    const cond = line.match(/^    if:\s*(.*)$/);
    if (cond) jobs[current].ifExpr = cond[1];
    if (/^    continue-on-error:\s*true/.test(line)) jobs[current].continueOnError = true;
    const out = line.match(/^      ([A-Za-z0-9_-]+):\s*\$\{\{.*\}\}\s*$/);
    if (out) jobs[current].outputs.push(out[1]);
  }
  return jobs;
}

function closure(jobs, name, seen = new Set()) {
  for (const need of jobs[name]?.needs ?? []) {
    if (!seen.has(need)) { seen.add(need); closure(jobs, need, seen); }
  }
  return seen;
}

/** Remote actions must be pinned to a full commit SHA; a local ./ workflow is part of this commit already. */
function unpinnedActions(text, label) {
  const found = [];
  for (const m of text.replace(/\r\n/g, "\n").matchAll(/^\s*(?:-\s*)?uses:\s*(\S+)/gm)) {
    const ref = m[1];
    if (ref.startsWith("./")) continue;
    if (!/@[0-9a-f]{40}$/.test(ref)) found.push(`${label}: ${ref} is not pinned to a full commit SHA`);
  }
  return found;
}

/**
 * Returns a list of problems (empty when the graph is sound).
 * `called` maps a workflow file name (codeql.yml, scan.yml) to its text, for the reusable-workflow checks; when
 * omitted those checks are skipped (the self-test passes them in).
 */
export function check(text, called = null) {
  const jobs = parse(text);
  const problems = [];
  if (/^\s*pull_request_target\s*:/m.test(text)) problems.push("ci.yml must not use pull_request_target (it would run pull-request code with repository secrets)");
  problems.push(...unpinnedActions(text, "ci.yml"));
  for (const name of COMMIT_BOUND) {
    const job = jobs[name];
    if (!job) continue;
    const file = CALLED_WORKFLOWS[name];
    if (job.uses !== `./.github/workflows/${file}`) problems.push(`"${name}" must call ./.github/workflows/${file} (found "${job.uses || "no reusable workflow"}"): a separate workflow is not part of this run, so nothing would wait for it`);
    if (job.ifExpr) problems.push(`"${name}" has a job-level condition: the security scan must run for every release`);
    const body = called?.[file];
    if (called) {
      if (body === undefined) problems.push(`workflow ${file} could not be read`);
      else {
        if (!/^\s{2}workflow_call:/m.test(body)) problems.push(`${file} does not declare workflow_call: ci.yml cannot require it`);
        if (!/scanned_sha:/.test(body)) problems.push(`${file} does not output scanned_sha: the gate cannot tell which commit was scanned`);
        if (/continue-on-error:\s*true/.test(body)) problems.push(`${file} has continue-on-error: a failed scan would not fail the release`);
        if (/^\s*pull_request_target\s*:/m.test(body)) problems.push(`${file} must not use pull_request_target`);
        problems.push(...unpinnedActions(body, file));
      }
    }
  }
  for (const name of REQUIRED) {
    if (!jobs[name]) problems.push(`required job "${name}" does not exist`);
    else if (jobs[name].continueOnError) problems.push(`required job "${name}" has continue-on-error: it can fail without failing the release`);
  }
  for (const name of DEPLOYERS) {
    if (!jobs[name]) { problems.push(`deploy job "${name}" does not exist`); continue; }
    const deps = closure(jobs, name);
    for (const required of REQUIRED) {
      if (!deps.has(required)) problems.push(`${name} can start without "${required}" (its needs reach only: ${[...deps].join(", ") || "nothing"})`);
    }
    if (!deps.has("release-gate")) problems.push(`${name} does not depend on release-gate`);
  }
  const gate = jobs["release-gate"];
  if (!gate) problems.push('job "release-gate" does not exist');
  else {
    for (const required of REQUIRED) if (!gate.needs.includes(required)) problems.push(`release-gate does not need "${required}" directly (needs.${required}.result would be unavailable)`);
    if (!/always\(\)/.test(gate.ifExpr)) problems.push("release-gate must use always(), otherwise a failed or skipped need skips the gate silently instead of failing it");
    if (!text.includes(GATE_SCRIPT)) problems.push(`release-gate must run "${GATE_SCRIPT}": it is the tested decision (every need succeeded, scans bound to this commit, REQUIRE_CVE_SCAN)`);
    const gateBlock = text.replace(/\r\n/g, "\n").split(/^  release-gate:\s*$/m)[1]?.split(/^  [A-Za-z0-9_-]+:\s*$/m)[0] ?? "";
    if (!/REQUIRE_CVE_SCAN:\s*\$\{\{\s*vars\.REQUIRE_CVE_SCAN\s*\}\}/.test(gateBlock)) problems.push("release-gate must pass vars.REQUIRE_CVE_SCAN to the decision, otherwise a skipped backend CVE scan can never block a promotion");
  }
  const scan = jobs["dependency-scan"];
  if (scan && !scan.outputs.includes("scan")) problems.push('dependency-scan must expose an output "scan" (ran|skipped) so a skipped CVE scan is not reported as a pass');
  return problems;
}

function selfTest(text, called) {
  const mutations = [
    ["deploy-staging back to backend/admin only", (t) => t.replace(/deploy-staging:\r?\n    needs: \[release-gate\]/, "deploy-staging:\n    needs: [backend, admin]")],
    ["gate without backup-restore", (t) => t.replace(/needs: \[ci-graph, backend, admin, monitoring-rules, backup-restore,/, "needs: [ci-graph, backend, admin, monitoring-rules,")],
    ["gate without always()", (t) => t.replace("if: always() && github.event_name == 'push'", "if: github.event_name == 'push'")],
    ["continue-on-error on a required job", (t) => t.replace(/  monitoring-rules:\r?\n/, "  monitoring-rules:\n    continue-on-error: true\n")],
    ["scan output removed", (t) => t.replace(/      scan: \$\{\{ steps\.scan\.outputs\.status \}\}\r?\n/, "")],
    // A24-04: the security scans must be prerequisites of the release.
    ["gate without codeql", (t) => t.replace(/(needs: \[ci-graph,[^\]]*), codeql/, "$1")],
    ["gate without trivy", (t) => t.replace(/(needs: \[ci-graph,[^\]]*), trivy\]/, "$1]")],
    ["codeql job removed", (t) => t.replace(/  codeql:\r?\n    uses: [^\n]*\n/, "  codeql:\n    runs-on: ubuntu-latest\n")],
    ["trivy no longer a called workflow", (t) => t.replace("uses: ./.github/workflows/scan.yml", "uses: ./.github/workflows/other.yml")],
    ["codeql made conditional", (t) => t.replace(/  codeql:\r?\n/, "  codeql:\n    if: github.event_name == 'pull_request'\n")],
    ["gate no longer runs the tested decision", (t) => t.replace(GATE_SCRIPT, "echo skipped")],
    ["REQUIRE_CVE_SCAN no longer reaches the decision", (t) => t.replace(/REQUIRE_CVE_SCAN: \$\{\{ vars\.REQUIRE_CVE_SCAN \}\}/g, "REQUIRE_CVE_SCAN: ''")],
    ["unpinned action", (t) => t.replace(/actions\/setup-node@[0-9a-f]{40}/, "actions/setup-node@v4")],
    ["pull_request_target trigger", (t) => t.replace(/^on:\r?\n/m, "on:\n  pull_request_target:\n")],
  ];
  const calledMutations = [
    ["codeql.yml without workflow_call", (c) => ({ ...c, "codeql.yml": c["codeql.yml"].replace(/^  workflow_call:/m, "  push:") })],
    ["scan.yml without scanned_sha", (c) => ({ ...c, "scan.yml": c["scan.yml"].replace(/scanned_sha:/g, "other:") })],
    ["scan.yml with continue-on-error", (c) => ({ ...c, "scan.yml": c["scan.yml"].replace("  trivy:\n", "  trivy:\n    continue-on-error: true\n") })],
    ["scan.yml unpinned action", (c) => ({ ...c, "scan.yml": c["scan.yml"].replace(/actions\/checkout@[0-9a-f]{40}/, "actions/checkout@v4") })],
  ];
  let failed = 0;
  for (const [label, mutate] of mutations) {
    const mutated = mutate(text);
    if (mutated === text) { console.error(`self-test "${label}": the mutation did not change the workflow (update the self-test)`); failed++; continue; }
    const problems = check(mutated, called);
    if (problems.length === 0) { console.error(`self-test "${label}": the broken graph was ACCEPTED`); failed++; } else console.log(`ok   self-test rejects: ${label}`);
  }
  for (const [label, mutate] of calledMutations) {
    const files = mutate(Object.fromEntries(Object.entries(called).map(([k, v]) => [k, v.replace(/\r\n/g, "\n")])));
    if (JSON.stringify(files) === JSON.stringify(Object.fromEntries(Object.entries(called).map(([k, v]) => [k, v.replace(/\r\n/g, "\n")])))) { console.error(`self-test "${label}": the mutation did not change the workflow (update the self-test)`); failed++; continue; }
    const problems = check(text, files);
    if (problems.length === 0) { console.error(`self-test "${label}": the broken workflow was ACCEPTED`); failed++; } else console.log(`ok   self-test rejects: ${label}`);
  }
  return failed;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const text = readFileSync(WORKFLOW, "utf8");
  const called = {};
  for (const file of Object.values(CALLED_WORKFLOWS)) {
    try { called[file] = readFileSync(resolve(WORKFLOW_DIR, file), "utf8"); } catch { /* reported by check() */ }
  }
  const problems = check(text, called);
  const jobs = parse(text);
  console.log(`jobs: ${Object.keys(jobs).join(", ")}`);
  for (const name of DEPLOYERS) console.log(`${name} (transitive needs): ${[...closure(jobs, name)].join(", ")}`);
  problems.forEach((p) => console.error(`FAIL ${p}`));
  let failed = problems.length;
  if (process.argv.includes("--self-test")) failed += selfTest(text, called);
  if (failed) process.exit(1);
  console.log("CI dependency graph: OK");
}
