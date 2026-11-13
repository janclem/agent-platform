// Records a successful deployment of HEAD to <environment> for each earlier
// main commit that deployment also delivered (see covered-deployments.ts). It
// walks main's first-parent history back from HEAD to the nearest commit with a
// successful deployment there, or to --since <sha> for a one-off repair, and
// records nothing when neither is within MAX_COMMITS. Uses `gh` (GH_TOKEN in
// Actions, the operator's login locally); run it only after HEAD's own
// deployment to the environment succeeded.
//
//   tsx scripts/record-covered-deployments.ts <environment> [--since <sha>] [--dry-run]
import { execFileSync } from "node:child_process";
import { parseArgs } from "node:util";
import { DELIVERY_TARGETS_PATH } from "../src/reconciliation";
import { coveredCommits, type MainCommit } from "./covered-deployments";

const MAX_COMMITS = 100;

const run = (command: string, args: string[], input?: string): string =>
  execFileSync(command, args, { encoding: "utf8", input }).trim();
const git = (...args: string[]) => run("git", args);
const gh = <T>(path: string, ...args: string[]): T =>
  JSON.parse(run("gh", ["api", path, ...args]) || "null") as T;

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: { since: { type: "string" }, "dry-run": { type: "boolean" } },
});
const [environment] = positionals;
if (!environment || positionals.length !== 1) {
  throw new Error("Usage: record-covered-deployments.ts <environment> [--since <sha>] [--dry-run]");
}
const repository = (process.env.GITHUB_REPOSITORY ?? "janclem/agent-platform").toLowerCase();
const head = git("rev-parse", "HEAD");
const since = values.since === undefined ? undefined : git("rev-parse", `${values.since}^{commit}`);

// Any success counts: GitHub marks a deployment inactive once a newer one
// succeeds, so the latest status of an earlier deployment is usually inactive.
const hasSuccessfulDeployment = (sha: string): boolean =>
  gh<{ id: number }[]>(
    `repos/${repository}/deployments?environment=${encodeURIComponent(environment)}&sha=${sha}&per_page=100`,
  ).some(({ id }) =>
    gh<{ state: string }[]>(`repos/${repository}/deployments/${id}/statuses?per_page=100`).some(
      ({ state }) => state === "success",
    ),
  );

// Newest first, excluding HEAD itself.
const history = git("rev-list", "--first-parent", `--max-count=${MAX_COMMITS + 1}`, `${head}^`)
  .split("\n")
  .filter(Boolean);
const commits: MainCommit[] = [];
const alreadyDeployed = new Set<string>();
let boundary: string | undefined;
for (const sha of history) {
  if (sha === since) {
    boundary = sha;
    break;
  }
  if (hasSuccessfulDeployment(sha)) {
    if (since === undefined) {
      boundary = sha;
      break;
    }
    alreadyDeployed.add(sha);
  }
  commits.unshift({
    sha,
    // Against the first parent; the root commit is compared with the empty tree.
    changedPaths: git("diff-tree", "-r", "--root", "--no-commit-id", "--name-only", "-m", "--first-parent", sha)
      .split("\n")
      .filter(Boolean),
  });
}
if (boundary === undefined) {
  console.log(
    `No ${since === undefined ? "earlier successful deployment" : `commit ${since}`} to ${environment} within ${MAX_COMMITS} commits of ${head}; recording nothing.`,
  );
  process.exit(0);
}

const covered = coveredCommits({
  repository,
  environment,
  catalog: git("show", `${head}:${DELIVERY_TARGETS_PATH}`),
  catalogRevision: git("rev-parse", `${head}:${DELIVERY_TARGETS_PATH}`),
  commits,
  alreadyDeployed,
});
const post = <T>(path: string, body: unknown): T =>
  JSON.parse(run("gh", ["api", path, "--input", "-"], JSON.stringify(body))) as T;
for (const { sha, targetIds } of covered) {
  if (values["dry-run"]) {
    console.log(`Would record ${environment} deployment for ${sha} (${targetIds.join(", ")}).`);
    continue;
  }
  const deployment = post<{ id: number; sha: string }>(`repos/${repository}/deployments`, {
    ref: sha,
    environment,
    auto_merge: false,
    required_contexts: [],
    production_environment: true,
    description: `Delivered by ${head.slice(0, 12)}`,
    payload: { deliveredBy: head, targetIds },
  });
  if (deployment.sha !== sha) {
    throw new Error(`Deployment ${deployment.id} points at ${deployment.sha}, not ${sha}.`);
  }
  // auto_inactive: false keeps HEAD's own deployment the active one.
  post(`repos/${repository}/deployments/${deployment.id}/statuses`, {
    state: "success",
    description: `Delivered by the deployment of ${head.slice(0, 12)}`,
    auto_inactive: false,
  });
  console.log(`Recorded ${environment} deployment ${deployment.id} for ${sha} (${targetIds.join(", ")}).`);
}
console.log(
  covered.length === 0
    ? `No commits between ${boundary.slice(0, 7)} and ${head.slice(0, 7)} needed a ${environment} deployment.`
    : `${values["dry-run"] ? "Would record" : "Recorded"} ${environment} deployments for ${covered.length} commit(s) delivered by ${head.slice(0, 7)}.`,
);
