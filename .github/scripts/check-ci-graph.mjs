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

// The validation jobs a release must wait for, and the jobs that deploy or promote.
export const REQUIRED = ["ci-graph", "backend", "admin", "monitoring-rules", "backup-restore", "sbom", "flutter", "android", "dependency-scan"];
export const DEPLOYERS = ["deploy-staging"];

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
    if (job) { current = job[1]; jobs[current] = { needs: [], ifExpr: "", continueOnError: false, outputs: [] }; collectingNeeds = false; continue; }
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

/** Returns a list of problems (empty when the graph is sound). */
export function check(text) {
  const jobs = parse(text);
  const problems = [];
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
  }
  const scan = jobs["dependency-scan"];
  if (scan && !scan.outputs.includes("scan")) problems.push('dependency-scan must expose an output "scan" (ran|skipped) so a skipped CVE scan is not reported as a pass');
  return problems;
}

function selfTest(text) {
  const mutations = [
    ["deploy-staging back to backend/admin only", (t) => t.replace(/deploy-staging:\r?\n    needs: \[release-gate\]/, "deploy-staging:\n    needs: [backend, admin]")],
    ["gate without backup-restore", (t) => t.replace(/needs: \[ci-graph, backend, admin, monitoring-rules, backup-restore,/, "needs: [ci-graph, backend, admin, monitoring-rules,")],
    ["gate without always()", (t) => t.replace("if: always() && github.event_name == 'push'", "if: github.event_name == 'push'")],
    ["continue-on-error on a required job", (t) => t.replace(/  monitoring-rules:\r?\n/, "  monitoring-rules:\n    continue-on-error: true\n")],
    ["scan output removed", (t) => t.replace(/      scan: \$\{\{ steps\.scan\.outputs\.status \}\}\r?\n/, "")],
  ];
  let failed = 0;
  for (const [label, mutate] of mutations) {
    const mutated = mutate(text);
    if (mutated === text) { console.error(`self-test "${label}": the mutation did not change the workflow (update the self-test)`); failed++; continue; }
    const problems = check(mutated);
    if (problems.length === 0) { console.error(`self-test "${label}": the broken graph was ACCEPTED`); failed++; } else console.log(`ok   self-test rejects: ${label}`);
  }
  return failed;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const text = readFileSync(WORKFLOW, "utf8");
  const problems = check(text);
  const jobs = parse(text);
  console.log(`jobs: ${Object.keys(jobs).join(", ")}`);
  for (const name of DEPLOYERS) console.log(`${name} (transitive needs): ${[...closure(jobs, name)].join(", ")}`);
  problems.forEach((p) => console.error(`FAIL ${p}`));
  let failed = problems.length;
  if (process.argv.includes("--self-test")) failed += selfTest(text);
  if (failed) process.exit(1);
  console.log("CI dependency graph: OK");
}
