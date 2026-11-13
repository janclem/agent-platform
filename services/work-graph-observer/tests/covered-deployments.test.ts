import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { coveredCommits, type MainCommit } from "../scripts/covered-deployments";
import { DELIVERY_TARGETS_PATH } from "../src/reconciliation";

const repository = "janclem/agent-platform";

const covered = async (
  environment: string,
  commits: MainCommit[],
  alreadyDeployed: string[] = [],
) =>
  coveredCommits({
    repository,
    environment,
    catalog: await readFile(resolve(__dirname, "../../..", DELIVERY_TARGETS_PATH), "utf8"),
    catalogRevision: "test-revision",
    commits,
    alreadyDeployed: new Set(alreadyDeployed),
  });

const apiChange = { sha: "a".repeat(40), changedPaths: ["services/work-graph-api/src/app.ts"] };
const infraChange = { sha: "b".repeat(40), changedPaths: ["infra/work-graph/main.tf"] };
const docsChange = { sha: "c".repeat(40), changedPaths: ["docs/adr/0019-work-graph-github-evidence-app.md"] };

describe("covered deployments", () => {
  it("records only commits whose targets list the environment", async () => {
    expect(await covered("production-work-graph-infra", [apiChange, infraChange, docsChange])).toEqual([
      { sha: infraChange.sha, targetIds: ["delivery-target:work-graph/infrastructure"] },
    ]);
    expect(await covered("production-agent-platform", [apiChange, infraChange, docsChange])).toEqual([
      { sha: docsChange.sha, targetIds: ["delivery-target:agent-platform/platform"] },
    ]);
  });

  it("records a commit that maps to several targets once, naming each", async () => {
    const mixed = {
      sha: "d".repeat(40),
      changedPaths: ["services/work-graph-api/src/app.ts", ".github/workflows/ci.yml"],
    };
    expect(await covered("production-work-graph", [mixed])).toEqual([
      { sha: mixed.sha, targetIds: ["delivery-target:work-graph/service"] },
    ]);
    expect(await covered("production-agent-platform", [mixed])).toEqual([
      { sha: mixed.sha, targetIds: ["delivery-target:agent-platform/platform"] },
    ]);
  });

  it("skips commits that already have a successful deployment, and empty commits", async () => {
    expect(
      await covered(
        "production-work-graph-infra",
        [infraChange, { sha: "e".repeat(40), changedPaths: [] }],
        [infraChange.sha],
      ),
    ).toEqual([]);
  });
});
